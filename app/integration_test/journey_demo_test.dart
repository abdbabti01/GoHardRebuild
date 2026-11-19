import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/widgets.dart' show ListRow;
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

import 'support.dart';

/// Exercise demonstrations on a device (docs/EXERCISE_DEMOS.md), one compact run by scripts\test-android.ps1
/// (`-Only journey_demo_test`) against a local API. REAL content: the bench press clip is the reviewed wger clip 22
/// (CC BY-SA 4.0, Goulart), streamed from wger.de, decoded by the phone's own player, then downloaded; nothing is a
/// sample video and nothing is faked. The host answers the markers: `GOHARD_SHOT:<name>` (adb screencap, so the native
/// video surface is in the picture), GOHARD_BG:home (Home, then the app again) and GOHARD_NET:off/on (Wi-Fi and data).
///
/// The picker's Watch demo previews without choosing and keeps the search; a manual workout with a recorded set, the
/// rest timer running and an unsaved typed weight; the recorder's thumbnail opens the movement actually selected; the
/// real clip plays (its position advances, decoded at 640 x 352), 0.5×, full screen and back, pauses when the app goes
/// to the background, and downloads; closing it leaves the typed weight, the recorded sets, the rest timer and the
/// clock. Offline: the downloaded clip plays from the phone and the credit is there; after Remove download it says
/// "Demonstration unavailable" with Retry and the guide; back online, Retry plays it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exercise demonstrations', (tester) async {
    final j = Journey(tester, binding);

    // Shows the real screen again (Journey.start turns it into an image for takeScreenshot), so the host's captures
    // see the video.
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
      expect(f, findsWidgets, reason: what);
    }

    Future<void> closeSheet(String key) async {
      Navigator.of(tester.element(find.byKey(Key(key)))).pop();
      await watch(1000);
      expect(find.byKey(Key(key)), findsNothing, reason: 'the sheet closed');
    }

    Future<void> tapReal(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await watch(300);
      await tester.tap(find.byKey(Key(key)));
      await watch(600);
    }

    String field(String key) => tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).controller.text;
    VideoPlayerValue video() => tester.widget<VideoPlayer>(find.byType(VideoPlayer).first).controller.value;

    /// The phone's own player decoded the real clip and its position moves.
    Future<void> expectPlaying(String what) async {
      await waitReal(find.byType(VideoPlayer), '$what: the player');
      for (var i = 0; i < 120 && !video().isPlaying; i++) {
        await watch(250);
      }
      final a = video().position;
      await watch(2500);
      final v = video();
      expect(v.hasError, isFalse, reason: '$what: ${v.errorDescription}');
      expect(v.isPlaying, isTrue, reason: '$what: playing');
      expect(v.position, isNot(a), reason: '$what: the position advances, so frames are being decoded');
      expect((v.size.width, v.size.height), (640.0, 352.0), reason: '$what: decoded at the clip\'s own size');
      expect(v.volume, 0, reason: '$what: muted');
      debugPrint('GOHARD_DEMO:$what position ${v.position.inMilliseconds} ms, size ${v.size}, speed ${v.playbackSpeed}');
    }

    await j.start('Demo Journey');
    await realSurface();

    // ---- The picker: Watch demo previews, chooses nothing and keeps the search.
    await j.tapKey('nav-train');
    if (find.byKey(const Key('train-workouts')).evaluate().isNotEmpty) await j.tapKey('train-workouts');
    await j.tapKey('start-manual');
    await j.type('manual-title', 'Push');
    await j.tapKey('manual-add-exercise');
    await j.type('exercise-search', 'bench');
    await j.waitFor(find.byKey(const Key('exercise-demo-bench-press')), what: 'Watch demo on the bench press row');
    await shot('demo-01-picker');
    await tapReal('exercise-demo-bench-press');
    await waitReal(find.byKey(const Key('demo-play')), 'the poster and Play');
    await shot('demo-02-picker-sheet');
    await closeSheet('exercise-info-sheet');
    expect(field('exercise-search'), 'bench', reason: 'the search is kept');
    await j.tap(find.descendant(of: find.byType(ListRow), matching: find.text('Bench press')));
    await j.tapKey('manual-start');
    await j.waitFor(find.byKey(const Key('complete-set')), what: 'the recorder');

    // ---- Recording: one set, the rest timer running, a typed weight not yet recorded.
    await j.type('set-load', '60');
    await j.type('set-reps', '8');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('rest-clock')), what: 'rest after the recorded set');
    await j.type('set-load', '62.5');
    FocusManager.instance.primaryFocus?.unfocus();
    await watch(800);
    List<String?> progress() => [for (final e in find.textContaining('recorded').evaluate()) (e.widget as Text).data];
    final recorded = progress();
    expect(recorded, isNotEmpty, reason: 'the sets-recorded line');
    final pause = tester.widget<Text>(find.descendant(of: find.byKey(const Key('workout-pause')), matching: find.byType(Text))).data;
    int restLeft() {
      final p = tester.widget<Text>(find.byKey(const Key('rest-clock'))).data!.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    await tester.ensureVisible(find.byKey(const Key('workout-demo-thumb')));
    await shot('demo-03-recorder');
    final restBefore = restLeft();
    final openedAt = DateTime.now();

    // ---- The recorder's thumbnail: the real clip, 0.5×, full screen, background, download.
    await tapReal('workout-demo-thumb');
    await waitReal(find.byKey(const Key('demo-play')), 'the sheet for the selected movement');
    expect(find.byKey(const Key('exercise-variant')), findsOneWidget);
    await tapReal('demo-play');
    await expectPlaying('streamed');
    await shot('demo-04-playing');
    await tapReal('demo-speed-0.5');
    await watch(1000);
    expect(video().playbackSpeed, 0.5);
    await shot('demo-05-half-speed');
    await tapReal('demo-fullscreen');
    await waitReal(find.byKey(const Key('demo-fullscreen-page')), 'full screen');
    await shot('demo-06-fullscreen');
    await tapReal('demo-exit-fullscreen');
    await waitReal(find.byKey(const Key('demo-toggle')), 'back on the sheet');
    expect(video().isPlaying, isTrue, reason: 'the same playback continues');
    debugPrint('GOHARD_BG:home');
    await watch(9000);
    expect(video().isPlaying, isFalse, reason: 'paused when the app went to the background, and it stays paused');
    await tapReal('demo-download');
    await waitReal(find.byKey(const Key('demo-remove')), 'downloaded', seconds: 90);
    await shot('demo-07-downloaded');
    await closeSheet('exercise-info-sheet');

    // ---- Nothing in the workout changed.
    expect(field('set-load'), '62.5', reason: 'the typed weight is still there, not recorded');
    expect(progress(), recorded, reason: 'no set recorded or removed');
    expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('workout-pause')), matching: find.byType(Text))).data, pause, reason: 'the workout was not paused');
    final elapsed = DateTime.now().difference(openedAt).inSeconds;
    if (find.byKey(const Key('rest-clock')).evaluate().isNotEmpty) {
      expect((restBefore - restLeft() - elapsed).abs(), lessThanOrEqualTo(3), reason: 'the rest timer kept running at its own pace');
    }

    // ---- Offline: the downloaded clip plays from the phone and the credit is there.
    debugPrint('GOHARD_NET:off');
    await watch(5000);
    await tapReal('workout-demo-thumb');
    await waitReal(find.byKey(const Key('demo-play')), 'the sheet offline');
    await tapReal('demo-play');
    await expectPlaying('offline from the download');
    await shot('demo-08-offline-replay');
    await tester.scrollUntilVisible(find.byKey(const Key('exercise-demo-credit')), 300, scrollable: find.byType(Scrollable).last);
    await shot('demo-09-offline-credit');
    await tester.scrollUntilVisible(find.byKey(const Key('demo-remove')), -300, scrollable: find.byType(Scrollable).last);
    await tapReal('demo-remove');
    await waitReal(find.byKey(const Key('demo-play')), 'back to the poster after Remove download');
    await tapReal('demo-play');
    await waitReal(find.byKey(const Key('demo-retry')), 'unavailable offline, with Retry', seconds: 40);
    expect(find.byKey(const Key('demo-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('exercise-how-to')), findsOneWidget, reason: 'the written guide stays');
    await shot('demo-10-offline-unavailable');

    // ---- Online again: Retry plays it.
    debugPrint('GOHARD_NET:on');
    await watch(8000);
    await tapReal('demo-retry');
    await expectPlaying('after Retry');
    await shot('demo-11-retry-playing');
    await closeSheet('exercise-info-sheet');
    expect(field('set-load'), '62.5');
    expect(progress(), recorded);
  });
}
