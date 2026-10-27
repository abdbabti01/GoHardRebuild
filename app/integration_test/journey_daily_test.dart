import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Help with today and food on a real install (docs/COACH.md › Help with today), against a local branch API that
/// captures mail and whose coach provider is `scripts/coach-stub.mjs` — a STUB with a fixed rule, not a model, so this
/// proves the app and API path, never live AI. Not in the default run:
/// `scripts\test-android.ps1 -Only journey_daily_test -ApiBase http://10.0.2.2:PORT`.
///
/// One process: the briefing and the goal question answer with no AI; Edit goals opens Eat's own goal sheet; a saved
/// meal is made; a typed request names it, a typed "smaller" changes the portion; Review then back logs nothing; Review
/// then Log meal logs it once at the suggested amounts (checked on the account); a typed request the provider fails keeps
/// the question with Retry while the built-in requests still answer. The disposable account is deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('help with today and food', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Daily Tester');
    Finder prefixed(String p) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith(p));
    Future<Map<String, dynamic>> account() async => j.snapshot(await j.apiToken());
    Future<void> ask(String words) async {
      await j.type('day-input', words);
      await j.tapKey('day-send');
      await j.waitFor(find.byKey(const Key('day-sending')), what: 'the request in flight', seconds: 3).catchError((_) {});
      await j.waitUntil(() async => find.byKey(const Key('day-sending')).evaluate().isEmpty, what: 'the answer');
      await j.settle(4);
    }

    // Today: the guide opens the conversation; opening it asks nothing.
    await j.tapKey('coach-avatar-launcher');
    await j.waitFor(find.byKey(const Key('day-context')), what: 'help with today');
    await j.shot('dc-01-open');
    await j.tapKey('day-chip-today');
    await j.waitFor(find.textContaining('No training plan is active.'), what: 'the briefing');
    await j.shot('dc-02-briefing');

    // No goal: said so, and Edit goals opens Eat's own goal sheet.
    await j.tapKey('day-chip-goal');
    await j.waitFor(find.textContaining("You haven't set a daily protein goal."), what: 'no goal');
    await j.tap(prefixed('day-act-goals-').last);
    await j.waitFor(find.byKey(const Key('goal-protein')), what: "Eat's goal sheet");
    await j.type('goal-protein', '120');
    await j.tapKey('goal-save');
    await j.settle(6);

    // A saved meal, made in the library from bundled common foods.
    await j.tap(find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-saved-meals'))));
    await j.tapKey('meals-new');
    await j.type('meal-name', 'Breakfast bowl');
    for (final (query, name) in [('egg', 'Eggs'), ('oatmeal', 'Oats')]) {
      await j.tapKey('meal-add-food');
      await j.type('food-search', query);
      await j.tap(find.descendant(of: find.byType(ListView), matching: find.text(name)));
      await j.waitFor(find.byKey(const Key('food-save')), what: 'the amount form');
      await j.tapKey('food-save');
      await j.waitFor(find.byKey(const Key('meal-save')), what: 'back in the editor');
    }
    await j.tapKey('meal-save');
    await j.waitFor(find.text('Breakfast bowl'), what: 'the saved meal');
    await j.waitUntil(() async => ((await account())['savedMeals'] as List).length == 1, what: 'the meal on the account');
    await tester.pageBack();
    await j.settle(4);

    // Back to Today's guide: typed words (read by the stub), then a typed follow-up.
    await j.tapKey('nav-today');
    await j.tapKey('coach-avatar-launcher');
    await j.waitFor(find.byKey(const Key('day-input')), what: 'the request field');
    await ask('Help me reach my protein goal with my breakfast bowl');
    await j.waitFor(prefixed('day-review-'), what: 'a portion card');
    await j.shot('dc-03-typed');
    await ask('Make that smaller');
    await j.waitFor(find.textContaining('0.75× the saved amounts'), what: 'the smaller portion');
    await j.shot('dc-04-smaller');

    // Review then back: nothing logged.
    await j.tap(prefixed('day-review-').last);
    await j.waitFor(find.byKey(const Key('meal-log')), what: 'the review');
    await j.shot('dc-05-review');
    await tester.pageBack();
    await j.settle(6);
    expect((await account())['foodEntries'] as List, isEmpty, reason: 'leaving the review logs nothing');

    // Review then Log meal: one meal, at 0.75× of each saved amount.
    await j.tap(prefixed('day-review-').last);
    await j.tapKey('meal-log');
    await j.waitUntil(() async => ((await account())['foodEntries'] as List).length == 2, what: 'the meal on the account');
    final saved = ((await account())['savedMeals'] as List).single as Map;
    final logged = [for (final f in (await account())['foodEntries'] as List) f as Map];
    final parts = [for (final c in saved['body']['components'] as List) c as Map];
    for (final c in parts) {
      final e = logged.firstWhere((f) => f['source']['item']['sourceId'] == c['item']['sourceId']);
      expect((e['source']['quantity'] as num).toDouble(), closeTo((c['quantity'] as num).toDouble() * 0.75, 1e-9));
    }
    expect((saved['revision'], (parts.first['quantity'] as num) > 0), (1, true), reason: 'the saved meal itself is unchanged');
    await j.shot('dc-06-logged');

    // The provider fails: the question stays with Retry; built-in requests still answer from the records.
    await ask('please fail now');
    await j.waitFor(find.byKey(const Key('day-problem')), what: 'an honest failure');
    expect(find.byKey(const Key('day-retry')), findsOneWidget);
    await j.shot('dc-07-unavailable');
    await j.tapKey('day-chip-recorded');
    await j.waitFor(find.textContaining('Foods in the journal: 2'), what: 'the recorded facts, with no AI');
    await j.shot('dc-08-fallback');
    expect(((await account())['foodEntries'] as List).length, 2, reason: 'nothing logged twice');

    final token = await j.apiToken();
    expect((await j.api.delete<void>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer $token'}))).statusCode, 204);
    debugPrint('GOHARD_DC done; disposable account deleted');
  });
}
