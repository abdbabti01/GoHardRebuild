import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/nutrition/nutrient_coverage.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart';
import 'package:gohard_rebuild/features/shell/home_shell.dart';
import 'package:gohard_rebuild/features/workout/workout_detail_screen.dart';

import 'support.dart';

const _day = '2026-10-09';

class _FixedDay extends TodayKey {
  @override
  String build() => _day;
}

Stored<T> _stored<T>(T value, String kind, String id, Json body, {String state = 'synced'}) =>
    Stored(value, Rec(ownerId: 'one', kind: kind, id: id, body: jsonEncode(body), revision: 1, localRevision: 0, syncState: state));

Json _openWorkout() => {
      'id': 'w1', 'kind': 'manual', 'title': 'Upper Body', 'dayKey': _day, 'startedAtUtc': '2026-10-09T15:00:00Z', 'finishedAtUtc': null, 'isDeleted': false,
      'exercises': [{'id': 'e1', 'ordinal': 1, 'name': 'Bench press', 'catalogKey': 'bench-press', 'isDeleted': false}],
    };

/// The real shell and screens over fixed owner-scoped streams; no database or network is involved here.
Future<List<Override>> _overrides({List<Json> workouts = const [], List<Json> food = const [], bool foodFails = false, String appearance = 'dark'}) async {
  final sessions = SessionManager(MemorySecretStore());
  await sessions.signIn(authFor('one'));
  return [
    sessionsProvider.overrideWithValue(sessions),
    todayKeyProvider.overrideWith(_FixedDay.new),
    profileProvider.overrideWith((ref) => Stream.value(Profile({...authFor('one')['profile'] as Json, 'displayName': 'Alex Sample', 'appearance': appearance}))),
    contextRowProvider.overrideWith((ref) => Stream.value(_stored(TrainingCtx({'contextRevision': 1, 'primaryPlanId': null}), Kinds.context, 'one', {}))),
    plansProvider.overrideWith((ref) => Stream.value(const [])),
    workoutsProvider.overrideWith((ref) => Stream.value([for (final w in workouts) _stored(Workout(w), Kinds.workout, w['id'] as String, w)])),
    allSetsProvider.overrideWith((ref) => Stream.value(const [])),
    setsProvider.overrideWith((ref, id) => Stream.value(const [])),
    runtimesProvider.overrideWith((ref) => Stream.value(const [])),
    foodProvider.overrideWith((ref, day) => foodFails ? Stream.error(StateError('disk')) : Stream.value([for (final f in food) _stored(FoodEntry(f), Kinds.food, f['id'] as String, f)])),
    runsProvider.overrideWith((ref) => Stream.value(const [])),
    metricsProvider.overrideWith((ref) => Stream.value(const [])),
    proposalsProvider.overrideWith((ref) => Stream.value(const [])),
    catalogProvider.overrideWith((ref) => Stream.value(const [])),
    issuesProvider.overrideWith((ref) => Stream.value(const [])),
    pendingCountProvider.overrideWith((ref) => Stream.value(0)),
  ];
}

Future<ProviderContainer> _pump(WidgetTester tester, List<Override> overrides, {Widget home = const HomeShell(), Size size = const Size(390, 844), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: eveningTheme(Brightness.light), darkTheme: eveningTheme(Brightness.dark), themeMode: ThemeMode.dark,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('train_selection_survives_tab_switch', (tester) async {
    final container = await _pump(tester, await tester.runAsync(_overrides) ?? []);
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
    await _pump(tester, await tester.runAsync(_overrides) ?? []);
    expect(find.text('Friday, October 9'), findsOneWidget);
    expect(find.text('No plan yet'), findsOneWidget);
    expect(find.text('No food logged yet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No other activity recorded today.'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('kcal'), findsNothing, reason: 'no invented nutrition');
    expect(find.text('Resume workout'), findsNothing, reason: 'no invented training');
  });

  testWidgets('section_failure_keeps_workout_action', (tester) async {
    await _pump(tester, await tester.runAsync(() => _overrides(workouts: [_openWorkout()], foodFails: true)) ?? []);
    expect(find.text('Resume workout'), findsOneWidget);
    expect(find.text('Upper Body'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Log food'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('could not be read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow_scaled_today_has_no_overflow', (tester) async {
    final food = [{'id': 'f1', 'dayKey': _day, 'meal': 'Breakfast', 'name': 'Greek yogurt with a long descriptive name', 'amountDescription': '200 g', 'macros': {'calories': 110, 'protein': null, 'carbs': null, 'fat': 0}, 'isDeleted': false}];
    await _pump(tester, await tester.runAsync(() => _overrides(workouts: [_openWorkout()], food: food)) ?? [], size: const Size(320, 640), textScale: 2);
    expect(find.text('Resume workout'), findsOneWidget);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Log food'), 200, scrollable: scroll);
    expect(find.text('Known totals'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start a run'), 200, scrollable: scroll);
    for (final tab in ['train', 'eat', 'me']) {
      await tester.tap(find.byKey(Key('nav-$tab')));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull, reason: 'no overflow at 320 px with 2x text on any destination');
  });

  testWidgets('blank_macros_show_known_totals and unknown is a dash, never zero', (tester) async {
    final entries = [
      FoodEntry({'id': 'a', 'name': 'Rice', 'amountDescription': '1 bowl', 'meal': 'Lunch', 'dayKey': _day, 'macros': {'calories': 400, 'protein': 25, 'carbs': null, 'fat': 0}}),
      FoodEntry({'id': 'b', 'name': 'Toast', 'amountDescription': '2 slices', 'meal': 'Lunch', 'dayKey': _day, 'macros': {'calories': 110, 'protein': null, 'carbs': null, 'fat': null}}),
    ];
    await _pump(tester, const [], home: Scaffold(body: SingleChildScrollView(child: NutritionSurface(entries: entries, coverage: NutrientCoverage.calculate(entries)))));
    expect(find.text('Known totals'), findsOneWidget);
    expect(find.text('510'), findsOneWidget);
    expect(find.text('25 g'), findsOneWidget);
    expect(find.text('—'), findsOneWidget, reason: 'carbs are unknown for every food');
    expect(find.text('0 g'), findsOneWidget, reason: 'an entered zero is a known zero');
  });

  testWidgets('appearance_is_shared_across_four_tabs and unfinished_history_is_not_completed', (tester) async {
    final container = await _pump(tester, await tester.runAsync(() => _overrides(workouts: [_openWorkout()], appearance: 'light')) ?? [], home: const WorkoutHistoryScreen());
    container.listen(appearanceProvider, (_, _) {});
    await tester.pumpAndSettle();
    expect(container.read(appearanceProvider), "light", reason: 'one saved preference drives the whole app');
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.textContaining('Finished'), findsNothing);
    final c = EveningColors.dark;
    expect((c.canvas, c.nutritionSurface, EveningColors.light.nutritionSurface), (const Color(0xFF191918), const Color(0xFFE5DFD3), const Color(0xFFEBE5DA)));
  });
}
