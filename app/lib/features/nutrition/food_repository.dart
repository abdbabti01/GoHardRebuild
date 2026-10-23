import 'dart:convert';

import '../../core/language.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'food_item.dart';

/// Why food form input cannot be saved; the form says it in the app's language.
enum FoodProblem { noName, noAmount, tooLong, noMeal, noQuantity, badValues, badValue, badSavedName, tooLarge, mealSize }

/// Food form input that cannot be saved. The draft stays on screen.
class InvalidFood implements Exception {
  const InvalidFood(this.problem, [this.nutrient]);
  final FoodProblem problem;

  /// For [FoodProblem.badValue]: the nutrient key ("protein").
  final String? nutrient;
  @override
  String toString() => 'InvalidFood(${problem.name})';
}

/// A stored meal name ([meals]: "Breakfast" …) as it reads in the app's language. The stored name never changes.
String mealLabel(AppLocalizations l, String meal) => switch (meal) {
      'Breakfast' => l.mealBreakfast,
      'Lunch' => l.mealLunch,
      'Dinner' => l.mealDinner,
      'Snack' => l.mealSnack,
      _ => meal,
    };

/// One consumed food being added or edited. `dayKey` is pinned when the form opens, so midnight passing
/// while it is open never moves the entry to another day.
class FoodDraft {
  FoodDraft({this.id, required this.dayKey, this.meal = 'Breakfast', this.name = '', this.amount = '', this.calories, this.protein, this.carbs, this.fat,
      this.item, this.quantity, this.unitId, this.recipe});
  factory FoodDraft.edit(FoodEntry e) {
    final source = e.source;
    return FoodDraft(id: e.id, dayKey: e.dayKey, meal: e.meal, name: e.name, amount: e.amountDescription,
        calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat,
        item: source?['item'] is Map ? FoodItem(source!['item'] as Json) : null, quantity: (source?['quantity'] as num?)?.toDouble(), unitId: source?['unit'] as String?,
        recipe: e.isRecipePortion ? source : null);
  }

  /// A new entry for a chosen food: one serving (or 100 g / 100 ml) of it, with that amount's values. A catalog
  /// food gives the everyday `name` it is logged under and the `unitId` it starts in; the food itself is the same.
  factory FoodDraft.of(FoodItem item, {required String dayKey, required String meal, String? name, String? unitId}) {
    final start = unitId == null ? null : FoodScaling.unit(item, unitId);
    final (double quantity, FoodUnit unit) = start == null ? FoodScaling.initial(item) : (start.id.startsWith('serving') ? 1 : 100, start);
    final scaled = FoodScaling.scale(item, quantity, unit);
    return FoodDraft(dayKey: dayKey, meal: meal, name: name ?? item.name, amount: FoodScaling.describe(item, quantity, unit),
        calories: scaled['calories'], protein: scaled['protein'], carbs: scaled['carbs'], fat: scaled['fat'], item: item, quantity: quantity, unitId: unit.id);
  }

  final String? id;
  String dayKey, meal, name, amount;

  /// Null = left blank = unknown. Zero = the user entered zero. These are never interchangeable.
  double? calories, protein, carbs, fat;

  /// The food these values were taken from, and how much of it. Null for an entry typed by hand.
  FoodItem? item;
  double? quantity;
  String? unitId;

  /// For one portion of a recipe: its whole source snapshot `{recipe, portion, partial}` (features/nutrition/saved_meals.dart).
  /// Its values are worked out from that frozen batch, never from the recipe as it is now.
  Json? recipe;

  Map<String, double?> get macros => {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat};
}

/// The owner's consumed-food journal, saved locally first. Today and Eat both read these same records.
class FoodRepository {
  FoodRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  /// Snapshot bounds the account applies too (api FoodService): a recipe portion carries its whole batch.
  static const snapshotLimit = 16000, compositeSnapshotLimit = 48000, maxBatch = 30;

  static void validate(FoodDraft d) {
    if (d.name.trim().isEmpty) throw const InvalidFood(FoodProblem.noName);
    if (d.amount.trim().isEmpty) throw const InvalidFood(FoodProblem.noAmount);
    if (d.name.trim().length > 120 || d.amount.trim().length > 80) throw const InvalidFood(FoodProblem.tooLong);
    if (!meals.contains(d.meal)) throw const InvalidFood(FoodProblem.noMeal);
    if (d.item != null && !((d.quantity ?? 0) > 0)) throw const InvalidFood(FoodProblem.noQuantity);
    for (final v in [d.calories, d.protein, d.carbs, d.fat]) {
      if (v != null && (!v.isFinite || v < 0 || v > 100000)) throw const InvalidFood(FoodProblem.badValues);
    }
    final source = sourceFields(d)['source'];
    if (source != null && jsonEncode(source).length > (d.recipe != null ? compositeSnapshotLimit : snapshotLimit)) throw const InvalidFood(FoodProblem.tooLarge);
  }

  /// What is recorded with an entry taken from a food: the food as it was, the amount, and per nutrient whether
  /// the value is the source's (`imported`) or the user's own (`entered`). Empty for an entry typed by hand.
  static Json sourceFields(FoodDraft d) {
    // A recipe portion's values are all its own batch's: known ones are taken from it, the rest are unknown.
    if (d.recipe != null) return {'source': d.recipe, 'provenance': {for (final e in d.macros.entries) e.key: e.value == null ? 'unknown' : 'imported'}};
    final item = d.item;
    if (item == null) return const {};
    final unit = FoodScaling.unit(item, d.unitId);
    final scaled = FoodScaling.scale(item, d.quantity!, unit);
    return {
      'source': {'item': item.j, 'quantity': d.quantity, 'unit': unit.id},
      'provenance': {for (final e in d.macros.entries) e.key: e.value == null ? 'unknown' : e.value == scaled[e.key] ? 'imported' : 'entered'},
    };
  }

  static Json _fields(FoodDraft d) => {'dayKey': d.dayKey, 'meal': d.meal, 'name': d.name.trim(), 'amountDescription': d.amount.trim(), 'macros': d.macros, ...sourceFields(d)};

  static Json _body(String id, Json fields) => {
        'id': id, 'isDeleted': false, 'source': null,
        'provenance': {for (final e in (fields['macros'] as Map).entries) e.key: e.value == null ? 'unknown' : 'entered'},
        ...fields,
      };

  /// Runs [submit] once per [operationId]: a second tap, or a retry after the first was written, writes nothing more.
  Future<Receipt> _once(String? operationId, Future<Receipt> Function() submit) async {
    final done = operationId == null ? null : await _sync.command(operationId);
    if (done != null) return Receipt(done.operationId, done.state);
    try {
      return await submit();
    } on LocalSaveFailure {
      final raced = operationId == null ? null : await _sync.command(operationId);
      if (raced != null) return Receipt(raced.operationId, raced.state);
      rethrow;
    }
  }

  /// Saves a new entry or one edited entry. Blank nutrients are sent as null, never as zero. A recipe portion is
  /// sent as its own command kind, held until the account's server takes recipe snapshots.
  Future<Receipt> save(FoodDraft d, {String? operationId}) {
    validate(d);
    final id = d.id ?? SyncEngine.newId();
    final fields = _fields(d);
    final write = [LocalWrite(Kinds.food, id, _body(id, fields), dayKey: d.dayKey)];
    final recipe = d.recipe == null ? '' : '.recipe';
    return _once(operationId, () => d.id == null
        ? _sync.submit(_owner, kind: 'food$recipe.create', path: '/food-entries', targetKind: Kinds.food, targetId: id, writes: write, payload: {'entryId': id, ...fields}, operationId: operationId)
        : _sync.submit(_owner, kind: 'food$recipe.update', method: 'PUT', path: '/food-entries/$id', targetKind: Kinds.food, targetId: id, writes: write,
            payload: {'expectedRevision': {r'$rev': [Kinds.food, id]}, ...fields}, operationId: operationId));
  }

  /// Logs a saved meal as one operation: one ordinary entry per food, all on the confirmed day and meal, written on
  /// the phone in one transaction with one command the account records whole or not at all. Every entry is checked
  /// first; one that cannot be saved saves none. The other entries point at the first (`parentId`), so a refused
  /// meal is reviewed and removed as one.
  Future<Receipt> logMeal(List<FoodDraft> drafts, {required String operationId}) async {
    if (drafts.isEmpty || drafts.length > maxBatch) throw const InvalidFood(FoodProblem.mealSize);
    drafts.forEach(validate);
    final ids = [for (final _ in drafts) SyncEngine.newId()];
    final fields = [for (final d in drafts) _fields(d)];
    return _once(operationId, () => _sync.submit(_owner, kind: 'food.batch', path: '/food-entries/batch', targetKind: Kinds.food, targetId: ids.first, operationId: operationId,
        writes: [for (final (i, d) in drafts.indexed) LocalWrite(Kinds.food, ids[i], _body(ids[i], fields[i]), dayKey: d.dayKey, parentId: i == 0 ? null : ids.first)],
        payload: {'entries': [for (final (i, f) in fields.indexed) {'entryId': ids[i], ...f}]}));
  }

  /// Removes exactly this entry. Other entries, including others in the same meal, are untouched.
  Future<Receipt> remove(FoodEntry e) => _sync.submit(_owner, kind: 'food.delete', path: '/food-entries/${e.id}/delete', targetKind: Kinds.food, targetId: e.id,
      writes: [LocalWrite(Kinds.food, e.id, copyJson(e.j)..['isDeleted'] = true, dayKey: e.dayKey)],
      payload: {'expectedRevision': {r'$rev': [Kinds.food, e.id]}});

  /// Conflict choice "keep mine" for a food entry edited on two devices.
  Future<void> keepLocal(String conflictOperationId, FoodEntry local) => _sync.resolveKeepLocal(_owner, conflictOperationId,
      kind: local.isDeleted ? 'food.delete' : local.isRecipePortion ? 'food.recipe.update' : 'food.update', method: local.isDeleted ? 'POST' : 'PUT',
      path: local.isDeleted ? '/food-entries/${local.id}/delete' : '/food-entries/${local.id}',
      payload: {
        'expectedRevision': {r'$rev': [Kinds.food, local.id]},
        if (!local.isDeleted) ...{
          'dayKey': local.dayKey, 'meal': local.meal, 'name': local.name, 'amountDescription': local.amountDescription, 'macros': local.macros,
          if (local.source != null) ...{'source': local.source, 'provenance': local.j['provenance']},
        },
      });
}

/// A reusable food the owner keeps: one they wrote, a provider food they corrected, or a favourite.
extension type SavedFood(Json j) {
  String get id => j['id'] as String;
  FoodItem get item => FoodItem(j['item'] as Json? ?? const {});
  bool get isFavourite => j['isFavourite'] as bool? ?? false;
  bool get isDeleted => j['isDeleted'] as bool? ?? false;

  /// Written or corrected by the owner, as opposed to a provider food kept only as a favourite.
  bool get isMine => item.source == 'user';
}

/// The owner's reusable foods and favourites, through the same local-first outbox as everything else.
/// Saving a food here never records anything as eaten.
class SavedFoodRepository {
  SavedFoodRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  Future<Receipt> _put(String id, FoodItem item, bool isFavourite) {
    if (item.name.trim().isEmpty || item.name.trim().length > 120) throw const InvalidFood(FoodProblem.badSavedName);
    return _sync.submit(_owner, kind: 'savedfood.put', method: 'PUT', path: '/saved-foods/$id', targetKind: Kinds.savedFood, targetId: id,
        writes: [LocalWrite(Kinds.savedFood, id, {'id': id, 'item': item.j, 'isFavourite': isFavourite, 'isDeleted': false})],
        // A food the account has never confirmed has revision 0, which is what creating one expects.
        payload: {'expectedRevision': {r'$rev': [Kinds.savedFood, id]}, 'item': item.j, 'isFavourite': isFavourite});
  }

  /// Keeps `values` (for `quantity` of `unitId` of `from`, or free-standing) as the owner's own food.
  /// The copy records what it was based on; the provider's food is not changed for anyone.
  Future<Receipt> saveMine({String? id, required String name, required Map<String, double?> values, FoodItem? from, double? quantity, String? unitId, String? amount, bool isFavourite = false}) {
    final key = id ?? SyncEngine.newId();
    final Json item;
    if (from != null && (quantity ?? 0) > 0) {
      final amountOfBasis = quantity! * FoodScaling.unit(from, unitId).basisPerUnit;
      item = {
        ...copyJson(from.j), 'source': 'user', 'sourceId': key, 'name': name.trim(),
        // Stored back on the food's own basis, so it can be scaled to any amount again.
        'nutrients': {for (final e in values.entries) e.key: e.value == null ? null : (e.value! / amountOfBasis * 100).roundToDouble() / 100},
        if (from.source != 'user') 'basedOn': {'source': from.source, 'sourceId': from.sourceId},
      }..remove('imageUrl')..remove('imageAttribution');
    } else {
      item = {
        'source': 'user', 'sourceId': key, 'name': name.trim(), 'basis': FoodItem.perServing, 'nutrients': values,
        'servings': [{'label': (amount ?? '').trim().isEmpty ? '1 serving' : amount!.trim(), 'grams': null, 'milliliters': null}],
      };
    }
    return _put(key, FoodItem(item), isFavourite);
  }

  /// Gives a kept food the portions of `from`, another copy of the same food on which the user just defined one.
  /// Only the list of portions changes: the kept food's name, values and favourite mark stay as they were.
  Future<Receipt> keepPortions(SavedFood food, FoodItem from) => _put(food.id, FoodItem({...copyJson(food.item.j), 'servings': from.j['servings']}), food.isFavourite);

  /// Marks a food as a favourite. A provider food is kept as a copy of how it was when it was marked.
  Future<Receipt> favourite(FoodItem item, {SavedFood? existing}) => _put(existing?.id ?? SyncEngine.newId(), existing?.item ?? item, true);

  /// A favourite that was only ever a provider copy is removed; the owner's own food just loses the mark.
  Future<Receipt> unfavourite(SavedFood food) => food.isMine ? _put(food.id, food.item, false) : remove(food);

  Future<Receipt> remove(SavedFood food) => _sync.submit(_owner, kind: 'savedfood.delete', path: '/saved-foods/${food.id}/delete', targetKind: Kinds.savedFood, targetId: food.id,
      writes: [LocalWrite(Kinds.savedFood, food.id, copyJson(food.j)..['isDeleted'] = true)], payload: {'expectedRevision': {r'$rev': [Kinds.savedFood, food.id]}});
}
