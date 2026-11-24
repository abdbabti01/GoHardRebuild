import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/data/models.dart' show Json;
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart' show EatScreen;
import 'package:gohard_rebuild/features/nutrition/nutrition_surface.dart' show NutritionSurface;

import 'food_fakes.dart';
import 'ui_support.dart';

/// Eat's compact top (docs/FOOD_DATA.md › Compact top): Nutrition details folded under the figures, Nutrition settings
/// opening the existing goals and tracking flows, Set daily goals right there while none is set, the coach with one
/// action and Ask me. Opening any of it logs nothing and asks no AI; Today keeps its own summary.
const day = '2026-10-11';

/// Every request the app sends: none may reach the coach (the AI) just from opening Eat, its details or its settings.
class _Recorder implements Transport {
  final paths = <String>[];
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    paths.add(path);
    return const ApiResponse(503, null);
  }
}

const _hints = ['eat.first', 'eat.habits', 'eat.history', 'eat.meals', 'eat.out', 'eat.reminders', 'eat.saved.new', 'eat.saved.shortcut'];

Future<(FoodFakes, _Recorder)> _openEat(WidgetTester tester, {List<Json> food = const [], int? kcal, int? protein}) async {
  final fakes = FoodFakes(), recorder = _Recorder();
  await pumpApp(tester, [
    ...(await tester.runAsync(() => overridesFor(day: day, food: food, calorieGoal: kcal, proteinGoal: protein)))!,
    ...fakes.overrides,
    transportProvider.overrideWithValue(recorder),
    coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())..value = CoachPrefs(dismissed: {for (final h in _hints) 'one|$h'})),
  ], size: const Size(390, 1600));
  await tester.tap(find.byKey(const Key('nav-eat')));
  await tester.pumpAndSettle();
  return (fakes, recorder);
}

final _eat = find.byType(EatScreen);
Finder _inEat(String key) => find.descendant(of: _eat, matching: find.byKey(Key(key)));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.runAsync(() => Scrollable.ensureVisible(tester.element(f), alignment: 0.5));
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

final _lunch = [
  foodEntry('a', day, 'Lunch', 'Chicken, rice', '1 plate', calories: 650, protein: 48, carbs: 70, fat: 16),
  foodEntry('b', day, 'Snack', 'Shake', '1', calories: 370, protein: 23, carbs: 42), // no fat value: a known sum
];

void main() {
  testWidgets('Nutrition details is folded; open, it shows the composition, each goal\'s share and the notes; it logs nothing and asks nothing', (tester) async {
    final handle = tester.ensureSemantics();
    final (fakes, recorder) = await _openEat(tester, food: _lunch, kcal: 2200, protein: 140);
    // Folded: the figures and their qualification stay in view, the longer parts wait.
    expect(_inEat('eat-macros'), findsNothing);
    expect(find.text('Calories: 46% of goal'), findsNothing);
    expect(find.descendant(of: _eat, matching: find.text('Known totals')), findsOneWidget, reason: 'never hidden');
    expect(tester.getSemantics(_inEat('eat-details')), isSemantics(label: 'Nutrition details', isButton: true, hasExpandedState: true, isExpanded: false));

    await _tap(tester, _inEat('eat-details'));
    expect(_inEat('eat-macros'), findsOneWidget);
    expect(find.text('Calories: 46% of goal'), findsOneWidget);
    expect(find.text('Protein: 50% of goal'), findsOneWidget);
    expect(find.textContaining('sums of what you entered'), findsOneWidget, reason: 'the partial-values note');
    expect(tester.getSemantics(_inEat('eat-details')), isSemantics(label: 'Nutrition details', isExpanded: true));
    // The details sit under the actions, inside the summary.
    expect(tester.getTopLeft(_inEat('eat-macros')).dy, greaterThan(tester.getBottomLeft(_inEat('log-food')).dy));

    await _tap(tester, _inEat('eat-details'));
    expect(_inEat('eat-macros'), findsNothing, reason: 'folds again');
    expect(fakes.journal.saved, isEmpty);
    expect(recorder.paths.where((p) => p.contains('coach')), isEmpty, reason: 'no AI request');
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('Nutrition settings opens the existing goals editor (Help me set my targets inside) and Customize tracking; opening saves nothing', (tester) async {
    final (fakes, recorder) = await _openEat(tester, food: _lunch, kcal: 2200, protein: 140);
    expect(_inEat('eat-set-goals'), findsNothing, reason: 'goals are set: Edit goals is in Nutrition settings');
    expect(_inEat('eat-goals'), findsNothing, reason: 'no separate Edit goals / Customize tracking row');
    expect(_inEat('eat-customize'), findsNothing);

    await _tap(tester, _inEat('eat-nutrition-settings'));
    expect(find.descendant(of: find.byKey(const Key('eat-goals')), matching: find.text('Edit goals')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('eat-customize')), matching: find.text('Customize tracking')), findsOneWidget);
    await tester.tap(find.byKey(const Key('eat-goals')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-calories')), findsOneWidget, reason: 'the existing goals editor');
    expect(find.byKey(const Key('goals-help')), findsOneWidget, reason: 'Help me set my targets stays inside it');
    Navigator.of(tester.element(find.byKey(const Key('goal-calories')))).pop();
    await tester.pumpAndSettle();

    await _tap(tester, _inEat('eat-nutrition-settings'));
    await tester.tap(find.byKey(const Key('eat-customize')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('track-carbs')), findsOneWidget, reason: 'the existing Customize tracking');
    Navigator.of(tester.element(find.byKey(const Key('track-carbs')))).pop();
    await tester.pumpAndSettle();

    expect(fakes.journal.saved, isEmpty);
    expect(recorder.paths.where((p) => p.contains('coach')), isEmpty, reason: 'no AI request');
  });

  testWidgets('no goals: Set daily goals is right on the summary; the coach has one action and Ask me, not a second Set goals', (tester) async {
    await _openEat(tester, food: _lunch);
    final coach = find.byKey(const Key('eat-coach'));
    expect(find.descendant(of: coach, matching: find.byKey(const Key('eat-brief-ideas'))), findsOneWidget);
    expect(find.descendant(of: coach, matching: find.byKey(const Key('coach-say-ask'))), findsOneWidget, reason: 'free-text Ask me stays');
    expect(find.descendant(of: coach, matching: find.byKey(const Key('eat-brief-goals'))), findsNothing);
    expect(find.descendant(of: find.byType(NutritionSurface), matching: find.text('No goal')), findsNWidgets(2), reason: 'nothing invented');
    await _tap(tester, _inEat('eat-set-goals'));
    expect(find.byKey(const Key('goal-calories')), findsOneWidget);
  });

  testWidgets('an earlier day stays chosen through Nutrition details and Nutrition settings', (tester) async {
    await _openEat(tester, food: [for (final e in _lunch) {...e, 'id': 'y-${e['id']}', 'dayKey': '2026-10-10'}], kcal: 2200, protein: 140);
    await _tap(tester, find.descendant(of: _eat, matching: find.byTooltip('Previous day')));
    await _tap(tester, _inEat('eat-details'));
    await _tap(tester, _inEat('eat-nutrition-settings'));
    Navigator.of(tester.element(find.byKey(const Key('eat-customize')))).pop();
    await tester.pumpAndSettle();
    expect(find.descendant(of: _eat, matching: find.text('Meals')), findsOneWidget, reason: 'still the earlier day');
    expect(find.descendant(of: _eat, matching: find.text("Today's meals")), findsNothing);
    expect(_inEat('eat-macros'), findsOneWidget, reason: 'the details stay open');
  });

  testWidgets('Today keeps its own summary: its photo, the share beside each ring and the state in words', (tester) async {
    await _openEat(tester, food: _lunch, kcal: 2200, protein: 140);
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-goal-calories-percent')), findsOneWidget);
    expect(find.byKey(const Key('today-goal-calories-status')), findsOneWidget);
    expect(find.byKey(const Key('today-goal-calories-left')), findsNothing, reason: 'Today\'s glance, as before');
    expect(find.byKey(const Key('today-nutrition-settings')), findsNothing);
    expect(find.byKey(const Key('eat-details')).hitTestable(), findsNothing);
  });
}
