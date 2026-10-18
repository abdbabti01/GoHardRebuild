import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/activity/intervals.dart';
import 'package:gohard_rebuild/features/activity/move_prefs.dart';
import 'package:gohard_rebuild/features/activity/move_widgets.dart';
import 'package:gohard_rebuild/features/activity/steps.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/log_food_screen.dart';

import 'food_fakes.dart';
import 'ui_support.dart';

/// The screens of docs/RUN_WALK.md › Steps and › Intervals, and docs/COACH.md › Saved foods. Step counts are SIMULATED.
const day = '2026-10-11';

Future<List<Override>> _fixture(WidgetTester tester, FoodFakes fakes, {List<Json> saved = const [], List<Json> food = const [], StepSource? steps, Set<String> stepsOn = const {}}) async {
  final prefs = MovePrefsStore(MemorySecretStore())..value = MovePrefs(steps: stepsOn, stepGoals: stepsOn.isEmpty ? const {} : const {'one': 6000});
  return [
    ...(await tester.runAsync(() => overridesFor(day: day, food: food, savedFoods: saved)))!,
    ...fakes.overrides,
    movePrefsStoreProvider.overrideWithValue(prefs),
    if (steps != null) stepSourceProvider.overrideWithValue(steps),
  ];
}

void main() {
  group('saved foods on Eat', () {
    testWidgets('with a favourite, the coach offers it once; the shortcut opens Favourites for the day viewed and logs nothing', (tester) async {
      final fakes = FoodFakes();
      final c = await pumpApp(tester, await _fixture(tester, fakes, saved: [savedFood('s1', chickenRaw(), favourite: true)]));
      expect(c.read(coachPrefsProvider).seen('one', 'eat.saved.shortcut'), isFalse, reason: 'Eat is built off screen behind Today: the hint is not used up unseen');
      await tester.tap(find.byKey(const Key('nav-eat')));
      await tester.pumpAndSettle();
      final coach = find.byKey(const Key('eat-coach'));
      expect(find.descendant(of: coach, matching: find.textContaining('Your favourite foods are one tap away')), findsOneWidget);
      await tester.tap(find.byKey(const Key('eat-coach-favourites')));
      await tester.pumpAndSettle();
      final screen = tester.widget<LogFoodScreen>(find.byType(LogFoodScreen));
      expect((screen.dayKey, screen.scope), (day, FoodScope.favourites), reason: 'the real Add food, on the real list, for the day in view');
      expect(find.text('Chicken, breast, meat only, raw'), findsOneWidget);
      expect(fakes.journal.saved, isEmpty, reason: 'a shortcut never logs food');
      expect(c.read(coachPrefsProvider).seen('one', 'eat.saved.shortcut'), isTrue, reason: 'shown once; Coaching hints govern it');
    });

    testWidgets('a first visit is about logging a meal; once food is logged and nothing is saved, the coach says how to keep it', (tester) async {
      await pumpApp(tester, await _fixture(tester, FoodFakes()));
      await tester.tap(find.byKey(const Key('nav-eat')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.textContaining('Log a meal')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await pumpApp(tester, await _fixture(tester, FoodFakes(), food: [foodEntry('f1', day, 'Breakfast', 'Porridge', '1 bowl', calories: 300, protein: 10, carbs: 50, fat: 5)]));
      await tester.tap(find.byKey(const Key('nav-eat')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.textContaining('Tap the star')), findsOneWidget);
      expect(find.byType(EatScreen), findsOneWidget);
    });
  });

  group('steps on Today', () {
    Future<void> today(WidgetTester tester, StepSource src) async {
      await pumpApp(tester, await _fixture(tester, FoodFakes(), steps: src, stepsOn: {'one'}), size: const Size(390, 1600));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    String value(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('today-steps-value'))).data!;

    testWidgets('off: nothing is read or shown', (tester) async {
      await pumpApp(tester, await _fixture(tester, FoodFakes(), steps: SimulatedStepSource(state: StepAccess.allowed)));
      expect(find.byKey(const Key('today-steps')), findsNothing);
    });

    testWidgets('a total says its source and goal; a genuine zero, not allowed and unavailable read differently', (tester) async {
      await today(tester, SimulatedStepSource(state: StepAccess.allowed, dailyTotal: 3480));
      expect(value(tester), '3,480');
      expect(find.textContaining('of 6,000 · This phone (simulated)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await today(tester, SimulatedStepSource(state: StepAccess.allowed, dailyTotal: 0));
      expect(value(tester), '0', reason: 'measured zero is a number');
      await tester.pumpWidget(const SizedBox());

      await today(tester, SimulatedStepSource(state: StepAccess.blocked));
      expect(value(tester), '—');
      expect(find.text('Motion access is off. Allow it in Settings.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await today(tester, SimulatedStepSource(state: StepAccess.unavailable));
      expect(value(tester), '—');
      expect(find.textContaining('Health Connect'), findsOneWidget, reason: 'Android names the daily source it needs');
      await tester.pumpWidget(const SizedBox()); // the row goes, and its refresh with it
    });
  });

  testWidgets('interval setup: an editable preset, a preview of the phases and the total, kept for next time', (tester) async {
    final c = await pumpApp(tester, await _fixture(tester, FoodFakes()), home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => showIntervalSetup(context), child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('interval-summary')), findsOneWidget);
    expect(find.text('5:00 warm-up · 8 × run 1:00, walk 1:30 · 5:00 cool-down'), findsOneWidget);
    expect(find.text('Programmed active time 30:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('interval-reps-less')));
    await tester.tap(find.byKey(const Key('interval-run-more')));
    await tester.pump();
    expect(find.text('5:00 warm-up · 7 × run 1:15, walk 1:30 · 5:00 cool-down'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('interval-use')));
    await tester.tap(find.byKey(const Key('interval-use')));
    await tester.pumpAndSettle();
    final p = c.read(movePrefsProvider);
    expect((p.intervals, p.plan), (true, const IntervalPlan(warmup: 300, run: 75, walk: 90, reps: 7, cooldown: 300)));
  });
}
