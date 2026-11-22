import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/widgets.dart' show ListRow;
import 'package:gohard_rebuild/features/coach/exercise_media.dart' show demoPreview;
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

import 'support.dart';

/// The internal demonstration preview on a device (docs/EXERCISE_DEMOS.md › Internal preview), run by
/// scripts\test-android.ps1 `-Only journey_preview_test`, which builds with GOHARD_DEMO_PREVIEW and keeps the captures
/// in app\build (they show the third-party sample, so they never go to docs\evidence). REAL content: the Exercise
/// Animatic sample from the local slot, decoded by the phone's own player.
///
/// With the sample in the build: the picker's Watch demo only on Bodyweight squat; a manual workout with a recorded set,
/// the rest timer running and typed reps not yet recorded; the recorder's thumbnail opens the preview; it plays (position
/// advances, 1920 x 1080, muted), 0.5×, full screen and back, pauses in the background; closing it leaves the typed
/// reps, the recorded sets, the selection, the rest timer and the clock. Built without the sample (the slot emptied):
/// "Demonstration unavailable" with the preview's own reason, Retry and the written guide, and the workout unchanged.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('internal demonstration preview', (tester) async {
    expect(demoPreview, isTrue, reason: 'run by the script, which builds with --dart-define=GOHARD_DEMO_PREVIEW=true');
    final inBuild = await rootBundle.load(previewClip).then((_) => true, onError: (_) => false);
    debugPrint('GOHARD_PREVIEW: sample ${inBuild ? 'in' : 'NOT in'} this build');
    final j = Journey(tester, binding);

    Future<void> realSurface() => const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    final tag = inBuild ? 'preview' : 'preview-missing';
    Future<void> shot(String name) async {
      await watch(600);
      debugPrint('GOHARD_SHOT:$tag-$name');
      await watch(2500);
    }

    Future<void> waitReal(Finder f, String what, {int seconds = 45}) async {
      for (var i = 0; i < seconds * 4 && f.evaluate().isEmpty; i++) {
        await watch(250);
      }
      expect(f, findsWidgets, reason: what);
    }

    Future<void> tapReal(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await watch(300);
      await tester.tap(find.byKey(Key(key)));
      await watch(600);
    }

    Future<void> closeSheet() async {
      Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet')))).pop();
      await watch(1000);
      expect(find.byKey(const Key('exercise-info-sheet')), findsNothing);
    }

    String field(String key) => tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).controller.text;
    VideoPlayerValue video() => tester.widget<VideoPlayer>(find.byType(VideoPlayer).first).controller.value;

    await j.start('Preview Journey');
    await realSurface();

    // ---- The picker: Watch demo on the exact bodyweight squat only.
    await j.tapKey('nav-train');
    if (find.byKey(const Key('train-workouts')).evaluate().isNotEmpty) await j.tapKey('train-workouts');
    await j.tapKey('start-manual');
    await j.type('manual-title', 'Legs');
    await j.tapKey('manual-add-exercise');
    await j.type('exercise-search', 'squat');
    await j.waitFor(find.byKey(const Key('exercise-demo-bodyweight-squat')), what: 'Watch demo on Bodyweight squat');
    for (final k in ['back-squat', 'goblet-squat', 'bulgarian-split-squat']) {
      expect(find.byKey(Key('exercise-demo-$k')), findsNothing, reason: '$k keeps its written guide');
    }
    await shot('01-picker');
    await tapReal('exercise-demo-bodyweight-squat');
    await waitReal(find.byKey(const Key('demo-play')), 'the poster and Play');
    expect(find.byKey(const Key('demo-preview-note')), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing, reason: 'no autoplay: nothing decodes before Play');
    await shot('02-picker-sheet');
    await closeSheet();
    expect(field('exercise-search'), 'squat', reason: 'the search is kept');
    await j.tap(find.descendant(of: find.byType(ListRow), matching: find.text('Bodyweight squat')));
    await j.tapKey('manual-start');
    await j.waitFor(find.byKey(const Key('complete-set')), what: 'the recorder');

    // ---- Recording: one set, the rest timer running, typed reps not yet recorded.
    await j.type('set-reps', '12');
    await j.tapKey('complete-set');
    // An added movement without a target has no rest timer; when one shows, it is checked below.
    await j.waitFor(find.textContaining('1 set recorded'), what: 'the recorded set');
    await j.type('set-reps', '10');
    FocusManager.instance.primaryFocus?.unfocus();
    await watch(800);
    List<String?> progress() => [for (final e in find.textContaining('recorded').evaluate()) (e.widget as Text).data];
    final recorded = progress();
    expect(recorded, isNotEmpty);
    final pause = tester.widget<Text>(find.descendant(of: find.byKey(const Key('workout-pause')), matching: find.byType(Text))).data;
    int restLeft() {
      final p = tester.widget<Text>(find.byKey(const Key('rest-clock'))).data!.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    await tester.ensureVisible(find.byKey(const Key('workout-demo-thumb')));
    await shot('03-recorder');
    // The workout's elapsed clock: the first m:ss text that is not the rest clock.
    int clockSeconds() {
      final rest = find.byKey(const Key('rest-clock')).evaluate().map((e) => e.widget).toSet();
      final t = find.textContaining(RegExp(r'^\d+:\d\d$')).evaluate().map((e) => e.widget).whereType<Text>().firstWhere((w) => !rest.contains(w));
      final p = t.data!.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final clockBefore = clockSeconds();
    final restBefore = find.byKey(const Key('rest-clock')).evaluate().isEmpty ? null : restLeft();
    debugPrint('GOHARD_PREVIEW: rest timer ${restBefore == null ? 'not shown for this movement' : '$restBefore s left'}');
    final openedAt = DateTime.now();

    await tapReal('workout-demo-thumb');
    await waitReal(find.byKey(const Key('demo-play')), 'the sheet for the selected movement');
    expect(find.byKey(const Key('demo-preview-note')), findsOneWidget);
    expect(find.byKey(const Key('demo-download')), findsNothing, reason: 'the preview is never downloaded');
    await tapReal('demo-play');
    if (inBuild) {
      await waitReal(find.byType(VideoPlayer), 'the player');
      for (var i = 0; i < 120 && !video().isPlaying; i++) {
        await watch(250);
      }
      final a = video().position;
      await watch(2500);
      final v = video();
      expect(v.hasError, isFalse, reason: v.errorDescription);
      expect(v.isPlaying, isTrue);
      expect(v.position, isNot(a), reason: 'the position advances, so frames are being decoded');
      expect((v.size.width, v.size.height), (1920.0, 1080.0), reason: 'decoded at the sample\'s own size');
      expect(v.volume, 0, reason: 'muted');
      final frame = tester.getSize(find.byType(VideoPlayer).first);
      expect((frame.width / frame.height - 16 / 9).abs(), lessThan(0.02), reason: 'shown at its own shape, not stretched or cropped');
      debugPrint('GOHARD_DEMO: position ${v.position.inMilliseconds} ms, size ${v.size}, shown ${frame.width.round()}x${frame.height.round()}');
      await shot('04-playing');
      await tapReal('demo-speed-0.5');
      await watch(1500);
      expect(video().playbackSpeed, 0.5);
      await shot('05-half-speed');
      await tapReal('demo-fullscreen');
      await waitReal(find.byKey(const Key('demo-fullscreen-page')), 'full screen');
      final full = tester.getSize(find.byType(VideoPlayer).last);
      expect((full.width / full.height - 16 / 9).abs(), lessThan(0.02), reason: 'full screen keeps the shape');
      await shot('06-fullscreen');
      await tapReal('demo-exit-fullscreen');
      await waitReal(find.byKey(const Key('demo-toggle')), 'back on the sheet');
      expect(video().isPlaying, isTrue, reason: 'the same playback continues');
      debugPrint('GOHARD_BG:home');
      await watch(9000);
      expect(video().isPlaying, isFalse, reason: 'paused in the background and still paused on return');
      await shot('07-after-background');
      await tapReal('demo-toggle');
      await watch(1500);
      expect(video().isPlaying, isTrue, reason: 'Play resumes it');
    } else {
      await waitReal(find.byKey(const Key('demo-retry')), 'unavailable, with Retry', seconds: 40);
      expect(find.byKey(const Key('demo-unavailable')), findsOneWidget);
      expect(find.text('This preview clip is not in this build. The written guide below is unaffected.'), findsOneWidget);
      expect(find.byKey(const Key('exercise-how-to')), findsOneWidget, reason: 'the written guide stays');
      await shot('04-missing');
    }
    await closeSheet();

    // ---- Nothing in the workout changed.
    expect(field('set-reps'), '10', reason: 'the typed reps are still there, not recorded');
    expect(progress(), recorded, reason: 'no set recorded or removed');
    expect(find.text('Bodyweight squat'), findsWidgets, reason: 'the same movement is selected');
    expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('workout-pause')), matching: find.byType(Text))).data, pause, reason: 'not paused');
    final elapsed = DateTime.now().difference(openedAt).inSeconds;
    if (restBefore != null && find.byKey(const Key('rest-clock')).evaluate().isNotEmpty) {
      expect((restBefore - restLeft() - elapsed).abs(), lessThanOrEqualTo(3), reason: 'the rest timer kept running at its own pace');
    }
    final clockAfter = clockSeconds();
    debugPrint('GOHARD_PREVIEW: workout clock $clockBefore s before, $clockAfter s after ($elapsed s with the demonstration open)');
    expect(clockAfter - clockBefore, greaterThanOrEqualTo(elapsed - 2), reason: 'the workout clock kept running while the demonstration was open');
    await shot('08-recorder-after');
  });
}

const previewClip = 'assets/demos/preview/bodyweight-squat.mp4';
