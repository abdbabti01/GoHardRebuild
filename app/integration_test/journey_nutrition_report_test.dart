import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show dayKeyOf;
import 'package:gohard_rebuild/features/coach/day_coach_screen.dart' show DayCoachScreen;
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/nutrition_history.dart' show WeeklyReportScreen;
import 'package:gohard_rebuild/features/nutrition/saved_meals_screens.dart' show MealReviewScreen;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Shared nutrition assessment on a real install (docs/EAT_COMPANION.md › Shared assessment), against a local branch API
/// whose coach provider is `scripts/coach-stub.mjs` — a STUB with a fixed rule, not a model. Not in the default run:
/// `scripts\test-android.ps1 -Only journey_nutrition_report_test -ApiBase http://10.0.2.2:PORT`.
///
/// No goals → What could I eat? says so; a protein goal set in Eat; the remaining goal said; a stub idea reviewed and left
/// (nothing logged), then logged once; the briefing says the goal is reached and offers Find something to eat; the coach
/// asks first and continuing gives options; the weekly report shows the day with its recorded goal.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no goals, goals, reached, continue, weekly report', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Report Tester');
    final today = dayKeyOf(DateTime.now());
    Future<List<Map>> todays() async => [for (final f in (await j.snapshot(await j.apiToken()))['foodEntries'] as List) if ((f as Map)['dayKey'] == today && f['isDeleted'] != true) f];
    final eatCoach = find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-coach')));
    Future<void> eatTop() async {
      await tester.drag(find.descendant(of: find.byType(EatScreen), matching: find.byType(Scrollable)).first, const Offset(0, 3000));
      await j.settle(8);
    }

    await j.tapKey('nav-eat');
    await j.waitFor(find.descendant(of: eatCoach, matching: find.textContaining('Nothing logged yet today', findRichText: true)), what: "the day's briefing");
    await j.tap(find.descendant(of: eatCoach, matching: find.byKey(const Key('eat-brief-ideas'))));
    await j.waitFor(find.byType(DayCoachScreen), what: 'What could I eat?');
    await j.waitFor(find.textContaining('You haven’t set daily targets'), what: 'no goals said, nothing invented');
    await j.shot('nr-01-no-goals');
    await j.tapKey('day-close');
    await j.settle(8);

    await eatTop();
    await j.tap(find.descendant(of: eatCoach, matching: find.byKey(const Key('eat-brief-goals'))));
    await j.type('goal-protein', '10');
    await j.tapKey('goal-save');
    await j.settle(10);
    await eatTop();

    await j.tap(find.descendant(of: eatCoach, matching: find.byKey(const Key('eat-brief-ideas'))));
    await j.waitFor(find.textContaining('10 g protein remaining'), what: 'the remaining goal said first');
    await j.shot('nr-02-remaining');
    await j.waitFor(find.byKey(const Key('day-idea-0')), what: 'idea requests (the server declares coach.ideas)', seconds: 40);
    await j.tapKey('day-idea-0'); // the stub's two ideas
    await j.waitFor(find.text('Confirm the foods below to see totals.'), what: 'an idea asking for the toast amount', seconds: 60);
    await j.tap(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-amount-')).first);
    await j.tapKey('food-save');
    await j.waitFor(find.text('Calculated from food records.'), what: 'the idea calculated', seconds: 30);
    final review = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-review-'));
    await j.tap(review.first);
    await j.waitFor(find.byType(MealReviewScreen), what: 'the review');
    await tester.pageBack();
    await j.settle(8);
    expect(await todays(), isEmpty, reason: 'leaving the review logs nothing');
    await j.tap(review.first);
    await j.tapKey('meal-log');
    await j.waitUntil(() async => (await todays()).length == 2, what: 'logged once, as one meal');
    await j.settle(8);
    await j.tapKey('day-close');
    await j.settle(8);

    await eatTop();
    await j.waitFor(find.descendant(of: eatCoach, matching: find.textContaining('reached your protein target based on what you logged', findRichText: true)), what: 'the reached briefing');
    expect(find.descendant(of: eatCoach, matching: find.text('Find something to eat')), findsOneWidget);
    expect(find.byKey(const Key('eat-goal-protein-status')), findsOneWidget);
    await j.shot('nr-03-reached');
    await j.tap(find.descendant(of: eatCoach, matching: find.byKey(const Key('eat-brief-ideas'))));
    await j.waitFor(find.textContaining('If you’re still hungry'), what: 'told before any food');
    await j.tap(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-act-proceed-')).last);
    await j.waitFor(find.textContaining('A few ways to go'), what: 'continuing gives options');
    await j.shot('nr-04-continue');
    await j.tapKey('day-close');
    await j.settle(8);

    await j.tapKey('eat-history');
    await j.tapKey('trends-weekly-report');
    await j.waitFor(find.byType(WeeklyReportScreen), what: 'the weekly report');
    await j.waitFor(find.byKey(const Key('wr-goal-history')), what: 'goal history said');
    await j.shot('nr-05-weekly-report');
    debugPrint('GOHARD_NR goal history: ${(tester.widget<Text>(find.byKey(const Key('wr-goal-history')))).data}');

    expect((await j.api.delete<void>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer ${await j.apiToken()}'}))).statusCode, 204);
    debugPrint('GOHARD_NR done; disposable account deleted');
  });
}
