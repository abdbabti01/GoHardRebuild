import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/coach/meal_ideas.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_search.dart';
import 'package:gohard_rebuild/features/nutrition/food_traits.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart' show MealComponent;

/// Described-meal resolution (docs/FOOD_DATA.md › Food resolution): what was said, which records are found, and whether
/// one may be taken without asking. Words as the server would check them; no model, no network.
void main() {
  final catalog = CommonFoodCatalog.parse(File('assets/data/common-foods.json').readAsStringSync(),
      overlay: File('assets/data/common-foods.l10n.json').readAsStringSync());
  SaidFood said(String name, [double? q, String? unit, String? noun, String? evidence, String? brand]) =>
      (name: name, label: name, preparation: null, brand: brand, quantity: q, unit: unit, noun: noun, evidence: evidence ?? [if (q != null) '${q.round()} ${unit == 'piece' ? noun ?? '' : unit}', name].join(' '));
  IdeaSources sources({List<FoodItem> seen = const [], List<FoodItem> mine = const [], List<FoodItem> Function(String q)? search, List<String>? searched, bool fails = false}) =>
      IdeaSources.fromCatalog(catalog, seen: seen, mine: mine, maxSearches: 6,
          search: search == null && !fails ? null : (q) async {
            searched?.add(q);
            if (fails) throw StateError('offline');
            return search!(q);
          });
  String status(Json i) => i['status'] as String;
  List<String> optionNames(Json i) => [for (final o in i['options'] as List) '${(o as Map)['name']} · ${o['match']}'];
  MealComponent part(Json i) => MealComponent(Map<String, dynamic>.from(i['part'] as Map));
  String id(Json i) => catalog.of(part(i).item)!.id;
  FoodItem usda(String id, String name, {String? brand, double kcal = 100}) =>
      FoodItem({'source': 'usda', 'sourceId': id, 'name': name, 'brand': brand, 'basis': '100g', 'nutrients': {'calories': kcal}, 'servings': []});

  group('the reported sentence (IPA 86)', () {
    test('"100 g of cooked chicken thighs and 130 g of cooked potatoes": the potatoes take USDA\'s general record, said as general; the thighs ask about the skin with the full preparation shown', () async {
      final items = await resolveMeal([said('cooked chicken thighs', 100, 'g'), said('cooked potatoes', 130, 'g')], sources());
      expect([for (final i in items) status(i)], ['record', 'ready']);
      // No general cooked-thigh record exists (every thigh record states the skin; the general chicken record cannot show
      // "thigh"): one concise choice, each option saying its whole preparation, none of them roasted.
      expect(optionNames(items[0]), ['Chicken thigh · Cooked, way not specified · skin not eaten', 'Chicken thigh · Cooked, way not specified · skin eaten']);
      expect(items[0]['unresolved'], ['skin']);
      // Potatoes: the reviewed general record for a cooked potato (USDA "Potato, NFS"), marked general, never baked or skin-on.
      expect((items[1]['general'], part(items[1]).item.sourceId, part(items[1]).quantity), (true, '2709382', 130.0));
      expect(part(items[1]).item.name, 'Potato, NFS');
      final thigh = chooseRecord(items[0], 0);
      expect((status(thigh), part(thigh).quantity, (thigh['part'] as Map)['match']), ('ready', 100.0, 'Cooked, way not specified · skin not eaten'));
    });

    test('the same words without "cooked": raw or cooked is asked first, and the answer is kept', () async {
      final items = await resolveMeal([said('chicken thighs', 100, 'g'), said('potatoes', 130, 'g')], sources());
      expect([for (final i in items) status(i)], ['state', 'state']);
      final cooked = await answerState(items[0], 'cooked', sources());
      expect(status(cooked), 'record');
      expect(cooked['confirmed'], {'state': 'cooked'});
      final raw = await answerState(items[1], 'raw', sources());
      expect(status(raw), 'record', reason: 'one raw potato record, it says "with skin", and there is no general raw potato: confirmed, never taken');
      expect(optionNames(raw), ['Potato · Raw · with skin']);
    });
  });

  group('everyday defaults and explicit words', () {
    test('"2 eggs": USDA\'s general cooked egg, no question, said as general with its standard size; nothing fried, no oil or butter', () async {
      final eggs = (await resolveMeal([said('eggs', 2, 'piece', 'egg')], sources())).single;
      expect((status(eggs), id(eggs), eggs['general']), ('ready', 'eggs-cooked', true));
      expect(part(eggs).amount, '2 eggs (100 g)', reason: 'the gram equivalent is shown');
      expect((eggs['part'] as Map)['standard'], '1 egg (50 g)', reason: 'a standard size, not one the person gave: said on the card');
      final t = traitsOf(catalog.foods.firstWhere((f) => f.id == 'eggs-cooked').attrs);
      expect([t[Attr.method], t[Attr.addedFat]], [{'*'}, {'*'}], reason: 'neither a way of cooking nor any fat is claimed');
    });

    test('explicit words override the default: raw eggs, egg whites, fried eggs, boiled eggs', () async {
      Future<String> idOf(String words) async => id((await resolveMeal([said(words, 2, 'piece', 'egg')], sources())).single);
      expect(await idOf('raw eggs'), 'eggs');
      expect(await idOf('egg whites'), 'egg-whites');
      expect(await idOf('fried eggs'), 'eggs-fried');
      expect(await idOf('boiled eggs'), 'eggs-boiled');
      expect((await resolveMeal([said('fried eggs', 2, 'piece', 'egg')], sources())).single['general'], isNull, reason: 'a specific record is not general');
    });

    test('potatoes: general when the preparation is not said; the record said when it is', () async {
      Future<Json> one(String words) async => (await resolveMeal([said(words, 150, 'g')], sources())).single;
      expect(id(await one('cooked potatoes')), 'potato-nfs');
      expect([id(await one('boiled peeled potatoes')), (await one('boiled peeled potatoes'))['general']], ['potato-boiled-peeled', null]);
      expect([id(await one('baked potato with skin')), (await one('baked potato with skin'))['general']], ['potato', null]);
      expect([id(await one('boiled potatoes')), (await one('boiled potatoes'))['general']], ['potato-boiled-nfs', true], reason: 'boiled said, the peel not: USDA\'s boiled potato with the peel not specified');
    });

    test('"100 g roasted skinless chicken breast and 100 g boiled peeled potatoes": used directly, nothing asked', () async {
      final items = await resolveMeal([said('roasted skinless chicken breast', 100, 'g'), said('boiled peeled potatoes', 100, 'g')], sources());
      expect([for (final i in items) status(i)], ['ready', 'ready']);
      expect([id(items[0]), id(items[1])], ['chicken-breast', 'potato-boiled-peeled']);
    });

    test('"100 g chicken and 100 g potato": raw or cooked first (it decides what the weight means), then general defaults; both amounts kept', () async {
      final items = await resolveMeal([said('chicken', 100, 'g'), said('potato', 100, 'g')], sources());
      expect([for (final i in items) status(i)], ['state', 'state']);
      final chicken = await answerState(items[0], 'cooked', sources());
      expect((status(chicken), id(chicken), chicken['general'], part(chicken).quantity), ('ready', 'chicken-cooked-nfs', true, 100.0),
          reason: 'USDA\'s chicken with part, way and skin not specified: never taken as breast');
      final rawChicken = await answerState(items[0], 'raw', sources());
      expect(rawChicken['unresolved'], ['cut', 'skin'], reason: 'no general raw chicken: breast or thigh, skin or not');
      expect(status(items[1]), 'state', reason: 'the potato is untouched while the chicken is answered');
    });

    test('rice, pasta, ground beef, milk, yogurt and bread: a general record when one exists, a choice when not', () async {
      Future<Json> cooked(String w, [String state = 'cooked']) async => answerState((await resolveMeal([said(w, 150, 'g')], sources())).single, state, sources());
      expect([id(await cooked('rice')), (await cooked('rice'))['general']], ['rice-cooked-nfs', true]);
      expect(optionNames(await cooked('rice', 'raw')), ['White rice · Dry · uncooked', 'Brown rice · Dry · uncooked'], reason: 'no general dry rice: white or brown');
      expect(id(await cooked('pasta', 'raw')), 'pasta-dry', reason: 'plain "pasta" means regular pasta');
      expect([id(await cooked('ground beef')), (await cooked('ground beef'))['general']], ['ground-beef-cooked-nfs', true]);
      final milk = (await resolveMeal([said('milk', 1, 'piece', 'glass')], sources())).single;
      expect((status(milk), milk['general'], (milk['food'] as Map)['name']), ('amount', true, 'Milk'), reason: 'general milk; a glass names no amount, so it is asked, never converted');
      final yogurt = (await resolveMeal([said('yogurt', 1, 'piece', 'yogurt')], sources())).single;
      expect((status(yogurt), yogurt['general']), ('amount', true), reason: 'one yogurt names no container weight');
      final greek = (await resolveMeal([said('greek yogurt', 170, 'g')], sources())).single;
      expect((id(greek), greek['general']), ('greek-yogurt-plain', true));
      final bread = (await resolveMeal([said('bread', 2, 'piece', 'slice')], sources())).single;
      expect(optionNames(bread), ['Whole wheat bread · Sliced loaf', 'White bread · Sliced loaf'], reason: 'no general bread record: which bread');
      expect(status(chooseRecord(bread, 1)), 'amount', reason: 'several slice sizes: the person chooses, never an assumed one');
    });

    test('one record found is not proof, and a contradicting one is no candidate', () async {
      final one = [usda('900', 'Chicken, roasted')];
      final f = IdeaSources(seen: [for (final i in one) candidateOf(i)]);
      final item = (await resolveMeal([said('chicken', 100, 'g', null, '100 g cooked chicken')], f)).single;
      expect(status(item), 'record', reason: 'an unreviewed record is never a default');
      expect((item['options'] as List).length, 1);
      final raw = (await resolveMeal([said('broccoli', 100, 'g', null, '100 g cooked broccoli')], sources())).single;
      expect(status(raw), 'missing', reason: 'the only broccoli is raw; cooked broccoli was said');
    });

    test('a sandwich or couscous: a mixed dish is never split into a recipe; couscous asks dry or cooked', () async {
      final searched = <String>[];
      final sandwich = (await resolveMeal([said('sandwich', 1, 'piece', 'sandwich')], sources(searched: searched, search: (q) => const []))).single;
      expect(status(sandwich), 'missing', reason: 'nothing suitable: Find food, no ingredients invented');
      expect(searched, ['sandwich']);
      final couscous = await answerState((await resolveMeal([said('couscous', 150, 'g')], sources())).single, 'cooked', sources());
      expect((status(couscous), id(couscous)), ('ready', 'couscous'));
    });
  });

  group('retrieval and compatibility', () {
    test('relevant records on the phone that cannot show what was said do not stop the search: grilled chicken breast, cooked broccoli', () async {
      final searched = <String>[];
      final grilled = usda('2705968', 'Chicken breast, grilled without sauce, skin not eaten');
      final item = (await resolveMeal([said('grilled skinless chicken breast', 100, 'g')], sources(searched: searched, search: (q) => [grilled]))).single;
      expect(searched, ['chicken breast'], reason: 'no bundled breast shows "grilled": the search is asked');
      expect([for (final o in item['options'] as List) FoodItem(((o as Map)['item'] as Map).cast()).sourceId], contains('2705968'));
      final broccoli = (await resolveMeal([said('broccoli', 100, 'g', null, '100 g cooked broccoli')], sources(search: (q) => [usda('7', 'Broccoli, cooked, boiled')]))).single;
      expect(status(broccoli), 'record', reason: 'found by the search, confirmed by the person');
      // An adequate bundled match asks nothing more.
      final none = <String>[];
      await resolveMeal([said('eggs', 2, 'piece', 'egg')], sources(searched: none, search: (q) => const []));
      expect(none, isEmpty);
    });

    test('an answer from the server deployed now (no evidence): only the person\'s sentence counts as said; the same everyday defaults apply', () async {
      // The model wrote "chicken breast" and "roasted" for "chicken": not in the sentence, not taken as said.
      final old = (name: 'chicken breast', label: 'chicken', preparation: 'roasted', brand: null, quantity: 100.0, unit: 'g', noun: null, evidence: null);
      final f = withSentence(old, 'I ate 100 g of chicken');
      expect(f.evidence, 'I ate 100 g of chicken');
      expect(foodPart(f, f.evidence!), 'I ate 100 g of chicken');
      expect(status((await resolveMeal([f], sources())).single), 'state', reason: 'raw or cooked was not said; neither was the cut nor "roasted"');
      final eggs = withSentence((name: 'egg', label: 'eggs', preparation: null, brand: null, quantity: 2.0, unit: 'piece', noun: 'egg', evidence: null), 'two eggs');
      final e = (await resolveMeal([eggs], sources())).single;
      expect((id(e), e['general']), ('eggs-cooked', true));
      // Words the person did say stay said.
      final said2 = withSentence((name: 'potatoes', label: 'boiled potatoes', preparation: 'boiled', brand: null, quantity: 100.0, unit: 'g', noun: null, evidence: null), 'I had 100 g of boiled potatoes');
      expect(id((await resolveMeal([said2], sources())).single), 'potato-boiled-nfs');
    });
  });

  group('mixed foods: one food\'s words never stand for another\'s', () {
    SaidFood food(String name, String label, String? prep, double q, {String? evidence}) =>
        (name: name, label: label, preparation: prep, brand: null, quantity: q, unit: 'g', noun: null, evidence: evidence);

    for (final shape in ['deployed (no evidence)', 'new (per-food evidence)']) {
      final old = shape.startsWith('deployed');
      test('$shape: "100 g of boiled potatoes and 100 g of chicken" — "boiled" is the potatoes\', never the chicken\'s', () async {
        const sentence = 'I had 100 g of boiled potatoes and 100 g of chicken';
        // The model copied "boiled" onto the chicken too.
        final foods = [
          food('potatoes', 'boiled potatoes', 'boiled', 100, evidence: old ? null : '100 g of boiled potatoes'),
          food('chicken', 'boiled chicken', 'boiled', 100, evidence: old ? null : '100 g of chicken'),
        ];
        final items = await resolveMeal([for (final f in foods) withSentence(f, sentence)], sources());
        expect((id(items[0]), items[0]['general']), ('potato-boiled-nfs', true), reason: 'boiled said of the potatoes; the peel was not');
        expect(status(items[1]), 'state', reason: 'nothing was said about how the chicken was cooked: raw or cooked is asked for its 100 g');
        final cooked = await answerState(items[1], 'cooked', sources());
        expect((id(cooked), cooked['general']), ('chicken-cooked-nfs', true), reason: 'the general cooked chicken, never "boiled" from the potatoes');
      });

      test('$shape: "raw carrots and 120 g of cooked chicken" — raw is the carrots\', cooked is the chicken\'s', () async {
        const sentence = 'I had 80 g of raw carrots and 120 g of cooked chicken';
        // The model wrote "raw" on the chicken.
        final foods = [
          food('carrots', 'raw carrots', 'raw', 80, evidence: old ? null : '80 g of raw carrots'),
          food('chicken', 'chicken', 'raw', 120, evidence: old ? null : '120 g of cooked chicken'),
        ];
        final items = await resolveMeal([for (final f in foods) withSentence(f, sentence)], sources());
        expect((status(items[0]), id(items[0])), ('ready', 'carrots'));
        expect((id(items[1]), items[1]['general']), ('chicken-cooked-nfs', true), reason: 'cooked, from the chicken\'s own words; never raw');
      });
    }

    test('a span naming two foods says nothing of either\'s details (a too-wide evidence, or "with")', () async {
      // New shape, but the model gave a span covering both foods for the chicken.
      final wide = food('chicken', 'chicken', null, 100, evidence: 'boiled potatoes with 100 g of chicken');
      expect(foodPart(wide, wide.evidence!), '', reason: 'one part names potatoes and chicken: not this food\'s alone');
      expect(status((await resolveMeal([wide], sources())).single), 'state', reason: '"boiled" is not taken for the chicken');
      // Arabic and French joins split the same way.
      final ar = food('chicken', 'دجاج مطبوخ', null, 100);
      expect(foodPart(ar, 'أكلت بطاطس مسلوقة و دجاج مطبوخ'), 'دجاج مطبوخ');
      final fr = food('potatoes', 'pommes de terre bouillies', null, 100);
      expect(foodPart(fr, 'du poulet et des pommes de terre bouillies'), 'des pommes de terre bouillies');
    });
  });

  group('what was said is respected', () {
    test('contradictions exclude: raw is never cooked, skin eaten is never skinless, another brand is never the brand said', () async {
      final skin = (await resolveMeal([said('chicken breast with skin', 100, 'g', null, '100 g cooked chicken breast with skin')], sources())).single;
      expect(id(skin), 'chicken-breast-cooked-skin', reason: 'cooked and skin said; the way of cooking was not, so the record that does not specify it');
      final rawSkinless = (await resolveMeal([said('raw skinless chicken thigh', 100, 'g')], sources())).single;
      expect(id(rawSkinless), 'chicken-thigh-raw');
      final brands = [usda('1', 'GREEK YOGURT', brand: 'CHOBANI'), usda('2', 'GREEK YOGURT', brand: 'OIKOS')];
      final chobani = (await resolveMeal([said('greek yogurt', 170, 'g', null, '170 g Chobani greek yogurt', 'Chobani')], sources(search: (q) => brands))).single;
      expect([for (final o in chobani['options'] as List) FoodItem(((o as Map)['item'] as Map).cast()).brand], ['CHOBANI'],
          reason: 'only the brand said; a generic record cannot show a brand either');
    });

    test('negation and other languages: "without skin", "sans peau", "بدون جلد", "skin not eaten" all mean the same', () {
      for (final words in ['chicken thigh without skin', 'cuisse de poulet sans peau', 'فخذ دجاج بدون جلد', 'Chicken thigh, skin not eaten', 'skinless chicken thigh']) {
        final t = readTraits(words);
        expect([t[Attr.family], t[Attr.cut], t[Attr.skin]], [{'chicken'}, {'thigh'}, {'no'}], reason: words);
      }
      expect(readTraits('pommes de terre bouillies avec la peau')[Attr.skin], {'yes'});
      expect(readTraits('Chicken breast, baked, broiled, or roasted, skin not eaten, from raw')[Attr.state], {'cooked'}, reason: '"from raw" is what it was made from');
      expect(readTraits('Fish, salmon, Atlantic, farmed, cooked, dry heat')[Attr.state], {'cooked'}, reason: '"dry heat" is a way of cooking, not dry food');
      expect(readTraits('riz blanc cuit')[Attr.variety], {'white'});
      expect(readTraits('blanc de poulet')[Attr.cut], {'breast'});
    });

    test('a detail the model added but the person did not say is not taken as said (the person\'s words are the evidence)', () async {
      // The model wrote "chicken breast" for "chicken": only the person's words count.
      final f = (name: 'chicken breast', label: 'chicken', preparation: 'roasted', brand: null, quantity: 100.0, unit: 'g', noun: null, evidence: '100 g of chicken');
      expect(status((await resolveMeal([f], sources())).single), 'state', reason: 'neither the cut nor "roasted" was said');
    });
  });

  group('retrieval', () {
    test('a saved or seen record is considered beside the catalog, never in its place; it is never taken without asking', () async {
      final mine = usda('77', 'Chicken thigh, cooked, skin not eaten');
      final item = (await resolveMeal([said('cooked chicken thighs', 100, 'g')], sources(mine: [mine]))).single;
      expect(status(item), 'record');
      expect([for (final o in item['options'] as List) FoodItem(((o as Map)['item'] as Map).cast()).sourceId], contains('77'));
    });

    test('the food search is asked once per query, and a failed search keeps the item for Try again', () async {
      final searched = <String>[];
      final items = await resolveMeal([said('dragonfruit', 100, 'g'), said('dragonfruit', 50, 'g')], sources(searched: searched, search: (q) => const []));
      expect(searched, ['dragonfruit'], reason: 'the same words are not searched twice in one request');
      expect(status(items.first), 'missing');
      final offline = (await resolveMeal([said('dragonfruit', 100, 'g')], sources(fails: true))).single;
      expect(status(offline), 'unavailable');
      final again = await retryItem(offline, sources(search: (q) => [usda('5', 'Dragonfruit, raw')]));
      expect(status(again), 'record', reason: 'found on the explicit Try again, still confirmed by the person');
    });
  });

  group('estimates and changes', () {
    test('"I\'m not sure" uses a real record, says so in its name, and keeps the said amount', () async {
      // Cooked chicken thighs ask about the skin; "I'm not sure" offers USDA's general cooked chicken, disclosed first, and
      // said to be another record than a thigh (it cannot show "thigh").
      final thighs = (await resolveMeal([said('cooked chicken thighs', 100, 'g')], sources())).single;
      expect(((thighs['estimate'] as Map)['generic'], (thighs['estimate'] as Map)['substitute']), (true, true));
      final e = acceptEstimate(thighs, (n) => '$n (estimate)');
      expect((status(e), part(e).name, part(e).quantity, part(e).item.sourceId), ('ready', 'Chicken (estimate)', 100.0, '2705929'));
      expect(e['estimate'], isNotNull);
    });

    test('a follow-up amount keeps the chosen record and confirmed details', () async {
      final thigh = chooseRecord((await resolveMeal([said('cooked chicken thighs', 100, 'g')], sources())).single, 1);
      final edited = await applyMealEdits([thigh], [(op: 'amount', ref: 'd1', food: said('chicken thighs', 150, 'g'))], sources());
      expect((status(edited.items.single), part(edited.items.single).quantity, part(edited.items.single).item.sourceId), ('ready', 150.0, part(thigh).item.sourceId));
    });
  });

  test('every family profile names only known attributes, and the catalog\'s reviewed details are readable', () {
    for (final f in catalog.foods) {
      expect(() => traitsOf(f.attrs), returnsNormally, reason: f.id);
      expect(traitsOf(f.attrs)[Attr.family], isNotNull, reason: '${f.id} has a family');
    }
  });
}
