import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/progress/recap_screen.dart';
import 'package:gohard_rebuild/features/progress/trend_screens.dart';
import 'package:gohard_rebuild/features/workout/workout_detail_screen.dart';

import 'ui_support.dart';

/// Train › Progress, its goal sheet, an exercise trend and a weekly recap over fixture records (docs/PROGRESS.md).
/// None of these numbers ships in the app.

const _day = '2026-10-21'; // Wednesday; last week is Oct 12 – 18

Json _workout(String id, String day, String time, List<(int reps, num kg)> sets, {String name = 'Bench press', String key = 'bench-press'}) => {
      'id': id, 'kind': 'manual', 'title': 'Upper $id', 'dayKey': day, 'startedAtUtc': '${day}T$time:00Z', 'finishedAtUtc': '${day}T$time:40Z', 'activeDurationSeconds': 2400,
      'outcome': 'manual_recorded', 'performedSets': sets.length, 'performedExercises': 1, 'qualifiedOccasion': false, 'isDeleted': false,
      'exercises': [{'id': '$id-e', 'ordinal': 1, 'name': name, 'catalogKey': key, 'isDeleted': false}],
    };
List<Json> _sets(Json w, List<(int reps, num kg)> sets) => [
      for (final (i, (reps, kg)) in sets.indexed)
        {'id': '${w['id']}-s$i', 'exerciseId': '${w['id']}-e', 'workoutId': w['id'], 'reps': reps, 'loadKg': kg, 'performedAtUtc': '${w['dayKey']}T${(w['startedAtUtc'] as String).substring(11, 16)}:0${i}Z', 'isDeleted': false},
    ];

final _plan = <(String, String, String, List<(int, num)>)>[
  ('older', '2026-10-06', '17:00', [(8, 80)]),
  ('mon', '2026-10-12', '17:00', [(8, 88.5), (5, 95)]),
  ('thu', '2026-10-15', '17:00', [(8, 93)]),
  ('now', '2026-10-19', '17:00', [(8, 95)]),
  ('am', '2026-10-20', '07:00', [(8, 95), (5, 102.5)]),
  ('pm', '2026-10-20', '18:00', [(8, 97.5)]),
];
final _workouts = [for (final (id, day, time, sets) in _plan) _workout(id, day, time, sets)];
final _allSets = [for (final (i, w) in _workouts.indexed) ..._sets(w, _plan[i].$4)];
final _runs = [
  {'id': 'walk1', 'dayKey': '2026-10-13', 'startedAtUtc': '2026-10-13T06:30:00Z', 'finishedAtUtc': '2026-10-13T07:10:00Z', 'activeDurationSeconds': 2280, 'distanceMeters': 3100, 'isDeleted': false, 'activityType': 'walk', 'title': 'Morning walk'},
];

class _Net implements Transport {
  final paths = <String>[];
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    paths.add(path);
    return const ApiResponse(503, null);
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<List<Override>> _overrides(WidgetTester tester, {_Net? net, bool live = false, List<Json> goals = const [], AppearanceStore? appearance}) async => [
      ...(await tester.runAsync(() => overridesFor(day: _day, workouts: _workouts, sets: _allSets, runs: _runs, weeklyGoals: goals, liveGoals: live, appearance: appearance)))!,
      transportProvider.overrideWithValue(net ?? _Net()),
      if (live) ..._db(),
    ];

/// A real local database for the goals; nothing leaves it (the engine is blocked).
List<Override> _db() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDb(NativeDatabase.memory());
  addTearDown(db.close);
  return [
    dbProvider.overrideWithValue(db),
    syncProvider.overrideWith((ref) {
      final engine = SyncEngine(db, Api(_Net(), ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
      ref.onDispose(engine.dispose);
      return engine;
    }),
  ];
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  testWidgets('choose goals, see the counts, edit this week\'s goal: last week keeps its own, an older week had none, nothing is asked of the AI', (tester) async {
    final net = _Net();
    final container = await pumpApp(tester, await _overrides(tester, net: net, live: true), size: const Size(390, 1600));
    // Week A's goal was chosen last week (saved on this phone).
    await tester.runAsync(() => container.read(goalRepositoryProvider).set('2026-10-12', workouts: 3, runWalk: 2));
    await tester.pumpAndSettle();

    await _tap(tester, 'nav-train');
    await _tap(tester, 'train-progress');
    expect(find.text('Oct 19 – 25'), findsOneWidget);
    expect(find.bySemanticsLabel('Workouts: 3 of 3 this week.'), findsOneWidget, reason: 'two sessions on one day are two workouts');
    expect(find.bySemanticsLabel('Run / Walk: 0 of 2 this week.'), findsOneWidget, reason: 'inherited from last week');
    expect(find.text('Edit goals'), findsOneWidget);

    await _tap(tester, 'goals-edit');
    expect(find.text('These are weekly activity targets. Your training plan stays the same.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('goal-workouts')), '22');
    await tester.enterText(find.byKey(const Key('goal-runwalk')), '');
    await _tap(tester, 'goals-save');
    expect(find.text('Use a whole number from 1 to 21, or leave it blank.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('goal-workouts')), '4');
    await _tap(tester, 'goals-save');
    expect(find.byKey(const Key('goals-save')), findsNothing, reason: 'saved and closed');
    expect(find.bySemanticsLabel('Workouts: 3 of 4 this week.'), findsOneWidget);
    expect(find.bySemanticsLabel('Run / Walk: 0 runs or walks recorded this week, no target.'), findsOneWidget);
    expect(find.byKey(const Key('goals-pending')), findsOneWidget, reason: 'honest: on this phone, not yet on the account');
    final saved = (await tester.runAsync(() => container.read(syncProvider).list('one', Kinds.weeklyGoal)))!;
    expect(saved.map((r) => r.id).toSet(), {'2026-10-12', '2026-10-19'}, reason: 'this week\'s record; last week\'s untouched');

    await _tap(tester, 'progress-recap');
    expect(find.text('Last week · Oct 12 – 18'), findsOneWidget);
    expect(find.bySemanticsLabel('Workouts: 2 of 3.'), findsOneWidget, reason: 'the goal that applied then, not today\'s 4');
    expect(find.bySemanticsLabel('Run / Walk: 1 of 2.'), findsOneWidget);
    expect(find.text('88.5 kg × 8 → 93 kg × 8'), findsOneWidget);
    expect(find.textContaining('Walking distance'), findsOneWidget, reason: 'walks only');
    expect(find.text('3.10 km'), findsOneWidget);
    await _tap(tester, 'recap-previous');
    expect(find.text('Week of Oct 5 – 11'), findsOneWidget);
    expect(find.byKey(const Key('recap-no-goals')), findsOneWidget);
    expect(find.text('No goals were set for this week.'), findsOneWidget);
    expect(find.byKey(const Key('recap-previous')).hitTestable(), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('recap-previous'))).onPressed, isNull, reason: 'nothing earlier was recorded');
    await _tap(tester, 'recap-next');
    await _tap(tester, 'recap-workout-thu');
    expect(find.byType(WorkoutDetailScreen), findsOneWidget);
    expect(net.paths.where((p) => p.contains('coach')), isEmpty, reason: 'viewing progress, a recap and the coach\'s facts sends nothing');
  });

  testWidgets('the trend follows the chosen reps and range; chart, change and sessions agree; a point opens its real session', (tester) async {
    await pumpApp(tester, await _overrides(tester), home: const ExerciseTrendScreen(exerciseKey: 'bench-press'), size: const Size(390, 1800));
    expect(_text(tester, 'trend-metric'), 'Top set load · 8 reps', reason: 'the reps of the most recent loaded set');
    expect(_text(tester, 'trend-latest'), '97.5 kg × 8');
    // 4 weeks: Oct 12 … Oct 20 (pm). Two sessions on Oct 20 stay two rows, told apart by their time.
    for (final id in ['mon', 'thu', 'now', 'am', 'pm']) {
      expect(find.byKey(Key('trend-session-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const Key('trend-session-older')), findsOneWidget, reason: 'Oct 6 is inside the last 28 days');
    expect(find.textContaining('Tue, Oct 20 · '), findsNWidgets(3), reason: 'two rows and the hero, with times');
    expect(find.descendant(of: find.byKey(const Key('trend-change')), matching: find.text('+17.5 kg')), findsOneWidget, reason: '80 → 97.5');

    await _tap(tester, 'trend-reps-5');
    expect(_text(tester, 'trend-metric'), 'Top set load · 5 reps');
    expect(find.byKey(const Key('trend-session-mon')), findsOneWidget);
    expect(find.byKey(const Key('trend-session-am')), findsOneWidget);
    expect(find.byKey(const Key('trend-session-thu')), findsNothing, reason: 'no 5-rep set that day: no point, nothing interpolated');
    expect(find.text('+7.5 kg'), findsOneWidget);

    await _tap(tester, 'trend-reps-8');
    await _tap(tester, 'trend-range-weeks4');
    final chart = find.byKey(const Key('trend-chart'));
    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    // The rightmost point is the latest session (pm): tap it on the chart.
    final box = tester.getRect(chart);
    await tester.tapAt(Offset(box.right - 10, box.top + 12));
    await tester.pumpAndSettle();
    expect(tester.widget<WorkoutDetailScreen>(find.byType(WorkoutDetailScreen)).workoutId, 'pm');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'trend-session-thu');
    expect(tester.widget<WorkoutDetailScreen>(find.byType(WorkoutDetailScreen)).workoutId, 'thu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 px at twice the text size: Progress, the goal sheet, a trend and a recap fit and scroll', (tester) async {
    final goals = [{'weekStart': '2026-10-12', 'workoutsTarget': 3, 'runWalkTarget': 2}];
    final overrides = await _overrides(tester, goals: goals);
    await pumpApp(tester, overrides, size: const Size(320, 640), textScale: 2);
    await _tap(tester, 'nav-train');
    await _tap(tester, 'train-progress');
    expect(tester.takeException(), isNull, reason: 'progress');
    await _tap(tester, 'goals-edit');
    expect(tester.takeException(), isNull, reason: 'goal sheet');
    for (final (name, page) in <(String, Widget)>[
      ('trend', const ExerciseTrendScreen(exerciseKey: 'bench-press')), ('list', const ExerciseListScreen()), ('recap', const WeeklyRecapScreen(monday: '2026-10-12')),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, overrides, home: page, size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull, reason: name);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name, further down');
    }
  });

  for (final (accent, mode) in [(Accent.green, ThemeMode.dark), (Accent.pink, ThemeMode.light), (Accent.blue, ThemeMode.light)]) {
    testWidgets('${accent.name} ${mode.name}: the trend and the recap meet contrast, target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final store = AppearanceStore(MemorySecretStore())
        ..accent = accent
        ..mode = mode;
      final overrides = await _overrides(tester, goals: [{'weekStart': '2026-10-12', 'workoutsTarget': 3, 'runWalkTarget': null}], appearance: store);
      for (final page in [const ExerciseTrendScreen(exerciseKey: 'bench-press'), const WeeklyRecapScreen(monday: '2026-10-12')]) {
        await pumpApp(tester, overrides, home: page, size: const Size(390, 2400));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        if (page is WeeklyRecapScreen) {
          // The panel's figures are excluded from semantics, so the guideline above cannot see them: they take the panel's ink.
          final figure = find.descendant(of: find.byKey(const Key('recap-workouts')), matching: find.byType(Text)).first;
          expect(tester.widget<Text>(figure).style!.color, GoColors.panelOf(GoColors.of(accent, mode == ThemeMode.dark ? Brightness.dark : Brightness.light)).text);
        }
        await tester.pumpWidget(const SizedBox());
      }
      handle.dispose();
    });
  }
}
