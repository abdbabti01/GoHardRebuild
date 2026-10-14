import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Native journey 7: nutrition goals; search → amount → log → the same totals and goal progress on Eat and Today;
/// a common food found by typing (bundled with the app, nothing asked of the server), previewed, cancelled, then
/// logged once, and still found after the restart;
/// logging a recent food again and marking a favourite; a cancelled preview that logs nothing; a typed barcode
/// that finds a product; an unknown barcode that falls back to manual entry; what the account then holds; restart.
///
/// The local API must be started with `scripts\start-api.ps1 -FoodFixtures`: search and barcode lookups are then
/// answered from recorded Open Food Facts and USDA responses. That proves the app, the API and its provider
/// adapters together; it does not prove the live providers. The camera view opens here, but an emulator has
/// nothing to point it at, so the barcode is typed: reading a real barcode needs a real phone.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('food: goals, search, amount, log, reuse, barcode, manual fallback, restart', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Food Journey');
    final declared = (await j.api.get<Map>('/capabilities')).data!['capabilities'] as List;
    if (!declared.contains('food.search')) fail('Food search is not available on this API. Start it with scripts\\start-api.ps1 -FoodFixtures');
    String field(String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

    // --- Goals: none to begin with, then set by the user.
    await j.tapKey('nav-me');
    await j.reveal(find.byKey(const Key('me-goals')));
    expect(find.text('None set'), findsOneWidget, reason: 'no goal is suggested');
    await j.tapKey('me-goals');
    expect((field('goal-calories'), field('goal-protein')), ('', ''));
    await j.type('goal-calories', '2200');
    await j.type('goal-protein', '140');
    await j.shot('90-nutrition-goals');
    await j.tapKey('goal-save');
    await j.waitFor(find.text('2200 kcal · 140 g protein'), what: 'the saved goals in Me');

    // --- Search → amount → confirm. Nothing is logged before the confirmation.
    await j.tapKey('nav-eat');
    await j.waitFor(find.byKey(const Key('goal-summary')), what: 'the goal on an empty day');
    await j.tapKey('log-food');
    await j.shot('91-log-food-nothing-saved-yet');
    await j.type('food-search', 'rice');
    // Plain rice is found on the phone at once; the wider database is one deliberate tap further.
    await j.waitFor(find.byKey(const Key('common-white-rice')), what: 'common foods for what was typed');
    expect(find.byKey(const Key('common-rice-cakes')), findsOneWidget, reason: 'rice cakes stay their own food');
    await j.shot('91b-common-foods-for-rice');
    await j.reveal(find.byKey(const Key('food-search-online')));
    await j.tapKey('food-search-online');
    await j.waitFor(find.text('More foods'), what: 'the wider search to answer');
    await j.reveal(find.byKey(const Key('result-usda:2708402')));
    await j.waitFor(find.byKey(const Key('result-usda:2708402')), what: 'search results');
    await j.shot('92-search-results');
    await j.tapKey('result-usda:2708402');
    await j.waitFor(find.byKey(const Key('food-source')), what: 'the food preview');
    expect((field('food-quantity'), field('food-calories')), ('1', '203.82'));
    // One cup said in grams is that cup's 158 g, with the same values; and back again.
    await j.waitFor(find.text('1 cup, cooked (158 g)'), what: 'the amount spelled out with its weight');
    await j.tapKey('food-unit');
    await j.tap(find.byKey(const Key('food-unit-g')).last);
    expect((field('food-quantity'), field('food-calories')), ('158', '203.82'), reason: 'changing the unit keeps the amount');
    await j.shot('93a-food-preview-cup-in-grams');
    await j.tapKey('food-unit');
    await j.tap(find.byKey(const Key('food-unit-serving:0')).last);
    expect((field('food-quantity'), field('food-calories')), ('1', '203.82'));
    await j.type('food-quantity', '2');
    expect((field('food-calories'), field('food-protein')), ('407.64', '8.44'));
    await j.shot('93-food-preview-two-cups');
    expect(((await j.snapshot(await j.apiToken()))['foodEntries'] as List), isEmpty, reason: 'searching and previewing log nothing');
    await j.tapKey('food-save');
    await j.waitFor(find.textContaining('407.6 of 2,200 kcal'), what: 'calorie progress on Eat');
    expect(find.textContaining('Protein 8.4 of 140 g'), findsOneWidget);
    await j.shot('94-eat-goal-progress');
    await j.tapKey('nav-today');
    await j.waitFor(find.text('/ 2,200 kcal'), what: 'the same progress on Today, in its short form');
    expect(find.text('407.6'), findsOneWidget);
    expect(find.text('8.4'), findsOneWidget);
    expect(find.text('/ 140 g protein'), findsOneWidget);
    await j.shot('95-today-goal-progress');

    // --- The same food again from Recent, for another meal, and marked as a favourite on the way.
    await j.tapKey('nav-eat');
    await j.tapKey('eat-add-lunch');
    await j.waitFor(find.byKey(const Key('recent-usda:2708402')), what: 'the food just logged, offered again');
    await j.tapKey('recent-usda:2708402');
    expect(field('food-quantity'), '2', reason: 'starts from the amount it was logged with');
    await j.tapKey('food-favourite');
    await j.tapKey('food-save');
    await j.waitFor(find.textContaining('815.3 of 2,200 kcal'), what: 'both entries in the total');

    // --- A preview that is cancelled logs nothing, and the search is still there.
    await j.tapKey('log-food');
    await j.tapKey('food-scope-favourites');
    await j.waitFor(find.byKey(const Key('favourite-usda:2708402')), what: 'the favourite just marked');
    await j.shot('96-favourites-and-recent');
    await j.tapKey('food-scope-search');
    // The rice search above also returned rice noodles; a food seen before is found on the phone, with no new request.
    await j.type('food-search', 'noodles');
    await j.waitFor(find.byKey(const Key('local-usda:2708356')), what: 'a food seen before, found on the phone');
    await j.tapKey('local-usda:2708356');
    await j.waitFor(find.byKey(const Key('food-source')));
    await j.tapKey('food-cancel');
    expect(field('food-search'), 'noodles');

    // --- Barcode. The camera view opens; the code is typed because an emulator has nothing to scan.
    await j.tapKey('food-scan');
    await j.waitFor(find.byKey(const Key('barcode-typed')), what: 'the scanner');
    await j.shot('97-scanner');
    await j.type('barcode-typed', '3017620422003');
    await j.tapKey('barcode-typed-submit');
    await j.waitFor(find.textContaining('Barcode 3017620422003'), what: 'the product for that barcode');
    expect(find.textContaining('Open Food Facts'), findsWidgets);
    expect((field('food-quantity'), field('food-calories')), ('1', '80.85'));
    await j.shot('98-barcode-product');
    // A portion in the user's own words: "1 spoon = 20 g". The 15 g already entered becomes three quarters of a spoon.
    await j.tapKey('food-add-portion');
    await j.type('portion-name', 'spoon');
    await j.type('portion-amount', '20');
    await j.tapKey('portion-add');
    await j.waitFor(find.text('¾ spoon (15 g)'), what: 'the same amount in the new portion');
    expect((field('food-quantity'), field('food-calories')), ('0.75', '80.85'));
    await j.shot('98b-barcode-own-portion');
    await j.tapKey('food-save');
    await j.waitFor(find.textContaining('896.1 of 2,200 kcal'), what: 'the product in the total');

    // --- An unknown barcode invents nothing and leads to manual entry.
    await j.tapKey('log-food');
    await j.tapKey('food-scan');
    await j.type('barcode-typed', '96385074');
    await j.tapKey('barcode-typed-submit');
    await j.waitFor(find.textContaining('No product was found for barcode 96385074'), what: 'the honest not-found message');
    await j.shot('99-barcode-not-found');
    await j.tapKey('food-manual');
    await j.type('food-name', 'Corner shop flapjack');
    await j.type('food-amount', '1 bar');
    await j.tapKey('food-save');
    await j.waitFor(find.text('Corner shop flapjack'), what: 'the manual entry in the journal');
    expect(find.text('Known totals'), findsOneWidget, reason: 'one food has no values, so the sum is a known sum');
    expect(find.textContaining('896.1 of 2,200 kcal · known so far'), findsOneWidget, reason: 'and no remainder is claimed');

    // --- A common food: found by typing, previewed and cancelled without logging, then logged exactly once.
    await j.tapKey('log-food');
    await j.type('food-search', 'eggs');
    await j.waitFor(find.byKey(const Key('common-eggs')), what: 'the whole egg among common foods');
    expect(find.byKey(const Key('common-egg-whites')), findsOneWidget, reason: 'egg whites are a separate, separately named food');
    await j.shot('99b-common-eggs');
    await j.tapKey('common-eggs');
    await j.waitFor(find.byKey(const Key('food-source')), what: 'the preview of the egg');
    expect((field('food-name'), field('food-quantity'), field('food-calories')), ('Eggs', '1', '71.5'));
    expect(find.text('Egg, whole, raw'), findsOneWidget, reason: 'the full provider title is on the preview');
    expect(find.textContaining('USDA FoodData Central'), findsWidgets);
    await j.shot('99c-common-egg-preview');
    await j.tapKey('food-cancel');
    expect(field('food-search'), 'eggs', reason: 'cancelling keeps the search');
    await j.tapKey('common-eggs');
    await j.waitFor(find.byKey(const Key('food-source')));
    await j.tapKey('food-save');
    await j.waitFor(find.textContaining('967.6 of 2,200 kcal · known so far'), what: 'one egg added to the total, once');

    // --- What the account holds: five entries, four with their source, one favourite, the goals.
    late Map<String, dynamic> account;
    await j.waitUntil(() async {
      account = await j.snapshot(await j.apiToken());
      return (account['foodEntries'] as List).length == 5 && (account['savedFoods'] as List).length == 1;
    }, what: 'the food to reach the account');
    final entries = (account['foodEntries'] as List).cast<Map>();
    expect(entries.where((e) => e['source'] != null).length, 4);
    final egg = entries.singleWhere((e) => e['name'] == 'Eggs');   // logged once, with the catalog's record as its source
    expect((((egg['source'] as Map)['item'] as Map)['source'], ((egg['source'] as Map)['item'] as Map)['sourceId'], egg['amountDescription']), ('usda', '2707152', '1 egg (50 g)'));
    expect(entries.singleWhere((e) => e['name'] == 'Nutella')['provenance'], {'calories': 'imported', 'protein': 'imported', 'carbs': 'imported', 'fat': 'imported'});
    expect(((account['savedFoods'] as List).single as Map)['isFavourite'], true);
    expect(((account['profile'] as Map)['calorieGoal'], (account['profile'] as Map)['proteinGoal']), (2200, 140));

    // --- Restart: the journal, the goals and their progress are all still there.
    await app.main();
    await j.waitFor(find.byKey(const Key('nav-eat')), what: 'the app after a restart');
    await j.tapKey('nav-eat');
    await j.waitFor(find.textContaining('967.6 of 2,200 kcal · known so far'), what: 'the same totals after a restart');
    await j.shot('100-eat-after-restart');
    // The common foods are part of the app, so they are found again straight after a restart.
    await j.tapKey('log-food');
    await j.type('food-search', 'egg');
    // Egg whites were never logged: a pure catalog row. Eggs were logged above, so they are listed once, as one of
    // this account's own foods (same USDA record, same key), and not again under Common foods.
    await j.waitFor(find.byKey(const Key('common-egg-whites')), what: 'a common food after a restart');
    expect(find.byKey(const Key('local-usda:2707152')), findsOneWidget, reason: 'the eggs logged earlier, found on the phone');
    expect(find.byKey(const Key('common-eggs')), findsNothing, reason: 'one record is listed once');
    await j.shot('101-common-food-after-restart');
  });
}
