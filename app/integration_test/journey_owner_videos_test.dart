import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Owner-published exercise videos on a device (docs/OWNER_EXERCISE_VIDEOS.md), two accounts on one phone, run by
/// scripts\test-android.ps1 -Only journey_owner_videos_test against scripts\start-media-local.ps1 -LocalOwner (the API's
/// real Linux image with FFmpeg, an S3-compatible store standing in for R2).
///
/// SIMULATED: choosing the video. A device test cannot tap the system photo picker, so the debug-only
/// GOHARD_TEST_PICK_FILE hands the app a file the runner put on the phone. Everything after that is real: the app
/// uploads it to a signed storage URL, the server's worker converts it with FFmpeg, the preview plays the processed
/// clip, and the published clip streams from the public bucket. The clip is wger clip 79 (Face pull, Goulart, CC BY-SA 4.0),
/// credited as licensed footage, not as the owner's own.
///
/// Owner: Me › Manage exercise videos › Upload video › Face pull › details and rights › Upload › Processing › preview
/// (0.5×, full screen) › Publish to everyone. Viewer (a new account): the picker's Demo plays the owner's video; in a
/// workout, Watch demo plays it and typed values and the clock stay. Owner again: Replace › Publish replacement › Unpublish.
const _ownerEmail = String.fromEnvironment('GOHARD_OWNER_EMAIL');
const _ownerPassword = String.fromEnvironment('GOHARD_OWNER_PASSWORD');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner exercise videos', (tester) async {
    final j = Journey(tester, binding);
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    Future<void> shot(String name) async {
      await watch(700);
      debugPrint('GOHARD_SHOT:$name');
      await watch(2500);
    }

    // Pages build lazily: while waiting, scroll towards the target every two seconds.
    Future<void> waitReal(Finder f, String what, {int seconds = 60}) async {
      for (var i = 0; i < seconds * 4 && f.evaluate().isEmpty; i++) {
        if (i % 8 == 7) await j.reveal(f);
        await watch(250);
      }
      await j.waitFor(f, what: what);
    }

    // The page has its own Publish button: the confirmation is the dialog's.
    Future<void> dialogButton(String label) => j.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(FilledButton, label)));

    String field(String key) => tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).controller.text;

    Future<void> today() async {
      await waitReal(find.byWidgetPredicate((w) => w.key == const Key('setup-skip') || w.key == const Key('nav-me')), 'setup or the app');
      if (find.byKey(const Key('setup-skip')).evaluate().isNotEmpty) await j.tapKey('setup-skip');
      await waitReal(find.byKey(const Key('nav-me')), 'the tabs');
    }

    Future<void> signIn() async {
      await waitReal(find.byKey(const Key('auth-submit')), 'the sign-in page');
      await j.type('auth-email', _ownerEmail);
      await j.type('auth-password', _ownerPassword);
      await j.tapKey('auth-submit');
      await today();
    }

    Future<void> signOut() async {
      await j.tapKey('nav-me');
      await j.tapKey('me-sign-out');
      await j.confirmWith('Sign out');
      await waitReal(find.byKey(const Key('auth-submit')), 'signed out');
    }

    Future<void> openManager() async {
      await j.tapKey('nav-me');
      // Lower on Me than the screen: scroll to it while the server's answer arrives.
      for (var i = 0; i < 30 && find.byKey(const Key('me-manage-videos')).evaluate().isEmpty; i++) {
        await j.reveal(find.byKey(const Key('me-manage-videos')));
        await watch(500);
      }
      await j.tapKey('me-manage-videos');
      await waitReal(find.byKey(const Key('videos-upload')), 'the manager');
    }

    /// Details (licensed footage, credited), Upload, then waits through processing to the preview.
    Future<void> uploadAndProcess({required String prefix, bool fill = true}) async {
      await waitReal(find.byKey(const Key('video-start-upload')), 'the chosen video and its details');
      if (fill) {
        await j.type('video-variant', 'Cable face pull with a rope, standing; side view');
        await j.type('video-creator', 'Goulart');
        // Details from an earlier draft for this exercise are prefilled: switch it on only if it is off.
        if (!tester.widget<SwitchListTile>(find.byKey(const Key('video-licensed'))).value) await j.tapKey('video-licensed');
        await j.type('video-licence', 'CC BY-SA 4.0');
        await j.type('video-licence-url', 'https://creativecommons.org/licenses/by-sa/4.0/');
        await j.type('video-source', 'https://wger.de/en/exercise/222/view-base');
        await j.type('video-notice', 'Transcoded to H.264, muted, by GoHard.');
        FocusManager.instance.primaryFocus?.unfocus();
        if (!(tester.widget<CheckboxListTile>(find.byKey(const Key('video-rights'))).value ?? false)) await j.tapKey('video-rights');
        await shot('$prefix-details');
      }
      await j.tapKey('video-start-upload');
      await waitReal(find.byKey(const Key('video-processing')), 'Processing after the upload', seconds: 120);
      await shot('$prefix-processing');
      await waitReal(find.byKey(const Key('video-ready')), 'the processed preview', seconds: 300);
      await waitReal(find.byKey(const Key('demo-play')), 'the preview player');
      await shot('$prefix-ready');
    }

    Future<void> publish(String prefix) async {
      await j.tapKey('video-publish');
      await dialogButton('Publish');
      await waitReal(find.byKey(const Key('video-unpublish')), 'the published video');
      await shot('$prefix-published');
    }

    await app.main();
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');

    // ---- the owner publishes
    await signIn();
    await openManager();
    await shot('owner-01-manager');
    await j.tapKey('videos-upload');
    await j.type('exercise-search', 'face');
    await j.tapKey('exercise-face-pull');
    await uploadAndProcess(prefix: 'owner-02');
    // The processed result in the existing player: slow and full screen.
    await j.tapKey('demo-play');
    await waitReal(find.byTooltip('Pause demonstration'), 'the processed clip playing');
    await j.tapKey('demo-speed-0.5');
    await j.tapKey('demo-fullscreen');
    await watch(2000);
    await shot('owner-03-preview-fullscreen');
    await j.tapKey('demo-exit-fullscreen');
    await publish('owner-04');
    await tester.pageBack();
    await j.settle();
    await tester.pageBack();
    await j.settle();
    await signOut();

    // ---- an ordinary viewer sees and plays it
    j.email = 'owner-videos-viewer-${DateTime.now().millisecondsSinceEpoch}@example.test';
    await j.tapKey('auth-toggle');
    await j.type('auth-name', 'Viewer');
    await j.type('auth-email', j.email);
    await j.type('auth-password', j.password);
    await j.tapKey('auth-submit');
    await today();
    await j.tapKey('nav-me');
    await j.reveal(find.byKey(const Key('me-sign-out'))); // the Account group is built, so the absence below is real
    await watch(3000);
    expect(find.byKey(const Key('me-manage-videos')), findsNothing, reason: 'an ordinary account never sees management');
    await j.tapKey('nav-today');
    await j.tapKey('today-manual');
    await j.tapKey('manual-add-exercise');
    await j.type('exercise-search', 'face');
    await waitReal(find.byKey(const Key('exercise-demo-face-pull')), 'Demo on Face pull (the owner video, after the catalogue refresh)');
    await shot('viewer-01-picker');
    await j.tapKey('exercise-demo-face-pull');
    await waitReal(find.textContaining('Video by Goulart, CC BY-SA 4.0'), 'the owner video credit');
    await j.tapKey('demo-play');
    await waitReal(find.byTooltip('Pause demonstration'), 'the published clip playing for the viewer');
    await watch(2500);
    await shot('viewer-02-playing');
    Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet')))).pop();
    await watch(800);
    await j.tapKey('exercise-face-pull');
    await j.tapKey('manual-start');
    await waitReal(find.byKey(const Key('workout-demo')), 'the workout');
    await j.type('set-load', '15');
    await j.type('set-reps', '12');
    FocusManager.instance.primaryFocus?.unfocus();
    await j.tapKey('workout-demo');
    await j.tapKey('demo-play');
    await waitReal(find.byTooltip('Pause demonstration'), 'the owner video in the workout');
    await watch(2000);
    Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet')))).pop();
    await watch(1000);
    await j.reveal(find.byKey(const Key('set-load')));
    expect((field('set-load'), field('set-reps')), ('15', '12'), reason: 'typed values kept');
    await j.reveal(find.byKey(const Key('workout-pause')));
    expect(find.descendant(of: find.byKey(const Key('workout-pause')), matching: find.text('Pause')), findsOneWidget, reason: 'the clock still running');
    await shot('viewer-03-workout-after');
    await j.tapText('Save for later');
    await j.settle(6);
    await signOut();

    // ---- the owner replaces, then unpublishes
    await signIn();
    await openManager();
    await j.type('videos-search', 'face');
    await j.tapKey('videos-face-pull');
    await waitReal(find.byKey(const Key('video-pick')), 'the exercise page');
    expect(find.text('Upload a replacement'), findsOneWidget);
    await j.tapKey('video-pick');
    await uploadAndProcess(prefix: 'owner-05', fill: false);
    expect(find.text('Publish replacement'), findsOneWidget);
    await publish('owner-06');
    await j.tapKey('video-unpublish');
    await dialogButton('Unpublish');
    await waitReal(find.textContaining('No demonstration yet'), 'the fallback after unpublishing');
    await shot('owner-07-unpublished');
  });
}
