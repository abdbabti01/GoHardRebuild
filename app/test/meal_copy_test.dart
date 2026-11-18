import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/nutrition/meal_copy.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/features/plus/entitlement.dart' show CreateGate;

import 'support.dart';

/// Repeating and copying a logged meal (docs/MEAL_COPY_WORKOUT_PANEL.md): which meal is the source, exact copies of
/// the logged snapshots, and logging them once through the real local database and the fake account.

FoodItem egg() => FoodItem({'source': 'usda', 'sourceId': 'egg', 'name': 'Egg', 'basis': FoodItem.per100g, 'attribution': 'USDA FoodData Central',
    'nutrients': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5}, 'servings': [{'label': '1 egg', 'grams': 50, 'milliliters': null}]});
FoodItem oats() => FoodItem({'source': 'usda', 'sourceId': 'oats', 'name': 'Oats', 'basis': FoodItem.per100g,
    'nutrients': {'calories': 379, 'protein': 13.2, 'carbs': 67.7, 'fat': 0}, 'servings': const []});
FoodItem spice() => FoodItem({'source': 'user', 'sourceId': 'spice', 'name': 'Spice mix', 'basis': FoodItem.per100g,
    'nutrients': {'calories': null, 'protein': null, 'carbs': null, 'fat': 0}, 'servings': const []});
MealComponent part(FoodItem item, double q, String unit) => MealComponent({'item': item.j, 'quantity': q, 'unit': unit, 'amount': FoodScaling.describe(item, q, FoodScaling.unit(item, unit))});

/// 379 kcal known + a spice nobody knows the calories of; 4 servings, weighed at 800 g.
MealBody chili() => MealBody({'kind': 'recipe', 'name': 'Chili', 'servings': 4, 'preparedWeightG': 800, 'components': [part(oats(), 100, 'g').j, part(spice(), 10, 'g').j]});

FoodDraft eggs(String day, String meal, double n) {
  final u = FoodScaling.unit(egg(), 'serving:0'), v = FoodScaling.scale(egg(), n, u);
  return FoodDraft(dayKey: day, meal: meal, name: 'Egg', amount: FoodScaling.describe(egg(), n, u), item: egg(), quantity: n, unitId: u.id,
      calories: v['calories'], protein: v['protein'], carbs: v['carbs'], fat: v['fat']);
}

FoodEntry entry(String id, String day, String meal, {bool deleted = false}) => FoodEntry({'id': id, 'dayKey': day, 'meal': meal, 'name': id, 'amountDescription': '1', 'macros': const {}, 'isDeleted': deleted});

void main() {
  group('the source', () {
    final journal = [
      entry('b1', '2026-11-16', 'Breakfast'), entry('l1', '2026-11-16', 'Lunch'), entry('b2', '2026-11-16', 'Breakfast'),
      entry('gone', '2026-11-16', 'Breakfast', deleted: true), entry('b0', '2026-11-15', 'Breakfast'), entry('old', '2026-10-01', 'Breakfast'),
      entry('today', '2026-11-18', 'Breakfast'),
    ];

    test('yesterday is the day before the day shown; one meal of that one day, in logged order, never a deleted entry', () {
      expect(dayBefore('2026-11-17'), '2026-11-16', reason: 'the day shown in Eat, not the phone’s');
      expect(dayBefore('2026-03-01'), '2026-02-28');
      expect([for (final e in mealOn(journal, dayBefore('2026-11-17'), 'Breakfast')) e.id], ['b1', 'b2']);
      expect(mealOn(journal, dayBefore('2026-11-16'), 'Lunch'), isEmpty, reason: 'nothing there: the ordinary empty meal');
    });

    test('other days: each day’s meal on its own, newest first, the last 14 days only', () {
      final s = mealSources(journal, before: '2026-11-18', meal: 'Breakfast');
      expect([for (final d in s) '${d.day}: ${[for (final e in d.entries) e.id].join(', ')}'], ['2026-11-16: b1, b2', '2026-11-15: b0']);
    });

    test('Copy meal starts on today: the same meal from an earlier day, the meal of the time of day from today', () {
      expect(copyDestination(sourceDay: '2026-11-16', sourceMeal: 'Lunch', today: '2026-11-18', mealNow: 'Dinner'), (day: '2026-11-18', meal: 'Lunch'));
      expect(copyDestination(sourceDay: '2026-11-18', sourceMeal: 'Breakfast', today: '2026-11-18', mealNow: 'Lunch'), (day: '2026-11-18', meal: 'Lunch'));
    });
  });

  group('exact copies', () {
    test('an unchanged copy is written as logged: values, food identity, unit, attribution and provenance, even a unit the food no longer lists', () {
      // An older snapshot: its unit is not among the food's units today (scaling would fall back to another), and the
      // person corrected the calories (entered) while the rest came from the food (imported).
      final logged = FoodEntry({
        'id': 'e1', 'dayKey': '2026-11-16', 'meal': 'Breakfast', 'name': 'Egg', 'amountDescription': '2 large eggs', 'isDeleted': false,
        'macros': {'calories': 150, 'protein': 12.6, 'carbs': null, 'fat': 9.5},
        'provenance': {'calories': 'entered', 'protein': 'imported', 'carbs': 'unknown', 'fat': 'imported'},
        'source': {'item': egg().j, 'quantity': 2, 'unit': 'serving:large'},
      });
      final d = FoodDraft.copy(logged, dayKey: '2026-11-18', meal: 'Lunch');
      expect((d.id, d.dayKey, d.meal, d.name, d.amount), (null, '2026-11-18', 'Lunch', 'Egg', '2 large eggs'));
      expect(d.macros, {'calories': 150, 'protein': 12.6, 'carbs': null, 'fat': 9.5}, reason: 'unknown stays unknown, nothing rounded or looked up');
      expect(jsonEncode(FoodRepository.sourceFields(d)), jsonEncode({'source': logged.source, 'provenance': logged.j['provenance']}));
      expect(copyChange(d), CopyChange.amount);
    });

    test('a recipe portion keeps its frozen batch and partial sums; a typed entry and one without a quantity cannot be scaled', () {
      final portion = MealMath.portion(chili(), amount: 1, measure: PortionMeasure.serving, dayKey: '2026-11-16', meal: 'Dinner', amountText: '1 serving', recipeId: 'r1', recipeRevision: 3);
      final logged = FoodEntry({'id': 'p', 'dayKey': '2026-11-16', 'meal': 'Dinner', 'name': 'Chili', 'amountDescription': '1 serving', 'macros': portion.macros, 'isDeleted': false,
          ...FoodRepository.sourceFields(portion)});
      final d = FoodDraft.copy(logged, dayKey: '2026-11-18', meal: 'Dinner');
      expect(copyChange(d), CopyChange.portion);
      expect(d.calories, isNull, reason: 'a spice without calories: unknown, never a guess');
      expect(previewEntry(d).partial('calories'), 94.75, reason: 'its known part is kept, labelled');
      expect(NutrientCoverage.calculate([previewEntry(d)])[Nutrient.calories]!.isComplete, isFalse);
      expect(jsonEncode(FoodRepository.sourceFields(d)['source']), jsonEncode(logged.source));

      // Two servings from the batch frozen into the entry (4 servings, 800 g), whatever the recipe says now.
      final frozen = MealBody((d.recipe!['recipe'] as Json));
      final two = MealMath.portion(frozen, amount: 400, measure: PortionMeasure.gram, dayKey: '2026-11-18', meal: 'Dinner', amountText: '400 g', recipeId: 'r1', recipeRevision: 3);
      expect((two.calories, two.recipe!['partial']['calories'], two.recipe!['recipe']['servings'], two.recipe!['recipe']['revision']), (null, 189.5, 4, 3));

      final typed = FoodDraft.copy(FoodEntry({'id': 't', 'dayKey': '2026-11-16', 'meal': 'Snack', 'name': 'Coffee', 'amountDescription': '1 cup', 'macros': {'calories': 5}, 'isDeleted': false}),
          dayKey: '2026-11-18', meal: 'Snack');
      expect((copyChange(typed), typed.calories), (CopyChange.none, 5));
      expect(FoodRepository.sourceFields(typed), isEmpty, reason: 'typed by hand: no snapshot to invent');

      final noQuantity = FoodDraft.copy(FoodEntry({'id': 'q', 'dayKey': '2026-11-16', 'meal': 'Snack', 'name': 'Egg', 'amountDescription': 'some', 'macros': {'calories': 70},
          'isDeleted': false, 'source': {'item': egg().j}}), dayKey: '2026-11-18', meal: 'Snack');
      expect(copyChange(noQuantity), CopyChange.none, reason: 'nothing to scale from');
      expect(FoodRepository.sourceFields(noQuantity)['source'], {'item': egg().j}, reason: 'its snapshot is still copied as it was');
      FoodRepository.validate(noQuantity); // and it can be logged as it is
    });
  });

  group('on the real database', () {
    late Harness h;
    late String owner;
    setUp(() async {
      h = Harness();
      owner = await h.signIn('one');
    });
    tearDown(() => h.dispose());

    FoodRepository journal() => FoodRepository(h.sync, owner);
    Future<List<Json>> food() => h.bodies(owner, Kinds.food);
    Future<List<FoodEntry>> meal(String day, String m) async => mealOn([for (final j in await food()) FoodEntry(j)], day, m);

    test('logged once per review with fresh IDs; the source and the destination’s own food untouched; another review copies again; no saved meal', () async {
      await journal().logMeal([eggs('2026-11-16', 'Breakfast', 2), FoodDraft(dayKey: '2026-11-16', meal: 'Breakfast', name: 'Baguette', amount: '1 slice', calories: 80)], operationId: 'src');
      await journal().save(FoodDraft(dayKey: '2026-11-17', meal: 'Breakfast', name: 'Apple', amount: '1', calories: 95));
      await h.sync.flush();
      final source = await meal('2026-11-16', 'Breakfast');
      final before = jsonEncode([for (final e in source) e.j]);

      // Saved meals are at this account's limit: copying is logging, so the limit is never asked.
      final saved = SavedMealRepository(h.sync, owner, mayCreate: () => (CreateGate.limit, 1));
      await expectLater(saved.put(MealBody({'kind': 'meal', 'name': 'x', 'components': [part(egg(), 1, 'serving:0').j]})), throwsA(isA<MealLimitReached>()));

      List<FoodDraft> copies() => placed([for (final e in source) FoodDraft.copy(e, dayKey: '2026-11-17', meal: 'Breakfast')], day: '2026-11-17', meal: 'Breakfast');
      h.server.loseNextResponse = true; // the account records it, the answer is lost
      await Future.wait([journal().logMeal(copies(), operationId: 'review-1'), journal().logMeal(copies(), operationId: 'review-1')]); // a double tap
      await h.sync.flush();
      await h.sync.flush();
      final there = await meal('2026-11-17', 'Breakfast');
      expect([for (final e in there) e.name], ['Apple', 'Egg', 'Baguette'], reason: 'added after what was there, in the source order, once');
      expect(h.server.food, hasLength(5));
      expect({for (final e in there) e.id}.intersection({for (final e in source) e.id}), isEmpty, reason: 'fresh entry IDs');
      expect(jsonEncode(there[1].source), jsonEncode(source[0].source), reason: 'the same food snapshot and amount');
      expect(jsonEncode([for (final e in await meal('2026-11-16', 'Breakfast')) e.j]), before, reason: 'the source day is never written');

      await journal().logMeal(copies(), operationId: 'review-2'); // eaten again, on purpose: a new review
      await h.sync.flush();
      expect(await meal('2026-11-17', 'Breakfast'), hasLength(5));
      expect(h.server.food, hasLength(7));
      expect(await h.bodies(owner, Kinds.savedMeal), isEmpty, reason: 'no saved meal made or used');
      expect(h.server.savedMeals, isEmpty);
      expect([for (final c in await h.sync.commands(owner, states: const ['pending', 'accepted'])) c.kind].where((k) => k.startsWith('savedmeal')), isEmpty);
    });

    test('offline: one changed amount, a portion from the frozen batch and a typed food survive a restart and reach the account once', () async {
      final recipe = MealMath.portion(chili(), amount: 1, measure: PortionMeasure.serving, dayKey: '2026-11-16', meal: 'Dinner', amountText: '1 serving', recipeId: 'r1', recipeRevision: 1);
      await journal().logMeal([eggs('2026-11-16', 'Dinner', 2), recipe, FoodDraft(dayKey: '2026-11-16', meal: 'Dinner', name: 'Tea', amount: '1 cup', calories: 2)], operationId: 'src');
      await h.sync.flush();
      final source = await meal('2026-11-16', 'Dinner');

      final drafts = [for (final e in source) FoodDraft.copy(e, dayKey: '2026-11-17', meal: 'Lunch')];
      drafts[0] = eggs('2026-11-17', 'Lunch', 3); // the amount form's answer for this time only
      final r = drafts[1].recipe!;
      drafts[1] = MealMath.portion(MealBody(r['recipe'] as Json), amount: 2, measure: PortionMeasure.serving, dayKey: '2026-11-17', meal: 'Lunch', amountText: '2 servings',
          recipeId: 'r1', recipeRevision: 1, name: drafts[1].name);

      h.server.offline = true;
      await journal().logMeal(placed(drafts, day: '2026-11-17', meal: 'Lunch'), operationId: 'copy');
      await h.restart();
      expect([for (final e in await meal('2026-11-17', 'Lunch')) e.amountDescription], ['3 eggs (150 g)', '2 servings', '1 cup']);
      h.server.offline = false;
      await h.sync.flush();
      await h.sync.flush();
      expect(h.server.food, hasLength(6), reason: 'the copy reached the account once');
      await h.sync.pull();
      final copied = await meal('2026-11-17', 'Lunch');
      expect(copied, hasLength(3), reason: 'reconciled without duplicates');
      expect((copied[0].calories, copied[1].calories, copied[1].partial('calories'), copied[2].calories), (214.5, null, 189.5, 2));
      expect([for (final e in await meal('2026-11-16', 'Dinner')) e.amountDescription], ['2 eggs (100 g)', '1 serving', '1 cup'], reason: 'the original keeps its amounts');
    });
  });
}
