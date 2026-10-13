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
  group('one journey from finding a food to logging it', () {
    testWidgets('search is asked for on purpose, a result opens the shared form, the amount rescales it, and only the confirmation logs', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [chickenRaw(), riceCooked()]));
      await pumpApp(tester, await _overrides(tester, fakes), size: const Size(390, 1400));

      await _tap(tester, 'log-food');                                            // from Today
      await tester.enterText(find.byKey(const Key('food-search')), 'chicken');
      await tester.pumpAndSettle();
      expect(fakes.discovery.searches, isEmpty, reason: 'typing alone asks the provider nothing');
      await _tap(tester, 'food-search-online');
      expect(fakes.discovery.searches, ['chicken']);
      expect(find.text('Chicken, breast, meat only, raw'), findsOneWidget);
      expect(find.textContaining('120 kcal per 100 g'), findsOneWidget);
      expect(fakes.journal.saved, isEmpty, reason: 'searching logs nothing');

      await _tap(tester, 'result-usda:171077');
      expect(find.byKey(const Key('food-source')), findsOneWidget);
      expect(find.textContaining('Source: USDA FoodData Central'), findsOneWidget);
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories'), _field(tester, 'food-carbs')), ('100', '120', '0'), reason: 'a stated zero is shown as zero');
      expect(fakes.journal.saved, isEmpty, reason: 'opening the preview logs nothing');

      await tester.enterText(find.byKey(const Key('food-quantity')), '150');
      await tester.pumpAndSettle();
      expect((_field(tester, 'food-calories'), _field(tester, 'food-protein'), _field(tester, 'food-fat')), ('180', '33.75', '3.93'));

      await _tap(tester, 'food-save');
      final logged = fakes.journal.saved.single;
      expect((logged.dayKey, logged.meal, logged.name, logged.amount, logged.quantity, logged.unitId, logged.calories, logged.protein), (_day, 'Breakfast', 'Chicken, breast, meat only, raw', '150 g', 150, 'g', 180, 33.75));
      expect(logged.item!.sourceId, '171077');
      expect(find.byKey(const Key('food-search')), findsNothing, reason: 'back where logging began');
      expect(find.byKey(const Key('nav-today')), findsOneWidget);
    });

    testWidgets('cancelling a preview or a scan logs nothing and the search is still there; manual entry carries the meal and what was typed', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(results: [riceCooked()]));
      await pumpApp(tester, await _overrides(tester, fakes), size: const Size(390, 1400));
      await _tap(tester, 'nav-eat');
      await _tap(tester, 'eat-add-dinner');
      expect(find.textContaining('Dinner ·'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('food-search')), 'rice');
      await tester.testTextInput.receiveAction(TextInputAction.search);          // the keyboard's search key works too
      await tester.pumpAndSettle();
      await _tap(tester, 'result-usda:2708402');
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('1', '203.82'), reason: 'one stated serving of 158 g');
      await _tap(tester, 'food-cancel');
      expect((_field(tester, 'food-search'), find.text('Rice, cooked, NFS').evaluate().length), ('rice', 1), reason: 'the search and its results are still there');

      await _tap(tester, 'food-scan');
      await _tap(tester, 'barcode-cancel');
      expect(fakes.discovery.barcodes, isEmpty);

      await _tap(tester, 'food-manual');
      expect(_field(tester, 'food-name'), 'rice');
      expect(find.byKey(const Key('food-source')), findsNothing);
      expect(find.text('Dinner'), findsOneWidget);
      await _tap(tester, 'food-cancel');
      expect(fakes.journal.saved, isEmpty);
      expect(fakes.discovery.searches, ['rice'], reason: 'one search, asked once');
    });

    testWidgets('a barcode seen many times is one lookup and one draft; a web link is ignored; a double tap logs once', (tester) async {
      final fakes = FoodFakes(
          discovery: ScriptedDiscovery(products: {'3017620422003': hazelnutSpread()}),
          codes: ['https://example.test/free-prize', '3017620422003', '3017620422003', '3017620422003', '3017620422003']);
      await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Snack'), size: const Size(390, 1400));

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
      expect((fakes.journal.saved.single.meal, fakes.journal.saved.single.amount), ('Snack', '15 g'));
    });

    testWidgets('camera refused: typing the barcode works; an unknown product says so and leads to manual entry', (tester) async {
      final fakes = FoodFakes(cameraRefused: true);
      await pumpApp(tester, await _overrides(tester, fakes), home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 1400));
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

    testWidgets('offline: the search says so, foods already on the phone are still offered, and one of them can be logged', (tester) async {
      final fakes = FoodFakes(discovery: ScriptedDiscovery(searchProblem: LookupProblem.offline));
      await pumpApp(tester, await _overrides(tester, fakes, savedFoods: [savedFood('s-oats', ownOats())], seenFoods: [hazelnutSpread().j]),
          home: const LogFoodScreen(dayKey: _day, meal: 'Breakfast'), size: const Size(390, 1400));
      expect(find.text('My foods'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('food-search')), 'o');
      await tester.pumpAndSettle();
      expect(find.text('Overnight oats'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('food-search')), 'nut');
      await tester.pumpAndSettle();
      expect(find.text('Nutella'), findsOneWidget, reason: 'a product looked up earlier is found without a connection');
      await _tap(tester, 'food-search-online');
      expect(find.textContaining('You are offline'), findsOneWidget);
      expect(find.text('Nutella'), findsOneWidget);
      expect(find.byKey(const Key('food-manual')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('food-search')), 'oats');
      await tester.pumpAndSettle();
      await _tap(tester, 'local-user:s-oats');
      expect(find.textContaining('Your own food'), findsOneWidget);
      expect(find.textContaining('gives no value for fat'), findsOneWidget);
      expect((_field(tester, 'food-fat'), _field(tester, 'food-calories')), ('', '420'), reason: 'unknown stays blank, not zero');
      await _tap(tester, 'food-save');
      expect((fakes.journal.saved.single.fat, fakes.journal.saved.single.amount), (null, '1 jar'));
    });

    testWidgets('recent and favourite foods are logged again from where they were; a favourite can be marked from the form', (tester) async {
      final logged = {...foodEntry('f1', '2026-10-07', 'Dinner', 'Rice, cooked, NFS', '2 × 1 cup, cooked', calories: 407.64, protein: 8.44, carbs: 88.45, fat: 0.88), 'source': {'item': riceCooked().j, 'quantity': 2, 'unit': 'serving:0'}};
      final typed = foodEntry('f2', '2026-10-08', 'Lunch', 'Soup from the canteen', '1 bowl', calories: 250);
      final fakes = FoodFakes();
      await pumpApp(tester, await _overrides(tester, fakes, food: [logged, typed], savedFoods: [savedFood('s-nut', hazelnutSpread(), favourite: true)]),
          home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 1600));
      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.textContaining('1 bowl · as you logged it'), findsOneWidget);

      await _tap(tester, 'recent-usda:2708402');
      expect((_field(tester, 'food-quantity'), _field(tester, 'food-calories')), ('2', '407.64'), reason: 'starts from the amount it was logged with');
      await _tap(tester, 'food-favourite');
      expect(fakes.savedFoods.favourited.single.sourceId, '2708402');
      expect(fakes.journal.saved, isEmpty, reason: 'marking a favourite is not eating');
      await _tap(tester, 'food-save');
      expect((fakes.journal.saved.single.dayKey, fakes.journal.saved.single.meal, fakes.journal.saved.single.quantity), (_day, 'Lunch', 2), reason: 'logged for the day and meal chosen now');
    });

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

    testWidgets('search that is not set up on the server says so before anything is asked', (tester) async {
      final fakes = FoodFakes();
      final server = FakeServer()..capabilities = {'contractVersion': 1, 'minimumClientContract': 1, 'capabilities': ['food.barcode']};
      final container = await pumpApp(tester, [...await _overrides(tester, fakes), transportProvider.overrideWithValue(server)], home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'));
      await tester.runAsync(() => container.read(compatibilityProvider.notifier).check());
      await tester.enterText(find.byKey(const Key('food-search')), 'chicken');
      await tester.pumpAndSettle();
      expect(find.textContaining('Online food search is not set up on this server'), findsOneWidget);
      expect(find.byKey(const Key('food-search-online')), findsNothing);
      expect(find.byKey(const Key('food-scan')), findsOneWidget);
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
      await surface(tester, const [], calorieGoal: 2200, proteinGoal: 140);
      expect(find.text('Your daily goal: 2,200 kcal · 140 g protein'), findsOneWidget);
      expect(find.byType(ProgressRail), findsNothing, reason: 'nothing logged is not zero eaten');
    });

    testWidgets('over the goal the rail stays full while the words give the real total', (tester) async {
      final handle = tester.ensureSemantics();
      await surface(tester, [entry('a', calories: 2500, protein: 150)], calorieGoal: 2200, proteinGoal: 140);
      expect(find.text('2,500 of 2,200 kcal · 300 kcal over'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.descendant(of: find.byKey(const Key('goal-calories-progress')), matching: find.byType(LinearProgressIndicator))).value, 1.0);
      expect(find.bySemanticsLabel(RegExp('Calorie goal: 2,500 of 2,200 kcal · 300 kcal over')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Today and Eat show the same totals and the same progress', (tester) async {
      final fakes = FoodFakes();
      final food = [foodEntry('f1', _day, 'Breakfast', 'Yogurt', '1 bowl', calories: 380, protein: 24), foodEntry('f2', _day, 'Lunch', 'Chicken and rice', '1 plate', calories: 650, protein: 48)];
      await pumpApp(tester, await _overrides(tester, fakes, food: food, calorieGoal: 2200, proteinGoal: 140), size: const Size(390, 2000));
      // Today shows the same numbers in its shorter form.
      await _tap(tester, 'nav-today');
      for (final text in ['1,030', 'of 2,200 · 1,170 left', '72', 'of 140 · 68 left']) {
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
              home: const LogFoodScreen(dayKey: _day, meal: 'Lunch'), size: const Size(390, 1900));
          await guidelines(tester, 'saved and recent foods');

          await tester.enterText(find.byKey(const Key('food-search')), 'c');
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('food-search')), 'co');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          await guidelines(tester, 'search results');

          await _tap(tester, 'result-off:5449000000996');
          await guidelines(tester, 'preview of a food with unknown values');
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
