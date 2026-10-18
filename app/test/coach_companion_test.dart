import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/core/theme.dart';
import 'package:gohard_rebuild/data/db.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/data/sync.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_bubble.dart';
import 'package:gohard_rebuild/features/coach/coach_client.dart';
import 'package:gohard_rebuild/features/coach/coach_companion.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/coach/coach_rig.dart';
import 'package:gohard_rebuild/features/plans/builder/plan_builder_screen.dart';
import 'package:gohard_rebuild/features/plans/plan_draft.dart';
import 'package:gohard_rebuild/features/plans/train_screen.dart' show builderDraftProvider;

import 'ui_support.dart';

/// The Today companion (docs/COACH.md › Companion): when it greets, that it never replays, that it stays until Show
/// coach on Today is turned off (no close button; an old "hidden for today" is ignored), the guide as Ask GoHard's
/// launcher, the eyes' own life, Reduce Motion, pausing, both guides, the missing-texture fallback, the one
/// acknowledgement of a saved workout and that none of it asks the AI. Rendering itself is reviewed in
/// docs/evidence/coach (coach_rig_render_test.dart).

const _day = '2026-10-11'; // the fixture block has "Upper body A" due on this Sunday
final _plan = blockPlan(start: '2026-09-21', recorded: 8);

/// Every request the app makes. Today must make none to the coach.
class _Recorder implements Transport {
  final paths = <String>[];
  @override
  Future<ApiResponse> send(String method, String path, {Object? data, String? bearer}) async {
    paths.add(path);
    return const ApiResponse(503, null);
  }
}

Future<ProviderContainer> _today(WidgetTester tester, {String day = _day, CoachPrefsStore? coach, DevicePrefsStore? device, _Recorder? recorder, List<Override> more = const [], Size size = const Size(390, 844), double textScale = 1}) async =>
    pumpApp(
        tester,
        [
          ...(await tester.runAsync(() => overridesFor(day: day, plans: [_plan], primaryPlanId: 'p1')))!,
          coachPrefsStoreProvider.overrideWithValue(coach ?? CoachPrefsStore(MemorySecretStore())),
          if (device != null) devicePrefsStoreProvider.overrideWithValue(device),
          transportProvider.overrideWithValue(recorder ?? _Recorder()),
          ...more,
        ],
        size: size, textScale: textScale, settle: false);

CoachCompanionState _state(WidgetTester tester) => tester.state<CoachCompanionState>(find.byType(CoachCompanion, skipOffstage: false).first);
CoachCompanion _widget(WidgetTester tester) => tester.widget<CoachCompanion>(find.byType(CoachCompanion, skipOffstage: false).first);

/// A database for the builder's plan in progress (kept on the phone); nothing is ever sent.
List<Override> _withDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDb(NativeDatabase.memory());
  addTearDown(db.close);
  return [
    dbProvider.overrideWithValue(db),
    syncProvider.overrideWith((ref) {
      final engine = SyncEngine(db, Api(_Recorder(), ref.watch(sessionsProvider)), ref.watch(sessionsProvider))..isBlocked = () => true;
      ref.onDispose(engine.dispose);
      return engine;
    }),
  ];
}

/// Real frames for [ms] milliseconds.
Future<void> _frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The conversation without its store: these tests only check that it opens, never what it says.
class _Quiet extends AskConversation {
  @override
  AskState build() => const AskState(loaded: true);
}

final _quiet = askConversationProvider.overrideWith(_Quiet.new);

/// A phone's stored preference as an earlier build wrote it, "hidden for today" included.
Future<CoachPrefsStore> _upgraded(String hidden) async {
  final phone = MemorySecretStore();
  await phone.write('gohard.rebuild.coach', '{"guide":"leon","hints":true,"dismissed":[],"today":true,"greeted":null,"hidden":"$hidden"}');
  final store = CoachPrefsStore(phone);
  await store.restore();
  return store;
}

void main() {
  group('preferences', () {
    test('the greeting: once per local day per account on this phone; another account or day is new; Coaching hints do not govern Today', () {
      var p = const CoachPrefs();
      expect(p.mayGreet('one', '2026-10-11'), isTrue);
      p = p.copy(greeted: CoachPrefs.dayKey('one', '2026-10-11'));
      expect(p.mayGreet('one', '2026-10-11'), isFalse, reason: 'already greeted today');
      expect(p.mayGreet('two', '2026-10-11'), isTrue, reason: 'another account on the same phone');
      expect(p.mayGreet('one', '2026-10-12'), isTrue, reason: 'the next local day');
      expect(p.copy(hintsEnabled: false).mayGreet('one', '2026-10-12'), isTrue, reason: 'Show coach on Today governs the greeting; hints govern introductions elsewhere');
    });

    test('Show coach on Today, the greeting day, the guide and hints survive a restart; no "hidden" is written', () async {
      final phone = MemorySecretStore();
      final store = CoachPrefsStore(phone)..value = const CoachPrefs(guide: CoachGuide.leona, hintsEnabled: false, onToday: false, greeted: 'one|2026-10-11');
      await store.save();
      expect(await phone.read('gohard.rebuild.coach'), isNot(contains('hidden')));
      final back = CoachPrefsStore(phone);
      await back.restore();
      expect(back.value, store.value);
      final fresh = CoachPrefsStore(MemorySecretStore());
      await fresh.restore();
      expect(fresh.value.onToday, isTrue, reason: 'on by default, also for a preference saved before this setting existed');
    });

    test('an old "hidden for today" is ignored, not turned into Show coach on Today off', () async {
      final store = await _upgraded('one|2026-10-11');
      expect(store.value.onToday, isTrue);
      expect(store.value, const CoachPrefs(), reason: 'nothing of the old flag is kept');
    });
  });

  group('Today', () {
    testWidgets('opening Today: the guide greets once and speaks through its bubble, with Ask me; no close button and no second Ask beside the title; no AI request', (tester) async {
      final recorder = _Recorder();
      final c = await _today(tester, recorder: recorder);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsOneWidget);
      await _frames(tester, 100);
      expect(c.read(coachPrefsProvider).greeted, CoachPrefs.dayKey(c.read(ownerProvider)!, _day), reason: 'marked as soon as it starts');
      expect(_state(tester).pose.value.slide, lessThan(1), reason: 'peeking in, not snapped into place');
      await _frames(tester, 1800);
      expect(find.textContaining(RegExp(r'^Good (morning|afternoon|evening), Alex!$')), findsOneWidget, reason: 'the title line of the bubble');
      expect(find.textContaining('Upper body A is planned today.', findRichText: true), findsOneWidget);
      expect(find.byKey(const Key('coach-say-ask')), findsOneWidget, reason: 'Ask me in the bubble');
      expect(find.byKey(const Key('coach-avatar-launcher')), findsOneWidget, reason: 'the guide is the launcher');
      expect(find.byKey(const Key('today-ask')), findsNothing, reason: 'no generic Ask beside the title');
      expect(find.byKey(const Key('coach-say-close')), findsNothing, reason: 'no close button on Today');
      expect(find.byTooltip('Hide coach for today'), findsNothing);
      expect(recorder.paths.where((p) => p.contains('coach')), isEmpty, reason: 'greeting and line are worked out on the phone');
    });

    testWidgets('an account that hid the coach for today in an earlier build sees it again after upgrading, that same day', (tester) async {
      final owner = (await _today(tester)).read(ownerProvider)!;
      final store = (await tester.runAsync(() => _upgraded('$owner|$_day')))!; // this account, today, as the old build wrote it
      await tester.pumpWidget(const SizedBox());
      await _today(tester, coach: store);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsOneWidget);
      expect(find.byKey(const Key('coach-avatar-launcher')), findsOneWidget);
    });

    testWidgets('no replay: a rebuild, a tab change, a sync and the app returning show the settled portrait at once; it is still there', (tester) async {
      final c = await _today(tester);
      await _frames(tester, 11000); // greeting, settling, rest
      expect(_state(tester).ticking, isFalse, reason: 'at rest nothing ticks');
      expect(_state(tester).pose.value.slide, 1);

      // Another tab and back: the header is rebuilt, the greeting already played.
      await tester.tap(find.byKey(const Key('nav-train')));
      await _frames(tester, 400);
      expect(_state(tester).ticking, isFalse, reason: 'Today hidden: paused');
      await tester.tap(find.byKey(const Key('nav-today')));
      await tester.pump();
      expect(_widget(tester).greet, isFalse);
      expect(_state(tester).pose.value.slide, 1, reason: 'settled at once');

      // A sync replaces the records; the app goes to the background and comes back.
      c.invalidate(dailySnapshotProvider);
      await tester.pump();
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(_state(tester).ticking, isFalse);
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(_widget(tester).greet, isFalse);
      expect(_state(tester).pose.value.slide, 1);

      // Restart on the same day: still no greeting, still there.
      final again = c.read(coachPrefsStoreProvider);
      await tester.pumpWidget(const SizedBox());
      await _today(tester, coach: again);
      await tester.pump();
      expect(_widget(tester).greet, isFalse);
      expect(find.byType(CoachCompanion), findsOneWidget);
    });

    testWidgets('tapping the guide opens Ask GoHard; so does Ask me; both with the same guide in the conversation', (tester) async {
      await _today(tester, more: [_quiet]);
      await _frames(tester, 3000);
      await tester.tap(find.byKey(const Key('coach-avatar-launcher')));
      await _frames(tester, 600);
      expect(find.byKey(const Key('ask-input')), findsOneWidget, reason: 'the conversation');
      expect(find.byKey(const Key('ask-companion')), findsOneWidget, reason: 'the same guide in its header');
      await tester.tap(find.byKey(const Key('ask-close')));
      await _frames(tester, 600);
      await tester.tap(find.byKey(const Key('coach-say-ask')));
      await _frames(tester, 600);
      expect(find.byKey(const Key('ask-input')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ask-close')));
      await _frames(tester, 600);
      expect(find.byType(CoachCompanion), findsOneWidget, reason: 'still on Today afterwards');
    });

    testWidgets('the guide is a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      await _today(tester);
      await _frames(tester, 3000);
      expect(tester.getSemantics(find.bySemanticsLabel('Ask GoHard: open the conversation with Leon')), matchesSemantics(isButton: true, hasTapAction: true, label: 'Ask GoHard: open the conversation with Leon'));
      handle.dispose();
    });

    testWidgets('at rest the eyes live on their own: a blink, a look away or at the bubble, back to the user; nothing ticks in between', (tester) async {
      await _today(tester);
      await _frames(tester, 11000);
      var moved = false, restedBetween = false;
      for (var t = 0; t < 14000; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        final p = _state(tester).pose.value;
        if (p.blink > 0.2 || p.gazeX.abs() > 0.15 || p.gazeY.abs() > 0.15) moved = true;
        if (moved && !_state(tester).ticking) restedBetween = true;
        expect(p.slide, closeTo(1, 0.001), reason: 'the portrait stays in place');
      }
      expect(moved, isTrue);
      expect(restedBetween, isTrue, reason: 'back at rest, no frames, until the next moment');
      final p = _state(tester).pose.value;
      expect(p.gazeX.abs() < 0.05 && p.gazeY.abs() < 0.05 || _state(tester).ticking, isTrue, reason: 'settled means looking at the user');
    });

    testWidgets('an acknowledgement is one short nod; repeated ones blend instead of stacking', (tester) async {
      final ack = ValueNotifier(0);
      await tester.pumpWidget(ProviderScope(
        overrides: [rigImageProvider.overrideWith((ref, g) async => null)],
        child: MaterialApp(theme: goTheme(Accent.blue, Brightness.light), home: ValueListenableBuilder(valueListenable: ack, builder: (_, n, _) => Center(child: CoachCompanion(guide: CoachGuide.leon, size: const Size(92, 114), ack: n)))),
      ));
      await _frames(tester, 4000);
      for (var i = 0; i < 5; i++) {
        ack.value++;
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(_state(tester).ticking, isTrue);
      var maxNod = 0.0;
      for (var t = 0; t < 1500; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        final p = _state(tester).pose.value;
        maxNod = p.nod > maxNod ? p.nod : maxNod;
        expect(p.slide, closeTo(1, 0.001), reason: 'it stays in place');
      }
      expect(maxNod, lessThan(1.2), reason: 'one nod, never compounded');
      expect(_state(tester).pose.value.smile, lessThan(0.5), reason: 'the smile is gone again');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Show coach on Today off: no portrait, the time-of-day icon is back; Train keeps its own coach; on again, it is back', (tester) async {
      final c = await _today(tester, more: [_quiet]);
      c.read(coachPrefsProvider.notifier).setOnToday(false);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsNothing);
      expect(find.byKey(const Key('today-ask')), findsNothing, reason: 'no generic Ask button in its place');
      expect(find.byIcon(Icons.wb_sunny_outlined).evaluate().isNotEmpty || find.byIcon(Icons.nightlight_outlined).evaluate().isNotEmpty, isTrue);
      await tester.tap(find.byKey(const Key('nav-train')));
      await _frames(tester, 600);
      final trainFace = find.descendant(of: find.byKey(const Key('train-coach')), matching: find.byKey(const Key('coach-avatar-launcher')));
      expect(trainFace, findsOneWidget, reason: 'Today\'s switch does not change Train');
      await tester.tap(trainFace);
      await _frames(tester, 600);
      expect(find.byKey(const Key('ask-input')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ask-close')));
      await _frames(tester, 600);
      c.read(coachPrefsProvider.notifier).setOnToday(true);
      await tester.tap(find.byKey(const Key('nav-today')));
      await _frames(tester, 300);
      expect(find.byType(CoachCompanion), findsOneWidget);
    });

    testWidgets('Reduce Motion: a still, settled portrait at once, looking at the user; no frames, no blinking, no eye movement; the greeting counts as shown', (tester) async {
      final c = await _today(tester, device: DevicePrefsStore(MemorySecretStore())..motion = MotionPref.reduced);
      await tester.pump();
      await tester.pump();
      expect(_state(tester).pose.value.slide, 1);
      expect(_state(tester).pose.value.blink, 0);
      expect(_state(tester).ticking, isFalse);
      expect(c.read(coachPrefsProvider).greeted, isNotNull);
      for (var t = 0; t < 12000; t += 200) {
        await tester.pump(const Duration(milliseconds: 200));
        final p = _state(tester).pose.value;
        expect([p.blink, p.gazeX, p.gazeY], [0, 0, 0]);
        expect(_state(tester).ticking, isFalse);
      }
      expect(find.byKey(const Key('coach-avatar-launcher')), findsOneWidget, reason: 'still the way into Ask GoHard');
    });

    testWidgets('turning Reduce Motion on mid-greeting stops it in the settled pose', (tester) async {
      final c = await _today(tester);
      await _frames(tester, 200);
      expect(_state(tester).ticking, isTrue);
      c.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
      await tester.pump();
      await tester.pump();
      expect(_state(tester).ticking, isFalse);
      expect(_state(tester).pose.value.slide, 1);
    });

    testWidgets('a covering route pauses it and no timer or ticker is left after leaving', (tester) async {
      await _today(tester);
      await _frames(tester, 200);
      expect(_state(tester).ticking, isTrue);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('covering'))));
      await _frames(tester, 400);
      expect(_state(tester).ticking, isFalse, reason: 'covered: paused');
      nav.pop();
      await _frames(tester, 400);
      expect(_state(tester).ticking, isTrue, reason: 'back on top: the greeting carries on from where it was');
      await tester.pumpWidget(const SizedBox()); // disposed: the test fails on any timer still pending
    });

    testWidgets('both guides draw from their own texture; a missing texture shows the still avatar', (tester) async {
      // The real files, decoded outside the test clock, then handed to the page.
      final decoder = ProviderContainer();
      final images = {for (final g in CoachGuide.values) g: (await tester.runAsync(() => decoder.read(rigImageProvider(g).future)))!};
      decoder.dispose();
      final c = await _today(tester, more: [rigImageProvider.overrideWith((ref, g) async => images[g])]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('coach-rig-leon')), findsOneWidget);
      c.read(coachPrefsProvider.notifier).setGuide(CoachGuide.leona);
      await _frames(tester, 400);
      expect(find.byKey(const Key('coach-rig-leona')), findsOneWidget);
      expect(_state(tester).pose.value.slide, greaterThan(0.5), reason: 'switching guide does not restart the entrance');

      await tester.pumpWidget(const SizedBox());
      await _today(tester, more: [rigImageProvider.overrideWith((ref, g) async => null)]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('coach-rig-fallback')), findsOneWidget);
    });

    testWidgets('a saved workout is acknowledged once: the line says so, the cue is spent, a rebuild does not repeat it', (tester) async {
      final c = await _today(tester);
      await _frames(tester, 11000);
      c.read(workoutSavedProvider.notifier).saved('w1', _day);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Your workout is saved. Nice work.', findRichText: true), findsOneWidget);
      expect(c.read(workoutSavedProvider)!.played, isTrue);
      expect(_state(tester).ticking, isTrue, reason: 'the acknowledgement plays');
      await _frames(tester, 11000);
      c.invalidate(dailySnapshotProvider);
      await tester.pump();
      await tester.pump();
      expect(c.read(workoutSavedProvider)!.played, isTrue, reason: 'no second celebration');
    });

    testWidgets('Train and Eat: the guide speaks under the tab, with no second launcher or close button; Create my plan is in its bubble and opens the builder; a new section changes the words, never replays; nothing asks the AI', (tester) async {
      final recorder = _Recorder();
      await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: _day)))!,
        coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())),
        transportProvider.overrideWithValue(recorder),
        ..._withDb(),
      ], settle: false);
      await _frames(tester, 600);
      await tester.tap(find.byKey(const Key('nav-train')));
      await _frames(tester, 400);
      await tester.tap(find.byKey(const Key('train-plan')));
      await _frames(tester, 2500);
      final coach = find.byKey(const Key('train-coach'));
      expect(find.descendant(of: coach, matching: find.textContaining('Let\'s build your training plan.', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: coach, matching: find.byKey(const Key('create-plan'))), findsOneWidget, reason: 'the action is in the bubble');
      expect(find.byKey(const Key('create-plan')), findsOneWidget, reason: 'and nowhere else on the page');
      expect(find.byKey(const Key('train-manual-instead')), findsOneWidget, reason: 'manual training stays, quietly');
      expect(find.byKey(const Key('coach-ask-launcher')), findsNothing, reason: 'no small avatar beside the speaking one');
      expect(find.byKey(const Key('coach-say-close')), findsNothing);

      CoachCompanionState face() => tester.state<CoachCompanionState>(find.descendant(of: coach, matching: find.byType(CoachCompanion)));
      final first = face();
      expect(first.pose.value.slide, closeTo(1, 0.02), reason: 'arrived');
      await tester.tap(find.byKey(const Key('train-progress')));
      await _frames(tester, 100);
      expect(identical(face(), first), isTrue, reason: 'the same guide, not a new entrance');
      expect(face().pose.value.slide, closeTo(1, 0.02));
      expect(find.descendant(of: coach, matching: find.textContaining('once you finish a workout', findRichText: true)), findsOneWidget);
      await tester.tap(find.byKey(const Key('train-plan')));
      await _frames(tester, 300);

      await tester.tap(find.byKey(const Key('create-plan')));
      await _frames(tester, 800);
      expect(find.byType(CreatePlanScreen), findsOneWidget, reason: 'the existing builder, directly');
      Navigator.of(tester.element(find.byType(CreatePlanScreen))).pop();
      await _frames(tester, 600);

      await tester.tap(find.byKey(const Key('nav-eat')));
      await _frames(tester, 2500);
      final eat = find.byKey(const Key('eat-coach'));
      expect(find.descendant(of: eat, matching: find.textContaining('Log a meal, or set your daily goals.', findRichText: true)), findsOneWidget);
      expect(find.byKey(const Key('coach-help-eat')), findsNothing);
      expect(find.descendant(of: eat, matching: find.byKey(const Key('coach-say-ask'))), findsNothing, reason: 'no AI offered for food');
      expect(find.textContaining('water', findRichText: true), findsNothing, reason: 'water is off');
      await tester.tap(find.descendant(of: eat, matching: find.byKey(const Key('coach-avatar-launcher'))));
      await _frames(tester, 800);
      expect(find.byKey(const Key('coach-help-sheet')), findsOneWidget, reason: 'the guide opens the built-in food help');
      expect(recorder.paths.where((p) => p.contains('coach')), isEmpty, reason: 'opening Train and Eat never asks the AI');
    });

    testWidgets('scrolled out of the page and back, the tab coach is simply there: the entrance is not played again', (tester) async {
      await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: _day, food: [foodEntry('f1', _day, 'Lunch', 'Rice', '1 bowl', calories: 400)])))!,
        coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())),
        transportProvider.overrideWithValue(_Recorder()),
      ], size: const Size(390, 640), settle: false);
      await tester.tap(find.byKey(const Key('nav-eat')));
      await _frames(tester, 2500);
      final coach = find.byKey(const Key('eat-coach'));
      expect(coach, findsOneWidget);
      await tester.drag(find.descendant(of: find.byType(EatScreen), matching: find.byType(Scrollable)).first, const Offset(0, -2500));
      await _frames(tester, 600);
      expect(coach, findsNothing, reason: 'out of the lazy list, so built again on the way back');
      await tester.drag(find.byKey(const Key('eat-add-lunch')), const Offset(0, 2500));
      await tester.pump();
      await tester.pump();
      final face = tester.state<CoachCompanionState>(find.descendant(of: coach, matching: find.byType(CoachCompanion)));
      expect(face.pose.value.slide, 1, reason: 'settled at once, no second peek');
    });

    testWidgets('a plan in progress in the builder: Train offers to continue it, opens the builder on it and discards nothing', (tester) async {
      final c = await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: _day)))!,
        coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())),
        transportProvider.overrideWithValue(_Recorder()),
        ..._withDb(),
      ], settle: false);
      final draft = PlanDraft.fresh(today: _day, path: 'custom')..j['title'] = 'My split';
      await tester.runAsync(() => c.read(planRepositoryProvider).saveBuilderDraft(draft));
      c.invalidate(builderDraftProvider);
      await tester.tap(find.byKey(const Key('nav-train')));
      await _frames(tester, 300);
      await tester.tap(find.byKey(const Key('train-plan')));
      await tester.runAsync(() => c.read(builderDraftProvider.future));
      await _frames(tester, 2000);
      expect(find.byKey(const Key('create-plan')), findsNothing, reason: 'not a fresh start while one is in progress');
      await tester.tap(find.byKey(const Key('plan-builder-continue')));
      await _frames(tester, 800);
      expect(tester.widget<PlanBuilder>(find.byType(PlanBuilder)).initial.j['title'], 'My split');
      expect((await tester.runAsync(() => c.read(planRepositoryProvider).builderDraft('new')))?.j['title'], 'My split', reason: 'still saved');
    });

    testWidgets('Show coach on Train and Eat off: Create my plan, Log food and goals stay; the small avatar is the help; Today is unchanged; Reduce Motion on the tabs is still', (tester) async {
      final c = await pumpApp(tester, [
        ...(await tester.runAsync(() => overridesFor(day: _day)))!,
        coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore())),
        devicePrefsStoreProvider.overrideWithValue(DevicePrefsStore(MemorySecretStore())..motion = MotionPref.reduced),
        transportProvider.overrideWithValue(_Recorder()),
      ], settle: false);
      await tester.tap(find.byKey(const Key('nav-train')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('train-plan')));
      await tester.pump();
      await tester.pump();
      final face = tester.state<CoachCompanionState>(find.descendant(of: find.byKey(const Key('train-coach')), matching: find.byType(CoachCompanion)));
      expect((face.pose.value.slide, face.ticking), (1, false), reason: 'Reduce Motion: there at once, nothing moving');

      c.read(coachPrefsProvider.notifier).setOnTabs(false);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('train-coach')), findsNothing);
      expect(find.byKey(const Key('create-plan')), findsOneWidget, reason: 'the way to a plan stays on the page');
      expect(find.byKey(const Key('coach-ask-launcher')), findsOneWidget, reason: 'help: the small avatar');
      await tester.tap(find.byKey(const Key('nav-eat')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('eat-coach')), findsNothing);
      expect(find.byKey(const Key('log-food')), findsOneWidget);
      expect(find.byKey(const Key('eat-goals')), findsOneWidget);
      expect(find.byKey(const Key('coach-help-eat')), findsOneWidget);
      expect(c.read(coachPrefsProvider).onToday, isTrue, reason: 'Today\'s own switch is untouched');
    });

    testWidgets('narrow phones get a smaller guide and large text a taller bubble: the guide never disappears, nothing overflows', (tester) async {
      await _today(tester, size: const Size(320, 640));
      await tester.pump();
      expect(find.byType(CoachCompanion), findsOneWidget);
      expect(_widget(tester).size, const Size(68, 84));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _today(tester, size: const Size(320, 640), textScale: 2);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsOneWidget);
      expect(find.byKey(const Key('coach-avatar-launcher')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('in a help sheet the guide comes in once the sheet is up (it starts below the screen, and nothing scrolls)', (tester) async {
    await pumpApp(tester, [coachPrefsStoreProvider.overrideWithValue(CoachPrefsStore(MemorySecretStore()))], settle: false,
        home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showCoachHelpSheet(context, title: 'Help', say: const CoachSay('Words.')), child: const Text('help')))));
    await tester.tap(find.text('help'));
    await _frames(tester, 2000);
    expect(_state(tester).pose.value.slide, closeTo(1, 0.01), reason: 'the guide beside its words, not left hidden');
  });
}
