import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show addDays;
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/format.dart' show longDate;
import 'package:gohard_rebuild/core/language.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/food_form.dart' show FoodFormScreen;
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/meal_copy_screen.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

/// Same as yesterday? and Copy meal on Eat, as the person meets them: the day before the day shown, the review with
/// its destination, nothing logged by looking or going back, one log per review, and a way to the day it went to.

const day = '2026-11-18';
final yesterday = addDays(day, -1), twoBack = addDays(day, -2);

final egg = FoodItem({'source': 'usda', 'sourceId': 'egg', 'name': 'Egg', 'basis': FoodItem.per100g,
    'nutrients': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5}, 'servings': [{'label': '1 egg', 'grams': 50, 'milliliters': null}]});

final journal = [
  {...foodEntry('y-egg', yesterday, 'Breakfast', 'Egg', '2 eggs (100 g)', calories: 143, protein: 12.6, carbs: 0.7, fat: 9.5), 'source': {'item': egg.j, 'quantity': 2, 'unit': 'serving:0'}},
  foodEntry('y-bread', yesterday, 'Breakfast', 'Baguette', '1 slice', calories: 80),
  {...foodEntry('y-gone', yesterday, 'Breakfast', 'Deleted toast', '1', calories: 70), 'isDeleted': true},
  foodEntry('t-rice', twoBack, 'Lunch', 'Rice bowl', '1 bowl', calories: 400),
  foodEntry('d-tea', day, 'Snack', 'Tea', '1 cup', calories: 2),
];

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Eat's list builds lazily: back to its top, where the day arrows are.
Future<void> _top(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
  await tester.pumpAndSettle();
}

Future<FoodFakes> _eat(WidgetTester tester, {Size size = const Size(390, 1600), double text = 1, String? lang}) async {
  final fakes = FoodFakes();
  final c = await pumpApp(tester, [...(await tester.runAsync(() => overridesFor(day: day, food: journal)))!, ...fakes.overrides], size: size, textScale: text,
      settle: lang == null, home: lang == null ? const HomeShell() : const Scaffold(body: EatScreen()));
  if (lang != null) {
    c.read(devicePrefsProvider.notifier).setLanguage(AppLanguage.parse(lang));
    await tester.pumpAndSettle();
    return fakes;
  }
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
  return fakes;
}

void main() {
  testWidgets('an empty meal offers the same meal of the day before the day shown; the review logs only on Log this time, once, then View', (tester) async {
    final fakes = await _eat(tester);
    final repeat = find.byKey(const Key('eat-repeat-breakfast'));
    expect(repeat, findsOneWidget);
    expect(find.descendant(of: repeat, matching: find.text('Same as yesterday?')), findsOneWidget);
    expect(find.descendant(of: repeat, matching: find.text('Egg · Baguette')), findsOneWidget, reason: 'its foods in logged order, never a deleted one');
    for (final m in ['lunch', 'dinner', 'snack']) {
      expect(find.byKey(Key('eat-repeat-$m')), findsNothing, reason: '$m: nothing the day before, or already logged');
    }
    expect(find.byKey(const Key('eat-copy-meal-snack')), findsOneWidget, reason: 'a meal with food can be copied');

    // An earlier day shown: "yesterday" is the day before it, said with its date.
    await _tap(tester, find.byTooltip('Previous day'));
    expect(find.byKey(const Key('eat-repeat-breakfast')), findsNothing, reason: 'that breakfast has food');
    expect(find.descendant(of: find.byKey(const Key('eat-repeat-lunch')), matching: find.text('Same as ${longDate(twoBack)}?')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('eat-back-to-today')));

    await _tap(tester, find.byKey(const Key('eat-repeat-review-breakfast')));
    expect(find.byType(MealCopyScreen), findsOneWidget);
    expect(find.text('Review copied meal'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('copy-meal')), matching: find.text('Breakfast')), findsOneWidget, reason: 'the destination is always shown');
    expect(find.textContaining(longDate(day)), findsWidgets);
    expect(find.byKey(const Key('copy-same')), findsNothing);
    expect(find.text('1 slice · typed by hand'), findsOneWidget, reason: 'a typed food says it cannot be scaled');

    // Change one amount, then go back: nothing is logged.
    await _tap(tester, find.byKey(const Key('copy-item-0')));
    expect(find.byType(FoodFormScreen), findsOneWidget);
    await tester.enterText(find.byKey(const Key('food-quantity')), '3');
    await _tap(tester, find.byKey(const Key('food-save')));
    expect(find.text('3 eggs (150 g)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect([...fakes.journal.meals, ...fakes.journal.saved], isEmpty, reason: 'looking and going back log nothing');

    // A typed food is never swapped silently: keeping it changes nothing.
    await _tap(tester, find.byKey(const Key('eat-repeat-review-breakfast')));
    await _tap(tester, find.byKey(const Key('copy-item-1')));
    expect(find.text('This amount can’t be changed'), findsOneWidget);
    await _tap(tester, find.text('Keep as logged'));
    expect(find.text('Baguette'), findsOneWidget);

    final log = find.byKey(const Key('copy-log'));
    await tester.ensureVisible(log);
    await tester.tap(log);
    await tester.tap(log, warnIfMissed: false); // a rapid second tap
    await tester.pumpAndSettle();
    expect(fakes.journal.meals, hasLength(1), reason: 'one review is one log');
    final logged = fakes.journal.meals.single;
    expect([for (final d in logged) (d.dayKey, d.meal, d.name, d.amount, d.calories)], [(day, 'Breakfast', 'Egg', '2 eggs (100 g)', 143), (day, 'Breakfast', 'Baguette', '1 slice', 80)]);
    expect([for (final d in logged) d.id], [null, null], reason: 'new entries');
    expect(find.byType(EatScreen).hitTestable(), findsOneWidget);
    expect(find.text('Copied to Breakfast · ${longDate(day)}'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('Copy meal reviews first; it says when it adds to a meal with food and warns on the same meal and day; Other days lists each day', (tester) async {
    final fakes = await _eat(tester);
    await _tap(tester, find.byKey(const Key('eat-copy-meal-snack')));
    expect(find.byType(MealCopyScreen), findsOneWidget);
    expect(find.text('From Snack · ${longDate(day)}'), findsOneWidget);
    // To today's snack, the very meal it came from: allowed, with a warning.
    await _tap(tester, find.byKey(const Key('copy-meal')));
    await _tap(tester, find.text('Snack').hitTestable().last);
    expect(find.byKey(const Key('copy-same')), findsOneWidget);
    expect(find.byKey(const Key('copy-adds')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _top(tester);

    // Yesterday's breakfast into today's snack: added beside the tea, nothing replaced.
    await _tap(tester, find.byTooltip('Previous day'));
    await _tap(tester, find.byKey(const Key('eat-copy-meal-breakfast')));
    expect(find.descendant(of: find.byKey(const Key('copy-meal')), matching: find.text('Breakfast')), findsOneWidget, reason: 'an earlier day → today, the same meal');
    await _tap(tester, find.byKey(const Key('copy-meal')));
    await _tap(tester, find.text('Snack').hitTestable().last);
    expect(find.textContaining('already has 1 food. These are added; nothing is replaced.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fakes.journal.meals, isEmpty);

    // Other days: each earlier day's meal on its own; saved meals and Add food beside them.
    await _top(tester);
    await _tap(tester, find.byKey(const Key('eat-back-to-today')));
    await _tap(tester, find.byKey(const Key('eat-repeat-other-breakfast')));
    expect(find.byKey(const Key('copy-sources')), findsOneWidget);
    expect(find.byKey(Key('copy-source-$yesterday')), findsOneWidget);
    expect(find.byKey(const Key('copy-sources-saved')), findsOneWidget);
    expect(find.byKey(const Key('copy-sources-add')), findsOneWidget);
    await _tap(tester, find.byKey(Key('copy-source-$yesterday')));
    expect(find.byType(MealCopyScreen), findsOneWidget);
    expect(fakes.journal.meals, isEmpty);
  });

  testWidgets('320 px with twice the text, in Arabic and French: Eat’s shortcut and the review fit and keep their actions', (tester) async {
    for (final lang in ['ar', 'fr-CA']) {
      await tester.pumpWidget(const SizedBox()); // a fresh app: no route left from the language before
      await _eat(tester, size: const Size(320, 9000), text: 2, lang: lang); // tall, so the whole lazy list is built
      expect(tester.takeException(), isNull, reason: lang);
      final review = find.byKey(const Key('eat-repeat-review-breakfast'));
      expect(review.hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('eat-copy-meal-snack')).hitTestable(), findsOneWidget);
      await _tap(tester, review);
      expect(tester.takeException(), isNull, reason: '$lang review');
      expect(find.byKey(const Key('copy-log')).hitTestable(), findsOneWidget);
      if (lang == 'ar') expect(Directionality.of(tester.element(find.byType(MealCopyScreen))), TextDirection.rtl);
    }
  });
}
