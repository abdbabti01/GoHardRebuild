import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// R5, fifth native journey: the offline promise and a real two-device conflict, on the device.
///
/// scripts\test-android.ps1 watches this test's log for GOHARD_NET:off / GOHARD_NET:on and switches the
/// emulator's Wi-Fi and mobile data accordingly, so the phone is genuinely offline in the middle part.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline_training_and_food_sync_once_then_a_two_device_conflict_is_reviewed', (tester) async {
    final j = Journey(tester, binding);
    await j.start('Offline Tester');

    // --- Go offline for real.
    // ignore: avoid_print
    print('GOHARD_NET:off');
    await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');

    // A full manual workout and a food entry, entirely offline.
    await j.tapKey('nav-train');
    await j.tapKey('start-manual');
    await j.type('manual-title', 'No signal');
    await j.tapKey('manual-add-exercise');
    await j.tapKey('exercise-push-up');
    await j.tapKey('manual-start');
    await j.type('set-reps', '10');
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('set-row-0')));
    await j.tapKey('complete-set');
    await j.waitFor(find.byKey(const Key('set-row-1')));
    expect(find.textContaining('sync pending'), findsWidgets, reason: 'saved on the phone, honestly not yet in the account');
    await j.shot('70-offline-sets-pending');
    await j.tapKey('finish-workout');
    await j.tapKey('finish-confirm');
    await j.waitFor(find.text('Recorded'), what: 'the result, available immediately while offline');
    expect(find.textContaining('sync pending'), findsOneWidget);
    await j.tapKey('result-done');

    await j.tapKey('nav-today');
    await j.tapKey('log-food');
    await j.tapKey('food-manual'); // manual entry needs no connection
    await j.type('food-name', 'Banana');
    await j.type('food-amount', '1 medium');
    await j.tapKey('food-save');
    await j.waitFor(find.textContaining('Latest: Banana'), what: 'the food on Today while offline');
    await tester.drag(find.byType(ListView).hitTestable().last, const Offset(0, 500)); // pull to refresh: the account cannot be reached
    await j.waitFor(find.textContaining('Offline. Showing'), what: 'the offline notice');
    await j.shot('71-today-offline');
    await j.tapKey('nav-me');
    await j.reveal(find.textContaining('waiting to sync'));
    await j.waitFor(find.textContaining('waiting to sync'), what: 'the pending count in Me');

    // --- Reconnect. Everything syncs once, without the user repeating anything.
    // ignore: avoid_print
    print('GOHARD_NET:on');
    await j.waitUntil(j.apiReachable, what: 'the phone to be online again', seconds: 90);
    await j.waitUntil(() async {
      await j.tapKey('me-sync'); // asks the account again; safe to repeat
      return find.text('Everything is saved to your account').evaluate().isNotEmpty;
    }, what: 'all offline work to reach the account', seconds: 120);
    await j.shot('72-me-synced');

    final token = await j.apiToken();
    final auth = Options(headers: {'Authorization': 'Bearer $token'});
    var account = await j.snapshot(token);
    final workout = (account['workouts'] as List).single as Map;
    final sets = [for (final e in workout['exercises'] as List) ...(e as Map)['sets'] as List];
    expect((workout['outcome'], workout['performedSets'], sets.length), ('manual_recorded', 2, 2), reason: 'one workout, two sets, one finish: nothing duplicated');
    final food = (account['foodEntries'] as List).single as Map;
    expect((food['name'], food['revision']), ('Banana', 1));

    // --- This phone has an edit typed and ready; another device changes the same food; then the phone saves.
    // The other device's change lands in between, so the phone's save is made against the older revision.
    await j.tapKey('nav-eat');
    await j.tapText('Banana');
    await j.waitFor(find.text('Edit food'), what: 'the edit form');
    await j.type('food-name', 'Banana (phone)');
    final other = await j.api.put<Map>('/food-entries/${food['id']}', options: auth, data: {
      'operationId': '99999999-9999-4999-8999-${(DateTime.now().millisecondsSinceEpoch % 1000000000000).toString().padLeft(12, '0')}', 'expectedRevision': 1,
      'dayKey': food['dayKey'], 'meal': food['meal'], 'name': 'Banana (tablet)', 'amountDescription': food['amountDescription'], 'macros': food['macros'],
    });
    expect(other.data!['status'], 'accepted');
    await j.tapKey('food-save');
    await j.waitFor(find.textContaining('your review'), what: 'the review notice for the conflicting edit');
    await j.tap(find.textContaining('your review'));
    await j.waitFor(find.text('Banana (tablet) · 1 medium · Breakfast · ${_short(food['dayKey'] as String)}'), what: 'the account version shown beside the phone version');
    expect(find.textContaining('Banana (phone)'), findsOneWidget, reason: 'the phone version is kept, not overwritten. On screen: ${j.onScreen}');
    await j.shot('73-conflict-review');
    await j.tapKey('issue-keep-${food['id']}');
    await j.waitFor(find.text('Nothing to review'));
    await j.waitUntil(() async => ((await j.snapshot(token))['foodEntries'] as List).any((f) => (f as Map)['name'] == 'Banana (phone)'), what: 'the chosen version to reach the account');
    account = await j.snapshot(token);
    expect((account['foodEntries'] as List).length, 1, reason: 'resolving a conflict never adds an entry');
  });
}

String _short(String dayKey) {
  final d = DateTime.parse('${dayKey}T00:00:00Z');
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}
