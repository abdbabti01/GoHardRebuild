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
    await tester.scrollUntilVisible(find.text('No food logged today'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('No run today'), findsOneWidget);
    expect(find.text('WORKOUT'), findsNothing, reason: 'no workout, so no workout photograph above "No plan yet"');
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
      // The first three movements in the plan's order, each with its prescription; the rest behind one link.
      for (final name in ['Bench press', 'Overhead press', 'Barbell row']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('4 × 6–8'), findsNWidgets(3), reason: 'a prescription, shown because the plan has one');
      expect(find.text('Lat pulldown'), findsNothing);
      expect(find.text('See all 5 exercises'), findsOneWidget);
      expect(find.textContaining('sets recorded'), findsNothing, reason: 'nothing was recorded for a workout that has not started');
      expect(tester.getBottomLeft(find.byKey(const Key('today-start'))).dy, lessThan(navTop), reason: 'the workout action is on the first screen');
      for (final gone in ['Workout preview', 'View workout', 'Your week', 'Body measurements']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }

      // Calories are a partial-free sum here; protein is missing for one food and says so.
      await tester.scrollUntilVisible(find.text('510'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('510'), findsOneWidget);
      expect(find.text('2 foods logged'), findsOneWidget);
      expect(find.text('of 2,200 · 1,690 left'), findsOneWidget);
      expect(find.text('Protein · known'), findsOneWidget);
      expect(find.byKey(const Key('today-goal-protein')), findsNothing, reason: 'no protein goal was set, so no rail');
      expect(find.text('Some nutrition values are missing'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Manual workout · Recorded · 1 set'), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an in-progress workout shows what is planned, what is recorded, and one Resume action', (tester) async {
      final handle = tester.ensureSemantics();
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      final open = openWorkout(plan, 'o3-3', day: day, recordedSets: 6);
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout], sets: open.sets)) ?? []);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('5 exercises · 18 sets'), findsOneWidget);
      // Counts per movement, and nothing that calls a movement finished or current.
      expect(find.text('4 of 4 sets recorded'), findsOneWidget);
      expect(find.text('2 of 4 sets recorded'), findsOneWidget);
      expect(find.text('6 of 18 sets recorded'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing, reason: 'recorded sets are not a completed exercise');
      expect(find.byKey(const Key('today-resume')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Planned sets recorded')), findsOneWidget);
      // The rows are not buttons: only the link, the action and the two companion cards can be tapped.
      expect(find.ancestor(of: find.text('Bench press'), matching: find.byType(InkWell)), findsNothing);
      handle.dispose();
    });

    testWidgets('a manual workout with no targets counts sets without a percentage or a made-up total', (tester) async {
      Json exercise(int i, String name) => {'id': 'e$i', 'ordinal': i, 'name': name, 'catalogKey': null, 'isDeleted': false};
      Json workout(List<Json> exercises) => {'id': 'w1', 'kind': 'manual', 'title': 'Back', 'dayKey': day, 'startedAtUtc': '${day}T15:00:00Z', 'finishedAtUtc': null, 'isDeleted': false, 'exercises': exercises};
      Json set(int i, String exerciseId) => {'id': 's$i', 'exerciseId': exerciseId, 'workoutId': 'w1', 'reps': 8, 'loadKg': 60, 'performedAtUtc': '${day}T15:0$i:00Z', 'isDeleted': false};

      // One movement, one set: the reference's "1 exercise · 1 set recorded".
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, workouts: [workout([exercise(1, 'Barbell row')])], sets: [set(1, 'e1')])) ?? []);
      expect(find.text('1 exercise'), findsOneWidget);
      expect(find.text('Barbell row'), findsOneWidget);
      expect(find.text('1 set recorded'), findsOneWidget, reason: 'said once, not on the row and again below it');
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining(' of '), findsNothing, reason: 'no planned total exists, so none is shown');
      expect(find.text('Workout details'), findsOneWidget);
      expect(find.text('Resume workout'), findsOneWidget);

      // A long name and four movements: the name wraps, three are listed, the fourth is behind the link.
      const long = 'Single-arm dumbbell row with a three second pause at the top of every repetition';
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, workouts: [workout([exercise(1, long), exercise(2, 'Lat pulldown'), exercise(3, 'Cable row'), exercise(4, 'Face pull')])], sets: [set(1, 'e1'), set(2, 'e1'), set(3, 'e3')])) ?? [],
          size: const Size(320, 900));
      expect(find.text(long), findsOneWidget);
      expect(find.text('2 sets recorded'), findsOneWidget);
      expect(find.text('3 sets recorded'), findsOneWidget, reason: 'the total of what was recorded');
      expect(find.text('Face pull'), findsNothing);
      expect(find.text('See all 4 exercises'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow with a long name at 320 px');

      // Nothing added yet: still one honest card and one action.
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, workouts: [workout(const [])])) ?? []);
      expect(find.text('No exercise added yet'), findsOneWidget);
      expect(find.textContaining('recorded'), findsNothing);
    });

    testWidgets('a completed workout says so and offers no second start; a rest day shows no workout photograph', (tester) async {
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [blockPlan(start: '2026-09-21', recorded: 9)], primaryPlanId: 'p1')) ?? []);
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.textContaining('Finished: all planned sets recorded.'), findsOneWidget);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.byKey(const Key('today-resume')), findsNothing);

      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [blockPlan(start: '2026-09-22', recorded: 8)], primaryPlanId: 'p1')) ?? []);
      expect(find.text('Rest today'), findsOneWidget);
      expect(find.text('WORKOUT'), findsNothing);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.byKey(const Key('today-run')), findsOneWidget, reason: 'running stays available on a rest day');
    });

    testWidgets('Run and Nutrition sit side by side while short, and stack for logged food, large text or a narrow phone', (tester) async {
      final plan = blockPlan(start: '2026-09-21', recorded: 8);
      Future<bool> sideBySide({List<Json> food = const [], Size size = const Size(390, 1600), double scale = 1, int? calorieGoal}) async {
        await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [plan], primaryPlanId: 'p1', food: food, calorieGoal: calorieGoal)) ?? [], size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        final run = tester.getTopLeft(find.text('Run')), nutrition = tester.getTopLeft(find.text('Nutrition'));
        return (run.dy - nutrition.dy).abs() < 1 && nutrition.dx > run.dx;
      }

      expect(await sideBySide(), true);
      expect(find.text('No food logged today'), findsOneWidget);
      expect(find.textContaining('kcal'), findsNothing, reason: 'the bowl in the photograph is not an entry');
      expect(tester.getSize(find.byKey(const Key('today-run'))).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byKey(const Key('log-food'))).height, tester.getSize(find.byKey(const Key('today-run'))).height, reason: 'one button height for both');
      expect(tester.getTopLeft(find.byKey(const Key('log-food'))).dy, tester.getTopLeft(find.byKey(const Key('today-run'))).dy, reason: 'the two buttons line up');

      expect(await sideBySide(calorieGoal: 2200), true);
      expect(find.text('Your daily goal: 2,200 kcal'), findsOneWidget, reason: 'a goal that was set is named; none is invented');

      expect(await sideBySide(food: food, calorieGoal: 2200), false, reason: 'real values and a goal rail get the full width');
      expect(find.text('510'), findsOneWidget);
      expect(await sideBySide(scale: 1.6), false, reason: 'large text');
      expect(await sideBySide(size: const Size(320, 1600)), false, reason: 'a narrow phone');
      expect(await sideBySide(size: const Size(320, 4200), scale: 2, food: food, calorieGoal: 2200), false);
      expect(find.text('of 2,200 · 1,690 left'), findsOneWidget, reason: 'nothing is hidden to save space');
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
      expect(find.text('Can\'t sync right now'), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing, reason: 'a failed attempt does not prove the phone is offline');
      expect(find.text('Try again'), findsNothing);
      await tester.tap(find.byKey(const Key('today-connection')));
      await tester.pumpAndSettle();
      expect(find.textContaining('saved on this phone'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      // Me says the same thing in the same words, and does not claim the account has everything while it cannot be asked.
      await tester.tap(find.byKey(const Key('nav-me')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('me-sync')), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Can\'t sync right now · tap to try again'), findsOneWidget);
      expect(find.text('Everything is saved to your account'), findsNothing);
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('running has one clear button on every kind of day, and an open run is continued', (tester) async {
      Json run(String id, String startedDay, {bool open = true}) => {
            'id': id, 'dayKey': startedDay, 'startedAtUtc': '${startedDay}T07:00:00Z', 'finishedAtUtc': open ? null : '${startedDay}T07:30:00Z',
            'activeDurationSeconds': open ? null : 1800, 'distanceMeters': open ? null : 5000, 'isDeleted': false,
          };
      // No plan at all.
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day)) ?? []);
      expect(find.widgetWithText(OutlinedButton, 'Start run'), findsOneWidget);
      expect(find.text('No run today'), findsOneWidget);
      expect(find.byKey(const Key('today-run')), findsOneWidget, reason: 'one running entry point');

      // A run finished today: its real time and distance, and a new run can be started.
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, runs: [run('r0', day, open: false)])) ?? []);
      expect(find.text('Today: 30 min · 5.00 km'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Start run'), findsOneWidget);
      expect(find.text('Recorded today'), findsNothing, reason: 'a single run is said once, on its card');

      // A rest day of a plan, with a run begun yesterday and still open (as after closing and reopening the app).
      final plan = blockPlan(start: '2026-09-22', recorded: 8);
      await pumpApp(tester, await tester.runAsync(() => overridesFor(day: day, plans: [plan], primaryPlanId: 'p1', runs: [run('r1', '2026-10-10'), run('r0', day, open: false)])) ?? []);
      expect(find.text('Rest today'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Continue run'), findsOneWidget);
      expect(find.textContaining('In progress', findRichText: true), findsOneWidget);
      expect(find.textContaining('so far', findRichText: true), findsNothing, reason: 'no distance is claimed before one was measured');
      expect(find.text('Start run'), findsNothing, reason: 'an open run is never started twice');
      expect(find.byKey(const Key('today-run')), findsOneWidget, reason: 'one way into the open run, not two');
      expect(tester.takeException(), isNull);
    });

    testWidgets('unknown stays a dash and a goal never gets a remainder from a partial sum', (tester) async {
      Future<void> summary(List<FoodEntry> entries) => pumpApp(tester, const [],
          home: Scaffold(body: NutritionSummary(coverage: NutrientCoverage.calculate(entries), calorieGoal: 2200, proteinGoal: 140, onDetails: () {})));
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
