import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart' show EatScreen;
import 'package:gohard_rebuild/features/shell/home_shell.dart' show GoNavigationBar;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Eat's compact top on a device (docs/FOOD_DATA.md › Compact top), one process, a new account against the local API:
/// the empty day, goals through Set daily goals, one food logged by hand, then Nutrition details and Nutrition settings.
/// Prints where the first meal's heading and Add food sit against the floating bar (GOHARD_EAT_TOP lines). Not in the
/// default run.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Eat compact top: empty day, goals, one food, details, settings', (tester) async {
    final j = Journey(tester, binding);
    final eat = find.byType(EatScreen);
    Finder inEat(String key) => find.descendant(of: eat, matching: find.byKey(Key(key)));

    Future<void> top() async {
      final list = find.descendant(of: eat, matching: find.byType(Scrollable)).first;
      tester.state<ScrollableState>(list).position.jumpTo(0);
      await j.settle(4);
    }

    void measure(String state) {
      final add = inEat('eat-add-breakfast');
      final bar = tester.getTopLeft(find.byType(GoNavigationBar)).dy;
      String where(Finder f) {
        if (f.evaluate().isEmpty) return 'not built';
        final r = tester.getRect(f);
        return '${r.top.round()}-${r.bottom.round()} ${r.top >= 0 && r.bottom <= bar ? 'visible' : 'hidden'}';
      }
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      debugPrint('GOHARD_EAT_TOP $state screen=${size.width.round()}x${size.height.round()} bar-top=${bar.round()} '
          'breakfast-heading=${where(find.descendant(of: eat, matching: find.text('Breakfast')))} add=${where(add)}');
    }

    await j.start('Eat Compact');
    await j.tapKey('nav-eat');
    await j.settle(6);
    expect(find.descendant(of: eat, matching: find.text('No food logged yet')), findsOneWidget);
    measure('empty-no-goals');
    await j.shot('ec-01-empty-no-goals');

    // No goal yet: Set daily goals is right on the summary.
    await j.openEatGoals();
    await j.type('goal-calories', '2200');
    await j.type('goal-protein', '140');
    await j.tapKey('goal-save');
    await j.waitFor(find.text('Your daily goal: 2,200 kcal · 140 g protein'), what: 'the goals on the empty day');
    expect(inEat('eat-set-goals'), findsNothing, reason: 'with goals, Edit goals is in Nutrition settings');
    await top();
    measure('empty-goals');
    await j.shot('ec-02-empty-goals');

    // One food by hand; the totals and the briefing follow.
    await j.tap(inEat('log-food'));
    await j.tapKey('food-manual');
    await j.type('food-name', 'Oatmeal with milk');
    await j.type('food-amount', '1 bowl');
    await j.type('food-calories', '350');
    await j.type('food-protein', '14');
    await j.tapKey('food-save');
    await j.waitFor(find.text('1,850 kcal left'), what: 'the calories left under the ring');
    expect(find.text('126 g left'), findsOneWidget);
    await top();
    expect(find.descendant(of: find.byKey(const Key('eat-coach')), matching: find.textContaining('You still have room for calories and protein today.', findRichText: true)), findsOneWidget,
        reason: 'the briefing, without the figures the rings show');
    measure('one-food');
    await j.shot('ec-03-one-food');

    await j.tap(inEat('eat-details'));
    await j.waitFor(find.text('Calories: 15% of goal'), what: 'the share in Nutrition details');
    await j.shot('ec-04-details');
    await j.tap(inEat('eat-nutrition-settings'));
    await j.waitFor(find.byKey(const Key('eat-customize')), what: 'Nutrition settings');
    expect(find.byKey(const Key('eat-goals')), findsOneWidget);
    await j.shot('ec-05-settings');
    Navigator.of(tester.element(find.byKey(const Key('eat-customize')))).pop();
    await j.settle(4);

    final entries = (await j.snapshot(await j.apiToken()))['foodEntries'] as List;
    expect(entries, hasLength(1), reason: 'opening details and settings logged nothing');
  });
}
