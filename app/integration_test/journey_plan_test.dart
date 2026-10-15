import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// The plan builder on the device, in two runs of this file by scripts\test-android.ps1 (a real process end between).
///
/// Phase 1, OFFLINE (the script switches the emulator's network off on GOHARD_NET:off): a template plan is previewed,
/// customised (prescription with a weight target, a replaced exercise, a private exercise of my own) and activated;
/// today's workout is started and one set recorded; the app is left with the workout open. The process then ends.
///
/// Phase 2, a new process, back online: the plan and the open workout with its set are read back from the phone, the
/// queued commands reach the account, the workout is finished; one occurrence is moved; the plan is edited from today
/// (completed history unchanged); then "Build my own" makes a rotating plan that replaces the first (explicitly),
/// Today shows its next workout, a skip advances it once. Light and dark captures of the builder, Plan and Today.
const _phase = String.fromEnvironment('GOHARD_PHASE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plan builder phase $_phase: template customised and activated offline, recovered after the process ends, moved, edited, replaced by my own rotation', (tester) async {
    final j = Journey(tester, binding);
    if (_phase == '1') {
      await j.start('Plan Builder');
      await j.settle(12); // the first pull brings the exercise catalog
      // ignore: avoid_print
      print('GOHARD_NET:off');
      await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');

      // --- Template path: availability, the suggestion, a preview that creates nothing.
      await j.tapKey('today-create-plan');
      await j.tapKey('plan-path-direct'); // I know what I want
      await j.tapKey('plan-path-template');
      await j.chooseDays(Journey.daysIncludingToday());
      await j.shot('p01-builder-availability');
      await j.tapKey('builder-next');
      await j.waitFor(find.byKey(const Key('template-suggestion')), what: 'the suggested template and its reason');
      await j.tap(find.byKey(const Key('template-push-pull-legs')));
      await j.shot('p02-builder-template-preview');
      await j.tap(find.byKey(const Key('template-full-body'))); // back to the suggestion: nothing was created by looking
      await j.tapKey('builder-next');

      // --- Customise: 4 sets with a 60 kg target, a replaced exercise, and a private exercise of my own.
      await j.tapKey('exercise-0-0');
      await j.type('rx-sets', '4');
      await j.type('rx-load', '60');
      await j.tapKey('rx-save');
      await j.waitFor(find.textContaining('Target 60'), what: 'the weight target on the exercise');
      await j.tapKey('exercise-menu-0-2');
      await j.tapKey('exercise-replace-0-2');
      await j.type('exercise-search', 'dumbbell row');
      await j.tapKey('exercise-dumbbell-row');
      await j.waitFor(find.text('3. Dumbbell row'), what: 'the replaced exercise in its place');
      await j.tapKey('exercise-add-0');
      await j.type('exercise-search', 'Sled push');
      await j.tapKey('exercise-create-custom');
      await j.waitFor(find.byKey(const Key('custom-save')));
      await j.tapKey('custom-save');
      await j.waitFor(find.textContaining('Sled push'), what: 'my own exercise added');
      await j.shot('p03-builder-workout-editor');
      await j.tapKey('builder-next');
      await j.waitFor(find.byKey(const Key('plan-activate')), what: 'the review');
      await j.shot('p04-builder-review');
      await j.tapKey('plan-activate');

      // --- Active plan on Train and Today, still offline.
      await j.waitFor(find.byKey(const Key('train-plan')), what: 'Train after activating');
      await j.waitFor(find.textContaining('Week 1 of'), what: 'the active plan');
      await j.shot('p05-train-plan-active');
      await j.tapKey('nav-today');
      await j.waitFor(find.byKey(const Key('today-start')), what: 'today\'s workout from the new plan');
      await j.shot('p06-today-plan-due');
      await j.tapKey('today-start');
      await j.waitFor(find.byKey(const Key('complete-set')));
      expect(find.textContaining('Target 60'), findsWidgets, reason: 'the target travels into the workout, apart from any record');
      await j.type('set-load', '57.5');
      await j.type('set-reps', '8');
      await j.tapKey('complete-set');
      await j.waitFor(find.byKey(const Key('set-row-0')));
      await tester.pageBack(); // the workout stays open; nothing finishes it
      await j.waitFor(find.byKey(const Key('today-resume')), what: 'the open workout on Today');
      await j.shot('p07-before-process-ends');
      return;
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    // ignore: avoid_print
    print('GOHARD_NET:on');
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('today-resume')), what: 'the open workout after the process ended', seconds: 40);
    // 1 of 16: the set recorded offline, against the customised prescription (4 sets on the first exercise + 4 × 3).
    await j.waitFor(find.text('of 16 sets'), what: 'the customised prescription after the process ended');
    await j.waitFor(find.text('1'), what: 'the set recorded before the process ended (the count settles after a short animation)');
    await j.waitUntil(() async => await j.apiReachable(), what: 'the network to be back');
    await j.tapKey('today-resume');
    await j.waitFor(find.byKey(const Key('set-row-0')), what: 'the set recorded offline before the process ended');
    await j.shot('p08-recovered-workout');
    await j.tapKey('finish-workout');
    await j.tapKey('finish-confirm');
    await j.tapKey('result-done');

    // The queued plan, activation, start, set and finish reach the account once each.
    await j.tapKey('nav-me');
    await j.reveal(find.byKey(const Key('me-sign-out')));
    await j.waitFor(find.textContaining('@example.test'), what: 'the signed-in email (a new process does not know it)');
    j.email = (tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').firstWhere((s) => s.contains('@example.test'))).trim();
    final token = await j.apiToken();
    await j.waitUntil(() async {
      final s = await j.snapshot(token);
      final plans = ((s['context'] as Map)['plans'] as List).cast<Map>();
      final workouts = (s['workouts'] as List).cast<Map>();
      return plans.length == 1 && plans.single['lifecycle'] == 'active' && workouts.length == 1 && workouts.single['finishedAtUtc'] != null;
    }, what: 'the offline plan and workout to reach the account');
    final s = await j.snapshot(token);
    final plan = (((s['context'] as Map)['plans'] as List).single as Map);
    expect(((plan['workouts'] as List).first as Map)['exercises'].length, 5, reason: 'the customised workout, with my own exercise');
    expect((s['customExercises'] as List).single['name'], 'Sled push');

    // --- Move one occurrence (the third this week) one day later: it keeps its identity and original date.
    await j.tapKey('nav-train');
    await j.tapKey('train-plan');
    await j.tapKey('occasion-1-3');
    await j.tapKey('occasion-move');
    await j.waitFor(find.text('OK'));
    final from = DateTime.now().add(const Duration(days: 4)), to = DateTime.now().add(const Duration(days: 5));
    if (to.month != from.month) await j.tap(find.byTooltip('Next month'));
    await j.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('${to.day}')));
    await j.tapText('OK');
    await j.confirmWith('Move workout');
    await j.waitFor(find.textContaining('originally'), what: 'the moved workout keeping its original date');
    await j.closeSheet();

    // --- Edit the plan from today: rename the second workout. Today's finished workout is history and stays as it was.
    await j.tapKey('plan-edit');
    await j.tapKey('builder-next');
    await j.tapKey('workout-menu-1');
    await j.tapKey('workout-rename-1');
    await j.type('workout-name-field', 'Full body B, heavier');
    await j.tapKey('workout-name-save');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('plan-effective-date')), what: 'the edit scope and its effective date');
    await j.shot('p09-edit-scope-review');
    await j.tapKey('plan-save-changes');
    await j.waitFor(find.textContaining('Full body B, heavier'), what: 'the future workout renamed');
    expect(find.text('Full body A'), findsWidgets, reason: 'today\'s recorded occurrence keeps its name');

    // --- Build my own rotating, ongoing plan; it replaces the first only after an explicit confirmation.
    await j.tapText('Create a different plan');
    await j.tapKey('plan-path-direct'); // I know what I want
    await j.tapKey('plan-path-custom');
    await j.chooseDays(Journey.daysIncludingToday());
    await j.tapKey('builder-next');
    await j.type('custom-workout-name-0', 'Push day');
    await j.type('custom-workout-name-1', 'Pull day');
    await j.type('custom-workout-name-2', 'Leg day');
    await j.type('plan-title', 'My rotation');
    await j.tapKey('mode-rotating');
    await j.tapKey('duration-ongoing');
    await j.shot('p10-own-plan-rotation-structure');
    await j.tapKey('builder-next');
    for (final (i, key) in const ['exercise-push-up', 'exercise-pull-up', 'exercise-goblet-squat'].indexed) {
      await j.tapKey('exercise-add-$i');
      await j.tapKey(key);
    }
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('review-replaces')), what: 'the review naming the plan it replaces');
    await j.shot('p11-rotation-review');
    await j.tapKey('plan-activate');
    await j.confirmWith('Pause and activate');
    await j.waitFor(find.byKey(const Key('cycle-step-0')), what: 'the cycle overview');
    await j.shot('p12-train-rotation');

    // --- Today: the rotation's next workout; a skip moves on exactly one step. Today keeps the skipped workout as
    // Skipped today and names the next one as next in the rotation, never as due today.
    await j.tapKey('nav-today');
    await j.waitFor(find.text('Push day'), what: 'the rotation\'s first workout due today');
    await j.shot('p13-today-rotation-due');
    await j.tapKey('today-details');
    await j.tapKey('occasion-skip');
    await j.confirmWith('Skip this workout');
    await j.closeSheet();
    await j.waitFor(find.text('Skipped today'), what: 'the skipped workout kept on Today');
    expect(find.text('Push day'), findsOneWidget);
    expect(find.textContaining('Next in your rotation: Pull day'), findsOneWidget);
    expect(find.text('Due today'), findsNothing);
    expect(find.byKey(const Key('today-train-now')), findsOneWidget);
    await j.shot('p14-today-after-skip');

    // --- Dark captures of the same states.
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.tapKey('appearance-dark');
    await tester.pageBack();
    await j.settle(6);
    await j.tapKey('nav-train');
    await j.tapKey('train-plan');
    await j.waitFor(find.byKey(const Key('cycle-step-0')));
    await j.shot('p15-train-rotation-dark');
    await j.tapKey('nav-today');
    await j.waitFor(find.text('Skipped today'));
    await j.shot('p16-today-rotation-dark');
    await j.tapKey('nav-train');
    await j.tapText('Create a different plan');
    await j.tapKey('plan-path-direct'); // I know what I want
    await j.tapKey('plan-path-template');
    await j.chooseDays(Journey.daysIncludingToday());
    await j.tapKey('builder-next');
    await j.shot('p17-builder-templates-dark');
    await j.tapKey('builder-next');
    await j.shot('p18-builder-editor-dark');
    await j.tapKey('builder-next');
    await j.shot('p19-builder-review-dark');
    await j.tapKey('plan-save-draft');
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.tapKey('appearance-light');
  });
}
