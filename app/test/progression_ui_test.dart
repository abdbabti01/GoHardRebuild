import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/plus/entitlement.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/progression.dart';
import 'package:gohard_rebuild/features/workout/workout_runtime.dart';

import 'support.dart';
import 'ui_support.dart';

// Next targets in the real panel, on a real local database (docs/PROGRESSION.md). Fixture, clearly labelled: a daily
// "Push" plan from Sat 10 Oct with bench press at a 190 lb target (3 × 6–8), two complete earlier sessions (10 and
// 11 Oct) of 3 × 8 at 190 lb, and a 5 lb increment. Today is Mon 12 Oct.

const _pid = '7a1c2d3e-4a5b-4c6d-8e7f-90a1b2c3d4e5';
const _start = '2026-10-10', _today = '2026-10-12';
final _target = ProgressionRules.round3(loadInputToKg(190, LoadUnit.lb));

Json _plan() {
  final workouts = [
    {'id': 'push', 'name': 'Push', 'notes': null, 'exercises': [
      {'occurrenceKey': 'e1', 'catalogKey': 'bench-press', 'name': 'Bench press', 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 6, 'targetRepsMax': 8,
        'targetDurationSeconds': null, 'restSeconds': 90, 'targetLoadKg': _target},
      {'occurrenceKey': 'e2', 'catalogKey': 'overhead-press', 'name': 'Overhead press', 'isTimed': false, 'targetSets': 2, 'targetRepsMin': 8, 'targetRepsMax': 10,
        'targetDurationSeconds': null, 'restSeconds': 90},
    ]},
  ];
  final schedule = {'mode': 'fixed', 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0, 'pattern': [for (var d = 1; d <= 7; d++) {'weekday': d, 'workoutId': 'push'}]};
  return {
    'id': _pid, 'title': 'Daily push', 'lifecycle': 'active', 'pausedOn': null, 'startDate': _start, 'blockWeeks': 2, 'minRecoveryDays': 0, 'isOngoing': false, 'revision': 3,
    'timeBudgetMinutes': 45, 'templateId': null, 'workouts': workouts, 'schedule': schedule, 'occasions': PlanRules.generate(_pid, _start, 2, schedule, workouts),
  };
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<(ProviderContainer, AppDb, Future<T> Function<T>(Future<T>), Future<void> Function())> setUpApp(WidgetTester tester, {Size size = const Size(390, 2600), double textScale = 1}) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 10, 10, 7));
    final container = await pumpApp(
      tester,
      [
        ...(await tester.runAsync(() => overridesFor(day: _today, primaryPlanId: _pid, profile: {'loadUnit': 'lb'}, liveWorkouts: true, livePlans: true)))!,
        dbProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        plusProvider.overrideWithValue(plusPreview), // next-target suggestions are a GoHard Plus feature (docs/PLUS_PREVIEW.md)
        syncProvider.overrideWith((ref) {
          final engine = SyncEngine(db, Api(FakeServer()..offline = true, ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
          ref.onDispose(engine.dispose);
          return engine;
        }),
      ],
      size: size, textScale: textScale, settle: false,
    );
    Future<T> run<T>(Future<T> work) async {
      T? out;
      Object? failed;
      var done = false;
      work.then<void>((v) => out = v, onError: (Object e) => failed = e).whenComplete(() => done = true);
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      if (failed != null) throw failed!;
      expect(done, isTrue, reason: 'the local database answered');
      return out as T;
    }

    Future<void> settle() async {
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    final sync = container.read(syncProvider);
    await run(sync.putLocal('one', LocalWrite(Kinds.plan, _pid, _plan())));
    await settle();
    await run(() async {
      final repo = container.read(workoutRepositoryProvider);
      for (final day in ['2026-10-10', '2026-10-11']) {
        clock.now = DateTime.parse('${day}T07:00:00Z');
        final plan = container.read(planListProvider).single;
        final w = await repo.startPlanned(plan, plan.occasions.firstWhere((o) => o.scheduledDate == day), day);
        for (var i = 0; i < 3; i++) {
          clock.advance(const Duration(minutes: 3));
          await repo.recordSet(w, w.exercises[0].id, loadKg: _target, reps: 8);
        }
        for (var i = 0; i < 2; i++) {
          clock.advance(const Duration(minutes: 3));
          await repo.recordSet(w, w.exercises[1].id, loadKg: 40, reps: 9);
        }
        await repo.finish(w);
      }
      await container.read(progressionRepositoryProvider).setIncrement('bench-press', loadInputToKg(5, LoadUnit.lb));
      clock.now = DateTime.utc(2026, 10, 12, 15);
    }());
    await settle();
    return (container, db, run, settle);
  }

  testWidgets('preview and Keep current save no target; one confirmation saves once; typed entry, selection and sets survive; only Record set records', (tester) async {
    final (container, db, run, settle) = await setUpApp(tester);
    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await settle();
    }

    Future<List<Cmd>> commands() => run(db.select(db.commands).get());
    double? planTarget() => container.read(planListProvider).single.workouts.single.exercises.first.targetLoadKg;
    TextEditingController field(String key) => tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField))).controller!;

    // --- The preview of today's Push shows the suggestion: 190 → 195 lb, with the facts behind it.
    final occasion = container.read(planListProvider).single.occasions.firstWhere((o) => o.scheduledDate == _today);
    container.read(shellProvider.notifier).openWorkout(WorkoutFocus.preview(_pid, occasion.id));
    await tap('nav-train');
    expect(find.byKey(const Key('next-time')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('next-time-proposed'))).data, '195 lb');
    expect(find.textContaining('all 3 sets of Bench press at 190 lb with 8 or more reps'), findsOneWidget);
    final before = (await commands()).length;

    // --- Review, then Keep current target: nothing is queued, the plan keeps 190 lb, and the suggestion is not shown again.
    await tap('next-time-review');
    expect(find.text('Use 195 lb from next session'), findsOneWidget);
    expect(find.textContaining('Applies from the next time you start Push, until you change it.'), findsOneWidget);
    await tap('review-keep');
    expect((await commands()).length, before);
    expect(planTarget(), closeTo(_target, 1e-9));
    expect(find.byKey(const Key('next-time')), findsNothing, reason: 'declined from the same facts: not offered again');

    // --- Start; select Bench press, type an entry, then review the next target from the recorder and confirm twice.
    await tap('preview-start');
    final id = container.read(workoutListProvider).firstWhere((w) => w.isOpen).id;
    expect(tester.widget<Text>(find.byKey(const Key('workout-target-load'))).data, '190 lb');
    await tester.enterText(find.descendant(of: find.byKey(const Key('set-load')), matching: find.byType(TextField)), '200');
    await settle();
    final selected = WorkoutRuntime(jsonDecode((await run(container.read(syncProvider).get('one', Kinds.runtime, id)))!.body) as Json).selectedExerciseId;
    await tap('workout-next-target-review');
    expect(find.text('Use 195 lb from next session'), findsOneWidget, reason: 'opened from the recorder, the suggestion is still there to review');
    await tester.tap(find.byKey(const Key('review-confirm')));
    await tester.tap(find.byKey(const Key('review-confirm')), warnIfMissed: false);
    await settle();
    expect((await commands()).where((c) => c.kind == 'plan.revise'), hasLength(1), reason: 'a double tap saves once');
    expect(find.byKey(const Key('review-accepted')), findsOneWidget);
    expect(find.textContaining('Restore previous target (190 lb)'), findsOneWidget);
    expect(formatLoad(planTarget(), LoadUnit.lb), '195 lb');
    await tap('review-done');

    // --- Back in the recorder: same workout, same exercise, the typed entry, no set, today's target still 190 lb.
    expect(container.read(shellProvider).workout, WorkoutFocus.session(id));
    expect(WorkoutRuntime(jsonDecode((await run(container.read(syncProvider).get('one', Kinds.runtime, id)))!.body) as Json).selectedExerciseId, selected);
    expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('workout-exercise-panel')), matching: find.text('Bench press'))).data, 'Bench press');
    expect(field('set-load').text, '200');
    expect(await run(container.read(workoutRepositoryProvider).sets(id)), isEmpty, reason: 'reviewing and accepting record nothing');
    expect(tester.widget<Text>(find.byKey(const Key('workout-target-load'))).data, '190 lb', reason: 'the active workout keeps the target frozen into it');
    expect(tester.widget<Text>(find.byKey(const Key('workout-next-target'))).data, 'Next target · 195 lb');

    // --- Record set is the one action that records.
    await tap('complete-set');
    expect(await run(container.read(workoutRepositoryProvider).sets(id)), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('narrow screen with large text: the Next time card and the review fit with no overflow', (tester) async {
    final (container, _, _, settle) = await setUpApp(tester, size: const Size(320, 700), textScale: 2);
    final occasion = container.read(planListProvider).single.occasions.firstWhere((o) => o.scheduledDate == _today);
    container.read(shellProvider.notifier).openWorkout(WorkoutFocus.preview(_pid, occasion.id));
    await tester.tap(find.byKey(const Key('nav-train')));
    await settle();
    expect(find.byKey(const Key('next-time')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('next-time-review')), 200, scrollable: find.byType(Scrollable).first);
    await settle();
    await tester.tap(find.byKey(const Key('next-time-review')));
    await settle();
    await tester.ensureVisible(find.byKey(const Key('review-confirm')));
    await settle();
    expect(find.byKey(const Key('review-confirm')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
