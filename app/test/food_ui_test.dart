import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/compatibility.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/me/me_screen.dart';
import 'package:gohard_rebuild/features/nutrition/barcode_scan_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_discovery.dart';
import 'package:gohard_rebuild/features/nutrition/food_form.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/nutrition/log_food_screen.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart';

import 'food_fakes.dart';
import 'support.dart';
import 'ui_support.dart';

const _day = '2026-10-09';

Future<List<Override>> _overrides(WidgetTester tester, FoodFakes fakes,
        {List<Json> food = const [], List<Json> savedFoods = const [], List<Json> seenFoods = const [], int? calorieGoal, int? proteinGoal, AppearanceStore? appearance}) async =>
    [
      ...(await tester.runAsync(() => overridesFor(day: _day, food: food, savedFoods: savedFoods, seenFoods: seenFoods, calorieGoal: calorieGoal, proteinGoal: proteinGoal, appearance: appearance)))!,
      ...fakes.overrides,
    ];

String _field(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  double top(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
  String mealShown(WidgetTester tester) => tester.widget<Text>(find.descendant(of: find.byKey(const Key('food-meal-select')), matching: find.byType(Text))).data!;

  group('finding a food', () {
    testWidgets('typing finds a common food at once and asks the wider database nothing; the plus opens the shared form in the stated portion; only the confirmation logs', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [chickenRaw(), riceCooked()]));
      await pumpApp(tester, await _overrides(tester, fakes), size: const Size(390, 3200));

      await _tap(tester, 'log-food');                                            // from Today
      expect(find.text('Add food'), findsOneWidget);
      for (final typed in ['egg', 'eggs']) {
        await tester.enterText(find.byKey(const Key('food-search')), typed);
        await tester.pumpAndSettle();
        expect(top(tester, 'common-eggs'), lessThan(top(tester, 'common-egg-whites')), reason: '$typed: the whole egg first, the whites as their own row');
      }
      expect(fakes.discovery.searches, isEmpty, reason: 'typing alone asks the provider nothing');
      expect(find.descendant(of: find.byKey(const Key('common-eggs')), matching: find.text('Whole · raw')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('common-egg-whites')), matching: find.text('Whites only · raw')), findsOneWidget);
      expect(find.text('1 egg (50 g) · 72 kcal'), findsOneWidget, reason: 'the amount the values are for is stated');
      expect(find.text('6.2 g protein'), findsOneWidget);
      expect(find.byKey(const Key('food-search-online')), findsOneWidget, reason: 'the wider database is one tap away');
      expect(find.text('Choose a food to check the amount before logging.'), findsOneWidget);

      await tester.tap(find.byTooltip('Choose Eggs'));                           // the plus chooses; it does not log
      await tester.pumpAndSettle();
      expect(fakes.journal.saved, isEmpty, reason: 'choosing a food logs nothing');
      expect(find.byKey(const Key('food-source')), findsOneWidget);
      expect(find.text('Egg, whole, raw'), findsOneWidget, reason: 'the provider\'s full title is on the preview');
      expect(find.textContaining('Source: USDA FoodData Central'), findsOneWidget);
      expect((_field(tester, 'food-name'), _field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('Eggs', '1', '71.5'));
      expect(find.text('1 egg (50 g)'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('food-quantity')), '2');
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-calories'), _field(tester, 'food-protein'), _field(tester, 'food-fat')), ('143', '12.4', '9.96'));
      expect(fakes.journal.saved, isEmpty, reason: 'previewing logs nothing');

      await _tap(tester, 'food-save');
      final logged = fakes.journal.saved.single;
      expect((logged.dayKey, logged.meal, logged.name, logged.amount, logged.quantity, logged.unitId, logged.calories), (_day, 'Breakfast', 'Eggs', '2 eggs (100 g)', 2, 'serving:0', 143));
      expect((logged.item!.key, logged.item!.name), ('usda:2707152', 'Egg, whole, raw'), reason: 'the food kept with the meal is the source\'s record');
      expect(find.byKey(const Key('food-search')), findsNothing, reason: 'back where logging began');
      expect(find.byKey(const Key('nav-today')), findsOneWidget);
    });

    testWidgets('the wider database is asked on purpose and once; a cancelled preview or scan logs nothing and the search is still there; the meal chosen here carries into the form', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [chickenRaw(), riceCooked()]));
      await pumpApp(tester, await _overrides(tester, fakes), size: const Size(390, 3200));
      await _tap(tester, 'nav-eat');
      await _tap(tester, 'eat-add-dinner');
      expect(mealShown(tester), 'Dinner', reason: 'the plus beside a meal starts with that meal');

      await tester.enterText(find.byKey(const Key('food-search')), 'rice');
      await tester.pumpAndSettle();
      expect(top(tester, 'common-brown-rice'), lessThan(top(tester, 'common-rice-cakes')));
      expect(top(tester, 'common-white-rice'), lessThan(top(tester, 'common-rice-cakes')), reason: 'plain rice above rice cakes');
      expect(fakes.discovery.searches, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.search);          // the keyboard's search key asks the wider database
      await tester.pumpAndSettle();
      expect(fakes.discovery.searches, ['rice']);
      expect(find.text('More foods'), findsOneWidget);
      expect(top(tester, 'result-usda:2708402'), lessThan(top(tester, 'result-usda:171077')), reason: 'the answer is put in order: rice before what merely came with it');
      expect(find.byKey(const Key('common-white-rice')), findsOneWidget, reason: 'the foods on the phone stay listed');

      await _tap(tester, 'result-usda:2708402');
      expect((_field(tester, 'food-name'), _field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('Rice, cooked, NFS', '1', '203.82'), reason: 'one stated serving of 158 g');
      await _tap(tester, 'food-cancel');
      expect((_field(tester, 'food-search'), find.text('Rice, cooked, NFS').evaluate().length), ('rice', 1), reason: 'the search and its results are still there');

      await tester.enterText(find.byKey(const Key('food-search')), 'Rice ');     // the same question, typed again
      await tester.pumpAndSettle();
      expect(fakes.discovery.searches, ['rice'], reason: 'the same question is not asked twice');
      expect(find.text('More foods'), findsOneWidget, reason: 'and keeps its answer');

      await _tap(tester, 'food-meal-select');
      await tester.tap(find.byKey(const Key('food-meal-option-Snack')).last);
      await tester.pumpAndSettle();
      expect(mealShown(tester), 'Snack');

      await _tap(tester, 'food-scan');
      await _tap(tester, 'barcode-cancel');
      expect(fakes.discovery.barcodes, isEmpty);

      await _tap(tester, 'food-manual');
      expect(_field(tester, 'food-name'), 'Rice');
      expect(find.byKey(const Key('food-source')), findsNothing);
      expect(find.text('Snack'), findsOneWidget, reason: 'the meal chosen on the search screen');
      await _tap(tester, 'food-cancel');
      expect(fakes.journal.saved, isEmpty);
    });

    testWidgets('a food the wider search just returned stays under More foods, although the phone keeps it as seen', (tester) async {
      // On a phone the answer is also written to the seen-foods cache at once; here it is there from the start.
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [chickenRaw(), riceCooked()]));
      await pumpApp(tester, await _overrides(tester, fakes, seenFoods: [riceCooked().j]), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      await tester.enterText(find.byKey(const Key('food-search')), 'rice');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('local-usda:2708402')), findsOneWidget, reason: 'before asking, a food seen earlier is found on the phone');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('result-usda:2708402')), findsOneWidget, reason: 'what the database answered is listed where it came from');
      expect(find.byKey(const Key('local-usda:2708402')), findsNothing, reason: 'and not twice, nor as one of your foods');
    });

    testWidgets('a barcode seen many times is one lookup and one draft; a web link is ignored; a double tap logs once', (tester) async {
      final fakes = FoodFakes(
          discovery: ScriptedDiscovery(products: {'3017620422003': hazelnutSpread()}),
          codes: ['https://example.test/free-prize', '3017620422003', '3017620422003', '3017620422003', '3017620422003']);
      await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Snack'), size: const Size(390, 3200));

      await _tap(tester, 'food-scan');
      expect(fakes.discovery.barcodes, ['3017620422003']);
      expect(find.byType(BarcodeScanScreen), findsNothing);
      expect(find.byType(FoodFormScreen), findsOneWidget);
      expect(find.textContaining('Open Food Facts · Open Database License'), findsOneWidget);
      expect(find.textContaining('Barcode 3017620422003'), findsOneWidget);
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('1', '80.85'));
      expect(fakes.journal.saved, isEmpty, reason: 'scanning logs nothing');

      fakes.journal.hold = Completer();                                          // the first save is still in flight
      await tester.tap(find.byKey(const Key('food-save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('food-save')), warnIfMissed: false);
      await tester.pump();
      fakes.journal.hold!.complete();
      await tester.pumpAndSettle();
      expect(fakes.journal.saved.length, 1);
      expect((fakes.journal.saved.single.meal, fakes.journal.saved.single.amount), ('Snack', '1 serving (15 g)'));
    });

    testWidgets('camera refused: typing the barcode works; an unknown product says so and leads to creating the food', (tester) async {
      final fakes = FoodFakes(cameraRefused: true);
      await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      await _tap(tester, 'food-scan');
      expect(find.textContaining('not allowed to use the camera'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('barcode-typed')), '123');
      await _tap(tester, 'barcode-typed-submit');
      expect(find.textContaining('6 to 14 digits'), findsOneWidget);
      expect(fakes.discovery.barcodes, isEmpty);

      await tester.enterText(find.byKey(const Key('barcode-typed')), '96385074');
      await _tap(tester, 'barcode-typed-submit');
      expect(fakes.discovery.barcodes, ['96385074']);
      expect(find.textContaining('No product was found for barcode 96385074'), findsOneWidget);
      expect(find.byType(FoodFormScreen), findsNothing, reason: 'no product is invented');

      await _tap(tester, 'food-manual');
      await tester.enterText(find.byKey(const Key('food-name')), 'Corner shop flapjack');
      await tester.enterText(find.byKey(const Key('food-amount')), '1 bar');
      await _tap(tester, 'food-save');
      expect((fakes.journal.saved.single.name, fakes.journal.saved.single.item, fakes.journal.saved.single.calories), ('Corner shop flapjack', null, null));
    });

    testWidgets('a wider search that does not get through says only that, keeps the foods on the phone, and one of them can be logged', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(searchProblem: LookupProblem.offline));
      await pumpApp(tester, await _overrides(tester, fakes, savedFoods: [savedFood('s-oats', ownOats())], seenFoods: [hazelnutSpread().j]),
          home: const LogFoodScreen(dayKey: _day, meal: 'Breakfast'), size: const Size(390, 3200));

      await tester.enterText(find.byKey(const Key('food-search')), 'nut');
      await tester.pumpAndSettle();
      expect(find.text('Nutella'), findsOneWidget, reason: 'a product looked up earlier is found without a connection');
      await _tap(tester, 'food-search-online');
      expect(find.textContaining('could not be reached just now'), findsOneWidget);
      expect(find.textContaining('connection or the server'), findsOneWidget, reason: 'the app knows the attempt failed, not why');
      expect(find.textContaining(RegExp('offline', caseSensitive: false)), findsNothing);
      expect(find.byKey(const Key('food-search-empty')), findsNothing, reason: 'a failed search is not "no foods"');
      expect(find.text('Nutella'), findsOneWidget, reason: 'the failure erased nothing');
      expect(find.byKey(const Key('food-manual')), findsOneWidget);
      await _tap(tester, 'food-search-retry');
      expect(fakes.discovery.searches, ['nut', 'nut']);

      await tester.enterText(find.byKey(const Key('food-search')), 'oats');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('common-oatmeal')), findsOneWidget, reason: 'the catalog\'s oats and the user\'s own are two foods');
      await _tap(tester, 'local-user:s-oats');
      expect(find.textContaining('Your own food'), findsOneWidget);
      expect(find.textContaining('gives no value for fat'), findsOneWidget);
      expect((_field(tester, 'food-fat'), _field(tester, 'food-calories')), ('', '420'), reason: 'unknown stays blank, not zero');
      await _tap(tester, 'food-save');
      expect((fakes.journal.saved.single.fat, fakes.journal.saved.single.amount), (null, '1 jar'));
    });

    testWidgets('unreachable, too slow, over quota, provider trouble, not set up and nothing found each say something different and true', (tester) async {
      Future<void> ask(FoodFakes fakes, String text) async {
        await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
        await tester.enterText(find.byKey(const Key('food-search')), text);
        await tester.pumpAndSettle();
      }

      final said = <String>{};
      for (final problem in [LookupProblem.offline, LookupProblem.timeout, LookupProblem.rateLimited, LookupProblem.unavailable, LookupProblem.notConfigured]) {
        final fakes = FoodFakes(discovery: ScriptedDiscovery(searchProblem: problem));
        await ask(fakes, 'egg');
        await _tap(tester, 'food-search-online');
        final text = tester.widget<StatusLine>(find.byKey(const Key('food-search-problem'))).text;
        said.add(text);
        expect(text.toLowerCase(), allOf(isNot(contains('offline')), isNot(contains('no foods'))), reason: problem.name);
        expect(find.byKey(const Key('common-eggs')), findsOneWidget, reason: '${problem.name}: the foods on the phone are still listed');
        expect(find.byKey(const Key('food-search-empty')), findsNothing, reason: problem.name);
        expect(find.byKey(const Key('food-search-retry')), problem == LookupProblem.notConfigured ? findsNothing : findsOneWidget, reason: problem.name);
        await tester.pumpWidget(const SizedBox());                               // a fresh app for the next state
      }

      // The database answered and had nothing more: only then is "no other foods" said, and the egg is still there.
      await ask(FoodFakes(), 'egg');
      await _tap(tester, 'food-search-online');
      said.add(tester.widget<StatusLine>(find.byKey(const Key('food-search-empty'))).text);
      expect(find.text('The wider database has no other foods for "egg".'), findsOneWidget);
      expect(find.byKey(const Key('common-eggs')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      // Nothing on the phone either: it is asked after a pause, and the answer "nothing" is said as that.
      final nothing = FoodFakes();
      await ask(nothing, 'zzzq');
      expect(find.textContaining('Nothing on this phone matches "zzzq"'), findsOneWidget);
      await tester.pump(LogFoodScreen.pause);
      await tester.pumpAndSettle();
      expect(nothing.discovery.searches, ['zzzq']);
      said.add(tester.widget<StatusLine>(find.byKey(const Key('food-search-empty'))).text);
      expect(find.textContaining('No foods were found for "zzzq"'), findsOneWidget);
      expect(said.length, 7, reason: 'seven states, seven different sentences');
    });

    testWidgets('typing pauses before the wider database is asked, once; an answer to an earlier, cleared or re-scoped question never replaces what is on screen', (tester) async {
      final held = HeldDiscovery();
      await pumpApp(tester, await _overrides(tester, FoodFakes(discovery: held)), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      Future<void> type(String text) async {
        await tester.enterText(find.byKey(const Key('food-search')), text);
        await tester.pump();
      }

      // Nothing on the phone is called "xyzzy": the wider database is asked by itself, but not per keystroke.
      for (final text in ['xyz', 'xyzz', 'xyzzy']) {
        await type(text);
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(held.searches, isEmpty, reason: 'still typing');
      await tester.pump(LogFoodScreen.pause);
      expect(held.searches, ['xyzzy'], reason: 'one request for three keystrokes');
      expect(find.byKey(const Key('food-search-busy')), findsOneWidget);

      // A newer question while the first is still on its way.
      await type('plugh');
      await tester.pump(LogFoodScreen.pause);
      expect(held.searches, ['xyzzy', 'plugh']);
      held.pending['xyzzy']!.complete([chickenRaw()]);
      await tester.pump();
      expect(find.text('Chicken, breast, meat only, raw'), findsNothing, reason: 'the older answer is dropped');
      expect(find.byKey(const Key('food-search-busy')), findsOneWidget, reason: 'the current question is still being asked');
      held.pending['plugh']!.complete([riceCooked()]);
      await tester.pumpAndSettle();
      expect(find.text('Rice, cooked, NFS'), findsOneWidget);

      // Cleared while asking.
      await type('quux');
      await tester.pump(LogFoodScreen.pause);
      await _tap(tester, 'food-search-clear');
      held.pending['quux']!.complete([chickenRaw()]);
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-search'), find.text('Chicken, breast, meat only, raw').evaluate().length, find.byKey(const Key('food-search-guide')).evaluate().length), ('', 0, 1));

      // A category chosen while asking: the wider database has no categories, so its answer has no place there.
      await type('egg');
      await _tap(tester, 'food-search-online');
      await _tap(tester, 'food-category-Proteins');
      held.pending['egg']!.complete([riceCooked()]);
      await tester.pumpAndSettle();
      expect((find.text('More foods').evaluate().length, find.text('Rice, cooked, NFS').evaluate().length, find.byKey(const Key('common-eggs')).evaluate().length), (0, 0, 1));

      // Another list chosen while asking.
      await _tap(tester, 'food-category-all');
      await type('tofu');
      await _tap(tester, 'food-search-online');
      await _tap(tester, 'food-scope-recent');
      held.pending['tofu']!.complete([chickenRaw()]);
      await tester.pumpAndSettle();
      expect(find.text('Chicken, breast, meat only, raw'), findsNothing);

      // Each of those answers still belongs to its own question, and is shown when that is asked again: no new request.
      await _tap(tester, 'food-scope-search');
      expect(find.text('Chicken, breast, meat only, raw'), findsOneWidget);
      expect(held.searches, ['xyzzy', 'plugh', 'quux', 'egg', 'tofu']);
    });

    testWidgets('a category lists and filters common foods only, says so, and shows no unclassified food under it', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [riceCooked()]));
      await pumpApp(tester, await _overrides(tester, fakes, savedFoods: [savedFood('s-oats', ownOats())], seenFoods: [hazelnutSpread().j]),
          home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      await _tap(tester, 'food-category-Vegetables');
      expect((find.byKey(const Key('common-broccoli')).evaluate().length, find.byKey(const Key('common-eggs')).evaluate().length), (1, 0), reason: 'the category\'s own foods, with nothing typed');
      expect(find.byKey(const Key('food-category-note')), findsOneWidget);

      await _tap(tester, 'food-category-Carbohydrates');
      await tester.enterText(find.byKey(const Key('food-search')), 'oat');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('common-oatmeal')), findsOneWidget);
      expect(find.text('Overnight oats'), findsNothing, reason: 'the user\'s own oats have no category, so they are not passed off as a carbohydrate');
      expect(find.byKey(const Key('food-search-online')), findsNothing, reason: 'the wider database cannot be filtered by category');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(fakes.discovery.searches, isEmpty);

      await _tap(tester, 'food-category-Fruits');
      expect(find.text('No common food in Fruits matches "oat".'), findsOneWidget);

      await _tap(tester, 'food-category-all');
      expect((find.text('Overnight oats').evaluate().length, find.byKey(const Key('food-search-online')).evaluate().length, find.byKey(const Key('food-category-note')).evaluate().length), (1, 1, 0));
    });

    testWidgets('a brand typed finds the branded food and no generic one', (tester) async {
      final yogurt = FoodItem({'source': 'usda', 'sourceId': '900001', 'name': 'Greek Yogurt, Vanilla', 'brand': 'Chobani', 'basis': '100g', 'nutrients': {'calories': 80, 'protein': 8, 'carbs': 9, 'fat': null}, 'servings': []});
      await pumpApp(tester, await _overrides(tester, FoodFakes(), seenFoods: [yogurt.j, hazelnutSpread().j]), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      await tester.enterText(find.byKey(const Key('food-search')), 'chobani');
      await tester.pumpAndSettle();
      expect((find.text('Greek Yogurt, Vanilla').evaluate().length, find.text('Chobani').evaluate().length, find.text('Common foods').evaluate().length), (1, 1, 0));

      await tester.enterText(find.byKey(const Key('food-search')), 'greek yogurt');
      await tester.pumpAndSettle();
      expect((find.text('Greek Yogurt, Vanilla').evaluate().length, find.byKey(const Key('common-greek-yogurt')).evaluate().length), (1, 1), reason: 'the brand and the plain food, each as itself');
      expect(find.descendant(of: find.byKey(const Key('common-greek-yogurt')), matching: find.text('Plain · nonfat')), findsOneWidget);
    });

    testWidgets('recent foods are logged again from where they were, for the meal chosen now; a favourite can be marked from the form', (tester) async {
      final logged = {...foodEntry('f1', '2026-10-07', 'Dinner', 'Rice, cooked, NFS', '2 × 1 cup, cooked', calories: 407.64, protein: 8.44, carbs: 88.45, fat: 0.88), 'source': {'item': riceCooked().j, 'quantity': 2, 'unit': 'serving:0'}};
      final typed = foodEntry('f2', '2026-10-08', 'Lunch', 'Soup from the canteen', '1 bowl', calories: 250);
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes, food: [logged, typed], savedFoods: [savedFood('s-nut', hazelnutSpread(), favourite: true)]),
          home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      expect(find.byKey(const Key('food-search-guide')), findsOneWidget, reason: 'an empty search shows recent foods and one line of guidance');
      expect(find.text('Soup from the canteen'), findsOneWidget);
      expect(find.text('As you logged it'), findsOneWidget);
      expect(find.text('1 bowl · 250 kcal'), findsOneWidget);
      expect(find.text('— protein'), findsOneWidget, reason: 'an unknown value is a dash');

      await _tap(tester, 'recent-usda:2708402');
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('2', '407.64'), reason: 'starts from the amount it was logged with');
      await _tap(tester, 'food-favourite');
      expect(fakes.savedFoods.favourited.single.sourceId, '2708402');
      expect(fakes.journal.saved, isEmpty, reason: 'marking a favourite is not eating');
      await _tap(tester, 'food-save');
      expect((fakes.journal.saved.single.dayKey, fakes.journal.saved.single.meal, fakes.journal.saved.single.quantity), (_day, 'Lunch', 2), reason: 'logged for the day and meal chosen now');
    });

    testWidgets('Recent, Favourites and My foods are the owner\'s own lists, narrowed by what is typed', (tester) async {
      final logged = {...foodEntry('f1', '2026-10-07', 'Dinner', 'Rice, cooked, NFS', '1 cup, cooked', calories: 203.82), 'source': {'item': riceCooked().j, 'quantity': 1, 'unit': 'serving:0'}};
      await pumpApp(tester, await _overrides(tester, FoodFakes(), food: [logged], savedFoods: [savedFood('s-nut', hazelnutSpread(), favourite: true), savedFood('s-oats', ownOats())]),
          home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      int rows(String key) => find.byKey(Key(key)).evaluate().length;

      await _tap(tester, 'food-scope-favourites');
      expect((rows('favourite-off:3017620422003'), rows('recent-usda:2708402'), rows('mine-user:s-oats')), (1, 0, 0));
      expect(find.text('Favourite · Nutella, Ferrero'), findsOneWidget);
      await _tap(tester, 'food-scope-mine');
      expect((rows('favourite-off:3017620422003'), rows('mine-user:s-oats')), (0, 1));
      expect(find.text('1 jar · 420 kcal'), findsOneWidget);
      await _tap(tester, 'food-scope-recent');
      expect((rows('recent-usda:2708402'), rows('mine-user:s-oats')), (1, 0));

      await tester.enterText(find.byKey(const Key('food-search')), 'zebra');
      await tester.pumpAndSettle();
      expect(find.text('Nothing in this list matches "zebra".'), findsOneWidget);
      await tester.pump(LogFoodScreen.pause);
      expect(find.byKey(const Key('food-search-busy')), findsNothing, reason: 'the owner\'s lists never ask the wider database');
      await _tap(tester, 'food-search-clear');
      expect(rows('recent-usda:2708402'), 1);
      expect(find.byKey(const Key('food-manual')), findsOneWidget, reason: 'creating a food is reachable from every list');
    });

    testWidgets('a new account sees guidance and honest empty lists, not a feature inventory', (tester) async {
      await pumpApp(tester, await _overrides(tester, FoodFakes()), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      expect(find.byKey(const Key('food-search-guide')), findsOneWidget);
      for (final (scope, title) in [('recent', 'Nothing logged yet'), ('favourites', 'No favourites yet'), ('mine', 'No foods of your own yet')]) {
        await _tap(tester, 'food-scope-$scope');
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('the keyboard, a change of theme and a trip to the form leave the query, category, meal and scroll position as they were', (tester) async {
      final fakes = FoodFakes();
      final container = await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 760));
      await _tap(tester, 'food-meal-select');
      await tester.tap(find.byKey(const Key('food-meal-option-Dinner')).last);
      await tester.pumpAndSettle();
      await _tap(tester, 'food-category-Proteins');
      await tester.enterText(find.byKey(const Key('food-search')), 'c');
      await tester.pumpAndSettle();
      final list = tester.state<ScrollableState>(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      final scrolled = list.position.pixels;
      expect(scrolled, greaterThan(100));
      void same(String when) {
        // "Proteins" twice: the chip, and the heading of the list it filters (scrolled just out of view, still laid out).
        expect((_field(tester, 'food-search'), mealShown(tester), find.text('Proteins', skipOffstage: false).evaluate().length, list.position.pixels), ('c', 'Dinner', 2, scrolled), reason: when);
        expect(tester.takeException(), isNull, reason: when);
      }

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);               // the keyboard comes up
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-search')).hitTestable(), findsOneWidget, reason: 'the field stays on screen above the keyboard');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      same('after the keyboard');

      container.read(appearanceProvider.notifier).setMode(ThemeMode.dark);
      container.read(appearanceProvider.notifier).setAccent(Accent.pink);
      await tester.pumpAndSettle();
      same('after a change of theme');

      await tester.tap(find.byIcon(Icons.add).hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.byType(FoodFormScreen), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget, reason: 'the meal chosen on the search screen is the form\'s meal');
      await _tap(tester, 'food-cancel');
      same('back from the form');
      expect(fakes.journal.saved, isEmpty, reason: 'cancelling leaves the journal alone');
    });

    testWidgets('what was found for one account is gone when the account changes', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [riceCooked()]));
      final container = await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3200));
      await tester.enterText(find.byKey(const Key('food-search')), 'rice');
      await tester.pumpAndSettle();
      await _tap(tester, 'food-search-online');
      expect(find.text('Rice, cooked, NFS'), findsOneWidget);

      await tester.runAsync(() => container.read(sessionsProvider).signOut());
      await tester.pumpAndSettle();
      expect((find.text('Rice, cooked, NFS').evaluate().length, find.text('More foods').evaluate().length), (0, 0), reason: 'the last account\'s results are not left on screen');
      await _tap(tester, 'food-search-online');
      expect(fakes.discovery.searches, ['rice', 'rice'], reason: 'nor kept to answer the next account');
    });

    testWidgets('search that is not set up on the server says so before anything is asked, and common foods still work', (tester) async {
      final fakes = FoodFakes();
      final server = FakeServer()..capabilities = {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': ['food.barcode']};
      final container = await pumpApp(tester, [...await _overrides(tester, fakes), transportProvider.overrideWithValue(server)], home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'));
      await tester.runAsync(() => container.read(compatibilityProvider.notifier).check());
      await tester.enterText(find.byKey(const Key('food-search')), 'chicken');
      await tester.pumpAndSettle();
      expect(find.textContaining('Wider food search is not set up on this server'), findsOneWidget);
      expect(find.byKey(const Key('food-search-online')), findsNothing);
      expect(find.byKey(const Key('common-chicken-breast')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('common-chicken-breast')), matching: find.text('Baked or roasted · skinless')), findsOneWidget);
      expect(find.byKey(const Key('food-scan')), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(LogFoodScreen.pause);
      expect(fakes.discovery.searches, isEmpty);
    });
  });

  group('the amount form', () {
    testWidgets('a corrected value is kept while the amount changes, is marked as yours, and can be put back; saving a reusable food logs nothing', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: FoodFormScreen(draft: FoodDraft.of(hazelnutSpread(), dayKey: _day, meal: 'Snack')), size: const Size(390, 1500));
      await tester.enterText(find.byKey(const Key('food-protein')), '2');
      await tester.pumpAndSettle();
      expect(find.text('Your value'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('food-quantity')), '2');
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-protein'), _field(tester, 'food-calories')), ('2', '161.7'), reason: 'the correction stays; the rest follows the amount');

      await _tap(tester, 'food-save-reusable');
      expect(find.textContaining('Nothing was logged'), findsOneWidget);
      expect((fakes.savedFoods.mine.single.quantity, fakes.savedFoods.mine.single.values['protein'], fakes.savedFoods.mine.single.from!.source), (2, 2, 'off'));
      expect(fakes.journal.saved, isEmpty);
      expect(find.byType(FoodFormScreen), findsOneWidget, reason: 'still on the form, with everything typed');

      await _tap(tester, 'food-reset-values');
      expect(_field(tester, 'food-protein'), '1.89');
      expect(find.text('Your value'), findsNothing);

      await tester.enterText(find.byKey(const Key('food-quantity')), '0');
      await _tap(tester, 'food-save');
      expect(find.textContaining('a number above zero'), findsOneWidget);
      expect(fakes.journal.saved, isEmpty);
    });

    testWidgets('changing the unit says the same amount in the new unit, both ways, and the values do not move', (tester) async {
      final cereal = FoodItem({'source': 'usda', 'sourceId': 'c1', 'name': 'Bran flakes', 'basis': '100g', 'nutrients': {'calories': 360, 'protein': 10, 'carbs': 70, 'fat': null},
        'servings': [{'label': '1 serving', 'grams': 30, 'milliliters': null}]});
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: FoodFormScreen(draft: FoodDraft.of(cereal, dayKey: _day, meal: 'Breakfast')), size: const Size(390, 1500));
      Future<void> choose(String unitId) async {
        await _tap(tester, 'food-unit');
        await tester.tap(find.byKey(Key('food-unit-$unitId')).last);
        await tester.pumpAndSettle();
      }

      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('1', '108'));
      expect(find.text('1 serving (30 g)'), findsOneWidget, reason: 'the amount is spelled out with what it weighs');
      expect(find.text('Nutrition for 1 serving (30 g)'), findsOneWidget);

      await choose('g');
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories'), _field(tester, 'food-fat')), ('30', '108', ''), reason: 'one 30 g serving is 30 g, not 1 g; unknown fat stays blank');
      expect(find.text('Nutrition for 30 g'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('food-quantity')), '45');
      await tester.pumpAndSettle();
      await choose('serving:0');
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('1.5', '162'));
      expect(find.text('1½ servings (45 g)'), findsOneWidget);

      await _tap(tester, 'food-save');
      final logged = fakes.journal.saved.single;
      expect((logged.amount, logged.quantity, logged.unitId, logged.calories, logged.fat), ('1½ servings (45 g)', 1.5, 'serving:0', 162, null));
    });

    testWidgets('a portion is defined in the user\'s own words, becomes the unit with the amount kept, and joins the kept copy of the food', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes, savedFoods: [savedFood('s-nut', hazelnutSpread(), favourite: true)]),
          home: FoodFormScreen(draft: FoodDraft.of(hazelnutSpread(), dayKey: _day, meal: 'Snack')), size: const Size(390, 1500));
      await tester.enterText(find.byKey(const Key('food-quantity')), '4');   // four 15 g servings
      await tester.pumpAndSettle();

      await _tap(tester, 'food-add-portion');
      expect(_field(tester, 'portion-amount'), '', reason: 'no weight is suggested from the name of the food or the portion');
      await tester.enterText(find.byKey(const Key('portion-name')), 'spoon');
      await _tap(tester, 'portion-add');
      expect(find.textContaining('how much one spoon is'), findsOneWidget, reason: 'a portion without an amount is not accepted');
      await tester.enterText(find.byKey(const Key('portion-amount')), '20');
      await _tap(tester, 'portion-add');

      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('3', '323.4'), reason: '60 g is three 20 g spoons, with the values of 60 g');
      expect(find.text('3 spoons (60 g)'), findsOneWidget);
      expect(fakes.journal.saved, isEmpty, reason: 'defining a portion logs nothing');
      expect((fakes.savedFoods.portioned.single.food.id, fakes.savedFoods.portioned.single.from.servings.last.label), ('s-nut', '1 spoon'));

      await tester.enterText(find.byKey(const Key('food-quantity')), '0.5');
      await tester.pumpAndSettle();
      await _tap(tester, 'food-save');
      final logged = fakes.journal.saved.single;
      expect((logged.amount, logged.quantity, logged.unitId, logged.calories, logged.item!.servings.last.isUserDefined), ('½ spoon (10 g)', 0.5, 'serving:1', 53.9, true));
    });

    testWidgets('a food met again offers the portion defined on its kept copy; a draft survives a change of theme', (tester) async {
      final spooned = FoodScaling.withPortion(hazelnutSpread(), 'spoon', 20);
      final fakes = FoodFakes(discovery: ScriptedDiscovery(products: {'3017620422003': hazelnutSpread()}), cameraRefused: true);
      final container = await pumpApp(tester, await _overrides(tester, fakes, savedFoods: [savedFood('s-mine', FoodItem({...spooned.j, 'source': 'user', 'sourceId': 's-mine'})), savedFood('s-nut', spooned, favourite: true)]),
          home: const LogFoodScreen(dayKey: _day, meal: 'Snack'), size: const Size(390, 1600));
      await _tap(tester, 'food-scan');
      await tester.enterText(find.byKey(const Key('barcode-typed')), '3017620422003');
      await _tap(tester, 'barcode-typed-submit');
      expect(find.byKey(const Key('food-source')), findsOneWidget);
      await _tap(tester, 'food-unit');
      expect(find.text('spoon · 20 g each'), findsWidgets, reason: 'the provider\'s fresh copy has the user\'s portion again');
      await tester.tap(find.byKey(const Key('food-unit-serving:1')).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food-quantity')), '2.5');
      await tester.pumpAndSettle();

      container.read(appearanceProvider.notifier).setMode(ThemeMode.dark);
      container.read(appearanceProvider.notifier).setAccent(Accent.pink);
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('2.5', '269.5'), reason: 'changing the look leaves the open draft alone');
      expect(find.text('2½ spoons (50 g)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grams to a cup and back is the same grams: the amount is kept exactly and only what is shown is rounded', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: FoodFormScreen(draft: FoodDraft.of(riceCooked(), dayKey: _day, meal: 'Dinner')), size: const Size(390, 1500));
      Future<void> choose(String unitId) async {
        await _tap(tester, 'food-unit');
        await tester.tap(find.byKey(Key('food-unit-$unitId')).last);
        await tester.pumpAndSettle();
      }

      await choose('g');
      await tester.enterText(find.byKey(const Key('food-quantity')), '100');
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-calories'), _field(tester, 'food-protein')), ('129', '2.67'));

      await choose('serving:0');                                                 // 100 g of a 158 g cup
      expect(_field(tester, 'food-quantity'), '0.63', reason: 'shown to two decimals');
      expect((_field(tester, 'food-calories'), _field(tester, 'food-protein')), ('129', '2.67'), reason: 'still the values of 100 g, not of 0.63 cup');
      expect(find.text('0.63 cup, cooked (100 g)'), findsOneWidget);

      await choose('g');
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('100', '129'), reason: 'not 99.54 g');
      await choose('serving:0');
      await choose('g');
      expect(_field(tester, 'food-quantity'), '100', reason: 'however often the unit is changed');

      await _tap(tester, 'food-save');
      final logged = fakes.journal.saved.single;
      expect((logged.amount, logged.quantity, logged.unitId, logged.calories, logged.meal), ('100 g', 100, 'g', 129, 'Dinner'));
    });

    testWidgets('a count portion takes fractions, and a value the source does not give stays unknown through every unit', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: FoodFormScreen(draft: FoodDraft.of(sparseDrink(), dayKey: _day, meal: 'Snack')), size: const Size(390, 1500));
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories'), _field(tester, 'food-protein')), ('1', '138.6', ''), reason: 'one 330 ml can; protein is not stated');
      await tester.enterText(find.byKey(const Key('food-quantity')), '1.5');
      await tester.pumpAndSettle();
      expect(find.text('1½ cans (330 ml each) (495 ml)'), findsOneWidget);
      await _tap(tester, 'food-unit');
      await tester.tap(find.byKey(const Key('food-unit-ml')).last);
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories'), _field(tester, 'food-protein'), _field(tester, 'food-fat')), ('495', '207.9', '', ''));
      await _tap(tester, 'food-save');
      final logged = fakes.journal.saved.single;
      expect((logged.quantity, logged.unitId, logged.amount, logged.calories, logged.protein, logged.carbs, logged.fat), (495, 'ml', '495 ml', 207.9, null, null, null));
    });

    testWidgets('Food details opens the source in full: provider title, basis values, credit and barcode; opening it logs nothing', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: FoodFormScreen(draft: FoodDraft.of(hazelnutSpread(), dayKey: _day, meal: 'Snack', name: 'Chocolate spread')), size: const Size(390, 1500));
      expect(find.descendant(of: find.byKey(const Key('food-source')), matching: find.text('Nutella')), findsOneWidget, reason: 'the provider title, under the everyday name');
      expect(find.descendant(of: find.byKey(const Key('food-source')), matching: find.textContaining('Open Food Facts · Open Database License')), findsOneWidget);
      await _tap(tester, 'food-source');
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.text('Food details')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Nutella')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('Nutrition per 100 g')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('Source: Open Food Facts · Open Database License · Barcode 3017620422003')), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect((find.byType(BottomSheet).evaluate().length, fakes.journal.saved.length), (0, 0));
    });

    testWidgets('the read-out shows an unknown value as a dash and follows the amount and unit exactly; a corrected value is marked in it', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: FoodFormScreen(draft: FoodDraft.of(sparseDrink(), dayKey: _day, meal: 'Snack')), size: const Size(390, 1500));
      for (final key in ['food-protein', 'food-carbs', 'food-fat']) {
        expect(find.descendant(of: find.byKey(Key(key)), matching: find.text('—')), findsOneWidget, reason: '$key is unknown, never zero');
      }
      expect(find.text('Nutrition for 1 can (330 ml)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('food-quantity')), '3');
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-calories'), _field(tester, 'food-protein')), ('415.8', ''));
      expect(find.text('Nutrition for 3 cans (330 ml each) (990 ml)'), findsOneWidget);
      await _tap(tester, 'food-unit');
      await tester.tap(find.byKey(const Key('food-unit-ml')).last);
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('990', '415.8'));

      await tester.tap(find.byKey(const Key('food-protein')));                   // tapping a value is how it is corrected
      await tester.enterText(find.byKey(const Key('food-protein')), '1');
      await tester.pumpAndSettle();
      expect(find.text('Your value'), findsOneWidget);
      await _tap(tester, 'food-save');
      expect((fakes.journal.saved.single.protein, fakes.journal.saved.single.calories), (1, 415.8));
    });

    testWidgets('Cancel and back never log; Log food logs once', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 1600));
      await tester.enterText(find.byKey(const Key('food-search')), 'eggs');
      await tester.pumpAndSettle();
      await _tap(tester, 'common-eggs');
      await _tap(tester, 'food-cancel');
      await _tap(tester, 'common-eggs');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((find.byType(FoodFormScreen).evaluate().length, fakes.journal.saved.length), (0, 0));
      await _tap(tester, 'common-eggs');
      await _tap(tester, 'food-save');
      expect((fakes.journal.saved.length, fakes.journal.saved.single.name, fakes.journal.saved.single.meal), (1, 'Eggs', 'Lunch'));
    });

    testWidgets('with the keyboard up on a 320 px phone at 2x text, the amount and Log food stay reachable', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), home: FoodFormScreen(draft: FoodDraft.of(hazelnutSpread(), dayKey: _day, meal: 'Snack')), size: const Size(320, 640), textScale: 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('food-quantity')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-quantity')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('food-save')).hitTestable(), findsOneWidget, reason: 'the pinned action rides above the keyboard');
      await tester.enterText(find.byKey(const Key('food-quantity')), '2');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-save')));
      await tester.pumpAndSettle();
      expect((fakes.journal.saved.single.quantity, tester.takeException()), (2, null));
    });

  });

  group('goals and the shared totals', () {
    FoodEntry entry(String id, {num? calories, num? protein}) => FoodEntry(foodEntry(id, _day, 'Lunch', 'Food $id', '1', calories: calories, protein: protein));
    Future<void> surface(WidgetTester tester, List<FoodEntry> entries, {int? calorieGoal, int? proteinGoal}) => pumpApp(tester, const [],
        home: Scaffold(body: SingleChildScrollView(child: NutritionSurface(entries: entries, coverage: NutrientCoverage.calculate(entries), calorieGoal: calorieGoal, proteinGoal: proteinGoal))));

    testWidgets('a rail appears only for a goal that was set', (tester) async {
      await surface(tester, [entry('a', calories: 1400, protein: 62)]);
      expect(find.byType(ProgressRail), findsNothing);
      await surface(tester, [entry('a', calories: 1400, protein: 62)], proteinGoal: 140);
      expect(find.byKey(const Key('goal-calories-progress')), findsNothing);
      expect(find.byKey(const Key('goal-protein-progress')), findsOneWidget);
      expect(find.text('Protein 62 of 140 g · 78 g left'), findsOneWidget);
    });

    testWidgets('complete totals say what is left; a partial sum is called known and states no remainder', (tester) async {
      await surface(tester, [entry('a', calories: 900, protein: 40), entry('b', calories: 500, protein: 22)], calorieGoal: 2200, proteinGoal: 140);
      expect(find.text('1,400 of 2,200 kcal · 800 kcal left'), findsOneWidget);

      await surface(tester, [entry('a', calories: 900, protein: 40), entry('b', protein: 22)], calorieGoal: 2200, proteinGoal: 140);
      expect(find.text('900 of 2,200 kcal · known so far'), findsOneWidget);
      expect(find.textContaining('kcal left'), findsNothing, reason: 'a remainder from a partial sum would be invented');
      expect(find.text('Protein 62 of 140 g · 78 g left'), findsOneWidget, reason: 'protein is complete, so its remainder is real');

      await surface(tester, [entry('a')], calorieGoal: 2200);
      expect(find.text('No calorie value entered yet · goal 2,200 kcal'), findsOneWidget);
      expect(find.byType(ProgressRing), findsNothing, reason: 'an unknown total is not an empty ring');
      await surface(tester, const [], calorieGoal: 2200, proteinGoal: 140);
      expect(find.text('Your daily goal: 2,200 kcal · 140 g protein'), findsOneWidget);
      expect(find.byType(ProgressRail), findsNothing, reason: 'nothing logged is not zero eaten');
    });

    testWidgets('over the goal the rail stays full while the words give the real total', (tester) async {
      final handle = tester.ensureSemantics();
      await surface(tester, [entry('a', calories: 2500, protein: 150)], calorieGoal: 2200, proteinGoal: 140);
      expect(find.text('2,500 of 2,200 kcal · 300 kcal over'), findsOneWidget);
      expect(find.text('114%'), findsOneWidget, reason: "the ring's centre gives the real share");
      final ring = tester.getSemantics(find.byKey(const Key('goal-calories-progress')));
      expect((ring.label, ring.value), ('Calorie goal: 2,500 of 2,200 kcal · 300 kcal over', '100 percent'), reason: 'the ring stops at full');
      expect(tester.widget<LinearProgressIndicator>(find.descendant(of: find.byKey(const Key('goal-protein-progress')), matching: find.byType(LinearProgressIndicator))).value, 1.0);
      handle.dispose();
    });

    testWidgets('Today and Eat show the same totals and the same progress', (tester) async {
      final fakes = FoodFakes();
      final food = [foodEntry('f1', _day, 'Breakfast', 'Yogurt', '1 bowl', calories: 380, protein: 24), foodEntry('f2', _day, 'Lunch', 'Chicken and rice', '1 plate', calories: 650, protein: 48)];
      await pumpApp(tester, await _overrides(tester, fakes, food: food, calorieGoal: 2200, proteinGoal: 140), size: const Size(390, 2000));
      // Today shows the same numbers in its shorter form.
      await _tap(tester, 'nav-today');
      for (final text in ['1,030', '/ 2,200 kcal', '72', '/ 140 g protein']) {
        expect(find.text(text).hitTestable(), findsOneWidget, reason: text);
      }
      await _tap(tester, 'nav-eat');
      expect(find.text('1,030 of 2,200 kcal · 1,170 kcal left').hitTestable(), findsOneWidget);
      expect(find.text('Protein 72 of 140 g · 68 g left').hitTestable(), findsOneWidget);
    });

    testWidgets('goals start empty, are checked, and blank means none', (tester) async {
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes), size: const Size(390, 2000));
      await _tap(tester, 'nav-me');
      expect(find.text('None set'), findsOneWidget);
      await _tap(tester, 'me-goals');
      expect((_field(tester, 'goal-calories'), _field(tester, 'goal-protein')), ('', ''), reason: 'no goal is suggested or pre-filled');

      await tester.enterText(find.byKey(const Key('goal-calories')), '300');
      await _tap(tester, 'goal-save');
      expect(find.textContaining('500 to 10,000'), findsWidgets);
      expect(fakes.profiles.goals, isEmpty);
      await tester.enterText(find.byKey(const Key('goal-calories')), '2200.5');
      await _tap(tester, 'goal-save');
      expect(find.textContaining('whole number'), findsWidgets);

      await tester.enterText(find.byKey(const Key('goal-calories')), '2200');
      await _tap(tester, 'goal-save');
      expect(fakes.profiles.goals, [(2200, null)]);
      expect(find.byType(NutritionGoalsScreen), findsNothing);
    });
  });

  testWidgets('a build the server no longer accepts is blocked over the open form, and the form is intact when the block lifts', (tester) async {
    final fakes = FoodFakes();
    final server = FakeServer()..capabilities = {'contractVersion': 2, 'minimumClientContract': 2, 'capabilities': []};
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await pumpApp(tester, [...await _overrides(tester, fakes), transportProvider.overrideWithValue(server), dbProvider.overrideWithValue(db)],
        home: FoodFormScreen(draft: FoodDraft.of(hazelnutSpread(), dayKey: _day, meal: 'Snack')), size: const Size(390, 1500));
    await tester.enterText(find.byKey(const Key('food-quantity')), '3');
    await tester.pumpAndSettle();

    await tester.runAsync(() => container.read(compatibilityProvider.notifier).check());
    await tester.pumpAndSettle();
    expect(find.text('Update GoHard to continue'), findsOneWidget);
    expect(find.textContaining('still here'), findsOneWidget);
    expect(find.byKey(const Key('food-save')).hitTestable(), findsNothing, reason: 'nothing underneath can be pressed');

    server.capabilities = {'contractVersion': 2, 'minimumClientContract': 1, 'capabilities': []};
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('compat-recheck')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await container.read(syncProvider).idle();
    });
    await tester.pumpAndSettle();
    expect(find.text('Update GoHard to continue'), findsNothing);
    expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('3', '242.55'), reason: 'what was typed is exactly as it was');
    container.read(syncProvider).dispose();
  });

  group('looks and access', () {
    Future<void> guidelines(WidgetTester tester, String what) async {
      await expectLater(tester, meetsGuideline(textContrastGuideline), reason: what);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: what);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: what);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: what);
    }

    final recent = {...foodEntry('f1', '2026-10-07', 'Dinner', 'Rice, cooked, NFS', '1 cup, cooked', calories: 203.82), 'source': {'item': riceCooked().j, 'quantity': 1, 'unit': 'serving:0'}};

    for (final accent in Accent.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('${accent.name} ${mode.name}: search, results, preview, scanner fallback and goals meet contrast, target and label guidelines', (tester) async {
          final handle = tester.ensureSemantics();
          final store = AppearanceStore(MemorySecretStore())
            ..accent = accent
            ..mode = mode;
          final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [chickenRaw(), riceCooked(), sparseDrink()]), cameraRefused: false);
          await pumpApp(tester, await _overrides(tester, fakes, food: [recent], savedFoods: [savedFood('s-nut', hazelnutSpread(), favourite: true), savedFood('s-oats', ownOats())], appearance: store, calorieGoal: 2200, proteinGoal: 140),
              home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 3600));
          await guidelines(tester, 'recent foods and guidance');
          await _tap(tester, 'food-scope-favourites');
          await guidelines(tester, 'favourites');
          await _tap(tester, 'food-scope-search');
          await _tap(tester, 'food-category-Proteins');
          await guidelines(tester, 'a category of common foods');
          await _tap(tester, 'food-category-all');

          await tester.enterText(find.byKey(const Key('food-search')), 'c');
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('food-search')), 'co');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          await guidelines(tester, 'search results');

          await _tap(tester, 'result-off:5449000000996');
          await guidelines(tester, 'preview of a food with unknown values');
          await _tap(tester, 'food-source');
          await guidelines(tester, 'the food details sheet');
          await tester.tapAt(const Offset(10, 10));                              // the barrier closes the sheet
          await tester.pumpAndSettle();
          await _tap(tester, 'food-cancel');

          await _tap(tester, 'food-scan');
          await guidelines(tester, 'scanner without a camera');
          await tester.enterText(find.byKey(const Key('barcode-typed')), '1');
          await _tap(tester, 'barcode-typed-submit');
          await guidelines(tester, 'scanner with an error');
          handle.dispose();
        });
      }
    }

    testWidgets('large text on a narrow phone: nothing overflows on search, preview, scanner or goals', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [chickenRaw(), riceCooked(), sparseDrink()]), cameraRefused: true);
      final overrides = await _overrides(tester, fakes, food: [recent], savedFoods: [savedFood('s-nut', hazelnutSpread(), favourite: true)], calorieGoal: 2200, proteinGoal: 140);
      const narrow = Size(320, 2600);
      await pumpApp(tester, overrides, home: const LogFoodScreen(dayKey: _day, meal: 'Breakfast'), size: narrow, textScale: 2);
      await tester.enterText(find.byKey(const Key('food-search')), 'co');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'search');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);               // the keyboard, over large text on a small phone
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'search with the keyboard up');
      tester.view.resetViewInsets();
      for (final key in ['food-category-Snacks', 'food-category-all', 'food-scope-mine', 'food-scope-search']) {
        await _tap(tester, key);
        expect(tester.takeException(), isNull, reason: key);
      }
      expect(_field(tester, 'food-search'), 'co');
      await _tap(tester, 'food-scan');
      expect(tester.takeException(), isNull, reason: 'scanner');
      await tester.pumpWidget(const SizedBox());                                 // a fresh app for the next screen

      await pumpApp(tester, overrides, home: FoodFormScreen(draft: FoodDraft.of(sparseDrink(), dayKey: _day, meal: 'Breakfast')), size: narrow, textScale: 2);
      expect(tester.takeException(), isNull, reason: 'preview');
      expect(find.byKey(const Key('food-fat')), findsOneWidget, reason: 'every field stays built on a form with a pinned action');
      await tester.pumpWidget(const SizedBox());

      await pumpApp(tester, overrides, home: NutritionGoalsScreen(profile: Profile(authFor('one')['profile'] as Json)), size: narrow, textScale: 2);
      expect(tester.takeException(), isNull, reason: 'goals');
    });
  });
}
