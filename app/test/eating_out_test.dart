import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/eating_out.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/restaurants.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';

import 'support.dart';

/// Eating out (docs/EATING_OUT.md): the verified catalog, the order arithmetic, the ranking rule, reading the server's
/// interpretation, and logging/saving through the ordinary journal and saved meals on the real database.

final catalogText = File('assets/data/restaurant-catalog.json').readAsStringSync();
final catalog = RestaurantCatalog.parse(catalogText)!;
final subway = catalog.chain('subway-ca')!, pizza = catalog.chain('pizzapizza-ca')!;
const chicken = 'subway-ca:rotisserie-chicken-6in', chickenFoot = 'subway-ca:rotisserie-chicken-footlong', rings = 'subway-ca:potato-rings-4', tuna = 'subway-ca:tuna-6in';
const pepperoni = 'pizzapizza-ca:small-pepperoni-slice';

void main() {
  group('the catalog', () {
    test('the app bundles exactly the API\'s reviewed catalog', () {
      expect(catalogText, File('../api/src/GoHard.Api/Data/restaurant-catalog.json').readAsStringSync());
    });

    test('four Canadian chains, each from its own official source, with honest dates', () {
      expect([for (final c in catalog.chains) (c.id, c.j['country'], c.available)],
          [('mcdonalds-ca', 'CA', true), ('timhortons-ca', 'CA', true), ('subway-ca', 'CA', true), ('pizzapizza-ca', 'CA', true)]);
      final mcd = catalog.chain('mcdonalds-ca')!, tims = catalog.chain('timhortons-ca')!;
      expect(mcd.sources.single['url'], startsWith('https://www.mcdonalds.com/ca/en-ca/'));
      expect(mcd.sources.single['published'], isNull, reason: 'the calculator states no date: unknown, never invented');
      expect((tims.sources.single['published'], tims.sources.single['checked']), ('2026-07', '2026-10-25'), reason: 'publication and check dates kept apart');
      // Sizes are the source's own stated variants, never a scaled guess: Mini and Medium fries are separate records.
      final mini = mcd.items.firstWhere((i) => i.id == 'mcdonalds-ca:fries-mini'), medium = mcd.items.firstWhere((i) => i.id == 'mcdonalds-ca:world-famous-fries-medium');
      expect((mini.nutrient('calories'), medium.nutrient('calories'), mini.group == medium.group), (120, 350, true));
      // A Double Double is offered only because Tim Hortons states its values; the black coffee stays black.
      expect(tims.item('timhortons-ca:medium-double-double')!.nutrient('calories'), 200);
      expect(tims.item('timhortons-ca:medium-coffee-original')!.nutrient('calories'), 4);
      expect(mcd.items.where((i) => i.role == 'drink' && i.grams != null), isEmpty, reason: 'drinks are stated in mL, not grams');
    });

    test('every offered item has a real source, stable ID, exact portion and plausible stated values', () {
      final ids = <String>{};
      for (final c in catalog.chains.where((c) => c.available)) {
        expect(c.items.length, inInclusiveRange(10, 40), reason: c.id);
        for (final s in c.sources) {
          expect(s['url'], startsWith('https://'), reason: '${s['id']}');
          expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s['checked'] as String), isTrue, reason: 'check date, not publication date');
        }
        for (final i in c.items) {
          expect(ids.add(i.id), isTrue, reason: 'unique ${i.id}');
          expect(i.id, startsWith('${c.id}:'));
          expect(i.portion, matches(RegExp(r'^1 [A-Za-z]')), reason: i.id);
          expect(c.sourceOf(i.source), isNotNull, reason: i.id);
          expect(i.rankable, isTrue, reason: '${i.id}: calories and protein are stated');
          final (kcal, p, carbs, fat) = (i.nutrient('calories')!, i.nutrient('protein')!, i.nutrient('carbs')!, i.nutrient('fat')!);
          expect((4 * p + 4 * carbs + 9 * fat - kcal).abs(), lessThanOrEqualTo(kcal * 0.12 < 25 ? 25 : kcal * 0.12), reason: '${i.id}: energy agrees with macros');
        }
      }
    });

    test('a footlong is exactly two 6-inch subs, as Subway instructs; nothing else is derived', () {
      for (final f in subway.items.where((i) => i.derived)) {
        final six = subway.item(f.j['variantOf'] as String)!;
        expect(f.size, 'Footlong');
        expect(f.group, six.group, reason: 'the same order for variety');
        for (final k in FoodItem.nutrientKeys) {
          expect(f.nutrient(k), six.nutrient(k)! * 2, reason: '${f.id} $k');
        }
        expect(f.grams, six.grams! * 2);
      }
      expect(pizza.items.where((i) => i.derived), isEmpty);
    });

    test('pizza slices name their pizza; an unreliable value stays unknown rather than zero', () {
      final p = pizza.item(pepperoni)!;
      expect(p.portion, '1 slice (1/6 of a 10-inch small pizza)');
      expect(p.extra('satFatG'), isNull, reason: 'the page loses its decimal point: unknown, never 0 and never 35');
      expect(pizza.items.firstWhere((i) => i.id.endsWith('walkin-pepperoni-slice')).portion, '1 Walk-In slice');
      expect(subway.item(chicken)!.extra('sodiumMg'), 920);
    });

    test('a restaurant food converts and describes amounts exactly, with its provenance', () {
      final food = catalog.food(pizza, pizza.item(pepperoni)!);
      final slice = FoodScaling.unit(food, 'serving:0');
      expect(FoodScaling.describe(food, 2, slice), '2 slices (1/6 of a 10-inch small pizza each)');
      expect(FoodScaling.scale(food, 3, slice), {'calories': 630, 'protein': 30, 'carbs': 72, 'fat': 24});
      final sub = catalog.food(subway, subway.item(chicken)!);
      expect(FoodScaling.describe(sub, 2, FoodScaling.unit(sub, 'serving:0')), '2 subs (6-inch each) (488 g)');
      final origin = RestaurantOrigin.of(sub)!;
      expect((origin.chain, origin.catalogVersion, origin.published, origin.checked), ('subway-ca', catalog.version, '2026-10', '2026-10-25'));
      expect(origin.build, contains('does not say which bread'));
      expect(food.key, 'restaurant:$pepperoni', reason: 'its own identity, never USDA, Open Food Facts or the person\'s');
    });
  });

  group('the ranking rule', () {
    void bounded(Suggestion s, OrderPreferences p, RestaurantChain chain) {
      final items = [for (final l in s.order.lines) (chain.item(l.itemId)!, l.quantity)];
      final added = [for (final (i, q) in items) if (!p.keep.containsKey(i.id)) (i, q)];
      expect(added.where((e) => e.$1.role == 'main').length, lessThanOrEqualTo(1), reason: 'no stack of mains');
      expect(added.where((e) => e.$1.role == 'side').length, lessThanOrEqualTo(1));
      for (final (i, q) in added) {
        expect(q, lessThanOrEqualTo(i.maxQuantity));
      }
      for (final e in p.keep.entries) {
        expect(s.order.quantityOf(e.key), e.value, reason: 'kept, with its count');
      }
      for (final x in p.exclude) {
        expect(s.order.quantityOf(x), 0, reason: 'never an excluded item');
      }
    }

    test('fits meet every hard target, keep the kept items, leave out the excluded, and are sorted as shown', () {
      const p = OrderPreferences(maxCalories: 600, minProtein: 25, keep: {rings: 1}, exclude: {tuna});
      final r = OrderPlanner.suggest(subway, p);
      expect(r.sortedBy, OrderPriority.protein, reason: 'a protein target: most protein first');
      expect(r.fits, isNotEmpty);
      expect(r.fits.length, lessThanOrEqualTo(3));
      for (final s in r.fits) {
        expect(s.calories, lessThanOrEqualTo(600));
        expect(s.protein, greaterThanOrEqualTo(25));
        expect(s.fits, isTrue);
        bounded(s, p, subway);
      }
      final proteins = [for (final s in r.fits) s.protein];
      expect(proteins, [...proteins]..sort((a, b) => b.compareTo(a)));
      // Variety: one suggestion per main, and a 6-inch and its footlong count as the same.
      final groups = [for (final s in r.fits) for (final l in s.order.lines) if (l.itemId != rings) subway.item(l.itemId)!.group];
      expect(groups.toSet().length, groups.length);
      expect(OrderPlanner.suggest(subway, p).fits.map((s) => s.order), r.fits.map((s) => s.order), reason: 'deterministic');
    });

    test('totals are the catalog values times the counts', () {
      const order = RestaurantOrder([OrderLine(chicken, 1), OrderLine(rings, 2)]);
      final t = order.totals(subway);
      expect((t[Nutrient.calories]!.knownTotal, t[Nutrient.protein]!.knownTotal, t[Nutrient.calories]!.isComplete), (460 + 2 * 150, 28 + 2 * 2, true));
      expect(const RestaurantOrder([OrderLine(pepperoni, 3)]).total(pizza, Nutrient.calories), 630);
      expect(order.withQuantity(rings, 0).lines, const [OrderLine(chicken, 1)]);
      expect(order.withQuantity(tuna, 1).lines.last, const OrderLine(tuna, 1));
    });

    test('fewest calories and closest to the limit are explicit choices; neither is called healthiest', () {
      final fewest = OrderPlanner.suggest(subway, const OrderPreferences(maxCalories: 700, priority: OrderPriority.calories)).fits;
      expect([for (final s in fewest) s.calories], [for (final s in fewest) s.calories]..sort());
      final closest = OrderPlanner.suggest(subway, const OrderPreferences(maxCalories: 700));
      expect(closest.sortedBy, OrderPriority.closest);
      expect([for (final s in closest.fits) 700 - s.calories], [for (final s in closest.fits) 700 - s.calories]..sort());
    });

    test('prefer narrows the main only; avoid keeps a kind out; pizza slices stay within three', () {
      final sandwiches = OrderPlanner.suggest(subway, const OrderPreferences(maxCalories: 800, prefer: {'sandwich'}));
      for (final s in sandwiches.fits) {
        expect([for (final l in s.order.lines) subway.item(l.itemId)!].where((i) => i.role == 'main').map((i) => i.kind), everyElement('sandwich'));
      }
      expect(sandwiches.fits.any((s) => s.order.lines.any((l) => subway.item(l.itemId)!.role == 'side')), isTrue, reason: 'sides still allowed');
      final noSalad = OrderPlanner.suggest(subway, const OrderPreferences(maxCalories: 300, avoid: {'salad'}));
      for (final s in [...noSalad.fits, ...noSalad.nearest]) {
        expect(s.order.lines.map((l) => subway.item(l.itemId)!.kind), isNot(contains('salad')));
      }
      for (final s in OrderPlanner.suggest(pizza, const OrderPreferences(minProtein: 60)).nearest) {
        bounded(s, const OrderPreferences(minProtein: 60), pizza);
      }
    });

    test('nothing fits: the nearest are labelled with what they miss, and kept items are never relaxed', () {
      const p = OrderPreferences(maxCalories: 300, minProtein: 40, keep: {rings: 1});
      final r = OrderPlanner.suggest(subway, p);
      expect(r.fits, isEmpty);
      expect(r.nearest, isNotEmpty);
      for (final s in r.nearest) {
        expect(s.fits, isFalse);
        expect(s.misses, isNotEmpty);
        expect(s.order.quantityOf(rings), 1);
        bounded(s, p, subway);
      }
    });

    test("McDonald's around 600 kcal with more protein, keeping the mini fries: every suggestion keeps them and fits", () {
      final mcd = catalog.chain('mcdonalds-ca')!;
      const p = OrderPreferences(maxCalories: 600, priority: OrderPriority.protein, keep: {'mcdonalds-ca:fries-mini': 1});
      final r = OrderPlanner.suggest(mcd, p);
      expect(r.fits, isNotEmpty);
      for (final s in r.fits) {
        bounded(s, p, mcd);
        expect(s.calories, lessThanOrEqualTo(600));
      }
      final proteins = [for (final s in r.fits) s.protein];
      expect(proteins, [...proteins]..sort((a, b) => b.compareTo(a)));
      expect(r.fits.first.order.lines.map((l) => l.itemId), isNot(contains('mcdonalds-ca:world-famous-fries-medium')), reason: 'kept is the size kept');
    });

    test('contradictions are not guessed away', () {
      expect(OrderPlanner.suggest(subway, const OrderPreferences(minCalories: 900, maxCalories: 500)).impossible, isTrue);
      expect(OrderPlanner.suggest(subway, const OrderPreferences(keep: {rings: 1}, exclude: {rings})).impossible, isTrue);
    });
  });

  group('the server\'s interpretation', () {
    Json request() => interpretRequest(requestId: 'r1', catalog: catalog, chainId: 'subway-ca', question: 'keep the rings, more protein',
        draft: const EatOutDraft(chainId: 'subway-ca', order: RestaurantOrder([OrderLine(tuna, 1)])), revision: '3|en', languageCode: 'fr');

    test('the request carries only the order, preferences, words and catalog version', () {
      final r = request();
      expect(r.keys.toSet(), {'requestId', 'catalogVersion', 'chainId', 'question', 'language', 'history', 'order', 'orderRevision', 'preferences'});
      expect((r['catalogVersion'], r['language'], r['orderRevision']), (catalog.version, 'fr-CA', '3|en'));
      expect(jsonEncode(r), isNot(contains('@')), reason: 'no email or account data');
    });

    test('only an answer to this request, naming real items, becomes preferences; no value is taken from it', () {
      Json body(Json intent, {String id = 'r1'}) => {'requestId': id, 'catalogVersion': catalog.version, 'chainId': 'subway-ca', 'orderRevision': '3|en', 'intent': intent};
      final intent = {
        'kind': 'constraints', 'mode': 'improve', 'maxCalories': 600, 'minProtein': 30, 'calories': 999,
        'keep': [{'itemId': rings, 'quantity': 1}, {'itemId': 'subway-ca:made-up', 'quantity': 1}], 'exclude': [tuna, 'nope'], 'prefer': ['sandwich'], 'avoid': [], 'priority': 'protein',
      };
      final i = Interpretation.read(body(intent), request(), subway)!;
      expect((i.preferences.maxCalories, i.preferences.minProtein, i.preferences.priority), (600, 30, OrderPriority.protein));
      expect(i.preferences.keep, {rings: 1});
      expect(i.preferences.exclude, {tuna});
      expect(Interpretation.read(body(intent, id: 'other'), request(), subway), isNull, reason: 'a reply to another request');
      expect(Interpretation.read(body({...intent, 'kind': 'answer'}), request(), subway), isNull);
    });
  });

  group('logging and saving on the real database', () {
    late Harness h;
    late String owner;
    setUp(() async {
      h = Harness();
      owner = await h.signIn('one');
    });
    tearDown(() => h.dispose());

    FoodRepository journal() => FoodRepository(h.sync, owner);
    Future<List<FoodEntry>> food() async => [for (final j in await h.bodies(owner, Kinds.food)) FoodEntry(j)];
    const order = RestaurantOrder([OrderLine(chicken, 1), OrderLine(rings, 2)]);
    List<FoodDraft> drafts() => MealMath.mealEntries(orderComponents(catalog, subway, order), dayKey: '2026-10-20', meal: 'Lunch');

    test('Save as meal records no food; the saved meal keeps the restaurant identity of every item', () async {
      final body = MealBody({'kind': 'meal', 'name': 'Subway order', 'components': [for (final c in orderComponents(catalog, subway, order)) c.j]});
      final id = await SavedMealRepository(h.sync, owner).put(body);
      await h.sync.flush();
      expect(await food(), isEmpty);
      expect(h.server.food, isEmpty);
      final kept = MealBody(h.server.savedMeals[id]!['body'] as Json).components;
      expect([for (final c in kept) (c.item.source, RestaurantOrigin.of(MealComponent.slim(c.item))?.catalogVersion, c.quantity)],
          [(FoodItem.restaurant, catalog.version, 1), (FoodItem.restaurant, catalog.version, 2)]);
    });

    test('Log records every item once, as ordinary entries with frozen restaurant snapshots; taps and lost answers add nothing', () async {
      h.server.loseNextResponse = true;
      await Future.wait([journal().logMeal(drafts(), operationId: 'op-1'), journal().logMeal(drafts(), operationId: 'op-1')]);
      await h.sync.flush();
      await h.sync.flush();
      final logged = await food();
      expect([for (final e in logged) (e.name, e.amountDescription, e.meal, e.dayKey, e.calories, e.protein)], [
        ('Rotisserie-Style Chicken · 6-inch', '1 sub (6-inch) (244 g)', 'Lunch', '2026-10-20', 460, 28),
        ('Potato Rings', '2 sides (4 rings each) (184 g)', 'Lunch', '2026-10-20', 300, 4),
      ], reason: 'one entry per item, no total entry');
      expect(h.server.food, hasLength(2));
      for (final e in logged) {
        expect(e.source!['item']['source'], FoodItem.restaurant);
        expect(e.source!['item']['restaurant']['catalogVersion'], catalog.version);
        expect(e.j['provenance'], {'calories': 'imported', 'protein': 'imported', 'carbs': 'imported', 'fat': 'imported'});
      }
      expect(NutrientCoverage.calculate(logged)[Nutrient.calories]!.isComplete, isTrue);
    });

    test('offline: the order logs locally, survives a restart and reaches the account once; the draft is kept too', () async {
      h.server.offline = true;
      final store = EatOutStore(h.sync, owner);
      store.keep(const EatOutDraft(chainId: 'subway-ca', order: order, preferences: OrderPreferences(maxCalories: 600, keep: {rings: 2})));
      await journal().logMeal(drafts(), operationId: 'op-offline');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await h.restart();
      expect(await food(), hasLength(2));
      final again = await EatOutStore(h.sync, owner).load();
      expect((again.chainId, again.order, again.preferences.maxCalories), ('subway-ca', order, 600));
      expect(again.preferences.keep, {rings: 2});
      h.server.offline = false;
      await h.sync.flush();
      await h.sync.flush();
      expect(h.server.food, hasLength(2));
    });
  });
}
