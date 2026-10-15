import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/plan_progress.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/plans/plan_screens.dart';
import 'package:gohard_rebuild/features/workout/workout_detail_screen.dart';
import 'package:gohard_rebuild/features/workout/workout_repository.dart';
import 'package:gohard_rebuild/features/workout/workout_runtime.dart';
import 'package:gohard_rebuild/features/workout/workout_screen.dart';

import 'support.dart';
import 'ui_support.dart';

// Built plans (docs/TRAINING_PLANS.md) through the real shell: Train › Plan, Today and the occurrence sheet all read
// the one projection, so they must say the same thing on every kind of day.

const _start = '2026-10-12'; // a Monday
const _pid = '6f1c2d3e-4a5b-4c6d-8e7f-90a1b2c3d4e5';
const _pid2 = '0b9d7c1e-2f3a-4b5c-9d6e-7f8091a2b3c4';
const _tall = Size(390, 3600);

Json _exercise(String workout, int i, String name, {double? load, String? notes}) => {
      'occurrenceKey': '$workout-e$i', 'catalogKey': name.toLowerCase().replaceAll(' ', '-'), 'name': name, 'isTimed': false,
      'targetSets': 3, 'targetRepsMin': 8, 'targetRepsMax': 12, 'targetDurationSeconds': null, 'restSeconds': 90,
      'targetLoadKg': ?load, 'notes': ?notes,
    };

final _workouts = <Json>[
  {'id': 'push', 'name': 'Push', 'notes': null, 'exercises': [_exercise('push', 1, 'Bench press', load: 60, notes: 'Pause at the bottom'), _exercise('push', 2, 'Overhead press')]},
  {'id': 'pull', 'name': 'Pull', 'notes': null, 'exercises': [_exercise('pull', 1, 'Barbell row'), _exercise('pull', 2, 'Lat pulldown')]},
  {'id': 'legs', 'name': 'Legs', 'notes': null, 'exercises': [_exercise('legs', 1, 'Back squat'), _exercise('legs', 2, 'Leg curl')]},
];

/// Push / Pull / Legs twice a week, Monday to Saturday, for four weeks: three definitions, six occurrences a week.
Json fixedPpl({String lifecycle = 'active', String? pausedOn}) {
  final schedule = {
    'mode': 'fixed', 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0,
    'pattern': [for (final (i, w) in ['push', 'pull', 'legs', 'push', 'pull', 'legs'].indexed) {'weekday': i + 1, 'workoutId': w}],
  };
  return {
    'id': _pid, 'title': 'Six-day PPL', 'lifecycle': lifecycle, 'pausedOn': pausedOn, 'startDate': _start, 'blockWeeks': 4, 'minRecoveryDays': 0,
    'isOngoing': false, 'timeBudgetMinutes': 45, 'templateId': 'push-pull-legs', 'workouts': _workouts, 'schedule': schedule,
    'occasions': PlanRules.generate(_pid, _start, 4, schedule, _workouts),
  };
}

/// Push → Pull → Legs on Monday, Wednesday and Friday, ongoing. Nothing is materialized until it is acted on.
Json rotatingPpl({String lifecycle = 'active', String? pausedOn, List<Json> occasions = const []}) => {
      'id': _pid, 'title': 'PPL rotation', 'lifecycle': lifecycle, 'pausedOn': pausedOn, 'startDate': _start, 'blockWeeks': 1, 'minRecoveryDays': 0,
      'isOngoing': true, 'timeBudgetMinutes': null, 'templateId': null, 'workouts': _workouts,
      'schedule': {'mode': 'rotating', 'pattern': <Json>[], 'cycle': ['push', 'pull', 'legs'], 'trainingDays': [1, 3, 5], 'cycleAnchor': 0},
      'occasions': occasions,
    };

Json _fixedOccasion(Json plan, String date) => (plan['occasions'] as List).cast<Json>().firstWhere((o) => o['scheduledDate'] == date);

/// A finished planned workout credited to occurrence [occasionId] (as on the phone before the account answers).
Json done(String occasionId, String title, String day, {String outcome = 'full'}) => {
      'id': 'w-$occasionId', 'planId': _pid, 'occasionId': occasionId, 'kind': 'planned', 'title': title, 'dayKey': day,
      'startedAtUtc': '${day}T10:00:00Z', 'finishedAtUtc': '${day}T11:00:00Z', 'activeDurationSeconds': 3600, 'outcome': outcome,
      'performedSets': 6, 'performedExercises': 2, 'qualifiedOccasion': true, 'isDeleted': false, 'exercises': <Json>[],
    };

Json manual(String day) => {
      'id': 'm1', 'kind': 'manual', 'title': 'Quick pull-ups', 'dayKey': day, 'startedAtUtc': '${day}T07:00:00Z', 'finishedAtUtc': '${day}T07:20:00Z',
      'activeDurationSeconds': 1200, 'outcome': 'manual_recorded', 'performedSets': 3, 'performedExercises': 1, 'qualifiedOccasion': false, 'isDeleted': false, 'exercises': <Json>[],
    };

String _seq(int k) => PlanRules.sequenceId(_pid, k);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, String day, Json plan, {List<Json> workouts = const [], Size size = _tall, double textScale = 1}) async {
  await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: day, plans: [plan], primaryPlanId: _pid, workouts: workouts)))!, size: size, textScale: textScale);
}

Future<void> _toPlan(WidgetTester tester) async {
  await _tap(tester, 'nav-train');
  await _tap(tester, 'train-plan');
}

Finder _in(String key, Finder f) => find.descendant(of: find.byKey(Key(key)), matching: f);
Finder _today(Finder f) => find.descendant(of: find.byKey(const Key('today-module-workout')), matching: f);

void main() {
  group('fixed weekdays: Train and Today agree', () {
    testWidgets('PPL on six days is six rows with their own states; finishing Monday\'s Push leaves Thursday\'s Push planned', (tester) async {
      final plan = fixedPpl();
      final monday = _fixedOccasion(plan, '2026-10-12');
      await _pump(tester, '2026-10-12', plan, workouts: [done(monday['id'] as String, 'Push', '2026-10-12')]);
      expect(_today(find.text('Completed')), findsOneWidget);
      expect(_today(find.textContaining('Next: Pull · Tuesday')), findsOneWidget);

      await _toPlan(tester);
      for (final (ordinal, title, state) in [(1, 'Push', 'Completed'), (2, 'Pull', 'Planned'), (3, 'Legs', 'Planned'), (4, 'Push', 'Planned'), (5, 'Pull', 'Planned'), (6, 'Legs', 'Planned')]) {
        expect(_in('occasion-1-$ordinal', find.text(title)), findsOneWidget, reason: 'row $ordinal is $title');
        expect(_in('occasion-1-$ordinal', find.text(state)), findsOneWidget, reason: 'row $ordinal is $state');
      }
      expect(find.byKey(const Key('occasion-1-7')), findsNothing);
      expect(find.text('Push / Pull / Legs · Fixed weekdays'), findsOneWidget, reason: 'the starter\'s name and the schedule mode');
      expect(find.text('Planned time 45 min'), findsOneWidget, reason: 'planned time, never a duration');
      // A finite fixed plan: credited completions out of the expected occurrences.
      expect(find.bySemanticsLabel('Six-day PPL. Week 1 of 4. 1 / 24 workouts completed, 4%.'), findsOneWidget);
    });

    testWidgets('due, rest, skipped and paused days read the same in Today and Train', (tester) async {
      // Due: Monday's Push.
      await _pump(tester, '2026-10-12', fixedPpl());
      expect(_today(find.text('Due today')), findsOneWidget);
      expect(_today(find.text('Push')), findsOneWidget);
      expect(_today(find.text('Week 1 · 45 min planned')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('occasion-1-1', find.text('Due')), findsOneWidget);

      // Rest: Sunday, everything of the week recorded.
      final plan = fixedPpl();
      final week = [for (final o in (plan['occasions'] as List).cast<Json>()) if (o['weekNumber'] == 1) done(o['id'] as String, o['title'] as String, o['scheduledDate'] as String)];
      await _pump(tester, '2026-10-18', plan, workouts: week);
      expect(_today(find.text('Rest day')), findsOneWidget);
      expect(_today(find.textContaining('Next: Push · Monday')), findsOneWidget);
      await _toPlan(tester);
      for (var n = 1; n <= 6; n++) {
        expect(_in('occasion-1-$n', find.text('Completed')), findsOneWidget);
      }

      // Skipped: Monday skipped. Today keeps it as Skipped today under its own name, not a rest day, and names
      // Tuesday's workout on its real date without offering it as today's; Train says Skipped.
      final skipped = fixedPpl();
      _fixedOccasion(skipped, '2026-10-12')['isSkipped'] = true;
      await _pump(tester, '2026-10-12', skipped);
      expect(_today(find.text('Skipped today')), findsOneWidget);
      expect(_today(find.text('Push')), findsOneWidget);
      expect(_today(find.textContaining('Next: Pull · Tuesday')), findsOneWidget);
      expect(_today(find.text('Rest day')), findsNothing);
      expect(find.byKey(const Key('today-start')), findsNothing);
      expect(find.byKey(const Key('today-undo-skip')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('occasion-1-1', find.text('Skipped')), findsOneWidget);
      expect(find.bySemanticsLabel('Six-day PPL. Week 1 of 4. 0 / 23 workouts completed, 0%.'), findsOneWidget, reason: 'a skipped workout is not expected');

      // Paused.
      await _pump(tester, '2026-10-14', fixedPpl(lifecycle: 'paused', pausedOn: '2026-10-13'));
      expect(_today(find.text('Plan paused')), findsOneWidget);
      await _toPlan(tester);
      expect(find.byKey(const Key('plan-resume')), findsOneWidget);
      expect(_in('occasion-1-1', find.text('Missed')), findsOneWidget, reason: 'it came due before the pause');
      expect(_in('occasion-1-3', find.text('Paused')), findsOneWidget);
      expect(find.byKey(const Key('plan-pause')), findsNothing);
    });

    testWidgets('a manual workout completes nothing scheduled, in Today or in Train', (tester) async {
      await _pump(tester, '2026-10-12', fixedPpl(), workouts: [manual('2026-10-12')]);
      expect(_today(find.text('Due today')), findsOneWidget);
      expect(find.byKey(const Key('today-start')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('occasion-1-1', find.text('Due')), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
    });
  });

  group('rotating sequence: Train and Today agree', () {
    testWidgets('due, rest, completed, skipped and paused', (tester) async {
      // Due on Monday: Push, step 1 of 3.
      await _pump(tester, '2026-10-12', rotatingPpl());
      expect(_today(find.text('Due today')), findsOneWidget);
      expect(_today(find.text('Push')), findsOneWidget);
      expect(_today(find.text('Step 1 of 3')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('rotation-0', find.text('Due')), findsOneWidget);
      expect(_in('cycle-step-0', find.text('Next')), findsOneWidget, reason: 'the current position is said in a word');
      expect(find.text('Your own split · Rotating sequence'), findsOneWidget);
      expect(find.textContaining('A rotation has no fixed dates'), findsOneWidget);

      // Tuesday is a rest day: the next workout waits for Wednesday.
      await _pump(tester, '2026-10-13', rotatingPpl());
      expect(_today(find.text('Rest day')), findsOneWidget);
      expect(_today(find.textContaining('Next in your rotation: Push · Wednesday')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('rotation-0', find.text('Planned')), findsOneWidget);
      expect(_in('rotation-0', find.text('Wed')), findsOneWidget);

      // Monday's Push done: done for today, Pull next on Wednesday; Push is a recent session.
      await _pump(tester, '2026-10-12', rotatingPpl(), workouts: [done(_seq(0), 'Push', '2026-10-12')]);
      expect(_today(find.text('Completed')), findsOneWidget);
      expect(_today(find.textContaining('Next in your rotation: Pull · Wednesday')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('rotation-0', find.text('Completed')), findsOneWidget);
      expect(_in('rotation-1', find.text('Planned')), findsOneWidget);
      expect(_in('rotation-1', find.text('Pull')), findsOneWidget);
      expect(_in('cycle-step-1', find.text('Next')), findsOneWidget);

      // Push skipped today: the skip keeps its day. Today says Push was skipped and names Pull as next in the
      // rotation, on its next training day, with "Train this now" as an explicit choice; Pull is not due today.
      final skippedPush = {
        ...PlanRules.occurrence(id: _seq(0), date: '2026-10-12', weekNumber: 1, ordinal: 1, workout: _workouts[0], sequenceIndex: 0),
        'isSkipped': true,
      };
      await _pump(tester, '2026-10-12', rotatingPpl(occasions: [skippedPush]));
      expect(_today(find.text('Skipped today')), findsOneWidget);
      expect(_today(find.text('Push')), findsOneWidget);
      expect(_today(find.textContaining('Next in your rotation: Pull · Wednesday')), findsOneWidget);
      expect(_today(find.text('Due today')), findsNothing);
      expect(find.byKey(const Key('today-train-now')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('rotation-0', find.text('Skipped')), findsOneWidget);
      expect(_in('rotation-1', find.text('Planned')), findsOneWidget);
      expect(_in('rotation-1', find.text('Wed')), findsOneWidget);

      // Paused.
      await _pump(tester, '2026-10-12', rotatingPpl(lifecycle: 'paused', pausedOn: '2026-10-12'));
      expect(_today(find.text('Plan paused')), findsOneWidget);
      await _toPlan(tester);
      expect(find.byKey(const Key('plan-resume')), findsOneWidget);
      expect(_in('rotation-0', find.text('Paused')), findsOneWidget);
    });

    testWidgets('the rotation continues across a week boundary instead of restarting on Monday', (tester) async {
      // Push and Pull done in week 1, Friday missed: the next Monday is Legs, still due, never missed.
      final ws = [done(_seq(0), 'Push', '2026-10-12'), done(_seq(1), 'Pull', '2026-10-14')];
      await _pump(tester, '2026-10-19', rotatingPpl(), workouts: ws);
      expect(_today(find.text('Due today')), findsOneWidget);
      expect(_today(find.text('Legs')), findsOneWidget);
      expect(_today(find.text('Step 3 of 3')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('rotation-2', find.text('Legs')), findsOneWidget);
      expect(_in('rotation-2', find.text('Due')), findsOneWidget);
      expect(_in('rotation-2', find.text('19')), findsOneWidget);
      expect(_in('rotation-3', find.text('Push')), findsOneWidget, reason: 'the cycle starts again only after Legs');
      expect(find.text('Missed'), findsNothing);

      // After Legs, cycle 2 begins.
      await _pump(tester, '2026-10-21', rotatingPpl(), workouts: [...ws, done(_seq(2), 'Legs', '2026-10-19')]);
      await _toPlan(tester);
      expect(find.text('Cycle 2 · step 1 of 3 · Push next'), findsOneWidget);
    });

    testWidgets('rotating plans show this week and the cycle position, never an overall percentage', (tester) async {
      await _pump(tester, '2026-10-14', rotatingPpl(), workouts: [done(_seq(0), 'Push', '2026-10-12')]);
      await _toPlan(tester);
      expect(find.text('Sessions completed this week'), findsNothing);
      expect(find.text('Session completed this week'), findsOneWidget);
      expect(find.text('Cycle 1 · step 2 of 3 · Pull next'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget, reason: 'an ongoing plan counts its weeks with no total');
      expect(find.textContaining('%'), findsNothing);
      expect(find.byType(ProgressRail), findsNothing);
      expect(find.textContaining('Workouts completed'), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const Key('plan-edit')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Replace a movement in remaining workouts'), findsNothing, reason: 'a rotation has no dated workouts to swap in; it is edited');
    });

    testWidgets('a manual workout does not advance the rotation', (tester) async {
      await _pump(tester, '2026-10-12', rotatingPpl(), workouts: [manual('2026-10-12')]);
      expect(_today(find.text('Push')), findsOneWidget);
      expect(_today(find.text('Due today')), findsOneWidget);
      await _toPlan(tester);
      expect(_in('rotation-0', find.text('Due')), findsOneWidget);
      expect(_in('cycle-step-0', find.text('Next')), findsOneWidget);
    });
  });

  group('the occurrence sheet', () {
    testWidgets('a missed fixed day offers Move, Skip, Start now and Edit this workout only, with the prescription and weight target', (tester) async {
      await _pump(tester, '2026-10-14', fixedPpl());
      await _toPlan(tester);
      expect(_in('occasion-1-1', find.text('Missed')), findsOneWidget);
      await _tap(tester, 'occasion-1-1');
      expect(find.byType(BottomSheet), findsOneWidget);
      for (final k in ['occasion-move', 'occasion-skip', 'occasion-start', 'occasion-edit-one']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.widgetWithText(FilledButton, 'Start now'), findsOneWidget);
      expect(find.textContaining('never marked done by itself'), findsOneWidget);
      expect(find.text('3 × 8–12 · 90 s rest'), findsNWidgets(2));
      expect(find.text('Target 60 kg'), findsOneWidget);
      expect(find.text('Pause at the bottom'), findsOneWidget);
    });

    testWidgets('a rotation\'s next workout offers Start and Skip, no Move, and says why; a later step waits its turn', (tester) async {
      await _pump(tester, '2026-10-12', rotatingPpl());
      await _toPlan(tester);
      await _tap(tester, 'rotation-0');
      expect(find.byKey(const Key('occasion-start')), findsOneWidget);
      expect(find.byKey(const Key('occasion-skip')), findsOneWidget);
      expect(find.byKey(const Key('occasion-move')), findsNothing);
      expect(find.byKey(const Key('occasion-edit-one')), findsNothing);
      expect(find.text('A rotation has no dates to move: this workout waits for you until you do it or skip it.'), findsOneWidget);
      expect(find.text('SESSION 1 · STEP 1 OF 3, CYCLE 1'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await _tap(tester, 'rotation-1');
      expect(find.byKey(const Key('occasion-start')), findsNothing);
      expect(find.byKey(const Key('occasion-skip')), findsNothing);
      expect(find.textContaining('Comes after Push'), findsOneWidget);
    });
  });

  testWidgets('Edit, Pause, Duplicate and Create are in Manage; Archive is on a saved plan\'s page', (tester) async {
    final saved = {...rotatingPpl(lifecycle: 'paused'), 'id': _pid2, 'title': 'Old rotation'};
    final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-12', plans: [fixedPpl(), saved], primaryPlanId: _pid)))!;
    await pumpApp(tester, overrides, size: _tall);
    await _toPlan(tester);
    for (final k in ['plan-edit', 'plan-pause', 'plan-duplicate']) {
      expect(tester.widget<GroupRow>(find.byKey(Key(k))).onTap, isNotNull, reason: k);
    }
    // A fixed plan keeps the reviewed swap (its own workouts follow an accepted one); a rotation is edited instead.
    expect(find.text('Replace a movement in remaining workouts'), findsOneWidget);
    expect(find.text('Create a different plan'), findsOneWidget);
    await _tap(tester, 'plan-pause');
    expect(find.text('Pause Six-day PPL?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await _tap(tester, 'saved-plan-$_pid2');
    expect(find.byType(PlanDetailScreen), findsOneWidget);
    for (final k in ['plan-archive', 'plan-edit', 'plan-duplicate', 'plan-resume']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('Your own split · Rotating sequence'), findsOneWidget);
  });

  testWidgets('the workout shows the plan\'s weight target apart from the last performance, and never puts the target in the entry', (tester) async {
    final plan = fixedPpl();
    final monday = _fixedOccasion(plan, '2026-10-12');
    final prescription = (monday['prescription'] as List).cast<Json>();
    final open = {
      'id': 'w-open', 'planId': _pid, 'occasionId': monday['id'], 'kind': 'planned', 'title': 'Push', 'dayKey': '2026-10-12',
      'startedAtUtc': '2026-10-12T15:00:00Z', 'finishedAtUtc': null, 'isDeleted': false,
      'exercises': [
        for (final (i, p) in prescription.indexed)
          {'id': 'x$i', 'ordinal': i + 1, 'name': p['name'], 'catalogKey': p['catalogKey'], 'isPrescribed': true, 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 8, 'targetRepsMax': 12,
            'restSeconds': 90, 'targetLoadKg': p['targetLoadKg'], 'notes': p['notes'], 'isDeleted': false},
      ],
    };
    final before = {...manual('2026-10-09'), 'id': 'm0', 'startedAtUtc': '2026-10-09T07:00:00Z', 'exercises': [{'id': 'm0-e', 'ordinal': 1, 'name': 'Bench press', 'catalogKey': 'bench-press', 'isDeleted': false}]};
    final sets = [{'id': 's0', 'exerciseId': 'm0-e', 'workoutId': 'm0', 'reps': 8, 'loadKg': 57.5, 'performedAtUtc': '2026-10-09T07:05:00Z', 'isDeleted': false}];
    final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-12', plans: [plan], primaryPlanId: _pid, workouts: [open, before], sets: sets)))!;
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _QuietRepo(SyncEngine(db, Api(FakeServer(), SessionManager(MemorySecretStore())), SessionManager(MemorySecretStore())));
    await pumpApp(tester, [...overrides, workoutRepositoryProvider.overrideWithValue(repo)], home: const WorkoutScreen(workoutId: 'w-open'), settle: false);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('workout-target-load')), findsOneWidget);
    expect(find.text('Target 60 kg'), findsOneWidget);
    expect(find.text('Last time 57.5 kg × 8 (Fri, Oct 9)'), findsOneWidget);
    expect(find.text('Pause at the bottom'), findsOneWidget);
    final load = tester.widget<TextField>(find.descendant(of: find.byKey(const Key('set-load')), matching: find.byType(TextField)));
    expect(load.controller!.text, isNot('60'), reason: 'a suggestion only ever comes from what was recorded, never from the target');
    expect(find.text('None yet. Targets and suggestions are not recorded sets.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history says which plan and session a workout came from, and that a manual one is manual', (tester) async {
    final plan = {...rotatingPpl(lifecycle: 'closed'), 'isArchived': true};
    final earlier = [for (final (k, t, d) in [(0, 'Push', '2026-10-12'), (1, 'Pull', '2026-10-14'), (2, 'Legs', '2026-10-16'), (3, 'Push', '2026-10-19')]) done(_seq(k), t, d)];
    final w = done(_seq(4), 'Pull', '2026-10-21');
    final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-30', plans: [plan], workouts: [...earlier, w, manual('2026-10-22')])))!;
    await pumpApp(tester, overrides, home: WorkoutDetailScreen(workoutId: 'w-${_seq(4)}'));
    expect(find.text('From PPL rotation (archived) · Pull · session 5 of the rotation · Wednesday, October 21'), findsOneWidget);
    await pumpApp(tester, overrides, home: const WorkoutDetailScreen(workoutId: 'm1'));
    expect(find.text('Manual workout · not part of a plan'), findsOneWidget);
    await pumpApp(tester, overrides, home: const WorkoutHistoryScreen());
    expect(find.textContaining('· PPL rotation'), findsNWidgets(5));
    expect(find.textContaining('· manual'), findsOneWidget);
  });

  testWidgets('a 320 px phone at twice the text size: fixed and rotating plans, the sheet and plan review do not overflow', (tester) async {
    for (final plan in [fixedPpl(), rotatingPpl()]) {
      await _pump(tester, '2026-10-14', plan, workouts: [done(plan['schedule']['mode'] == 'rotating' ? _seq(0) : _fixedOccasion(plan, '2026-10-12')['id'] as String, 'Push', '2026-10-12')],
          size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull, reason: 'Today');
      await _toPlan(tester);
      expect(tester.takeException(), isNull, reason: 'Train');
      await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Train, at the end');
      final row = plan['schedule']['mode'] == 'rotating' ? 'rotation-1' : 'occasion-1-2';
      await _tap(tester, row);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the sheet');
      await tester.pumpWidget(const SizedBox());
    }
    final draft = {...rotatingPpl(lifecycle: 'draft'), 'id': _pid2};
    await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: '2026-10-12', plans: [draft])))!, home: const PlanReviewScreen(planId: _pid2), size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull, reason: 'review');
    expect(find.byKey(const Key('plan-start')), findsOneWidget);
    expect(find.byKey(const Key('plan-save-later')), findsOneWidget);
  });

  testWidgets('plan review shows a rotation truthfully: its cycle and projected next sessions', (tester) async {
    final draft = {...rotatingPpl(lifecycle: 'draft'), 'id': _pid2};
    await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: '2026-10-13', plans: [draft])))!, home: const PlanReviewScreen(planId: _pid2), size: _tall);
    expect(find.text('Cycle: Push → Pull → Legs'), findsOneWidget);
    expect(find.text('Wed, Oct 14 · Push'), findsOneWidget, reason: 'projected from today onto the training days');
    expect(find.text('Fri, Oct 16 · Pull'), findsOneWidget);
    expect(find.text('Mon, Oct 19 · Legs'), findsOneWidget);
    expect(find.byKey(const Key('plan-edit')), findsOneWidget);
    expect(find.byKey(const Key('plan-edit-schedule')), findsNothing, reason: 'the older setup route cannot change a built plan');
    expect(tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('plan-start')), matching: find.byType(FilledButton))).onPressed, isNotNull);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name}: a rotation\'s plan view and its sheet meet contrast, target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final store = AppearanceStore(MemorySecretStore())
        ..accent = Accent.pink
        ..mode = mode;
      final overrides = (await tester.runAsync(() => overridesFor(day: '2026-10-14', plans: [rotatingPpl()], primaryPlanId: _pid, workouts: [done(_seq(0), 'Push', '2026-10-12')], appearance: store)))!;
      await pumpApp(tester, overrides, size: const Size(390, 2600));
      await _toPlan(tester);
      Future<void> check(String what) async {
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: what);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: what);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: what);
      }

      await check('plan');
      await _tap(tester, 'rotation-1');
      await check('sheet');
      handle.dispose();
    });
  }

  test('prescriptions read as sets × reps with rest', () {
    expect(prescriptionLine(sets: 3, repsMin: 8, repsMax: 12, rest: 90), '3 × 8–12 · 90 s rest');
    expect(prescriptionLine(sets: 3, seconds: 45, rest: 120), '3 × 45 s · 2 min rest');
    expect(prescriptionLine(sets: 3), '3 sets');
    expect(prescriptionLine(repsMin: 5, repsMax: 5), '5 reps');
    expect(prescriptionLine(), 'No target');
    expect(weekStart('2026-10-18'), '2026-10-12');
    expect(addDays(weekStart('2026-10-19'), 0), '2026-10-19');
  });
}

/// The workout screen's runtime is phone-only state; this keeps it in memory so the screen can be pumped alone.
class _QuietRepo extends WorkoutRepository {
  _QuietRepo(SyncEngine sync) : super(sync, 'one', FakeClock(DateTime.utc(2026, 10, 12, 15)));
  @override
  Future<WorkoutRuntime?> runtime(String workoutId) async => WorkoutRuntime.started(DateTime.utc(2026, 10, 12, 15));
  @override
  Future<void> saveRuntime(String workoutId, WorkoutRuntime runtime) async {}
}
