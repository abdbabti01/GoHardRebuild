import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Evidence run for the Today companion (docs/COACH.md › Companion), not part of the regular suite: the real app on a
/// device, three new accounts (the greeting is once per account per day, so a new account is a genuine first greeting).
/// Prints `GOHARD_REC:start:<name>` / `GOHARD_REC:stop` around each part worth recording and `GOHARD_REC:home` when the
/// host should press Home and bring the app back (scripts record with `adb screenrecord`; see PROGRESS_LEDGER).
///
///   1. leon       Leon's entrance, greeting, blink, a tap's acknowledgement
///   2. scroll     scrolling Today and switching tabs: no replay; the weather sky moving beside the companion
///   3. return     the app sent to the background and brought back: no replay
///   4. leon-hide  Hide coach for today
///   5. leona      the same sequence for Leona
///   6. reduced    Motion › Reduced: a still portrait, hidden without the tuck
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('companion: both guides, scrolling, tabs, return, reduced motion', (tester) async {
    final j = Journey(tester, binding);
    // Real time passes (on a device pump() does not wait), so the recording sees the motion.
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    Future<void> rec(String name, Future<void> Function() body) async {
      debugPrint('GOHARD_REC:start:$name');
      await watch(1500); // screenrecord needs a moment to start
      await body();
      await watch(2500); // screenrecord drops the last moments when stopped: keep the ending well inside
      debugPrint('GOHARD_REC:stop');
      await watch(1500);
    }

    Future<void> signUpAgain(String name) async {
      await j.tapKey('nav-me');
      await tester.scrollUntilVisible(find.byKey(const Key('me-sign-out')), 300, scrollable: find.byType(Scrollable).hitTestable().first);
      await j.tapKey('me-sign-out');
      await j.settle(4);
      if (find.text('Sign out').evaluate().length > 1) await j.tap(find.text('Sign out').last); // the confirmation
      await j.settle(4);
      await j.tapKey('auth-toggle');
      await j.type('auth-name', name);
      await j.type('auth-email', '${name.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}@example.test');
      await j.type('auth-password', j.password);
    }

    Future<void> greetAckHide(String name, {required bool hide}) async {
      await rec(name, () async {
        await j.tapKey('auth-submit');
        // Landing on Today: the companion peeks in and greets by itself.
        await watch(4500);
        await tester.tapAt(tester.getTopLeft(find.byKey(const Key('today-coach'))) + const Offset(46, 25)); // the face
        await watch(2500);
        if (hide) {
          await tester.tap(find.byKey(const Key('today-coach-hide')));
          await watch(1500);
          expect(find.byKey(const Key('today-coach')), findsNothing, reason: 'hidden for today');
          expect(find.byKey(const Key('today-ask')), findsOneWidget, reason: 'Ask GoHard stays');
        }
      });
    }

    // --- Account 1, Leon. The weather scene first, so the sky moves beside the companion.
    await j.start('Bob Rivera');
    // start() turns the Flutter surface into a still image for screenshots; screenrecord needs the live surface back.
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.tapKey('appearance-today-background');
    await j.tapKey('today-background-weather');
    await j.tapKey('weather-location-city');
    await j.type('city-search-field', 'Halifax');
    await j.tapKey('city-search-go');
    await j.waitFor(find.textContaining('Nova Scotia'), what: 'Halifax in the results', seconds: 30);
    await j.tap(find.textContaining('Nova Scotia').first);
    await j.settle(4);
    await tester.pageBack();
    await j.settle(2);
    await tester.pageBack();
    await j.settle(2);
    // A new account for the recorded first greeting (this one has already been greeted on landing).
    await signUpAgain('Bob Leon');
    await greetAckHide('leon', hide: false);

    await rec('scroll', () async {
      final list = find.byType(Scrollable).hitTestable().first;
      for (final dy in [-220.0, -220.0, 220.0, 220.0]) {
        await tester.drag(list, Offset(0, dy));
        await watch(1200);
      }
      for (final tab in ['nav-train', 'nav-eat', 'nav-today', 'nav-me', 'nav-today']) {
        await tester.tap(find.byKey(Key(tab)));
        await watch(1500);
      }
      await watch(4000); // the sky keeps moving; the companion rests
    });

    await rec('return', () async {
      debugPrint('GOHARD_REC:home'); // the host presses Home, waits, and brings the app back
      await watch(9000);
    });

    await rec('leon-hide', () async {
      await tester.tap(find.byKey(const Key('today-coach-hide')));
      await watch(2000);
    });
    expect(find.byKey(const Key('today-coach')), findsNothing);
    expect(find.byKey(const Key('today-ask')), findsOneWidget);

    // --- Account 2, Leona.
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await tester.scrollUntilVisible(find.byKey(const Key('coach-leona')), 300, scrollable: find.byType(Scrollable).hitTestable().last);
    await j.tapKey('coach-leona');
    await tester.pageBack();
    await j.settle(2);
    await signUpAgain('Ana Leona');
    await greetAckHide('leona', hide: true);

    // --- Account 3, Reduced motion.
    await j.tapKey('nav-me');
    await j.tapKey('me-motion');
    await j.tapKey('motion-reduced');
    await tester.pageBack();
    await j.settle(2);
    await signUpAgain('Rae Reduced');
    await greetAckHide('reduced', hide: true);
    await j.tapKey('nav-me');
    await j.tapKey('me-motion');
    await j.tapKey('motion-device');
    await tester.pageBack();
    await j.settle(2);
    // One capture for the runner's evidence check: the still image again, then the shot.
    await j.tapKey('nav-today');
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('convertFlutterSurfaceToImage');
    await j.shot('companion-today-hidden-ask-stays');
  });
}
