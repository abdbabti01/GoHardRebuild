import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// R5: the joined native journey on a real device/emulator against the real local API and PostgreSQL.
/// A disposable account is registered for each run; nothing is mocked and no sample data is inserted.
///
/// Run with scripts\test-android.ps1 (it validates the device and the non-production API origin first).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int frames = 4]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder, {String? what, int seconds = 25}) async {
    for (var i = 0; i < seconds * 4; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 250));
    }
    final visible = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((s) => s.isNotEmpty).take(25).join(' | ');
    fail('Timed out waiting for ${what ?? finder}. On screen: $visible');
  }

  /// Lists build lazily: scroll the innermost list until the target exists.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await settle(tester, 2);
    if (finder.evaluate().isNotEmpty || find.byType(ListView).hitTestable().evaluate().isEmpty) return;
    // The page list itself, not a text field's inner scrollable.
    final list = find.descendant(of: find.byType(ListView).hitTestable().last, matching: find.byType(Scrollable)).first;
    for (final delta in const [300.0, -300.0]) {
      try {
        await tester.scrollUntilVisible(finder, delta, scrollable: list, maxScrolls: 25);
        return;
      } on StateError {
        // Not in that direction; try the other, then let waitFor report it properly.
      }
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await settle(tester, 2);
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) => tap(tester, find.byKey(Key(key)));
  Future<void> type(WidgetTester tester, String key, String text) async {
    await reveal(tester, find.byKey(Key(key)));
    await waitFor(tester, find.byKey(Key(key)));
    await tester.ensureVisible(find.byKey(Key(key)));

    // On a real device the first enterText after a focus change can be dropped; focus first, then verify and retry.
    final field = find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));
    for (var attempt = 0; attempt < 4; attempt++) {
      await tester.tap(find.byKey(Key(key)), warnIfMissed: false);
      await settle(tester, 2);
      if (field.evaluate().isEmpty) {
        fail('Field $key left the screen after it was tapped (attempt $attempt). On screen: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((x) => x.isNotEmpty).take(30).join(' | ')}');
      }
      await tester.enterText(find.byKey(Key(key)), text);
      await settle(tester, 2);
      if (tester.widget<EditableText>(field).controller.text == text) return;
    }
    fail('Could not type "$text" into $key');
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 3);
    await binding.takeScreenshot(name);
  }

  testWidgets('register_plan_workout_food_me_signout_signin', (tester) async {
    final email = 'journey-${DateTime.now().millisecondsSinceEpoch}@example.test';
    const password = 'journey password 1';
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await waitFor(tester, find.byKey(const Key('auth-submit')), what: 'the sign-in screen');
    await shot(tester, '01-sign-in');

    // --- Registration against the real API.
    await tapKey(tester, 'auth-toggle');
    await type(tester, 'auth-name', 'Journey Tester');
    await type(tester, 'auth-email', email);
    await type(tester, 'auth-password', password);
    await tapKey(tester, 'auth-submit');
    await waitFor(tester, find.text('No active plan'), what: 'Today for a new account');
    expect(find.text('No food logged today'), findsOneWidget, reason: 'a new account has no invented nutrition');
    expect(find.text('Resume workout'), findsNothing);
    await shot(tester, '02-today-new-account');

    // --- Create plan → review → activation. Days are chosen so a workout is due on whatever day this runs.
    await tapKey(tester, 'today-create-plan');

    await Journey(tester, binding).createPlanFromTemplate(shotPrefix: '03');

    expect(find.text('Full Body'), findsWidgets, reason: 'the plan is the user\'s own copy of the template');

    await tapKey(tester, 'nav-today');
    await waitFor(tester, find.byKey(const Key('today-start')), what: 'today\'s due workout');
    await shot(tester, '05-today-workout-due');
    // The title opens the workout's details; the button underneath stays the one main action.
    await tapKey(tester, 'today-details');
    await waitFor(tester, find.byKey(const Key('occasion-start')), what: 'the workout details');
    await shot(tester, '05b-today-workout-details');
    await tester.tapAt(const Offset(20, 60)); // close the sheet
    await settle(tester, 4);

    // --- All four tabs; Train keeps its selected section.
    await tapKey(tester, 'nav-train');
    await tapKey(tester, 'train-plan');
    await waitFor(tester, find.textContaining('Week 1 of'));
    await shot(tester, '06-train-plan');
    await tapKey(tester, 'nav-eat');
    await tapKey(tester, 'nav-me');
    await tapKey(tester, 'nav-train');
    expect(find.textContaining('Week 1 of'), findsOneWidget, reason: 'Train retained the Plan section');
    await tapKey(tester, 'nav-today');

    // --- Actual workout: entered values become the set; rest starts; nothing advances by itself.
    await tapKey(tester, 'today-start');
    await waitFor(tester, find.byKey(const Key('complete-set')));
    expect(find.textContaining('None yet'), findsOneWidget, reason: 'targets are not recorded sets');
    await type(tester, 'set-load', '60');
    await type(tester, 'set-reps', '8');
    await shot(tester, '07-workout-entry');
    await tapKey(tester, 'complete-set');
    await waitFor(tester, find.byKey(const Key('set-row-0')));
    await waitFor(tester, find.byKey(const Key('rest-clock')), what: 'the rest countdown');
    expect(find.textContaining('60 kg × 8'), findsWidgets);
    await shot(tester, '08-workout-rest');
    await tapKey(tester, 'rest-skip');
    // The entry keeps its values, so the next set is one tap. Two more reach the 3-set target.
    await tapKey(tester, 'complete-set');
    await waitFor(tester, find.byKey(const Key('set-row-1')));
    await tapKey(tester, 'complete-set');
    await waitFor(tester, find.byKey(const Key('set-row-2')));
    expect(find.text('Add another set'), findsOneWidget, reason: 'reaching the target does not change exercise');
    expect(find.text('Back squat'), findsWidgets);
    await tapKey(tester, 'rest-skip');
    await tapKey(tester, 'complete-set'); // an extra set stays possible
    await waitFor(tester, find.byKey(const Key('set-row-3')));
    await shot(tester, '09-workout-target-reached-extra-set');
    await tapKey(tester, 'next-exercise'); // the deliberate transition
    await waitFor(tester, find.text('Bench press'));

    // --- Partial finish: honest result, one credit.
    await tapKey(tester, 'finish-workout');
    await waitFor(tester, find.byKey(const Key('finish-confirm')));
    expect(find.textContaining('Not fully recorded'), findsOneWidget);
    await shot(tester, '10-finish-review-partial');
    await tapKey(tester, 'finish-confirm');
    await waitFor(tester, find.text('Finished partially'));
    await shot(tester, '11-result-partial');
    await tapKey(tester, 'result-done');
    await waitFor(tester, find.text('Partly completed'));
    expect(find.byKey(const Key('today-start')), findsNothing, reason: 'the recorded occasion is not offered again');
    await shot(tester, '12-today-done');

    // --- Food: blank protein stays unknown, entered zero stays zero; Today and Eat agree.
    await tapKey(tester, 'log-food');
    await tapKey(tester, 'food-manual'); // typed by hand; search and barcode are journey_food_test
    await type(tester, 'food-name', 'Greek yogurt');
    await type(tester, 'food-amount', '200 g');
    await type(tester, 'food-calories', '110');
    await type(tester, 'food-fat', '0');
    await shot(tester, '13-food-form');
    await tapKey(tester, 'food-save');
    await waitFor(tester, find.text('Some nutrition values are missing'));
    expect(find.text('110'), findsOneWidget);
    expect(find.text('—'), findsOneWidget, reason: 'protein is unknown, not zero');
    await shot(tester, '14-today-nutrition-known-totals');
    await tapKey(tester, 'today-nutrition-missing'); // the short note leads to the full explanation in Eat
    await waitFor(tester, find.text('Greek yogurt'));
    expect(find.text('Known totals'), findsWidgets);
    expect(find.text('0 g'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2), reason: 'protein and carbs are unknown, not zero');
    await shot(tester, '15-eat-journal');
    // Edit then cancel keeps the recorded version; then a real edit; then confirmed removal.
    await tap(tester, find.text('Greek yogurt'));
    await type(tester, 'food-name', 'Something else');
    await tapKey(tester, 'food-cancel');
    await waitFor(tester, find.text('Greek yogurt'));
    await tap(tester, find.text('Greek yogurt'));
    await type(tester, 'food-protein', '20');
    await tapKey(tester, 'food-save');
    await waitFor(tester, find.text('20 g'));
    await tapKey(tester, 'log-food');
    await tapKey(tester, 'food-manual');
    await type(tester, 'food-name', 'Toast');
    await type(tester, 'food-amount', '2 slices');
    await tapKey(tester, 'food-save');
    await waitFor(tester, find.text('Toast'));
    await tap(tester, find.text('Toast'));
    await tapKey(tester, 'food-remove');
    await shot(tester, '16-food-remove-confirmation');
    await tap(tester, find.widgetWithText(FilledButton, 'Remove this food'));
    await settle(tester, 6);
    expect(find.text('Toast'), findsNothing);
    expect(find.text('Greek yogurt'), findsOneWidget, reason: 'removing one food leaves the other');

    // --- Me: shared appearance, history, then non-destructive sign-out and sign-in.
    await tapKey(tester, 'nav-me');
    await waitFor(tester, find.text('Journey Tester'));
    await shot(tester, '17-me');
    // Appearance has its own page: mode and accent are two independent choices, applied at once.
    await tapKey(tester, 'me-appearance');
    await shot(tester, '17b-appearance-system');
    await tapKey(tester, 'appearance-light');
    await tapKey(tester, 'accent-green');
    await settle(tester, 6);
    await shot(tester, '18-appearance-green-light');
    await tapKey(tester, 'accent-pink');
    await settle(tester, 6);
    await shot(tester, '18b-appearance-pink-light');
    await tester.pageBack();
    await settle(tester, 4);
    await waitFor(tester, find.text('Pink · Light'));
    await shot(tester, '18c-me-light');
    await tapKey(tester, 'nav-today');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await shot(tester, '19-today-pink-light');
    await tapKey(tester, 'nav-train');
    await tapKey(tester, 'train-progress');
    await waitFor(tester, find.text('Am I following my plan?'));
    expect(find.textContaining('1 of 1 due workouts recorded'), findsOneWidget);
    await shot(tester, '20-train-progress-pink-light');
    await tapKey(tester, 'train-workouts');
    await shot(tester, '21-train-workouts-pink-light');

    await tapKey(tester, 'nav-me');
    await tapKey(tester, 'me-appearance');
    await tapKey(tester, 'appearance-dark');
    await tapKey(tester, 'accent-blue');
    await tester.pageBack();
    await settle(tester, 4);
    // Let the page finish closing and the new theme settle before the next tap: on a device pump() does not wait, and a
    // tap during that moment intermittently found nothing (seen 16 Oct 2026; Me itself was intact throughout).
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
    await tapKey(tester, 'me-sign-out');
    await tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
    await waitFor(tester, find.byKey(const Key('auth-submit')), what: 'the sign-in screen after sign-out');
    await type(tester, 'auth-email', email);
    await type(tester, 'auth-password', 'wrong password');
    await tapKey(tester, 'auth-submit');
    await waitFor(tester, find.textContaining('do not match'));
    // A failed attempt keeps what was typed: the email is still there and only the password is retyped.
    expect(tester.widget<TextField>(find.byKey(const Key('auth-email'))).controller!.text, email);
    await type(tester, 'auth-password', password);
    await tapKey(tester, 'auth-submit');
    await waitFor(tester, find.text('Partly completed'), what: 'the same account\'s day after signing back in');
    await waitFor(tester, find.text('Some nutrition values are missing'));
    expect(find.text('110'), findsOneWidget);
    await shot(tester, '22-today-after-sign-in-again');
  });
}
