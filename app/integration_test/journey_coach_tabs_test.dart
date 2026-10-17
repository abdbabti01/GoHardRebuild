import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/log_food_screen.dart';
import 'package:gohard_rebuild/features/plans/builder/plan_builder_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Evidence run for the coach on Train and Eat, the meal groups and the display choices on the account
/// (docs/COACH.md › Train and Eat, docs/FOOD_DATA.md › What is shown). Not part of the default run. A new account on
/// the local API.
///
/// First a recording (GOHARD_REC markers, the host runs `adb screenrecord`): the coach peeking in on Train without a
/// plan, a section change (new words, no replay), Create my plan opening the builder, then Eat's coach and a meal's
/// "+ Add food". Then still captures: Train's sections, Eat empty and with food, water shown, and Pink Dark. The display
/// choices are checked on the account itself, read as a second phone would.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coach on Train and Eat, meal groups, display choices on the account', (tester) async {
    final j = Journey(tester, binding);
    const surface = MethodChannel('plugins.flutter.io/integration_test');
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    Future<void> rec(String name, Future<void> Function() body) async {
      debugPrint('GOHARD_REC:start:$name');
      await watch(1500);
      await body();
      await watch(2500);
      debugPrint('GOHARD_REC:stop');
      await watch(1000);
    }

    // After the recording the surface stays an image (the binding converts it only once per run).
    Future<void> shot(String name) => j.shot(name);

    Finder inCoach(String coach, Finder f) => find.descendant(of: find.byKey(Key(coach)), matching: f);

    await j.start('Tara Quinn');
    await surface.invokeMethod<void>('revertFlutterImage'); // the live surface, for screenrecord

    await rec('coach-train-eat', () async {
      await j.tapKey('nav-train');
      await j.tapKey('train-plan');
      await j.waitFor(find.byKey(const Key('train-coach')), what: 'the coach on Train');
      await watch(4500); // the peek, the nod, the words; then a moment at rest
      expect(inCoach('train-coach', find.byKey(const Key('create-plan'))), findsOneWidget, reason: 'the action is in the bubble');
      expect(find.byKey(const Key('coach-ask-launcher')), findsNothing, reason: 'no second, small launcher');
      await j.tapKey('train-workouts');
      await watch(2500);
      await j.tapKey('train-progress');
      await watch(2500);
      await j.tapKey('train-plan');
      await watch(1500);
      await j.tapKey('create-plan');
      await j.waitFor(find.byKey(const Key('plan-path-direct')), what: 'the builder\'s first page');
      await watch(2000);
      await tester.pageBack();
      await watch(1500);
      await j.tapKey('nav-eat');
      await j.waitFor(find.byKey(const Key('eat-coach')), what: 'the coach on Eat');
      await watch(4500);
      await j.tapKey('eat-add-lunch');
      await j.waitFor(find.byType(LogFoodScreen), what: 'Log food');
      expect(tester.widget<LogFoodScreen>(find.byType(LogFoodScreen)).meal, 'Lunch', reason: 'the meal of the footer');
      await watch(1500);
      await j.tapKey('food-back');
      await watch(2000);
    });

    // Captures on the same account.
    await surface.invokeMethod<void>('convertFlutterSurfaceToImage');
    await j.tapKey('nav-train');
    await j.tapKey('train-plan');
    await watch(800);
    await shot('coach-tabs-01-train-no-plan');
    await j.tapKey('train-workouts');
    await watch(800);
    await shot('coach-tabs-02-train-workouts');
    await j.tapKey('train-progress');
    await watch(800);
    await shot('coach-tabs-03-train-progress');
    await j.tapKey('nav-eat');
    await watch(800);
    await shot('coach-tabs-04-eat-empty');

    // A food logged under Lunch from its footer: the group then has its heading, the food and the small action.
    await j.tapKey('eat-add-lunch');
    await j.type('food-search', 'eggs');
    await j.tapKey('common-eggs');
    await j.tapKey('food-save');
    await j.waitFor(find.byKey(const Key('eat-add-lunch')), what: 'back on Eat');
    await watch(800);
    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -520));
    await watch(800);
    await shot('coach-tabs-05-eat-meals');
    // Back to the top of Eat's own list (dragging a row of it), where the coach is.
    await tester.drag(find.byKey(const Key('eat-add-lunch')), const Offset(0, 1500));
    await watch(800);
    expect(find.byKey(const Key('eat-coach')), findsOneWidget);

    // Water on, carbs off: shown at once here, and kept on the account (read as another phone would).
    await j.tapKey('eat-customize');
    await j.waitFor(find.byKey(const Key('track-water')));
    await j.tapKey('track-water');
    await j.tapKey('track-carbs');
    await watch(600);
    Navigator.of(tester.element(find.byKey(const Key('track-water')))).pop();
    await watch(3000);
    expect(find.byKey(const Key('eat-water')), findsOneWidget);
    await tester.drag(find.byKey(const Key('eat-water')), const Offset(0, 1500)); // tapping Customize scrolled it to the top
    await watch(800);
    for (final e in inCoach('eat-coach', find.byType(RichText)).evaluate()) {
      debugPrint('GOHARD_EAT_COACH: ${(e.widget as RichText).text.toPlainText()}');
    }
    await j.waitFor(inCoach('eat-coach', find.textContaining('water', findRichText: true)), what: 'the coach mentioning water');
    await shot('coach-tabs-06-eat-water');
    final profile = (await j.snapshot(await j.apiToken()))['profile'] as Map;
    debugPrint('GOHARD_PROFILE_DISPLAY: showWater=${profile['showWater']} showCarbs=${profile['showCarbs']} showFat=${profile['showFat']}');
    expect((profile['showWater'], profile['showCarbs'], profile['showFat']), (true, false, true), reason: 'the choice is on the account');

    // Goals are set in Eat: the suggested starting water goal, accepted, then saved by the person.
    await j.tapKey('eat-goals');
    await j.waitFor(find.byKey(const Key('water-suggestion')), what: 'the suggested starting goal');
    await shot('coach-tabs-09-goals-suggestion');
    await j.tapKey('water-suggestion-use');
    await j.tapKey('goal-save');
    await j.waitFor(find.byKey(const Key('water-goal-bar')), what: 'the water goal bar');
    await j.tapKey('water-quick-add');
    await j.tapKey('water-add-500');
    await j.settle(4);
    Navigator.of(tester.element(find.byKey(const Key('water-add-500')))).pop();
    await watch(1500);
    await tester.drag(find.byKey(const Key('eat-water')), const Offset(0, -260));
    await watch(800);
    await shot('coach-tabs-10-eat-water-bar');
    await j.tapKey('nav-today');
    await watch(1500);
    expect(find.byKey(const Key('today-goals')), findsNothing, reason: 'Today shows progress, not goal editing');
    await tester.drag(find.byKey(const Key('today-module-nutrition')), const Offset(0, -380));
    await watch(1000);
    await shot('coach-tabs-11-today-water-bar');

    // Pink Dark.
    await j.tapKey('nav-me');
    await tester.scrollUntilVisible(find.byKey(const Key('me-appearance')), 300, scrollable: find.byType(Scrollable).hitTestable().first);
    await j.tapKey('me-appearance');
    await j.tapKey('accent-pink');
    await j.tapKey('appearance-dark');
    await tester.pageBack();
    await j.settle(3);
    await j.tapKey('nav-train');
    await j.tapKey('train-plan');
    await watch(800);
    await shot('coach-tabs-07-train-pink-dark');
    await j.tapKey('nav-eat');
    await watch(800);
    await shot('coach-tabs-08-eat-pink-dark');
    expect(find.byType(PlanBuilder), findsNothing);
  });
}
