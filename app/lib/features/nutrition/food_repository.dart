import '../../data/models.dart';
import '../../data/sync.dart';
import 'food_item.dart';

/// Food form input that cannot be saved. The draft stays on screen.
class InvalidFood implements Exception {
  const InvalidFood(this.message);
  final String message;
}

/// One consumed food being added or edited. `dayKey` is pinned when the form opens, so midnight passing
/// while it is open never moves the entry to another day.
class FoodDraft {
  FoodDraft({this.id, required this.dayKey, this.meal = 'Breakfast', this.name = '', this.amount = '', this.calories, this.protein, this.carbs, this.fat,
      this.item, this.quantity, this.unitId});
  factory FoodDraft.edit(FoodEntry e) {
    final source = e.source;
    return FoodDraft(id: e.id, dayKey: e.dayKey, meal: e.meal, name: e.name, amount: e.amountDescription,
        calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat,
        item: source?['item'] is Map ? FoodItem(source!['item'] as Json) : null, quantity: (source?['quantity'] as num?)?.toDouble(), unitId: source?['unit'] as String?);
  }

  /// A new entry for a chosen food: one serving (or 100 g / 100 ml) of it, with that amount's values.
  factory FoodDraft.of(FoodItem item, {required String dayKey, required String meal}) {
    final (quantity, unit) = FoodScaling.initial(item);
    final scaled = FoodScaling.scale(item, quantity, unit);
    return FoodDraft(dayKey: dayKey, meal: meal, name: item.name, amount: FoodScaling.amountText(quantity, unit),
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

  Map<String, double?> get macros => {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat};
}

/// The owner's consumed-food journal, saved locally first. Today and Eat both read these same records.
class FoodRepository {
  FoodRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static void validate(FoodDraft d) {
    if (d.name.trim().isEmpty) throw const InvalidFood('Enter what you ate.');
    if (d.amount.trim().isEmpty) throw const InvalidFood('Enter how much, in your own words.');
    if (d.name.trim().length > 120 || d.amount.trim().length > 80) throw const InvalidFood('That text is too long.');
    if (!meals.contains(d.meal)) throw const InvalidFood('Choose a meal.');
    if (d.item != null && !((d.quantity ?? 0) > 0)) throw const InvalidFood('Enter how much you had, as a number above zero.');
    for (final v in [d.calories, d.protein, d.carbs, d.fat]) {
      if (v != null && (!v.isFinite || v < 0 || v > 100000)) throw const InvalidFood('Nutrition values must be zero or more.');
    }
  }

  /// What is recorded with an entry taken from a food: the food as it was, the amount, and per nutrient whether
  /// the value is the source's (`imported`) or the user's own (`entered`). Empty for an entry typed by hand.
  static Json sourceFields(FoodDraft d) {
    final item = d.item;
    if (item == null) return const {};
    final unit = FoodScaling.unit(item, d.unitId);
    final scaled = FoodScaling.scale(item, d.quantity!, unit);
    return {
      'source': {'item': item.j, 'quantity': d.quantity, 'unit': unit.id},
      'provenance': {for (final e in d.macros.entries) e.key: e.value == null ? 'unknown' : e.value == scaled[e.key] ? 'imported' : 'entered'},
    };
  }

  /// Saves a new entry or one edited entry. Blank nutrients are sent as null, never as zero.
  Future<Receipt> save(FoodDraft d) {
    validate(d);
    final id = d.id ?? SyncEngine.newId();
    final fields = {'dayKey': d.dayKey, 'meal': d.meal, 'name': d.name.trim(), 'amountDescription': d.amount.trim(), 'macros': d.macros, ...sourceFields(d)};
    final body = <String, dynamic>{
      'id': id, 'isDeleted': false, 'source': null,
      'provenance': {for (final e in d.macros.entries) e.key: e.value == null ? 'unknown' : 'entered'},
      ...fields,
    };
    final write = [LocalWrite(Kinds.food, id, body, dayKey: d.dayKey)];
    return d.id == null
        ? _sync.submit(_owner, kind: 'food.create', path: '/food-entries', targetKind: Kinds.food, targetId: id, writes: write, payload: {'entryId': id, ...fields})
        : _sync.submit(_owner, kind: 'food.update', method: 'PUT', path: '/food-entries/$id', targetKind: Kinds.food, targetId: id, writes: write,
            payload: {'expectedRevision': {r'$rev': [Kinds.food, id]}, ...fields});
  }

  /// Removes exactly this entry. Other entries, including others in the same meal, are untouched.
  Future<Receipt> remove(FoodEntry e) => _sync.submit(_owner, kind: 'food.delete', path: '/food-entries/${e.id}/delete', targetKind: Kinds.food, targetId: e.id,
      writes: [LocalWrite(Kinds.food, e.id, copyJson(e.j)..['isDeleted'] = true, dayKey: e.dayKey)],
      payload: {'expectedRevision': {r'$rev': [Kinds.food, e.id]}});

  /// Conflict choice "keep mine" for a food entry edited on two devices.
  Future<void> keepLocal(String conflictOperationId, FoodEntry local) => _sync.resolveKeepLocal(_owner, conflictOperationId,
      kind: local.isDeleted ? 'food.delete' : 'food.update', method: local.isDeleted ? 'POST' : 'PUT',
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
    if (item.name.trim().isEmpty || item.name.trim().length > 120) throw const InvalidFood('Give the food a name of up to 120 characters.');
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

  /// Marks a food as a favourite. A provider food is kept as a copy of how it was when it was marked.
  Future<Receipt> favourite(FoodItem item, {SavedFood? existing}) => _put(existing?.id ?? SyncEngine.newId(), existing?.item ?? item, true);

  /// A favourite that was only ever a provider copy is removed; the owner's own food just loses the mark.
  Future<Receipt> unfavourite(SavedFood food) => food.isMine ? _put(food.id, food.item, false) : remove(food);

  Future<Receipt> remove(SavedFood food) => _sync.submit(_owner, kind: 'savedfood.delete', path: '/saved-foods/${food.id}/delete', targetKind: Kinds.savedFood, targetId: food.id,
      writes: [LocalWrite(Kinds.savedFood, food.id, copyJson(food.j)..['isDeleted'] = true)], payload: {'expectedRevision': {r'$rev': [Kinds.savedFood, food.id]}});
}
