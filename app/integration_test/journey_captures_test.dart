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
    await j.createPlanFromTemplate();
    await j.tapKey('nav-today');
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

    // --- Today in Weather mode for a chosen city. With start-api.ps1 -FoodFixtures every place gets the recorded
    // Open-Meteo answer (overcast, night): simulated weather, not live conditions.
    await j.tapKey('nav-me');
    await j.tapKey('me-appearance');
    await j.tapKey('appearance-today-background');
    await j.tapKey('today-background-weather');
    await j.tapKey('weather-location-city');
    await j.type('city-search-field', 'Paris');
    await j.tapKey('city-search-go');
    await j.waitFor(find.textContaining('France'), what: 'Paris in the results', seconds: 30);
    await j.tap(find.textContaining('France').first);
    await j.settle(4);
    await tester.pageBack();
    await j.settle(2);
    await tester.pageBack();
    await j.settle(2);

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

    // --- For the recording: Today scrolled slowly to its end and back while the sky moves, then a capture of the
    // end of the page above the navigation bar.
    await j.tapKey('nav-today');
    await j.settle(4);
    await top();
    // Real time passes here (on a device pump() does not wait), so the recording sees the sky move.
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    debugPrint('GOHARD_REC:start');
    await watch(4000);
    final list = find.byType(Scrollable).hitTestable().first;
    for (final dy in [for (var i = 0; i < 10; i++) i < 5 ? -160.0 : 160.0]) {
      await tester.drag(list, Offset(0, dy));
      await watch(1500);
    }
    debugPrint('GOHARD_REC:stop');
    await tester.drag(list, const Offset(0, -2000));
    await j.settle(3);
    await j.shot('cap-dark-pink-7-today-end');
  });
}
