import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/plans/week_widgets.dart';
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
    await tester.scrollUntilVisible(find.text('No food logged yet'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Recorded today'), findsNothing, reason: 'no activity, so no activity section');
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
    await tester.scrollUntilVisible(find.text('Start a run'), -200, scrollable: scroll);
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

  group('compact Today', () {
    const day = '2026-10-11'; // week 3 of the fixture block, with "Upper body A" due
    Json manualDone() => {
          'id': 'm1', 'kind': 'manual', 'title': 'Quick pull-ups', 'dayKey': day, 'startedAtUtc': '${day}T09:00:00Z', 'finishedAtUtc': '${day}T09:10:00Z',
          'outcome': 'manual_recorded', 'performedSets': 1, 'performedExercises': 1, 'qualifiedOccasion': false, 'isDeleted': false, 'exercises': const [],
        };
    final food = [foodEntry('f1', day, 'Lunch', 'Rice', '1 bowl', calories: 400, protein: 25), foodEntry('f2', day, 'Snack', 'Toast', '2 slices', calories: 110)];

    testWidgets('the workout action and the food values share the first screen; a manual workout completes nothing', (tester) async {
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [plan], primaryPlanId: 'p1', workouts: [manualDone()], food: food, calorieGoal: 2200)) ?? []);
      final navTop = tester.getTopLeft(find.byKey(const Key('nav-today'))).dy;

      expect(find.byKey(const Key('today-start')).hitTestable(), findsOneWidget, reason: 'the planned workout is still due after an unrelated manual one');
      expect(find.text('Done for today'), findsNothing);
      expect(find.textContaining('50 min planned'), findsOneWidget, reason: 'the plan\'s chosen session length, not an estimate');
      expect(find.textContaining('about'), findsNothing);
      expect(find.text('Bench press · Overhead press · Barbell row +2 more'), findsOneWidget);
      for (final gone in ['Workout preview', 'View workout', 'Your week', 'Body measurements']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }

      // Calories are a partial-free sum here; protein is missing for one food and says so.
      expect(find.text('510'), findsOneWidget);
      expect(tester.getBottomLeft(find.text('510')).dy, lessThan(navTop), reason: 'nutrition values are on the first screen');
      expect(find.text('of 2,200 · 1,690 left'), findsOneWidget);
      expect(find.text('Protein · known'), findsOneWidget);
      expect(find.byKey(const Key('today-goal-protein')), findsNothing, reason: 'no protein goal was set, so no rail');
      expect(find.text('Some nutrition values are missing'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Manual workout · Recorded · 1 set'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('today-details')), findsOneWidget, reason: 'the title opens the workout details');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an in-progress workout shows its recorded sets', (tester) async {
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      final open = openWorkout(plan, 'o3-3', day: day, recordedSets: 6);
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout], sets: open.sets)) ?? []);
      expect(find.text('6 of 18 sets recorded'), findsOneWidget);
      expect(find.byKey(const Key('today-resume')).hitTestable(), findsOneWidget);
    });

    testWidgets('the week calendar and its progress are in Train › Plan', (tester) async {
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [plan], primaryPlanId: 'p1')) ?? [], size: const Size(390, 1900));
      expect(find.byType(WeekDayStrip), findsNothing);
      await tester.tap(find.byKey(const Key('nav-train')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('train-plan')));
      await tester.pumpAndSettle();
      expect(find.byType(WeekDayStrip), findsOneWidget);
      expect(find.text('2 of 3 completed'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
    });

    testWidgets('an unreachable account is one line until it is opened', (tester) async {
      final container = await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day)) ?? []);
      expect(find.byKey(const Key('today-connection')), findsNothing, reason: 'nothing is claimed before an attempt has failed');
      container.read(connectionProvider.notifier).report(false);
      await tester.pumpAndSettle();
      expect(find.text('Can\'t reach your account'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      await tester.tap(find.byKey(const Key('today-connection')));
      await tester.pumpAndSettle();
      expect(find.textContaining('saved on this phone'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('unknown stays a dash and a goal never gets a remainder from a partial sum', (tester) async {
      Future<void> summary(List<FoodEntry> entries) => pumpApp(tester, const [],
          home: Scaffold(body: NutritionSummary(entries: entries, coverage: NutrientCoverage.calculate(entries), calorieGoal: 2200, proteinGoal: 140, onLogFood: () {}, onDetails: () {})));
      await summary([FoodEntry(foodEntry('a', day, 'Lunch', 'Rice', '1 bowl', calories: 400)), FoodEntry(foodEntry('b', day, 'Lunch', 'Toast', '2 slices'))]);
      expect(find.text('Calories · known'), findsOneWidget);
      expect(find.text('of 2,200 · known so far'), findsOneWidget);
      expect(find.textContaining('left'), findsNothing);
      expect(find.text('—'), findsOneWidget, reason: 'protein is unknown, not zero');
      expect(find.text('Goal 140 g'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.descendant(of: find.byKey(const Key('today-goal-protein')), matching: find.byType(LinearProgressIndicator))).value, 0);

      await summary([FoodEntry(foodEntry('c', day, 'Lunch', 'Mystery', '1'))]);
      expect(find.text('No nutrition values entered yet'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  testWidgets('unfinished_history_is_not_completed', (tester) async {
    await pumpApp(tester, await tester.runAsync(() => overridesFor(day: _day, workouts: [_openWorkout()])) ?? [], home: const WorkoutHistoryScreen());
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.textContaining('Finished'), findsNothing);
  });
}
