import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// The Steps and Ready corrections on a device (GoHard_Steps_RunWalk_UX_Corrections), one short run of this file by
/// scripts\test-android.ps1 (`-Only journey_ux_test`). SIMULATED: steps (`GOHARD_SIM_STEPS`; the emulator has no step
/// counter, and the simulated source allows at once, so the refusal path is covered by move_ui_test, not here) and GPS
/// (Android's test location provider, fed by the host). Today's Steps tile → Enable → its count; Ready with every
/// setting above Start; intervals, voice and auto-pause set from their rows and their summaries read back; Start,
/// Pause and Resume of the same activity; Finish and Discard.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('steps on Today and Ready above Start', (tester) async {
    final j = Journey(tester, binding);
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    bool above(String key, String than) => tester.getRect(find.byKey(Key(key))).bottom <= tester.getRect(find.byKey(Key(than))).top + 0.5;

    await j.start('Ux Journey');
    // Steps is on Today before it is turned on: no number, an Enable.
    await j.reveal(find.byKey(const Key('today-steps')));
    expect(find.text('Track your steps'), findsOneWidget);
    await j.shot('ux-01-today-steps-first-use');
    await j.tapKey('today-steps-enable');
    await j.waitFor(find.textContaining('This phone (simulated)'), what: 'today\'s count with its source');
    await j.shot('ux-02-today-steps-on');

    // Ready: the setup, Steps and Start all on the first screen, Start last.
    await j.tapKey('today-run');
    await j.waitFor(find.byKey(const Key('runwalk-start')), what: 'Ready');
    await watch(1500);
    for (final k in ['runwalk-intervals', 'runwalk-voice', 'runwalk-autopause', 'runwalk-steps-row']) {
      expect(find.byKey(Key(k)).hitTestable(), findsOneWidget, reason: '$k in view without scrolling');
      expect(above(k, 'runwalk-start'), isTrue, reason: '$k above Start');
    }
    await j.shot('ux-03-ready');

    await j.tapKey('runwalk-intervals');
    await j.tapKey('interval-use');
    await j.tapKey('runwalk-voice');
    await j.tapKey('voice-on');
    Navigator.of(tester.element(find.byKey(const Key('voice-on')))).pop();
    await j.settle(4);
    await j.tapKey('runwalk-autopause');
    await j.tapKey('autopause-switch');
    Navigator.of(tester.element(find.byKey(const Key('autopause-switch')))).pop();
    await j.settle(4);
    expect(find.text('Run 1 min · Walk 90 s · × 8'), findsOneWidget);
    expect(find.text('On · every 1 km'), findsOneWidget);
    expect(find.text('Not used with intervals'), findsOneWidget, reason: 'auto-pause was turned on for free runs, and is not used with intervals');
    expect(find.text('Steps on'), findsOneWidget);
    await j.shot('ux-04-ready-configured');

    await j.tapKey('runwalk-start');
    await j.waitFor(find.byKey(const Key('runwalk-pause')), what: 'recording');
    await watch(3000);
    await j.tapKey('runwalk-pause');
    await j.waitFor(find.text('Paused'), what: 'paused');
    await j.shot('ux-05-paused');
    await j.tapKey('runwalk-resume');
    await j.waitFor(find.byKey(const Key('runwalk-pause')), what: 'the same activity recording again');
    expect(find.byKey(const Key('runwalk-interval')), findsOneWidget);
    await watch(2000);
    await j.tapKey('runwalk-finish');
    await j.waitFor(find.byKey(const Key('runwalk-discard')), what: 'the review');
    await j.tapKey('runwalk-discard');
    await j.confirmWith('Discard run');
    await j.settle(6);
  });
}
