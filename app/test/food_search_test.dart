import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/nutrition/food_search.dart';

import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart' show foodEntry;

/// Finding foods by name: the bundled catalog, the relevance rule, and what the phone can answer on its own.
void main() {
  final catalog = shippedCatalog();
  ({List<Suggestion> own, List<Suggestion> common}) find(String q, {List<Json> saved = const [], List<FoodEntry> journal = const [], List<FoodItem> seen = const [], String? category}) =>
      searchLocal(q, catalog: catalog, saved: saved, journal: journal, seen: seen, category: category);
  List<String> ids(String q, {String? category}) => [for (final s in find(q, category: category).common) s.common!.id];

  group('the bundled catalog', () {
    final raw = jsonDecode(File('assets/data/common-foods.json').readAsStringSync()) as Json;

    test('declares its version and where its values come from', () {
      expect(raw['version'], isA<int>());
      expect(catalog.version, greaterThanOrEqualTo(1));
      final provenance = raw['provenance'] as Json;
      expect(provenance['source'], contains('USDA FoodData Central'));
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(provenance['retrieved'] as String), isTrue);
      expect((provenance['method'] as String).length, greaterThan(40));
      expect(catalog.categories, ['Proteins', 'Carbohydrates', 'Vegetables', 'Fruits', 'Dairy', 'Fats & Oils', 'Snacks', 'Beverages']);
    });

    test('every entry is a whole, valid, uniquely identified food', () {
      expect(catalog.foods.length, greaterThanOrEqualTo(60));
      expect({for (final f in catalog.foods) f.id}.length, catalog.foods.length, reason: 'ids are unique');
      expect({for (final f in catalog.foods) f.item.key}.length, catalog.foods.length, reason: 'one record stands for one everyday food');
      for (final f in catalog.foods) {
        final why = f.id;
        expect(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(f.id), isTrue, reason: why);
        expect((f.name.trim().isNotEmpty, f.qualifier.trim().isNotEmpty, f.item.name.trim().isNotEmpty), (true, true, true), reason: why);
        expect(catalog.categories, contains(f.category), reason: why);
        expect((f.item.source, RegExp(r'^\d+$').hasMatch(f.item.sourceId ?? '')), ('usda', true), reason: '$why: a real FoodData Central record');
        expect(f.item.brand, isNull, reason: '$why: a generic food, not a product');
        expect([FoodItem.per100g, FoodItem.per100ml, FoodItem.perServing], contains(f.item.basis), reason: why);
        expect(f.item.nutrients.keys.toSet(), FoodItem.nutrientKeys.toSet(), reason: why);
        for (final key in FoodItem.nutrientKeys) {
          final v = f.item.nutrient(key);
          expect(v == null || (v.isFinite && v >= 0), isTrue, reason: '$why $key: unknown or a value, never negative');
        }
        for (final s in f.item.servings) {
          expect(s.label.trim().isNotEmpty && ((s.grams ?? 0) > 0 || (s.milliliters ?? 0) > 0), isTrue, reason: '$why: every portion has a stated weight or volume');
          expect(s.isUserDefined, isFalse, reason: '$why: only the source\'s portions');
        }
        expect(f.aliases.every((a) => a.trim().isNotEmpty), isTrue, reason: why);
        // The portion a new entry starts from is one the record itself states.
        if (f.portion != null) expect([for (final s in f.item.servings) s.label], contains(f.portion), reason: why);
        expect(FoodScaling.units(f.item).map((u) => u.id), contains(f.unitId), reason: why);
        expect(sourceCredit(f.item), 'USDA FoodData Central', reason: why);
      }
    });

    test('the app reads the same catalog from its own bundle', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final bundled = await container.read(commonFoodsProvider.future);
      expect((bundled.version, bundled.foods.length), (catalog.version, catalog.foods.length));
    });
  });

  group('what a search understands', () {
    test('case, spacing, accents and ligatures do not matter; simple plurals are one word', () {
      expect(normalizeSearch('  Œufs   BROUILLÉS '), 'oeufs brouilles');
      expect(normalizeSearch('Crème brûlée, 2%'), 'creme brulee 2%');
      expect(searchWords('Eggs, Tomatoes & blueberries'), ['egg', 'tomato', 'blueberry']);
      expect(searchWords('Œufs'), searchWords('oeuf'));
      expect(searchWords('glass'), ['glass'], reason: 'not every final s is a plural');
    });

    test('an exact name beats a beginning, which beats a word, which beats part of a word', () {
      int? score(String q, String name, {List<String> aliases = const [], String? qualifier, String? brand}) => matchScore(q, SearchFields(name, aliases: aliases, qualifier: qualifier, brand: brand));
      expect(score('eggs', 'Eggs'), 0);
      expect(score('egg', 'Eggs', aliases: ['oeuf']), 0);
      expect(score('OEUF', 'Eggs', aliases: ['œuf']), 0);
      expect(score('rice', 'Rice, white, cooked'), 1, reason: 'the head of a provider title');
      expect(score('nutella', 'Hazelnut spread', brand: 'Nutella, Ferrero'), 1, reason: 'the brand, exactly');
      expect(score('rice', 'Rice cakes'), 2);
      expect(score('chick', 'Chicken breast'), 2, reason: 'the word still being typed');
      expect(score('rice', 'Snacks, rice cakes'), 3);
      expect(score('raw egg', 'Eggs', aliases: ['egg'], qualifier: 'Whole · raw'), 3, reason: 'the preparation is searched too');
      expect(score('bre', 'Chicken breast'), 4);
      expect(score('nut', 'Walnuts'), 5);
      expect(score('chicken soup', 'Chicken breast'), isNull, reason: 'every word has to be found');
      expect(score('', 'Anything'), 0);
    });
  });

  group('everyday queries', () {
    test('egg and eggs: the whole egg first, whites separately named', () {
      for (final q in ['egg', 'eggs', 'Egg ', 'EGGS']) {
        expect(ids(q), ['eggs', 'egg-whites'], reason: q);
      }
      final [whole, whites] = [for (final s in find('eggs').common) rowFacts(s)];
      expect((whole.title, whole.detail, whole.basis, whole.calories, whole.protein), ('Eggs', 'Whole · raw', '1 egg (50 g)', 71.5, 6.2));
      expect((whites.title, whites.detail, whites.basis), ('Egg whites', 'Whites only · raw', '1 egg white (33 g)'));
    });

    test('chicken breast: an identifiable breast with its preparation', () {
      final first = find('chicken breast').common.first;
      expect((first.common!.id, rowFacts(first).title), ('chicken-breast', 'Chicken breast'));
      expect(rowFacts(first).detail, allOf(contains('skinless'), contains('roasted')));
      expect(first.item.name, contains('skin not eaten'), reason: 'the record itself is a cooked, skinless breast');
      expect(ids('chicken').first, 'chicken-breast');
    });

    test('rice: plain rice above rice cakes, which stay a snack', () {
      expect(ids('rice'), ['brown-rice', 'white-rice', 'rice-cakes']);
      expect([for (final s in find('rice').common) s.common!.category], ['Carbohydrates', 'Carbohydrates', 'Snacks']);
      expect([for (final s in find('rice').common) rowFacts(s).title], ['Brown rice', 'White rice', 'Rice cakes']);
      expect(ids('rice cake'), ['rice-cakes']);
    });

    test('French names and accents find the same foods', () {
      expect(ids('œuf').first, 'eggs');
      expect(ids('oeufs').first, 'eggs');
      expect(ids('riz').take(2), ['brown-rice', 'white-rice']);
      expect(ids('poitrine de poulet'), ['chicken-breast']);
      expect(ids('blanc de poulet'), ['chicken-breast']);
      expect(ids('pâtes'), ['whole-wheat-pasta']);
      expect(ids('epinards'), ['spinach']);
      expect(ids('lait écrémé').first, 'skim-milk');
    });

    test('plurals, and foods that differ only by how they are prepared or how fat they are, stay apart', () {
      expect([ids('bananas'), ids('tomatoes'), ids('blueberry')], [['banana'], ['tomato'], ['blueberries']]);
      final milk = [for (final s in find('milk').common) '${rowFacts(s).title} · ${rowFacts(s).detail}'];
      expect(milk.take(2), ['Milk 2% · Reduced fat', 'Skim milk · Fat free'], reason: 'the two milks, each named for what it is');
      expect(milk, contains('Almond milk · Unsweetened'));
      expect([for (final s in find('raw egg').common) rowFacts(s).detail], ['Whole · raw', 'Whites only · raw']);
      expect({for (final f in catalog.foods) '${f.name} · ${f.qualifier}'}.length, catalog.foods.length, reason: 'no two rows read the same');
    });

    test('a category filters real records only, and nothing unclassified slips through', () {
      final vegetables = find('', category: 'Vegetables');
      expect(vegetables.common.length, catalog.foods.where((f) => f.category == 'Vegetables').length);
      expect(vegetables.common.every((s) => s.common!.category == 'Vegetables'), isTrue);
      expect(ids('rice', category: 'Snacks'), ['rice-cakes']);
      expect(ids('egg', category: 'Fruits'), isEmpty);

      // The owner's own oats and a branded product have no category: under one, they are not shown at all.
      final mine = find('o', saved: [savedFood('s-oats', ownOats())], seen: [hazelnutSpread()], category: 'Carbohydrates');
      expect(mine.own, isEmpty);
      expect(mine.common.map((s) => s.common!.id), contains('oatmeal'));
      // The catalog's own record, kept as a favourite, keeps its category: it is the same food.
      final eggs = catalog.foods.firstWhere((f) => f.id == 'eggs');
      final kept = find('egg', saved: [savedFood('s-egg', eggs.item, favourite: true)], category: 'Proteins');
      expect([[for (final s in kept.own) s.common!.id], [for (final s in kept.common) s.common!.id]], [['eggs'], ['egg-whites']]);
    });
  });

  group('the owner\'s foods and brands', () {
    final chobani = FoodItem({'source': 'usda', 'sourceId': '900001', 'name': 'Greek Yogurt, Vanilla', 'brand': 'Chobani', 'basis': '100g', 'nutrients': {'calories': 80, 'protein': 8, 'carbs': 9, 'fat': null}, 'servings': []});

    test('a brand that is asked for is found, and is not buried under generic foods', () {
      final byBrand = find('chobani', seen: [chobani, hazelnutSpread()]);
      expect([for (final s in byBrand.own) s.item.name], ['Greek Yogurt, Vanilla']);
      expect(byBrand.common, isEmpty, reason: 'no generic food answers to a brand');
      expect(rowFacts(byBrand.own.single).detail, 'Chobani', reason: 'the row says whose it is');
      expect([for (final s in find('ferrero', seen: [chobani, hazelnutSpread()]).own) s.item.name], ['Nutella']);

      // A plain name finds both, and each stays what it is.
      final both = find('greek yogurt', seen: [chobani]);
      expect([[for (final s in both.own) rowFacts(s).detail], [for (final s in both.common) rowFacts(s).title]], [['Chobani'], ['Greek yogurt']]);
      expect(rowFacts(both.own.single).protein, 8);
    });

    test('foods are one food only when they are the same record; a similar name never merges them', () {
      final eggs = catalog.foods.firstWhere((f) => f.id == 'eggs');
      final myEggs = FoodItem({'source': 'user', 'sourceId': 'mine-1', 'name': 'Eggs', 'basis': 'serving', 'nutrients': {'calories': 90, 'protein': 7, 'carbs': null, 'fat': null}, 'servings': [{'label': '1 egg', 'grams': null, 'milliliters': null}]});
      final found = find('eggs', saved: [savedFood('mine-1', myEggs)], seen: [FoodItem(copyJson(eggs.item.j))]);
      expect([for (final s in found.own) (s.origin, s.item.key, rowFacts(s).calories)], [(Origin.mine, 'user:mine-1', 90.0), (Origin.seen, 'usda:2707152', 71.5)],
          reason: 'the user\'s own "Eggs" keeps its own values; the record seen before is the catalog egg');
      expect([for (final s in found.common) s.common!.id], ['egg-whites'], reason: 'the egg already listed is not listed twice');
      expect(rowFacts(found.own.last).title, 'Eggs', reason: 'the same record reads the same wherever it is met');
    });

    test('a wider answer is put in the app\'s order, without what is already listed, and loses nothing', () {
      FoodItem usda(String id, String name) => FoodItem({'source': 'usda', 'sourceId': id, 'name': name, 'basis': '100g', 'nutrients': {'calories': 100, 'protein': null, 'carbs': null, 'fat': null}, 'servings': []});
      final white = catalog.foods.firstWhere((f) => f.id == 'white-rice');
      final answer = [usda('1', 'Snacks, rice cakes, brown rice, buckwheat'), usda('2', 'Rice cake'), usda('3', 'Wild thing, NFS'), white.item, usda('4', 'Rice, cooked, NFS')];
      final ranked = rankFound('rice', answer, catalog: catalog, shown: {white.item.key});
      expect([for (final s in ranked) s.item.name], ['Rice, cooked, NFS', 'Rice cake', 'Snacks, rice cakes, brown rice, buckwheat', 'Wild thing, NFS']);
      expect(rankFound('rice', answer, catalog: catalog).firstWhere((s) => s.item.key == white.item.key).common!.name, 'White rice');
    });

    test('a row states its basis and never turns an unknown value into a number', () {
      final salmon = find('salmon').common.single;
      expect((rowFacts(salmon).basis, rowFacts(salmon).calories), ('100 g', 206));
      final drink = rowFacts(Suggestion(sparseDrink(), Origin.found));
      expect((drink.basis, drink.calories, drink.protein, drink.detail), ('100 ml', 42, null, 'Example Drinks'));
      final jar = rowFacts(Suggestion(ownOats(), Origin.mine));
      expect((jar.basis, jar.calories, jar.detail), ('1 jar', 420, 'My food'));
      final typed = FoodEntry(foodEntry('f', '2026-10-08', 'Lunch', 'Soup', '1 bowl', calories: 250));
      final soup = rowFacts(localSuggestions(saved: const [], journal: [typed], seen: const []).single);
      expect((soup.title, soup.detail, soup.basis, soup.calories, soup.protein), ('Soup', 'As you logged it', '1 bowl', 250, null));
    });

    test('a catalog food starts in its stated portion; the food logged is the provider\'s record, untouched', () {
      final eggs = catalog.foods.firstWhere((f) => f.id == 'eggs');
      final before = jsonEncode(eggs.item.j);
      final draft = FoodDraft.of(eggs.item, dayKey: '2026-10-09', meal: 'Breakfast', name: eggs.name, unitId: eggs.unitId);
      expect((draft.name, draft.amount, draft.quantity, draft.unitId, draft.calories, draft.item!.name), ('Eggs', '1 egg (50 g)', 1, 'serving:0', 71.5, 'Egg, whole, raw'));
      expect(jsonEncode(FoodRepository.sourceFields(draft)['source']['item']), before, reason: 'the meal\'s snapshot is the record as the source gave it');
      final salmon = catalog.foods.firstWhere((f) => f.id == 'salmon');
      final plain = FoodDraft.of(salmon.item, dayKey: '2026-10-09', meal: 'Dinner', name: salmon.name, unitId: salmon.unitId);
      expect((plain.amount, plain.quantity, plain.unitId), ('100 g', 100, 'g'));
    });
  });

  group('amounts said in another unit', () {
    test('grams to a portion and back is the amount it started as, with nothing lost on the way', () {
      final rice = catalog.foods.firstWhere((f) => f.id == 'white-rice').item;
      final g = FoodScaling.unit(rice, 'g'), cup = FoodScaling.unit(rice, 'serving:0');
      expect(cup.basisPerUnit, 1.58);
      for (final grams in [1.0, 45.0, 100.0, 123.45, 333.0, 1000.0]) {
        final there = FoodScaling.exact(grams, g, cup), back = FoodScaling.exact(there, cup, g);
        expect(back, closeTo(grams, 1e-9), reason: '$grams g');
        expect(FoodScaling.scale(rice, there, cup), FoodScaling.scale(rice, grams, g), reason: '$grams g: the same food, so the same values');
      }
      // Rounding the amount itself on the way is what lost it before: 100 g became 0.63 cup, then 99.54 g.
      expect(FoodScaling.convert(FoodScaling.convert(100, g, cup), cup, g), 99.54);
    });

    test('count portions scale exactly and an unknown value stays unknown in every unit', () {
      final eggs = catalog.foods.firstWhere((f) => f.id == 'eggs').item;
      final egg = FoodScaling.unit(eggs, 'serving:0');
      expect((FoodScaling.describe(eggs, 2, egg), FoodScaling.describe(eggs, 0.5, egg), FoodScaling.scale(eggs, 2, egg)['calories']), ('2 eggs (100 g)', '½ egg (25 g)', 143));
      final drink = sparseDrink();
      final can = FoodScaling.unit(drink, 'serving:0'), ml = FoodScaling.unit(drink, 'ml');
      final inMl = FoodScaling.exact(1.5, can, ml);
      expect(inMl, closeTo(495, 1e-9));
      expect(FoodScaling.scale(drink, inMl, ml), {'calories': 207.9, 'protein': null, 'carbs': null, 'fat': null});
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

    Future<({List<Suggestion> own, List<Suggestion> common})> search(String who, String q) async => searchLocal(q,
        catalog: catalog, saved: await h.bodies(who, Kinds.savedFood), journal: [for (final j in await h.bodies(who, Kinds.food)) FoodEntry(j)],
        seen: [for (final c in await FoodDiscovery(Api(h.server, h.sessions), h.sync, who, h.clock).cached()) c.item]);

    test('common and saved foods are found with no connection and after a restart; another account sees only the common ones', () async {
      h.server.lookups['/foods/search?q=hazelnut'] = ApiResponse(200, {'results': [hazelnutSpread().j]});
      await FoodDiscovery(Api(h.server, h.sessions), h.sync, owner, h.clock).search('hazelnut');   // seen once, online
      h.server.offline = true;
      await SavedFoodRepository(h.sync, owner).saveMine(name: 'Egg muffin', values: {'calories': 310, 'protein': 17, 'carbs': null, 'fat': null}, amount: '1 muffin');
      final eggs = catalog.foods.firstWhere((f) => f.id == 'eggs');
      await FoodRepository(h.sync, owner).save(FoodDraft.of(eggs.item, dayKey: '2026-10-09', meal: 'Breakfast', name: eggs.name, unitId: eggs.unitId));

      await h.restart();
      final found = await search(owner, 'egg');
      expect([for (final s in found.own) '${s.origin.name}:${rowFacts(s).title}'], ['recent:Eggs', 'mine:Egg muffin'], reason: 'the best match first: the egg logged before, then the user\'s own muffin');
      expect([for (final s in found.common) s.common!.id], ['egg-whites']);
      expect([for (final s in (await search(owner, 'nutella')).own) s.item.name], ['Nutella'], reason: 'a product seen before, still offline');
      expect(h.server.callsTo('/foods/search').length, 1, reason: 'none of this asked the server anything more');

      // The meal logged keeps the record exactly as the catalog had it.
      final logged = FoodEntry((await h.bodies(owner, Kinds.food)).single);
      expect((logged.name, logged.amountDescription, jsonEncode(logged.source!['item'])), ('Eggs', '1 egg (50 g)', jsonEncode(eggs.item.j)));

      await h.sessions.signOut();
      final two = await h.signIn('two');
      final other = await search(two, 'egg');
      expect(other.own, isEmpty, reason: 'private foods stay with their owner');
      expect([for (final s in other.common) s.common!.id], ['eggs', 'egg-whites'], reason: 'the catalog is the same for every account');
      expect((await search(two, 'nutella')).own, isEmpty);
    });
  });
}
