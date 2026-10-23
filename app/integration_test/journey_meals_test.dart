import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Saved meals & recipes on a real install (docs/FOOD_DATA.md › Saved meals and recipes), against a local branch API
/// that captures mail. Not in the default run:
/// `scripts\test-android.ps1 -Only journey_meals_test -ApiBase http://10.0.2.2:PORT`.
///
/// One process (the Pixel_7 emulator has no room for a phase-2 reinstall): a restart with work waiting is covered by
/// test/saved_meals_test.dart on the real database, and on an iPhone by the checklist. Foods are picked from the
/// bundled common foods, so no provider is asked.
///
/// A meal is made (2 foods), reviewed at 1½× and logged once; Update saved meal makes it 2×, Save as new keeps a
/// variation; a 4-serving recipe is made and 1½ servings of it logged; then, genuinely offline (GOHARD_NET), the meal is
/// logged again and reaches the account once the connection is back. The account's own snapshot is checked, and the
/// disposable account deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved meals and recipes', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Meals Tester');
    final eat = find.descendant(of: find.byType(EatScreen), matching: find.byKey(const Key('eat-saved-meals')));

    // By its name: once logged, a common food is listed under Your foods rather than as the catalog row.
    Future<void> pick(String query, String name) async {
      await j.tapKey('meal-add-food');
      await j.type('food-search', query);
      await j.tap(find.descendant(of: find.byType(ListView), matching: find.text(name)));
      await j.waitFor(find.byKey(const Key('food-save')), what: 'the amount form');
      await j.tapKey('food-save'); // "Use this amount": adds it, logs nothing
      await j.waitFor(find.byKey(const Key('meal-save')), what: 'back in the editor');
    }

    Future<Map<String, dynamic>> account() async => j.snapshot(await j.apiToken());

    // A new meal from scratch.
    await j.tapKey('nav-eat');
    await j.tap(eat);
    await j.waitFor(find.byKey(const Key('meals-empty')), what: 'the empty library');
    await j.shot('sm-01-library-empty');
    await j.tapKey('meals-new');
    await j.type('meal-name', 'Breakfast bowl');
    await pick('egg', 'Eggs');
    await pick('oatmeal', 'Oats');
    await j.shot('sm-02-meal-editor');
    await j.tapKey('meal-save');
    await j.waitFor(find.text('Breakfast bowl'), what: 'the saved meal in the library');
    expect((await account())['foodEntries'] as List, isEmpty, reason: 'saving a meal logs nothing');

    // Reviewed at 1½× and logged once.
    await j.tapText('Breakfast bowl');
    await j.tapKey('meal-factor-1.5');
    await j.shot('sm-03-review-1-5x');
    await j.tapKey('meal-log');
    await j.waitFor(find.byKey(const Key('nav-eat')), what: 'back on Eat');
    await j.waitUntil(() async => ((await account())['foodEntries'] as List).length == 2, what: 'the meal on the account');
    await j.shot('sm-04-eat-after-log');

    // Update saved meal (2×) and a variation saved as new.
    await j.tap(eat);
    await j.tapText('Breakfast bowl');
    await j.tapKey('meal-factor-2.0');
    await j.tapKey('meal-update-saved');
    await j.confirmWith('Update saved meal');
    await j.tapKey('meal-review-save-new');
    await j.type('meal-new-name', 'Small bowl');
    await j.tapKey('meal-new-save');
    await j.settle(8);
    await tester.pageBack(); // leaving the review logs nothing
    await j.waitFor(find.text('Small bowl'), what: 'the variation in the library');

    // A recipe: the batch makes 4 servings; 1½ of them are logged.
    await j.tapKey('meals-tab-recipe');
    await j.tapKey('meals-new');
    await j.type('meal-name', 'Overnight oats');
    await j.type('recipe-servings', '4');
    await pick('oatmeal', 'Oats');
    await pick('egg', 'Eggs');
    await j.shot('sm-05-recipe-editor');
    await j.tapKey('meal-save');
    await j.tapText('Overnight oats');
    await j.type('recipe-amount', '1.5');
    await j.shot('sm-06-recipe-review');
    await j.tapKey('meal-log');
    await j.waitFor(find.byKey(const Key('nav-eat')), what: 'back on Eat');

    // Offline: the meal is logged on the phone, then reaches the account once.
    // ignore: avoid_print
    print('GOHARD_NET:off');
    await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');
    await j.tap(eat);
    await j.tapKey('meals-tab-meal');
    await j.tapText('Small bowl');
    await j.tapKey('meal-log');
    await j.waitFor(find.byKey(const Key('nav-eat')), what: 'back on Eat, offline');
    await j.shot('sm-07-eat-offline');
    // ignore: avoid_print
    print('GOHARD_NET:on');
    await j.waitUntil(() async => await j.apiReachable(), what: 'the connection back');
    await j.waitUntil(() async => ((await account())['foodEntries'] as List).length == 5, what: 'the offline meal on the account', seconds: 180);

    final s = await account();
    final meals = [for (final m in s['savedMeals'] as List) m as Map];
    expect(meals.length, 3);
    final bowl = meals.firstWhere((m) => m['body']['name'] == 'Breakfast bowl');
    expect(bowl['revision'], 2, reason: 'updated once, by the explicit action');
    final food = [for (final f in s['foodEntries'] as List) f as Map];
    expect(food.length, 5, reason: '2 + recipe portion + 2 offline, nothing twice');
    expect(food.where((f) => f['source']?['recipe'] != null).single['amountDescription'], '1.5 servings');
    await j.shot('sm-08-synced');

    final token = await j.apiToken();
    expect((await j.api.delete<void>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer $token'}))).statusCode, 204);
    debugPrint('GOHARD_SM done; disposable account deleted');
  });
}
