import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/plans/plan_progress.dart';
import 'package:gohard_rebuild/features/plans/plan_screens.dart';
import 'package:gohard_rebuild/features/workout/workout_flow.dart';
import 'package:gohard_rebuild/features/plans/week_widgets.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/workout_detail_screen.dart';

import 'ui_support.dart';

const _day = '2026-10-11'; // Sunday of week 3 of a block started 2026-09-21: Mon 5, Wed 7 and Sun 11 are its workouts
const _start = '2026-09-21';
const _tall = Size(390, 3200);

Json _finished(String id, String day) => {
      'id': id, 'kind': 'manual', 'title': 'Push day', 'dayKey': day, 'startedAtUtc': '${day}T16:00:00Z', 'finishedAtUtc': '${day}T16:40:00Z', 'activeDurationSeconds': 2400,
      'outcome': 'manual_recorded', 'performedSets': 3, 'performedExercises': 1, 'qualifiedOccasion': false, 'isDeleted': false,
      'exercises': [{'id': '$id-e', 'ordinal': 1, 'name': 'Bench press', 'catalogKey': 'bench-press', 'isDeleted': false}],
    };

Json _occasion(Json plan, String id) => (plan['occasions'] as List).cast<Json>().firstWhere((o) => o['id'] == id);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _openTrain(WidgetTester tester, String section) async {
  await _tap(tester, 'nav-train');
  await _tap(tester, 'train-$section');
}

void main() {
  group('week states come from recorded work', () {
    WeekState state(Json plan, int week, {String today = _day, List<Workout> workouts = const []}) {
      final p = Plan(plan);
      return weekStateOf(planWeeks(p, today, workouts)[week - 1], p, today, workouts);
    }

    test('a week whose dates have passed is Done only when every expected workout has a result', () {
      final plan = blockPlan(start: _start, recorded: 5); // week 1 complete, week 2 two of three
      expect(state(plan, 1), WeekState.done);
      expect(state(plan, 2), WeekState.partial, reason: 'the dates have passed; one workout has no record');
      expect(weekLook(WeekState.partial, const Completion(2, 3)).$1, '2 of 3');
      expect(state(plan, 3), WeekState.current);
      expect(state(plan, 4), WeekState.upcoming);
      expect(state(blockPlan(start: _start), 1), WeekState.missed, reason: 'nothing recorded in a past week is never Done');
      expect(state(blockPlan(start: _start, recorded: 9), 3), WeekState.done, reason: 'the current week once all of it is recorded');
      expect(state(blockPlan(start: _start, weeks: 2), 1, today: '2027-01-01'), WeekState.missed, reason: 'long after the block ended, still not Done');
    });

    test('skipped and paused weeks say so instead of Missed', () {
      final plan = blockPlan(start: _start, recorded: 3);
      for (final o in (plan['occasions'] as List).cast<Json>().where((o) => o['weekNumber'] == 2)) {
        o['isSkipped'] = true;
      }
      expect(state(plan, 2), WeekState.skipped);
      final paused = {...blockPlan(start: _start, recorded: 3), 'lifecycle': 'paused', 'pausedOn': '2026-09-28'};
      expect(state(paused, 2, today: '2026-10-20'), WeekState.paused, reason: 'nothing counts as missed while the plan is paused');
    });
  });

  for (final weeks in [8, 12, 16]) {
    testWidgets('a $weeks-week plan shows every week with its own dates, and the pass shows the real plan', (tester) async {
      final handle = tester.ensureSemantics();
      final plan = blockPlan(title: 'Winter strength', start: _start, weeks: weeks, recorded: 8);
      await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1')))!, size: _tall);
      await _openTrain(tester, 'plan');
      expect(find.text('Winter strength'), findsOneWidget);
      expect(find.text('Week 3 of $weeks'), findsOneWidget);
      expect(find.bySemanticsLabel('Winter strength. Week 3 of $weeks. 8 / ${weeks * 3} workouts completed, ${(800 / (weeks * 3)).round()}%.'), findsOneWidget);
      expect(find.textContaining('8 / ${weeks * 3}', findRichText: true), findsOneWidget);
      for (var n = 1; n <= weeks; n++) {
        final range = dateRange(addDays(_start, 7 * (n - 1)), addDays(_start, 7 * n - 1));
        expect(find.byKey(Key('week-$n')), findsOneWidget, reason: 'week $n of $weeks');
        expect(find.descendant(of: find.byKey(Key('week-$n')), matching: find.text(range)), findsOneWidget, reason: 'week $n is $range');
      }
      expect(find.byKey(Key('week-${weeks + 1}')), findsNothing);
      // Three across on an ordinary phone.
      expect(tester.getTopLeft(find.byKey(const Key('week-3'))).dy, tester.getTopLeft(find.byKey(const Key('week-1'))).dy);
      expect(tester.getTopLeft(find.byKey(const Key('week-4'))).dy, greaterThan(tester.getTopLeft(find.byKey(const Key('week-1'))).dy));
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }

  testWidgets('past weeks with unrecorded workouts are labelled honestly, and the chosen week is not the current week', (tester) async {
    final handle = tester.ensureSemantics();
    final plan = blockPlan(start: _start, recorded: 2); // week 1: two of three; week 2: nothing
    await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1')))!, size: _tall);
    await _openTrain(tester, 'plan');
    Finder inWeek(int n, String text) => find.descendant(of: find.byKey(Key('week-$n')), matching: find.text(text));
    expect(find.text('Done'), findsNothing, reason: 'no week is complete, whatever the calendar says');
    expect(inWeek(1, '2 of 3'), findsOneWidget);
    expect(inWeek(2, 'Missed'), findsOneWidget);
    expect(inWeek(3, 'Current'), findsOneWidget);
    expect(inWeek(4, 'Upcoming'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('week-2')), matching: find.byIcon(Icons.error_outline)), findsOneWidget, reason: 'an icon with the word, not a colour');

    // The current week is selected to begin with: both facts, said separately.
    expect(tester.getSemantics(find.byKey(const Key('week-3'))), isSemantics(isSelected: true, isButton: true, label: 'Week 3, Oct 5 – 11, this week, 0 of 3 workouts completed', value: 'Current'));
    expect(find.text('This week'), findsOneWidget);

    await _tap(tester, 'week-5');
    expect(tester.getSemantics(find.byKey(const Key('week-5'))), isSemantics(isSelected: true, isButton: true, label: 'Week 5, Oct 19 – 25, 0 of 3 workouts completed', value: 'Upcoming'));
    expect(tester.getSemantics(find.byKey(const Key('week-3'))), isSemantics(isSelected: false, isButton: true, label: 'Week 3, Oct 5 – 11, this week, 0 of 3 workouts completed', value: 'Current'));
    expect(inWeek(5, 'Current'), findsNothing, reason: 'choosing a week does not make it the current one');
    expect(inWeek(5, 'Upcoming'), findsOneWidget);
    expect(inWeek(3, 'Current'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
    expect(find.text('Week 5'), findsNWidgets(2), reason: 'the tile and the schedule heading');
    expect(find.byKey(const Key('occasion-5-1')), findsOneWidget);
    Color fill(int n) => tester.widget<Material>(find.ancestor(of: find.byKey(Key('week-$n')), matching: find.byType(Material)).first).color!;
    expect(fill(5), isNot(fill(3)), reason: 'the chosen tile is tinted; the current one is not');
    handle.dispose();
  });

  testWidgets('each workout of the chosen week has its day, a prescription summary and a named state with an icon', (tester) async {
    final handle = tester.ensureSemantics();
    final plan = blockPlan(start: _start, recorded: 4);
    _occasion(plan, 'o2-2')
      ..['resultOutcome'] = 'partial'
      ..['resultWorkoutId'] = 'done-2-2';
    _occasion(plan, 'o2-3')['isSkipped'] = true;
    final open = openWorkout(plan, 'o3-2', day: _day, recordedSets: 2);
    final overrides = (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout], sets: open.sets)))!;
    await pumpApp(tester, overrides, size: _tall);
    await _openTrain(tester, 'plan');

    void row(String key, String state, IconData icon) {
      final r = find.byKey(Key('occasion-$key'));
      expect(find.descendant(of: r, matching: find.text(state)), findsOneWidget, reason: '$key is $state');
      expect(find.descendant(of: r, matching: find.byIcon(icon)), findsOneWidget, reason: '$state has its icon');
      expect(find.descendant(of: r, matching: find.text('5 exercises · 18 planned sets')), findsOneWidget);
    }

    row('3-1', 'Missed', Icons.error_outline);
    row('3-2', 'In progress', Icons.timelapse);
    row('3-3', 'Due', Icons.radio_button_unchecked);
    expect(find.descendant(of: find.byKey(const Key('occasion-3-3')), matching: find.text('Sun')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('occasion-3-3')), matching: find.text('11')), findsOneWidget);
    expect(find.bySemanticsLabel('Upper body A, Sunday, October 11, today, 5 exercises · 18 planned sets, Due'), findsOneWidget);
    expect(find.text('1 of 3 completed'), findsNothing, reason: 'an open workout is not a completed one');
    expect(find.text('0 of 3 completed'), findsOneWidget);

    await _tap(tester, 'week-2');
    row('2-1', 'Completed', Icons.check_circle);
    row('2-2', 'Partial', Icons.check_circle_outline);
    row('2-3', 'Skipped', Icons.remove_circle_outline);
    expect(find.text('2 of 2 completed'), findsOneWidget, reason: 'a skipped workout is not expected');

    await _tap(tester, 'week-4');
    row('4-1', 'Planned', Icons.schedule);

    // The row still opens the workout's sheet, in the shared sheet.
    await _tap(tester, 'occasion-4-1');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('occasion-start')), findsOneWidget);
    expect(find.byKey(const Key('occasion-move')), findsOneWidget);
    expect(find.byKey(const Key('occasion-skip')), findsOneWidget);
    expect(find.text('4 × 6–8 · 90 s rest'), findsNWidgets(3), reason: 'sets × reps and the rest, as the plan builder writes them');
    expect(find.text('3 × 6–8 · 90 s rest'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('a paused plan labels what is waiting as Paused and keeps Resume plan', (tester) async {
    final plan = {...blockPlan(start: _start, recorded: 6), 'lifecycle': 'paused', 'pausedOn': '2026-10-06'};
    await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1')))!, size: _tall);
    await _openTrain(tester, 'plan');
    expect(find.byKey(const Key('plan-resume')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('occasion-3-1')), matching: find.text('Missed')), findsOneWidget, reason: 'it came due before the pause');
    expect(find.descendant(of: find.byKey(const Key('occasion-3-3')), matching: find.text('Paused')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('week-4')), matching: find.text('Paused')), findsOneWidget);
    expect(find.text('Pause plan'), findsNothing);
    for (final action in ['Replace a movement in remaining workouts', 'Review or finish this block', 'Create a different plan']) {
      expect(find.text(action), findsOneWidget, reason: action);
    }
  });

  testWidgets('the Train section survives other tabs, a pushed page, and a change of accent and mode', (tester) async {
    final store = AppearanceStore(MemorySecretStore());
    final plan = blockPlan(start: _start, recorded: 8);
    final container = await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', workouts: [_finished('m1', '2026-10-09')], appearance: store)))!);
    await _openTrain(tester, 'progress');
    expect(find.text('Am I following my plan?'), findsOneWidget);

    await _tap(tester, 'nav-eat');
    await _tap(tester, 'nav-me');
    container.read(appearanceProvider.notifier)
      ..setAccent(Accent.green)
      ..setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await _tap(tester, 'nav-train');
    expect(Theme.of(tester.element(find.text('Am I following my plan?'))).extension<GoColors>()!.accent, GoColors.of(Accent.green, Brightness.dark).accent);
    expect(container.read(shellProvider).trainView, TrainView.progress);

    await _tap(tester, 'progress-history');
    expect(find.byType(WorkoutHistoryScreen), findsOneWidget);
    container.read(appearanceProvider.notifier).setAccent(Accent.pink);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(container.read(shellProvider).trainView, TrainView.progress);
    expect(find.text('Am I following my plan?'), findsOneWidget);
    expect(find.byKey(const Key('start-manual')), findsNothing, reason: 'still Progress, not Workouts');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Workout history is offered in Workouts and in Progress, with and without recorded training', (tester) async {
    for (final workouts in [const <Json>[], [_finished('m1', '2026-10-09')]]) {
      await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, workouts: workouts)))!, size: const Size(390, 1400));
      await _openTrain(tester, 'workouts');
      expect(find.byKey(const Key('start-manual')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('train-start-run')), matching: find.text('Start a run')), findsOneWidget);
      expect(find.text('Run history'), findsOneWidget);
      expect(find.text(workouts.isEmpty ? 'No workouts recorded yet' : 'Push day'), findsOneWidget);
      await _tap(tester, 'train-history');
      expect(find.byType(WorkoutHistoryScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // The route the native journeys take: Train, Progress, the row that reads "Workout history".
      await _tap(tester, 'train-progress');
      expect(find.text(workouts.isEmpty ? 'No training recorded yet' : 'Am I consistent?'), findsOneWidget);
      await tester.ensureVisible(find.text('Workout history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workout history'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutHistoryScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('an open workout keeps its Resume button in Workouts', (tester) async {
    final plan = blockPlan(start: _start, recorded: 8);
    final open = openWorkout(plan, 'o3-3', day: _day, recordedSets: 6);
    await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout], sets: open.sets)))!);
    await _openTrain(tester, 'workouts');
    expect(find.text('Open workouts'), findsOneWidget);
    expect(find.ancestor(of: find.text('Resume'), matching: find.byWidgetPredicate((w) => w is FilledButton)), findsOneWidget, reason: 'the deep Resume button of the open workout panel');
    expect(find.textContaining('In progress · started Sun, Oct 11'), findsOneWidget);
  });

  testWidgets('nothing overflows at 320 px with twice the text size: a 16-week plan, Workouts and Progress', (tester) async {
    final plan = blockPlan(title: 'A sixteen week strength and conditioning block', start: _start, weeks: 16, recorded: 7);
    final open = openWorkout(plan, 'o3-3', day: _day, recordedSets: 6);
    final overrides = (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout, _finished('m1', '2026-10-09'), _finished('m2', '2026-10-02')], sets: open.sets)))!;
    await pumpApp(tester, overrides, size: const Size(320, 640), textScale: 2);
    await _tap(tester, 'nav-train');
    for (final section in ['plan', 'workouts', 'progress']) {
      await _tap(tester, 'train-$section');
      expect(tester.takeException(), isNull, reason: section);
    }
    await _tap(tester, 'train-plan');
    expect(find.byKey(const Key('week-16')), findsOneWidget, reason: 'every week is there, one to a row');
    expect(tester.getTopLeft(find.byKey(const Key('week-2'))).dy, greaterThan(tester.getTopLeft(find.byKey(const Key('week-1'))).dy));
    expect(tester.getSize(find.byKey(const Key('week-1'))).height, greaterThanOrEqualTo(48));
    await _tap(tester, 'occasion-3-1');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the workout sheet');
  });

  testWidgets('workout record, history, plan review, manual setup and the movement picker fit 320 px at twice the text size', (tester) async {
    final draft = {...blockPlan(id: 'p2', title: 'Next block', start: '2026-11-16'), 'lifecycle': 'draft'};
    final done = _finished('m1', '2026-10-09');
    final sets = [for (var i = 0; i < 3; i++) {'id': 's$i', 'exerciseId': 'm1-e', 'workoutId': 'm1', 'reps': 6, 'loadKg': 82.5, 'performedAtUtc': '2026-10-09T16:1$i:00Z', 'isDeleted': false}];
    final overrides = (await tester.runAsync(() => overridesFor(day: _day, plans: [blockPlan(start: _start), draft], primaryPlanId: 'p1', workouts: [done], sets: sets)))!;
    for (final (name, page) in <(String, Widget)>[
      ('record', const WorkoutDetailScreen(workoutId: 'm1')),
      ('result', const WorkoutDetailScreen(workoutId: 'm1', justFinished: true)),
      ('history', const WorkoutHistoryScreen()),
      ('plan review', const PlanReviewScreen(planId: 'p2')),
      ('manual setup', const ManualWorkoutSetup()),
      ('picker', const ExercisePicker()),
    ]) {
      await pumpApp(tester, overrides, home: page, size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull, reason: name);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name, further down');
      await tester.pumpWidget(const SizedBox());
    }
    await pumpApp(tester, overrides, home: const WorkoutDetailScreen(workoutId: 'm1'));
    expect(find.text('40 min'), findsOneWidget);
    expect(find.text('1.  82.5 kg × 6'), findsOneWidget, reason: 'what was recorded, unchanged');
  });

  for (final accent in Accent.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${accent.name} ${mode.name}: Workouts, Progress, a past week and the workout sheet meet contrast, target and label guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        final plan = blockPlan(start: _start, recorded: 2);
        final open = openWorkout(plan, 'o3-3', day: _day, recordedSets: 6);
        final store = AppearanceStore(MemorySecretStore())
          ..accent = accent
          ..mode = mode;
        await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _day, plans: [plan], primaryPlanId: 'p1', workouts: [open.workout, _finished('m1', '2026-10-09')], sets: open.sets, appearance: store)))!, size: const Size(390, 2000));
        Future<void> check(String what) async {
          await expectLater(tester, meetsGuideline(textContrastGuideline), reason: what);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: what);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: what);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: what);
        }

        await _tap(tester, 'nav-train');
        for (final section in ['workouts', 'progress', 'plan']) {
          await _tap(tester, 'train-$section');
          await check(section);
        }
        await _tap(tester, 'week-2'); // a missed week, selected
        await check('a missed week');
        await _tap(tester, 'occasion-2-1');
        expect(find.byType(BottomSheet), findsOneWidget);
        await check('the workout sheet');
        handle.dispose();
      });
    }
  }

  testWidgets('with Reduce Motion a section changes at once', (tester) async {
    final overrides = (await tester.runAsync(() => overridesFor(day: _day)))!;
    await pumpApp(tester, overrides);
    await _tap(tester, 'nav-train');
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('train-plan')));
    await tester.pump();
    await tester.pump();
    expect(find.text('No plan yet'), findsOneWidget);
    expect(find.byKey(const Key('start-manual')), findsNothing);
    expect(tester.widget<FadeTransition>(find.ancestor(of: find.text('No plan yet'), matching: find.byType(FadeTransition)).first).opacity.value, 1);
    expect(find.byType(GroupCard), findsNothing);
  });
}
