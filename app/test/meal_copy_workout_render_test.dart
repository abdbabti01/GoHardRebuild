import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/clock.dart' show addDays;
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/plans/plan_rules.dart';
import 'package:gohard_rebuild/features/plus/entitlement.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/progression.dart';

import 'support.dart';
import 'ui_support.dart';

/// Before/after renders for docs/MEAL_COPY_WORKOUT_PANEL.md, light and dark, at one phone viewport (390 × 844 with a
/// notched phone's insets) and the same fixture state:
///
///   flutter test test/meal_copy_workout_render_test.dart --dart-define=GOHARD_RENDER=true --dart-define=GOHARD_RENDER_SET=after
///
/// It uses only keys that exist before and after the change, so the same file renders `main` (SET=before). FIXTURES,
/// not phone captures: yesterday's breakfast (2 eggs, egg whites, baguette), today's breakfast empty; a daily "Push"
/// plan with bench press at 190 lb (3 × 6–8) recorded twice at the top, today's workout open with a 5 lb increment.
const _enabled = bool.fromEnvironment('GOHARD_RENDER');
const _set = String.fromEnvironment('GOHARD_RENDER_SET', defaultValue: 'after');
const _out = '../docs/evidence/meal-copy-workout-panel/$_set';
const _pid = '7a1c2d3e-4a5b-4c6d-8e7f-90a1b2c3d4e5', _today = '2026-10-12';
final _target = ProgressionRules.round3(loadInputToKg(190, LoadUnit.lb));
final _inc = {'exerciseKey': 'bench-press', 'incrementKg': loadInputToKg(5, LoadUnit.lb), 'revision': 1};

final _egg = FoodItem({'source': 'usda', 'sourceId': 'egg', 'name': 'Egg', 'basis': FoodItem.per100g,
    'nutrients': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5}, 'servings': [{'label': '1 egg', 'grams': 50, 'milliliters': null}]});
final _whites = FoodItem({'source': 'usda', 'sourceId': 'whites', 'name': 'Egg whites', 'basis': FoodItem.per100g,
    'nutrients': {'calories': 52, 'protein': 10.9, 'carbs': 0.7, 'fat': 0.2}, 'servings': const []});
final _food = [
  {...foodEntry('y1', addDays(_today, -1), 'Breakfast', '2 eggs', '2 eggs (100 g)', calories: 143, protein: 12.6, carbs: 0.7, fat: 9.5), 'source': {'item': _egg.j, 'quantity': 2, 'unit': 'serving:0'}},
  {...foodEntry('y2', addDays(_today, -1), 'Breakfast', 'Egg whites', '100 g', calories: 52, protein: 10.9, carbs: 0.7, fat: 0.2), 'source': {'item': _whites.j, 'quantity': 100, 'unit': 'g'}},
  foodEntry('y3', addDays(_today, -1), 'Breakfast', 'Baguette', '1 slice', calories: 80, protein: 3, carbs: 15, fat: 1),
  foodEntry('t1', _today, 'Lunch', 'Chicken and rice', '1 plate', calories: 650, protein: 48, carbs: 70, fat: 16),
];

final _workouts = [
  {'id': 'push', 'name': 'Push', 'notes': null, 'exercises': [
    {'occurrenceKey': 'e1', 'catalogKey': 'bench-press', 'name': 'Bench press', 'isTimed': false, 'targetSets': 3, 'targetRepsMin': 6, 'targetRepsMax': 8, 'targetDurationSeconds': null, 'restSeconds': 90, 'targetLoadKg': _target},
    {'occurrenceKey': 'e2', 'catalogKey': 'overhead-press', 'name': 'Overhead press', 'isTimed': false, 'targetSets': 2, 'targetRepsMin': 8, 'targetRepsMax': 10, 'targetDurationSeconds': null, 'restSeconds': 90},
  ]},
];

Json _plan() {
  final schedule = {'mode': 'fixed', 'cycle': <String>[], 'trainingDays': <int>[], 'cycleAnchor': 0, 'pattern': [for (var d = 1; d <= 7; d++) {'weekday': d, 'workoutId': 'push'}]};
  return {'id': _pid, 'title': 'Daily push', 'lifecycle': 'active', 'pausedOn': null, 'startDate': '2026-10-10', 'blockWeeks': 2, 'minRecoveryDays': 0, 'isOngoing': false, 'revision': 3,
    'timeBudgetMinutes': 45, 'templateId': null, 'workouts': _workouts, 'schedule': schedule, 'occasions': PlanRules.generate(_pid, '2026-10-10', 2, schedule, _workouts)};
}

(List<Json>, List<Json>) _history() {
  final plan = Plan(_plan());
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
  }
  return (workouts, sets);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  for (var i = 0; i < 30 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot'))).toImage(pixelRatio: 2)))!;
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

/// [key]'s top at the top of the screen, under the status bar.
Future<void> _toTop(WidgetTester tester, String key) async {
  await Scrollable.ensureVisible(tester.element(find.byKey(Key(key))), alignment: 0.06);
  await tester.pumpAndSettle();
}

void main() {
  if (!_enabled) {
    test('meal copy and workout panel renders are skipped without GOHARD_RENDER', () {});
    return;
  }
  setUpAll(loadAppFonts);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final m = mode.name;
    AppearanceStore store() => AppearanceStore(MemorySecretStore())..mode = mode;

    testWidgets('$m: Eat with an empty breakfast after yesterday’s, and the copy review', (tester) async {
      await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _today, food: _food, appearance: store())))!, size: const Size(390, 844), insets: phoneInsets);
      await _tap(tester, 'nav-eat');
      await _toTop(tester, 'eat-add-breakfast');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 120)); // the meal's heading in view too
      await tester.pumpAndSettle();
      await _shot(tester, 'eat-breakfast-$m');
      if (find.byKey(const Key('eat-repeat-review-breakfast')).evaluate().isEmpty) return; // before: no shortcut
      await _tap(tester, 'eat-repeat-review-breakfast');
      await _shot(tester, 'copy-review-$m');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$m: the recorder’s selected exercise', (tester) async {
      final (workouts, sets) = _history();
      final overrides = (await tester.runAsync(() => overridesFor(day: _today, plans: [_plan()], primaryPlanId: _pid, workouts: workouts, sets: sets,
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
        incrementsProvider.overrideWith((ref) => Stream.value({'bench-press': stored(ExerciseIncrement(_inc), Kinds.exerciseIncrement, 'bench-press', _inc)})),
      ], size: const Size(390, 844), insets: phoneInsets);
      c.read(shellProvider.notifier).openWorkout(WorkoutFocus.session('w-$_today'));
      await _tap(tester, 'nav-train');
      await _toTop(tester, 'workout-exercise-panel');
      await _shot(tester, 'recorder-$m');
      expect(tester.takeException(), isNull);
      if (find.byKey(const Key('compare-toggle')).evaluate().isEmpty) return; // before: no compact panel
      await _tap(tester, 'compare-toggle');
      await _toTop(tester, 'last-time');
      await _shot(tester, 'recorder-compare-open-$m');
      await _tap(tester, 'compare-toggle');
      await _tap(tester, 'today-more');
      await _shot(tester, 'recorder-more-choices-$m');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320 px, twice the text: the copy review and the recorder (after only)', (tester) async {
    if (_set != 'after') return;
    await pumpApp(tester, (await tester.runAsync(() => overridesFor(day: _today, food: _food)))!, size: const Size(320, 900), textScale: 2, insets: phoneInsets);
    await _tap(tester, 'nav-eat');
    await _tap(tester, 'eat-repeat-review-breakfast');
    await _shot(tester, 'copy-review-320-2x');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    final (workouts, sets) = _history();
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final c = await pumpApp(tester, [
      ...(await tester.runAsync(() => overridesFor(day: _today, plans: [_plan()], primaryPlanId: _pid, workouts: workouts, sets: sets, profile: {'loadUnit': 'lb'})))!,
      dbProvider.overrideWithValue(db),
      syncProvider.overrideWith((ref) {
        final engine = SyncEngine(db, Api(FakeServer()..offline = true, ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
        ref.onDispose(engine.dispose);
        return engine;
      }),
      plusProvider.overrideWithValue(plusPreview),
    ], size: const Size(320, 900), textScale: 2, insets: phoneInsets);
    c.read(shellProvider.notifier).openWorkout(WorkoutFocus.session('w-$_today'));
    await _tap(tester, 'nav-train');
    await _toTop(tester, 'last-time');
    await _shot(tester, 'recorder-320-2x-history');
    await _tap(tester, 'compare-toggle');
    await _toTop(tester, 'last-time');
    await _shot(tester, 'recorder-320-2x-compare-open');
    await _tap(tester, 'compare-toggle');
    await _toTop(tester, 'set-load');
    await _shot(tester, 'recorder-320-2x-entry');
    expect(tester.takeException(), isNull);
  });
}
