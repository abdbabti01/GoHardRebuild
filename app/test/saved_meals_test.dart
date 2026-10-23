import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/db.dart' show Cmd;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';

import 'support.dart';

/// Saved meals and recipes (docs/FOOD_DATA.md › Saved meals and recipes): the arithmetic, the coverage rules, and the
/// local-first storage and logging on the real database against the fake authority.

FoodItem egg() => FoodItem({'source': 'usda', 'sourceId': 'egg', 'name': 'Egg', 'basis': FoodItem.per100g,
    'nutrients': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5}, 'servings': [{'label': '1 egg', 'grams': 50, 'milliliters': null}]});
FoodItem oats() => FoodItem({'source': 'usda', 'sourceId': 'oats', 'name': 'Oats', 'basis': FoodItem.per100g,
    'nutrients': {'calories': 379, 'protein': 13.2, 'carbs': 67.7, 'fat': 0}, 'servings': const []});
/// A food whose calories nobody knows.
FoodItem spice() => FoodItem({'source': 'user', 'sourceId': 'spice', 'name': 'Spice mix', 'basis': FoodItem.per100g,
    'nutrients': {'calories': null, 'protein': null, 'carbs': null, 'fat': 0}, 'servings': const []});

MealComponent part(FoodItem item, double q, String unit) => MealComponent({'item': item.j, 'quantity': q, 'unit': unit, 'amount': FoodScaling.describe(item, q, FoodScaling.unit(item, unit))});
MealBody breakfast() => MealBody({'kind': 'meal', 'name': 'Breakfast', 'components': [part(egg(), 2, 'serving:0').j, part(oats(), 60, 'g').j]});
MealBody chili({double servings = 4, double? weight}) => MealBody({'kind': 'recipe', 'name': 'Chili', 'servings': servings, 'preparedWeightG': weight,
    'components': [part(oats(), 100, 'g').j, part(spice(), 10, 'g').j]}); // 379 kcal known + unknown spice calories
String said(MealComponent c, double q) => FoodScaling.describe(c.item, q, c.unit);

void main() {
  group('arithmetic and coverage', () {
    test('a meal scales from its saved amounts, without drift, and one food can be changed alone', () {
      final saved = breakfast().components;
      final half = MealMath.scaled(saved, 0.5, said);
      expect([for (final c in half) (c.quantity, c.amount)], [(1, '1 egg (50 g)'), (30, '30 g')]);
      // Each multiplier works from the saved amounts, never from the last one shown, so 1½× then 1× is exact again.
      expect([for (final c in MealMath.scaled(saved, 1.5, said)) c.quantity], [3, 90]);
      expect([for (final c in MealMath.scaled(saved, 1, said)) c.quantity], [2, 60]);
      expect([for (final c in MealMath.scaled(saved, 1 / 3, said)) c.quantity * 3], [closeTo(2, 1e-12), closeTo(60, 1e-12)]);
      // Today: 3 eggs and 40 g of oats. The values follow those amounts; the saved meal does not move.
      final today = [saved[0].withAmount(3, 'serving:0', '3 eggs'), saved[1].withAmount(40, 'g', '40 g')];
      final t = NutrientCoverage.ofParts(today.map((c) => c.values));
      expect(t[Nutrient.calories]!.knownTotal, closeTo(143 * 1.5 + 379 * 0.4, 1e-9));
      expect([for (final c in breakfast().components) c.quantity], [2, 60]);
    });

    test('a unit change converts the amount: one 50 g egg is 50 g, never 1 g', () {
      final c = part(egg(), 1, 'serving:0');
      expect(FoodScaling.exact(1, c.unit, FoodScaling.unit(c.item, 'g')), 50);
      expect(part(egg(), 50, 'g').values['calories'], c.values['calories']);
    });

    test('a recipe divides its batch by the yield the person gave; grams only through a weighed batch', () {
      final r = chili();
      expect(MealMath.share(r, 1, PortionMeasure.serving), 0.25);
      expect(MealMath.share(r, 1.5, PortionMeasure.serving), 1.5 / 4);
      expect(MealMath.share(r, 300, PortionMeasure.gram), isNull, reason: 'no weighed batch: no grams, and no guess from the raw weights');
      expect(MealMath.convert(r, 1, PortionMeasure.serving, PortionMeasure.gram), isNull);
      final weighed = chili(weight: 1200);
      expect(MealMath.share(weighed, 300, PortionMeasure.gram), 0.25);
      expect(MealMath.convert(weighed, 1, PortionMeasure.serving, PortionMeasure.gram), 300);
      expect(MealMath.convert(weighed, 450, PortionMeasure.gram, PortionMeasure.serving), 1.5);
      // A bigger yield makes each serving smaller; the ingredients stay as they are.
      final eight = chili(servings: 8);
      expect(MealMath.perServing(eight)[Nutrient.protein]!.knownTotal, closeTo(13.2 / 8, 1e-9));
      expect(eight.components.first.quantity, 100);
    });

    test('400 known kcal plus an unknown never reads as a complete total, through the portion and the day', () {
      final batch = chili().totals;
      expect((batch[Nutrient.calories]!.knownTotal, batch[Nutrient.calories]!.isComplete, batch[Nutrient.calories]!.hasAnyKnown), (379, false, true));
      expect((batch[Nutrient.fat]!.knownTotal, batch[Nutrient.fat]!.isComplete), (0, true), reason: 'a stated zero is a known zero');

      final d = MealMath.portion(chili(), amount: 1, measure: PortionMeasure.serving, dayKey: '2026-10-09', meal: 'Dinner', amountText: '1 serving');
      // An app that reads only the values sees "unknown", never 94.75 as if complete.
      expect((d.calories, d.fat, d.protein), (null, 0, null));
      expect(d.recipe!['partial'], {'calories': 94.75, 'protein': 3.3, 'carbs': 16.93});
      expect(FoodRepository.sourceFields(d)['provenance'], {'calories': 'unknown', 'protein': 'unknown', 'carbs': 'unknown', 'fat': 'imported'});

      // In the day: the known part counts, and the day's calories stay "known so far".
      final entry = FoodEntry({'id': 'a', 'dayKey': '2026-10-09', 'meal': 'Dinner', 'name': 'Chili', 'amountDescription': '1 serving', 'macros': d.macros, 'source': d.recipe});
      final plain = FoodEntry({'id': 'b', 'dayKey': '2026-10-09', 'meal': 'Lunch', 'name': 'Apple', 'amountDescription': '1', 'macros': {'calories': 95, 'protein': 0.5, 'carbs': 25, 'fat': 0.3}});
      final day = NutrientCoverage.calculate([entry, plain])[Nutrient.calories]!;
      expect((day.knownTotal, day.isComplete, day.hasAnyKnown, day.knownEntries, day.unknownEntries), (94.75 + 95, false, true, 1, 1));
      expect(NutrientCoverage.calculate([plain])[Nutrient.calories]!.isComplete, isTrue);
    });

    test('Save as meal copies what was logged: snapshots, amounts and corrected values', () {
      final corrected = FoodEntry({'id': 'x', 'dayKey': '2026-10-09', 'meal': 'Lunch', 'name': 'Egg', 'amountDescription': '2 eggs', 'macros': {'calories': 150, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5},
          'source': {'item': egg().j, 'quantity': 2, 'unit': 'serving:0'}});
      final typed = FoodEntry({'id': 'y', 'dayKey': '2026-10-09', 'meal': 'Lunch', 'name': 'Soup', 'amountDescription': '1 bowl', 'macros': {'calories': null, 'protein': 5, 'carbs': null, 'fat': null}});
      final a = MealComponent.fromEntry(corrected), b = MealComponent.fromEntry(typed);
      expect((a.quantity, a.unitId, a.item.source), (2, 'serving:0', 'user'), reason: 'a corrected value is the person\'s, not the provider\'s');
      expect(a.values['calories'], closeTo(150, 1e-9));
      expect((b.quantity, b.amount, b.values['calories'], b.values['protein']), (1, '1 bowl', null, 5));
    });

    test('a definition the account echoes back with its keys reordered and 2 written for 2.0 is the same definition', () {
      final mine = breakfast();
      final echoed = MealBody(jsonDecode(jsonEncode({'components': [for (final c in mine.components) {...c.j, 'quantity': c.quantity.round()}], 'name': 'Breakfast', 'kind': 'meal'})) as Json);
      expect(sameMeal(mine, echoed), isTrue, reason: 'our own acknowledged save is not a change from another phone');
      expect(sameMeal(mine, mine.copyWith(name: 'Theirs')), isFalse);
    });

    test('limits and invalid input are refused with a reason', () {
      MealProblem? problem(MealBody b) {
        try {
          SavedMealRepository.validate(b);
          return null;
        } on InvalidMeal catch (e) {
          return e.problem;
        }
      }
      expect(problem(breakfast()), isNull);
      expect(problem(breakfast().copyWith(name: ' ')), MealProblem.noName);
      expect(problem(breakfast().copyWith(components: [])), MealProblem.noComponents);
      expect(problem(breakfast().copyWith(components: [part(egg(), 0, 'g')])), MealProblem.badQuantity);
      expect(problem(breakfast().copyWith(components: [part(egg(), double.nan, 'g')])), MealProblem.badQuantity);
      expect(problem(breakfast().copyWith(components: [for (var i = 0; i < 31; i++) part(egg(), 1, 'g')])), MealProblem.tooManyComponents);
      expect(problem(chili(servings: 0)), MealProblem.badServings);
      expect(problem(chili(weight: -1)), MealProblem.badWeight);
      expect(() => MealMath.portion(chili(), amount: 0, measure: PortionMeasure.serving, dayKey: 'd', meal: 'Dinner', amountText: ''), throwsA(isA<InvalidMeal>()));
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
    SavedMealRepository saved() => SavedMealRepository(h.sync, owner);
    Future<List<FoodEntry>> food() async => [for (final j in await h.bodies(owner, Kinds.food)) FoodEntry(j)];
    List<FoodDraft> drafts(String day) => MealMath.mealEntries(breakfast().components, dayKey: day, meal: 'Breakfast');

    test('saving, updating, saving as new and drafts log nothing; logging changes no definition', () async {
      final id = await saved().put(breakfast());
      await saved().keepDraft('new:x', breakfast().copyWith(name: 'Draft'));
      await h.sync.flush();
      expect(await food(), isEmpty);
      expect(h.server.food, isEmpty);

      await saved().put(breakfast().copyWith(components: [part(egg(), 3, 'serving:0')]), id: id); // Update saved meal
      final copy = await saved().put(breakfast().copyWith(name: 'Big breakfast')); // Save as new
      await h.sync.flush();
      expect((h.server.savedMeals[id]!['revision'], (h.server.savedMeals[id]!['body'] as Json)['components'].length, h.server.savedMeals.length), (2, 1, 2));
      expect(h.server.savedMeals[copy]!['body']['name'], 'Big breakfast');

      await journal().logMeal(drafts('2026-10-09'), operationId: 'op-1');
      await h.sync.flush();
      expect(h.server.savedMeals[id]!['revision'], 2, reason: 'logging never touches the template');
      expect(await food(), hasLength(2));
    });

    test('a meal is logged as one operation: atomic locally, one command, rapid taps and a lost answer add nothing', () async {
      final bad = drafts('2026-10-09')..last.calories = -5;
      await expectLater(journal().logMeal(bad, operationId: 'op-bad'), throwsA(isA<InvalidFood>()));
      expect(await food(), isEmpty, reason: 'one invalid food saves none of the meal');
      expect(await h.sync.commands(owner), isEmpty);

      // The account records the first attempt but its answer is lost on the way back.
      h.server.loseNextResponse = true;
      await Future.wait([journal().logMeal(drafts('2026-10-09'), operationId: 'op-1'), journal().logMeal(drafts('2026-10-09'), operationId: 'op-1')]);
      await journal().logMeal(drafts('2026-10-09'), operationId: 'op-1');
      expect((await food()).length, 2, reason: 'one review is one meal, however often Log is tapped');
      expect((await h.sync.commands(owner, states: const ['pending', 'accepted'])).single.kind, 'food.batch');

      await h.sync.flush(); // the same operation again: replayed, nothing recorded twice
      expect(h.server.food, hasLength(2));
      final sent = h.server.callsTo('/food-entries/batch');
      expect(sent, hasLength(2), reason: 'the lost answer, then the replay');
      expect(sent[0].body, sent[1].body, reason: 'the retry is the same bytes');
      expect((await h.sync.commands(owner, states: const ['accepted'])).single.operationId, 'op-1');
      expect([for (final r in await h.sync.list(owner, Kinds.food)) r.syncState], ['synced', 'synced']);
      final logged = await food();
      expect([for (final e in logged) (e.name, e.amountDescription, e.meal, e.calories)], [('Egg', '2 eggs (100 g)', 'Breakfast', 143), ('Oats', '60 g', 'Breakfast', 227.4)]);
    });

    test('offline, a meal and a recipe portion keep their past day across a restart and reach the account once', () async {
      h.server.offline = true;
      await journal().logMeal(drafts('2026-10-07'), operationId: 'op-meal');
      await journal().save(MealMath.portion(chili(), amount: 1.5, measure: PortionMeasure.serving, dayKey: '2026-10-07', meal: 'Dinner', amountText: '1.5 servings', recipeId: 'r1', recipeRevision: 1),
          operationId: 'op-portion');
      await h.restart();
      expect([for (final e in await food()) e.dayKey], everyElement('2026-10-07'));
      h.server.offline = false;
      await h.sync.flush();
      await h.sync.flush();
      expect([for (final f in h.server.food.values) f['dayKey']], ['2026-10-07', '2026-10-07', '2026-10-07']);
      await h.sync.pull();
      expect(await food(), hasLength(3), reason: 'reconciled without duplicates');
    });

    test('a server without saved meals receives none of these commands; the account isolates definitions and drafts', () async {
      Set<String>? caps = {'food.saved'};
      h.sync.mayDispatch = (Cmd c) => SavedMealRepository.serverTakes(c, caps);
      await saved().put(breakfast());
      await journal().logMeal(drafts('2026-10-09'), operationId: 'op-1');
      await journal().save(FoodDraft(dayKey: '2026-10-09', meal: 'Snack', name: 'Apple', amount: '1', calories: 95));
      await h.sync.flush();
      expect(h.server.callsTo('/saved-meals'), isEmpty);
      expect(h.server.callsTo('/food-entries/batch'), isEmpty);
      expect(h.server.food.length, 1, reason: 'the ordinary entry still goes');
      caps = null;
      await h.sync.flush();
      expect(h.server.callsTo('/saved-meals'), isEmpty, reason: 'unknown waits too');
      caps = {'food.saved', SavedMealRepository.capability};
      await h.sync.flush();
      expect((h.server.savedMeals.length, h.server.food.length), (1, 3));

      await saved().keepDraft('new:x', breakfast());
      final other = await h.signIn('two');
      expect(await SavedMealRepository(h.sync, other).draft('new:x'), isNull);
      expect(await h.sync.list(other, Kinds.savedMeal), isEmpty);
    });

    test('editing or deleting a recipe never changes a logged portion; changing the portion uses its own snapshot', () async {
      final id = await saved().put(chili());
      final d = MealMath.portion(chili(), amount: 1, measure: PortionMeasure.serving, dayKey: '2026-10-09', meal: 'Dinner', amountText: '1 serving', recipeId: id, recipeRevision: 1);
      await journal().save(d, operationId: 'op-1');
      await h.sync.flush();
      final before = jsonEncode((await h.bodies(owner, Kinds.food)).single);

      await saved().put(chili(servings: 10).copyWith(name: 'Chili v2'), id: id);
      await h.sync.flush();
      await saved().remove(SavedMeal((await h.bodies(owner, Kinds.savedMeal)).single));
      await h.sync.flush();
      await h.sync.pull();
      expect(jsonEncode((await h.bodies(owner, Kinds.food)).single), before);
      expect(SavedMeal((await h.bodies(owner, Kinds.savedMeal)).single).isDeleted, isTrue);

      // Two servings now, from the frozen 4-serving batch, not the recipe's later 10.
      final e = (await food()).single;
      final from = MealMath.ofEntry(e)!;
      expect((from.recipe.servings, from.amount, from.recipeId), (4, 1, id));
      await journal().save(MealMath.portion(from.recipe, amount: 2, measure: from.measure, dayKey: e.dayKey, meal: e.meal, amountText: '2 servings', entryId: e.id, recipeId: from.recipeId, recipeRevision: from.revision));
      await h.sync.flush();
      final changed = (await food()).single;
      expect((changed.partial('calories'), h.server.food[e.id]!['amountDescription']), (189.5, '2 servings'));
    });

    test('a definition changed on another phone is a conflict held for review, never overwritten', () async {
      final id = await saved().put(breakfast());
      await h.sync.flush();
      h.server.savedMeals[id] = {...h.server.savedMeals[id]!, 'revision': 2, 'body': breakfast().copyWith(name: 'Theirs').j};
      await saved().put(breakfast().copyWith(name: 'Mine'), id: id);
      await h.sync.flush();
      final rec = (await h.sync.get(owner, Kinds.savedMeal, id))!;
      expect((rec.syncState, SavedMeal(jsonDecode(rec.body) as Json).body.name, (jsonDecode(rec.serverBody!) as Json)['body']['name']), ('conflict', 'Mine', 'Theirs'));
    });
  });
}
