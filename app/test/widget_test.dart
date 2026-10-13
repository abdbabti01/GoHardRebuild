import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/workout_detail_screen.dart';

import 'ui_support.dart';

const _day = '2026-10-09';

Json _openWorkout() => {
      'id': 'w1', 'kind': 'manual', 'title': 'Upper Body', 'dayKey': _day, 'startedAtUtc': '2026-10-09T15:00:00Z', 'finishedAtUtc': null, 'isDeleted': false,
      'exercises': [{'id': 'e1', 'ordinal': 1, 'name': 'Bench press', 'catalogKey': 'bench-press', 'isDeleted': false}],
    };

void main() {
  testWidgets('train_selection_survives_tab_switch', (tester) async {
    final container = await pumpApp(tester, await tester.runAsync(() => overridesFor(day: _day)) ?? []);
    for (final label in ['Today', 'Train', 'Eat', 'Me']) {
      expect(find.byKey(Key('nav-${label.toLowerCase()}')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('nav-train')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('train-plan')));
    await tester.pumpAndSettle();
    expect(find.text('Create my plan'), findsWidgets);

    await tester.tap(find.byKey(const Key('nav-eat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-train')));
    await tester.pumpAndSettle();

    expect(container.read(shellProvider).trainView, TrainView.plan);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new account sees only truthful empty states on Today', (tester) async {
    await pumpApp(tester, await tester.runAsync(() => overridesFor(day: _day)) ?? []);
    expect(find.text('Friday, October 9'), findsOneWidget);
    expect(find.text('No plan yet'), findsOneWidget);
    expect(find.text('Your week'), findsNothing, reason: 'no plan, so no invented week');
    await tester.scrollUntilVisible(find.text('No food logged today'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('No run today'), findsOneWidget);
    expect(find.byKey(const Key('today-photo-workout')), findsNothing, reason: 'no workout, so no workout photograph beside "No plan yet"');
    expect(find.text('RECORDED TODAY'), findsNothing, reason: 'no activity, so no activity section');
    expect(find.textContaining('kcal'), findsNothing, reason: 'no invented nutrition');
    expect(find.text('Resume workout'), findsNothing, reason: 'no invented training');
  });

  testWidgets('section_failure_keeps_workout_action', (tester) async {
    await pumpApp(tester, await tester.runAsync(() => overridesFor(day: _day, workouts: [_openWorkout()], foodFails: true)) ?? []);
    expect(find.text('Resume workout'), findsOneWidget);
    expect(find.text('Upper Body'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Log food'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('could not be read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow_scaled_today_has_no_overflow', (tester) async {
    final food = [foodEntry('f1', _day, 'Breakfast', 'Greek yogurt with a long descriptive name', '200 g', calories: 110, fat: 0)];
    await pumpApp(tester, await tester.runAsync(() => overridesFor(day: _day, workouts: [_openWorkout()], food: food)) ?? [], size: const Size(320, 640), textScale: 2);
    expect(find.text('Resume workout'), findsOneWidget);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Log food'), 200, scrollable: scroll);
    expect(find.text('Some nutrition values are missing'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start run'), -200, scrollable: scroll);
    for (final tab in ['train', 'eat', 'me']) {
      await tester.tap(find.byKey(Key('nav-$tab')));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull, reason: 'no overflow at 320 px with 2x text on any destination');
  });

  testWidgets('blank_macros_show_known_totals and unknown is a dash, never zero', (tester) async {
    final entries = [
      FoodEntry(foodEntry('a', _day, 'Lunch', 'Rice', '1 bowl', calories: 400, protein: 25, fat: 0)),
      FoodEntry(foodEntry('b', _day, 'Lunch', 'Toast', '2 slices', calories: 110)),
    ];
    await pumpApp(tester, const [], home: Scaffold(body: SingleChildScrollView(child: NutritionSurface(entries: entries, coverage: NutrientCoverage.calculate(entries)))));
    expect(find.text('Known totals'), findsOneWidget);
    expect(find.text('510'), findsOneWidget);
    expect(find.text('25 g'), findsOneWidget);
    expect(find.text('—'), findsOneWidget, reason: 'carbs are unknown for every food');
    expect(find.text('0 g'), findsOneWidget, reason: 'an entered zero is a known zero');

    final big = [FoodEntry(foodEntry('c', _day, 'Dinner', 'Feast', '1', calories: 12400.5))];
    await pumpApp(tester, const [], home: Scaffold(body: SingleChildScrollView(child: NutritionSurface(entries: big, coverage: NutrientCoverage.calculate(big)))));
    expect(find.text('12,400.5'), findsOneWidget, reason: 'large totals are grouped for reading');
  });

  testWidgets('unfinished_history_is_not_completed', (tester) async {
    await pumpApp(tester, await tester.runAsync(() => overridesFor(day: _day, workouts: [_openWorkout()])) ?? [], home: const WorkoutHistoryScreen());
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.textContaining('Finished'), findsNothing);
  });
}
