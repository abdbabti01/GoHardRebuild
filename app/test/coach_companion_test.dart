import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/device_prefs.dart';
import 'package:gohard_rebuild/data/session.dart';
import 'package:gohard_rebuild/features/coach/coach_avatar.dart';
import 'package:gohard_rebuild/features/coach/coach_companion.dart';
import 'package:gohard_rebuild/features/coach/coach_prefs.dart';
import 'package:gohard_rebuild/features/coach/coach_rig.dart';

import 'ui_support.dart';

/// The Today companion (docs/COACH.md › Companion): when it greets, that it never replays, hiding it for the day,
/// Reduce Motion, pausing, both guides, the missing-texture fallback, the one acknowledgement of a saved workout and
/// that none of it asks the AI. Rendering itself is reviewed in docs/evidence/coach (coach_rig_render_test.dart).

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

CoachCompanionState _state(WidgetTester tester) => tester.state<CoachCompanionState>(find.byType(CoachCompanion, skipOffstage: false));
CoachCompanion _widget(WidgetTester tester) => tester.widget<CoachCompanion>(find.byType(CoachCompanion, skipOffstage: false));

/// Real frames for [ms] milliseconds.
Future<void> _frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('daily greeting eligibility', () {
    test('once per local day per account on this phone; another account or day is new; hints off never greet', () {
      var p = const CoachPrefs();
      expect(p.mayGreet('one', '2026-10-11'), isTrue);
      p = p.copy(greeted: CoachPrefs.dayKey('one', '2026-10-11'));
      expect(p.mayGreet('one', '2026-10-11'), isFalse, reason: 'already greeted today');
      expect(p.mayGreet('two', '2026-10-11'), isTrue, reason: 'another account on the same phone');
      expect(p.mayGreet('one', '2026-10-12'), isTrue, reason: 'the next local day');
      expect(p.copy(hintsEnabled: false).mayGreet('one', '2026-10-12'), isFalse, reason: 'coaching hints off: no proactive greeting');
      p = p.copy(hidden: CoachPrefs.dayKey('one', '2026-10-11'));
      expect(p.hiddenOn('one', '2026-10-11'), isTrue);
      expect(p.hiddenOn('one', '2026-10-12'), isFalse, reason: 'hidden for that day only');
    });

    test('Show coach on Today, the greeting day and the hidden day survive a restart; the guide and hints are kept', () async {
      final phone = MemorySecretStore();
      final store = CoachPrefsStore(phone)..value = const CoachPrefs(guide: CoachGuide.leona, hintsEnabled: false, onToday: false, greeted: 'one|2026-10-11', hidden: 'one|2026-10-11');
      await store.save();
      final back = CoachPrefsStore(phone);
      await back.restore();
      expect(back.value, store.value);
      final old = CoachPrefsStore(MemorySecretStore());
      await old.restore();
      expect(old.value.onToday, isTrue, reason: 'on by default, also for a preference saved before this setting existed');
    });
  });

  group('Today', () {
    testWidgets('opening Today greets once, asks the AI nothing, and says a grounded line under the greeting', (tester) async {
      final recorder = _Recorder();
      final c = await _today(tester, recorder: recorder);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsOneWidget);
      await _frames(tester, 100);
      expect(c.read(coachPrefsProvider).greeted, CoachPrefs.dayKey(c.read(ownerProvider)!, _day), reason: 'marked as soon as it starts');
      expect(_state(tester).pose.value.slide, lessThan(1), reason: 'peeking in, not snapped into place');
      await _frames(tester, 1800);
      expect(find.text('Upper body A is planned today.'), findsOneWidget);
      expect(find.byKey(const Key('today-ask')), findsOneWidget);
      expect(recorder.paths.where((p) => p.contains('coach')), isEmpty, reason: 'greeting and line are worked out on the phone');
    });

    testWidgets('no replay: a rebuild, a tab change, a sync and the app returning show the settled portrait at once', (tester) async {
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

      // Restart on the same day: still no greeting.
      final again = c.read(coachPrefsStoreProvider);
      await tester.pumpWidget(const SizedBox());
      await _today(tester, coach: again);
      await tester.pump();
      expect(_widget(tester).greet, isFalse);
    });

    testWidgets('a tap plays one short acknowledgement; rapid taps blend instead of stacking', (tester) async {
      await _today(tester);
      await _frames(tester, 11000);
      for (var i = 0; i < 5; i++) {
        await tester.tapAt(tester.getTopLeft(find.byKey(const Key('today-coach'))) + const Offset(46, 25)); // the face
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
    });

    testWidgets('Hide coach for today tucks it away; Ask GoHard stays; it is back the next day', (tester) async {
      final c = await _today(tester);
      await _frames(tester, 2000);
      await tester.tap(find.byTooltip('Hide coach for today'));
      await _frames(tester, 600);
      expect(find.byType(CoachCompanion), findsNothing);
      expect(c.read(coachPrefsProvider).hiddenOn(c.read(ownerProvider)!, _day), isTrue);
      expect(find.byKey(const Key('today-ask')), findsOneWidget, reason: 'Ask GoHard stays');

      final store = c.read(coachPrefsStoreProvider);
      await tester.pumpWidget(const SizedBox());
      await _today(tester, coach: store);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsNothing, reason: 'hidden survives a restart that day');

      await tester.pumpWidget(const SizedBox());
      await _today(tester, coach: store, day: '2026-10-12');
      await tester.pump();
      expect(find.byType(CoachCompanion), findsOneWidget, reason: 'the next day');
    });

    testWidgets('Show coach on Today off: no portrait, the time-of-day icon is back, Ask GoHard stays', (tester) async {
      final c = await _today(tester);
      c.read(coachPrefsProvider.notifier).setOnToday(false);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsNothing);
      expect(find.byKey(const Key('today-ask')), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined).evaluate().isNotEmpty || find.byIcon(Icons.nightlight_outlined).evaluate().isNotEmpty, isTrue);
    });

    testWidgets('Reduce Motion: a still, settled portrait at once; no frames, no blinking; the greeting counts as shown', (tester) async {
      final c = await _today(tester, device: DevicePrefsStore(MemorySecretStore())..motion = MotionPref.reduced);
      await tester.pump();
      await tester.pump();
      expect(_state(tester).pose.value.slide, 1);
      expect(_state(tester).pose.value.blink, 0);
      expect(_state(tester).ticking, isFalse);
      expect(c.read(coachPrefsProvider).greeted, isNotNull);
      await tester.tapAt(tester.getTopLeft(find.byKey(const Key('today-coach'))) + const Offset(46, 25)); // the face
      await tester.pump();
      expect(_state(tester).ticking, isFalse, reason: 'no acknowledgement motion either');
      await tester.tap(find.byTooltip('Hide coach for today'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CoachCompanion), findsNothing, reason: 'hidden at once, without the tuck');
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

    testWidgets('Reduce Motion switched on during the tuck: it has left at once and the day is recorded as hidden', (tester) async {
      final c = await _today(tester);
      await _frames(tester, 2000);
      await tester.tap(find.byTooltip('Hide coach for today'));
      await _frames(tester, 80);
      c.read(devicePrefsProvider.notifier).setMotion(MotionPref.reduced);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CoachCompanion), findsNothing);
      expect(c.read(coachPrefsProvider).hiddenOn(c.read(ownerProvider)!, _day), isTrue);
    });

    testWidgets('Hide right after an acknowledgement still tucks it away and records the day', (tester) async {
      final c = await _today(tester);
      await _frames(tester, 4500);
      await tester.tapAt(tester.getTopLeft(find.byKey(const Key('today-coach'))) + const Offset(46, 25));
      await _frames(tester, 2500);
      await tester.tap(find.byKey(const Key('today-coach-hide')));
      await _frames(tester, 1500);
      expect(find.byType(CoachCompanion), findsNothing);
      expect(c.read(coachPrefsProvider).hidden, isNotNull);
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
      expect(find.text('Your workout is saved. Nice work.'), findsOneWidget);
      expect(c.read(workoutSavedProvider)!.played, isTrue);
      expect(_state(tester).ticking, isTrue, reason: 'the acknowledgement plays');
      await _frames(tester, 11000);
      expect(_state(tester).ticking, isFalse);
      c.invalidate(dailySnapshotProvider);
      await tester.pump();
      await tester.pump();
      expect(_state(tester).ticking, isFalse, reason: 'no second celebration');
    });

    testWidgets('narrow phones and large text drop the portrait before any words', (tester) async {
      await _today(tester, size: const Size(320, 640));
      await tester.pump();
      expect(find.byType(CoachCompanion), findsNothing);
      expect(find.byKey(const Key('today-ask')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _today(tester, textScale: 1.6);
      await tester.pump();
      expect(find.byType(CoachCompanion), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
