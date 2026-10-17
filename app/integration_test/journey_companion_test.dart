import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Evidence run for the coach who speaks through bubbles (docs/COACH.md › Companion), not part of the regular suite:
/// the real app on a device against the local API with live weather. New accounts give genuine first appearances
/// (Today greets once per account per day; introductions are once per account). Prints `GOHARD_REC:start:<name>` /
/// `GOHARD_REC:stop` around each part worth recording and `GOHARD_REC:home` when the host should press Home and bring
/// the app back (the host records with `adb screenrecord`; see PROGRESS_LEDGER).
///
///   today-leon     Leon peeks in, nods, and speaks: greeting, Today's line, Ask me, the bubble's tail at the mouth
///                  through the head's movement; then at rest: the eyes look about, glance at the bubble, blink
///   ask-leon       the guide opens Ask GoHard (the same guide in its header and on the answer); Ask me does too;
///                  back on Today the guide nods for being asked
///   scroll-return  scrolling and tabs, then Home and back: no replay, still there; the weather sky beside the guide
///   split-help     the coach on Train without a plan (Create my plan in its bubble), then the split step's introduction and Compare splits
///   exercise-help  the exercise editor's help: the bubble, then About this exercise; the typed sets are kept
///   food-portion   food search introduced once, then the portion guidance on a food with portions
///   appearance     Show coach on Today off: Today without the guide (no Ask button in its place), the guide on Train
///                  still opens Ask GoHard; on again: back on Today, settled
///   hints-off      Coaching hints off: no introduction by itself, help on request (nutrition goals)
///   today-leona    the same greeting with Leona, ask-leona the same ways into Ask GoHard
///   reduced        Motion › Reduced: a settled portrait and its bubble at once
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coach speech bubbles across the app: Today, the builder, the exercise editor, food, hints off, Leona, reduced motion', (tester) async {
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
      await watch(1000);
    }

    Future<void> back() async {
      await tester.pageBack();
      await j.settle(3);
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

    Future<void> greet(String name) => rec(name, () async {
          await j.tapKey('auth-submit');
          // Landing on Today: the guide peeks in, nods, and the bubble arrives as it settles.
          await watch(5000);
          expect(find.byKey(const Key('coach-say-title')), findsOneWidget, reason: 'the greeting is in the bubble');
          expect(find.byKey(const Key('today-ask')), findsNothing, reason: 'no generic Ask beside the title');
          expect(find.byKey(const Key('coach-say-close')), findsNothing, reason: 'no close button on Today');
          await watch(14000); // at rest: its eyes' own moments
        });

    /// Both ways into Ask GoHard from Today: the guide, then Ask me.
    Future<void> ask(String name) => rec(name, () async {
          await j.tapKey('coach-avatar-launcher');
          await j.waitFor(find.byKey(const Key('ask-input')), what: 'Ask GoHard from the guide');
          expect(find.byKey(const Key('ask-companion')), findsOneWidget, reason: 'the same guide in the conversation');
          await watch(2500);
          await j.tapKey('ask-close');
          await watch(1500);
          await j.tapKey('coach-say-ask');
          await j.waitFor(find.byKey(const Key('ask-input')), what: 'Ask GoHard from Ask me');
          await watch(2000);
          await j.tapKey('ask-close');
          await watch(3000); // back on Today: the nod for being asked
          expect(find.byKey(const Key('today-coach')), findsOneWidget);
        });

    // --- Account 1, Leon. Live weather first, so the sky moves beside the guide.
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
    await back();
    await back();
    await signUpAgain('Babti Leon');
    await greet('today-leon');
    await ask('ask-leon');

    await rec('scroll-return', () async {
      final list = find.byType(Scrollable).hitTestable().first;
      for (final dy in [-220.0, 220.0]) {
        await tester.drag(list, Offset(0, dy));
        await watch(1200);
      }
      for (final tab in ['nav-eat', 'nav-today']) {
        await tester.tap(find.byKey(Key(tab)));
        await watch(1500);
      }
      debugPrint('GOHARD_REC:home'); // the host presses Home, waits, and brings the app back
      await watch(9000);
    });

    await rec('split-help', () async {
      await j.tapKey('nav-train');
      await j.tapKey('train-plan');
      await j.waitFor(find.byKey(const Key('train-coach')), what: 'the coach on Train');
      await watch(3500);
      await j.tapKey('create-plan'); // in the coach's bubble
      await j.tapKey('plan-path-guided');
      await j.tapKey('days-4');
      await j.tapKey('builder-next');
      await j.waitFor(find.byKey(const Key('coach-spot-builder.structure')), what: 'the split step\'s introduction');
      await watch(3500);
      await j.tapKey('coach-compare');
      await j.waitFor(find.byKey(const Key('guide-compare-sheet')));
      await watch(2500);
      Navigator.of(tester.element(find.byKey(const Key('guide-compare-sheet')))).pop();
      await watch(1200);
    });

    await rec('exercise-help', () async {
      await j.tapKey('coach-say-close');
      await j.tapKey('guide-use-upper-lower');
      await j.tapKey('builder-next');
      await j.tapKey('exercise-0-0');
      await j.type('rx-sets', '5');
      FocusManager.instance.primaryFocus?.unfocus();
      await watch(800);
      await j.tapKey('coach-help-exercise.prescription');
      await watch(3500);
      await j.tapKey('coach-exercise-info');
      await j.waitFor(find.byKey(const Key('exercise-info-sheet')));
      await watch(2500);
      Navigator.of(tester.element(find.byKey(const Key('exercise-info-sheet')))).pop();
      await watch(1500);
      expect(find.text('5'), findsWidgets, reason: 'the typed sets are still there');
    });
    // Out of the builder (the draft is kept on the phone).
    Navigator.of(tester.element(find.byKey(const Key('rx-sets')))).popUntil((r) => r.isFirst);
    await j.settle(4);

    await rec('food-portion', () async {
      await j.tapKey('nav-eat');
      await j.tapKey('eat-add-breakfast');
      await j.waitFor(find.byKey(const Key('coach-spot-food.search')), what: 'food search\'s one-time introduction');
      await watch(3500);
      await j.type('food-search', 'eggs');
      await j.tapKey('common-eggs');
      await j.waitFor(find.byKey(const Key('coach-spot-food.portion')), what: 'the portion guidance');
      await watch(3500);
      await j.tapKey('food-cancel');
      await j.settle(3);
      await j.tapKey('food-back');
      await j.settle(3);
    });

    Future<void> showOnToday() async {
      await j.tapKey('nav-me');
      await j.tapKey('me-appearance');
      await tester.scrollUntilVisible(find.byKey(const Key('coach-on-today')), 300, scrollable: find.byType(Scrollable).hitTestable().last);
      await watch(800);
      await j.tap(find.descendant(of: find.byKey(const Key('coach-on-today')), matching: find.byType(Switch)));
      await watch(1200);
      await back();
    }

    await rec('appearance', () async {
      await j.tapKey('nav-today');
      await watch(2000);
      expect(find.byKey(const Key('today-coach')), findsOneWidget, reason: 'still there after the other tabs and screens');
      await showOnToday(); // off
      await j.tapKey('nav-today');
      await watch(2500);
      expect(find.byKey(const Key('today-coach')), findsNothing, reason: 'Show coach on Today off');
      expect(find.byKey(const Key('today-ask')), findsNothing, reason: 'no generic Ask button in its place');
      await j.tapKey('nav-train');
      await watch(1500);
      await j.tap(find.descendant(of: find.byKey(const Key('train-coach')), matching: find.byKey(const Key('coach-avatar-launcher'))));
      await j.waitFor(find.byKey(const Key('ask-input')), what: 'Ask GoHard from the guide on Train');
      await watch(1500);
      await j.tapKey('ask-close');
      await watch(1000);
      await showOnToday(); // on again
      await j.tapKey('nav-today');
      await watch(3000);
      expect(find.byKey(const Key('today-coach')), findsOneWidget, reason: 'back, settled');
    });

    // Coaching hints off, then a screen this account has not seen: nothing by itself, help when asked.
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await tester.scrollUntilVisible(find.byKey(const Key('coach-hints')), 300, scrollable: find.byType(Scrollable).hitTestable().last);
    await j.tap(find.descendant(of: find.byKey(const Key('coach-hints')), matching: find.byType(Switch)));
    await back();
    await rec('hints-off', () async {
      await j.tapKey('me-goals');
      await watch(2500);
      expect(find.byKey(const Key('coach-spot-me.goals')), findsNothing, reason: 'hints off: no introduction by itself');
      await j.tapKey('coach-help-me.goals');
      await watch(3500);
      expect(find.byKey(const Key('coach-spot-me.goals')), findsOneWidget, reason: 'asked for: shown');
    });
    await back();

    // --- Account 2, Leona.
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await tester.scrollUntilVisible(find.byKey(const Key('coach-leona')), 300, scrollable: find.byType(Scrollable).hitTestable().last);
    await j.tapKey('coach-leona');
    await back();
    await signUpAgain('Ana Leona');
    await greet('today-leona');
    await ask('ask-leona');

    // --- Account 3, Reduced motion.
    await j.tapKey('nav-me');
    await j.tapKey('me-motion');
    await j.tapKey('motion-reduced');
    await back();
    await signUpAgain('Rae Reduced');
    await greet('reduced');
    await j.tapKey('nav-me');
    await j.tapKey('me-motion');
    await j.tapKey('motion-device');
    await back();
    // One capture for the runner's evidence check: the still image again, then the shot.
    await j.tapKey('nav-today');
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('convertFlutterSurfaceToImage');
    await j.shot('companion-today-leona-reduced');
  });
}
