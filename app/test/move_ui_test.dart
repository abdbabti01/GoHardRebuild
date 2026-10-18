import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/features/activity/announcer.dart' show offlineVoices;
import 'package:gohard_rebuild/features/activity/intervals.dart';
import 'package:gohard_rebuild/features/activity/location_source.dart';
import 'package:gohard_rebuild/features/activity/recorder.dart';
import 'package:gohard_rebuild/features/activity/run_walk_screens.dart';
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

class _CountingSteps extends SimulatedStepSource {
  _CountingSteps() : super(state: StepAccess.notAllowed);
  int requests = 0;
  @override
  Future<StepAccess> request() {
    requests++;
    return super.request();
  }

  @override
  Future<StepAccess> dailyRequest() async => state;
}

/// A device-like location source (not labelled simulated), for checking Ready's real fit.
class _Gps extends SimulatedLocationSource {
  _Gps() : super(const [(46.8, -71.2, 5.0, null)]);
  @override
  bool get simulated => false;
}

Future<List<Override>> _fixture(WidgetTester tester, FoodFakes fakes,
    {List<Json> saved = const [], List<Json> food = const [], StepSource? steps, Set<String> stepsOn = const {}, bool coach = true, MovePrefsStore? move}) async {
  final prefs = move ?? (MovePrefsStore(MemorySecretStore())..value = MovePrefs(steps: stepsOn, stepGoals: stepsOn.isEmpty ? const {} : const {'one': 6000}));
  final coachStore = CoachPrefsStore(MemorySecretStore())..value = CoachPrefs(onTabs: coach, onToday: coach);
  return [
    coachPrefsStoreProvider.overrideWithValue(coachStore),
    locationSourceProvider.overrideWithValue(_Gps()),
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

    testWidgets('off: the tile offers steps (no number, no bar) and opening Today asks the phone for nothing', (tester) async {
      final src = _CountingSteps();
      await pumpApp(tester, await _fixture(tester, FoodFakes(), steps: src), size: const Size(390, 1600));
      await tester.pumpAndSettle();
      expect(find.text('Track your steps'), findsOneWidget);
      expect(find.text('Count with your phone.'), findsOneWidget);
      expect(find.byKey(const Key('today-steps-enable')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('today-steps')), matching: find.byType(LinearProgressIndicator)), findsNothing);
      expect(src.requests, 0, reason: 'nothing is asked until Enable');
      await tester.tap(find.byKey(const Key('today-steps-enable')));
      await tester.pumpAndSettle();
      expect(src.requests, 1, reason: 'Enable asks, once');
      expect(find.text('3,480'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with the coach off the tile is still there with its own Enable; hiding it changes nothing else', (tester) async {
      final c = await pumpApp(tester, await _fixture(tester, FoodFakes(), coach: false, steps: SimulatedStepSource(state: StepAccess.allowed)), size: const Size(390, 1600));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-steps-enable')).hitTestable(), findsOneWidget);
      c.read(movePrefsProvider.notifier).setStepsOnToday('one', false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today-steps')), findsNothing);
      expect(find.byKey(const Key('today-run-history')), findsNothing, reason: 'Run / Walk history is in Train, not on Today');
      expect(find.byKey(const Key('today-module-run')), findsOneWidget);
      expect(c.read(stepsEnabledProvider), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a total says its source and goal; a genuine zero, not allowed and unavailable read differently', (tester) async {
      await today(tester, SimulatedStepSource(state: StepAccess.allowed, dailyTotal: 3480));
      expect(value(tester), '3,480');
      expect(find.text('of 6,000'), findsOneWidget, reason: 'the goal, with its bar, only because a goal is set');
      expect(find.textContaining('This phone (simulated) · '), findsOneWidget, reason: 'where and when it was read');
      await tester.pumpWidget(const SizedBox());

      await today(tester, SimulatedStepSource(state: StepAccess.allowed, dailyTotal: 0));
      expect(value(tester), '0', reason: 'measured zero is a number');
      await tester.pumpWidget(const SizedBox());

      await today(tester, SimulatedStepSource(state: StepAccess.blocked));
      expect(value(tester), '—');
      expect(find.text('Access is off. Allow it in Settings.'), findsOneWidget);
      expect(find.byKey(const Key('today-steps-settings')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await today(tester, SimulatedStepSource(state: StepAccess.unavailable));
      expect(value(tester), '—');
      expect(find.textContaining('Health Connect'), findsOneWidget, reason: 'Android names the daily source it needs');
      await tester.pumpWidget(const SizedBox()); // the row goes, and its refresh with it
    });
  });

  group('Steps in one place', () {
    testWidgets('Today, Me and Ready open the same sheet; turning it on in one is on everywhere; no screen asks by opening', (tester) async {
      final src = _CountingSteps();
      final c = await pumpApp(tester, await _fixture(tester, FoodFakes(), steps: src), size: const Size(390, 1600));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today-steps')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('track-steps')), findsOneWidget);
      expect(find.byKey(const Key('steps-on-today')), findsOneWidget);
      expect(src.requests, 0, reason: 'the sheet opening asks nothing');
      await tester.tap(find.byKey(const Key('track-steps')));
      await tester.pumpAndSettle();
      expect((c.read(stepsEnabledProvider), src.requests), (true, 1));
      Navigator.of(tester.element(find.byKey(const Key('track-steps')))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-me')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.byKey(const Key('me-steps')), find.byType(Scrollable).last, const Offset(0, -200));
      expect(find.descendant(of: find.byKey(const Key('me-steps')), matching: find.text('On')), findsOneWidget);
      await tester.tap(find.byKey(const Key('me-steps')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('track-steps'))).value, isTrue, reason: 'the same choice, not a second switch');
      expect(src.requests, 1);
      await tester.pumpWidget(const SizedBox());
    });

    test('choices saved before the move are kept: steps on and the goal; Today shows the tile unless hidden', () {
      final before = MovePrefs.fromJson({'steps': ['one'], 'stepGoals': {'one': 7000}, 'voice': true});
      expect(before.steps, {'one'});
      expect(before.stepGoals, {'one': 7000});
      expect(before.stepsHidden, isEmpty);
      final hidden = MovePrefs.fromJson(before.copy(stepsHidden: {'one'}).toJson());
      expect((hidden.steps.contains('one'), hidden.stepsHidden.contains('one')), (true, true), reason: 'hiding the tile is display only');
    });
  });

  group('Ready', () {
    Future<ProviderContainer> ready(WidgetTester tester, {bool coach = true, Size size = const Size(390, 844), double text = 1, MovePrefs move = const MovePrefs()}) async {
      final c = await pumpApp(tester, await _fixture(tester, FoodFakes(), coach: coach, steps: _CountingSteps(), move: MovePrefsStore(MemorySecretStore())..value = move),
          home: const RunWalkScreen(), size: size, textScale: text, insets: phoneInsets, settle: false);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return c;
    }

    void inView(WidgetTester tester, String key) {
      final r = tester.getRect(find.byKey(Key(key)));
      final start = tester.getRect(find.byKey(const Key('runwalk-start')));
      expect(r.top >= 47 && r.bottom <= 844 - 34, isTrue, reason: '$key within the safe area ($r)');
      if (key != 'runwalk-start') expect(r.bottom <= start.top, isTrue, reason: '$key above Start, not under it ($r, Start $start)');
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget, reason: '$key can be tapped where it is');
    }

    for (final coach in [true, false]) {
      testWidgets('a 390 × 844 phone with its notch and home indicator: the setup, Steps and Start in view without scrolling (coach ${coach ? 'on' : 'off'})', (tester) async {
        await ready(tester, coach: coach);
        for (final k in ['runwalk-intervals', 'runwalk-voice', 'runwalk-autopause', 'runwalk-steps-row', 'runwalk-start']) {
          inView(tester, k);
        }
        expect(find.text('Off'), findsNWidgets(3), reason: 'each row says its real state');
        expect(find.byKey(const Key('runwalk-steps-enable')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('setup rows say what is set; auto-pause says it is not used with intervals and keeps the choice', (tester) async {
      final c = await ready(tester, move: const MovePrefs(voice: true, intervals: true, plan: IntervalPlan.preset, everyDistance: 1));
      expect(find.text('Run 1 min · Walk 90 s · × 8'), findsOneWidget);
      expect(find.text('On · every 1 km'), findsOneWidget);
      expect(find.text('Not used with intervals'), findsOneWidget);
      await tester.tap(find.byKey(const Key('runwalk-autopause')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('autopause-switch')));
      await tester.pumpAndSettle();
      expect(c.read(devicePrefsProvider).autoPause, isTrue, reason: 'the free-run choice, kept apart from intervals');
      expect(c.read(recorderProvider).open, isFalse, reason: 'a settings sheet starts nothing');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('320 px at twice the text: everything is reached by scrolling, Start stays, nothing overflows', (tester) async {
      await ready(tester, size: const Size(320, 640), text: 2);
      expect(find.byKey(const Key('runwalk-start')).hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('runwalk-steps-row')), 150, scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
      expect(find.byKey(const Key('runwalk-steps-row')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('only voices that speak offline are offered (Android marks network voices)', () {
    final v = offlineVoices([
      {'name': 'en-us-x-iol-local', 'locale': 'en-US', 'network_required': '0'},
      {'name': 'en-us-x-iol-network', 'locale': 'en-US', 'network_required': '1'},
      {'name': 'Samantha', 'locale': 'en-US'}, // iOS: no flag, on the phone
    ]);
    expect(v.map((x) => x.name), ['en-us-x-iol-local', 'Samantha']);
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
