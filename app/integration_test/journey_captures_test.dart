import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Captures for design review, from the real app on a device against the local API: a realistic account (goals, an
/// active plan with today's workout in progress, logged food), then Today, Train › Plan, Eat, Me, food search and the
/// portion form, in Blue Light and in Pink Dark. Nothing here is a mockup or a widget render.
///
/// Run with `scripts\test-android.ps1 -Only journey_captures_test` (the API started with `start-api.ps1 -FoodFixtures`).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures: every main screen, food search and the portion form, in light and dark', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Alex Rivera');

    // --- Goals, so the nutrition rails and the ring have something real to show.
    await j.tapKey('nav-me');
    await j.tapKey('me-goals');
    await j.type('goal-calories', '2200');
    await j.type('goal-protein', '140');
    await j.tapKey('goal-save');
    await j.waitFor(find.text('2,200 kcal · 140 g protein'));

    // --- A plan with a workout due today, then two recorded sets, left open.
    await j.tapKey('nav-today');
    await j.tapKey('today-create-plan');
    await j.chooseTrainingDaysIncludingToday();
    await j.tapKey('setup-submit');
    await j.waitFor(find.byKey(const Key('plan-start')), what: 'the plan review');
    await j.tapKey('plan-start');
    await j.waitFor(find.byKey(const Key('today-start')), what: 'today\'s due workout');
    await j.tapKey('today-start');
    await j.waitFor(find.byKey(const Key('complete-set')));
    await j.type('set-load', '60');
    await j.type('set-reps', '8');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('rest-clock')));
    await j.tapKey('rest-skip');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('set-row-1')));
    await tester.pageBack();
    await j.settle(4);
    await j.waitFor(find.byKey(const Key('today-resume')), what: 'the open workout on Today');

    // --- Food: eggs for breakfast from the common foods, and a typed lunch.
    await j.tapKey('nav-eat');
    await j.tapKey('eat-add-breakfast');
    await j.type('food-search', 'eggs');
    await j.tapKey('common-eggs');
    await j.waitFor(find.byKey(const Key('food-quantity')));
    await j.type('food-quantity', '2');
    await j.tapKey('food-save');
    await j.waitFor(find.byKey(const Key('eat-add-lunch')));
    await j.tapKey('eat-add-lunch');
    await j.type('food-search', 'rice');
    await j.tapKey('common-white-rice');
    await j.waitFor(find.byKey(const Key('food-quantity')));
    await j.tapKey('food-save');
    await j.waitFor(find.byKey(const Key('eat-add-lunch')));

    Future<void> look(String accent, String mode) async {
      await j.tapKey('nav-me');
      await j.tapKey('me-appearance');
      await j.tapKey('accent-$accent');
      await j.tapKey('appearance-$mode');
      await tester.pageBack();
      await j.settle(4);
    }

    // A tab keeps its scroll position; a capture shows each screen from its top.
    Future<void> top() async {
      for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
        final position = (e as StatefulElement).state as ScrollableState;
        if (position.position.axis == Axis.vertical && position.position.pixels > 0) position.position.jumpTo(0);
      }
      await j.settle(4);
    }

    Future<void> every(String tag) async {
      await j.tapKey('nav-today');
      await j.settle(6);
      await top();
      await j.shot('cap-$tag-1-today');
      await j.tapKey('nav-train');
      await j.tapKey('train-plan');
      await j.waitFor(find.textContaining('Week 1 of'));
      await top();
      await j.shot('cap-$tag-2-train-plan');
      await j.tapKey('nav-eat');
      await j.settle(4);
      await top();
      await j.shot('cap-$tag-3-eat');
      await j.tapKey('nav-me');
      await j.settle(4);
      await top();
      await j.shot('cap-$tag-4-me');
      await j.tapKey('nav-eat');
      await j.tapKey('eat-add-lunch');
      await j.type('food-search', 'egg');
      await j.waitFor(find.byKey(const Key('common-egg-whites')));
      await j.shot('cap-$tag-5-food-search');
      await j.tapKey('common-egg-whites');
      await j.waitFor(find.byKey(const Key('food-quantity')));
      await j.shot('cap-$tag-6-portion');
      await j.tapKey('food-cancel');
      await j.settle(4);
      await j.tapKey('food-back');
      await j.settle(4);
    }

    await look('blue', 'light');
    await every('light-blue');
    await look('pink', 'dark');
    await every('dark-pink');
  });
}
