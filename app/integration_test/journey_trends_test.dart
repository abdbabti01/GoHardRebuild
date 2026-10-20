import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/core/format.dart';
import 'package:gohard_rebuild/features/nutrition/eat_screen.dart';
import 'package:gohard_rebuild/features/nutrition/water.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'support.dart';

/// Eat › History & trends (docs/FOOD_DATA.md › History & trends) on a real install against a local API, in two runs of
/// this file by scripts\test-android.ps1 -Only journey_trends_test (not in the default run).
///
/// Phase 1: a new account. Last week is SEEDED through the API, every entry named "Seeded …": Monday complete, Tuesday
/// not logged, Wednesday partial (a sauce without values), Thursday unknown only, Friday water only, Saturday a recorded
/// zero, Sunday complete. Viewing the week, choosing days, opening Wednesday's journal, Month, Protein and Water send
/// nothing. Then, offline, Wednesday's pasta is removed from that day's journal.
/// Phase 2 is a new process: the removal is still there; back online it reaches the account once and the week's
/// totals stay as they were after the removal.
const _phase = String.fromEnvironment('GOHARD_PHASE');
const _surface = MethodChannel('plugins.flutter.io/integration_test');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nutrition trends phase $_phase', (tester) async {
    final j = Journey(tester, binding);
    final today = dayKeyOf(DateTime.now());
    final monday = addDays(today, 1 - parseDayKey(today).weekday - 7); // last week's Monday
    String day(int i) => addDays(monday, i);
    final account = File('${(await getApplicationDocumentsDirectory()).path}/trends-journey-account.txt');
    ProviderContainer scope() => ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    Future<int> commands() async => (await scope().read(syncProvider).commands(scope().read(ownerProvider)!)).length;
    Finder inEat(Key key) => find.descendant(of: find.byType(EatScreen), matching: find.byKey(key));

    Future<void> openLastWeek() async {
      await j.tapKey('nav-eat');
      await j.tap(inEat(const Key('eat-history')));
      await j.waitFor(find.byKey(const Key('trends-period-label')), what: 'History & trends');
      if (text('trends-period-label') != _week(monday)) await j.tapKey('trends-previous');
      expect(text('trends-period-label'), _week(monday));
    }

    if (_phase == '1') {
      await j.start('Trends Journey');
      await account.writeAsString(j.email);

      // --- SEEDED last week, through the API as another phone would log it.
      final token = await j.apiToken();
      final auth = Options(headers: {'Authorization': 'Bearer $token'});
      const uuid = Uuid();
      Future<void> food(int d, String meal, String name, num? kcal, num? protein) async {
        final r = await j.api.post<Map>('/food-entries', options: auth, data: {
          'operationId': uuid.v4(), 'entryId': uuid.v4(), 'dayKey': day(d), 'meal': meal, 'name': 'Seeded $name', 'amountDescription': '1 serving',
          'macros': {'calories': kcal, 'protein': protein, 'carbs': null, 'fat': null},
        });
        expect(r.data?['status'], 'accepted', reason: '$name: ${r.data}');
      }

      await food(0, 'Breakfast', 'oatmeal', 450, 15);
      await food(0, 'Lunch', 'chicken', 700, 50);
      await food(2, 'Dinner', 'pasta', 860, 30);
      await food(2, 'Dinner', 'homemade sauce', null, null);
      await food(3, 'Lunch', 'soup', null, null);
      await food(5, 'Snack', 'black coffee', 0, 0);
      await food(6, 'Lunch', 'salad', 520, 20);
      final w = await j.api.post<Map>('/water-entries', options: auth, data: {'operationId': uuid.v4(), 'entryId': uuid.v4(), 'dayKey': day(4), 'volumeMl': 750});
      expect(w.data?['status'], 'accepted');
      expect(await scope().read(syncProvider).pull(), isTrue);
      await setNutritionDisplay(scope().read, const NutritionDisplay(water: true)); // the account's own choice, before viewing
      await j.waitUntil(() async => (await scope().read(syncProvider).commands(scope().read(ownerProvider)!)).every((c) => c.state != 'pending'), what: 'the display choice to be sent');
      final before = await commands();

      await _surface.invokeMethod<void>('revertFlutterImage');
      debugPrint('GOHARD_REC:start:trends-flow');
      await openLastWeek();
      await watch(1200);
      expect((text('trends-total'), text('trends-coverage'), text('trends-average')), ('2,530 kcal', '4 of 7 days with calorie values', '633 kcal'),
          reason: 'Monday, Wednesday (partial), Saturday (zero) and Sunday; not Tuesday, Thursday or Friday');

      // Sunday is chosen; step back through the days with the day panel.
      for (final (d, words) in [(5, '0 kcal recorded'), (4, 'No food logged'), (3, 'Calories not entered'), (2, '860 kcal known')]) {
        await j.tapKey('trends-day-previous');
        await watch(600);
        expect(text('trends-selected-date'), longDate(day(d)));
        expect(text('trends-selected-value'), startsWith(words));
      }
      await j.tapKey('trends-view-day');
      await j.waitFor(inEat(const Key('eat-back-to-today')), what: 'Wednesday in Eat');
      expect(find.text(longDate(day(2))), findsOneWidget);
      await j.reveal(find.text('Seeded homemade sauce'));
      await watch(1500);

      await j.tap(inEat(const Key('eat-history')));
      await j.waitFor(find.byKey(const Key('trends-period-label')));
      expect(text('trends-period-label'), _week(monday), reason: 'the same week');
      await j.reveal(find.byKey(const Key('trends-selected-date'))); // below the fold: the list builds it on the way
      await j.waitFor(find.byKey(const Key('trends-selected-date')));
      expect(text('trends-selected-date'), longDate(day(2)), reason: 'the same day');
      await j.tapKey('trends-kind-month');
      await watch(1200);
      await j.tapKey('trends-metric-protein');
      await watch(900);
      await j.tapKey('trends-metric-water');
      await watch(900);
      await j.tapKey('trends-kind-week');
      await j.tapKey('trends-metric-calories');
      final open = await scope().read(syncProvider).commands(scope().read(ownerProvider)!);
      expect(open.where((c) => c.kind.startsWith('food') || c.kind.startsWith('water')), isEmpty, reason: 'viewing history logged, changed or removed nothing');
      expect(open.length, lessThanOrEqualTo(before), reason: 'and queued nothing else (the display choice may finish sending meanwhile)');

      // --- Offline: remove Wednesday's pasta from that day's journal.
      await j.tapKey('trends-view-day');
      await j.waitFor(inEat(const Key('eat-back-to-today')));
      debugPrint('GOHARD_NET:off');
      await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');
      await j.tap(find.text('Seeded pasta'));
      await j.tapKey('food-remove');
      await j.confirmWith('Remove this food');
      await j.waitUntil(() async => find.text('Seeded pasta').evaluate().isEmpty, what: 'the pasta to leave the journal');
      await j.tap(inEat(const Key('eat-history')));
      await j.waitFor(find.byKey(const Key('trends-total')));
      expect((text('trends-total'), text('trends-coverage')), ('1,670 kcal', '3 of 7 days with calorie values'), reason: 'Wednesday now has only an unknown value');
      await watch(1500);
      debugPrint('GOHARD_REC:stop');
      await watch(5000);

      // --- Captures.
      await _surface.invokeMethod<void>('convertFlutterSurfaceToImage');
      tester.state<ScrollableState>(find.byType(Scrollable).last).position.jumpTo(0);
      await j.shot('trends-01-week-after-offline-removal');
      // Wednesday is still chosen: after the removal only the sauce, without a calorie value, is left on it.
      await j.reveal(find.byKey(const Key('trends-selected')));
      expect(text('trends-selected-value'), startsWith('Calories not entered'));
      await j.shot('trends-02-week-unknown-day');
      await j.tapKey('trends-kind-month');
      tester.state<ScrollableState>(find.byType(Scrollable).last).position.jumpTo(0);
      await j.shot('trends-03-month');
      await j.tapKey('trends-view-day');
      await j.waitFor(inEat(const Key('eat-back-to-today')));
      await j.shot('trends-04-selected-day-journal');
      return;
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    j.email = await account.readAsString();
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('nav-eat')), what: 'the app after the process ended', seconds: 40);
    await openLastWeek();
    expect(text('trends-total'), '1,670 kcal', reason: 'the offline removal survived the restart');
    debugPrint('GOHARD_NET:on');
    final token = await (() async {
      for (var i = 0; i < 60; i++) {
        await watch(1000);
        if (await j.apiReachable()) return j.apiToken();
      }
      fail('The API did not become reachable again.');
    })();
    await scope().read(syncProvider).flush();
    await j.waitUntil(() async {
      final food = (await j.snapshot(token))['foodEntries'] as List;
      return food.cast<Map>().any((f) => f['name'] == 'Seeded pasta' && f['isDeleted'] == true);
    }, what: 'the removal on the account');
    await scope().read(syncProvider).pull();
    await watch(1500);
    expect((text('trends-total'), text('trends-coverage')), ('1,670 kcal', '3 of 7 days with calorie values'), reason: 'counted once after reconnecting');
    await j.shot('trends-05-after-reconnect');
  });
}

String _week(String monday) {
  final a = parseDayKey(monday), b = parseDayKey(addDays(monday, 6));
  if (a.year != b.year) return '${dayMonth(monday)}, ${a.year} – ${dayMonth(addDays(monday, 6))}, ${b.year}';
  return '${dayMonth(monday)} – ${a.month == b.month ? '${b.day}' : dayMonth(addDays(monday, 6))}, ${b.year}';
}
