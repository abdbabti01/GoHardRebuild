import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_form.dart' show FoodFormScreen;
import 'package:gohard_rebuild/features/nutrition/food_repository.dart' show FoodDraft;
import 'package:gohard_rebuild/features/nutrition/saved_meals.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals_screens.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';

import 'food_fakes.dart';
import 'saved_meals_test.dart' show breakfast, chili;
import 'ui_support.dart';
import 'package:gohard_rebuild/features/plus/entitlement.dart' show CreateGate;

/// The saved meals & recipes screens with recorded collaborators: what each action asks for, and what it never does.
/// With `--dart-define=GOHARD_RENDER=true` (and GOHARD_RENDER_LANG=fr|ar) the last group also writes renders of the
/// library, editor, recipe editor and log review to docs/evidence/saved-meals. They are renders of the Flutter widgets
/// with FIXTURE meals, not phone captures.

const day = '2026-10-11';
const _render = bool.fromEnvironment('GOHARD_RENDER');
const _out = renderLanguage == '' ? '../docs/evidence/saved-meals' : '../docs/evidence/localization/$renderLanguage/saved-meals';

class RecordingMeals implements SavedMealRepository {
  @override
  (CreateGate, int) Function()? get mayCreate => null;
  final puts = <({MealBody body, String? id})>[];
  final removed = <SavedMeal>[];
  @override
  Future<String> put(MealBody body, {String? id}) async {
    SavedMealRepository.validate(body);
    puts.add((body: body, id: id));
    return id ?? 'new-id';
  }

  @override
  Future<Receipt> remove(SavedMeal m) async {
    removed.add(m);
    return const Receipt('op', 'pending');
  }

  @override
  Future<void> keepDraft(String key, MealBody body, {MealBody? base}) async {}
  @override
  Future<({MealBody body, MealBody? base})?> draft(String key) async => null;
  @override
  Future<void> dropDraft(String key) async {}
}

Json _saved(String id, MealBody b) => {'id': id, 'body': b.j, 'revision': 1, 'isDeleted': false};

Future<(List<Override>, FoodFakes, RecordingMeals)> _fixture(WidgetTester tester, {AppearanceStore? appearance, List<Json>? food}) async {
  final fakes = FoodFakes(), meals = RecordingMeals();
  final defs = [_saved('m1', breakfast()), _saved('r1', chili(weight: 1200))];
  return (
    [
      ...(await tester.runAsync(() => overridesFor(day: day, appearance: appearance, food: food ?? const [])))!,
      ...fakes.overrides,
      savedMealRepositoryProvider.overrideWithValue(meals),
      savedMealsProvider.overrideWith((ref) => Stream.value([for (final d in defs) stored(SavedMeal(d), Kinds.savedMeal, d['id'] as String, d)])),
      mealDraftsProvider.overrideWith((ref) => Stream.value(const {})),
    ],
    fakes,
    meals,
  );
}

Future<void> _fonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await inter.load();
  await (FontLoader(serif)..addFont(File('assets/fonts/DMSerifDisplay-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  await loadArabicFonts();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_fonts);

  testWidgets('Eat opens the library; a meal is reviewed, multiplied and logged once, and the saved meal is untouched', (tester) async {
    final (overrides, fakes, meals) = await _fixture(tester);
    await pumpApp(tester, overrides, size: const Size(390, 1400));
    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    await _tap(tester, find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-saved-meals'))));
    expect(find.text('Saved meals & recipes'), findsWidgets);
    expect(find.descendant(of: find.byKey(const Key('meals-row-m1')), matching: find.text('2 foods · 370 kcal')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('meals-row-m1')));
    expect(fakes.journal.meals, isEmpty, reason: 'opening a saved meal logs nothing');
    await _tap(tester, find.byKey(const Key('meal-factor-1.5')));
    expect(find.text('3 eggs (150 g)'), findsOneWidget);
    expect(find.text('90 g'), findsOneWidget);
    // Changing only the meal logs nothing either.
    await _tap(tester, find.byKey(const Key('meal-review-meal')));
    await _tap(tester, find.text('Dinner').last);
    expect(fakes.journal.meals, isEmpty);

    final log = find.byKey(const Key('meal-log'));
    await tester.ensureVisible(log);
    await tester.tap(log);
    await tester.tap(log, warnIfMissed: false); // a rapid second tap
    await tester.pumpAndSettle();
    expect(fakes.journal.meals, hasLength(1));
    final logged = fakes.journal.meals.single;
    expect([for (final d in logged) (d.dayKey, d.meal, d.quantity, d.unitId)], [(day, 'Dinner', 3, 'serving:0'), (day, 'Dinner', 90, 'g')]);
    expect(meals.puts, isEmpty, reason: 'Log never updates the saved meal');
    expect(find.byType(EatScreen).hitTestable(), findsOneWidget, reason: 'back where logging began');
  });

  testWidgets('Update saved meal and Save as new are explicit and log nothing; cancelling the review records nothing', (tester) async {
    final (overrides, fakes, meals) = await _fixture(tester);
    await pumpApp(tester, overrides, home: const MealsLibraryScreen(dayKey: day, meal: 'Breakfast'), size: const Size(390, 1400));
    await _tap(tester, find.byKey(const Key('meals-row-m1')));
    await _tap(tester, find.byKey(const Key('meal-factor-0.5')));
    await _tap(tester, find.byKey(const Key('meal-update-saved')));
    expect(find.textContaining('become Breakfast’s saved amounts'), findsOneWidget);
    await _tap(tester, find.text('Update saved meal').last);
    expect([for (final c in meals.puts.single.body.components) c.quantity], [1, 30]);
    expect(meals.puts.single.id, 'm1');
    await tester.pump(const Duration(seconds: 3)); // the confirmation toast covers the bottom actions while it shows
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const Key('meal-review-save-new')));
    await tester.enterText(find.byKey(const Key('meal-new-name')), 'Light breakfast');
    await _tap(tester, find.byKey(const Key('meal-new-save')));
    expect((meals.puts.last.id, meals.puts.last.body.name), (null, 'Light breakfast'));
    expect(fakes.journal.meals, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fakes.journal.meals, isEmpty, reason: 'leaving the review logs nothing');
    expect(fakes.journal.saved, isEmpty);
  });

  testWidgets('a recipe portion in servings or grams of the weighed batch; unknown calories stay "known", never a total', (tester) async {
    final (overrides, fakes, _) = await _fixture(tester);
    await pumpApp(tester, overrides, home: const MealsLibraryScreen(dayKey: day, meal: 'Dinner'), size: const Size(390, 1600));
    await _tap(tester, find.byKey(const Key('meals-tab-recipe')));
    expect(find.textContaining('makes 4 servings'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('meals-row-r1')));
    await tester.enterText(find.byKey(const Key('recipe-amount')), '1,5'); // a French decimal comma reads the same
    await tester.pumpAndSettle();
    expect(find.text('142 kcal known'), findsOneWidget, reason: '379 known kcal × 1.5 / 4, still marked known');
    await _tap(tester, find.byKey(const Key('recipe-measure-gram')));
    expect(tester.widget<TextField>(find.byKey(const Key('recipe-amount'))).controller!.text, '450', reason: '1.5 of 4 servings of a 1,200 g batch');
    await _tap(tester, find.byKey(const Key('meal-log')));
    final d = fakes.journal.saved.single;
    expect((d.calories, d.recipe!['partial']['calories'], d.amount), (null, 142.13, '450 g'));
    expect(d.recipe!['portion'], {'quantity': 450.0, 'unit': 'g'});
  });

  testWidgets('one food of a meal changed for this log only: the other keeps its saved amount, the saved meal stays', (tester) async {
    final (overrides, fakes, meals) = await _fixture(tester);
    await pumpApp(tester, overrides, home: const MealsLibraryScreen(dayKey: day, meal: 'Breakfast'), size: const Size(390, 1400));
    expect(find.text('Create meal'), findsOneWidget);
    expect(find.text('Save foods you eat together. Change each amount when you log it.\nExample: Breakfast → 2 eggs + 60 g of baguette.'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('meals-row-m1')));
    await _tap(tester, find.byKey(const Key('meal-part-1')));
    expect(find.text('Amount for this log'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('food-quantity')), '90');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('food-save')));
    expect(fakes.journal.saved, isEmpty, reason: 'changing an amount logs nothing');
    expect(find.text('2 eggs (100 g)'), findsOneWidget, reason: 'the eggs keep their saved amount');
    expect(find.text('90 g · Saved amount: 60 g'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('meal-review-totals')), matching: find.text('484 kcal')), findsOneWidget, reason: '143 + 379 × 0.9');
    await _tap(tester, find.byKey(const Key('meal-log')));
    expect([for (final d in fakes.journal.meals.single) (d.quantity, d.unitId)], [(2, 'serving:0'), (90, 'g')]);
    expect(meals.puts, isEmpty, reason: 'Log this time never updates the saved meal');
  });

  testWidgets('two gram portions of one weighed recipe, each its share of the batch; without a weight, grams are explained, not guessed', (tester) async {
    final portions = <FoodDraft>[];
    for (final grams in ['170', '242']) {
      final (overrides, fakes, meals) = await _fixture(tester);
      await pumpApp(tester, overrides, home: MealReviewScreen(body: chili(weight: 1200), saved: SavedMeal(_saved('r1', chili(weight: 1200))), dayKey: day, meal: 'Dinner'), size: const Size(390, 1600));
      await _tap(tester, find.byKey(const Key('recipe-measure-gram')));
      await tester.enterText(find.byKey(const Key('recipe-amount')), grams);
      await tester.pumpAndSettle();
      expect(find.text('Amount for this log'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('meal-log')));
      portions.add(fakes.journal.saved.single);
      expect(meals.puts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    }
    // 379 known kcal and 13.2 g known protein in a 1,200 g batch; the spice's are unknown, so both stay partial.
    expect([for (final d in portions) (d.calories, d.recipe!['partial']['calories'], d.recipe!['partial']['protein'], d.fat, d.amount)],
        [(null, 53.69, 1.87, 0, '170 g'), (null, 76.43, 2.66, 0, '242 g')]);
    expect([for (final d in portions) d.recipe!['recipe']['preparedWeightG']], [1200, 1200], reason: 'each log keeps the batch it came from');

    final (overrides, _, _) = await _fixture(tester);
    await pumpApp(tester, overrides, home: MealReviewScreen(body: chili(), saved: SavedMeal(_saved('r1', chili(weight: 1200))), dayKey: day, meal: 'Dinner'), size: const Size(390, 1600));
    expect(find.byKey(const Key('recipe-measure-gram')), findsNothing, reason: 'no weighed batch: no grams');
    expect(find.textContaining('weigh the whole batch once it’s cooked'), findsOneWidget);
  });

  testWidgets('the editor saves only a valid definition and never logs', (tester) async {
    final (overrides, fakes, meals) = await _fixture(tester);
    await pumpApp(tester, overrides, home: const MealEditorScreen(dayKey: day, kind: MealBody.recipe), size: const Size(390, 1400));
    await tester.enterText(find.byKey(const Key('meal-name')), 'Soup');
    await tester.enterText(find.byKey(const Key('recipe-servings')), '0');
    await _tap(tester, find.byKey(const Key('meal-save')));
    expect(find.text('Add at least one food.'), findsOneWidget);
    expect(meals.puts, isEmpty);
    expect(fakes.journal.saved, isEmpty);
    expect(fakes.journal.meals, isEmpty);
  });

  testWidgets('Arabic runs right to left and French fits at 320 px with large text, keyboard space included', (tester) async {
    for (final lang in ['ar', 'fr-CA']) {
      final (overrides, _, _) = await _fixture(tester);
      final c = await pumpApp(tester, overrides, home: MealReviewScreen(body: breakfast(), saved: SavedMeal(_saved('m1', breakfast())), dayKey: day, meal: 'Breakfast'),
          size: const Size(320, 900), textScale: 1.6, settle: false);
      c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300); // the keyboard
      final semantics = tester.ensureSemantics();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: lang);
      final l = c.read(appL10nProvider);
      expect(find.text(l.mealsLogThisTime), findsOneWidget, reason: '$lang: the main action stays on screen above the keyboard');
      expect(tester.getRect(find.byKey(const Key('meal-log'))).bottom, lessThanOrEqualTo(900 - 300));
      expect(Directionality.of(tester.element(find.byKey(const Key('meal-log')))), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      final remove = find.byKey(const Key('meal-part-remove-0'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(remove).tooltip, l.mealsRemoveFood('Egg'), reason: 'read out by name, in the app language');
      semantics.dispose();
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Create food, Create meal and Create recipe fit at 320 px with 2× text, and run right to left in Arabic', (tester) async {
    for (final lang in ['ar', 'fr-CA']) {
      for (final (home, then) in <(Widget, String?)>[
        (FoodFormScreen(draft: FoodDraft(dayKey: day, meal: 'Lunch')), 'food-basis-100g'),
        (const MealsLibraryScreen(dayKey: day, meal: 'Breakfast'), 'meals-tab-recipe'),
        (MealReviewScreen(body: chili(), saved: SavedMeal(_saved('r1', chili(weight: 1200))), dayKey: day, meal: 'Dinner'), null),
      ]) {
        final (overrides, _, _) = await _fixture(tester);
        final c = await pumpApp(tester, overrides, home: home, size: const Size(320, 2400), textScale: 2, settle: false);
        c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
        await tester.pumpAndSettle();
        if (then != null) await _tap(tester, find.byKey(Key(then)));
        expect(tester.takeException(), isNull, reason: '$lang ${home.runtimeType}');
        expect(Directionality.of(tester.element(find.byType(Scaffold).first)), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        final l = c.read(appL10nProvider);
        if (home is FoodFormScreen) expect(find.text(l.foodAmountForLog), findsOneWidget, reason: lang);
        if (home is MealsLibraryScreen) expect(find.text('${l.mealsCreateRecipeAbout}\n${l.mealsCreateRecipeExample}'), findsOneWidget, reason: lang);
        if (home is MealReviewScreen) expect(find.text(l.mealsNoWeight), findsOneWidget, reason: lang);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  group('renders', () {
    if (!_render) {
      test('saved meals renders are skipped without GOHARD_RENDER', () {});
      return;
    }
    Future<void> shot(WidgetTester tester, Widget home, String name, {Size size = const Size(390, 1100), ThemeMode mode = ThemeMode.light, double text = 1, Future<void> Function()? then}) async {
      final store = AppearanceStore(MemorySecretStore())
        ..accent = Accent.blue
        ..mode = mode;
      final (overrides, _, _) = await _fixture(tester, appearance: store);
      await pumpApp(tester, overrides, home: home, size: size, textScale: text, insets: phoneInsets, settle: false);
      await tester.pumpAndSettle();
      await then?.call();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
      await tester.runAsync(() async {
        final file = File('$_out/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }

    final review = MealReviewScreen(body: breakfast(), saved: SavedMeal(_saved('m1', breakfast())), dayKey: day, meal: 'Breakfast');
    testWidgets('library, editors and review', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await shot(tester, const MealsLibraryScreen(dayKey: day, meal: 'Breakfast'), 'library-${mode.name}', mode: mode);
        await shot(tester, MealEditorScreen(dayKey: day, saved: SavedMeal(_saved('m1', breakfast()))), 'meal-editor-${mode.name}', mode: mode);
        await shot(tester, MealEditorScreen(dayKey: day, saved: SavedMeal(_saved('r1', chili(weight: 1200)))), 'recipe-editor-${mode.name}', size: const Size(390, 1500), mode: mode);
        await shot(tester, review, 'meal-review-${mode.name}', mode: mode, then: () async {
          await tester.tap(find.byKey(const Key('meal-factor-1.5')));
          await tester.pumpAndSettle();
        });
        await shot(tester, MealReviewScreen(body: chili(weight: 1200), saved: SavedMeal(_saved('r1', chili(weight: 1200))), dayKey: day, meal: 'Dinner'), 'recipe-review-${mode.name}', size: const Size(390, 1500), mode: mode);
      }
      await shot(tester, review, 'meal-review-320-large', size: const Size(320, 1800), text: 2);
      await shot(tester, MealEditorScreen(dayKey: day, saved: SavedMeal(_saved('r1', chili(weight: 1200)))), 'recipe-editor-320-large', size: const Size(320, 2400), text: 2);
      await shot(tester, const MealsLibraryScreen(dayKey: day, meal: 'Breakfast'), 'library-recipes', then: () async {
        await tester.tap(find.byKey(const Key('meals-tab-recipe')));
        await tester.pumpAndSettle();
      });
      await shot(tester, FoodFormScreen(draft: FoodDraft(dayKey: day, meal: 'Lunch')), 'create-food-320-large', size: const Size(320, 2000), text: 2, then: () async {
        await _tap(tester, find.byKey(const Key('food-basis-100g')));
        await tester.enterText(find.byKey(const Key('food-name')), 'Baguette');
        await tester.enterText(find.byKey(const Key('food-calories')), '260');
        await tester.enterText(find.byKey(const Key('food-protein')), '9');
        await tester.enterText(find.byKey(const Key('food-log-quantity')), '60');
        await tester.pumpAndSettle();
      });
      await shot(tester, const HomeShell(), 'eat-entry', size: const Size(390, 1500), then: () async {
        await tester.tap(find.byKey(const Key('nav-eat')));
        await tester.pumpAndSettle();
      });
    });
    // Large text with an open keyboard: the editor's fields and its Save stay reachable.
    testWidgets('editor at 320 px, large text, keyboard open', (tester) async {
      await shot(tester, MealEditorScreen(dayKey: day, start: breakfast()), 'meal-editor-320-keyboard', size: const Size(320, 700), text: 1.6, then: () async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.tap(find.byKey(const Key('meal-name')));
        await tester.pumpAndSettle();
      });
      tester.view.resetViewInsets();
    });
  });
}
