import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Guided setup, the quick guide, Ask GoHard, Leon/Leona and Today's rest day on the device (docs/COACH.md,
/// docs/TRAINING_PLANS.md › Today). Not in the default run: `scripts\test-android.ps1 -Only journey_coach_test`.
///
/// Leona is chosen in Appearance; Create plan offers Guide me; the one-time split hint appears in the page and is
/// closed; Compare splits and Why this suggestion? open built-in text; Ask GoHard opens with the split's name and,
/// against an API with no AI configured, says honestly that it is not available (the question kept); the suggested
/// plan is used and activated on days that leave today free, so Today shows a planned rest day; a manual workout
/// started on it is its own entry and the rest day stays. Coaching hints are then turned off.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coach: Leona, Guide me, quick guide, Ask GoHard unavailable, planned rest day with a manual workout', (tester) async {
    final j = Journey(tester, binding);
    // The builder's back arrow sits where Journey.closeSheet taps; close a sheet by its own route instead.
    Future<void> closeSheet(String key) async {
      Navigator.of(tester.element(find.byKey(Key(key)))).pop();
      await j.settle(6);
    }
    await j.start('Coach Journey');
    await j.settle(12); // the first pull brings the exercise catalog

    // --- Appearance: Leon by default, Leona chosen; nothing else changes.
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.reveal(find.byKey(const Key('coach-leon')));
    await j.shot('c01-appearance-coach-leon');
    await j.tapKey('coach-leona');
    await j.shot('c02-appearance-coach-leona');
    await tester.pageBack();
    await j.settle(4);

    // --- Create plan: Guide me, on three days that leave today free.
    await j.tapKey('nav-today');
    await j.tapKey('today-create-plan');
    await j.waitFor(find.byKey(const Key('plan-path-guided')), what: 'the two ways to create a plan');
    await j.shot('c03-create-plan-choices');
    await j.tapKey('plan-path-guided');
    final today = DateTime.now().weekday;
    await j.chooseDays({today % 7 + 1, (today + 2) % 7 + 1, (today + 4) % 7 + 1});
    await j.shot('c04-guided-availability');
    await j.tapKey('builder-next');

    // --- Structure: the guide introduces it once, in the page; the suggestion and its reason.
    await j.waitFor(find.byKey(const Key('coach-spot-builder.structure')), what: 'the one-time split introduction');
    await j.waitFor(find.byKey(const Key('guide-suggestion')), what: 'the suggested starting plan');
    // The words arrive as the guide settles (taps wait for them): real time and real frames, as pump() alone does not
    // wait on a device.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump(); // a device test advances animation only on pumped frames
    }
    await j.shot('c05-guided-suggestion-with-hint');
    await j.tapKey('coach-say-close');
    expect(find.byKey(const Key('coach-spot-builder.structure')), findsNothing);
    await j.tapKey('guide-compare');
    await j.waitFor(find.byKey(const Key('guide-compare-sheet')));
    await j.shot('c06-compare-splits');
    await closeSheet('guide-compare-sheet');
    await j.tapKey('guide-why');
    await j.waitFor(find.byKey(const Key('guide-why-sheet')));
    await j.shot('c07-why-this-suggestion');

    // --- Ask GoHard from Why: no request until Send; with no AI configured, an honest unavailable state.
    await j.tapKey('guide-why-ask');
    await j.waitFor(find.byKey(const Key('ask-context')), what: 'Ask GoHard with its context');
    await j.shot('c08-ask-initial');
    await j.type('ask-input', 'What does 3 × 8–12 mean?');
    await j.tapKey('ask-send');
    await j.waitFor(find.byKey(const Key('ask-problem')), what: 'the AI-unavailable state', seconds: 40);
    expect(find.textContaining('Offline'), findsNothing);
    expect(find.text('What does 3 × 8–12 mean?'), findsWidgets, reason: 'the question is kept');
    await j.shot('c09-ask-unavailable');
    await j.tapKey('ask-close');
    await j.waitFor(find.byKey(const Key('guide-suggestion')), what: 'back on the same builder step');

    // --- Use the suggestion; exercise quick help; activate.
    await j.tapKey('guide-use-full-body');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('exercise-info-0-0')), what: 'the workout editor');
    await j.tapKey('exercise-info-0-0');
    await j.waitFor(find.byKey(const Key('exercise-info-sheet')));
    await j.shot('c10-exercise-quick-help');
    await closeSheet('exercise-info-sheet');
    await j.tapKey('builder-next');
    await j.waitFor(find.byKey(const Key('plan-activate')), what: 'the review');
    await j.tapKey('plan-activate');
    await j.waitFor(find.byKey(const Key('train-plan')), what: 'Train after activating');

    // --- Today: a planned rest day, with manual training still on offer.
    await j.tapKey('nav-today');
    await j.waitFor(find.text('Planned rest day'), what: 'the plan\'s rest day');
    expect(find.byKey(const Key('today-start')), findsNothing, reason: 'no future workout is presented as today\'s');
    await j.shot('c11-today-planned-rest');
    await j.tapKey('today-manual');
    await j.type('manual-title', 'Arms');
    await j.tapKey('manual-start');
    await j.waitFor(find.text('Arms'), what: 'the manual workout');
    await j.settle(4);
    await j.tapKey('nav-today');
    await j.settle(6);
    await j.waitFor(find.byKey(const Key('today-resume')), what: 'the manual workout\'s own Resume');
    expect(find.text('Planned rest day'), findsOneWidget, reason: 'the rest day is still the plan\'s fact');
    expect(find.text('Arms'), findsOneWidget);
    await j.shot('c12-today-rest-with-manual-open');

    // --- Coaching hints off; manual help stays (the avatar button in the builder is unaffected).
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.reveal(find.byKey(const Key('coach-hints')));
    await j.tap(find.descendant(of: find.byKey(const Key('coach-hints')), matching: find.byType(Switch)));
    await j.shot('c13-appearance-hints-off');
    await tester.pageBack();
    await j.settle(4);
  });
}
