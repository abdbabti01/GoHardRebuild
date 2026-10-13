import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// A real cold start, in two runs of this file by scripts\test-android.ps1.
///
/// Phase 1 signs up, leaves a manual workout open with one recorded set, logs one food and leaves a run open.
/// When that run of the test ends, the Flutter tool stops the app: the process is gone. Phase 2 is a new process
/// on the same install (the app is not uninstalled in between), so everything it shows was read back from the
/// phone's storage: the session, the open workout and its set, the food, and the open run.
///
/// This is not the same as calling main() a second time inside one process, which the other journeys do.
const _phase = String.fromEnvironment('GOHARD_PHASE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold start phase $_phase: open workout, logged food and open run survive the process ending', (tester) async {
    final j = Journey(tester, binding);
    if (_phase == '1') {
      await j.start('Cold Start');

      await j.tapKey('nav-train');
      await j.tapKey('start-manual');
      await j.type('manual-title', 'Back');
      await j.tapKey('manual-add-exercise');
      await j.tapKey('exercise-push-up');
      await j.tapKey('manual-start');
      await j.type('set-reps', '10');
      await j.tapKey('complete-set');
      await j.waitFor(find.byKey(const Key('set-row-0')), what: 'the recorded set');
      await tester.pageBack(); // leaves the workout open; nothing finishes it
      await j.tapKey('nav-today');
      await j.waitFor(find.byKey(const Key('today-resume')), what: 'the open workout on Today');

      await j.tapKey('log-food');
      await j.tapKey('food-manual');
      await j.type('food-name', 'Banana');
      await j.type('food-amount', '1 medium');
      await j.type('food-calories', '105');
      await j.tapKey('food-save');
      await j.waitFor(find.text('1 food logged'), what: 'the food on Today');

      await j.tapKey('today-run');
      await j.waitFor(find.byKey(const Key('run-finish')), what: 'the run screen');
      await tester.pageBack(); // leaves the run open
      await j.waitFor(find.text('Continue run'), what: 'the open run on Today');
      await j.shot('110-coldstart-before-process-ends');
      return;
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    // A new process. No sign-in, no setup: only what the previous process saved.
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.text('Continue run'), what: 'the open run after a cold start', seconds: 40);
    expect(find.byKey(const Key('auth-submit')), findsNothing, reason: 'the session was kept');
    expect(find.text('Start run'), findsNothing);
    await j.waitFor(find.byKey(const Key('today-resume')), what: 'the open workout after a cold start');
    expect(find.text('Back'), findsOneWidget);
    await j.waitFor(find.text('1 set recorded'), what: 'the set recorded before the process ended');
    await j.waitFor(find.text('1 food logged'), what: 'the logged food after a cold start');
    expect(find.text('105'), findsOneWidget);
    await j.shot('111-coldstart-after-new-process');

    // The same run, then the same workout with its set.
    await j.tapKey('today-run');
    await j.waitFor(find.byKey(const Key('run-finish')), what: 'the same run');
    await j.tapKey('run-finish');
    await j.waitFor(find.text('Start run'), what: 'Today once that run is finished');
    await j.tapKey('today-resume');
    await j.waitFor(find.byKey(const Key('set-row-0')), what: 'the set recorded before the process ended');
    await j.shot('112-coldstart-workout-resumed');
  });
}
