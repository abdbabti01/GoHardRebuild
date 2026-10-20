import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';

import 'ui_support.dart';

/// Eat › History & trends on screen (docs/FOOD_DATA.md). Fixture data only: the handoff's illustrative week.

const _today = '2026-10-20';

final _food = [
  foodEntry('m', '2026-10-12', 'Lunch', 'Rice bowl', '1 bowl', calories: 2100, protein: 120),
  foodEntry('t', '2026-10-13', 'Lunch', 'Pasta', '1 plate', calories: 1950, protein: 90),
  foodEntry('h1', '2026-10-15', 'Dinner', 'Pasta', '1 plate', calories: 2230, protein: 140),
  foodEntry('h2', '2026-10-15', 'Dinner', 'Homemade sauce', '1 cup'),
  foodEntry('f', '2026-10-16', 'Lunch', 'Chicken and rice', '1 plate', calories: 2050),
  foodEntry('s', '2026-10-17', 'Lunch', 'Curry', '1 plate', calories: 2380),
  foodEntry('z', '2026-10-19', 'Snack', 'Black coffee', '1 cup', calories: 0),
];

Json _w(String id, String day, double ml) => {'id': id, 'dayKey': day, 'volumeMl': ml, 'isDeleted': false};

Future<List<Override>> _fixture(WidgetTester tester, {List<Json> water = const [], bool waterFails = false}) async => [
      ...(await tester.runAsync(() => overridesFor(day: _today, food: _food)))!,
      waterEntriesProvider.overrideWith((ref) => waterFails ? Stream.error(StateError('disk')) : Stream.value([for (final w in water) stored(WaterEntry(w), Kinds.water, w['id'] as String, w)])),
      waterProvider.overrideWith((ref, d) => Stream.value([for (final w in water) if (w['dayKey'] == d) stored(WaterEntry(w), Kinds.water, w['id'] as String, w)])),
    ];

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> _openTrends(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('eat-history')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  // The page is a lazy list: a control scrolled far off is rebuilt on the way back to it.
  if (find.byKey(Key(key)).evaluate().isEmpty) await tester.scrollUntilVisible(find.byKey(Key(key)), -200, scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('week totals, a day chosen on the chart opens its journal, and coming back keeps the week, metric and day; month to date', (tester) async {
    await pumpApp(tester, await _fixture(tester), size: const Size(390, 1600));
    await _openTrends(tester);
    expect(_text(tester, 'trends-period-label'), 'Oct 19 – 25, 2026', reason: 'today\'s week first');
    expect(_text(tester, 'trends-so-far'), 'This week so far · Oct 19 – 20');
    expect(_text(tester, 'trends-coverage'), '1 of 2 days with calorie values so far', reason: 'Monday\'s recorded zero counts; future days do not');
    expect(_text(tester, 'trends-total'), '0 kcal');
    expect(tester.widget<IconButton>(find.byKey(const Key('trends-next'))).onPressed, isNull, reason: 'no wholly future week');

    await _tap(tester, 'trends-previous');
    expect(_text(tester, 'trends-period-label'), 'Oct 12 – 18, 2026');
    expect(find.byKey(const Key('trends-so-far')), findsNothing);
    expect((_text(tester, 'trends-total'), _text(tester, 'trends-coverage'), _text(tester, 'trends-average'), _text(tester, 'trends-average-days')),
        ('10,710 kcal', '5 of 7 days with calorie values', '2,142 kcal', 'Across the 5 days with calorie values'));
    expect(find.byKey(const Key('trends-partial-note')), findsOneWidget, reason: 'the average includes Thursday\'s partial sum, and says so');
    expect(find.text('Known Calories logged'.toUpperCase()), findsOneWidget);
    expect(_text(tester, 'trends-selected-value'), 'No food logged', reason: 'the week\'s last day, Sunday, is chosen: not logged, not zero');

    // The chart's middle position is Thursday.
    final chart = tester.getRect(find.byKey(const Key('trends-chart')));
    await tester.tapAt(Offset(chart.center.dx + 18, chart.center.dy));
    await tester.pumpAndSettle();
    expect(_text(tester, 'trends-selected-date'), 'Thursday, October 15');
    expect(_text(tester, 'trends-selected-value'), '2,230 kcal known · 1 of 2 foods without calorie values');
    final row = find.byKey(const Key('trends-day-2026-10-14'));
    expect(find.descendant(of: row, matching: find.text('No food logged')), findsOneWidget, reason: 'every day of the period is listed');

    await _tap(tester, 'trends-metric-protein');
    expect((_text(tester, 'trends-total'), _text(tester, 'trends-coverage')), ('350 g', '3 of 7 days with protein values'), reason: 'protein\'s own days, not calorie days');
    expect(_text(tester, 'trends-logged'), '5 days with food logged · 2 without any protein value');

    await _tap(tester, 'trends-view-day');
    expect(find.text('Thursday, October 15'), findsOneWidget, reason: 'Eat shows that day, dated');
    expect(find.byKey(const Key('eat-back-to-today')), findsOneWidget);
    expect(find.text('Homemade sauce'), findsOneWidget, reason: 'the real journal of that day');

    await tester.tap(find.byKey(const Key('eat-history')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'trends-period-label'), 'Oct 12 – 18, 2026', reason: 'back to the same week');
    expect(_text(tester, 'trends-selected-date'), 'Thursday, October 15');
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('trends-metric-protein'))).selected, isTrue);

    await _tap(tester, 'trends-kind-month');
    expect((_text(tester, 'trends-period-label'), _text(tester, 'trends-so-far')), ('October 2026', 'Month to date · Oct 1 – 20'));
    await _tap(tester, 'trends-metric-calories');
    expect((_text(tester, 'trends-total'), _text(tester, 'trends-coverage')), ('10,710 kcal', '6 of 20 days with calorie values so far'));
    expect(_text(tester, 'trends-average'), '1,785 kcal', reason: 'the zero day counts in the denominator');
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional metrics follow the account\'s settings; water that cannot be read leaves food intact', (tester) async {
    final container = await pumpApp(tester, await _fixture(tester, waterFails: true), size: const Size(390, 1600));
    await _openTrends(tester);
    for (final m in ['calories', 'protein', 'carbs', 'fat']) {
      expect(find.byKey(Key('trends-metric-$m')), findsOneWidget);
    }
    expect(find.byKey(const Key('trends-metric-water')), findsNothing, reason: 'water is off until turned on');
    final before = container.read(trackingPrefsProvider);

    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trends-metric-water')), findsOneWidget);
    expect(_text(tester, 'trends-total'), '0 kcal', reason: 'food is still shown');
    expect(find.text('Water could not be read from this phone; food is shown.'), findsOneWidget);
    await _tap(tester, 'trends-metric-water');
    expect(find.text('Your water could not be read from this phone.'), findsOneWidget);
    expect(find.text('0 mL'), findsNothing, reason: 'unreadable water is not zero water');

    await _tap(tester, 'trends-metric-carbs');
    container.read(trackingPrefsProvider.notifier).setDisplay('one', const NutritionDisplay(water: true, carbs: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trends-metric-carbs')), findsNothing);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('trends-metric-calories'))).selected, isTrue, reason: 'a hidden metric gives way to calories');
    expect(_text(tester, 'trends-period-label'), 'Oct 19 – 25, 2026', reason: 'the period stays');
    expect(before.unit, container.read(trackingPrefsProvider).unit, reason: 'viewing changes no preference');
  });

  testWidgets('water by day in the chosen unit; the calendar still opens any day', (tester) async {
    final container = await pumpApp(tester, await _fixture(tester, water: [_w('a', '2026-10-14', 500), _w('b', '2026-10-14', 250)]), size: const Size(390, 1600));
    container.read(trackingPrefsProvider.notifier)
      ..setDisplay('one', const NutritionDisplay(water: true))
      ..setUnit(VolumeUnit.flOz);
    await _openTrends(tester);
    await _tap(tester, 'trends-previous');
    await _tap(tester, 'trends-metric-water');
    expect((_text(tester, 'trends-total'), _text(tester, 'trends-coverage')), ('25.4 fl oz', '1 of 7 days with water logged'));
    expect(find.descendant(of: find.byKey(const Key('trends-day-2026-10-12')), matching: find.textContaining('No water logged')), findsOneWidget, reason: 'a food-only day');

    await _tap(tester, 'trends-calendar');
    expect(find.byKey(const Key('history-calendar')), findsOneWidget);
    await _tap(tester, 'history-day-2026-10-14');
    expect(find.text('Wednesday, October 14'), findsOneWidget, reason: 'a water-only day opens from the list');
  });

  testWidgets('fits 320 px at twice the text size', (tester) async {
    await pumpApp(tester, await _fixture(tester), size: const Size(320, 2400), textScale: 2);
    await _openTrends(tester);
    await _tap(tester, 'trends-previous');
    await _tap(tester, 'trends-kind-month');
    expect(find.byKey(const Key('trends-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
