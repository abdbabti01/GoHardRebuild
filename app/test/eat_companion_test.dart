import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show addDays;
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/day_coach.dart';
import 'package:gohard_rebuild/features/coach/meal_ideas.dart';
import 'package:gohard_rebuild/features/nutrition/eat_briefing.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_search.dart';
import 'package:gohard_rebuild/features/nutrition/meal_habits.dart';
import 'package:gohard_rebuild/l10n/app_localizations.dart' show lookupAppLocalizations;

/// Eat's briefing and meal ideas (docs/EAT_COMPANION.md): what is said from which records, and how a model's idea
/// becomes values only through real food records.

final l = lookupAppLocalizations(const Locale('en'));
const today = '2026-10-30';

var _n = 0;
FoodEntry e(String meal, {double? kcal, double? protein, double? fat = 1, String day = today}) =>
    FoodEntry({'id': 'e${_n++}', 'dayKey': day, 'meal': meal, 'name': 'x', 'amountDescription': '1', 'macros': {'calories': kcal, 'protein': protein, 'carbs': 1, 'fat': fat}});

Briefing brief(List<FoodEntry> entries, {int? kcalGoal, int? proteinGoal, int minute = 10 * 60, String day = today, bool headsUps = true, Set<String> seen = const {}}) =>
    eatBriefing(day: day, today: today, entries: entries, kcalGoal: kcalGoal, proteinGoal: proteinGoal, nowMinute: minute, nextMeal: 'Lunch', headsUps: headsUps, seen: seen);
String say(Briefing b) => briefingText(l, b, dayLabel: 'Thursday, October 29');

void main() {
  group('briefing', () {
    test('calories and protein are judged separately; an unknown calorie never gives an allowance', () {
      final b = brief([e('Breakfast', kcal: 400, protein: 30, fat: null), e('Lunch', kcal: null, protein: 20)], kcalGoal: 2000, proteinGoal: 120);
      expect(b.kind, BriefKind.unknownKcal);
      expect((b.proteinComplete, b.protein), (true, 50), reason: 'missing fat or calories never make known protein unknown');
      expect(say(b), allOf(contains('at least 400 kcal'), isNot(contains('left'))));
      final known = brief([e('Breakfast', kcal: 400, protein: 30, fat: null)], kcalGoal: 2000, proteinGoal: 120);
      expect(say(known), 'You have 1,600 kcal and 90 g protein left. Want some options?');
      expect(say(brief([e('Breakfast', kcal: 400, protein: null)], kcalGoal: 2000, proteinGoal: 120)), contains('1,600 kcal left'));
    });

    test('no goals: the meal logged and ideas, with a quiet way to goals; nothing logged: the next meal', () {
      final b = brief([e('Breakfast', kcal: 300, protein: 10)]);
      expect((b.kind, b.noGoals), (BriefKind.logged, true));
      expect(say(b), 'Breakfast is logged. Want ideas for your next meal?');
      expect(say(brief(const [])), 'Nothing logged yet today. Want ideas for lunch?');
    });

    test('heads-ups: over, near (only with time left in the day), protein reached; each once, then said plainly; off when turned off', () {
      final over = brief([e('Lunch', kcal: 2100, protein: 40)], kcalGoal: 2000);
      expect((over.kind, over.headsUp), (BriefKind.headsUp, HeadsUp.over));
      expect(say(over), allOf(contains('100 kcal above'), contains('lighter options'), isNot(contains('skip'))));
      final again = brief([e('Lunch', kcal: 2100, protein: 40)], kcalGoal: 2000, seen: {over.seenKey(today)!});
      // The only goal reached (above it): said plainly once its heads-up has been said, without offering more food.
      expect((again.kind, say(again)), (BriefKind.reached, 'You’ve reached your calorie target based on what you logged. Recorded calories are 100 kcal above your target today.'));
      expect(brief([e('Lunch', kcal: 2100)], kcalGoal: 2000, headsUps: false).kind, BriefKind.reached);
      expect(say(brief([e('Lunch', kcal: 2100, protein: 40)], kcalGoal: 2000, proteinGoal: 120, seen: {over.seenKey(today)!})), 'Recorded calories are 100 kcal above your target today. 80 g protein left.');

      final near = brief([e('Lunch', kcal: 1900)], kcalGoal: 2000, minute: 13 * 60);
      expect(near.headsUp, HeadsUp.near);
      expect(brief([e('Lunch', kcal: 1900)], kcalGoal: 2000, minute: 19 * 60).headsUp, isNull, reason: 'evening: no projection');
      expect(brief([e('Lunch', kcal: 1700)], kcalGoal: 2000, minute: 13 * 60).headsUp, isNull, reason: '10 % of 2,000 is 200, 300 is not near');
      expect(brief([e('Lunch', kcal: 1900, protein: 1)], kcalGoal: 3000, minute: 9 * 60).headsUp, isNull);

      // Reached is true even with an unknown protein value: the known part only grows.
      final protein = brief([e('Lunch', kcal: 600, protein: 130), e('Snack', kcal: 100, protein: null)], kcalGoal: 2000, proteinGoal: 120);
      expect((protein.headsUp, say(protein)), (HeadsUp.protein, 'You’ve reached your protein goal: 130 g of 120 g. Want ideas for your next meal?'));
      // The only goal (protein) reached: no heads-up asking for more food, the plain reached briefing instead.
      final only = brief([e('Lunch', kcal: 600, protein: 130), e('Snack', kcal: 100, protein: null)], proteinGoal: 120);
      expect((only.kind, say(only)), (BriefKind.reached, 'You’ve reached your protein target based on what you logged.'));
    });

    test('an earlier day is told looking back, with no heads-up and no "eat now"', () {
      final day = addDays(today, -1);
      final b = brief([e('Dinner', kcal: 2300, protein: 90, day: day)], kcalGoal: 2000, proteinGoal: 120, day: day);
      expect((b.kind, b.headsUp), (BriefKind.past, null));
      expect(say(b), 'On Thursday, October 29 you recorded 2,300 kcal and 90 g protein. That is 300 kcal above your target.');
      expect(say(brief(const [], day: day)), 'Nothing was recorded on Thursday, October 29.');
    });

    test('the next meal follows the person’s own meal reminders, else the time of day', () {
      expect(nextMealAt(10 * 60, reminders: [(meal: 'Lunch', minute: 12 * 60 + 30), (meal: 'Snack', minute: 15 * 60)]), 'Lunch');
      expect(nextMealAt(13 * 60, reminders: [(meal: 'Lunch', minute: 12 * 60 + 30)]), 'Lunch', reason: 'time of day after it');
      expect(nextMealAt(17 * 60), 'Dinner');
    });
  });

  group('ideas', () {
    final catalog = CommonFoodCatalog.parse(File('assets/data/common-foods.json').readAsStringSync());
    final common = [for (final c in catalog.foods) (item: c.item, fields: c.fields, name: c.name, detail: c.qualifier, startUnit: c.unitId)];
    IdeaFood f(String name, double? q, String? unit, {String? noun, String? prep}) => (name: name, label: name, preparation: prep, quantity: q, unit: unit, noun: noun);

    test('foods become real records with their own units; an unknown food stays a name; no unit is converted', () async {
      final searched = <String>[];
      final branded = FoodItem({'source': 'off', 'sourceId': 'b1', 'name': 'Farro', 'brand': 'Acme', 'basis': '100g', 'nutrients': {'calories': 120, 'protein': 4.4}, 'servings': const []});
      final plain = FoodItem({'source': 'usda', 'sourceId': 'q1', 'name': 'Farro, cooked', 'basis': '100g', 'nutrients': {'calories': 120, 'protein': 4.4}, 'servings': const []});
      final ideas = await resolveIdeas([
        (title: 'Eggs on toast', foods: [f('egg', 2, 'piece', noun: 'egg'), f('whole wheat bread', 1, 'piece', noun: 'slice'), f('banana', 2, 'ml')]),
        (title: 'Bowl', foods: [f('farro', 150, 'g', prep: 'cooked'), f('dragonfruit zzz', 100, 'g'), f('mango zzz', 100, 'g'), f('kiwi zzz', 100, 'g'), f('lychee zzz', 100, 'g')]),
      ], IdeaSources(common: common, search: (q) async {
        searched.add(q);
        return q.startsWith('farro') ? [branded, plain] : const [];
      }));
      final eggs = ideas[0]['parts'] as List;
      expect([for (final p in eggs) (p as Map)['unit']], ['serving:0'], reason: '2 of the record’s own "1 egg"');
      // Several slice sizes, and ml for a banana that has none: the person chooses the amount; nothing is substituted.
      expect([for (final c in ideas[0]['confirm'] as List) ((c as Map)['confirm'], c['label'])], [('amount', 'whole wheat bread'), ('amount', 'banana')]);
      final bowl = ideas[1];
      expect(((bowl['parts'] as List).single as Map)['item']['sourceId'], 'q1', reason: 'never a branded product the idea did not name');
      expect(bowl['unmatched'], ['dragonfruit zzz', 'mango zzz', 'kiwi zzz', 'lychee zzz']);
      expect(searched.length, 3, reason: 'at most three searches per request');
    });

    test('a preparation is never swapped: "cooked oats" is not matched to dry oats without the person confirming it', () async {
      final ideas = await resolveIdeas([
        (title: 'Porridge', foods: [f('oats', 40, 'g', prep: 'cooked')]),
        (title: 'Raw egg?', foods: [f('egg', 1, 'piece', noun: 'egg', prep: 'raw')]),
      ], IdeaSources(common: common));
      expect(ideas[0]['parts'], isEmpty);
      final which = (ideas[0]['confirm'] as List).single as Map;
      expect(which['confirm'], 'record');
      expect([for (final o in which['options'] as List) (o as Map)['match']], ['Dry · uncooked'], reason: 'offered, with its preparation, never taken');
      expect((((ideas[1]['parts'] as List).single as Map)['match']), 'Whole · raw', reason: 'a record stating the preparation is taken');
      // Choosing dry oats for "cooked oats" never reuses the 40 g proposed for cooked: a fresh amount, said why.
      final confirmed = confirmIdeaFood(ideas[0], 0, option: 0);
      expect(confirmed['parts'], isEmpty);
      final amount = (confirmed['confirm'] as List).single as Map;
      expect((amount['confirm'], amount['asked']), ('amount', 'cooked'));
      final records = DayRecords(today: today, shown: today, entries: (_) => const [], mealNow: 'Lunch');
      expect(((resolveDay(DayIntent('ideas', ideas: [confirmed]), records, l)['cards'] as List).single as Map).containsKey('kcal'), isFalse, reason: 'no totals before it');
      final done = confirmIdeaFood(confirmed, 0, part: {'item': (amount['food'] as Map)['item'], 'quantity': 30, 'unit': 'g', 'name': 'Oats'});
      expect(((done['parts'] as List).single as Map)['quantity'], 30);
      expect(((resolveDay(DayIntent('ideas', ideas: [done]), records, l)['cards'] as List).single as Map).containsKey('kcal'), isTrue);
    });

    test('equally good records are a choice, never the first one; an amount chosen in the form completes the idea', () async {
      FoodItem rice(String id, String name) => FoodItem({'source': 'usda', 'sourceId': id, 'name': name, 'basis': '100g', 'nutrients': {'calories': 130, 'protein': 2.7}, 'servings': const []});
      final pool = [candidateOf(rice('w', 'Rice, white, cooked')), candidateOf(rice('b', 'Rice, brown, cooked'))];
      final idea = (await resolveIdeas([(title: 'Rice bowl', foods: [f('rice', 150, 'g', prep: 'cooked'), f('banana', 2, 'ml')])], IdeaSources(common: pool, mine: common)))[0];
      final which = (idea['confirm'] as List).first as Map;
      expect([for (final o in which['options'] as List) (o as Map)['item']['sourceId']], ['w', 'b']);
      final brown = confirmIdeaFood(idea, 0, option: 1);
      expect(((brown['parts'] as List).single as Map)['item']['sourceId'], 'b');
      final records = DayRecords(today: today, shown: today, entries: (_) => const [], mealNow: 'Lunch');
      Map card(Json i) => (resolveDay(DayIntent('ideas', ideas: [i]), records, l)['cards'] as List).single as Map;
      expect(card(brown).containsKey('kcal'), isFalse, reason: 'the banana amount is still to be chosen: no totals, no Review');
      final banana = ((brown['confirm'] as List).single as Map)['food'] as Map;
      final done = confirmIdeaFood(brown, 0, part: {'item': banana['item'], 'quantity': 1, 'unit': 'serving:1', 'name': 'Banana'});
      expect((card(done)['kcal'] as Map)['complete'], isTrue);
      expect([for (final a in resolveDay(DayIntent('ideas', ideas: [done]), records, l)['actions'] as List) (a as Map)['id']], contains('reviewIdea'));
    });

    test('a reply gives totals only from records, fits the person’s own limit, and keeps unmatched ideas without totals', () async {
      final matched = await resolveIdeas([
        (title: 'Eggs', foods: [f('egg', 4, 'piece', noun: 'egg')]),
        (title: 'Mystery', foods: [f('dragonfruit zzz', 100, 'g')]),
      ], IdeaSources(common: common));
      final records = DayRecords(today: today, shown: today, entries: (_) => const [], mealNow: 'Lunch', calorieGoal: 2000);
      // The model's own words cannot carry a value: ideas are read by name, quantity and unit only.
      expect(ideasOf([{'title': 'X', 'foods': [{'name': 'egg', 'quantity': 2, 'unit': 'piece', 'calories': 9999, 'protein': 9999}]}]).single.foods.single.quantity, 2);
      final r = resolveDay(DayIntent('ideas', maxCalories: 200, preferences: const ['moreProtein', 'cheaper'], ideas: matched), records, l);
      final cards = [for (final c in r['cards'] as List) c as Map];
      final eggCard = cards.firstWhere((c) => c['name'] == 'Eggs');
      expect((eggCard['kcal'] as Map)['known'], lessThanOrEqualTo(200), reason: 'a practical step of every amount meets the limit');
      expect(cards.firstWhere((c) => c['name'] == 'Mystery').containsKey('kcal'), isFalse);
      expect([for (final a in r['actions'] as List) (a as Map)['id']], containsAll(['reviewIdea', 'findFood', 'another', 'addFood']));
      expect(r['lines'], contains(l.dcNoPrices));
      expect(resolveDay(DayIntent('ideas', ideas: matched), DayRecords(today: today, shown: addDays(today, -1), entries: (_) => const [], mealNow: 'Lunch'), l)['cards'], isEmpty,
          reason: 'no ideas for an earlier day');
    });

    test('"different from my usual" leaves out ideas sharing a food with the usual meal; a stored reply reads back the same', () async {
      final matched = await resolveIdeas([(title: 'Eggs', foods: [f('egg', 2, 'piece', noun: 'egg')]), (title: 'Banana', foods: [f('banana', 1, 'piece', noun: 'banana')])], IdeaSources(common: common));
      final egg = (matched[0]['parts'] as List).single as Map;
      final usualEntry = FoodEntry({'id': 'u', 'dayKey': addDays(today, -1), 'meal': 'Lunch', 'name': 'Eggs', 'amountDescription': '2', 'macros': const {}, 'source': {'item': egg['item'], 'quantity': 2, 'unit': egg['unit']}});
      final records = DayRecords(today: today, shown: today, entries: (_) => const [], mealNow: 'Lunch',
          usual: UsualMeal(meal: 'Lunch', signature: '', days: 3, lastDay: addDays(today, -1), entries: [usualEntry]));
      final intent = DayIntent('ideas', preferences: const ['different'], ideas: matched);
      expect([for (final c in resolveDay(intent, records, l)['cards'] as List) (c as Map)['name']], ['Banana']);
      expect(resolveDay(DayIntent.fromJson(intent.toJson())!, records, l)['cards'], resolveDay(intent, records, l)['cards']);
    });

    test('What could I eat? needs no AI: the usual meal, saved items and the ways to Eating out and Find food', () {
      final records = DayRecords(today: today, shown: today, entries: (_) => const [], mealNow: 'Lunch');
      final r = resolveDay(const DayIntent('eat'), records, l);
      // No goals: said first, with Edit goals offered (optional), then the options; nothing invented.
      expect((r['lines'] as List).first, l.dcAssessNoGoals);
      expect([for (final a in r['actions'] as List) (a as Map)['id']], ['goals', 'eatingOut', 'addFood', 'meals']);
    });
  });
}
