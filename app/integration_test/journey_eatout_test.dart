import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Eating out on a real install (docs/EATING_OUT.md), against a local branch API that captures mail and whose coach
/// provider is the STUB scripts/coach-stub.mjs (a fixed reply, not a model: this proves the app and API path, not live
/// AI). Not in the default run:
/// `scripts\test-android.ps1 -Only journey_eatout_test -ApiBase http://10.0.2.2:PORT`.
///
/// Subway is chosen; a request is sent and its interpreted targets shown; a suggestion keeps the kept item and is
/// compared with the order; the order is reviewed and logged once; another is saved as a meal and reopened; then,
/// genuinely offline (GOHARD_NET), asking fails honestly while the menu, building and logging work, and the offline order
/// reaches the account once. The account's snapshot is checked and the disposable account deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('eating out', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Eatout Tester');
    final entry = find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-eating-out')));
    // One sign-in for the whole run: polling must not hit the auth rate limit.
    String? token;
    Future<Map<String, dynamic>> account() async => j.snapshot(token ??= await j.apiToken());
    Future<void> addFromMenu(String id) async {
      await j.tapKey('eatout-add');
      await j.tapKey('eatout-menu-add-$id');
      Navigator.of(tester.element(find.byKey(const Key('eatout-menu-filter')))).pop();
      await j.settle(8);
    }

    await j.tapKey('nav-eat');
    await j.tap(entry);
    await j.waitFor(find.byKey(const Key('eatout-chain-subway-ca')), what: 'the chains');
    await j.shot('eo-01-chains');
    await j.tapKey('eatout-chain-subway-ca');
    await j.waitFor(find.byKey(const Key('eatout-ask')), what: 'Subway');

    // Asked in words (stub provider): the interpreted targets are shown and editable.
    await j.type('eatout-ask', "McDonald's isn't here, so Subway for lunch, around 600 calories, more protein, keep the potato rings");
    await j.tapKey('eatout-send');
    await j.waitFor(find.byKey(const Key('eatout-chip-max')), what: 'the interpreted targets');
    await j.shot('eo-02-interpreted');
    await j.waitFor(find.byKey(const Key('eatout-suggestion-0')), what: 'a suggestion');
    expect(find.descendant(of: find.byKey(const Key('eatout-suggestion-0')), matching: find.text('1 × Potato Rings')), findsOneWidget);
    await j.shot('eo-03-suggestion');

    // Use it, then compare: the suggestions now show the difference from the order.
    await j.tapKey('eatout-use-0');
    await j.waitFor(find.byKey(const Key('eatout-totals')), what: 'the order');
    await j.shot('eo-04-order');
    await j.tapKey('eatout-tab-choose');
    await j.waitFor(find.byKey(const Key('eatout-compare-0')), what: 'the comparison');
    await j.shot('eo-05-compare');
    expect((await account())['foodEntries'] as List, isEmpty, reason: 'asking, choosing and comparing log nothing');

    // Review and log once.
    await j.tapKey('eatout-tab-order');
    await j.tapKey('eatout-review');
    await j.waitFor(find.byKey(const Key('meal-log')), what: 'the review');
    await j.shot('eo-06-review');
    await j.tapKey('meal-log');
    await j.waitFor(find.byKey(const Key('nav-eat')), what: 'back on Eat');
    await j.waitUntil(() async => ((await account())['foodEntries'] as List).length == 2, what: 'the order on the account');
    await j.shot('eo-07-eat-after-log');

    // Another order saved as a meal, then reopened from the library.
    await j.tap(entry);
    await j.tapKey('eatout-tab-order');
    await addFromMenu('subway-ca:rotisserie-chicken-6in');
    await j.tapKey('eatout-save-meal');
    await j.waitFor(find.byKey(const Key('meal-save')), what: 'the saved-meal editor');
    await j.tapKey('meal-save');
    await j.settle(8);
    await tester.pageBack();
    await j.settle(8);
    await j.tap(find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-saved-meals'))));
    await j.waitFor(find.text('Subway order'), what: 'the saved order in the library');
    await j.shot('eo-08-saved-meal');
    await j.tapText('Subway order');
    await j.waitFor(find.text('Rotisserie-Style Chicken · 6-inch'), what: 'the reopened order');
    await tester.pageBack();
    await j.settle(4);
    await tester.pageBack();
    await j.settle(4);
    expect(((await account())['foodEntries'] as List).length, 2, reason: 'saving a meal logs nothing');

    // Offline: asking says what is true; the menu, the order and logging work and reach the account once.
    // ignore: avoid_print
    print('GOHARD_NET:off');
    await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');
    await j.tap(entry);
    await j.tapKey('eatout-tab-order');
    await addFromMenu('subway-ca:turkey-breast-6in');
    await j.type('eatout-ask', 'more protein please');
    await j.tapKey('eatout-send');
    await j.waitFor(find.byKey(const Key('eatout-problem')), what: 'the honest failure', seconds: 40);
    await j.shot('eo-09-offline');
    await j.tapKey('eatout-review');
    await j.tapKey('meal-log');
    await j.waitFor(find.byKey(const Key('nav-eat')), what: 'back on Eat, offline');
    // ignore: avoid_print
    print('GOHARD_NET:on');
    await j.waitUntil(() async => await j.apiReachable(), what: 'the connection back');
    await j.waitUntil(() async => ((await account())['foodEntries'] as List).length == 4, what: 'the offline order (the saved chicken still in the draft + turkey) on the account', seconds: 180);

    final s = await account();
    final food = [for (final f in s['foodEntries'] as List) f as Map];
    expect(food.map((f) => f['source']['item']['source']), everyElement('restaurant'));
    expect(food.map((f) => f['source']['item']['restaurant']['catalogVersion']).toSet().length, 1);
    expect((s['savedMeals'] as List).length, 1);
    await j.shot('eo-10-synced');

    expect((await j.api.delete<void>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer ${token ?? await j.apiToken()}'}))).statusCode, 204);
    debugPrint('GOHARD_EO done; disposable account deleted');
  });
}
