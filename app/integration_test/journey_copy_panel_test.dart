import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/meal_copy_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Repeat a meal and the workout exercise panel on a real install (docs/MEAL_COPY_WORKOUT_PANEL.md), against the local
/// API that captures mail. Not in the default run:
/// `scripts\test-android.ps1 -Only journey_copy_panel_test`.
///
/// One process. Yesterday's breakfast is logged from the bundled common foods (no provider asked); today, Same as
/// yesterday? → change one amount → back (nothing logged) → Review & log → Log this time (logged once, checked on the
/// account). Then a template plan, an earlier manual session of its first exercise, Start: last session set by set,
/// the set being entered, Use last values asking before replacing a typed weight, Record set, rest, Next exercise and
/// back with the typed draft kept. A new account is Free: no personal aim is shown (Plus only), which is checked.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('repeat a meal, then the exercise panel', (tester) async {
    final j = Journey(tester, binding);
    TextEditingController field(String key) => tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField))).controller!;
    Future<List> entries() async => (await j.snapshot(await j.apiToken()))['foodEntries'] as List;

    await j.start('Copy Journey');

    // --- Yesterday's breakfast, logged from the common foods.
    await j.tapKey('nav-eat');
    await j.tap(find.byTooltip('Previous day'));
    for (final (query, name) in [('egg', 'Eggs'), ('oatmeal', 'Oats')]) {
      await j.tapKey('eat-add-breakfast');
      await j.type('food-search', query);
      await j.tap(find.descendant(of: find.byType(ListView), matching: find.text(name)));
      await j.waitFor(find.byKey(const Key('food-save')), what: 'the amount form');
      await j.tapKey('food-save');
      await j.waitFor(find.descendant(of: find.byType(EatScreen), matching: find.text(name)), what: '$name in yesterday’s breakfast');
    }
    await j.waitUntil(() async => (await entries()).length == 2, what: 'yesterday on the account');
    // Back to today sits under the date at the top of Eat's (lazily built) list: back to the top first, as a person would.
    tester.state<ScrollableState>(find.ancestor(of: find.byKey(const Key('eat-add-breakfast')), matching: find.byType(Scrollable)).first).position.jumpTo(0);
    await j.settle(4);
    await j.tapKey('eat-back-to-today');

    // --- Same as yesterday? Review, change one amount, go back: nothing logged.
    debugPrint('GOHARD_REC:start:copy-panel-recording');
    await j.waitFor(find.byKey(const Key('eat-repeat-breakfast')), what: 'Same as yesterday? in today’s empty breakfast');
    await j.shot('cp-01-eat-same-as-yesterday');
    await j.tapKey('eat-repeat-review-breakfast');
    await j.waitFor(find.byKey(const Key('copy-log')), what: 'the copy review');
    await j.shot('cp-02-copy-review');
    await j.tapKey('copy-item-0');
    await j.type('food-quantity', '3');
    await j.tapKey('food-save');
    await j.waitFor(find.byKey(const Key('copy-log')), what: 'back in the review');
    await j.shot('cp-03-copy-review-changed');
    await Navigator.of(tester.element(find.byType(MealCopyScreen))).maybePop();
    await j.settle(6);
    expect(await entries(), hasLength(2), reason: 'reviewing and going back log nothing');

    // --- Review & log, then Log this time: once.
    await j.tapKey('eat-repeat-review-breakfast');
    await j.tapKey('copy-log');
    await j.waitFor(find.byKey(const Key('eat-copy-meal-breakfast')), what: 'today’s breakfast, logged');
    await j.shot('cp-04-eat-copied');
    await j.waitUntil(() async => (await entries()).length == 4, what: 'the copy on the account');
    await j.settle(10);
    expect(await entries(), hasLength(4), reason: 'logged once');

    // --- A plan, and an earlier session of its first exercise.
    await j.tapKey('nav-today');
    await j.tapKey('today-create-plan');
    await j.createPlanFromTemplate();
    await j.tapKey('nav-today');
    await j.tapKey('today-details');
    await j.waitFor(find.byKey(const Key('workout-preview')), what: 'the preview');
    final first = tester.widget<Text>(find.descendant(of: find.byKey(const Key('preview-exercise-0')), matching: find.byType(Text)).at(1)).data!;
    FocusManager.instance.primaryFocus?.unfocus();
    tester.state<ScrollableState>(find.ancestor(of: find.byKey(const Key('workout-all')), matching: find.byType(Scrollable)).first).position.jumpTo(0);
    await j.settle(4);
    await j.tapKey('workout-all');
    await j.tapKey('start-manual');
    await j.type('manual-title', 'Earlier');
    await j.tapKey('manual-add-exercise');
    await j.type('exercise-search', first);
    await j.tap(find.descendant(of: find.byType(ListRow), matching: find.text(first)));
    await j.tapKey('manual-start');
    await j.waitFor(find.byKey(const Key('complete-set')), what: 'the manual workout');
    for (final (load, reps) in [('40', '10'), ('42.5', '8')]) {
      await j.type('set-load', load);
      await j.type('set-reps', reps);
      await j.tapKey('complete-set');
      await j.settle(4);
    }
    await j.tapKey('finish-workout');
    await j.tapKey('finish-confirm');
    await j.waitFor(find.byKey(const Key('workout-result')), what: 'the result');
    await j.tapKey('result-done');

    // --- Start the planned workout: last session set by set, the set being entered, nothing invented.
    await j.tapKey('nav-today');
    await j.tapKey('today-details');
    await j.tapKey('preview-start');
    await j.waitFor(find.byKey(const Key('entry-heading')), what: 'the recorder');
    expect(tester.widget<Text>(find.byKey(const Key('entry-last-ref'))).data, 'Last session, set 1: 40 kg × 10');
    expect(find.byKey(const Key('suggested-today')), findsNothing, reason: 'Free: no personal aim');
    expect(find.byKey(const Key('compare-table')), findsNothing, reason: 'compact by default');
    FocusManager.instance.primaryFocus?.unfocus();
    await j.settle(2);
    await Scrollable.ensureVisible(tester.element(find.byKey(const Key('workout-exercise-panel'))), alignment: 0.05);
    await j.settle(3);
    await j.shot('cp-05-exercise-panel-compact');
    // Compare all sets: every set with its own load.
    await j.tapKey('compare-toggle');
    expect(find.descendant(of: find.byKey(const Key('compare-1-last')), matching: find.text('42.5 kg × 8')), findsOneWidget, reason: 'each set with its own load');
    await j.shot('cp-06-compare-all-sets');
    await j.tapKey('compare-toggle');

    // Use last values asks before replacing what was typed, and records nothing.
    await j.type('set-load', '45');
    await j.tapKey('use-last-values');
    await j.waitFor(find.text('Replace what you typed?'));
    await j.confirmWith('Use last values');
    expect((field('set-load').text, field('set-reps').text), ('40', '10'));
    expect(find.byKey(const Key('set-row-0')), findsNothing, reason: 'filling is not recording');
    await j.type('set-reps', '11');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('rest-clock')), what: 'rest under Record set');
    expect(tester.widget<Text>(find.byKey(const Key('entry-heading'))).data, contains('Set 2'));
    FocusManager.instance.primaryFocus?.unfocus();
    await j.settle(2);
    await Scrollable.ensureVisible(tester.element(find.byKey(const Key('entry-heading'))), alignment: 0.3);
    await j.settle(3);
    await j.shot('cp-07-recorded-rest');

    // Next exercise and back: the typed draft, the set and the rest stay.
    await j.type('set-load', '50');
    await j.tapKey('next-exercise');
    await j.settle(4);
    await j.tapKey('exercise-row-1');
    await j.settle(4);
    expect(field('set-load').text, '50', reason: 'the draft of the first exercise');
    expect(find.byKey(const Key('set-row-0')), findsOneWidget);
    expect(find.byKey(const Key('rest-clock')), findsOneWidget);
    debugPrint('GOHARD_REC:stop');
    await j.settle(8);
  });
}
