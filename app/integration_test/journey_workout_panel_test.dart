import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// The workout panel in Train › Workouts (docs/DESIGN.md › Workout panel), on a real install against the local API,
/// in two runs of this file by scripts\test-android.ps1 -Only journey_workout_panel_test.
///
/// Phase 1: a new account with a template plan; Today › Details shows the preview and creates nothing; an earlier
/// manual session of the plan's first exercise is recorded (the manual path through the same panel); Details again
/// shows it as last time; Start; Use last values fills without recording; Record set; history and About and back;
/// a typed entry is left unsaved and survives a tab switch. Phase 2 is a new process: Resume shows the same workout
/// with its set and the typed entry, and Finish shows the saved result under its real outcome.
const _phase = String.fromEnvironment('GOHARD_PHASE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout panel phase $_phase', (tester) async {
    final j = Journey(tester, binding);
    TextEditingController field(String key) => tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField))).controller!;
    // All workouts sits at the top of a long page: back to the top first, as a person would scroll.
    Future<void> allWorkouts() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await j.settle(2);
      tester.state<ScrollableState>(find.ancestor(of: find.byKey(const Key('workout-all')), matching: find.byType(Scrollable)).first).position.jumpTo(0);
      await j.settle(4);
      await tester.tap(find.byKey(const Key('workout-all')));
      await j.settle(4);
    }

    Future<void> closeSheet(String key) async {
      Navigator.of(tester.element(find.byKey(Key(key)))).pop();
      for (var i = 0; i < 24 && find.byKey(Key(key)).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byKey(Key(key)), findsNothing, reason: 'the sheet closed');
      await j.settle(2);
    }

    Finder byKeyPrefix(String prefix) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix));

    if (_phase == '1') {
      await j.start('Panel Journey');
      await j.tapKey('today-create-plan');
      await j.createPlanFromTemplate();
      await j.tapKey('nav-today');

      // Details: the preview in Train › Workouts, with nothing started.
      await j.tapKey('today-details');
      await j.waitFor(find.byKey(const Key('workout-preview')), what: 'the preview');
      expect(find.byKey(const Key('complete-set')), findsNothing, reason: 'no recorder: nothing was started');
      final first = tester.widget<Text>(find.descendant(of: find.byKey(const Key('preview-exercise-0')), matching: find.byType(Text)).at(1)).data!;
      expect(find.text('No previous session recorded.'), findsOneWidget);
      await allWorkouts();
      expect(byKeyPrefix('train-open-'), findsNothing, reason: 'All workouts after Details: still no workout');

      // An earlier session of that exercise, through Train's manual workout and the same panel.
      await j.tapKey('start-manual');
      await j.type('manual-title', 'Earlier');
      await j.tapKey('manual-add-exercise');
      await j.type('exercise-search', first);
      await j.tap(find.descendant(of: find.byType(ListRow), matching: find.text(first)));
      await j.tapKey('manual-start');
      await j.waitFor(find.byKey(const Key('complete-set')), what: 'the manual workout in the panel');
      for (final (load, reps) in [('40', '10'), ('42.5', '8')]) {
        await j.type('set-load', load);
        await j.type('set-reps', reps);
        await j.tapKey('complete-set');
        await j.settle(4);
      }
      await j.tapKey('finish-workout');
      await j.tapKey('finish-confirm');
      await j.waitFor(find.byKey(const Key('workout-result')), what: 'the manual result in the panel');
      await j.tapKey('result-done');

      // Details again: last time is the session just recorded.
      await j.tapKey('nav-today');
      await j.waitFor(find.byKey(const Key('today-start')), what: 'the planned workout, still due after a manual one');
      await j.shot('wp-01-today');
      await j.tapKey('today-details');
      await j.waitFor(find.byKey(const Key('workout-preview')));
      await j.waitFor(find.text('40 kg × 10'), what: 'last time in the preview');
      await j.shot('wp-02-preview');
      debugPrint('GOHARD_REC:start:wp-recording');

      // Start, then compare: Use last values asks before replacing a typed value, and records nothing.
      await j.tapKey('preview-start');
      await j.waitFor(find.byKey(const Key('complete-set')), what: 'the recorder for the started workout');
      await j.type('set-load', '45');
      await j.tapKey('use-last-values');
      await j.waitFor(find.text('Replace what you typed?'));
      await j.confirmWith('Use last values');
      expect(field('set-load').text, '40');
      expect(field('set-reps').text, '10');
      expect(find.byKey(const Key('set-row-0')), findsNothing, reason: 'filling is not recording');
      await j.type('set-reps', '11');
      // The table and the typed, unsaved entry under it, with the keyboard closed.
      FocusManager.instance.primaryFocus?.unfocus();
      await j.settle(3);
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('last-time'))), alignment: 0.12);
      await j.settle(3);
      expect(field('set-reps').text, '11');
      await j.shot('wp-03-compare-typed-unsaved');
      await j.tapKey('complete-set');
      await j.waitFor(find.byKey(const Key('rest-clock')), what: 'rest after the recorded set');

      // History and About above the panel, and back to it unchanged.
      await j.type('set-load', '50');
      await j.tapKey('all-sessions');
      await j.waitFor(find.byKey(const Key('history-sheet')));
      await j.shot('wp-04-history-sheet');
      await closeSheet('history-sheet');
      await j.tapKey('workout-demo');
      await j.waitFor(find.byKey(const Key('exercise-info-sheet')));
      await closeSheet('exercise-info-sheet');
      expect(field('set-load').text, '50');

      // Switching tabs and back keeps the same workout and the typed entry.
      await j.tapKey('nav-today');
      await j.tapKey('nav-train');
      await j.waitFor(find.byKey(const Key('complete-set')));
      expect(field('set-load').text, '50');
      await allWorkouts();
      await j.reveal(byKeyPrefix('train-open-'));
      await j.waitFor(byKeyPrefix('train-open-'), what: 'the one open workout on Workouts', seconds: 8);
      expect(byKeyPrefix('train-open-'), findsOneWidget, reason: 'one workout, still open');
      await j.tapKey('nav-today');
      await j.waitFor(find.byKey(const Key('today-resume')));
      await j.tapKey('today-resume');
      await j.waitFor(find.byKey(const Key('complete-set')));
      expect(field('set-load').text, '50', reason: 'saved as the panel closed, restored as it opened');
      debugPrint('GOHARD_REC:stop');
      await j.settle(8);
      return;
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    // A new process: only what the previous one saved on the phone.
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('today-resume')), what: 'the open workout after the process ended', seconds: 40);
    await j.tapKey('today-resume');
    await j.waitFor(find.byKey(const Key('complete-set')), what: 'the same workout in the panel');
    await j.reveal(find.byKey(const Key('set-row-0')));
    await j.waitFor(find.byKey(const Key('set-row-0')), what: 'the set recorded before the process ended');
    expect(find.byKey(const Key('set-row-1')), findsNothing);
    expect(field('set-load').text, '50', reason: 'the unsaved entry survived the process ending');
    await allWorkouts();
    await j.reveal(byKeyPrefix('train-open-'));
    await j.waitFor(byKeyPrefix('train-open-'), what: 'the one open workout on Workouts', seconds: 8);
    expect(byKeyPrefix('train-open-'), findsOneWidget, reason: 'the durable session, not a new one');
    await j.tap(byKeyPrefix('train-details-'));
    await j.tapKey('finish-workout');
    await j.tapKey('finish-confirm');
    await j.waitFor(find.byKey(const Key('workout-result')), what: 'the saved result in the panel');
    expect(find.text('Finished partially'), findsWidgets, reason: 'one set of a planned workout is partial');
    await j.shot('wp-05-result');
    await j.tapKey('result-done');
    expect(byKeyPrefix('train-open-'), findsNothing);
  });
}
