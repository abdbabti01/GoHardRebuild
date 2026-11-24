import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Help me set my targets on a real install (docs/NUTRITION_TARGETS.md): Eat › Edit goals › Help me set my targets,
/// the reference man (34 y, 170 cm, 199 lb typed for this estimate only, mostly seated, Lose weight), an edited
/// calorie target, Use these targets; then what the account holds: the two goals, the water goal as it was, and no
/// weigh-in. Not in the default run: `scripts\test-android.ps1 -Only journey_targets_test -ApiBase http://10.0.2.2:PORT`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('help me set my targets', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Targets');
    String field(String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

    // Goals set by hand first, so there is a water goal (when water is shown) to keep.
    await j.tapKey('nav-eat');
    await j.openEatGoals();
    await j.type('goal-calories', '1800');
    await j.type('goal-protein', '90');
    final water = find.byKey(const Key('goal-water')).evaluate().isNotEmpty;
    if (water) await j.type('goal-water', '2000');
    await j.tapKey('goal-save');
    await j.settle(8);
    final token = await j.apiToken();
    late Map<String, dynamic> account;
    await j.waitUntil(() async => ((account = await j.snapshot(token))['profile'] as Map)['calorieGoal'] == 1800, what: 'the hand-set goals to reach the account');
    final waterBefore = (account['profile'] as Map)['waterGoalMl'];
    debugPrint('GOHARD_TGT water shown=$water before=$waterBefore');

    await j.openEatGoals();
    await j.tapKey('goals-help');
    await j.tapKey('tgt-goal-lose');
    await j.tapKey('tgt-continue');
    await j.type('tgt-age', '34');
    await j.type('tgt-height-cm', '170');
    await j.tapKey('tgt-weight-unit-lb');
    await j.type('tgt-weight', '199');
    await j.tapKey('tgt-sex-male');
    await j.tapKey('tgt-activity-inactive');
    await j.shot('tgt-01-activity');
    await j.tapKey('tgt-continue');
    await j.waitFor(find.byKey(const Key('tgt-math')), what: 'the result');
    expect((field('tgt-calories'), field('tgt-protein')), ('2260', '145'));
    expect(tester.widget<Text>(find.byKey(const Key('tgt-maintenance'))).data, '2,760 kcal');
    expect(find.text('Your starting targets').hitTestable(), findsOneWidget, reason: 'the title is in view at the top');
    await j.shot('tgt-02-result');

    await j.type('tgt-calories', '2200');
    expect(tester.widget<Text>(find.byKey(const Key('tgt-calories-status'))).data, startsWith('Your edited target · suggested 2,260 kcal'));
    await j.tapKey('tgt-details');
    await j.shot('tgt-03-edited-details');
    await j.tapKey('tgt-use');
    await j.settle(8);

    await j.waitUntil(() async => ((account = await j.snapshot(token))['profile'] as Map)['calorieGoal'] == 2200, what: 'the new goals to reach the account');
    final profile = account['profile'] as Map;
    expect((profile['calorieGoal'], profile['proteinGoal'], profile['waterGoalMl']), (2200, 145, waterBefore), reason: 'calories and protein only');
    expect((account['bodyMetrics'] as List).where((m) => (m as Map)['isDeleted'] != true), isEmpty, reason: 'a weight typed for the estimate is not a weigh-in');
    await j.shot('tgt-04-eat-after');
  });
}
