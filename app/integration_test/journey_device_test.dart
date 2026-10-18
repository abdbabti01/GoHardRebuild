import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/activity/run_walk_screens.dart' show StatFigure;
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// R3/R5, third native journey: the two device capabilities.
///
/// * Reminders: turning them on schedules real OS notifications for the accepted plan's pending workouts;
///   pausing the plan removes them all; signing out removes them too.
/// * GPS: a run measures distance from real location readings (fed to the emulator by scripts\test-android.ps1
///   with `adb emu geo fix`) and saves it with the run.
///
/// The script grants notification and location permission before this runs, because a test cannot tap the
/// system permission dialogs.
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
    // A floating message can sit over the bottom of a list for a few seconds; wait for it rather than tap through it.
    for (var i = 0; i < 28 && find.byType(SnackBar).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    for (var attempt = 0;; attempt++) {
      try {
        await reveal(tester, finder);
        await waitFor(tester, finder);
        await tester.ensureVisible(finder.first);
        await settle(tester, 2);
        // A row can still sit just under the navigation bar; nudge the list until the target can really be tapped.
        for (var i = 0; i < 6 && finder.hitTestable().evaluate().isEmpty && find.byType(ListView).hitTestable().evaluate().isNotEmpty; i++) {
          await tester.drag(find.byType(ListView).hitTestable().last, const Offset(0, -160));
          await settle(tester, 2);
        }
        await tester.tap(finder.first, warnIfMissed: false);
        break;
      } on StateError {
        if (attempt == 3) rethrow;
      }
    }
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) => tap(tester, find.byKey(Key(key)));
  Future<void> type(WidgetTester tester, String key, String text) async {
    await reveal(tester, find.byKey(Key(key)));
    await waitFor(tester, find.byKey(Key(key)));

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

  /// What the operating system actually has scheduled for this app.
  Future<int> scheduled(WidgetTester tester, bool Function(int count) until) async {
    var count = -1;
    for (var i = 0; i < 40; i++) {
      count = (await FlutterLocalNotificationsPlugin().pendingNotificationRequests()).length;
      if (until(count)) break;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return count;
  }

  testWidgets('reminders_follow_the_plan_and_gps_measures_a_run', (tester) async {
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await tapKey(tester, 'auth-toggle');
    await type(tester, 'auth-name', 'Device Tester');
    await type(tester, 'auth-email', 'device-${DateTime.now().millisecondsSinceEpoch}@example.test');
    await type(tester, 'auth-password', 'device password 1');
    await tapKey(tester, 'auth-submit');
    // A new account is offered the coach setup first (docs/COACH.md › Setup); this journey skips it.
    await waitFor(tester, find.byWidgetPredicate((w) => w.key == const Key('setup-skip') || (w is Text && w.data == 'No active plan')), what: 'the setup or Today');
    if (find.byKey(const Key('setup-skip')).evaluate().isNotEmpty) await tapKey(tester, 'setup-skip');
    await waitFor(tester, find.text('No active plan'), what: 'Today for a new account');

    // --- Reminders. With no plan, turning them on schedules nothing.
    await tapKey(tester, 'nav-me');
    await tap(tester, find.descendant(of: find.byKey(const Key('me-reminders')), matching: find.byType(Switch)));
    await waitFor(tester, find.byKey(const Key('me-reminder-time')), what: 'reminders switched on');
    expect(await scheduled(tester, (c) => c == 0), 0, reason: 'no plan means no reminders');
    await binding.takeScreenshot('50-me-reminders-on');

    // An active plan: one reminder per pending workout from today on (today's only if its time has not passed).
    await tapKey(tester, 'nav-train');
    await tapKey(tester, 'train-plan');
    await tapKey(tester, 'create-plan');

    // Create plan: the template path with the suggestion for three days, starting today, activated as it is.

    await Journey(tester, binding).createPlanFromTemplate();

    await tapKey(tester, 'nav-today');
    await waitFor(tester, find.byKey(const Key('today-start')));
    final withPlan = await scheduled(tester, (c) => c >= 23);
    expect(withPlan, anyOf(23, 24), reason: '24 planned workouts in 8 weeks; today\'s is left out once its time has passed');

    // Pausing the plan removes every reminder: no nags while paused.
    await tapKey(tester, 'nav-train');
    await waitFor(tester, find.textContaining('Week 1 of').hitTestable());
    await tap(tester, find.text('Pause plan'));
    await tap(tester, find.widgetWithText(FilledButton, 'Pause this plan'));
    expect(await scheduled(tester, (c) => c == 0), 0, reason: 'a paused plan has no reminders');

    // --- GPS run. The host is feeding the emulator a walk north while this runs.
    await tapKey(tester, 'nav-today');
    final j = Journey(tester, binding);
    await j.startActivity();
    double km() => double.tryParse(tester.widget<StatFigure>(find.byKey(const Key('runwalk-distance'))).value) ?? 0;
    for (var i = 0; i < 240 && km() < 0.03; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();
    }
    final measured = km();
    expect(measured, greaterThanOrEqualTo(0.03), reason: 'distance grows from real location readings. On screen: ${j.onScreen}');
    await binding.takeScreenshot('51-run-gps-distance');

    // Leaving the screen does not end it: Today offers Resume, and the run kept recording meanwhile. (A real process
    // end is journey_coldstart_test and journey_runwalk_test; calling main() again here would leave this process's
    // first app instance running.)
    await tester.pageBack();
    await waitFor(tester, find.widgetWithText(FilledButton, 'Resume'), what: 'the open run on Today');
    await waitFor(tester, find.text('Run in progress'), what: 'still recording while away from its screen');
    await settle(tester, 8); // let the page transition finish before the capture
    await binding.takeScreenshot('51b-today-continue-run');
    await tapKey(tester, 'today-run');
    await waitFor(tester, find.byKey(const Key('runwalk-finish')), what: 'the same run');
    expect(km(), greaterThanOrEqualTo(measured), reason: 'the distance measured before leaving is kept');
    await j.finishAndSaveActivity();
    await waitFor(tester, find.text('Run completed'), what: 'Today with the saved run');
    await waitFor(tester, find.textContaining(' km'), what: 'the finished run with its measured distance on Today');
    await binding.takeScreenshot('52-today-run-with-distance');

    // --- Signing out removes this owner's reminders from the phone (resume first so there are some to remove).
    await tapKey(tester, 'nav-train');
    await tapKey(tester, 'plan-resume');
    await tapKey(tester, 'resume-accept');
    expect(await scheduled(tester, (c) => c >= 23), anyOf(23, 24), reason: 'resuming brings the reminders back');
    await tapKey(tester, 'nav-me');
    await tapKey(tester, 'me-sign-out');
    await tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
    await waitFor(tester, find.byKey(const Key('auth-submit')));
    expect(await scheduled(tester, (c) => c == 0), 0, reason: 'no reminders remain for a signed-out owner');
  });
}
