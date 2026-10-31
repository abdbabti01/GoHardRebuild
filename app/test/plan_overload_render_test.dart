import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/plus/entitlement.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/progression.dart';

import 'support.dart';
import 'ui_support.dart';

/// Renders of the plan library and Suggested today (docs/PLAN_LIBRARY_OVERLOAD.md), light and dark, for review:
///
///   flutter test test/plan_overload_render_test.dart --dart-define=GOHARD_RENDER=true
///
/// Without the flag it does nothing. FIXTURES, not phone captures: a daily "Push" plan with bench press at 190 lb
/// (3 × 6–8) recorded twice at the top, and overhead press (2 × 8–10, no weight target) recorded at 40 kg × 9, 9.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _out = '../docs/evidence/plan-library';
const _pid = '7a1c2d3e-4a5b-4c6d-8e7f-90a1b2c3d4e5', _saved = '0b9d7c1e-2f3a-4b5c-9d6e-7f8091a2b3c4', _paused = '5a4b3c2d-1e0f-4a9b-8c7d-6e5f4a3b2c1d';
const _today = '2026-10-12';
final _target = ProgressionRules.round3(loadInputToKg(190, LoadUnit.lb));
final _inc = {'exerciseKey': 'bench-press', 'incrementKg': loadInputToKg(5, LoadUnit.lb), 'revision': 1};

final _workouts = [
  {'id': 'push', 'name': 'Push', 'notes': null, 'exercises': [
    {'occurrenceKey': 'e1', 'catalogKey': 'bench-press', 'name': 'Bench press', 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 6, 'targetRepsMax': 8, 'targetDurationSeconds': null, 'restSeconds': 90, 'targetLoadKg': _target},
    {'occurrenceKey': 'e2', 'catalogKey': 'overhead-press', 'name': 'Overhead press', 'isTimed': false, 'targetSets': 2, 'targetRepsMin': 8, 'targetRepsMax': 10, 'targetDurationSeconds': null, 'restSeconds': 90},
  ]},
];

Json _plan(String id, String title, String lifecycle, {String start = '2026-10-10'}) {
  final schedule = {'mode': 'fixed', 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0, 'pattern': [for (var d = 1; d <= 7; d++) {'weekday': d, 'workoutId': 'push'}]};
  return {'id': id, 'title': title, 'lifecycle': lifecycle, 'pausedOn': lifecycle == 'paused' ? '2026-10-08' : null, 'startDate': start, 'blockWeeks': 2, 'minRecoveryDays': 0,
    'isOngoing': false, 'revision': 3, 'timeBudgetMinutes': 45, 'templateId': null, 'workouts': _workouts, 'schedule': schedule, 'occasions': PlanRules.generate(id, start, 2, schedule, _workouts)};
}

(List<Json>, List<Json>) _history() {
  final plan = Plan(_plan(_pid, 'Daily push', 'active'));
  final workouts = <Json>[], sets = <Json>[];
  for (final day in ['2026-10-10', '2026-10-11', _today]) {
    final o = plan.occasions.firstWhere((x) => x.scheduledDate == day);
    final id = 'w-$day', open = day == _today;
    workouts.add({'id': id, 'planId': _pid, 'occasionId': o.id, 'kind': 'planned', 'title': 'Push', 'dayKey': day, 'startedAtUtc': '${day}T15:00:00Z',
      'finishedAtUtc': open ? null : '${day}T16:00:00Z', 'outcome': open ? null : 'full', 'isDeleted': false,
      'exercises': [for (final (i, p) in o.prescription.indexed) {...p.j, 'id': '$id-$i', 'ordinal': i + 1, 'isPrescribed': true, 'isDeleted': false}]});
    if (open) continue;
    for (var n = 0; n < 3; n++) {
      sets.add({'id': '$id-0-$n', 'exerciseId': '$id-0', 'workoutId': id, 'reps': 8, 'loadKg': _target, 'performedAtUtc': '${day}T15:1$n:00Z', 'isDeleted': false});
    }
    for (var n = 0; n < 2; n++) {
      sets.add({'id': '$id-1-$n', 'exerciseId': '$id-1', 'workoutId': id, 'reps': 9, 'loadKg': 40.0, 'performedAtUtc': '${day}T15:3$n:00Z', 'isDeleted': false});
    }
  }
  return (workouts, sets);
}

Future<void> _fonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await inter.load();
  await (FontLoader(serif)..addFont(File('assets/fonts/DMSerifDisplay-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  for (var i = 0; i < 30 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 1.5)))!;
  await tester.runAsync(() async {
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  if (!_enabled) {
    test('plan library renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(_fonts);

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    final m = mode.name;
    AppearanceStore store() => AppearanceStore(MemorySecretStore())..mode = mode;

    testWidgets('$m: Train › Plan library and a saved plan', (tester) async {
      final plans = [_plan(_pid, 'Daily push', 'active'), _plan(_saved, 'Upper / Lower', 'draft', start: '2026-10-19'), {..._plan(_paused, 'Old rotation', 'paused'), 'title': 'Old rotation'}];
      final overrides = (await tester.runAsync(() => overridesFor(day: _today, plans: plans, primaryPlanId: _pid, appearance: store())))!;
      await pumpApp(tester, [...overrides, plusProvider.overrideWithValue(plusPreview)], size: const Size(390, 1400), insets: phoneInsets);
      await _tap(tester, 'nav-train');
      await _tap(tester, 'train-plan');
      await tester.ensureVisible(find.byKey(const Key('library-create')));
      await tester.pumpAndSettle();
      await _shot(tester, 'library-$m');
      await _tap(tester, 'saved-plan-$_saved');
      await _shot(tester, 'saved-plan-$m');
      expect(tester.takeException(), isNull);
    });

    for (final increment in [true, false]) {
      testWidgets('$m: the recorder with Suggested today (weight${increment ? '' : ' without an increment'}, reps, kept aim)', (tester) async {
      final (workouts, sets) = _history();
      final overrides = (await tester.runAsync(() => overridesFor(day: _today, plans: [_plan(_pid, 'Daily push', 'active')], primaryPlanId: _pid, workouts: workouts, sets: sets,
          profile: {'loadUnit': 'lb'}, appearance: store())))!;
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final c = await pumpApp(tester, [...overrides, dbProvider.overrideWithValue(db),
        syncProvider.overrideWith((ref) {
          final engine = SyncEngine(db, Api(FakeServer()..offline = true, ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
          ref.onDispose(engine.dispose);
          return engine;
        }),
        plusProvider.overrideWithValue(plusPreview),
        if (increment) incrementsProvider.overrideWith((ref) => Stream.value({'bench-press': stored(ExerciseIncrement(_inc), Kinds.exerciseIncrement, 'bench-press', _inc)})),
      ], size: const Size(390, 1700), insets: phoneInsets);
      c.read(shellProvider.notifier).openWorkout(WorkoutFocus.session('w-$_today'));
      await _tap(tester, 'nav-train');
      await tester.ensureVisible(find.byKey(const Key('suggested-today')));
      await tester.pumpAndSettle();
      await _shot(tester, increment ? 'recorder-weight-$m' : 'recorder-increment-$m');
      if (!increment) return;
      await _tap(tester, 'next-exercise');
      await tester.ensureVisible(find.byKey(const Key('suggested-today')));
      await tester.pumpAndSettle();
      await _shot(tester, 'recorder-reps-$m');
      await _tap(tester, 'today-aim');
      await _shot(tester, 'recorder-aim-kept-$m');
      expect(tester.takeException(), isNull);
    });
    }
  }
}
