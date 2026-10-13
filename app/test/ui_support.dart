import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/app.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/appearance.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/food_item.dart';
import 'package:gohard_rebuild/features/nutrition/food_repository.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';

import 'support.dart';

/// Widget-test plumbing: the real shell and screens over fixed owner-scoped streams. No database or network.
/// Everything here is test fixture data; none of it ships in the app.

class FixedDay extends TodayKey {
  FixedDay(this.day);
  final String day;
  @override
  String build() => day;
}

Stored<T> stored<T>(T value, String kind, String id, Json body, {String state = 'synced'}) =>
    Stored(value, Rec(ownerId: 'one', kind: kind, id: id, body: jsonEncode(body), revision: 1, localRevision: 0, syncState: state));

Future<List<Override>> overridesFor({required String day, List<Json> plans = const [], String? primaryPlanId, List<Json> workouts = const [], List<Json> sets = const [],
    List<Json> food = const [], bool foodFails = false, AppearanceStore? appearance, String profileAppearance = 'dark',
    int? calorieGoal, int? proteinGoal, List<Json> savedFoods = const [], List<Json> seenFoods = const [], List<Json> runs = const [],
    int pending = 0, List<Rec> issues = const [], Json profile = const {}, bool profileLoaded = true}) async {
  final sessions = SessionManager(MemorySecretStore());
  await sessions.signIn(authFor('one'));
  List<Stored<WorkoutSet>> setRows(String? workoutId) => [for (final s in sets) if (workoutId == null || s['workoutId'] == workoutId) stored(WorkoutSet(s), Kinds.set, s['id'] as String, s)];
  return [
    sessionsProvider.overrideWithValue(sessions),
    if (appearance != null) appearanceStoreProvider.overrideWithValue(appearance),
    todayKeyProvider.overrideWith(() => FixedDay(day)),
    profileProvider.overrideWith((ref) => Stream.value(!profileLoaded ? null : Profile({...authFor('one')['profile'] as Json, 'displayName': 'Alex Sample', 'appearance': profileAppearance, 'calorieGoal': calorieGoal, 'proteinGoal': proteinGoal, ...profile}))),
    foodJournalProvider.overrideWith((ref) => Stream.value([for (final f in food) stored(FoodEntry(f), Kinds.food, f['id'] as String, f)])),
    savedFoodsProvider.overrideWith((ref) => Stream.value([for (final f in savedFoods) stored(SavedFood(f), Kinds.savedFood, f['id'] as String, f)])),
    seenFoodsProvider.overrideWith((ref) => Stream.value([for (final f in seenFoods) FoodItem(f)])),
    contextRowProvider.overrideWith((ref) => Stream.value(stored(TrainingCtx({'contextRevision': 1, 'primaryPlanId': primaryPlanId}), Kinds.context, 'one', {}))),
    plansProvider.overrideWith((ref) => Stream.value([for (final p in plans) stored(Plan(p), Kinds.plan, p['id'] as String, p)])),
    workoutsProvider.overrideWith((ref) => Stream.value([for (final w in workouts) stored(Workout(w), Kinds.workout, w['id'] as String, w)])),
    allSetsProvider.overrideWith((ref) => Stream.value(setRows(null))),
    setsProvider.overrideWith((ref, id) => Stream.value(setRows(id))),
    runtimesProvider.overrideWith((ref) => Stream.value(const [])),
    foodProvider.overrideWith((ref, d) => foodFails ? Stream.error(StateError('disk')) : Stream.value([for (final f in food) if (f['dayKey'] == d) stored(FoodEntry(f), Kinds.food, f['id'] as String, f)])),
    runsProvider.overrideWith((ref) => Stream.value([for (final r in runs) stored(Run(r), Kinds.run, r['id'] as String, r)])),
    metricsProvider.overrideWith((ref) => Stream.value(const [])),
    proposalsProvider.overrideWith((ref) => Stream.value(const [])),
    catalogProvider.overrideWith((ref) => Stream.value(const [])),
    issuesProvider.overrideWith((ref) => Stream.value(issues)),
    pendingCountProvider.overrideWith((ref) => Stream.value(pending)),
  ];
}

/// Pumps `home` inside the app's real themes, driven by the appearance provider exactly as GoHardApp does.
Future<ProviderContainer> pumpApp(WidgetTester tester, List<Override> overrides,
    {Widget home = const HomeShell(), Size size = const Size(390, 844), double textScale = 1, bool settle = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  addTearDown(container.dispose);
  await tester.pumpWidget(RepaintBoundary(
    key: const Key('shot'),
    child: UncontrolledProviderScope(
    container: container,
    child: Consumer(builder: (context, ref, _) {
      final a = ref.watch(appearanceProvider);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goTheme(a.accent, Brightness.light), darkTheme: goTheme(a.accent, Brightness.dark), themeMode: a.mode,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: DevicePrefsScope(child: CompatibilityGate(child: child!))),
        home: home,
      );
    }),
  )));
  if (settle) await tester.pumpAndSettle();
  return container;
}

// ---------------------------------------------------------------------------- fixtures

const _upperA = ['Bench press', 'Overhead press', 'Barbell row', 'Lat pulldown', 'Triceps pushdown'];

List<Json> _prescription(String prefix) => [
      for (final (i, name) in _upperA.indexed)
        {'occurrenceKey': '$prefix-e${i + 1}', 'catalogKey': name.toLowerCase().replaceAll(' ', '-'), 'name': name, 'isTimed': false, 'targetSets': i < 3 ? 4 : 3, 'targetRepsMin': 6, 'targetRepsMax': 8, 'restSeconds': 90},
    ];

/// A block of `weeks` weeks from `start`, training on the given day offsets within each week. The first
/// `recorded` workouts carry a recorded result.
Json blockPlan({String id = 'p1', String title = 'Strength block', required String start, int weeks = 8, List<int> offsets = const [0, 2, 6], int recorded = 0}) {
  const titles = ['Lower body A', 'Upper body B', 'Upper body A'];
  var n = 0;
  return {
    'id': id, 'title': title, 'lifecycle': 'active', 'startDate': start, 'blockWeeks': weeks, 'minRecoveryDays': 1,
    'setup': {'direction': 'strength', 'sessionsPerWeek': offsets.length, 'minutesPerSession': 50, 'equipment': 'full_gym'},
    'occasions': [
      for (var w = 0; w < weeks; w++)
        for (final (i, offset) in offsets.indexed)
          () {
            final date = addDays(start, 7 * w + offset);
            final done = n++ < recorded;
            return {
              'id': 'o${w + 1}-${i + 1}', 'weekNumber': w + 1, 'ordinal': i + 1, 'title': titles[i % titles.length], 'originalDate': date, 'scheduledDate': date,
              'isSkipped': false, 'resultOutcome': done ? 'full' : null, 'resultWorkoutId': done ? 'done-${w + 1}-${i + 1}' : null, 'prescription': _prescription('o${w + 1}-${i + 1}'),
            };
          }(),
    ],
  };
}

/// The open workout for one occasion of `plan`, with the first `recordedSets` of its planned sets recorded.
({Json workout, List<Json> sets}) openWorkout(Json plan, String occasionId, {required String day, int recordedSets = 0}) {
  final occasion = (plan['occasions'] as List).cast<Json>().firstWhere((o) => o['id'] == occasionId);
  final exercises = [
    for (final (i, p) in (occasion['prescription'] as List).cast<Json>().indexed)
      {'id': '$occasionId-x${i + 1}', 'ordinal': i + 1, 'name': p['name'], 'catalogKey': p['catalogKey'], 'isPrescribed': true, 'isTimed': false, 'targetSets': p['targetSets'], 'targetRepsMin': 6, 'targetRepsMax': 8, 'restSeconds': 90, 'isDeleted': false},
  ];
  final sets = <Json>[];
  for (final e in exercises) {
    for (var s = 0; s < (e['targetSets'] as int) && sets.length < recordedSets; s++) {
      sets.add({'id': 's${sets.length + 1}', 'exerciseId': e['id'], 'workoutId': 'w-open', 'reps': 8, 'loadKg': 60, 'performedAtUtc': '${day}T15:0${sets.length}:00Z', 'isDeleted': false});
    }
  }
  return (
    workout: {'id': 'w-open', 'planId': plan['id'], 'occasionId': occasionId, 'kind': 'planned', 'title': occasion['title'], 'dayKey': day, 'startedAtUtc': '${day}T15:00:00Z', 'finishedAtUtc': null, 'isDeleted': false, 'exercises': exercises},
    sets: sets
  );
}

Json foodEntry(String id, String day, String meal, String name, String amount, {num? calories, num? protein, num? carbs, num? fat}) =>
    {'id': id, 'dayKey': day, 'meal': meal, 'name': name, 'amountDescription': amount, 'macros': {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat}, 'isDeleted': false};
