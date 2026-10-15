import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// R5, fourth native journey: the remaining secondary screens. Fit feedback and building your own plan;
/// undoing and editing a set; pounds at the entry boundary; body measurements; moving a workout; replacing a
/// movement through a reviewed proposal; replacing the primary plan and archiving the old one.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('own_plan_draft_set_edit_units_metrics_move_substitute_replace_archive', (tester) async {
    final j = Journey(tester, binding);
    await j.start('More Tester');

    // --- Build my own plan and save it as a draft: nothing is created, scheduled or activated.
    await j.tapKey('today-create-plan');
    await j.tapKey('plan-path-custom');
    await j.chooseDays(Journey.daysIncludingToday());
    await j.tapKey('equipment-dumbbells');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('custom-workout-name-0')), what: 'my workout names');
    expect(find.text('My plan'), findsWidgets);
    await j.shot('60-own-plan-structure');
    await j.tapKey('builder-next');
    for (var i = 0; i < 3; i++) {
      await j.tapKey('exercise-add-$i');
      await j.tapKey(i == 1 ? 'exercise-plank' : 'exercise-push-up');
    }
    await j.shot('61-own-plan-workouts');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('plan-save-draft')), what: 'the review of my own plan');
    await j.tapKey('plan-save-draft');
    await j.settle(6);
    await j.waitFor(find.text('No plan yet'), what: 'Today: a saved draft schedules nothing');

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
    // The Today background follows the weather of a chosen city (recorded provider answers: an overcast night).
    // "Paris" has several matches, so the list says which is which before one is chosen.
    await j.tapKey('appearance-today-background');
    await j.tapKey('today-background-weather');
    await j.tapKey('weather-location-city');
    await j.type('city-search-field', 'Paris');
    await j.tapKey('city-search-go');
    await j.waitFor(find.byKey(const Key('city-result-4717560')), what: 'Paris, Texas listed beside Paris, France');
    await j.shot('62c-city-choice');
    await j.tapKey('city-result-2988507');
    await j.settle();
    await tester.pageBack();
    await j.settle();
    await tester.pageBack();
    await j.settle();
    await j.tapKey('nav-today');
    await j.settle(8);
    await j.shot('62b-today-in-progress-green-dark');
    // What Today's scene is based on, said where the setting is: the condition, its time and the place.
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.tapKey('appearance-today-background');
    await j.waitFor(find.byKey(const Key('weather-condition')), what: 'the weather the scene follows');
    expect(find.textContaining('Paris'), findsWidgets);
    await j.shot('62d-today-background-weather');
    await tester.pageBack();
    await j.settle();
    await tester.pageBack();
    await j.settle();
    await j.tapKey('nav-today');
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

    // --- My saved draft, resumed and activated; then move its last first-week workout one day later.
    await j.tapKey('nav-train');
    await j.tapKey('train-plan');
    await j.tapKey('create-plan');
    await j.tapKey('plan-draft-resume');
    await j.waitFor(find.byKey(const Key('plan-activate')), what: 'my draft, back at its review');
    await j.tapKey('plan-activate');
    await j.waitFor(find.byKey(const Key('train-plan')), what: 'Train after activating');
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
    await j.tapKey('substitute-from-push-up');
    await j.tapKey('substitute-to');
    await j.tapKey('exercise-dumbbell-bench-press');
    await j.tapKey('substitution-submit');
    await j.waitFor(find.byKey(const Key('proposal-accept')), what: 'the proposal to review');
    expect(find.textContaining('Dumbbell bench press'), findsWidgets);
    await j.shot('65-proposal-review');
    await j.tapKey('proposal-accept');
    await j.waitFor(find.text('Pause plan').hitTestable(), what: 'the plan after accepting');
    await j.tapKey('occasion-1-1');
    await j.waitFor(find.text('Dumbbell bench press'), what: 'the replaced movement in a remaining workout');
    await j.closeSheet();

    // --- Replace the primary plan with a template plan (explicit), then archive the displaced one.
    await j.tapText('Create a different plan');
    await j.tapKey('plan-path-template');
    await j.chooseDays(Journey.daysIncludingToday());
    await j.tapKey('builder-next');
    await j.tapKey('builder-next');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('review-replaces')), what: 'the review naming the plan it replaces');
    await j.shot('66-replace-primary-review');
    await j.tapKey('plan-activate');
    await j.confirmWith('Pause and activate');
    await j.tapKey('nav-today');
    await j.waitFor(find.text('Due today'), what: 'Today driven by the new primary plan');
    await j.tapKey('nav-train');
    await j.tapText('My plan');
    await j.tapKey('plan-archive');
    await j.waitFor(find.textContaining('Archived plans (1)'), what: 'the archived plan hidden from the list');
    await j.shot('67-archived');
  });
}
