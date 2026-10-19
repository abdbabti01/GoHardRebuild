import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Evidence run for Today's photographic panels (docs/DESIGN.md › Today panels), not part of the regular suite: the
/// real app on a device against the local API with live weather. Captures the states in Green Dark (the approved
/// mockup's combination) and the other accents and modes, checks that every panel action reaches its real place, then
/// prints `GOHARD_REC:start:today-panels` / `GOHARD_REC:stop` around a short recording (scrolling, the actions, the
/// guide and the weather still working). Run with `scripts\test-android.ps1 -Only journey_today_panels_test`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today panels: workout, nutrition and the compact run tile, their states and actions, in every look', (tester) async {
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
      await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 3000));
      await j.settle(4);
    }

    Future<void> look(String accent, String mode) async {
      await j.tapKey('nav-me');
      await j.tapKey('me-appearance');
      await j.tapKey('accent-$accent');
      await j.tapKey('appearance-$mode');
      await back();
      await j.tapKey('nav-today');
      await top();
    }

    double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;

    await j.start('Bob Rivera');
    // Live weather for a real city, as on a phone; Green Dark as in the approved mockup.
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
    await look('green', 'dark');
    await j.waitFor(find.byKey(const Key('today-sky-line')), what: 'the weather line', seconds: 30);
    await j.shot('today-panels-01-no-plan-green-dark');

    // --- A plan with a workout due today; nothing logged.
    await j.tapKey('today-create-plan');
    await j.createPlanFromTemplate();
    await j.tapKey('nav-today');
    await j.waitFor(find.byKey(const Key('today-start')), what: 'today\'s due workout');
    await top();
    expect(y('today-module-workout'), lessThan(y('today-module-nutrition')), reason: 'workout first');
    expect(y('today-module-nutrition'), lessThan(y('today-module-run')), reason: 'nutrition second, run third');
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('No food logged today'), findsOneWidget);
    await j.shot('today-panels-02-due-green-dark');

    // --- Log food reaches the food form; the logged eggs come back as real values.
    await j.tapKey('log-food');
    await j.type('food-search', 'eggs');
    await j.tapKey('common-eggs');
    await j.waitFor(find.byKey(const Key('food-quantity')));
    await j.type('food-quantity', '2');
    await j.tapKey('food-save');
    await j.waitUntil(() async => find.text('No food logged today').evaluate().isEmpty && find.byKey(const Key('today-module-nutrition')).evaluate().isNotEmpty,
        what: 'Today with the logged food');
    expect(find.descendant(of: find.byKey(const Key('today-module-nutrition')), matching: find.text('kcal')), findsOneWidget);
    await top();
    await j.shot('today-panels-03-due-food-green-dark');

    // --- Start workout opens the workout; one set recorded; back on Today it is Resume, with the recorded count.
    await j.tapKey('today-start');
    await j.waitFor(find.byKey(const Key('complete-set')));
    await j.type('set-load', '60');
    await j.type('set-reps', '8');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('rest-clock')));
    await j.tapKey('rest-skip');
    await j.tapKey('nav-today');
    await j.waitFor(find.byKey(const Key('today-resume')), what: 'Resume on Today');
    expect(find.text('In progress'), findsWidgets);
    await top();
    await j.shot('today-panels-04-in-progress-green-dark');

    // --- Journal is Eat.
    await j.tapKey('today-open-eat');
    await j.waitFor(find.byKey(const Key('eat-add-breakfast')), what: 'Eat from Journal');
    await j.tapKey('nav-today');

    // --- Start opens Run / Walk; back on Today it is Resume; finishing and saving leaves a finished run.
    await j.startActivity();
    await back();
    await j.waitFor(find.widgetWithText(FilledButton, 'Resume'), what: 'the open run on Today');
    await j.reveal(find.byKey(const Key('today-module-run')));
    await tester.ensureVisible(find.byKey(const Key('today-module-run')));
    await j.shot('today-panels-05-run-open-green-dark');
    await j.tapKey('today-run');
    await j.waitFor(find.byKey(const Key('runwalk-finish')), what: 'the same run');
    await j.tapKey('runwalk-finish');
    await j.waitFor(find.byKey(const Key('runwalk-save')), what: 'the save review');
    await j.tapKey('runwalk-save');
    await j.tapKey('activity-done');
    await j.waitFor(find.widgetWithText(FilledButton, 'Start new'), what: 'Start new once saved');

    // --- History is the Run / Walk history.
    await j.tapKey('nav-train');
    await j.tapKey('train-run-history');
    await j.waitFor(find.text('History'), what: 'Run / Walk history');
    await back();

    // --- Resume opens the same workout, with its recorded set.
    await j.tapKey('today-resume');
    await j.waitFor(find.byKey(const Key('complete-set')), what: 'the resumed workout');
    expect(find.textContaining('1 of'), findsWidgets, reason: 'the same workout, with its recorded set');
    await j.tapKey('nav-today');

    // --- The other accents and modes.
    for (final (accent, mode) in const [('blue', 'light'), ('pink', 'dark'), ('green', 'light'), ('blue', 'dark'), ('pink', 'light')]) {
      await look(accent, mode);
      await j.shot('today-panels-06-$accent-$mode');
    }

    // --- Recording: back to Green Dark, the live surface for screenrecord.
    await look('green', 'dark');
    await const MethodChannel('plugins.flutter.io/integration_test').invokeMethod<void>('revertFlutterImage');
    debugPrint('GOHARD_REC:start:today-panels');
    await watch(2000);
    final list = find.byType(Scrollable).hitTestable().first;
    for (final dy in [-260.0, -260.0, 520.0]) {
      await tester.drag(list, Offset(0, dy));
      await watch(1400);
    }
    await tester.tap(find.byKey(const Key('coach-say-ask')));
    await watch(2200);
    await tester.tap(find.byKey(const Key('ask-close')));
    await watch(1800);
    await tester.tap(find.byKey(const Key('today-details')));
    await watch(2200);
    await tester.tap(find.byKey(const Key('nav-today')));
    await watch(1500);
    await tester.drag(list, const Offset(0, -300));
    await watch(1200);
    await tester.tap(find.byKey(const Key('today-open-eat')));
    await watch(1800);
    await tester.tap(find.byKey(const Key('nav-today')));
    await watch(1500);
    await tester.tap(find.byKey(const Key('nav-train')));
    await watch(1200);
    await tester.ensureVisible(find.byKey(const Key('train-run-history')));
    await watch(800);
    await tester.tap(find.byKey(const Key('train-run-history')));
    await watch(2000);
    await tester.pageBack();
    await watch(1500);
    await tester.tap(find.byKey(const Key('nav-today')));
    await watch(1500);
    await tester.drag(list, const Offset(0, 1000));
    await watch(6000); // the guide's eyes and the sky, at rest
    debugPrint('GOHARD_REC:stop');
    await watch(1500);
  });
}
