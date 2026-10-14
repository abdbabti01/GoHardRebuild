import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// R5, fourth native journey: the remaining secondary screens. Fit feedback and building your own plan;
/// undoing and editing a set; pounds at the entry boundary; body measurements; moving a workout; replacing a
/// movement through a reviewed proposal; replacing the primary plan and archiving the old one.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fit_feedback_manual_plan_set_edit_units_metrics_move_substitute_replace_archive', (tester) async {
    final j = Journey(tester, binding);
    await j.start('More Tester');

    // --- Unsupported setup gives honest fit feedback and creates nothing; then build my own plan and save it.
    await j.tapKey('today-create-plan');
    await j.chooseTrainingDaysIncludingToday();
    await j.tapKey('equipment-dumbbells');
    await j.tapKey('setup-submit');
    await j.waitFor(find.text('No reviewed plan fits these answers'));
    expect(find.textContaining('needs full-gym equipment'), findsOneWidget);
    await j.shot('60-fit-feedback');
    await j.tapKey('setup-manual-plan');
    for (var i = 0; i < 3; i++) {
      await j.tapKey('manual-plan-add-$i');
      await j.tapKey(i == 1 ? 'exercise-plank' : 'exercise-push-up');
    }
    await j.shot('61-manual-plan-builder');
    await j.tapKey('manual-plan-submit');
    await j.waitFor(find.byKey(const Key('plan-start')), what: 'the review of my own plan');
    expect(find.text('My plan'), findsWidgets);
    await j.tapKey('plan-save-later');
    await j.settle(6);
    await j.waitFor(find.text('Your plan is ready to review'), what: 'Today offering the saved draft, not a started plan');

    // --- Pounds at the boundary, undo and edit of a recorded set.
    await j.tapKey('nav-me');
    await j.tapKey('me-units'); // Units is a row that opens a sheet; choosing closes it
    await j.tapKey('unit-lb');
    await j.tapKey('nav-train');
    await j.tapKey('start-manual');
    await j.tapKey('manual-add-exercise');
    await j.tapKey('exercise-bench-press');
    await j.tapKey('manual-start');
    await j.type('set-load', '100');
    await j.type('set-reps', '5');
    // Changing the look in the middle of a workout loses nothing: the typed entry and the open workout are still there.
    await tester.pageBack();
    await j.settle();
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.tapKey('accent-green');
    await j.tapKey('appearance-dark');
    await j.shot('62a-appearance-green-dark');
    await tester.pageBack();
    await j.settle();
    await j.tapKey('nav-today');
    await j.shot('62b-today-in-progress-green-dark');
    await j.tapKey('today-resume');
    await j.waitFor(find.byKey(const Key('complete-set')));
    String typed(String key) => tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).controller.text;
    expect((typed('set-load'), typed('set-reps')), ('100', '5'), reason: 'the unsaved entry survives a theme change');
    expect(find.byKey(const Key('set-row-0')), findsNothing, reason: 'and nothing was saved twice or by itself');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('set-row-0')));
    expect(find.textContaining('100 lb × 5'), findsWidgets);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo')); // tapped directly: it only exists while the message shows
    await j.settle();
    await j.waitFor(find.textContaining('None yet'), what: 'the set removed by Undo');
    await j.tapKey('complete-set'); // the entry kept its values, so recording it again is one tap
    await j.waitFor(find.byKey(const Key('set-row-0')));
    await j.tapKey('set-row-0');
    await j.waitFor(find.text('Edit set'));
    await tester.enterText(find.widgetWithText(TextField, 'Reps').last, '6');
    await j.confirmWith('Save');
    await j.waitFor(find.textContaining('100 lb × 6'));
    await j.shot('62-set-edited-in-pounds');
    await j.tapKey('finish-workout');
    await j.tapKey('finish-confirm');
    await j.tapKey('result-done');
    // The same record in kilograms: stored once in kg, only its presentation changes.
    await j.tapKey('nav-me');
    await j.tapKey('me-units');
    await j.tapKey('unit-kg');
    // History lives in Train, not Me.
    await j.tapKey('nav-train');
    await j.tapKey('train-progress');
    await j.tapText('Workout history');
    await j.tap(find.text('Workout'));
    await j.waitFor(find.textContaining('45.4 kg × 6'));
    await tester.pageBack();
    await j.settle();
    await tester.pageBack();
    await j.settle();

    // --- Body measurement.
    await j.tapKey('nav-me');
    await j.tapText('Body measurements');
    await j.type('metric-weight', '82.4');
    await j.tapKey('metric-save');
    await j.waitFor(find.text('82.4 kg'));
    await j.shot('63-body-measurement');
    await tester.pageBack();
    await j.settle();

    // --- A supported plan, then move its last first-week workout one day later (keeps its recovery spacing).
    await j.tapKey('nav-train');
    await j.tapKey('train-plan');
    await j.tapKey('create-plan');
    await j.chooseTrainingDaysIncludingToday();
    await j.tapKey('equipment-full_gym');
    await j.tapKey('setup-submit');
    await j.tapKey('plan-start');
    await j.waitFor(find.byKey(const Key('today-start')));
    await j.tapKey('nav-train');
    await j.waitFor(find.textContaining('Week 1 of').hitTestable());
    await j.tapKey('occasion-1-3');
    await j.waitFor(find.byKey(const Key('occasion-move')), what: 'the workout sheet with its Move action');
    await j.tapKey('occasion-move');
    await j.waitFor(find.text('OK'));
    final from = DateTime.now().add(const Duration(days: 4)), to = DateTime.now().add(const Duration(days: 5));
    if (to.month != from.month) await j.tap(find.byTooltip('Next month'));
    // Inside the picker only: the Train page underneath also shows this day number, and tapping that one lands on
    // the picker's barrier and closes it.
    await j.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('${to.day}')));
    await j.tapText('OK');
    await j.waitFor(find.text('Move this workout?'));
    await j.shot('64-move-review');
    await j.confirmWith('Move workout');
    await j.waitFor(find.textContaining('originally'), what: 'the moved workout keeping its original date');
    await j.closeSheet();

    // --- Replace a movement through a reviewed proposal.
    await j.tapText('Replace a movement in remaining workouts');
    await j.tapKey('substitute-from-bench-press');
    await j.tapKey('substitute-to');
    await j.tapKey('exercise-dumbbell-bench-press');
    await j.tapKey('substitution-submit');
    await j.waitFor(find.byKey(const Key('proposal-accept')), what: 'the proposal to review');
    expect(find.textContaining('Dumbbell bench press'), findsWidgets);
    await j.shot('65-proposal-review');
    await j.tapKey('proposal-accept');
    await j.waitFor(find.text('Pause plan').hitTestable(), what: 'the plan after accepting');
    await j.tapKey('occasion-1-2');
    await j.waitFor(find.text('Dumbbell bench press'), what: 'the replaced movement in a remaining workout');
    await j.closeSheet();

    // --- Replace the primary plan with my saved draft (explicit), then archive the displaced one.
    await j.tapText('My plan');
    await j.waitFor(find.text('Replace my current plan'));
    await j.shot('66-replace-primary-review');
    await j.tapKey('plan-start');
    await j.confirmWith('Pause and start');
    await j.waitFor(find.text('Due today'), what: 'Today driven by the new primary plan');
    await j.tapKey('nav-train');
    await j.tapText('Foundations of strength');
    await j.waitFor(find.textContaining('Archive'));
    await j.tap(find.textContaining('Archive (hide'));
    await j.waitFor(find.textContaining('Archived plans (1)'), what: 'the archived plan hidden from the list');
    await j.shot('67-archived');
  });
}
