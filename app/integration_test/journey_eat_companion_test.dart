import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show dayKeyOf;
import 'package:gohard_rebuild/features/coach/day_coach_screen.dart' show DayCoachScreen;
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/saved_meals_screens.dart' show MealReviewScreen;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Eat companion on a real install (docs/EAT_COMPANION.md), against a local branch API whose coach provider is
/// `scripts/coach-stub.mjs` — a STUB with a fixed rule, not a model. Not in the default run:
/// `scripts\test-android.ps1 -Only journey_eat_companion_test -ApiBase http://10.0.2.2:PORT`.
///
/// Eat's briefing for an empty day; What could I eat? (built in, no AI); a ready idea request answered by the stub with
/// two ideas, one matched to bundled foods and one that is not; the matched one reviewed with an amount changed and left
/// (nothing on the account), then logged once (two entries); the briefing then speaks of the logged meal.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('briefing, ideas, review, log once', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Companion Tester');
    final today = dayKeyOf(DateTime.now());
    Future<List<Map>> todays() async => [for (final f in (await j.snapshot(await j.apiToken()))['foodEntries'] as List) if ((f as Map)['dayKey'] == today && f['isDeleted'] != true) f];
    final eatCoach = find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-coach')));

    await j.tapKey('nav-eat');
    await j.waitFor(find.descendant(of: eatCoach, matching: find.textContaining('Nothing logged yet today', findRichText: true)), what: "the day's briefing");
    await j.shot('ec-01-briefing-empty');

    await j.tap(find.descendant(of: eatCoach, matching: find.byKey(const Key('eat-brief-ideas'))));
    await j.waitFor(find.byType(DayCoachScreen), what: 'What could I eat?');
    await j.waitFor(find.byKey(const Key('day-idea-0')), what: 'idea requests (the server declares coach.ideas)', seconds: 40);
    await j.shot('ec-02-what-could-i-eat');
    await j.tapKey('day-idea-0'); // Something quick with more protein → the stub's two ideas
    await j.waitFor(find.text('Confirm the foods below to see totals.'), what: 'a matched idea asking for the toast amount', seconds: 60);
    expect(find.textContaining('Needs a food match'), findsOneWidget);
    // Several slice sizes: the person chooses the amount in the usual form (its starting amount, confirmed).
    await j.tap(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-amount-')).first);
    await j.tapKey('food-save');
    await j.waitFor(find.text('Calculated from food records.'), what: 'the idea calculated', seconds: 30);
    await j.shot('ec-03-ideas');

    final review = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('day-review-'));
    await j.tap(review.first);
    await j.waitFor(find.byType(MealReviewScreen), what: 'the review');
    await j.tapKey('meal-part-0');
    await j.type('food-quantity', '3');
    await j.tapKey('food-save'); // this time only
    await j.waitFor(find.byKey(const Key('meal-log')), what: 'back in the review');
    await j.shot('ec-04-review-changed');
    await tester.pageBack();
    await j.settle(8);
    expect(await todays(), isEmpty, reason: 'leaving the review logs nothing');

    await j.tap(review.first);
    await j.tapKey('meal-log');
    await j.waitUntil(() async => (await todays()).length == 2, what: 'the idea logged once, as one meal');
    await j.settle(8);
    await j.tapKey('day-close'); // the conversation closes with its own button
    await j.settle(8);
    // Eat's coach is in the header of a lazy list that earlier taps scrolled: back to the top before looking at it.
    await tester.drag(find.descendant(of: find.byType(EatScreen), matching: find.byType(Scrollable)).first, const Offset(0, 3000));
    await j.settle(8);
    await j.waitFor(find.descendant(of: eatCoach, matching: find.textContaining('is logged', findRichText: true)), what: 'the briefing after logging');
    await j.shot('ec-05-briefing-logged');

    expect((await j.api.delete<void>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer ${await j.apiToken()}'}))).statusCode, 204);
    debugPrint('GOHARD_EC done; disposable account deleted');
  });
}
