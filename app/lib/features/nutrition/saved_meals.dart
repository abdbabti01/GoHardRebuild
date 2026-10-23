import 'dart:convert';

import '../../core/units.dart' show formatNumber2;
import '../../data/db.dart' show Cmd;
import '../../data/models.dart';
import '../../data/sync.dart';
import 'food_item.dart';
import 'food_repository.dart';
import 'nutrient_coverage.dart';

/// Saved meals and recipes (docs/FOOD_DATA.md › Saved meals and recipes).
///
/// * A saved meal is foods with default amounts; a recipe is a whole batch of ingredients with the number of servings it
///   makes, and optionally the weight the finished batch was weighed at. Both are templates: saving, editing, previewing
///   or deleting one logs nothing, and changes nothing already logged.
/// * Logging copies: a meal becomes one ordinary entry per food; a recipe portion becomes one entry carrying a frozen
///   snapshot of the batch it came from. History never looks at the template again.
/// * Every component keeps its food snapshot (identity, basis, portions, source) and a structured amount (quantity +
///   unit id), never display text to be parsed.

/// One food of a saved meal or a recipe: the food as it was when it was added, and how much of it.
extension type MealComponent(Json j) {
  FoodItem get item => FoodItem(j['item'] as Json? ?? const {});
  double get quantity => (j['quantity'] as num).toDouble();
  String get unitId => j['unit'] as String? ?? '';
  FoodUnit get unit => FoodScaling.unit(item, unitId);

  /// The name it is shown and logged under (a catalog food's everyday name), else the food's own.
  String get name => (j['name'] as String?)?.trim().isNotEmpty == true ? j['name'] as String : item.name;

  /// The amount in words as it was said when it was set ("2 eggs (100 g)"): a logged amount never changes language.
  String get amount => j['amount'] as String? ?? FoodScaling.describe(item, quantity, unit);

  /// Exact values for this amount, nothing rounded: unknown stays null, a zero stays zero.
  Map<String, double?> get values => {
        for (final k in FoodItem.nutrientKeys) k: item.nutrient(k) == null ? null : item.nutrient(k)! * quantity * unit.basisPerUnit,
      };

  /// The same food at another amount (and unit), with that amount said as [amount].
  MealComponent withAmount(double quantity, String unitId, String amount) => MealComponent({...j, 'quantity': quantity, 'unit': unitId, 'amount': amount});

  /// A food chosen in the picker and its confirmed amount. A hand-typed food becomes a food of its own, on a serving basis.
  static MealComponent ofDraft(FoodDraft d) {
    final item = d.item, quantity = d.quantity;
    if (item == null || quantity == null || quantity <= 0) return _typed(d.name, d.amount, d.macros);
    return _of(item, quantity, FoodScaling.unit(item, d.unitId), d.macros, d.name, d.amount);
  }

  /// [item] at [quantity] of [unit]. Values that differ from the food's own for that amount (the person corrected them)
  /// are kept by storing them on the food's basis, credited as the person's own (as My foods does), never as the source's.
  static MealComponent _of(FoodItem item, double quantity, FoodUnit unit, Map<String, double?> values, String name, String amount) {
    final scaled = FoodScaling.scale(item, quantity, unit);
    final same = FoodItem.nutrientKeys.every((k) => values[k] == scaled[k]);
    final amountOfBasis = quantity * unit.basisPerUnit;
    final kept = same
        ? item
        : FoodItem({
            ...item.j, 'source': 'user', 'sourceId': SyncEngine.newId(),
            'nutrients': {for (final k in FoodItem.nutrientKeys) k: values[k] == null ? null : values[k]! / amountOfBasis},
            if (item.source != 'user') 'basedOn': {'source': item.source, 'sourceId': item.sourceId},
          });
    return MealComponent({'item': slim(kept).j, 'quantity': quantity, 'unit': unit.id, 'name': name.trim(), 'amount': amount.trim()});
  }

  static MealComponent _typed(String name, String amount, Map<String, double?> values) => MealComponent({
        'item': {'source': 'user', 'sourceId': SyncEngine.newId(), 'name': name.trim(), 'basis': FoodItem.perServing, 'nutrients': values,
            'servings': [{'label': amount.trim().isEmpty ? '1 serving' : amount.trim(), 'grams': null, 'milliliters': null}]},
        'quantity': 1, 'unit': 'serving:0', 'name': name.trim(), 'amount': amount.trim(),
      });

  /// A copy of something logged (Save as meal): the food snapshot and amount it was logged with. Values the person
  /// corrected are kept by rebasing them onto the food's basis; a hand-typed entry or a recipe portion becomes a food of its
  /// own with the values it was logged with (a recipe portion's partial sums stay unknown: never a guess).
  static MealComponent fromEntry(FoodEntry e) {
    final source = e.source, quantity = (source?['quantity'] as num?)?.toDouble();
    if (source?['item'] is! Map || quantity == null || quantity <= 0) return _typed(e.name, e.amountDescription, e.macros.map((k, v) => MapEntry(k, (v as num?)?.toDouble())));
    final item = FoodItem(source!['item'] as Json);
    return _of(item, quantity, FoodScaling.unit(item, source['unit'] as String?), {for (final k in FoodItem.nutrientKeys) k: (e.macros[k] as num?)?.toDouble()}, e.name, e.amountDescription);
  }

  /// This food as a draft for the shared amount form (in its selection mode), at its amount and with its values.
  FoodDraft draft({required String dayKey, required String meal}) {
    final v = FoodScaling.scale(item, quantity, unit);
    return FoodDraft(dayKey: dayKey, meal: meal, name: name, amount: amount, item: item, quantity: quantity, unitId: unit.id,
        calories: v['calories'], protein: v['protein'], carbs: v['carbs'], fat: v['fat']);
  }

  /// The food without what a saved definition does not need (its photograph and the provider's long description), so
  /// definitions stay within their size bound. Identity, basis, values, portions and source are all kept.
  static FoodItem slim(FoodItem item) => FoodItem(copyJson(item.j)..remove('imageUrl')..remove('imageAttribution')..remove('description'));
}

/// What a saved meal or recipe is. The wire body of a [SavedMeal], and the state of an editor.
extension type MealBody(Json j) {
  static const meal = 'meal', recipe = 'recipe';
  String get kind => j['kind'] as String? ?? meal;
  bool get isRecipe => kind == recipe;
  String get name => j['name'] as String? ?? '';
  List<MealComponent> get components => [for (final c in j['components'] as List? ?? const []) MealComponent(c as Json)];

  /// A recipe's yield: how many servings the whole batch makes, as the person said.
  double? get servings => (j['servings'] as num?)?.toDouble();

  /// The finished batch's weight, only when the person weighed it. Never the sum of the raw ingredients.
  double? get preparedWeightG => (j['preparedWeightG'] as num?)?.toDouble();

  /// What is known of each nutrient across the whole meal or batch.
  Map<Nutrient, NutrientTotal> get totals => NutrientCoverage.ofParts(components.map((c) => c.values));

  MealBody copyWith({String? name, List<MealComponent>? components, double? servings, double? preparedWeightG, bool clearWeight = false}) => MealBody({
        ...j,
        'name': ?name,
        if (components != null) 'components': [for (final c in components) c.j],
        'servings': ?servings,
        if (clearWeight) 'preparedWeightG': null else 'preparedWeightG': ?preparedWeightG,
      });
}

/// [v] as text that is the same for the same content: keys sorted and numbers as doubles, so the account's copy (its
/// database orders keys its own way and writes 2 for 2.0) compares equal to the one this phone sent.
String canonical(Object? v) => switch (v) {
      final Map m => '{${(m.keys.map((k) => '$k').toList()..sort()).map((k) => '${jsonEncode(k)}:${canonical(m[k])}').join(',')}}',
      final List l => '[${l.map(canonical).join(',')}]',
      final num n => jsonEncode(n.toDouble()),
      _ => jsonEncode(v),
    };

/// Whether two definitions say the same thing (the parts the account keeps).
bool sameMeal(MealBody a, MealBody b) => canonical(SavedMealRepository._wire(a)) == canonical(SavedMealRepository._wire(b));

/// A saved meal or recipe as the account and this phone hold it.
extension type SavedMeal(Json j) {
  String get id => j['id'] as String;
  int get revision => j['revision'] as int? ?? 0;
  bool get isDeleted => j['isDeleted'] as bool? ?? false;
  MealBody get body => MealBody(j['body'] as Json? ?? const {});
}

/// How a recipe portion is measured: servings of the yield, or grams of the finished batch (only when it was weighed).
enum PortionMeasure { serving, gram }

/// Why a saved meal or recipe cannot be saved, or a portion logged; the screens say it in the app's language.
enum MealProblem { noName, nameTooLong, noComponents, tooManyComponents, badQuantity, badServings, badWeight, tooLarge, badMultiplier, badPortion }

class InvalidMeal implements Exception {
  const InvalidMeal(this.problem);
  final MealProblem problem;
  @override
  String toString() => 'InvalidMeal(${problem.name})';
}

/// The arithmetic of saved meals and recipes, in one place for every screen. Values are worked out from the food
/// snapshots, never from rounded display numbers, and rounded only when an entry is written.
abstract final class MealMath {
  static const maxQuantity = 100000.0, maxServings = 1000.0, maxMultiplier = 20.0;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// Every food's amount times [factor] (½×, 2×, a custom multiplier). From the given amounts each time, so
  /// switching back and forth never drifts.
  static List<MealComponent> scaled(List<MealComponent> parts, double factor, String Function(MealComponent c, double q) describe) => [
        for (final c in parts) c.withAmount(c.quantity * factor, c.unitId, describe(c, c.quantity * factor)),
      ];

  /// The share of a recipe's batch one portion is: [amount] servings of its yield, or [amount] grams of its prepared
  /// weight. Null when the measure cannot be used (no yield, or grams without a weighed batch).
  static double? share(MealBody recipe, double amount, PortionMeasure measure) {
    final servings = recipe.servings, weight = recipe.preparedWeightG;
    if (!(amount > 0) || !amount.isFinite) return null;
    return switch (measure) {
      PortionMeasure.serving => servings == null || servings <= 0 ? null : amount / servings,
      PortionMeasure.gram => weight == null || weight <= 0 ? null : amount / weight,
    };
  }

  /// The same portion said in the other measure, through the person's own two numbers: servings ↔ grams of the
  /// weighed batch. Null without a weighed batch: no weight is ever guessed for a serving.
  static double? convert(MealBody recipe, double amount, PortionMeasure from, PortionMeasure to) {
    if (from == to) return amount;
    final s = share(recipe, amount, from);
    if (s == null) return null;
    final servings = recipe.servings, weight = recipe.preparedWeightG;
    if (servings == null || weight == null) return null;
    return to == PortionMeasure.gram ? s * weight : s * servings;
  }

  /// One serving's share of the batch's known values.
  static Map<Nutrient, NutrientTotal> perServing(MealBody recipe) => {for (final e in recipe.totals.entries) e.key: e.value.times(1 / recipe.servings!)};

  /// The entry one portion of [recipe] logs: its values from the frozen batch (complete ones rounded to two decimals like
  /// every entry; a nutrient some ingredient lacks is null, with its known part kept as `partial`), and the whole batch
  /// copied into the entry, so it can be explained and changed later without the recipe.
  static FoodDraft portion(MealBody recipe, {required double amount, required PortionMeasure measure, required String dayKey, required String meal,
      required String amountText, String? recipeId, int? recipeRevision, String? entryId, String? name}) {
    final s = share(recipe, amount, measure);
    if (s == null) throw const InvalidMeal(MealProblem.badPortion);
    final values = <String, double?>{}, partial = <String, double>{};
    for (final e in recipe.totals.entries) {
      final known = _round2(e.value.knownTotal * s);
      values[e.key.name] = e.value.isComplete ? known : null;
      if (!e.value.isComplete && e.value.hasAnyKnown) partial[e.key.name] = known;
    }
    return FoodDraft(
      id: entryId, dayKey: dayKey, meal: meal, name: (name ?? recipe.name).trim(), amount: amountText,
      calories: values['calories'], protein: values['protein'], carbs: values['carbs'], fat: values['fat'],
      recipe: {
        'recipe': {...copyJson(recipe.j), 'kind': MealBody.recipe, 'id': ?recipeId, 'revision': ?recipeRevision},
        'portion': {'quantity': amount, 'unit': measure == PortionMeasure.gram ? 'g' : 'serving'},
        if (partial.isNotEmpty) 'partial': partial,
      },
    );
  }

  /// The recipe and portion a logged recipe entry was made from, to change that entry from its own snapshot.
  static ({MealBody recipe, double amount, PortionMeasure measure, String? recipeId, int? revision})? ofEntry(FoodEntry e) {
    if (!e.isRecipePortion) return null;
    final s = e.source!, r = s['recipe'] as Json, p = s['portion'] as Json? ?? const {};
    return (
      recipe: MealBody(r), amount: (p['quantity'] as num?)?.toDouble() ?? 1, measure: p['unit'] == 'g' ? PortionMeasure.gram : PortionMeasure.serving,
      recipeId: r['id'] as String?, revision: r['revision'] as int?,
    );
  }

  /// One ordinary entry per food of a meal, for the day and meal chosen. Each keeps its own food snapshot and amount.
  static List<FoodDraft> mealEntries(List<MealComponent> parts, {required String dayKey, required String meal}) =>
      [for (final c in parts) c.draft(dayKey: dayKey, meal: meal)];

  /// A count as people read it in an amount: "1", "1.5".
  static String count(double v) => formatNumber2(v);
}

/// Saved meals and recipes through the same local-first outbox as everything else. Nothing here logs food.
class SavedMealRepository {
  SavedMealRepository(this._sync, this._owner);
  final SyncEngine _sync;
  final String _owner;

  static const capability = 'food.saved-meals', maxComponents = 30;

  /// Saved meals, atomic meal logs and recipe portions wait until the account's server declares them (unknown waits
  /// too): an older server never receives a command it cannot take. Nothing else is held.
  static bool serverTakes(Cmd cmd, Set<String>? capabilities) =>
      !(cmd.kind.startsWith('savedmeal.') || cmd.kind == 'food.batch' || cmd.kind.startsWith('food.recipe.')) || (capabilities?.contains(capability) ?? false);

  /// The rules the account applies too.
  static void validate(MealBody b) {
    final name = b.name.trim();
    if (name.isEmpty) throw const InvalidMeal(MealProblem.noName);
    if (name.length > 120) throw const InvalidMeal(MealProblem.nameTooLong);
    final parts = b.components;
    if (parts.isEmpty) throw const InvalidMeal(MealProblem.noComponents);
    if (parts.length > maxComponents) throw const InvalidMeal(MealProblem.tooManyComponents);
    for (final c in parts) {
      if (!c.quantity.isFinite || c.quantity <= 0 || c.quantity > MealMath.maxQuantity) throw const InvalidMeal(MealProblem.badQuantity);
    }
    if (b.isRecipe) {
      final s = b.servings, w = b.preparedWeightG;
      if (s == null || !s.isFinite || s <= 0 || s > MealMath.maxServings) throw const InvalidMeal(MealProblem.badServings);
      if (w != null && (!w.isFinite || w <= 0 || w > MealMath.maxQuantity)) throw const InvalidMeal(MealProblem.badWeight);
    }
    if (jsonEncode(b.j).length > FoodRepository.compositeSnapshotLimit) throw const InvalidMeal(MealProblem.tooLarge);
  }

  static Json _wire(MealBody b) => {
        'kind': b.kind, 'name': b.name.trim(), 'components': [for (final c in b.components) c.j],
        if (b.isRecipe) ...{'servings': b.servings, 'preparedWeightG': b.preparedWeightG},
      };

  /// Saves [body] as the definition [id] (a new one when null: Save as new). Returns its ID.
  Future<String> put(MealBody body, {String? id}) async {
    validate(body);
    final key = id ?? SyncEngine.newId();
    final wire = _wire(body);
    await _sync.submit(_owner, kind: 'savedmeal.put', method: 'PUT', path: '/saved-meals/$key', targetKind: Kinds.savedMeal, targetId: key,
        writes: [LocalWrite(Kinds.savedMeal, key, {'id': key, 'body': wire, 'isDeleted': false})],
        // A definition the account has never confirmed has revision 0, which is what creating one expects.
        payload: {'expectedRevision': {r'$rev': [Kinds.savedMeal, key]}, 'body': wire});
    return key;
  }

  /// Removes it from future use. Everything logged from it stays exactly as it was.
  Future<Receipt> remove(SavedMeal m) => _sync.submit(_owner, kind: 'savedmeal.delete', path: '/saved-meals/${m.id}/delete', targetKind: Kinds.savedMeal, targetId: m.id,
      writes: [LocalWrite(Kinds.savedMeal, m.id, copyJson(m.j)..['isDeleted'] = true)], payload: {'expectedRevision': {r'$rev': [Kinds.savedMeal, m.id]}});

  // ---------------------------------------------------------------- unfinished editors (this phone, this account)

  /// The key an editor's draft is kept under: the definition's ID, or `new:meal` / `new:recipe`.
  static String draftKey(String? id, String kind) => id ?? 'new:$kind';

  /// Keeps an editor's state, with the definition as it was when the editing started ([base]). Local only.
  Future<void> keepDraft(String key, MealBody body, {MealBody? base}) =>
      _sync.putLocal(_owner, LocalWrite(Kinds.mealDraft, key, {'body': body.j, 'base': base?.j}));

  Future<({MealBody body, MealBody? base})?> draft(String key) async {
    final r = await _sync.get(_owner, Kinds.mealDraft, key);
    if (r == null) return null;
    final j = jsonDecode(r.body) as Json;
    return (body: MealBody(j['body'] as Json), base: j['base'] is Map ? MealBody(j['base'] as Json) : null);
  }

  Future<void> dropDraft(String key) => _sync.deleteLocal(_owner, Kinds.mealDraft, key);
}
