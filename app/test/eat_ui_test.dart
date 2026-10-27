import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_form.dart';
import 'package:gohard_rebuild/features/nutrition/log_food_screen.dart';
import 'package:gohard_rebuild/features/weather/weather.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

const day = '2026-10-11';

final journal = [
  foodEntry('f1', day, 'Breakfast', 'Eggs, scrambled', '2 eggs', calories: 180, protein: 12, carbs: 2, fat: 14),
  foodEntry('f2', day, 'Breakfast', 'Toast, wholemeal', '2 slices', calories: 190, protein: 8, carbs: 34, fat: 2),
  foodEntry('f3', day, 'Lunch', 'Chicken and rice', '1 plate', calories: 650, protein: 48, carbs: 70, fat: 16),
  foodEntry('y1', '2026-10-10', 'Dinner', 'Yesterday\'s soup', '1 bowl', calories: 300, protein: 10, carbs: 30, fat: 12),
];

Future<List<Override>> fixture(WidgetTester tester, {List<Json>? food, int? calorieGoal, int? proteinGoal, AppearanceStore? appearance}) async =>
    [...(await tester.runAsync(() => overridesFor(day: day, food: food ?? journal, calorieGoal: calorieGoal, proteinGoal: proteinGoal, appearance: appearance)))!, ...FoodFakes().overrides];

Future<void> openEat(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
}

/// Eat's own list: the four tabs stay built, so "the last scrollable" would be another tab's.
final eatList = find.descendant(of: find.byType(EatScreen), matching: find.byType(Scrollable)).first;

double rail(WidgetTester tester, String key) => tester.widget<LinearProgressIndicator>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(LinearProgressIndicator))).value!;

void main() {
  // The app's real font, so wrapping is what a phone shows.
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await inter.load();
  });

  testWidgets('each entry is its own row with its saved name, portion and values; meals show their own subtotal', (tester) async {
    await pumpApp(tester, await fixture(tester), size: const Size(390, 1500));
    await openEat(tester);
    expect(find.text('Sunday, October 11'), findsOneWidget);
    expect(find.text('Today\'s meals'), findsOneWidget);
    // Two breakfast foods stay two rows; nothing is merged into "Breakfast" or a made-up dish.
    for (final (id, name, kcal, detail) in [
      ('f1', 'Eggs, scrambled', '180 kcal', '2 eggs · P 12 g · C 2 g · F 14 g'),
      ('f2', 'Toast, wholemeal', '190 kcal', '2 slices · P 8 g · C 34 g · F 2 g'),
      ('f3', 'Chicken and rice', '650 kcal', '1 plate · P 48 g · C 70 g · F 16 g'),
    ]) {
      final row = find.byKey(Key('food-row-$id'));
      expect(row, findsOneWidget);
      for (final text in [name, kcal, detail]) {
        expect(find.descendant(of: row, matching: find.text(text)), findsOneWidget, reason: '$id: $text');
      }
    }
    expect(find.text('370 kcal'), findsOneWidget, reason: 'the breakfast subtotal: 180 + 190');
    // Dinner and snack are empty: their heading and the small add action, no repeated explanation.
    expect(find.text('Nothing logged'), findsNothing);
    for (final meal in ['Dinner', 'Snack']) {
      expect(find.text(meal), findsOneWidget);
    }
    expect(find.text('Yesterday\'s soup'), findsNothing, reason: 'another day\'s food is not in today\'s journal');
    expect(find.byKey(const Key('log-food')).hitTestable(), findsOneWidget, reason: 'one general Log food action');
    expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    // The GH mark and the summary panel's decorative bowl (the coach is painted, not an image): no scene (only Today has one)
    // and no food photograph standing in for a meal or an entry.
    expect(find.descendant(of: find.byType(EatScreen), matching: find.byType(Image)), findsNWidgets(2));
    expect(find.byKey(const Key('eat-photo-nutrition')), findsOneWidget);
    expect(find.descendant(of: find.byType(GroupCard), matching: find.byType(Image)), findsNothing, reason: 'the journal has no photographs');
    expect(find.byKey(const Key('eat-coach')), findsOneWidget, reason: 'the guide speaks under the title');
    expect(find.byKey(const Key('coach-help-eat')), findsNothing, reason: 'no second, small avatar beside the speaking one');
    expect(find.byType(SceneBackdrop), findsNothing);
    expect(find.text("Today's meals"), findsOneWidget);
    expect(find.byType(GroupCard), findsNWidgets(4), reason: 'one quiet group per meal');

    // A row opens that entry for editing.
    await tester.tap(find.byKey(const Key('food-row-f2')));
    await tester.pumpAndSettle();
    expect(tester.widget<FoodFormScreen>(find.byType(FoodFormScreen)).existing!.id, 'f2');
  });

  testWidgets('a meal\'s "Add food to" row opens Log food with that meal already chosen', (tester) async {
    await pumpApp(tester, await fixture(tester), size: const Size(390, 1500));
    await openEat(tester);
    for (final meal in ['breakfast', 'lunch', 'dinner', 'snack']) {
      expect(find.byKey(Key('eat-add-$meal')), findsOneWidget);
      expect(find.descendant(of: find.byKey(Key('eat-add-$meal')), matching: find.text('Add food')), findsOneWidget, reason: 'short on screen');
      expect(tester.getSemantics(find.byKey(Key('eat-add-$meal'))).label, 'Add food to $meal', reason: 'the meal is said');
      expect(find.descendant(of: find.byKey(Key('eat-add-$meal')), matching: find.byType(IconTile)), findsNothing, reason: 'no tile like the meal heading');
      expect(tester.getSize(find.byKey(Key('eat-add-$meal'))).shortestSide, greaterThanOrEqualTo(48));
    }
    // On an earlier day, the footer keeps that day: nothing is logged by opening it.
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('eat-add-dinner')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eat-add-dinner')));
    await tester.pumpAndSettle();
    final screen = tester.widget<LogFoodScreen>(find.byType(LogFoodScreen));
    expect((screen.meal, screen.dayKey), ('Dinner', '2026-10-10'));
  });

  testWidgets('unknown values are a dash, a partial meal sum is called known, and no remainder comes from a partial total', (tester) async {
    final food = [
      foodEntry('a', day, 'Lunch', 'Rice', '1 bowl', calories: 400, protein: 25, carbs: 80, fat: 2),
      foodEntry('b', day, 'Lunch', 'Corner shop flapjack', '1 bar'),
      foodEntry('c', day, 'Snack', 'Black coffee', '1 cup', calories: 0),
    ];
    await pumpApp(tester, await fixture(tester, food: food, calorieGoal: 2200, proteinGoal: 140), size: const Size(390, 1500));
    await openEat(tester);
    expect(find.text('Known totals'), findsOneWidget);
    expect(find.text('400 kcal known'), findsOneWidget, reason: 'the lunch subtotal leaves out the food with no calories');
    expect(find.descendant(of: find.byKey(const Key('food-row-b')), matching: find.text('— kcal')), findsOneWidget, reason: 'unknown, not 0');
    expect(find.descendant(of: find.byKey(const Key('food-row-b')), matching: find.text('1 bar · No nutrition entered')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('food-row-c')), matching: find.text('0 kcal')), findsOneWidget, reason: 'an entered zero is a known zero');
    expect(find.text('400 of 2,200 kcal · known so far'), findsOneWidget);
    expect(find.text('Protein 25 of 140 g · known so far'), findsOneWidget);
    expect(find.textContaining(' left'), findsNothing);
    expect(find.textContaining(' over'), findsNothing);
  });

  testWidgets('what is left or over is said only for a complete total with a goal; an over-goal bar stays full', (tester) async {
    // Complete totals and both goals.
    await pumpApp(tester, await fixture(tester, calorieGoal: 2200, proteinGoal: 60), size: const Size(390, 1500));
    await openEat(tester);
    expect(find.text('Totals'), findsOneWidget);
    expect(find.text('1,020 of 2,200 kcal · 1,180 kcal left'), findsOneWidget);
    expect(find.text('Protein 68 of 60 g · 8 g over'), findsOneWidget, reason: 'the words give the real total');
    expect(rail(tester, 'eat-goal-protein'), 1.0, reason: 'the bar stops at full');
    expect(rail(tester, 'eat-goal-calories'), closeTo(1020 / 2200, 0.001));
    expect(find.byType(ProgressRing), findsNothing, reason: 'one bar per goal, as on Today; no second measure for calories');
    expect(find.text('46%'), findsOneWidget);
    expect(find.text('106 g'), findsOneWidget, reason: 'carbs: a known total, no goal invented for it');
    expect(find.text('32 g'), findsOneWidget, reason: 'fat likewise');
    expect(find.byType(ProgressRail).hitTestable(), findsNWidgets(2), reason: 'a bar for each goal that was set (calories, protein), none for carbs or fat');

    // Complete totals, no goal: nothing to be left of.
    await pumpApp(tester, await fixture(tester), size: const Size(390, 1500));
    await openEat(tester);
    expect(find.text('1,020'), findsOneWidget);
    expect(find.byType(ProgressRail).hitTestable(), findsNothing);
    expect(find.byType(ProgressRing), findsNothing);
    expect(find.textContaining(' left'), findsNothing);
  });

  testWidgets('the picked day survives a change of accent and mode; Back to today returns', (tester) async {
    final store = AppearanceStore(MemorySecretStore());
    final container = await pumpApp(tester, await fixture(tester, appearance: store));
    await openEat(tester);
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(find.text('Saturday, October 10'), findsOneWidget);
    expect(find.text('Yesterday\'s soup'), findsOneWidget);
    expect(find.text('Meals'), findsOneWidget, reason: 'not called today\'s');

    container.read(appearanceProvider.notifier)
      ..setAccent(Accent.pink)
      ..setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Eat').first)).extension<GoColors>()!.accent, GoColors.of(Accent.pink, Brightness.dark).accent, reason: 'the look really changed');
    expect(find.text('Saturday, October 10'), findsOneWidget, reason: 'still the day that was picked');
    expect(find.text('Yesterday\'s soup'), findsOneWidget);

    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday, October 11'), findsOneWidget);
    expect(find.byKey(const Key('eat-back-to-today')), findsNothing);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull, reason: 'no journal for a day that has not come');

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(find.text('Friday, October 9'), findsOneWidget);
    await tester.tap(find.byKey(const Key('eat-back-to-today')));
    await tester.pumpAndSettle();
    expect(find.text('Sunday, October 11'), findsOneWidget);
  });

  testWidgets('nothing overflows at twice the text size on a 320 px phone', (tester) async {
    final food = [
      ...journal,
      foodEntry('long', day, 'Dinner', 'Slow-cooked beef and barley stew with root vegetables and dumplings', '1 large bowl (about 450 g)', calories: 12400.5, protein: 1000.5, carbs: 1000.5, fat: 1000.5),
      foodEntry('none', day, 'Snack', 'Corner shop flapjack', '1 bar'),
    ];
    for (final overrides in [await fixture(tester, food: food, calorieGoal: 2200, proteinGoal: 140), await fixture(tester, food: const [], calorieGoal: 2200, proteinGoal: 140), await fixture(tester, food: food)]) {
      await pumpApp(tester, overrides, size: const Size(320, 640), textScale: 2);
      await openEat(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('eat-back-to-today')), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.drag(eatList, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox()); // a fresh Eat, back on today, for the next state
    }
    await pumpApp(tester, await fixture(tester, food: food, calorieGoal: 2200, proteinGoal: 140), size: const Size(320, 5200), textScale: 2);
    await openEat(tester);
    await tester.scrollUntilVisible(find.textContaining('Slow-cooked beef and barley stew'), 400, scrollable: eatList);
    expect(tester.takeException(), isNull, reason: 'most of the page laid out at once');
    expect(find.textContaining('Slow-cooked beef and barley stew'), findsOneWidget, reason: 'the name wraps; it is not cut');
  });

  testWidgets('a meal footer: Add food and Save as meal side by side when they fit; stacked, Add food first, in French and Arabic with large text at 320 px', (tester) async {
    Future<(Rect, Rect)> footer(String lang, Size size, double scale) async {
      final c = await pumpApp(tester, await fixture(tester), size: size, textScale: scale);
      c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
      await openEat(tester);
      final save = find.byKey(const Key('eat-save-meal-breakfast'));
      await tester.scrollUntilVisible(save, 300, scrollable: eatList);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$lang: nothing overflows');
      final rects = (tester.getRect(find.byKey(const Key('eat-add-breakfast'))), tester.getRect(save));
      await tester.pumpWidget(const SizedBox());
      return rects;
    }

    final (add, save) = await footer('en', const Size(390, 1600), 1);
    expect(save.center.dy, closeTo(add.center.dy, 2), reason: 'side by side when both fit');
    for (final lang in ['fr-CA', 'ar']) {
      final (add, save) = await footer(lang, const Size(320, 5200), 2);
      expect(save.top, greaterThanOrEqualTo(add.bottom - 0.5), reason: '$lang: Save as meal under Add food');
      expect(add.width, greaterThan(250), reason: '$lang: Add food keeps the full width');
      expect([add.height, save.height], everyElement(greaterThanOrEqualTo(48)), reason: '$lang: 48 px targets');
      expect(save.left >= 0 && save.right <= 320, isTrue, reason: '$lang: on screen');
    }
  });
}
