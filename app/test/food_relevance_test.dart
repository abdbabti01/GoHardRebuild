import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_search.dart';
import 'package:gohard_rebuild/l10n/app_localizations_en.dart';

/// Finding the food meant (docs/FOOD_DATA.md › Search relevance, 24 Nov 2026): one ranking for the bundled foods, the
/// person's own and the wider database — plain foods before products made from them, the preparation and brand asked
/// for respected, misspellings and French or Arabic words understood. The wider answer here is USDA's real answer to
/// "chicken breast" as the API normalized it (test/fixtures/usda_chicken_breast.json); no test reaches USDA.
void main() {
  final catalog = CommonFoodCatalog.parse(File('assets/data/common-foods.json').readAsStringSync(),
      overlay: File('assets/data/common-foods.l10n.json').readAsStringSync());
  final usda = [for (final r in (jsonDecode(File('test/fixtures/usda_chicken_breast.json').readAsStringSync()) as Json)['results'] as List) FoodItem(r as Json)];
  List<String> found(String q, List<FoodItem> answer) => [for (final s in rankFound(q, answer, catalog: catalog)) s.item.name];
  List<String> local(String q, {List<FoodItem> seen = const [], String? also}) =>
      [for (final s in searchLocal(q, catalog: catalog, saved: const [], journal: const [], seen: seen, also: also).common) '${s.common!.name} · ${s.common!.qualifier}'];
  FoodItem branded(String id, String name, String brand, {double kcal = 120}) =>
      FoodItem({'source': 'usda', 'sourceId': id, 'name': name, 'brand': brand, 'basis': '100g', 'nutrients': {'calories': kcal, 'protein': 22, 'carbs': 0, 'fat': 2}, 'servings': []});

  group('a generic search finds the plain food first', () {
    test('chicken breast: the everyday raw and cooked breasts lead, offline, from the bundled foods', () {
      expect(local('chicken breast').take(2), ['Chicken breast · Baked or roasted · skinless', 'Chicken breast · Raw · boneless, skinless']);
      expect(local('Chicken Breasts').take(2), local('chicken breast').take(2), reason: 'case and plural do not matter');
    });

    test('chicken breast in the wider database: plain records before breaded, sauced, deli and fast-food ones', () {
      final order = found('chicken breast', usda);
      int at(String name) => order.indexOf(name);
      // USDA's own order puts lunchmeat first and the plain raw breast tenth.
      expect(usda.first.name, 'Lunchmeat, chicken breast, sliced');
      // Records that are also bundled foods (catalog v3) rank as the everyday foods they are; the plain ones still lead.
      expect(order.take(6), containsAll(['Chicken, breast, boneless, skinless, raw', 'Chicken breast, grilled without sauce, skin not eaten']));
      for (final processed in ['Chicken breast tenders, breaded, uncooked', 'Lunchmeat, chicken breast, sliced', 'Chicken breast, roll, oven-roasted',
        'Oscar Mayer, Chicken Breast (honey glazed)', 'Chicken breast, grilled with sauce, skin not eaten', 'Chicken breast, baked, coated, skin / coating not eaten']) {
        expect(at(processed), greaterThan(at('Chicken, breast, boneless, skinless, raw')), reason: processed);
        expect(at(processed), greaterThan(at('Chicken breast, grilled without sauce, skin not eaten')), reason: processed);
      }
      expect(order.length, usda.length, reason: 'every record that names the search is still listed, only reordered');
    });

    test('a preparation, cut or skin asked for is respected; a plain food is never put above what was asked', () {
      expect(found('chicken breast raw', usda).take(2), unorderedEquals(['Chicken, breast, boneless, skinless, raw', 'Chicken, breast, meat and skin, raw']));
      expect(found('grilled chicken breast', usda).first, 'Chicken breast, grilled without sauce, skin not eaten');
      expect(found('chicken breast with sauce', usda).first, 'Chicken breast, grilled with sauce, skin not eaten');
      expect(found('breaded chicken breast', usda).first, 'Chicken breast tenders, breaded, uncooked');
      final cooked = found('chicken breast cooked', usda);
      expect(cooked.indexOf('Chicken, breast, boneless, skinless, raw'), greaterThan(cooked.indexOf('Chicken breast, stewed, skin not eaten')), reason: '"cooked" never finds raw: it is only listed after every cooked record');
      expect(cooked.take(2), unorderedEquals(['Chicken breast, stewed, skin not eaten', 'Chicken breast, grilled without sauce, skin not eaten']),
          reason: '"cooked" finds any way of cooking, plain ones first (no added fat, sauce or coating)');
      expect(local('chicken breast raw'), ['Chicken breast · Raw · boneless, skinless', 'Chicken breast · Raw · with skin']);
      expect(local('chicken thigh'), containsAll(['Chicken thigh · Raw · boneless, skinless', 'Chicken thigh · Roasted · meat only', 'Chicken thigh · Cooked, way not specified · skin not eaten']));
      expect(local('chicken thigh'), everyElement(startsWith('Chicken thigh')));
    });

    test('a broader word is not taken as the narrower food: "chicken" is breast and thigh, raw and cooked, none of them exactly', () {
      final chicken = searchLocal('chicken', catalog: catalog, saved: const [], journal: const [], seen: const []).common;
      expect([for (final s in chicken.take(10)) s.common!.id], everyElement(startsWith('chicken-')), reason: 'breasts and thighs, raw and cooked');
      // Only the general record (part, way and skin not specified) is chicken exactly; no specific cut is.
      for (final s in chicken) {
        if (s.common!.id == 'chicken-cooked-nfs') continue;
        expect(relevance('chicken', s.common!.fields)!.tier, isNot(0), reason: s.common!.id);
      }
      expect(relevance('rice', catalog.foods.firstWhere((f) => f.id == 'white-rice').fields)!.tier, isNot(0), reason: 'rice is white or brown');
      expect(relevance('دجاج', catalog.foods.firstWhere((f) => f.id == 'chicken-breast').fields)!.tier, isNot(0), reason: 'the same rule in Arabic');
      expect(relevance('chicken breast', catalog.foods.firstWhere((f) => f.id == 'chicken-breast').fields)!.tier, 0);
    });

    test('milk: the dairy milks before almond milk, each named for what it is', () {
      final milk = local('milk');
      expect(milk.take(5), unorderedEquals(['Milk · Fat level not specified', 'Milk · Whole · 3.25%', 'Milk 2% · Reduced fat', 'Milk 1% · Low fat', 'Skim milk · Fat free']));
      expect(milk[5], 'Almond milk · Unsweetened');
    });
  });

  group('brands', () {
    final tyson = branded('900101', 'CHICKEN BREAST', 'TYSON');
    final store = branded('900102', 'CHICKEN BREAST', 'GIANT EAGLE', kcal: 110);
    final chobani = branded('900103', 'Chobani Plain Non- Fat Greek Yogurt', 'Chobani');

    test('a brand named puts its products first; a generic search keeps generic foods first without hiding the products', () {
      expect(found('tyson chicken breast', [...usda, store, tyson]).first, 'CHICKEN BREAST');
      expect(rankFound('tyson chicken breast', [...usda, store, tyson], catalog: catalog).first.item.brand, 'TYSON');
      final generic = found('chicken breast', [tyson, ...usda]);
      expect(generic.indexOf('CHICKEN BREAST'), greaterThan(generic.indexOf('Chicken, breast, boneless, skinless, raw')), reason: 'not asked for: after the plain food');
      expect(generic, contains('CHICKEN BREAST'), reason: 'never hidden');
      expect(found('chobani', [...usda, chobani]), ['Chobani Plain Non- Fat Greek Yogurt'], reason: 'nothing else names Chobani');
    });

    test('rows say generic or brand plainly, a capitalised product name reads as a sentence, and the record keeps its name', () {
      final l = AppLocalizationsEn();
      final row = rowFacts(Suggestion(tyson, Origin.found), l), plain = rowFacts(Suggestion(usda[9], Origin.found), l);
      expect((row.title, row.detail), ('Chicken breast', 'Brand: Tyson'));
      expect((plain.title, plain.detail), ('Chicken, breast, boneless, skinless, raw', 'Generic'));
      expect((tyson.name, tyson.sourceId), ('CHICKEN BREAST', '900101'), reason: 'display only: the source name and ID are untouched');
    });

    test('the same product listed twice is shown once; different products, values or portions are never merged', () {
      final again = branded('900199', 'CHICKEN BREAST', 'TYSON');
      final other = branded('900198', 'CHICKEN BREAST', 'TYSON', kcal: 130);
      expect([for (final i in withoutRepeats([tyson, again, other, store])) i.sourceId], ['900101', '900198', '900102']);
      expect(withoutRepeats(usda).length, usda.length, reason: 'raw, roasted, with skin and without are different records');
    });
  });

  group('what was typed', () {
    test('a misspelling is corrected to a word the app knows, and only then', () {
      expect(correctSpelling('chiken brest', catalog.vocabulary), 'chicken breast');
      expect(correctSpelling('chikcen', catalog.vocabulary), 'chicken', reason: 'two letters swapped');
      expect(local('brocolli', also: correctSpelling('brocolli', catalog.vocabulary)).first, 'Broccoli · Raw', reason: 'corrected to a word that names broccoli');
      expect(correctSpelling('tomatoe', catalog.vocabulary), 'tomato');
      expect(correctSpelling('chicken breast', catalog.vocabulary), isNull);
      expect(correctSpelling('chick', catalog.vocabulary), isNull, reason: 'a word being typed is left alone');
      expect(correctSpelling('kiwi', catalog.vocabulary), isNull, reason: 'a word with no close match is not changed into another food');
      expect(local('chiken brest'), isEmpty);
      expect(local('chiken brest', also: correctSpelling('chiken brest', catalog.vocabulary)).take(2), local('chicken breast').take(2));
    });

    test('French and Arabic words find the bundled foods, and are put in English for the English-only database', () {
      expect(local('poitrine de poulet').take(2), local('chicken breast').take(2));
      expect(local('صدر دجاج').take(2), local('chicken breast').take(2));
      expect(local('cuisse de poulet'), unorderedEquals(local('chicken thigh')));
      expect(englishQuery('poitrine de poulet cuite'), 'breast chicken cooked');
      expect(englishQuery('صدر دجاج مشوي'), 'breast chicken grilled');
      expect(englishQuery('pommes de terre'), 'potato');
      expect(englishQuery('chicken breast'), isNull, reason: 'English is sent as typed');
      expect(interpretQuery('poulet cuit', catalog).remote, 'chicken cooked');
      // USDA's answer to French words matched only "de": none of it is shown as an answer.
      final atole = FoodItem({'source': 'usda', 'sourceId': '1', 'name': 'Atole de avena', 'basis': '100g', 'nutrients': {'calories': 80}, 'servings': []});
      expect(rankFound('poitrine de poulet', [atole, ...usda], catalog: catalog, also: 'breast chicken').map((s) => s.item.name), isNot(contains('Atole de avena')));
      expect(rankFound('poitrine de poulet', [atole, ...usda], catalog: catalog, also: 'breast chicken').first.item.name, 'Chicken, breast, boneless, skinless, raw');
    });

    test('raw or cooked is read from the food\'s own words, in every language', () {
      SearchFields f(String id) => catalog.foods.firstWhere((x) => x.id == id).fields;
      expect([foodState(f('chicken-breast')), foodState(f('chicken-breast-raw')), foodState(f('oatmeal')), foodState(f('greek-yogurt'))], ['cooked', 'raw', 'raw', null]);
      expect(foodState(SearchFields('Chicken breast, baked, broiled, or roasted, skin not eaten, from raw')), 'cooked', reason: '"from raw" is what it was made from');
      expect(foodState(SearchFields('Lentils', qualifier: 'Cooked from dried · no added fat')), 'cooked');
    });
  });
}
