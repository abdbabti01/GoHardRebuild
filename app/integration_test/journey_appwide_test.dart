import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Evidence run for the app-wide design (docs/DESIGN.md › App-wide panels), not part of the regular suite: the real
/// app on a device against the local API. A new account from sign-in through the coach setup, then every tab and the
/// main secondary screens (plan builder, workout recording, food search and portions, run, Appearance, goals, Ask
/// GoHard) in Green Dark, a few in the other looks, and the main actions checked on the way. Prints
/// `GOHARD_REC:start:<name>` / `GOHARD_REC:stop` around a recording of navigation, the coach and motion. Run with
/// `scripts\test-android.ps1 -Only journey_appwide_test`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app-wide design: sign-in, setup, every tab and the main secondary screens', (tester) async {
    final j = Journey(tester, binding);
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    Future<void> back() async {
      await tester.pageBack();
      await j.settle(3);
    }

    Future<void> top() async {
      for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
        final position = (e as StatefulElement).state as ScrollableState;
        if (position.position.axis == Axis.vertical && position.position.pixels > 0) position.position.jumpTo(0);
      }
      await j.settle(4);
    }

    Future<void> look(String accent, String mode) async {
      await j.tapKey('nav-me');
      await j.tapKey('me-appearance');
      await j.tapKey('accent-$accent');
      await j.tapKey('appearance-$mode');
      await back();
    }

    // --- Sign-in and registration, then the coach setup a new account gets.
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('auth-submit')), what: 'the sign-in screen');
    await j.shot('appwide-01-sign-in');
    await j.tapKey('auth-toggle');
    await j.type('auth-name', 'Bob Rivera');
    j.email = 'bob-appwide-${DateTime.now().millisecondsSinceEpoch}@example.test';
    await j.type('auth-email', j.email);
    await j.type('auth-password', j.password);
    await j.shot('appwide-02-register');
    await j.tapKey('auth-submit');
    await j.waitFor(find.byKey(const Key('setup-coach-leon')), what: 'Choose your coach');
    await j.settle(8);
    await j.shot('appwide-03-setup-coach');
    await j.tapKey('setup-continue');
    await j.waitFor(find.byKey(const Key('setup-done')), what: 'Optional features');
    await j.shot('appwide-04-setup-features');
    await j.tapKey('setup-done');
    await j.waitFor(find.text('No active plan'), what: 'Today for a new account');

    // --- Green Dark (the boards' look) and goals, so nutrition has something to measure against.
    await look('green', 'dark');
    await j.tapKey('nav-me');
    await j.tapKey('me-goals');
    await j.shot('appwide-05-goals-empty');
    await j.type('goal-calories', '2200');
    await j.type('goal-protein', '140');
    await j.tapKey('goal-save');
    await j.waitFor(find.text('2,200 kcal · 140 g protein'));

    // --- The plan builder, with its steps captured.
    await j.tapKey('nav-today');
    await j.tapKey('today-create-plan');
    await j.createPlanFromTemplate(shotPrefix: 'appwide-06');
    await j.tapKey('nav-today');
    await j.waitFor(find.byKey(const Key('today-start')), what: 'today\'s due workout');
    await top();
    await j.shot('appwide-07-today-due');

    // --- Workout recording: one set recorded, then back with it open.
    await j.tapKey('today-start');
    await j.waitFor(find.byKey(const Key('complete-set')));
    await j.shot('appwide-08-workout-start');
    await j.type('set-load', '60');
    await j.type('set-reps', '8');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('rest-clock')));
    await j.shot('appwide-09-workout-rest');
    await j.tapKey('rest-skip');
    await j.settle(4);
    await j.shot('appwide-10-workout-next-set');
    await back();
    await j.waitFor(find.byKey(const Key('today-resume')), what: 'Resume on Today');

    // --- Food: search, the amount form (choosing never logs), then logged.
    await j.tapKey('log-food');
    await j.type('food-search', 'egg');
    await j.waitFor(find.byKey(const Key('common-eggs')));
    await j.shot('appwide-11-food-search');
    await j.tapKey('common-eggs');
    await j.waitFor(find.byKey(const Key('food-quantity')));
    await j.shot('appwide-12-portion');
    expect(find.byKey(const Key('food-save')), findsOneWidget, reason: 'choosing a food opens the form; nothing is logged yet');
    await j.type('food-quantity', '2');
    await j.tapKey('food-save');
    await j.waitUntil(() async => find.text('No food logged today').evaluate().isEmpty, what: 'the logged food on Today');

    // --- Train's three views, Eat.
    await j.tapKey('nav-train');
    await j.tapKey('train-workouts');
    await top();
    await j.shot('appwide-13-train-workouts');
    await j.tapKey('train-plan');
    await j.waitFor(find.textContaining('Week 1 of'));
    await top();
    await j.shot('appwide-14-train-plan');
    await j.tapKey('train-progress');
    await top();
    await j.shot('appwide-15-train-progress');
    await j.tapKey('nav-eat');
    await top();
    await j.shot('appwide-16-eat');

    // --- A run: started, captured, finished.
    await j.tapKey('nav-today');
    await j.tapKey('today-run');
    await j.waitFor(find.byKey(const Key('run-finish')), what: 'the run screen');
    await j.settle(6);
    await j.shot('appwide-17-run');
    await j.tapKey('run-finish');
    await j.waitFor(find.text('Start run'), what: 'Start run once finished');

    // --- Me, Appearance, Ask GoHard.
    await j.tapKey('nav-me');
    await top();
    await j.shot('appwide-18-me');
    await j.tapKey('me-appearance');
    await j.shot('appwide-19-appearance');
    await back();
    await j.tapKey('nav-today');
    await top();
    await j.tapKey('coach-say-ask');
    await j.waitFor(find.byKey(const Key('ask-input')), what: 'Ask GoHard');
    await j.shot('appwide-20-ask');
    await j.tapKey('ask-close');
    await j.settle(4);

    // --- Other looks on the busiest screens.
    for (final (accent, mode) in const [('blue', 'light'), ('pink', 'dark'), ('green', 'light')]) {
      await look(accent, mode);
      await j.tapKey('nav-train');
      await j.tapKey('train-plan');
      await top();
      await j.shot('appwide-21-train-plan-$accent-$mode');
      await j.tapKey('nav-eat');
      await top();
      await j.shot('appwide-22-eat-$accent-$mode');
    }

    // --- Recording, Green Dark: tabs, the coach, a plan week, food search with the keyboard, back to Today.
    await look('green', 'dark');
    await j.tapKey('nav-today');
    await top();
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');
    debugPrint('GOHARD_REC:start:appwide');
    await watch(2000);
    for (final tab in ['nav-train', 'nav-eat', 'nav-me', 'nav-today']) {
      await tester.tap(find.byKey(Key(tab)));
      await watch(1600);
    }
    await tester.tap(find.byKey(const Key('coach-say-ask')));
    await watch(2200);
    await tester.tap(find.byKey(const Key('ask-close')));
    await watch(1800);
    await tester.tap(find.byKey(const Key('nav-train')));
    await watch(1200);
    await tester.tap(find.byKey(const Key('train-plan')));
    await watch(1800);
    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -320));
    await watch(1500);
    await tester.tap(find.byKey(const Key('nav-eat')));
    await watch(1200);
    await tester.tap(find.byKey(const Key('log-food')));
    await watch(1500);
    await tester.tap(find.byKey(const Key('food-search')));
    await watch(800);
    await tester.enterText(find.byKey(const Key('food-search')), 'rice');
    await watch(2500);
    FocusManager.instance.primaryFocus?.unfocus();
    await watch(600);
    await tester.tap(find.byKey(const Key('food-back')));
    await watch(1500);
    await tester.tap(find.byKey(const Key('nav-today')));
    await watch(6000); // the guide and the sky at rest
    debugPrint('GOHARD_REC:stop');
    await watch(1500);
  });
}
