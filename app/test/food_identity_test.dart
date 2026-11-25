import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/meal_ideas.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_search.dart';
import 'package:gohard_rebuild/features/nutrition/food_traits.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart' show MealComponent;

/// Food identity (docs/FOOD_DATA.md › Food identity): a described food is matched only to records of that food. The search
/// answers are USDA's live answers of 25 Nov 2026 as the GoHard API normalizes them (test/fixtures, kept identical to the
/// server's normalization by the API test `The_apps_recorded_answers_are_this_servers_normalization`); no test reaches USDA.
void main() {
  final json = File('assets/data/common-foods.json').readAsStringSync(), overlay = File('assets/data/common-foods.l10n.json').readAsStringSync();
  final catalog = CommonFoodCatalog.parse(json, overlay: overlay);
  // The catalog before the part records were added (drumstick, wing, whole leg, liver): those foods only from the search.
  final parts = RegExp(r'drumstick|wing|leg-|liver');
  final before = CommonFoodCatalog.parse(jsonEncode({...jsonDecode(json) as Json, 'foods': [for (final f in (jsonDecode(json) as Json)['foods'] as List) if (!parts.hasMatch('${(f as Map)['id']}')) f]}),
      overlay: overlay);
  List<FoodItem> recorded(String file) => [for (final r in (jsonDecode(File('test/fixtures/$file').readAsStringSync()) as Json)['results'] as List) FoodItem(r as Json)];
  final drumstickPage = recorded('usda_items_chicken_drumstick.json'), chickenPage = recorded('usda_items_chicken.json');
  // USDA records with their real FDC IDs and names (SR Legacy and FNDDS downloads): organs, and the other parts.
  FoodItem fdc(String id, String name, double kcal, {List<Json> servings = const []}) =>
      FoodItem({'source': 'usda', 'sourceId': id, 'name': name, 'description': 'Poultry Products', 'basis': '100g', 'nutrients': {'calories': kcal}, 'servings': servings});
  final organs = [
    fdc('171455', 'Chicken, broilers or fryers, giblets, cooked, simmered', 157),
    fdc('171061', 'Chicken, liver, all classes, cooked, simmered', 167),
    fdc('171059', 'Chicken, heart, all classes, cooked, simmered', 185),
    fdc('171457', 'Chicken, gizzard, all classes, cooked, simmered', 154),
  ];
  final otherParts = [
    fdc('2706028', 'Chicken thigh, NS as to cooking method, skin not eaten', 191),
    fdc('2705954', 'Chicken breast, NS as to cooking method, skin not eaten', 151),
    fdc('2706056', 'Chicken wing, NS as to cooking method', 257),
    fdc('2705983', 'Chicken leg, drumstick and thigh, NS as to cooking method, skin not eaten', 185),
    fdc('2705929', 'Chicken, NS as to part and cooking method, NS as to skin eaten', 197),
  ];
  // The search: what USDA answers for the words asked, organs and every other part mixed in on purpose.
  List<FoodItem> usda(String q) {
    final w = searchWords(q);
    if (w.contains('drumstick')) return [...organs, ...otherParts, ...drumstickPage];
    if (w.contains('liver')) return [...otherParts, organs[1], ...chickenPage.where((i) => i.name.contains('Liver'))];
    if (w.contains('chicken')) return [...chickenPage, ...organs, ...otherParts];
    return const [];
  }

  IdeaSources sources({CommonFoodCatalog? from, List<String>? searched, List<FoodItem> Function(String q)? search, bool offline = false, int maxSearches = 6}) =>
      IdeaSources.fromCatalog(from ?? catalog, maxSearches: maxSearches, search: (q) async {
        searched?.add(q);
        if (offline) throw StateError('offline');
        return (search ?? usda)(q);
      });
  SaidFood said(String name, String evidence, {double? q, String? unit, String? noun, String? label, String? preparation}) =>
      (name: name, label: label ?? evidence, preparation: preparation, brand: null, quantity: q, unit: unit, noun: noun, evidence: evidence);
  List<String> offered(Json i) => [for (final o in i['options'] as List? ?? const []) FoodItem((o as Map)['item'] as Json).name];
  List<Json> facts(Json i) => [for (final o in i['options'] as List) Map<String, dynamic>.from((o as Map)['facts'] as Map? ?? const {})];
  MealComponent part(Json i) => MealComponent(Map<String, dynamic>.from(i['part'] as Map));
  String id(Json i) => catalog.of(part(i).item)!.id;
  final unwanted = RegExp(r'liver|heart|gizzard|giblet|feet|neck|back|tail|skin \(|chicken skin|thigh|breast|wing|leg,|NS as to part', caseSensitive: false);

  group('the reported screen: "Which matches your chicken drumsticks?" offered only giblets, liver, heart and gizzard', () {
    // Before: the model's name "chicken" was searched as "chicken"; USDA's first page for it is feet, skin, back, liver and
    // dishes (no drumstick among 25 of 847); every chicken record was "relevant", a part the record's name did not state was
    // no contradiction, and every record from the search was offered: giblets, liver, heart, gizzard; "Not said: which part".
    test('model name "chicken", noun "drumstick", the words "3 cooked chicken drumsticks", drumsticks not on the phone: "chicken drumstick" is searched; drumsticks are offered, nothing else', () async {
      final searched = <String>[];
      final item = (await resolveMeal([said('chicken', '3 cooked chicken drumsticks', q: 3, unit: 'piece', noun: 'drumstick')], sources(from: before, searched: searched))).single;
      expect(searched, ['chicken drumstick'], reason: 'the identity the person said is kept in the query');
      expect(item['status'], 'record');
      expect(offered(item), ['Chicken drumstick, NS as to cooking method, skin eaten', 'Chicken drumstick, NS as to cooking method, skin not eaten'],
          reason: 'the two that take least for granted, in USDA\x27s order');
      expect(item['unresolved'], ['skin'], reason: 'only the skin was not said; "which part" was said');
      expect(facts(item), [
        {'cut': 'drumstick', 'state': 'cooked', 'skin': 'yes'},
        {'cut': 'drumstick', 'state': 'cooked', 'skin': 'no'},
      ], reason: 'the short label says only what each record\'s own name establishes');
      final chosen = chooseRecord(item, 0);
      expect((chosen['status'], part(chosen).item.sourceId, part(chosen).quantity, part(chosen).amount), ('ready', '2706000', 3.0, '3 drumsticks (180 g)'),
          reason: 'three of the record\'s own drumsticks, its values unchanged');
      expect((chosen['part'] as Map)['facts'], isNull);
    });

    test('a search that returns only organs, parts and dishes offers none of them: a disclosed broader estimate, never a guess', () async {
      final item = (await resolveMeal([said('chicken', '3 cooked chicken drumsticks', q: 3, unit: 'piece', noun: 'drumstick')],
          sources(from: before, search: (q) => [...chickenPage, ...organs]))).single;
      expect(offered(item), isEmpty);
      final e = item['estimate'] as Map;
      expect((e['substitute'], FoodItem(e['item'] as Json).sourceId), (true, '2705929'), reason: 'the general chicken, said to be another record, taken only on a tap');
      final accepted = acceptEstimate(item, (n) => '$n (estimate)');
      expect((accepted['status'], (accepted['estimate'] as Map)['substitute']), ('amount', true), reason: '3 drumsticks is no amount of the general chicken: asked, never guessed');
    });

    test('with the part records in the catalog: no search, the two reviewed drumsticks; the chosen one at its own standard size', () async {
      final searched = <String>[];
      final item = (await resolveMeal([said('chicken drumsticks', '3 cooked chicken drumsticks', q: 3, unit: 'piece', noun: 'drumstick')], sources(searched: searched))).single;
      expect(searched, isEmpty, reason: 'a reviewed record on the phone shows everything said');
      expect([for (final o in item['options'] as List) catalog.of(FoodItem((o as Map)['item'] as Json))!.id], ['chicken-drumstick-cooked', 'chicken-drumstick-cooked-skin']);
      expect(item['unresolved'], ['skin']);
      final chosen = chooseRecord(item, 0);
      expect((id(chosen), part(chosen).amount, chosen['part']['standard']), ('chicken-drumstick-cooked', '3 drumsticks (150 g)', '1 drumstick (50 g)'));
    });
  });

  group('compatibility before ranking', () {
    final mixed = [...organs, ...otherParts, ...drumstickPage, ...chickenPage];
    Future<Json> one(SaidFood f, {CommonFoodCatalog? from}) async => (await resolveMeal([f], sources(from: from ?? before, search: (q) => mixed))).single;

    test('drumstick: never thigh, whole leg, breast, wing, skin, organ or the part-not-specified record; whatever is ranked first', () async {
      for (final words in ['cooked chicken drumsticks', '2 drumsticks', 'chicken drumstick, stewed', 'grilled chicken drumsticks']) {
        final item = await one(said('chicken drumsticks', words));
        expect(offered(item), isNotEmpty, reason: words);
        expect(offered(item).where(unwanted.hasMatch), isEmpty, reason: '$words → ${offered(item)}');
        expect(offered(item).every((n) => n.toLowerCase().contains('drumstick')), isTrue, reason: words);
      }
    });

    test('each part finds its own records: thigh, breast, wing, liver; the whole leg only when the leg is said', () async {
      expect(offered(await one(said('chicken thighs', 'cooked chicken thighs'))), everyElement(contains('thigh')));
      expect(offered(await one(said('chicken wings', 'cooked chicken wings'))), everyElement(contains('wing')));
      final leg = await one(said('chicken leg', 'a cooked chicken leg'), from: catalog);
      expect([for (final o in leg['options'] as List) catalog.of(FoodItem((o as Map)['item'] as Json))!.id], ['chicken-leg-cooked', 'chicken-leg-cooked-skin']);
      final liver = (await resolveMeal([said('chicken liver', 'chicken liver')], sources())).single;
      expect([for (final o in liver['options'] as List) catalog.of(FoodItem((o as Map)['item'] as Json))!.id], ['chicken-liver-cooked'],
          reason: '"chicken liver" is liver: what was asked for; eaten whole, the cooked record');
      final remoteLiver = await one(said('chicken liver', '100 g cooked chicken liver', q: 100, unit: 'g'));
      expect(offered(remoteLiver), everyElement(matches(RegExp('liver', caseSensitive: false))));
    });

    test('"chicken" with no part: no organ, skin, giblets or dish is ever a choice; the reviewed general record is the default', () async {
      final cooked = (await resolveMeal([said('chicken', '150 g of cooked chicken', q: 150, unit: 'g')], sources(search: (q) => [...chickenPage, ...organs]))).single;
      expect((cooked['status'], id(cooked), cooked['general']), ('ready', 'chicken-cooked-nfs', true));
      final raw = await answerState((await resolveMeal([said('chicken', '150 g of chicken', q: 150, unit: 'g')], sources(search: (q) => [...chickenPage, ...organs]))).single, 'raw', sources());
      expect(offered(raw).where(RegExp(r'liver|heart|gizzard|giblet|feet|back|tail|Chicken skin|roll|spread', caseSensitive: false).hasMatch), isEmpty, reason: '${offered(raw)}');
    });

    test('an explicit roasted and skinless drumstick is the matching record directly; from the search alone, the closest records say what they cannot show', () async {
      final direct = (await resolveMeal([said('chicken drumsticks', '150 g roasted skinless chicken drumsticks', q: 150, unit: 'g')], sources())).single;
      expect((direct['status'], id(direct), part(direct).item.name, part(direct).quantity), ('ready', 'chicken-drumstick-roasted', 'Chicken drumstick, baked, broiled, or roasted, skin not eaten, from raw', 150.0));
      // Counted: the record states small, medium and large drumsticks, so which size is asked, on that record.
      final counted = (await resolveMeal([said('chicken drumsticks', '2 roasted skinless chicken drumsticks', q: 2, unit: 'piece', noun: 'drumstick')], sources())).single;
      expect((counted['status'], catalog.of(FoodItem((counted['food'] as Map)['item'] as Json))!.id), ('amount', 'chicken-drumstick-roasted'));
      final remote = await one(said('chicken drumsticks', '2 roasted skinless chicken drumsticks', q: 2, unit: 'piece', noun: 'drumstick'));
      expect(offered(remote), ['Chicken drumstick, NS as to cooking method, skin not eaten'], reason: 'the one that contradicts nothing; rotisserie, stewed and skin eaten are not roasted and skinless');
      expect(remote['unresolved'], isEmpty, reason: '"roasted" was said: never "not said"');
      expect(remote['unshown'], ['method'], reason: 'the record cannot show "roasted", and that is kept apart');
    });
  });

  group('everyday defaults and explicit words', () {
    test('"2 eggs" is the general cooked egg with its standard size; raw, boiled and fried are those records', () async {
      final items = await resolveMeal([
        said('eggs', '2 eggs', q: 2, unit: 'piece', noun: 'egg'), said('eggs', '2 raw eggs', q: 2, unit: 'piece', noun: 'egg'),
        said('eggs', '2 boiled eggs', q: 2, unit: 'piece', noun: 'egg'), said('eggs', '2 fried eggs', q: 2, unit: 'piece', noun: 'egg'),
      ], sources());
      expect([for (final i in items) (i['status'], id(i))], [('ready', 'eggs-cooked'), ('ready', 'eggs'), ('ready', 'eggs-boiled'), ('ready', 'eggs-fried')]);
      expect((items[0]['general'], items[0]['part']['standard']), (true, '1 egg (50 g)'));
    });

    test('cooked potatoes: the general record; peeled and skin-on are those records', () async {
      final items = await resolveMeal([
        said('potatoes', '130 g cooked potatoes', q: 130, unit: 'g'), said('potatoes', '130 g boiled peeled potatoes', q: 130, unit: 'g'),
        said('potatoes', '130 g boiled potatoes with skin', q: 130, unit: 'g'), said('potatoes', '200 g baked potatoes, skin on', q: 200, unit: 'g'),
      ], sources(search: (q) => const []));
      expect([for (final i in items) id(i)], ['potato-nfs', 'potato-boiled-peeled', 'potato-boiled-skin', 'potato']);
      expect(items[0]['general'], isTrue);
    });
  });

  group('several foods in one sentence', () {
    test('different preparations stay with their own food, in both response shapes', () async {
      const sentence = 'I had 2 roasted chicken drumsticks and 150 g of boiled potatoes';
      for (final old in [true, false]) {
        final foods = [
          said('chicken drumsticks', old ? '' : '2 roasted chicken drumsticks', q: 2, unit: 'piece', noun: 'drumstick', preparation: 'boiled'),
          said('potatoes', old ? '' : '150 g of boiled potatoes', q: 150, unit: 'g', preparation: 'roasted'),
        ].map((f) => old ? (name: f.name, label: f.name, preparation: f.preparation, brand: null, quantity: f.quantity, unit: f.unit, noun: f.noun, evidence: null) : f);
        final items = await resolveMeal([for (final f in foods) withSentence(f, sentence)], sources());
        expect([for (final o in items[0]['options'] as List) catalog.of(FoodItem((o as Map)['item'] as Json))!.id], ['chicken-drumstick-roasted', 'chicken-drumstick-roasted-skin'],
            reason: 'roasted (said of the drumsticks), never the model\'s "boiled"; the skin was not said');
        expect((id(items[1]), items[1]['general']), ('potato-boiled-nfs', true), reason: 'boiled, never "roasted"');
      }
    });

    test('two foods of one family keep their own part: "100 g chicken breast and 150 g chicken thighs, both cooked"', () async {
      const sentence = 'I had 100 g cooked chicken breast and 150 g cooked chicken thighs';
      final items = await resolveMeal([
        withSentence((name: 'chicken breast', label: 'chicken breast', preparation: 'cooked', brand: null, quantity: 100, unit: 'g', noun: null, evidence: null), sentence),
        withSentence((name: 'chicken thighs', label: 'chicken thighs', preparation: 'cooked', brand: null, quantity: 150, unit: 'g', noun: null, evidence: null), sentence),
      ], sources());
      expect([for (final i in items) [for (final o in i['options'] as List) catalog.of(FoodItem((o as Map)['item'] as Json))!.id]], [
        ['chicken-breast-cooked', 'chicken-breast-cooked-skin'],
        ['chicken-thigh-cooked', 'chicken-thigh-cooked-skin'],
      ]);
      expect([for (final i in items) i['unresolved']], [['skin'], ['skin']], reason: 'the part was said for each: never "which part"');
    });
  });

  group('weighed with the bones', () {
    const sentence = '260 g cooked chicken drumsticks weighed with bones and skin; I did not eat the skin.';
    for (final old in [true, false]) {
      test('${old ? 'deployed' : 'new'} response shape: the record for no skin; 260 g is never used as what was eaten', () async {
        final f = said('chicken drumsticks', old ? '' : sentence, q: 260, unit: 'g');
        final item = (await resolveMeal([old ? withSentence((name: f.name, label: 'cooked chicken drumsticks', preparation: null, brand: null, quantity: 260, unit: 'g', noun: null, evidence: null), sentence) : f],
            sources())).single;
        expect((item['status'], item['weighed']), ('edible', 260.0));
        expect(catalog.of(FoodItem((item['food'] as Map)['item'] as Json))!.id, 'chicken-drumstick-cooked', reason: '"I did not eat the skin": the skinless record');
        // Bones and skin weighed after: 80 g left, 180 g eaten.
        final left = answerEdible(item, left: 80);
        expect((left['status'], part(left).quantity, part(left).unitId, left['weighed'], left['left']), ('ready', 180.0, 'g', 260.0, 80.0));
        expect(part(left).values['calories'], closeTo(172 * 1.8, 1e-9), reason: 'the record\'s values per 100 g of what is eaten, for 180 g');
        // Or the weight eaten given directly.
        expect(part(answerEdible(item, eaten: 150)).quantity, 150.0);
        // Nothing impossible is taken.
        for (final bad in [260.0, 300.0, -5.0]) {
          expect(answerEdible(item, left: bad)['status'], 'edible', reason: '$bad left');
        }
      });
    }

    test('"bone-in" in French and Arabic too; a weight without bones is placed as said', () {
      expect(weighedWithBones('300 g de pilons avec les os'), isTrue);
      expect(weighedWithBones('300 غ أفخاذ دجاج بالعظم'), isTrue);
      expect(weighedWithBones('300 g bone-in chicken thighs'), isTrue);
      expect(weighedWithBones('300 g boneless chicken thighs'), isFalse);
      expect(weighedWithBones('300 g cooked chicken drumsticks'), isFalse);
    });
  });

  group('words', () {
    test('singular, plural, French and Arabic name the same part', () {
      for (final w in ['chicken drumstick', 'chicken drumsticks', 'pilons de poulet', 'un pilon de poulet', 'سيقان دجاج', 'دبوس دجاج']) {
        final t = readTraits(w);
        expect(t[Attr.family], {'chicken'}, reason: w);
        expect(t[Attr.cut], {'drumstick'}, reason: w);
      }
      for (final (w, cut) in [('ailes de poulet', 'wing'), ('أجنحة دجاج', 'wing'), ('foie de poulet', 'liver'), ('كبدة دجاج', 'liver'), ('gésiers de poulet', 'gizzard'),
          ('Chicken leg, drumstick and thigh, rotisserie', 'leg'), ('Chicken, skin (drumsticks and thighs), raw', 'skin'),
          ('Chicken, broilers or fryers, meat and skin and giblets and neck, raw', 'whole')]) {
        expect(readTraits(w)[Attr.cut], {cut}, reason: w);
      }
    });

    test('French and Arabic descriptions with the model\'s plain "chicken" are searched as "chicken drumstick"', () async {
      for (final words in ['3 pilons de poulet cuits', '3 سيقان دجاج مطبوخة']) {
        final searched = <String>[];
        final item = (await resolveMeal([said('chicken', words, q: 3, unit: 'piece', noun: 'drumstick')], sources(from: before, searched: searched))).single;
        expect(searched, ['chicken drumstick'], reason: words);
        expect(offered(item), everyElement(contains('drumstick')), reason: words);
      }
    });

    test('a dish or product made with the food is not the food, unless its words were said', () {
      expect(productWords('Orange chicken'), {'orange'});
      expect(productWords('Chicken spread'), {'spread'});
      expect(productWords('Soup, chicken'), {'soup'});
      expect(productWords('Chicken drumstick, rotisserie, skin eaten'), isEmpty);
      expect(productWords('Chicken, broilers or fryers, drumstick, meat only, cooked, fried'), isEmpty);
      expect(productWords('Fish, salmon, Atlantic, farmed, cooked'), isEmpty, reason: 'a leading category names the food after it');
      expect(namesSameFood('chicken drumstick', 'Chicken drumstick, stewed, skin eaten'), isTrue);
      expect(namesSameFood('chicken drumstick', 'Chicken, liver, all classes, cooked, simmered'), isFalse);
      expect(namesSameFood('chicken drumstick', 'Chicken leg, drumstick and thigh, rotisserie, skin eaten'), isFalse);
      expect(namesSameFood('chicken', 'Orange chicken'), isFalse);
      expect(namesSameFood('orange chicken', 'Orange chicken'), isTrue);
      expect(namesSameFood('dragonfruit', 'Dragon fruit, raw'), isNull, reason: 'no known food named: nothing can be told');
    });
  });

  group('retrieval: offline, failures, nothing suitable, bounded', () {
    test('offline: the food stays, with Try again; never "nothing found"', () async {
      final item = (await resolveMeal([said('chicken', '3 cooked chicken drumsticks', q: 3, unit: 'piece', noun: 'drumstick')], sources(from: before, offline: true))).single;
      expect(item['status'], 'unavailable');
      final again = await retryItem(item, sources(from: before));
      expect(offered(again), everyElement(contains('drumstick')));
    });

    test('nothing at all for an unknown food: Find food; the other foods are kept', () async {
      final items = await resolveMeal([said('dragonfruit', '100 g dragonfruit', q: 100, unit: 'g'), said('eggs', '2 eggs', q: 2, unit: 'piece', noun: 'egg')], sources());
      expect([for (final i in items) i['status']], ['missing', 'ready']);
    });

    test('at most the request\'s budget of searches, each query once', () async {
      final searched = <String>[];
      final foods = [for (final w in ['drumstick', 'drumstick', 'liver', 'gizzard', 'heart']) said('chicken', '100 g cooked chicken $w', q: 100, unit: 'g')];
      await resolveMeal(foods, sources(from: before, searched: searched, maxSearches: 3));
      expect(searched, ['chicken drumstick', 'chicken liver', 'chicken gizzard'], reason: 'the same words are asked once; no more than three searches');
    });
  });
}
