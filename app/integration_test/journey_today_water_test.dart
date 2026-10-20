import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// GoHard_Today_History_Water_Corrections on a device, one short run (`scripts\test-android.ps1 -Only
/// journey_today_water_test`), local API: water turned on in Eat; Today's +250 mL logs one drink at once, Undo removes
/// it, Other amount logs a custom one; an amount logged on yesterday from Eat; Eat › History lists yesterday and opens
/// it, dated, with Back to today; Train › Run / Walk history. Captures in Blue Light and Pink Dark. SIMULATED steps
/// (`GOHARD_SIM_STEPS`, so the Steps tile shows a count); no GPS needed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('today, history and water', (tester) async {
    final j = Journey(tester, binding);
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    Finder inEat(Key key) => find.descendant(of: find.byType(EatScreen), matching: find.byKey(key));
    Future<void> theme(String accent, String mode) async {
      await j.tapKey('nav-me');
      await j.tapKey('me-appearance');
      await j.tapKey('accent-$accent');
      await j.tapKey('appearance-$mode');
      await j.tester.pageBack();
      await j.settle(4);
      await j.tapKey('nav-today');
      await j.settle(6);
    }

    await j.start('Water Journey');
    final today = dayKeyOf(DateTime.now()), yesterday = addDays(today, -1);

    // Water on, from Eat's labelled Customize tracking; Steps on from Today's tile.
    await j.tapKey('nav-eat');
    await j.tap(inEat(const Key('eat-customize')));
    await j.tapKey('track-water');
    Navigator.of(tester.element(find.byKey(const Key('track-water')))).pop();
    await j.settle(4);
    await j.tapKey('nav-today');
    await j.tapKey('today-steps-enable');
    await j.waitFor(find.textContaining('This phone (simulated)'), what: 'steps on');
    await theme('blue', 'light');
    await j.shot('thw-01-today-blue-light');
    await j.reveal(find.byKey(const Key('today-steps')));
    await j.shot('thw-02-today-tiles-blue-light');
    // Option 2: no goal yet, so Set a goal; it opens the shared Steps sheet and sets nothing.
    await j.tapKey('today-steps-goal-link');
    await j.waitFor(find.byKey(const Key('steps-goal')), what: 'the Steps sheet from Set a goal');
    Navigator.of(tester.element(find.byKey(const Key('steps-goal')))).pop();
    await j.settle(4);
    expect(find.text('Set a goal'), findsOneWidget, reason: 'opening the sheet sets no goal');

    // One tap, one drink; Undo takes exactly that one away; Other amount for a custom one.
    final quick = find.descendant(of: find.byKey(const Key('today-water')), matching: find.byKey(const Key('water-quick-add')));
    await j.tap(quick);
    await j.waitFor(find.descendant(of: find.byKey(const Key('today-water')), matching: find.text('250 mL')), what: '250 mL logged at once (no goal set: the amount alone)');
    // Undo is in the water line, in Other amount's place, for 5 s: tapped at once (a capture takes longer).
    await tester.tap(find.descendant(of: find.byKey(const Key('today-water')), matching: find.byKey(const Key('water-undo'))));
    await j.waitFor(find.descendant(of: find.byKey(const Key('today-water')), matching: find.text('0 mL')), what: 'the drink undone');
    // Another drink, kept, captured with its inline Undo.
    await tester.tap(quick);
    await j.settle(2);
    await j.shot('thw-03-water-added-undo');
    await j.waitFor(find.descendant(of: find.byKey(const Key('today-water')), matching: find.text('250 mL')), what: 'the second drink');
    await watch(6500); // Undo gives Other amount its place back by itself
    expect(find.byKey(const Key('water-undo')), findsNothing, reason: 'Undo does not stay');
    await j.tap(find.descendant(of: find.byKey(const Key('today-water')), matching: find.byKey(const Key('water-other'))));
    await j.type('water-other-amount', '330');
    await j.tapKey('water-other-add');
    await j.waitFor(find.descendant(of: find.byKey(const Key('today-water')), matching: find.text('580 mL')), what: 'a custom amount (250 + 330)');
    await watch(6500);

    // Yesterday, from Eat's day arrow: Other amount logs on the day shown.
    await j.tapKey('nav-eat');
    await j.tap(find.descendant(of: find.byType(EatScreen), matching: find.byTooltip('Previous day')));
    await j.waitFor(inEat(const Key('eat-back-to-today')), what: 'yesterday in Eat');
    await j.tap(inEat(const Key('water-other')));
    await j.type('water-other-amount', '500');
    await j.tapKey('water-other-add');
    await j.settle(6);
    await j.tap(inEat(const Key('eat-back-to-today')));

    // History & trends, then its Calendar: the calendar and the days with entries; yesterday opens dated, then Back to today.
    await j.tap(inEat(const Key('eat-history')));
    await j.reveal(find.byKey(const Key('trends-calendar')));
    await j.tapKey('trends-calendar');
    await j.waitFor(find.byKey(const Key('history-calendar')), what: 'History & trends › Calendar');
    await j.reveal(find.byKey(Key('history-day-$yesterday')));
    expect(find.descendant(of: find.byKey(Key('history-day-$yesterday')), matching: find.textContaining('500 mL water')), findsOneWidget);
    await j.shot('thw-04-eat-history');
    await j.tapKey('history-day-$yesterday');
    await j.waitFor(inEat(const Key('eat-back-to-today')), what: 'yesterday opened from History');
    await j.shot('thw-05-eat-yesterday');
    await j.tap(inEat(const Key('eat-back-to-today')));
    await j.tapKey('nav-today');

    // Run / Walk history from Train.
    expect(find.byKey(const Key('today-run-history')), findsNothing);
    await j.tapKey('nav-train');
    await j.tapKey('train-run-history');
    await j.waitFor(find.byKey(const Key('history-filter-all')), what: 'Run / Walk history (All / Run / Walk)');
    await j.shot('thw-06-train-run-history');
    await j.tester.pageBack();
    await j.settle(4);

    await theme('pink', 'dark');
    await j.shot('thw-07-today-pink-dark');
    await j.reveal(find.byKey(const Key('today-steps')));
    await j.shot('thw-08-today-tiles-pink-dark');
  });
}
