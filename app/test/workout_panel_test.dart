import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/progress.dart';
import 'package:gohard_rebuild/features/workout/result_rules.dart';
import 'package:gohard_rebuild/features/workout/workout_screen.dart';

import 'support.dart';
import 'ui_support.dart';
import 'package:gohard_rebuild/core/language.dart';

// The one workout panel in Train › Workouts (docs/DESIGN.md › Workout panel): Details shows a planned workout without
// creating anything, Start makes one workout and records into it beside last time, and leaving or switching keeps
// the typed entry and the rest deadline.

const _day = '2026-10-12'; // a Monday
const _pid = '6f1c2d3e-4a5b-4c6d-8e7f-90a1b2c3d4e5';

Json _rx(String workout, int i, String name, {bool timed = false}) => {
      'occurrenceKey': '$workout-e$i', 'catalogKey': name.toLowerCase().replaceAll(' ', '-'), 'name': name, 'isTimed': timed,
      'targetSets': 3, 'targetRepsMin': timed ? null : 8, 'targetRepsMax': timed ? null : 10, 'targetDurationSeconds': timed ? 45 : null, 'restSeconds': 90,
    };

Json _plan() {
  final workouts = [
    {'id': 'push', 'name': 'Push', 'notes': null, 'exercises': [_rx('push', 1, 'Bench press'), _rx('push', 2, 'Overhead press'), _rx('push', 3, 'Plank', timed: true)]},
  ];
  final schedule = {'mode': 'fixed', 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0, 'pattern': [for (var d = 1; d <= 7; d++) {'weekday': d, 'workoutId': 'push'}]};
  return {
    'id': _pid, 'title': 'Daily push', 'lifecycle': 'active', 'pausedOn': null, 'startDate': _day, 'blockWeeks': 2, 'minRecoveryDays': 0, 'isOngoing': false,
    'timeBudgetMinutes': 45, 'templateId': null, 'workouts': workouts, 'schedule': schedule, 'occasions': PlanRules.generate(_pid, _day, 2, schedule, workouts),
  };
}

CatalogExercise _ex(String name, {bool timed = false}) => CatalogExercise({'key': name.toLowerCase().replaceAll(' ', '-'), 'name': name, 'category': 'Chest', 'equipment': 'Barbell', 'isTimed': timed});

// ------------------------------------------------------------------ the history policy

Workout _w(String id, String startedAt, List<(String id, String? key)> exercises, {String outcome = WorkoutResultRules.manualRecorded}) => Workout({
      'id': id, 'kind': 'manual', 'title': 'W $id', 'dayKey': startedAt.substring(0, 10), 'startedAtUtc': startedAt, 'finishedAtUtc': startedAt, 'outcome': outcome, 'isDeleted': false,
      'exercises': [for (final (i, e) in exercises.indexed) {'id': e.$1, 'ordinal': i + 1, 'name': e.$2 ?? 'Free text', 'catalogKey': e.$2, 'isDeleted': false}],
    });
WorkoutSet _s(String id, String exerciseId, String at, {double? kg, int? reps, int? seconds}) =>
    WorkoutSet({'id': id, 'exerciseId': exerciseId, 'workoutId': 'x', 'loadKg': kg, 'reps': reps, 'durationSeconds': seconds, 'performedAtUtc': at, 'isDeleted': false});

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('last time: same identity and occurrence, latest earlier session by time (two on one day), sets in recorded order, nothing truncated or guessed', () {
    final workouts = [
      _w('a', '2026-10-09T07:00:00Z', [('a1', 'bench-press'), ('a2', 'bench-press'), ('a3', 'custom:mine'), ('a4', null)]),
      // Later the same day: this is last time, not the morning session.
      _w('b', '2026-10-09T18:00:00Z', [('b1', 'bench-press'), ('b2', 'custom:mine')]),
      _w('c', '2026-10-10T07:00:00Z', [('c1', 'bench-press')], outcome: WorkoutResultRules.noData), // gives no training credit
      _w('d', '2026-10-13T07:00:00Z', [('d1', 'bench-press')]), // after the anchor
      _w('e', '2026-10-08T07:00:00Z', [('e1', 'dumbbell-bench-press')]), // a different variant is never mixed in
    ];
    final sets = [
      _s('s1', 'a1', '2026-10-09T07:05:00Z', kg: 80, reps: 5),
      _s('s3', 'a2', '2026-10-09T07:20:00Z', kg: 60, reps: 12),
      _s('s4', 'a3', '2026-10-09T07:30:00Z', reps: 20),
      _s('s5', 'a4', '2026-10-09T07:40:00Z', reps: 20),
      // Recorded out of strength order and listed out of time order: shown in the order recorded, not heaviest first.
      _s('s7', 'b1', '2026-10-09T18:10:00Z', kg: 100, reps: 3),
      _s('s6', 'b1', '2026-10-09T18:05:00Z', kg: 90, reps: 5),
      _s('s8', 'b1', '2026-10-09T18:15:00Z', kg: 70, reps: 8),
      _s('s9', 'b1', '2026-10-09T18:20:00Z', kg: 70, reps: 8),
      _s('s10', 'c1', '2026-10-10T07:05:00Z', kg: 200, reps: 1),
      _s('s11', 'd1', '2026-10-13T07:05:00Z', kg: 200, reps: 1),
      _s('s12', 'e1', '2026-10-08T07:05:00Z', kg: 30, reps: 10),
    ];
    final anchor = DateTime.utc(2026, 10, 12, 15);
    List<PreviousPerformance> h(String key, int ordinal) => exerciseHistory(catalogKey: key, ordinal: ordinal, beforeUtc: anchor, workouts: workouts, sets: sets);

    final first = h('bench-press', 0);
    expect([for (final p in first) p.workout.id], ['b', 'a'], reason: 'newest first by start time; no-credit and later sessions excluded');
    expect([for (final s in first.first.sets) s.id], ['s6', 's7', 's8', 's9'], reason: 'every set, in the order recorded');
    // The second bench press of a workout has only its own history; session b had no second one.
    expect([for (final p in h('bench-press', 1)) [for (final s in p.sets) s.id]], [['s3']]);
    expect([for (final p in h('custom:mine', 0)) p.workout.id], ['a'], reason: 'a private custom identity counts; b2 has no sets, so it is not last time');
    expect(exerciseHistory(catalogKey: null, ordinal: 0, beforeUtc: anchor, workouts: workouts, sets: sets), isEmpty, reason: 'free text is never matched by name');
    expect(occurrenceOf(['bench-press', 'squat', 'bench-press'], 2), 1);

    // The recorder's anchor is its own start, and its own workout is never its history.
    final current = _w('now', '2026-10-09T12:00:00Z', [('n1', 'bench-press')], outcome: '');
    expect(previousPerformance(current, current.exercises.first, [...workouts, current], sets)!.workout.id, 'a');
  });

  testWidgets('Last time says loading, unreadable, no identity and no history apart; timed and bodyweight sets keep their own words', (tester) async {
    Future<void> show(LastTime w) => tester.pumpWidget(MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, theme: goTheme(Accent.values.first, Brightness.light), home: Scaffold(body: SingleChildScrollView(child: w))));
    String? empty() => tester.widget<Text>(find.byKey(const Key('last-time-empty'))).data;
    await show(LastTime(history: const [], status: HistoryStatus.loading, unit: LoadUnit.kg, onAll: () {}));
    expect(empty(), 'Reading your previous sessions…');
    await show(LastTime(history: const [], status: HistoryStatus.unavailable, unit: LoadUnit.kg, onAll: () {}));
    expect(empty(), contains('could not be read'));
    await show(LastTime(history: const [], status: HistoryStatus.noIdentity, unit: LoadUnit.kg, onAll: () {}));
    expect(empty(), contains('nothing is matched by name'));
    await show(LastTime(history: const [], status: HistoryStatus.ready, unit: LoadUnit.kg, nextIndex: 0, rows: 3, onAll: () {}));
    expect(empty(), 'No previous session recorded.');
    expect(find.text('—'), findsNWidgets(3), reason: 'no previous set is implied for any row');
    expect(find.byKey(const Key('all-sessions')), findsNothing);

    final past = PreviousPerformance(_w('a', '2026-10-09T07:00:00Z', [('a1', 'plank')]), [_s('t1', 'a1', '2026-10-09T07:05:00Z', seconds: 45), _s('t2', 'a1', '2026-10-09T07:07:00Z', reps: 12)]);
    await show(LastTime(history: [past], status: HistoryStatus.ready, unit: LoadUnit.kg, nextIndex: 0, rows: 1, onAll: () {}));
    expect(find.text('Last time · Fri, Oct 9'), findsOneWidget);
    expect(find.text('45 s'), findsOneWidget, reason: 'a timed set, with no invented weight');
    expect(find.text('Bodyweight × 12'), findsOneWidget);
    expect(find.text('Not recorded yet'), findsOneWidget, reason: 'the extra previous set stays visible, with no fabricated comparison');
  });

  testWidgets('Details shows the preview and creates nothing; one Start under rapid taps; Use last values only fills; leaving, history and tabs keep the entry and rest', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 10, 9, 7));
    final container = await pumpApp(
      tester,
      [
        ...(await tester.runAsync(() => overridesFor(day: _day, plans: [_plan()], primaryPlanId: _pid, profile: {'loadUnit': 'lb'}, liveWorkouts: true)))!,
        dbProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        syncProvider.overrideWith((ref) {
          final engine = SyncEngine(db, Api(FakeServer()..offline = true, ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
          ref.onDispose(engine.dispose);
          return engine;
        }),
      ],
      size: const Size(390, 2600), settle: false,
    );
    // Database work runs in the test's own zone, moved along by frames: a real-time call would wait on queries the
    // widgets started in it.
    Future<T> run<T>(Future<T> work) async {
      T? out;
      Object? failed;
      var done = false;
      work.then<void>((v) {
        out = v;
      }, onError: (Object e) {
        failed = e;
      }).whenComplete(() => done = true);
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      if (failed != null) throw failed!;
      expect(done, isTrue, reason: 'the local database answered');
      return out as T;
    }

    final repo = container.read(workoutRepositoryProvider);
    // Two earlier sessions, recorded through the real repository: Oct 5 and (last time) Oct 9.
    await run(() async {
      for (final (day, loads) in [(5, [50.0]), (9, [57.5, 60.0])]) {
        clock.now = DateTime.utc(2026, 10, day, 7);
        final w = await repo.startManual('Earlier push', [_ex('Bench press'), _ex('Overhead press')], '2026-10-0$day');
        for (final kg in loads) {
          clock.advance(const Duration(minutes: 3));
          await repo.recordSet(w, w.exercises.first.id, loadKg: kg, reps: 8);
        }
        await repo.finish(w);
      }
      clock.now = DateTime.utc(2026, 10, 12, 15);
    }());
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await settle();
    }

    TextEditingController field(String key) => tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField))).controller!;
    Future<List<Workout>> workouts() async => [for (final w in container.read(workoutListProvider)) if (w.isOpen) w];
    Future<int> commands() async => (await run(db.select(db.commands).get())).length;
    await settle();

    // --- Today › Details: Train › Workouts shows the preview; no workout, command or timer is created.
    final before = await commands();
    await tap('today-details');
    expect(container.read(shellProvider).tab, 1);
    expect(container.read(shellProvider).trainView, TrainView.workouts);
    expect(find.byKey(const Key('workout-preview')), findsOneWidget);
    expect(await workouts(), isEmpty);
    expect(await commands(), before);
    final lb57 = formatLoad(57.5, LoadUnit.lb), lb60 = formatLoad(60, LoadUnit.lb);
    expect(find.text('Last time · Fri, Oct 9'), findsOneWidget, reason: 'the first exercise is open, with its last session');
    expect(find.text('$lb57 × 8'), findsOneWidget, reason: 'shown in the preferred unit');
    expect(find.text('$lb60 × 8'), findsOneWidget, reason: 'every previous set, in order');

    // --- Start: rapid taps make one workout, and the same panel records into it.
    await tester.ensureVisible(find.byKey(const Key('preview-start')));
    await tester.tap(find.byKey(const Key('preview-start')));
    await tester.tap(find.byKey(const Key('preview-start')), warnIfMissed: false);
    await settle();
    final open = await workouts();
    expect(open, hasLength(1));
    final id = open.single.id;
    expect(container.read(shellProvider).workout, WorkoutFocus.session(id));
    expect(find.byKey(const Key('complete-set')), findsOneWidget);

    // --- Use last values: asks before replacing what was typed, fills only the entry and records nothing.
    await tester.enterText(find.descendant(of: find.byKey(const Key('set-load')), matching: find.byType(TextField)), '70');
    await settle();
    await tap('use-last-values');
    expect(find.text('Replace what you typed?'), findsOneWidget);
    await tester.tap(find.text('Keep mine'));
    await settle();
    expect(field('set-load').text, '70');
    await tap('use-last-values');
    await tester.tap(find.widgetWithText(FilledButton, 'Use last values'));
    await settle();
    expect(field('set-load').text, formatLoadValue(57.5, LoadUnit.lb));
    expect(field('set-reps').text, '8');
    expect(await run(repo.sets(id)), isEmpty, reason: 'filling is not recording');
    expect(find.byKey(const Key('rest-clock')), findsNothing);

    // --- Record set: one set, in kilograms (not the pounds figure read as kilograms), marked recorded, rest started.
    await tap('complete-set');
    final recorded = await run(repo.sets(id));
    expect(recorded, hasLength(1));
    expect(recorded.single.loadKg, closeTo(57.5, 0.3));
    expect(find.descendant(of: find.byKey(const Key('compare-0-today')), matching: find.text('Recorded')), findsOneWidget);
    expect(find.byKey(const Key('rest-clock')), findsOneWidget);
    final restLeft = (await run(repo.runtime(id)))!.restDeadlineUtc;

    // --- An unsaved entry survives history, leaving the panel and switching tabs; the rest deadline is the same.
    await tester.enterText(find.descendant(of: find.byKey(const Key('set-load')), matching: find.byType(TextField)), '150');
    await settle();
    await tap('all-sessions');
    expect(find.byKey(const Key('history-session-0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('history-session-0'))).data, contains('October 9'), reason: 'newest first');
    expect(tester.widget<Text>(find.byKey(const Key('history-session-1'))).data, contains('October 5'));
    Navigator.of(tester.element(find.byKey(const Key('history-sheet')))).pop();
    await settle();
    expect(field('set-load').text, '150');

    await tap('nav-today');
    await tap('nav-train');
    expect(field('set-load').text, '150');
    await tap('workout-all');
    expect(find.byKey(Key('train-open-$id')), findsOneWidget, reason: 'All workouts finishes or removes nothing');
    await tap('train-details-$id');
    expect(field('set-load').text, '150', reason: 'the draft was saved as the panel closed and restored when it opened');
    expect(find.byKey(const Key('rest-clock')), findsOneWidget);
    expect((await run(repo.runtime(id)))!.restDeadlineUtc, restLeft);

    // --- Today's Resume: the same workout, never a second one.
    await tap('nav-today');
    await tap('today-resume');
    expect(container.read(shellProvider).workout, WorkoutFocus.session(id));
    expect(await workouts(), hasLength(1));
    expect(field('set-load').text, '150');
    await tester.pumpWidget(const SizedBox());
  });

  // Regression (iPhone report): with the target reached, Next exercise and the All movements rows did nothing, because
  // the switch's draft save wrote the old selection back over the new one.
  testWidgets('Next exercise and All movements switch exercise after the target is reached; drafts, sets, workout and rest stay', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 10, 12, 15));
    final container = await pumpApp(
      tester,
      [
        ...(await tester.runAsync(() => overridesFor(day: _day, plans: [_plan()], primaryPlanId: _pid, profile: {'loadUnit': 'lb'}, liveWorkouts: true)))!,
        dbProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        syncProvider.overrideWith((ref) {
          final engine = SyncEngine(db, Api(FakeServer()..offline = true, ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
          ref.onDispose(engine.dispose);
          return engine;
        }),
      ],
      size: const Size(390, 2600), settle: false,
    );
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<T> run<T>(Future<T> work) async {
      T? out;
      var done = false;
      work.then<void>((v) => out = v).whenComplete(() => done = true);
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      return out as T;
    }

    Future<void> tap(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await settle();
    }

    Finder input(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
    String text(String key) => tester.widget<TextField>(input(key)).controller!.text;
    void showing(String name) {
      expect(find.descendant(of: find.byKey(const Key('workout-exercise-panel')), matching: find.text(name)), findsOneWidget, reason: '$name is the selected exercise');
      expect(find.textContaining(RegExp('sets recorded · current')), findsOneWidget);
    }

    await settle();
    await tap('today-details');
    await tap('preview-start');
    final repo = container.read(workoutRepositoryProvider);
    final id = container.read(workoutListProvider).singleWhere((w) => w.isOpen).id;
    showing('Bench press');

    // The screenshot's state: three sets on the first exercise, the entry still holding the last values.
    await tester.enterText(input('set-load'), '45');
    await tester.enterText(input('set-reps'), '10');
    await settle();
    for (var i = 0; i < 3; i++) {
      await tap('complete-set');
    }
    expect(find.text('Target set count recorded. Add another set, or move on when you are ready.'), findsOneWidget);
    final before = (await run(repo.runtime(id)))!;

    await tap('next-exercise');
    showing('Overhead press');
    expect(find.byKey(const Key('set-row-0')), findsNothing, reason: 'Bench press sets are not shown under Overhead press');
    expect((await run(repo.runtime(id)))!.selectedExerciseId, isNot(before.selectedExerciseId), reason: 'the stored selection moved too');

    // Directly to the third movement, then type a draft there.
    await tap('exercise-row-3');
    showing('Plank');
    expect(find.byKey(const Key('set-duration')), findsOneWidget);
    await tester.enterText(input('set-duration'), '40');
    await settle();

    // Back to the first: its three sets and its entry; then Plank again: its typed draft.
    await tap('exercise-row-1');
    showing('Bench press');
    expect(find.byKey(const Key('set-row-2')), findsOneWidget);
    expect(text('set-load'), '45');
    expect(text('set-reps'), '10');
    await tap('exercise-row-3');
    showing('Plank');
    expect(text('set-duration'), '40', reason: 'the typed draft stayed with its own exercise');
    expect(find.byKey(const Key('next-exercise')), findsNothing, reason: 'the last movement offers no Next that does nothing');

    // Rapid taps: the last one wins, and the earlier write's echo does not switch back.
    await tester.ensureVisible(find.byKey(const Key('exercise-row-1')));
    await tester.tap(find.byKey(const Key('exercise-row-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('exercise-row-2')));
    await settle();
    showing('Overhead press');

    // On a phone-sized screen scrolled to the end (as in the report), the last movement row is tappable above the
    // floating bar, and choosing it brings its panel into view.
    tester.view.physicalSize = const Size(390, 844);
    await settle();
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    list.jumpTo(list.maxScrollExtent);
    await settle();
    await tester.tap(find.byKey(const Key('exercise-row-3')));
    await settle();
    showing('Plank');
    final panelTop = tester.getTopLeft(find.byKey(const Key('workout-exercise-panel'))).dy;
    expect(panelTop, inInclusiveRange(0, 844 - 100), reason: 'the selected movement is on screen, not above it');
    tester.view.physicalSize = const Size(390, 2600);
    await settle();

    expect(await run(repo.sets(id)), hasLength(3), reason: 'switching records nothing');
    expect(container.read(workoutListProvider).where((w) => w.isOpen).map((w) => w.id), [id], reason: 'the same workout, never a second one');
    final after = (await run(repo.runtime(id)))!;
    expect(after.restDeadlineUtc, before.restDeadlineUtc, reason: 'selection leaves rest alone');
    expect(after.elapsedSeconds(clock.utcNow()), before.elapsedSeconds(clock.utcNow()), reason: 'and the workout clock');
    expect(after.isPaused, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
