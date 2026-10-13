import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/compatibility.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/me/account_repository.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';

import 'support.dart';

/// The food the API tests normalize a recorded Open Food Facts response to: both sides read this one sample.
FoodItem nutella() => FoodItem(copyJson((fixture['wire'] as Json)['foodItem'] as Json));

FoodItem food(String basis, {Json nutrients = const {'calories': 100, 'protein': 10, 'carbs': 0, 'fat': null}, List<Json> servings = const [], String source = 'usda', String id = '1'}) =>
    FoodItem({'source': source, 'sourceId': id, 'name': 'Test food', 'basis': basis, 'nutrients': nutrients, 'servings': servings});

void main() {
  group('amounts and values', () {
    test('a per-100 g food scales by weight and by its stated serving, to the journal\'s two decimals', () {
      final item = nutella();
      final units = FoodScaling.units(item);
      expect([for (final u in units) u.id], ['g', 'serving:0']);
      expect(FoodScaling.scale(item, 30, units[0]), {'calories': 161.7, 'protein': 1.89, 'carbs': 17.25, 'fat': 9.27});
      expect(FoodScaling.scale(item, 2, units[1]), FoodScaling.scale(item, 30, units[0]), reason: 'two 15 g servings are 30 g');
      final (quantity, unit) = FoodScaling.initial(item);
      expect((quantity, unit.label, FoodScaling.amountText(quantity, unit)), (1, '15 g', '1 serving (15 g)'));
      expect(FoodScaling.amountText(2, unit), '2 servings (15 g each)');
      expect(FoodScaling.amountText(150, units[0]), '150 g');
    });

    test('unknown stays unknown and zero stays zero at every amount', () {
      final item = food(FoodItem.per100g);
      for (final grams in [1.0, 100.0, 2500.0]) {
        final scaled = FoodScaling.scale(item, grams, FoodScaling.units(item).first);
        expect((scaled['carbs'], scaled['fat']), (0, null), reason: '$grams g');
      }
    });

    test('only units that mean something are offered: no grams for a liquid, no weight for an unweighed serving', () {
      // Per 100 ml: millilitres and servings with a volume. A gram is never assumed to be a millilitre.
      final liquid = food(FoodItem.per100ml, servings: [{'label': '1 can (330 ml)', 'grams': null, 'milliliters': 330}, {'label': '1 scoop', 'grams': 30, 'milliliters': null}]);
      expect([for (final u in FoodScaling.units(liquid)) u.id], ['ml', 'serving:0']);
      expect(FoodScaling.scale(liquid, 1, FoodScaling.units(liquid)[1])['calories'], 330);

      // Per 100 g with a serving given only as a volume: that serving cannot be weighed, so it is not offered.
      final solid = food(FoodItem.per100g, servings: [{'label': '1 cup', 'grams': null, 'milliliters': 240}]);
      expect([for (final u in FoodScaling.units(solid)) u.id], ['g']);

      // Per serving with no stated weight: it can only be counted.
      final jar = food(FoodItem.perServing, servings: [{'label': '1 jar', 'grams': null, 'milliliters': null}], source: 'user');
      expect([for (final u in FoodScaling.units(jar)) u.label], ['1 jar']);
      expect(FoodScaling.scale(jar, 1.5, FoodScaling.units(jar).single)['calories'], 150);
      expect(FoodScaling.basisText(jar), 'per 1 jar');

      // Per serving with a stated weight: grams become meaningful too.
      final bar = food(FoodItem.perServing, servings: [{'label': '1 bar', 'grams': 40, 'milliliters': null}]);
      expect([for (final u in FoodScaling.units(bar)) u.id], ['serving:0', 'g']);
      expect(FoodScaling.scale(bar, 20, FoodScaling.unit(bar, 'g'))['calories'], 50);
    });

    test('counting units read the way people count: eggs, slices, cups, halves', () {
      Json serving(String label, [num? grams]) => {'label': label, 'grams': grams, 'milliliters': null};
      final egg = food(FoodItem.per100g, nutrients: {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': null},
          servings: [serving('1 large', 50), serving('1 egg', 44), serving('1 cup, cooked', 158), serving('2 biscuits (25 g)', 25), serving('1 slice', 30), serving('1 loaf', 400), serving('1 berry', 5), serving('1 packet')]);
      final units = {for (final u in FoodScaling.units(egg)) u.label: u};
      expect(units.keys, isNot(contains('1 packet')), reason: 'a packet nobody weighed cannot be a unit of a food measured by weight');
      String said(double q, String label) => FoodScaling.amountText(q, units[label]!);

      expect([said(1, '1 egg'), said(2, '1 egg'), said(0.5, '1 egg'), said(1.5, '1 egg'), said(2.2, '1 egg')], ['1 egg', '2 eggs', '½ egg', '1½ eggs', '2.2 eggs']);
      expect([said(2, '1 slice'), said(0.25, '1 slice'), said(2, '1 loaf'), said(3, '1 berry')], ['2 slices', '¼ slice', '2 loaves', '3 berries']);
      expect(said(2, '1 large'), '2 large', reason: 'a size is not turned into a noun');
      expect(said(2, '1 cup, cooked'), '2 cups, cooked');
      expect([said(1, '2 biscuits (25 g)'), said(3, '2 biscuits (25 g)')], ['2 biscuits (25 g)', '3 × 2 biscuits (25 g)'], reason: 'a portion of several things is counted as that portion');
      expect(FoodScaling.amountText(2, FoodScaling.unit(food(FoodItem.per100ml, servings: [{'label': '1 can (330 ml)', 'grams': null, 'milliliters': 330}]), 'serving:0')), '2 cans (330 ml each)');

      // The list of units says what one of them weighs; the first countable one is where a new entry starts.
      expect((units['1 egg']!.menuLabel, units['1 cup, cooked']!.menuLabel, units['g']!.menuLabel), ('egg · 44 g each', 'cup, cooked · 158 g each', 'g'));
      final (quantity, unit) = FoodScaling.initial(egg);
      expect((quantity, unit.label), (1, '1 large'));

      // Two eggs are 88 g of this food, and get exactly the values of 88 g.
      expect(FoodScaling.measured(egg, 2, units['1 egg']!), '88 g');
      expect(FoodScaling.scale(egg, 2, units['1 egg']!), FoodScaling.scale(egg, 88, units['g']!));
      expect(FoodScaling.scale(egg, 0.5, units['1 egg']!), {'calories': 31.46, 'protein': 2.77, 'carbs': 0.15, 'fat': null}, reason: 'half an egg; unknown fat stays unknown');
    });

    test('changing the unit keeps the amount: a 30 g serving becomes 30 g, never 1 g, and back again', () {
      final cereal = food(FoodItem.per100g, servings: [{'label': '1 serving', 'grams': 30, 'milliliters': null}, {'label': '1 scoop', 'grams': 12.5, 'milliliters': null}]);
      final g = FoodScaling.unit(cereal, 'g'), serving = FoodScaling.unit(cereal, 'serving:0'), scoop = FoodScaling.unit(cereal, 'serving:1');
      expect(FoodScaling.convert(1, serving, g), 30);
      expect(FoodScaling.convert(45, g, serving), 1.5);
      expect(FoodScaling.convert(2, scoop, g), 25);
      expect(FoodScaling.convert(2, serving, scoop), 4.8, reason: 'between two counted units, through the weight they share');
      expect(FoodScaling.convert(FoodScaling.convert(2.5, serving, g), g, serving), 2.5);
      expect(FoodScaling.scale(cereal, FoodScaling.convert(1, serving, g), g), FoodScaling.scale(cereal, 1, serving), reason: 'the same food, so the same values');

      final juice = food(FoodItem.per100ml, servings: [{'label': '1 glass', 'grams': null, 'milliliters': 200}]);
      expect(FoodScaling.convert(1.5, FoodScaling.unit(juice, 'serving:0'), FoodScaling.unit(juice, 'ml')), 300);

      // A food measured per serving converts only when that serving has a stated weight.
      final bar = food(FoodItem.perServing, servings: [{'label': '1 bar', 'grams': 40, 'milliliters': null}]);
      expect(FoodScaling.convert(1, FoodScaling.unit(bar, 'serving:0'), FoodScaling.unit(bar, 'g')), 40);
      expect(FoodScaling.convert(20, FoodScaling.unit(bar, 'g'), FoodScaling.unit(bar, 'serving:0')), 0.5);
      final jar = food(FoodItem.perServing, servings: [{'label': '1 jar', 'grams': null, 'milliliters': null}], source: 'user');
      expect([for (final u in FoodScaling.units(jar)) u.id], ['serving:0'], reason: 'no weight is known, so grams are not offered and nothing can be reinterpreted');
      expect(FoodScaling.unit(jar, 'g').id, 'serving:0', reason: 'asking for a unit the food does not have falls back to its own, never to a bare number of grams');
      expect(FoodScaling.measured(jar, 2, FoodScaling.unit(jar, 'serving:0')), isNull);
    });

    test('a portion the user defines is theirs, explicit, and travels with the food', () {
      final bread = food(FoodItem.per100g, servings: [{'label': '1 packet', 'grams': null, 'milliliters': null}], id: 'bread');
      expect([for (final u in FoodScaling.units(bread)) u.id], ['g']);
      final sliced = FoodScaling.withPortion(bread, ' slice ', 32.5);
      expect(bread.servings.length, 1, reason: 'the original food is not changed');
      final slice = FoodScaling.unit(sliced, 'serving:1');
      expect((slice.label, slice.menuLabel, sliced.servings.last.isUserDefined, sliced.servings.first.isUserDefined), ('1 slice', 'slice · 32.5 g each', true, false));
      expect((FoodScaling.amountText(2, slice), FoodScaling.convert(2, slice, FoodScaling.unit(sliced, 'g')), FoodScaling.scale(sliced, 2, slice)['calories']), ('2 slices', 65, 65));

      // On a food measured per serving, a portion is a share of that serving.
      final pizza = food(FoodItem.perServing, nutrients: {'calories': 800, 'protein': null, 'carbs': 96, 'fat': 0}, servings: [{'label': '1 pizza', 'grams': null, 'milliliters': null}], source: 'user', id: 'pizza');
      final cut = FoodScaling.withPortion(pizza, 'slice', 0.125);
      expect(FoodScaling.portionMeasure(pizza), '× 1 pizza');
      expect(FoodScaling.scale(cut, 3, FoodScaling.unit(cut, 'serving:1')), {'calories': 300, 'protein': null, 'carbs': 36, 'fat': 0});
      expect(FoodScaling.convert(4, FoodScaling.unit(cut, 'serving:1'), FoodScaling.unit(cut, 'serving:0')), 0.5);

      // Met again from a search: only the user's portions of the same food are added, once.
      final fresh = FoodScaling.withKnownPortions(bread, [sliced, sliced, FoodScaling.withPortion(food(FoodItem.per100g, id: 'other'), 'wedge', 50), pizza]);
      expect([for (final s in fresh.servings) s.label], ['1 packet', '1 slice']);
      expect(identical(FoodScaling.withKnownPortions(bread, [bread]).j, bread.j), true, reason: 'nothing to add leaves the food as it was');

      // A food from before portions could be defined reads exactly as it did.
      final old = FoodItem({'source': 'usda', 'sourceId': '7', 'name': 'Rice', 'basis': '100g', 'nutrients': {'calories': 129}, 'servings': [{'label': '1 cup, cooked', 'grams': 158, 'milliliters': null}]});
      expect((old.servings.single.isUserDefined, old.servings.single.ofServing, FoodScaling.scale(old, 2, FoodScaling.unit(old, 'serving:0'))['calories']), (false, null, 407.64));
    });

    test('barcodes stay text and follow the documented normalization', () {
      expect(normalizeBarcode('034000470693'), '0034000470693', reason: 'the documented example: UPC-A is stored as 13 digits');
      expect(normalizeBarcode('0034000470693'), '0034000470693');
      expect(normalizeBarcode('0000000012345'), '00012345', reason: 'leading zeros are significant in the result');
      expect(normalizeBarcode(' 96385074 '), '96385074');
      for (final bad in ['12345', '301762042200X', 'https://example.test/a', '0000000000000', '', null]) {
        expect(normalizeBarcode(bad), isNull, reason: '$bad');
      }
    });

    test('a stored value put back into a field is not changed by being shown', () {
      for (final v in [161.7, 17.25, 30.0, 0.0, 0.05, 1234.5]) {
        expect(parseNonNegative(formatNumber2(v)), v);
      }
      expect(formatNumber2(30), '30');
    });
  });

  group('on this phone', () {
    test('favourites and the owner\'s foods come first, a logged food appears once (newest), filtered by name or brand', () {
      Json saved(String id, String name, {bool favourite = false, String source = 'user'}) =>
          {'id': id, 'item': {'source': source, 'sourceId': id, 'name': name, 'basis': '100g', 'nutrients': {}}, 'isFavourite': favourite, 'isDeleted': false};
      final journal = [
        FoodEntry({'id': 'a', 'dayKey': '2026-10-08', 'meal': 'Lunch', 'name': 'Chicken soup', 'amountDescription': '1 bowl', 'macros': {'calories': 200}}),
        FoodEntry({'id': 'b', 'dayKey': '2026-10-09', 'meal': 'Lunch', 'name': 'Chicken soup', 'amountDescription': '2 bowls', 'macros': {'calories': 400}}),
        FoodEntry({'id': 'c', 'dayKey': '2026-10-09', 'meal': 'Snack', 'name': 'Removed', 'amountDescription': '1', 'macros': {}, 'isDeleted': true}),
        FoodEntry({'id': 'd', 'dayKey': '2026-10-07', 'meal': 'Snack', 'name': 'Nutella', 'amountDescription': '15 g', 'macros': {}, 'source': {'item': nutella().j, 'quantity': 1, 'unit': 'serving:0'}}),
      ];
      final all = localSuggestions(
          saved: [saved('s1', 'Overnight oats'), saved('s2', 'Chicken breast, raw', favourite: true, source: 'usda'), saved('s3', 'Gone')..['isDeleted'] = true],
          journal: journal, seen: [nutella(), food('100g', id: '9')]);
      expect([for (final s in all) '${s.origin.name}:${s.item.name}'],
          ['favourite:Chicken breast, raw', 'mine:Overnight oats', 'recent:Chicken soup', 'recent:Nutella', 'seen:Test food']);
      expect(all[2].entry!.amountDescription, '2 bowls', reason: 'the newest logging of the same food');
      expect([for (final s in localSuggestions(saved: const [], journal: journal, seen: [nutella()], query: 'ferrero nut')) s.item.name], ['Nutella'], reason: 'matches brand and name; already-recent food is not repeated');
    });
  });

  group('journal, saved foods and lookups on the real database', () {
    late Harness h;
    late String owner;
    setUp(() async {
      h = Harness();
      owner = await h.signIn('one');
    });
    tearDown(() => h.dispose());

    Json sent(String fragment, [int index = 0]) => jsonDecode(h.server.callsTo(fragment)[index].body) as Json;

    test('logging a found food keeps its own snapshot, tells imported from corrected values, and survives restart offline', () async {
      final journal = FoodRepository(h.sync, owner);
      h.server.offline = true;
      // 30 g of the food; protein corrected by hand, fat cleared to unknown.
      final draft = FoodDraft.of(nutella(), dayKey: '2026-10-09', meal: 'Breakfast')
        ..quantity = 30
        ..unitId = 'g'
        ..amount = '30 g'
        ..calories = 161.7
        ..protein = 2
        ..carbs = 17.25
        ..fat = null;
      await journal.save(draft);
      await h.restart();

      var entry = FoodEntry((await h.bodies(owner, Kinds.food)).single);
      expect((entry.calories, entry.protein, entry.fat, entry.amountDescription), (161.7, 2, null, '30 g'));
      expect(entry.j['provenance'], {'calories': 'imported', 'protein': 'entered', 'carbs': 'imported', 'fat': 'unknown'});
      expect((entry.source!['quantity'], entry.source!['unit'], FoodItem(entry.source!['item'] as Json).barcode), (30, 'g', '3017620422003'));

      h.server.offline = false;
      await h.sync.flush();
      expect(sent('/food-entries')['provenance'], {'calories': 'imported', 'protein': 'entered', 'carbs': 'imported', 'fat': 'unknown'});
      expect((sent('/food-entries')['source'] as Json)['item'], nutella().j);
      expect(h.server.food.length, 1);

      // The same food is later corrected as a saved food and its cached copy is replaced. The meal does not move.
      await SavedFoodRepository(h.sync, owner).saveMine(name: 'Nutella', values: {'calories': 999, 'protein': 9, 'carbs': 9, 'fat': 9}, from: nutella(), quantity: 100, unitId: 'g');
      await FoodDiscovery(Api(h.server, h.sessions), h.sync, owner, h.clock).remember([FoodItem({...nutella().j, 'nutrients': {'calories': 1}})]);
      await h.sync.flush();
      await h.sync.pull();
      entry = FoodEntry((await h.bodies(owner, Kinds.food)).single);
      expect((entry.calories, FoodItem(entry.source!['item'] as Json).nutrient('calories')), (161.7, 539));

      // Opening it again to edit starts from what was logged, corrections included.
      final again = FoodDraft.edit(entry);
      expect((again.quantity, again.unitId, again.protein, again.item!.name), (30, 'g', 2, 'Nutella'));
    });

    test('a defined portion is kept offline and across restart, reaches the account, joins the saved food, and rewrites no earlier meal', () async {
      final journal = FoodRepository(h.sync, owner);
      final saved = SavedFoodRepository(h.sync, owner);
      // Last week, before any portion existed: two 15 g servings, in the words that version wrote.
      await journal.save(FoodDraft.of(nutella(), dayKey: '2026-10-02', meal: 'Breakfast')
        ..quantity = 2
        ..amount = '2 × 15 g'
        ..calories = 161.7);
      await saved.favourite(nutella());
      await h.sync.flush();
      final before = jsonEncode((await h.bodies(owner, Kinds.food)).single);

      // Today, with no connection: "1 spoon = 20 g" is defined, kept on the favourite, and one and a half are logged.
      h.server.offline = true;
      final spooned = FoodScaling.withPortion(nutella(), 'spoon', 20);
      await saved.keepPortions(SavedFood((await h.bodies(owner, Kinds.savedFood)).single), spooned);
      final spoon = FoodScaling.unit(spooned, 'serving:1');
      final values = FoodScaling.scale(spooned, 1.5, spoon);
      await journal.save(FoodDraft(dayKey: '2026-10-09', meal: 'Snack', name: 'Nutella', amount: FoodScaling.amountText(1.5, spoon),
          calories: values['calories'], protein: values['protein'], carbs: values['carbs'], fat: values['fat'], item: spooned, quantity: 1.5, unitId: spoon.id));
      await h.restart();

      final entries = [for (final j in await h.bodies(owner, Kinds.food)) FoodEntry(j)];
      final today = entries.singleWhere((e) => e.dayKey == '2026-10-09'), lastWeek = entries.singleWhere((e) => e.dayKey == '2026-10-02');
      expect((today.amountDescription, today.calories, today.source!['quantity'], today.source!['unit']), ('1½ spoons', 161.7, 1.5, 'serving:1'));
      expect(today.j['provenance'], {'calories': 'imported', 'protein': 'imported', 'carbs': 'imported', 'fat': 'imported'}, reason: 'the values are the source\'s for 30 g');
      final kept = FoodItem(today.source!['item'] as Json).servings.last;
      expect((kept.label, kept.grams, kept.isUserDefined), ('1 spoon', 20, true));
      expect(jsonEncode(lastWeek.j), before, reason: 'the earlier meal keeps its own quantity, unit, words and values');
      expect((FoodDraft.edit(lastWeek).quantity, FoodDraft.edit(lastWeek).unitId, FoodItem(lastWeek.source!['item'] as Json).servings.length), (2, 'serving:0', 1));

      final favourite = SavedFood((await h.bodies(owner, Kinds.savedFood)).single);
      expect((favourite.isFavourite, favourite.item.source), (true, 'off'));
      expect([for (final s in favourite.item.servings) s.label], ['15 g', '1 spoon']);

      // Back online: the definition is in what the account receives, for the meal and for the favourite.
      h.server.offline = false;
      await h.sync.flush();
      expect(await h.sync.commands(owner), isEmpty);
      final sentServing = (((sent('/food-entries', 1)['source'] as Json)['item'] as Json)['servings'] as List).last as Json;
      expect(sentServing, {'label': '1 spoon', 'grams': 20, 'milliliters': null, 'definedBy': 'user'});
      expect(((h.server.savedFoods[favourite.id]!['item'] as Json)['servings'] as List).length, 2);

      // The food found again by search carries the portion; someone else's copy of it does not.
      final again = FoodScaling.withKnownPortions(nutella(), [favourite.item, for (final e in entries) if (e.source != null) FoodItem(e.source!['item'] as Json)]);
      expect([for (final u in FoodScaling.units(again)) u.menuLabel], ['g', 'serving (15 g)', 'spoon · 20 g each']);
    });

    test('an entry typed by hand is sent exactly as an app from before food lookup sent it', () async {
      await FoodRepository(h.sync, owner).save(FoodDraft(dayKey: '2026-10-09', meal: 'Lunch', name: 'Soup', amount: '1 bowl', calories: 0));
      await h.sync.flush();
      expect(sent('/food-entries').keys.toSet(), {'entryId', 'dayKey', 'meal', 'name', 'amountDescription', 'macros', 'operationId'});
    });

    test('saved foods: saved offline, kept across restart, synced once, private to their owner, and never an eaten entry', () async {
      final saved = SavedFoodRepository(h.sync, owner);
      h.server.offline = true;
      await saved.saveMine(name: ' Overnight oats ', values: {'calories': 420, 'protein': 24, 'carbs': null, 'fat': 0}, amount: '1 jar');
      await saved.favourite(nutella());
      await h.restart();
      expect((await h.bodies(owner, Kinds.savedFood)).length, 2);
      expect(await h.bodies(owner, Kinds.food), isEmpty, reason: 'saving is not eating');

      h.server.offline = false;
      h.server.loseNextResponse = true;                       // the first acknowledgement is lost; the retry must not create a second food
      await h.sync.flush();
      await h.sync.flush();
      expect(h.server.savedFoods.length, 2);
      expect(await h.sync.commands(owner), isEmpty);
      final mine = SavedFood((await h.bodies(owner, Kinds.savedFood)).firstWhere((j) => SavedFood(j).isMine));
      expect((mine.item.name, mine.item.basis, mine.item.nutrient('carbs'), mine.item.nutrient('fat'), mine.item.servings.single.label), ('Overnight oats', 'serving', null, 0, '1 jar'));

      // Un-favouriting a provider copy removes it; the owner's own food only loses the mark.
      final favourite = SavedFood((await h.bodies(owner, Kinds.savedFood)).firstWhere((j) => !SavedFood(j).isMine));
      await SavedFoodRepository(h.sync, owner).unfavourite(favourite);
      await h.sync.flush();
      expect(h.server.savedFoods[favourite.id]!['isDeleted'], true);

      // Another account on the same phone sees none of it.
      await h.sessions.signOut();
      final two = await h.signIn('two');
      expect(await h.bodies(two, Kinds.savedFood), isEmpty);
      expect(await h.bodies(two, Kinds.foodCache), isEmpty);
    });

    test('a corrected provider food is kept as the owner\'s copy on the food\'s own basis, and says what it was based on', () async {
      // 30 g logged with protein corrected from 1.89 to 3: per 100 g that is 10.
      await SavedFoodRepository(h.sync, owner).saveMine(name: 'Nutella', values: {'calories': 161.7, 'protein': 3, 'carbs': 17.25, 'fat': null}, from: nutella(), quantity: 30, unitId: 'g');
      final mine = SavedFood((await h.bodies(owner, Kinds.savedFood)).single).item;
      expect((mine.source, mine.basis, mine.nutrient('calories'), mine.nutrient('protein'), mine.nutrient('fat')), ('user', '100g', 539, 10, null));
      expect(mine.j['basedOn'], {'source': 'off', 'sourceId': '3017620422003'});
      expect(mine.imageUrl, isNull, reason: 'the photo belongs to the provider\'s record, not to the copy');
      expect(mine.servings.single.grams, 15, reason: 'still scalable by its stated serving');
    });

    FoodDiscovery discovery() => FoodDiscovery(Api(h.server, h.sessions), h.sync, owner, h.clock);

    test('search keeps what it found for offline use; offline says so and invents nothing', () async {
      h.server.lookups['/foods/search?q=chicken+breast'] = ApiResponse(200, {'results': [food('100g', id: '171515').j, nutella().j]});
      final found = await discovery().search('  chicken   breast ');
      expect([for (final f in found) f.sourceId], ['171515', '3017620422003']);
      expect((await discovery().cached()).length, 2);

      h.server.offline = true;
      await expectLater(discovery().search('chicken breast'), throwsA(isA<LookupFailure>().having((e) => e.problem, 'problem', LookupProblem.offline)));
      expect([for (final s in localSuggestions(saved: const [], journal: const [], seen: [for (final c in await discovery().cached()) c.item], query: 'nutella')) s.item.name], ['Nutella']);
      await expectLater(discovery().search('a'), throwsA(isA<LookupFailure>().having((e) => e.problem, 'problem', LookupProblem.invalid)));
    });

    test('provider trouble is passed on as what it is', () async {
      for (final (response, problem) in [
        (const ApiResponse(429, {'code': 'PROVIDER_RATE_LIMITED'}), LookupProblem.rateLimited),
        (const ApiResponse(503, {'code': 'PROVIDER_NOT_CONFIGURED'}), LookupProblem.notConfigured),
        (const ApiResponse(503, {'code': 'PROVIDER_UNAVAILABLE'}), LookupProblem.unavailable),
        (const ApiResponse(404, null), LookupProblem.notConfigured),       // a server from before food lookup
      ]) {
        h.server.lookups['/foods/search?q=rice'] = response;
        await expectLater(discovery().search('rice'), throwsA(isA<LookupFailure>().having((e) => e.problem, 'problem', problem)), reason: problem.name);
      }
      await expectLater(discovery().barcode('96385074'), throwsA(isA<LookupFailure>().having((e) => e.problem, 'problem', LookupProblem.notFound)));
    });

    test('a barcode is asked for once however often it is scanned, then answered from the phone, also offline', () async {
      h.server.lookups['/foods/barcode/3017620422003'] = ApiResponse(200, {'item': nutella().j});
      final d = discovery();
      final same = await Future.wait([for (var i = 0; i < 6; i++) d.barcode('3017620422003')]);
      expect(same.every((f) => f.name == 'Nutella'), true);
      expect(h.server.callsTo('/foods/barcode').length, 1, reason: 'six detections of one code are one request');

      expect((await d.barcode('3017620422003')).name, 'Nutella');
      expect(h.server.callsTo('/foods/barcode').length, 1, reason: 'looked up this week: answered from the phone');

      h.clock.advance(const Duration(days: 30));
      h.server.offline = true;
      expect((await d.barcode('3017620422003')).name, 'Nutella', reason: 'offline, the older copy is still usable');
      await expectLater(d.barcode('96385074'), throwsA(isA<LookupFailure>().having((e) => e.problem, 'problem', LookupProblem.offline)));
      await expectLater(d.barcode('not a code'), throwsA(isA<LookupFailure>().having((e) => e.problem, 'problem', LookupProblem.invalid)));
    });

    test('goals: saved offline and kept across restart; other profile changes never carry or erase them; clearing is explicit', () async {
      Future<Profile> local() async => Profile((await h.bodies(owner, Kinds.profile)).single);
      h.server.profile = {...authFor('one')['profile'] as Json};
      await h.db.into(h.db.records).insert(RecordsCompanion.insert(ownerId: owner, kind: Kinds.profile, id: owner, body: jsonEncode(h.server.profile), revision: const Value(1)));
      final profiles = ProfileRepository(h.sync, owner);

      h.server.offline = true;
      await profiles.setGoals(await local(), calorieGoal: 2200, proteinGoal: 140);
      await h.restart();
      expect(((await local()).calorieGoal, (await local()).proteinGoal), (2200, 140));
      h.server.offline = false;
      await h.sync.flush();
      expect((h.server.profile['calorieGoal'], h.server.profile['proteinGoal']), (2200, 140));
      h.server.calls.clear();

      // A unit change sends no goal fields at all, exactly like an app from before goals; the server keeps them.
      await ProfileRepository(h.sync, owner).update(await local(), loadUnit: 'lb');
      await h.sync.flush();
      expect(sent('/me').containsKey('calorieGoal'), false);
      expect((h.server.profile['loadUnit'], h.server.profile['calorieGoal'], (await local()).proteinGoal), ('lb', 2200, 140));

      // Clearing one goal is sent as an explicit null, and the other stays.
      await ProfileRepository(h.sync, owner).setGoals(await local(), calorieGoal: null, proteinGoal: 140);
      await h.sync.flush();
      expect((sent('/me', 1).containsKey('calorieGoal'), sent('/me', 1)['calorieGoal']), (true, null));
      expect((h.server.profile['calorieGoal'], h.server.profile['proteinGoal'], (await local()).calorieGoal), (null, 140, null));

      for (final (calories, protein) in [(499, null), (10001, null), (null, 9), (null, 501)]) {
        expect(() => ProfileRepository.validateGoals(calories, protein), throwsA(isA<AuthFailure>()));
      }
      ProfileRepository.validateGoals(null, null);            // no goal is always valid
    });

    test('a server from before reusable foods still syncs: the missing list is simply empty', () async {
      h.server.savedFoods['x'] = {'id': 'x', 'item': {'name': 'Kept'}, 'isFavourite': false, 'revision': 1, 'isDeleted': false};
      expect(await h.sync.pull(), true);
      expect((await h.bodies(owner, Kinds.savedFood)).single['id'], 'x');
      // The snapshot of a server from before reusable foods has no such key at all.
      expect(recordsFromSnapshot({
        'profile': authFor(owner)['profile'], 'context': {'contextRevision': 1, 'primaryPlanId': null, 'plans': []},
        'workouts': [], 'foodEntries': [], 'runs': [], 'bodyMetrics': [], 'proposals': [], 'catalog': [],
      }, owner).where((r) => r.kind == Kinds.savedFood), isEmpty);
    });

    group('compatibility gate', () {
      ProviderContainer app(CompatibilityStore store) {
        final c = ProviderContainer(overrides: [
          dbProvider.overrideWithValue(h.db), sessionsProvider.overrideWithValue(h.sessions), transportProvider.overrideWithValue(h.server),
          compatibilityStoreProvider.overrideWithValue(store),
        ], retry: (_, _) => null);
        addTearDown(() async {
          c.read(syncProvider).dispose();
          await c.read(syncProvider).idle();
          c.dispose();
        });
        return c;
      }

      test('unknown is not a block; a confirmed block survives restart with no connection, keeps queued work, and lifts on a passing check', () async {
        final secrets = MemorySecretStore();
        var store = CompatibilityStore(secrets);
        var c = app(store);

        // Never checked, server unreachable: everything works as it did before the gate existed.
        h.server.offline = true;
        await c.read(compatibilityProvider.notifier).check();
        expect(c.read(compatibilityProvider).blocked, false);
        await FoodRepository(c.read(syncProvider), owner).save(FoodDraft(dayKey: '2026-10-09', meal: 'Lunch', name: 'Soup', amount: '1 bowl'));
        await c.read(syncProvider).flush();                  // tried, and failed, while offline
        expect((await c.read(syncProvider).commands(owner)).length, 1);
        h.server.calls.clear();

        // The server now requires a newer contract than this build has.
        h.server.offline = false;
        h.server.capabilities = {...h.server.capabilities, 'minimumClientContract': 2};
        await c.read(compatibilityProvider.notifier).check();
        expect((c.read(compatibilityProvider).blocked, c.read(compatibilityProvider).requiredContract), (true, 2));
        await c.read(syncProvider).flush();
        expect(await c.read(syncProvider).pull(), false);
        expect(h.server.callsTo('/food-entries'), isEmpty, reason: 'nothing is sent while blocked');
        expect((await c.read(syncProvider).commands(owner)).single.state, 'pending', reason: 'the queued entry is kept untouched');
        expect((await h.bodies(owner, Kinds.food)).single['name'], 'Soup');

        // Restart with no connection: still blocked, from what was confirmed before.
        h.server.offline = true;
        store = CompatibilityStore(secrets);
        await store.restore();
        c = app(store);
        expect(c.read(compatibilityProvider).blocked, true);
        await c.read(compatibilityProvider.notifier).check();
        expect(c.read(compatibilityProvider).blocked, true, reason: 'an unanswered check does not lift a confirmed block');

        // An unreadable answer changes nothing either.
        h.server.offline = false;
        h.server.capabilities = {'unexpected': true};
        await c.read(compatibilityProvider.notifier).check();
        expect(c.read(compatibilityProvider).blocked, true);

        // The server accepts this build again (or the app was updated): the block lifts and the queue drains once.
        h.server.capabilities = {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': ['food.barcode']};
        await c.read(compatibilityProvider.notifier).check();
        expect((c.read(compatibilityProvider).blocked, c.read(compatibilityProvider).supports('food.barcode'), c.read(compatibilityProvider).supports('food.search')), (false, true, false));
        await c.read(syncProvider).flush();
        expect(h.server.food.length, 1);
        final restored = CompatibilityStore(secrets);
        await restored.restore();
        expect(restored.requiredContract, isNull);
      });
    });
  });
}

