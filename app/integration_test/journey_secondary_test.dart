import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

/// R5, second native journey: the secondary flows. Manual workout with bodyweight sets, pause, save for later
/// and resume; a no-data finish; plan pause, reviewed resume, skip and stopping the block early; name edit;
/// and password-confirmed account deletion. Real API, real PostgreSQL, a disposable account.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int frames = 4]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder, {String? what, int seconds = 25}) async {
    for (var i = 0; i < seconds * 4; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    final visible = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((s) => s.isNotEmpty).take(30).join(' | ');
    fail('Timed out waiting for ${what ?? finder}. On screen: $visible');
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await settle(tester, 2);
    if (finder.evaluate().isNotEmpty || find.byType(ListView).hitTestable().evaluate().isEmpty) return;
    final list = find.descendant(of: find.byType(ListView).hitTestable().last, matching: find.byType(Scrollable)).first;
    for (final delta in const [300.0, -300.0]) {
      try {
        await tester.scrollUntilVisible(finder, delta, scrollable: list, maxScrolls: 25);
        return;
      } on StateError {
        // Not in that direction; try the other, then let waitFor report it properly.
      }
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // A lazily built list can rebuild between finding and tapping (for example when an acknowledgement lands); retry.
    for (var attempt = 0;; attempt++) {
      try {
        await reveal(tester, finder);
        await waitFor(tester, finder);
        await tester.ensureVisible(finder.first);
        await settle(tester, 2);
        await tester.tap(finder.first, warnIfMissed: false);
        break;
      } on StateError {
        if (attempt == 3) rethrow;
      }
    }
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) => tap(tester, find.byKey(Key(key)));
  Future<void> confirmWith(WidgetTester tester, String label) => tap(tester, find.widgetWithText(FilledButton, label));
  Future<void> type(WidgetTester tester, String key, String text) async {
    await reveal(tester, find.byKey(Key(key)));
    await waitFor(tester, find.byKey(Key(key)));
    await tester.ensureVisible(find.byKey(Key(key)));

    // On a real device the first enterText after a focus change can be dropped; focus first, then verify and retry.
    final field = find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));
    for (var attempt = 0; attempt < 4; attempt++) {
      await tester.tap(find.byKey(Key(key)), warnIfMissed: false);
      await settle(tester, 2);
      await tester.enterText(find.byKey(Key(key)), text);
      await settle(tester, 2);
      if (tester.widget<EditableText>(field).controller.text == text) return;
    }
    fail('Could not type "$text" into $key');
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 3);
    await binding.takeScreenshot(name);
  }

  testWidgets('manual_pause_park_nodata_plan_lifecycle_name_delete', (tester) async {
    final email = 'secondary-${DateTime.now().millisecondsSinceEpoch}@example.test';
    const password = 'secondary password 1';
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await tapKey(tester, 'auth-toggle');
    await type(tester, 'auth-name', 'Second Tester');
    await type(tester, 'auth-email', email);
    await type(tester, 'auth-password', password);
    await tapKey(tester, 'auth-submit');
    await waitFor(tester, find.text('No plan yet'), what: 'Today for a new account');

    // --- Manual workout: bodyweight set with no load typed, pause, save for later, resume, finish.
    await tapKey(tester, 'nav-train');
    await tapKey(tester, 'start-manual');
    await type(tester, 'manual-title', 'Hotel room');
    await tapKey(tester, 'manual-add-exercise');
    await tapKey(tester, 'exercise-push-up');
    await shot(tester, '30-manual-setup');
    await tapKey(tester, 'manual-start');
    await waitFor(tester, find.byKey(const Key('complete-set')));
    await type(tester, 'set-reps', '12');
    await tapKey(tester, 'complete-set');
    await waitFor(tester, find.byKey(const Key('set-row-0')));
    expect(find.textContaining('Bodyweight × 12'), findsWidgets, reason: 'no load typed means bodyweight, not zero typed');
    await tapKey(tester, 'workout-pause');
    await waitFor(tester, find.textContaining('Workout paused'));
    await shot(tester, '31-manual-paused');
    await tapKey(tester, 'workout-pause');
    await tap(tester, find.widgetWithText(TextButton, 'Save for later'));
    await waitFor(tester, find.textContaining('Saved for later'), what: 'the parked workout on Train');
    await shot(tester, '32-train-saved-for-later');
    await tapKey(tester, 'nav-today');
    await waitFor(tester, find.text('No plan yet'));
    expect(find.text('Resume workout'), findsNothing, reason: 'a parked workout does not take over Today');
    expect(find.textContaining('Saved for later'), findsOneWidget, reason: 'but it stays recoverable from Today');
    await tapKey(tester, 'nav-train');
    await tap(tester, find.widgetWithText(TextButton, 'Resume'));
    await waitFor(tester, find.byKey(const Key('set-row-0')), what: 'the resumed workout with its recorded set');
    await tapKey(tester, 'finish-workout');
    await tapKey(tester, 'finish-confirm');
    await waitFor(tester, find.text('Recorded'));
    expect(find.textContaining('does not tick off a planned workout'), findsOneWidget);
    await shot(tester, '33-manual-result');
    await tapKey(tester, 'result-done');

    // --- A finish with no sets is saved honestly as "No training logged".
    await tapKey(tester, 'start-manual');
    await type(tester, 'manual-title', 'Changed my mind');
    await tapKey(tester, 'manual-start');
    await tapKey(tester, 'finish-workout');
    await waitFor(tester, find.text('Save without training'));
    await shot(tester, '34-no-data-finish-review');
    await tapKey(tester, 'finish-confirm');
    await waitFor(tester, find.text('No training logged'));
    await tapKey(tester, 'result-done');

    // --- Plan lifecycle: start, pause, reviewed resume, skip, stop early.
    await tapKey(tester, 'train-plan');
    await tapKey(tester, 'create-plan');
    await waitFor(tester, find.byKey(const Key('setup-submit')));
    final weekday = DateTime.now().weekday;
    final days = {weekday, (weekday + 1) % 7 + 1, (weekday + 3) % 7 + 1};
    for (var d = 1; d <= 7; d++) {
      await reveal(tester, find.byKey(Key('weekday-$d')));
      final checked = tester.widget<CheckboxListTile>(find.byKey(Key('weekday-$d'))).value ?? false;
      if (checked != days.contains(d)) await tapKey(tester, 'weekday-$d');
    }
    await tapKey(tester, 'setup-submit');
    await tapKey(tester, 'plan-start');
    await waitFor(tester, find.byKey(const Key('today-start')));
    await tapKey(tester, 'nav-train');
    await waitFor(tester, find.textContaining('Week 1 of').hitTestable(), what: 'the Plan view actually on screen');

    await tap(tester, find.text('Pause plan'));
    await confirmWith(tester, 'Pause this plan');
    await reveal(tester, find.byKey(const Key('plan-resume')));
    await waitFor(tester, find.byKey(const Key('plan-resume')));
    await shot(tester, '35-plan-paused');
    await tapKey(tester, 'nav-today');
    await waitFor(tester, find.text('Plan paused'));
    expect(find.byKey(const Key('today-start')), findsNothing, reason: 'a paused plan offers no new planned start');
    await tapKey(tester, 'nav-train');
    await tapKey(tester, 'plan-resume');
    await waitFor(tester, find.byKey(const Key('resume-accept')));
    await shot(tester, '36-resume-review');
    await tapKey(tester, 'resume-accept');
    await reveal(tester, find.text('Pause plan'));
    await waitFor(tester, find.text('Pause plan'), what: 'the active plan after resuming');

    await tapKey(tester, 'occasion-1-2');
    await tapKey(tester, 'occasion-skip');
    await shot(tester, '37-skip-confirmation');
    await confirmWith(tester, 'Skip this workout');
    await waitFor(tester, find.text('Undo skip'));
    await tester.tapAt(const Offset(20, 60)); // close the sheet
    await settle(tester, 6);
    await reveal(tester, find.text('Skipped'));
    await waitFor(tester, find.text('Skipped'));
    await shot(tester, '38-plan-with-skipped');

    await tap(tester, find.text('Review or finish this block'));
    await waitFor(tester, find.byKey(const Key('block-stop')));
    await shot(tester, '39-block-review');
    await tapKey(tester, 'block-stop');
    await confirmWith(tester, 'Stop this block');
    await reveal(tester, find.byKey(const Key('create-plan')));
    await waitFor(tester, find.byKey(const Key('create-plan')), what: 'Train with the primary slot free');
    await reveal(tester, find.textContaining('Stopped early'));
    expect(find.textContaining('Stopped early'), findsOneWidget, reason: 'the closed block stays in the list with its real outcome');

    // --- Me: explicit name save, then deletion that refuses a wrong password.
    await tapKey(tester, 'nav-me');
    await tapKey(tester, 'me-edit-name');
    await type(tester, 'name-field', 'Renamed Tester');
    await tapKey(tester, 'name-save');
    await reveal(tester, find.text('Renamed Tester'));
    await waitFor(tester, find.text('Renamed Tester'));
    // History lives in Train, not Me.
    await tapKey(tester, 'nav-train');
    await tapKey(tester, 'train-progress');
    await tap(tester, find.text('Workout history'));
    await waitFor(tester, find.textContaining('No training logged'));
    expect(find.textContaining('Recorded'), findsWidgets);
    await shot(tester, '40-history');
    await tester.pageBack();
    await settle(tester);
    await tapKey(tester, 'nav-me');

    await tapKey(tester, 'me-delete-account');
    await type(tester, 'delete-password', 'not my password');
    await tapKey(tester, 'delete-confirm');
    await confirmWith(tester, 'Delete everything');
    await waitFor(tester, find.textContaining('not correct'));
    await shot(tester, '41-delete-wrong-password');
    await type(tester, 'delete-password', password);
    await tapKey(tester, 'delete-confirm');
    await confirmWith(tester, 'Delete everything');
    await waitFor(tester, find.byKey(const Key('auth-submit')), what: 'the sign-in screen after deletion');
    expect(find.textContaining('were deleted'), findsOneWidget);
    // The account is really gone: the same credentials no longer sign in.
    await type(tester, 'auth-email', email);
    await type(tester, 'auth-password', password);
    await tapKey(tester, 'auth-submit');
    await waitFor(tester, find.textContaining('do not match'));
    await shot(tester, '42-deleted-account-cannot-sign-in');
  });
}
