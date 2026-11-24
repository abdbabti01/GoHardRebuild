import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart' show EatScreen;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Search and Describe your meal on a device (docs/FOOD_DATA.md › Search relevance, Describe your meal), one process, a new
/// account against the local branch API whose coach provider is `scripts/coach-stub.mjs` — a STUB with a fixed rule, not
/// a model: this proves the app and API path (one request, local questions, review, one log, one charge), never how a
/// live model reads words. Food search runs against whatever USDA source the API is given. Not in the default run.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chicken breast search; a described meal: raw or cooked, which chicken, review, logged once, charged once', (tester) async {
    final j = Journey(tester, binding);
    final eat = find.byType(EatScreen);
    Finder prefixed(String p) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith(p));

    await j.start('Describe Meal');
    await j.tapKey('nav-eat');
    await j.settle(6);
    await j.tap(find.descendant(of: eat, matching: find.byKey(const Key('log-food'))));

    // Search: the everyday raw and cooked breasts, from the phone.
    await j.type('food-search', 'chicken breast');
    await j.waitFor(find.byKey(const Key('common-chicken-breast-raw')), what: 'the raw breast from the bundled foods');
    expect(find.byKey(const Key('common-chicken-breast')), findsOneWidget);
    await j.shot('dm-01-search-chicken-breast');
    await j.type('food-search', 'chiken brest');
    await j.waitFor(find.text('Showing results for “chicken breast”.'), what: 'the corrected search');
    await j.shot('dm-02-search-misspelt');
    await j.tapKey('food-search-clear');

    // Describe your meal: one sentence, one request.
    final token = await j.apiToken();
    Future<int> used() async => ((await j.api.get<Map>('/entitlement', options: Options(headers: {'authorization': 'Bearer $token'}))).data!['allowance'] as Map)['used'] as int;
    final before = await used();
    await j.tapKey('food-describe');
    await j.waitFor(find.byKey(const Key('day-intro')), what: 'the coach, ready for a sentence');
    expect(find.textContaining('Uses 1 AI request'), findsOneWidget);
    await j.shot('dm-03-describe-open');
    await j.type('day-input', 'I ate 120 g of chicken and 100 g of potatoes');
    await j.tapKey('day-send');
    await j.waitFor(find.text('chicken · 120 g: weighed raw or cooked?'), what: 'the raw-or-cooked question', seconds: 40);
    await j.shot('dm-04-questions');
    await j.tap(prefixed('day-meal-raw-').first);
    await j.waitFor(find.text('Which chicken?'), what: 'which chicken');
    await j.tap(find.textContaining('Chicken breast (Raw'));
    await j.tap(prefixed('day-meal-cooked-').first);
    await j.waitFor(find.text('Ready to review. Nothing is logged until you tap Log meal.'), what: 'a complete meal');
    await j.shot('dm-05-ready');

    await j.tap(prefixed('day-meal-review-').first);
    await j.waitFor(find.text('Log meal'), what: 'the meal review');
    await j.shot('dm-06-review');
    await j.tapKey('meal-log');
    await j.waitFor(find.descendant(of: eat, matching: find.text('Chicken breast')), what: 'the meal in Eat', seconds: 30);
    await j.shot('dm-07-logged');

    // The account holds both foods once; reading the sentence was charged once, logging nothing.
    await j.waitUntil(() async => ((await j.snapshot(token))['foodEntries'] as List).length == 2, what: 'two entries on the account');
    final names = [for (final e in (await j.snapshot(token))['foodEntries'] as List) (e as Map)['name']];
    expect(names, unorderedEquals(['Chicken breast', 'Potato']));
    final after = await used();
    expect(after - before, 1, reason: 'one charged request for the sentence; questions, review and logging free');
    debugPrint('GOHARD_DESCRIBE allowance used before=$before after=$after entries=$names');
  });
}
