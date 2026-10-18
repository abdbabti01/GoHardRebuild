import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support.dart';

/// Steps, intervals, voice and alerts, personal bests and the saved-foods shortcut on a device (docs/RUN_WALK.md,
/// docs/COACH.md › Saved foods), in two runs of this file by scripts\test-android.ps1 (`-Only journey_move_test`):
///
/// SIMULATED: GPS through Android's test location provider (a run north at about 3.5 m/s, fed by the host), and steps
/// from the labelled simulated source (`GOHARD_SIM_STEPS`, the emulator has no step counter). Speech goes to the
/// emulator's real text-to-speech engine, but nothing here hears it: the words are checked on screen.
///
/// Phase 1: Steps on (Customize tracking) and on Today; a favourite food marked (nothing logged); a short free run saved
/// (something to beat); a 2 × (15 s run, 15 s walk) interval run with Voice on and updates every 0.5 km: a phase
/// prompt, Pause freezing the phase, Skip phase, Intervals finished → Continue freely, the 0.5 km update; left
/// recording. The host force-stops the app.
///
/// Phase 2 (a new process): the run is Interrupted; Resume, Finish, Save; the coach names the new personal best once;
/// steps and the interval timeline in details; History's personal bests; Eat's hint is not repeated and its help opens Favourites; nothing logs
/// nothing.

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('steps, intervals, voice, records, saved foods', (tester) async {
    final j = Journey(tester, binding);
    // The phase is what the phone holds: phase 1 leaves the account file; phase 2 (the same build) finds it.
    final account = File('${(await getApplicationDocumentsDirectory()).path}/move-journey-account.txt');
    final phase = await account.exists() ? '2' : '1';
    debugPrint('GOHARD_MOVE_PHASE:$phase');
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    Future<void> waitText(Finder f, String what, {int seconds = 90}) async {
      for (var i = 0; i < seconds * 4 && f.evaluate().isEmpty; i++) {
        await watch(250);
      }
      await j.waitFor(f, what: what);
    }

    if (phase == '1') {
      await j.start('Move Journey');
      await account.writeAsString(j.email);

      // Steps: off until turned on, then today's total with its source.
      expect(find.byKey(const Key('today-steps')), findsNothing, reason: 'steps are opt-in');
      await j.tapKey('today-customize');
      await j.tapKey('track-steps');
      await j.waitFor(find.byKey(const Key('steps-goal')), what: 'the steps goal field');
      await j.type('steps-goal', '8000');
      await j.shot('move-01-customize-steps');
      // The keyboard makes the sheet fill the screen: pop its route rather than tap outside it.
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(tester.element(find.byKey(const Key('steps-goal')))).pop();
      await j.settle(6);
      await waitText(find.textContaining('This phone (simulated)'), 'today\'s steps from the simulated source');
      await j.shot('move-02-today-steps');

      // A favourite food, marked from Add food and cancelled: nothing is logged.
      await j.tapKey('nav-eat');
      await j.tap(find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('log-food')))); // Today has one too
      await j.waitFor(find.byKey(const Key('food-search')), what: 'Add food');
      await j.type('food-search', 'eggs');
      await j.tapKey('common-eggs');
      await j.waitFor(find.byKey(const Key('food-favourite')), what: 'the egg preview');
      await j.tapKey('food-favourite');
      await j.tapKey('food-cancel');
      await j.tester.pageBack();
      await j.settle();
      // Back on Eat with a favourite: the coach offers it once; the shortcut opens Favourites and logs nothing.
      // Tapping Log food scrolled it to the top, so the coach (a header) left the lazy list: back to the top first.
      await tester.drag(find.byType(ListView).hitTestable().last, const Offset(0, 900));
      await j.settle(4);
      await waitText(find.textContaining('Your favourite foods are one tap away', findRichText: true), 'the saved-foods hint', seconds: 20);
      await j.shot('move-13-eat-shortcut');
      await j.tapKey('eat-coach-favourites');
      await j.waitFor(find.textContaining('Eggs'), what: 'the favourite in Favourites');
      await j.shot('move-14-favourites');
      await j.tester.pageBack();
      await j.settle();
      expect(find.textContaining('Eggs'), findsNothing, reason: 'nothing was logged from the shortcut');
      await j.tapKey('nav-today');

      // Something to beat: a short free run.
      await j.startActivity();
      await watch(20000);
      await j.finishAndSaveActivity();

      // Intervals: the setup, made as short as allowed.
      await j.tapKey('today-run');
      await j.waitFor(find.byKey(const Key('runwalk-start')), what: 'Ready');
      await j.tapKey('runwalk-intervals');
      for (final (k, n) in [('warmup', 5), ('run', 3), ('walk', 5), ('reps', 6), ('cooldown', 5)]) {
        for (var i = 0; i < n; i++) {
          await j.tapKey('interval-$k-less');
        }
      }
      expect(find.text('2 × run 15 s, walk 15 s'), findsOneWidget);
      await j.shot('move-03-interval-setup');
      await j.tapKey('interval-use');
      await j.tapKey('runwalk-voice');
      await j.tapKey('voice-on');
      await j.tapKey('voice-every-d-0.5');
      await j.shot('move-04-voice-sheet');
      await j.closeSheet();
      expect(find.text('Intervals on'), findsOneWidget);
      await j.shot('move-05-ready-intervals');

      await j.tapKey('runwalk-start');
      await j.waitFor(find.byKey(const Key('runwalk-interval')), what: 'the phase bar');
      expect(find.text('Run'), findsWidgets);
      await waitText(find.text('Walk and recover for 15 seconds.'), 'the walk prompt', seconds: 40);
      await j.shot('move-06-phase-walk');
      await j.tapKey('runwalk-pause');
      final left = tester.widget<Text>(find.byKey(const Key('runwalk-phase-left'))).data;
      await watch(4000);
      expect(tester.widget<Text>(find.byKey(const Key('runwalk-phase-left'))).data, left, reason: 'a pause freezes the phase');
      await j.tapKey('runwalk-resume');
      await j.tapKey('runwalk-skip-phase');
      await waitText(find.text('Final round. Run for 15 seconds.'), 'the final round after Skip phase', seconds: 15);
      await waitText(find.byKey(const Key('runwalk-intervals-done')), 'the end of the plan', seconds: 60);
      await j.shot('move-07-intervals-finished');
      await j.tapKey('runwalk-continue-free');
      expect(find.byKey(const Key('runwalk-finish')), findsOneWidget, reason: 'the recording goes on');
      await waitText(find.textContaining('km completed.'), 'a distance update (every 0.5 km)', seconds: 200);
      await j.shot('move-08-distance-update');
      debugPrint('GOHARD_PHASE1:recording-left-open');
      return; // the host force-stops the app while it records
    }

    j.email = await account.readAsString();
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await waitText(find.text('Run interrupted'), 'the interrupted run on Today', seconds: 40);
    await j.tapKey('today-run');
    await j.waitFor(find.byKey(const Key('runwalk-resume')), what: 'Resume');
    expect(find.text('Intervals finished'), findsNothing, reason: 'Continue freely was kept across the restart');
    await j.shot('move-09-interrupted');
    await j.tapKey('runwalk-resume');
    await watch(6000);
    await j.tapKey('runwalk-finish');
    await j.waitFor(find.byKey(const Key('runwalk-save')), what: 'the save review');
    await j.tapKey('runwalk-save');
    await j.waitFor(find.byKey(const Key('activity-done')), what: 'Saved');
    await waitText(find.textContaining('Your longest run so far'), 'the personal best, said once', seconds: 15);
    await j.shot('move-10-saved-record');
    expect(find.byKey(const Key('activity-best-run.longest')), findsOneWidget);
    await j.reveal(find.byKey(const Key('activity-intervals')));
    await j.shot('move-11-saved-intervals-steps');
    await j.tapKey('activity-done');

    await j.tapKey('today-run-history');
    await j.waitFor(find.byKey(const Key('history-bests')), what: 'personal bests in History');
    await j.tapKey('history-bests');
    await j.waitFor(find.byKey(const Key('best-run.longest')), what: 'the bests list');
    await j.shot('move-12-bests');
    await j.tester.pageBack();
    await j.settle();
    await j.tester.pageBack();
    await j.settle();

    // Eat in a new process: the hint was shown once (phase 1), so the usual words; the help still opens Favourites.
    await j.tapKey('nav-eat');
    await waitText(find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.textContaining('Log a meal', findRichText: true)), 'the usual words, the hint not repeated', seconds: 20);
    await j.tap(find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.byKey(const Key('coach-avatar-launcher'))));
    await j.waitFor(find.byKey(const Key('eat-help-favourites')), what: 'Open Favourites in the journal help');
    await j.shot('move-15-eat-help');
    await j.tapKey('eat-help-favourites');
    await j.waitFor(find.textContaining('Eggs'), what: 'the favourite, from the help');
    expect(find.text('Favourites'), findsWidgets);
  });
}
