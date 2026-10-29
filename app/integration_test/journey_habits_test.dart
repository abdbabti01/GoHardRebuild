import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/clock.dart' show addDays, dayKeyOf;
import 'package:gohard_rebuild/core/widgets.dart' show GroupRow;
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Meal habits and reminders on a real install (docs/MEAL_HABITS_REMINDERS.md), against a local branch API that
/// captures mail. Not in the default run: `scripts\test-android.ps1 -Only journey_habits_test -ApiBase http://10.0.2.2:PORT`.
///
/// Three earlier days with the same breakfast, lunch, dinner and snack are logged through the API (as another phone
/// would). Meal suggestions are turned on; Eat offers the usual meal for the time of day; its review has one amount
/// changed and is left without logging (the account holds nothing for today); then it is logged once. A supplement
/// reminder is made, renamed, paused and turned on again, and today's occurrence confirmed as Taken. The notification
/// itself is not awaited (simulated delivery proves nothing about a phone); the disposable account is deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('usual meal, amounts, reminders', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Habits Tester');
    final token = await j.apiToken();
    final auth = Options(headers: {'Authorization': 'Bearer $token'});
    final today = dayKeyOf(DateTime.now());
    Future<List<Map>> todays() async => [for (final f in (await j.snapshot(await j.apiToken()))['foodEntries'] as List) if ((f as Map)['dayKey'] == today && f['isDeleted'] != true) f];

    // Three earlier days, the same egg at every meal (so whatever the time of day, that meal has a habit).
    const egg = {'source': 'usda', 'sourceId': 'journey-egg', 'name': 'Egg', 'basis': '100g',
        'nutrients': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5}, 'servings': [{'label': '1 egg', 'grams': 50, 'milliliters': null}]};
    var n = 0;
    for (final d in [1, 2, 3]) {
      for (final meal in ['Breakfast', 'Lunch', 'Dinner', 'Snack']) {
        n++;
        final id = '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
        final r = await j.api.post<Map>('/food-entries', options: auth, data: {
          'operationId': '10000000-0000-4000-8000-${n.toString().padLeft(12, '0')}', 'entryId': id, 'dayKey': addDays(today, -d), 'meal': meal,
          'name': 'Egg', 'amountDescription': '100 g', 'macros': {'calories': 143, 'protein': 12.6, 'carbs': 0.7, 'fat': 9.5},
          'source': {'item': egg, 'quantity': 100, 'unit': 'g'}, 'provenance': {'calories': 'imported', 'protein': 'imported', 'carbs': 'imported', 'fat': 'imported'},
        });
        expect(r.statusCode, inInclusiveRange(200, 299), reason: '${r.data}');
      }
    }

    // Suggestions are off until chosen.
    await j.tapKey('nav-me');
    await j.tapKey('me-meal-suggestions');
    await j.tap(find.descendant(of: find.byKey(const Key('habit-switch')), matching: find.byType(Switch)));
    await j.shot('hb-01-suggestions-on');
    await tester.pageBack();
    await j.settle();

    // Eat offers the usual meal once the earlier days have arrived on the phone.
    await j.tapKey('nav-eat');
    await j.waitFor(find.byKey(const Key('habit-review')), what: 'the usual meal', seconds: 120);
    await j.shot('hb-02-usual-meal');
    await j.tapKey('habit-review');
    await j.waitFor(find.byKey(const Key('meal-log')), what: 'the review');
    await j.tapKey('meal-part-0');
    await j.type('food-quantity', '150');
    await j.tapKey('food-save'); // "Use this amount": this time only, nothing logged
    await j.waitFor(find.byKey(const Key('meal-log')), what: 'back in the review');
    await j.shot('hb-03-review-changed');
    await tester.pageBack();
    await j.settle(8);
    expect(await todays(), isEmpty, reason: 'leaving the review logs nothing');

    await j.tapKey('habit-review');
    await j.tapKey('meal-log');
    await j.waitFor(find.byType(EatScreen), what: 'back on Eat');
    await j.waitUntil(() async => (await todays()).length == 1, what: 'one entry on the account');
    expect((await todays()).single['amountDescription'], '100 g', reason: 'the usual amount, logged once');
    expect(find.byKey(const Key('habit-review')), findsNothing, reason: 'that meal is logged: no suggestion');

    // A supplement reminder: made, renamed, paused, on again; today's occurrence confirmed.
    await j.tapKey('nav-me');
    await j.tapKey('me-reminders-page');
    await j.tapKey('reminder-add');
    await j.tapKey('reminder-category-supplement');
    await j.type('reminder-name', 'Vitamin D');
    await j.tapKey('reminder-time');
    await j.confirmWith('OK'); // the picker's own time (8:00)
    await j.tapKey('reminder-save');
    await j.waitFor(find.byKey(const Key('reminder-add')), what: 'back on Reminders');
    final row = find.byWidgetPredicate((w) => w is GroupRow && '${w.key}'.contains("'reminder-") && w.title.startsWith('Vitamin D'));
    await j.tap(row);
    await j.type('reminder-name', 'Vitamin D3');
    await j.tapKey('reminder-save');
    await j.waitFor(find.byKey(const Key('reminder-add')), what: 'back on Reminders');
    await j.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await j.waitFor(find.textContaining('Paused'), what: 'paused');
    await j.shot('hb-04-reminder-paused');
    await j.tap(find.descendant(of: row, matching: find.byType(Switch)));
    final dose = find.byWidgetPredicate((w) => w is GroupRow && '${w.key}'.contains("'dose-"));
    await j.waitFor(dose, what: "today's occurrence");
    expect(find.descendant(of: dose, matching: find.text('Unconfirmed')), findsOneWidget);
    await j.tap(dose);
    await j.tapKey('dose-taken');
    await j.waitFor(find.descendant(of: dose, matching: find.text('Taken')), what: 'confirmed');
    await j.shot('hb-05-taken');

    final s = await j.snapshot(await j.apiToken());
    expect('$s'.contains('Vitamin'), isFalse, reason: 'reminders never reach the account');
    expect((await j.api.delete<void>('/account', data: {'password': j.password}, options: Options(headers: {'Authorization': 'Bearer ${await j.apiToken()}'}))).statusCode, 204);
    debugPrint('GOHARD_HB done; disposable account deleted');
  });
}
