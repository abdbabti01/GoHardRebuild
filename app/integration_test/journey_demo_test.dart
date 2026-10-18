import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support.dart';

/// Exercise demonstrations on a device (docs/EXERCISE_DEMOS.md), in two runs of this file by scripts\test-android.ps1
/// (`-Only journey_demo_test`). REAL content: the bench press clip is the reviewed wger clip 22 (CC BY-SA 4.0,
/// Goulart), streamed from wger.de and then downloaded; nothing is a sample video. The host answers the journey's
/// markers: `GOHARD_SHOT:<name>` (adb screencap, so the native video surface is in the picture), GOHARD_REC:start/stop
/// (adb screenrecord), GOHARD_BG:home (Home, then the app again) and GOHARD_NET:off/on (Wi-Fi and data).
///
/// Phase 1 (online): the picker's Demo previews without choosing and keeps the search; a movement with no clip says
/// so; the builder's Watch demonstration keeps typed sets and notes; recording a workout with the rest timer running,
/// Demo on the movement actually selected plays the real clip, 0.5×, full screen and back, pauses when the app goes to
/// the background, and downloads; closing it leaves the typed weight and reps, the rest timer and the running clock.
///
/// Phase 2 (a new process, the network OFF): the downloaded clip plays from the phone; the typed values came back with
/// the workout; a clip that was never downloaded says "Demonstration unavailable" with Retry and the guide still there.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exercise demonstrations', (tester) async {
    final j = Journey(tester, binding);
    final account = File('${(await getApplicationDocumentsDirectory()).path}/demo-journey-account.txt');
    final phase = await account.exists() ? '2' : '1';
    debugPrint('GOHARD_DEMO_PHASE:$phase');

    // Shows the real screen again (Journey.start turns it into an image for takeScreenshot), so the host's captures
    // and recording see the video. Captures here are the host's, never takeScreenshot.
    Future<void> realSurface() => const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    Future<void> shot(String name) async {
      await watch(600);
      debugPrint('GOHARD_SHOT:$name');
      await watch(2500); // the host's screencap and pull
    }

    Future<void> waitReal(Finder f, String what, {int seconds = 45}) async {
      for (var i = 0; i < seconds * 4 && f.evaluate().isEmpty; i++) {
        await watch(250);
      }
      await j.waitFor(f, what: what);
    }

    Future<void> closeTopSheet(String key) async {
      Navigator.of(tester.element(find.byKey(Key(key)))).pop();
      await watch(800);
    }

    String field(String key) => tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).controller.text;
    bool playing() => find.byTooltip('Pause demonstration').evaluate().isNotEmpty;

    if (phase == '1') {
      await j.start('Demo Journey');
      await account.writeAsString(j.email);
      await realSurface();

      // ---- the picker: Demo previews, chooses nothing, keeps the search
      await j.tapKey('today-manual');
      await j.tapKey('manual-add-exercise');
      await j.type('exercise-search', 'bench');
      await j.waitFor(find.byKey(const Key('exercise-demo-bench-press')), what: 'Demo on the bench press row');
      await shot('demo-01-picker');
      await j.tapKey('exercise-demo-bench-press');
      await j.waitFor(find.byKey(const Key('demo-play')), what: 'the poster and Play');
      await shot('demo-02-picker-preview');
      await closeTopSheet('exercise-info-sheet');
      expect(field('exercise-search'), 'bench', reason: 'the search is kept');
      expect(find.byKey(const Key('exercise-bench-press')), findsOneWidget);
      // A movement with no reviewed clip: the guide, and a plain "no demonstration".
      await j.tapKey('exercise-about-bench-dip');
      await j.waitFor(find.text('No demonstration for this exercise yet.'), what: 'the honest fallback');
      await shot('demo-03-no-demonstration');
      await closeTopSheet('exercise-info-sheet');
      await tester.pageBack();
      await j.settle();
      expect(find.textContaining('None yet.'), findsOneWidget, reason: 'previewing chose nothing');
      await tester.pageBack();
      await j.settle();

      // ---- the builder: Watch demonstration over the prescription form keeps what was typed
      await j.tapKey('today-create-plan');
      await j.tapKey('plan-path-direct');
      await j.tapKey('plan-path-template');
      await j.chooseDays(Journey.daysIncludingToday());
      await j.tapKey('builder-next');
      await j.waitFor(find.byKey(const Key('template-full-body')), what: 'the template list');
      await j.tapKey('builder-next');
      await j.tapKey('exercise-0-1'); // Full body A: bench press
      await j.type('rx-sets', '4');
      await j.type('rx-notes', 'Pause on the chest');
      FocusManager.instance.primaryFocus?.unfocus();
      await j.tapKey('rx-demo');
      await j.waitFor(find.byKey(const Key('demo-play')), what: 'the sheet over the form');
      await shot('demo-04-builder-sheet');
      await closeTopSheet('exercise-info-sheet');
      expect((field('rx-sets'), field('rx-notes')), ('4', 'Pause on the chest'), reason: 'the draft survived');
      await j.tapKey('rx-save');
      await j.tapKey('builder-next');
      await j.tapKey('plan-activate');
      await j.waitFor(find.byKey(const Key('train-plan')), what: 'Train after activating');
      await j.tapKey('nav-today');

      // ---- recording: a set, the rest running, then the selected movement's demonstration
      await j.tapKey('today-start');
      await j.waitFor(find.byKey(const Key('complete-set')), what: 'the workout');
      await j.tapKey('workout-demo'); // back squat: no clip, the guide
      await j.waitFor(find.byKey(const Key('exercise-info-sheet')), what: 'the back squat guide');
      expect(find.byKey(const Key('demo-play')), findsNothing);
      await closeTopSheet('exercise-info-sheet');
      await j.type('set-load', '60');
      await j.type('set-reps', '5');
      FocusManager.instance.primaryFocus?.unfocus();
      await j.tapKey('complete-set');
      await j.waitFor(find.byKey(const Key('rest-clock')), what: 'the rest timer');
      await j.tapKey('exercise-row-2');
      // The row says it is current (the panel at the top may be out of the lazily built list here).
      await j.waitFor(find.descendant(of: find.byKey(const Key('exercise-row-2')), matching: find.textContaining('· current')), what: 'bench press selected');
      await j.type('set-load', '62.5');
      await j.type('set-reps', '8');
      FocusManager.instance.primaryFocus?.unfocus();
      await watch(800);
      debugPrint('GOHARD_REC:start:demo-recording');
      await watch(1500);
      await j.tapKey('workout-demo');
      await j.waitFor(find.byKey(const Key('demo-play')), what: 'Play');
      await j.tapKey('demo-play');
      await waitReal(find.byTooltip('Pause demonstration'), 'the real clip playing (streamed from wger.de)');
      await watch(3000);
      await shot('demo-05-playing');
      await j.tapKey('demo-speed-0.5');
      await watch(2500);
      await shot('demo-06-half-speed');
      await j.tapKey('demo-fullscreen');
      await j.waitFor(find.byKey(const Key('demo-fullscreen-page')), what: 'full screen');
      await watch(2500);
      await shot('demo-07-fullscreen');
      await j.tapKey('demo-exit-fullscreen');
      await watch(1500);
      expect(playing(), isTrue, reason: 'back from full screen, still the same playback');

      // Home and back: the clip is paused and stays paused until Play.
      debugPrint('GOHARD_BG:home');
      var left = false;
      for (var i = 0; i < 160; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final s = WidgetsBinding.instance.lifecycleState;
        if (s != AppLifecycleState.resumed) left = true;
        if (left && s == AppLifecycleState.resumed) break;
      }
      expect(left, isTrue, reason: 'the app really went to the background');
      await watch(1500);
      expect(playing(), isFalse, reason: 'paused by going to the background');
      await shot('demo-08-after-background');

      await j.tapKey('demo-download');
      await waitReal(find.textContaining('Downloaded on this phone'), 'the download (1.4 MB from wger.de)', seconds: 90);
      await shot('demo-09-downloaded');
      await closeTopSheet('exercise-info-sheet');
      debugPrint('GOHARD_REC:stop');
      await watch(4000);

      // The workout is a lazily built list: bring each part into view before checking it.
      await j.reveal(find.byKey(const Key('set-load')));
      expect((field('set-load'), field('set-reps')), ('62.5', '8'), reason: 'typed values kept');
      await j.reveal(find.byKey(const Key('rest-clock')));
      expect(find.byKey(const Key('rest-clock')), findsOneWidget, reason: 'the rest timer still running');
      await j.reveal(find.byKey(const Key('workout-pause')));
      expect(find.descendant(of: find.byKey(const Key('workout-pause')), matching: find.text('Pause')), findsOneWidget, reason: 'the workout was not paused');
      expect(find.textContaining(RegExp(r'^1 of \d+ planned sets recorded')), findsOneWidget, reason: 'nothing else recorded');
      await shot('demo-10-workout-after');
      return;
    }

    // ---- phase 2: a new process, the network off
    debugPrint('GOHARD_NET:off');
    await Future<void>.delayed(const Duration(seconds: 6));
    try {
      await app.main();
      await realSurface();
      // The app may reopen the workout that was in front, or show Today with Resume.
      await j.waitFor(find.byWidgetPredicate((w) => w.key == const Key('today-resume') || w.key == const Key('workout-pause')), what: 'Today or the workout');
      if (find.byKey(const Key('workout-pause')).evaluate().isEmpty) await j.tapKey('today-resume');
      await j.reveal(find.byKey(const Key('set-load')));
      await j.waitFor(find.byKey(const Key('set-load')), what: 'the workout again');
      expect((field('set-load'), field('set-reps')), ('62.5', '8'), reason: 'the typed values came back with the workout');
      await j.tapKey('workout-demo');
      await j.waitFor(find.textContaining('Downloaded on this phone'), what: 'the saved clip, offline');
      await j.tapKey('demo-play');
      await waitReal(find.byTooltip('Pause demonstration'), 'the downloaded clip playing with no network');
      await watch(3000);
      await shot('demo-11-offline-replay');
      await closeTopSheet('exercise-info-sheet');

      // A clip never downloaded, offline: unavailable, with Retry, and the guide still readable.
      await j.tapKey('workout-menu');
      await j.tapText('Add a movement');
      await j.type('exercise-search', 'dip');
      await j.tapKey('exercise-demo-dip');
      await j.tapKey('demo-play');
      await waitReal(find.text('Demonstration unavailable'), 'the offline failure', seconds: 40);
      expect(find.byKey(const Key('demo-retry')), findsOneWidget);
      expect(find.text('How to do it'), findsOneWidget);
      await shot('demo-12-offline-unavailable');
      await closeTopSheet('exercise-info-sheet');
    } finally {
      debugPrint('GOHARD_NET:on');
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  });
}
