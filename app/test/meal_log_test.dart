import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/day_coach.dart';
import 'package:gohard_rebuild/features/coach/meal_ideas.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_search.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/l10n/app_localizations_en.dart';

/// Describe what you ate (docs/FOOD_DATA.md › Describe your meal): the words the server checked become one draft of real
/// food records on the phone. Nothing uncertain is decided for the person, and every value comes from the records.
void main() {
  final catalog = CommonFoodCatalog.parse(File('assets/data/common-foods.json').readAsStringSync(),
      overlay: File('assets/data/common-foods.l10n.json').readAsStringSync());
  final l = AppLocalizationsEn();
  SaidFood said(String name, [double? q, String? unit, String? noun, String? prep, String? brand]) =>
      (name: name, label: name, preparation: prep, brand: brand, quantity: q, unit: unit, noun: noun, evidence: null);
  IdeaSources sources({List<FoodItem> seen = const [], List<FoodItem> Function(String q)? search, List<String>? searched}) => IdeaSources.fromCatalog(
      catalog, seen: seen, maxSearches: 6,
      search: search == null ? null : (q) async {
        searched?.add(q);
        return search(q);
      });
  MealComponent part(Json item) => MealComponent(Map<String, dynamic>.from(item['part'] as Map));

  group('one sentence, one draft', () {
    test('"120 g of chicken and 100 g of potatoes": each asks how it was weighed; then one choice each, never breast for "chicken"', () async {
      final items = await resolveMeal([said('chicken', 120, 'g'), said('potatoes', 100, 'g')], sources());
      expect([for (final i in items) (i['ref'], i['status'])], [('d1', 'state'), ('d2', 'state')]);
      // Raw: which part, skin or not, the person's choice (the same grams for any: it is what they weighed). The card shows three,
      // then More options; liver, giblets and the whole leg are never among them for "chicken".
      final raw = await answerState(items[0], 'raw', sources());
      expect(raw['status'], 'record');
      expect([for (final o in raw['options'] as List) '${(o as Map)['name']} (${o['match']})'],
          ['Chicken breast (Raw · boneless, skinless)', 'Chicken thigh (Raw · boneless, skinless)', 'Chicken breast (Raw · with skin)', 'Chicken thigh (Raw · with skin)',
            'Chicken drumstick (Raw · with skin)', 'Chicken wing (Raw · with skin)']);
      expect(raw['unresolved'], ['cut', 'skin']);
      final breast = chooseRecord(raw, 0);
      expect((breast['status'], part(breast).quantity, part(breast).unitId, part(breast).item.sourceId), ('ready', 120.0, 'g', '2646170'));
      // Values only from the record: 120 g of 112 kcal / 22.5 g per 100 g.
      expect(part(breast).values['calories'], closeTo(134.4, 1e-9));
      expect(part(breast).values['protein'], closeTo(27, 1e-9));
      // Potatoes, cooked: USDA's general cooked potato, said as general; never the baked, skin-on record.
      final potato = await answerState(items[1], 'cooked', sources());
      expect((potato['status'], potato['general'], part(potato).item.sourceId, part(potato).quantity), ('ready', true, '2709382', 100.0));
    });

    test('what was said is used; a count is not asked raw or cooked; nothing is added that was not said', () async {
      final items = await resolveMeal([said('skinless chicken breast', 150, 'g', null, 'cooked'), said('egg', 2, 'piece', 'egg'), said('olive oil', 1, 'piece', 'tablespoon')], sources());
      expect([for (final i in items) i['status']], ['ready', 'ready', 'ready']);
      expect([for (final i in items) part(i).amount], ['150 g', '2 eggs (100 g)', '1 tablespoon (14 g)']);
      expect(items.length, 3, reason: 'no oil, butter or sauce of its own');
    });

    test('no amount said: choose one; a unit the record lacks: choose one; never a standard portion in its place', () async {
      final items = await resolveMeal([said('banana'), said('nonfat greek yogurt', 1, 'piece', 'bowl')], sources());
      expect([for (final i in items) i['status']], ['amount', 'amount']);
      expect((items[0]['food'] as Map)['name'], 'Banana');
    });

    test('ounces and pounds are converted exactly; never between weight and volume, or raw and cooked', () async {
      final oz = await resolveMeal([said('skinless chicken breast', 4, 'oz', null, 'raw')], sources());
      expect(part(oz.single).quantity, closeTo(113.3980925, 1e-9));
      expect(part(oz.single).unitId, 'g');
      final ml = await resolveMeal([said('skinless chicken breast', 100, 'ml', null, 'raw')], sources());
      expect(ml.single['status'], 'amount', reason: 'a breast has no volume: the amount is chosen, not guessed');
    });

    test('a food with no record stays in the draft as "find it"; the others are kept; searches are bounded and free', () async {
      final searched = <String>[];
      final items = await resolveMeal([said('dragonfruit'), said('egg', 2, 'piece', 'egg')], sources(search: (_) => const [], searched: searched));
      expect([for (final i in items) i['status']], ['missing', 'ready']);
      expect(searched, ['dragonfruit'], reason: 'only the food nothing on the phone matched');
    });

    test('the preparation said is kept: cooked oats take the general cooked oatmeal, never dry oats, at the amount said', () async {
      final item = (await resolveMeal([said('oats', 40, 'g', null, 'cooked')], sources())).single;
      expect((item['status'], item['general'], part(item).quantity), ('ready', true, 40.0));
      expect((item['part'] as Map)['match'], contains('Cooked'));
    });

    test('a brand said is offered only as that brand, and confirmed; without one a branded product is never offered', () async {
      final chobani = FoodItem({'source': 'usda', 'sourceId': '900103', 'name': 'Plain Non-Fat Greek Yogurt', 'brand': 'Chobani', 'basis': '100g',
        'nutrients': {'calories': 59, 'protein': 10, 'carbs': 4, 'fat': null}, 'servings': []});
      final branded = (await resolveMeal([said('greek yogurt', 170, 'g', null, null, 'Chobani')], sources(seen: [chobani]))).single;
      expect(branded['status'], 'record', reason: 'a product seen before is never taken without asking');
      expect([for (final o in branded['options'] as List) FoodItem(((o as Map)['item'] as Map).cast()).brand], ['Chobani']);
      final plain = (await resolveMeal([said('nonfat greek yogurt', 170, 'g')], sources(seen: [chobani]))).single;
      expect(plain['status'], 'ready');
      expect(part(plain).item.brand, isNull);
    });

    test('raw or cooked is asked only where cooking changes the weight: never for fruit, nuts, yogurt or bread, never once said', () async {
      final toast = FoodItem({'source': 'usda', 'sourceId': 't1', 'name': 'Bread, white, toasted', 'basis': '100g', 'nutrients': {'calories': 293}, 'servings': []});
      final items = await resolveMeal([
        said('apple', 150, 'g'), said('banana', 120, 'g'), said('almonds', 30, 'g'), said('greek yogurt', 170, 'g'), said('bread', 60, 'g'), said('white bread', 60, 'g'),
        said('oats', 40, 'g'), said('potatoes', 100, 'g'), said('chicken', 120, 'g'),
      ], sources(seen: [toast]));
      expect([for (final i in items) i['status']], ['ready', 'ready', 'ready', 'ready', 'record', 'ready', 'state', 'state', 'state'],
          reason: 'fruit and nuts as they come; Greek yogurt takes its general record; bread asks which; oats, potatoes and chicken ask how they were weighed');
      expect(part(items[5]).item.name, 'Bread, white', reason: 'the reviewed white bread; the toasted record seen before is never taken by itself');
      // Said in the words ("riz cuit", "cooked rice") or as a preparation: never asked again.
      final rice = (await resolveMeal([(name: 'rice', label: 'riz cuit', preparation: null, brand: null, quantity: 150, unit: 'g', noun: null, evidence: null)], sources())).single;
      expect((rice['status'], rice['general']), ('ready', true), reason: 'cooked said in French; white or brown was not: the general cooked rice');
      final cooked = (await resolveMeal([said('cooked rice', 150, 'g')], sources())).single;
      expect(cooked['status'], isNot('state'));
      final answered = await answerState(items[7], 'cooked', sources());
      expect((answered['status'], answered['general']), ('ready', true), reason: 'answered once: not asked again; the general cooked potato');
      // The safeguards stay: chicken is never taken as breast, and nothing is added.
      final raw = await answerState(items[8], 'raw', sources());
      expect((raw['status'], (raw['options'] as List).length), ('record', 6));
      expect(items.length, 9);
    });
  });

  group('more than twelve foods', () {
    test('past twelve, each food is named and the meal is not complete until it is added on its own or left out', () async {
      final eggs = (await resolveMeal([said('egg', 2, 'piece', 'egg')], sources())).single;
      final draft = <String, dynamic>{'dayKey': '2026-10-27', 'meal': 'Lunch', 'items': [eggs], 'extra': [{'label': 'pickles', 'state': 'open'}, {'label': 'olives', 'state': 'open'}]};
      var card = mealCard(draft, l);
      expect(card['complete'], isFalse);
      expect(card['without'], ['pickles', 'olives']);
      card = mealCard({...draft, 'extra': [{'label': 'pickles', 'state': 'left'}, {'label': 'olives', 'state': 'open'}]}, l);
      expect(card['complete'], isFalse);
      expect(card['without'], ['olives']);
      card = mealCard({...draft, 'extra': [{'label': 'pickles', 'state': 'left'}, {'label': 'olives', 'state': 'added'}]}, l);
      expect(card['complete'], isTrue);
      // The server could not name them: the meal is "without the rest" until the person leaves the rest out.
      card = mealCard({...draft, 'extra': const [], 'overflow': true}, l);
      expect(card['complete'], isFalse);
      expect(card['without'], ['the rest of what you named']);
      expect(mealCard({...draft, 'extra': const [], 'overflow': false}, l)['complete'], isTrue);
    });

    test('a server answer carries the foods named past twelve with the twelve', () {
      final i = DayIntent.fromJson({'kind': 'ate', 'foods': [{'name': 'egg'}], 'extra': ['pickles'], 'dropped': ['foods']}, ai: true)!;
      expect((i.proposed as Map)['extra'], ['pickles']);
      expect(i.dropped, ['foods']);
    });
  });

  group('the draft card and follow-ups', () {
    test('totals: so far, naming what is not counted; complete only when every food is confirmed; unknown stays unknown', () async {
      final items = await resolveMeal([said('egg', 2, 'piece', 'egg'), said('chicken', 120, 'g')], sources());
      final draft = {'draftId': 'x', 'rev': 1, 'dayKey': '2026-11-23', 'meal': 'Lunch', 'items': items};
      final card = mealCard(draft, l);
      expect(card['complete'], false);
      expect(card['without'], ['chicken']);
      expect(kcalSaid(l, Map<String, dynamic>.from((card['totals'] as Map)['kcal'] as Map)), '176 kcal', reason: 'the eggs alone (cooked in a way not said: USDA\'s record for that), named as so far');
      expect(card['amount'], isNot(contains('kcal')), reason: 'a follow-up never carries values');
      final sparse = FoodItem({'source': 'user', 'sourceId': 'u1', 'name': 'Soup', 'basis': 'serving', 'nutrients': {'calories': 90, 'protein': null}, 'servings': [{'label': '1 bowl'}]});
      final withSoup = [...items.take(1), readyWith({'ref': 'd3', 'said': saidJson(said('soup'))}, MealComponent({'item': sparse.j, 'quantity': 1, 'unit': 'serving:0', 'name': 'Soup', 'amount': '1 bowl'}).j)];
      final full = mealCard({...draft, 'items': withSoup}, l);
      expect(full['complete'], true, reason: 'a food with a missing value is still a confirmed food');
      expect(proteinSaid(l, Map<String, dynamic>.from((full['totals'] as Map)['protein'] as Map)), '11.8 g protein known', reason: 'never a complete total, never zero');
    });

    test('a follow-up changes only the draft: an amount in the record\'s units, a removal, an addition; an unknown reference nothing', () async {
      final items = await resolveMeal([said('skinless chicken breast', 120, 'g', null, 'raw'), said('boiled peeled potato', 100, 'g')], sources());
      final edited = await applyMealEdits(items, [
        (op: 'amount', ref: 'd2', food: said('potatoes', 150, 'g')),
        (op: 'remove', ref: 'd1', food: null),
        (op: 'add', ref: null, food: said('olive oil', 1, 'piece', 'tablespoon')),
        (op: 'remove', ref: 'd9', food: null),
      ], sources());
      expect([for (final i in edited.items) '${i['ref']} ${i['status']} ${part(i).amount}'], ['d2 ready 150 g', 'd1 ready 1 tablespoon (14 g)']);
      expect([for (final c in edited.changes) c['op']], ['amount', 'remove', 'add']);
      expect(items.length, 2, reason: 'the draft it was applied to is not changed in place');
      final words = draftWords(edited.items);
      expect(words, [{'ref': 'd2', 'text': 'Potato · 150 g'}, {'ref': 'd1', 'text': 'Olive oil · 1 tablespoon (14 g)'}]);
    });

    test('the reply keeps its draft through storage and is never made stale by logging it', () {
      final intent = DayIntent('ate', yesterday: true, ai: true).withDraft({'draftId': 'x', 'rev': 2, 'dayKey': '2026-11-23', 'meal': 'Lunch', 'items': const []});
      final back = DayIntent.fromJson(intent.toJson())!;
      expect((back.kind, back.yesterday, back.draft?['rev']), ('ate', true, 2));
      expect(DayIntent.fromJson({'kind': 'ate', 'day': 'yesterday', 'foods': [{'name': 'egg'}], 'draft': {'rev': 9}}, ai: true)!.draft, isNull,
          reason: 'a server answer never brings a draft of its own');
    });
  });
}
