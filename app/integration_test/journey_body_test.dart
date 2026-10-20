import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'support.dart';

/// Body progress (docs/BODY_PROGRESS.md) on a real install against the local API, in two runs of this file by
/// scripts\test-android.ps1 -Only journey_body_test (not in the default run).
///
/// Phase 1: a new account. Two older entries are SEEDED through the API as an older app would send them (weight only,
/// no saved time, on one day 9 days ago): the legacy state. In the app: today's check-in in lb / in (weight, waist,
/// left upper arm), a measurement-only entry for yesterday, Compare dates, body units changed to cm in Me › Units,
/// today's entry corrected (waist), then, with Wi-Fi and data off, one more check-in saved on the phone.
/// Phase 2 is a new process: the offline entry is still there and waiting; back online it reaches the account once;
/// removing it recalculates the 7-day average.
const _phase = String.fromEnvironment('GOHARD_PHASE');
const _surface = MethodChannel('plugins.flutter.io/integration_test');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('body progress phase $_phase', (tester) async {
    final j = Journey(tester, binding);
    final today = dayKeyOf(DateTime.now());
    final account = File('${(await getApplicationDocumentsDirectory()).path}/body-journey-account.txt');
    ProviderContainer scope() => ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    Future<void> back() async {
      await tester.pageBack();
      await j.settle(4);
    }

    Future<void> openBody() async {
      await j.tapKey('nav-me');
      await j.tapKey('me-body');
      await j.waitFor(find.byKey(const Key('body-weight-panel')), what: 'Body progress');
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
      await j.settle(2);
    }

    Future<List<Map>> metrics(String token) async => ((await j.snapshot(token))['bodyMetrics'] as List).cast<Map>().where((m) => m['isDeleted'] != true).toList();

    if (_phase == '1') {
      await j.start('Body Journey');
      await account.writeAsString(j.email);

      // --- SEEDED legacy entries: the old app's shape, two on one day, no saved time.
      final token = await j.apiToken();
      final auth = Options(headers: {'Authorization': 'Bearer $token'});
      const uuid = Uuid();
      final legacyDay = addDays(today, -9);
      for (final kg in [90.9, 90.5]) {
        final r = await j.api.post<Map>('/body-metrics', data: {'operationId': uuid.v4(), 'metricId': uuid.v4(), 'dayKey': legacyDay, 'weightKg': kg, 'bodyFatPercent': null, 'note': 'Seeded'}, options: auth);
        expect(r.data?['status'], 'accepted');
      }
      expect(await scope().read(syncProvider).pull(), isTrue);

      await _surface.invokeMethod<void>('revertFlutterImage');
      await openBody();
      debugPrint('GOHARD_REC:start:body-flow');
      await watch(1500);
      expect(find.text('Average of 2 entries on ${_dayMonth(legacyDay)}'), findsOneWidget, reason: 'legacy same-day entries: an honest average');

      // --- Today's check-in in pounds and inches.
      await j.tapKey('body-log');
      await j.tapKey('body-mass-lb');
      await j.tapKey('body-length-inch');
      await j.type('body-field-weight', '198');
      await j.type('body-field-waist', '35,5');
      await j.type('body-field-leftUpperArm', '16.25');
      FocusManager.instance.primaryFocus?.unfocus();
      await watch(1000);
      await j.tapKey('body-save');
      await j.waitFor(find.text('198.0 lb'), what: 'today\'s weight on the overview');
      await watch(1500);

      // --- A measurement-only entry for yesterday (only when yesterday is in this month, for the date picker).
      final day = DateTime.now().day;
      if (day > 1) {
        await j.tapKey('body-log');
        await j.tapKey('body-date');
        await j.tap(find.text('${day - 1}'));
        await j.tapText('OK');
        await j.type('body-field-waist', '35.75');
        FocusManager.instance.primaryFocus?.unfocus();
        await watch(800);
        await j.tapKey('body-save');
        await j.waitFor(find.byKey(const Key('body-weight-panel')));
      }

      // --- Compare the newest two days.
      await j.tapKey('body-compare');
      await j.waitFor(find.byKey(const Key('body-compare-from')), what: 'Compare dates');
      await watch(2500);
      await back();

      // --- Body units to cm (lifting unit untouched), then correct today's waist.
      await back();
      await j.tapKey('me-units');
      await j.tapKey('unit-body-cm');
      await j.tapKey('me-body');
      await j.waitFor(find.byKey(const Key('body-weight-panel')), what: 'Body progress');
      await j.reveal(find.byKey(const Key('body-latest-waist')));
      expect(find.descendant(of: find.byKey(const Key('body-latest-waist')), matching: find.text('90.17 cm')), findsOneWidget, reason: 'the waist in centimetres');
      await j.tapKey('body-all');
      await j.tap(find.textContaining('Weight 198.0 lb').first);
      await j.type('body-field-waist', '89.5');
      FocusManager.instance.primaryFocus?.unfocus();
      await watch(800);
      await j.tapKey('body-save');
      await j.waitFor(find.textContaining('Waist 89.5 cm'), what: 'the corrected entry');
      await watch(1500);
      await back();

      // --- Offline: one more check-in, saved on the phone.
      debugPrint('GOHARD_NET:off');
      await j.waitUntil(() async => !await j.apiReachable(), what: 'the phone to be offline');
      await j.tapKey('body-log');
      await j.type('body-field-weight', '197.6');
      FocusManager.instance.primaryFocus?.unfocus();
      await watch(800);
      await j.tapKey('body-save');
      await j.waitFor(find.byKey(const Key('body-pending')), what: 'saved on this phone, waiting');
      await watch(2000);
      debugPrint('GOHARD_REC:stop');
      await watch(5000);

      // --- Captures.
      await _surface.invokeMethod<void>('convertFlutterSurfaceToImage');
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
      await j.shot('body-01-overview-offline-pending');
      await j.tapKey('body-log');
      await j.type('body-field-waist', '89.4');
      FocusManager.instance.primaryFocus?.unfocus();
      await j.settle(4);
      await j.shot('body-02-log');
      await back();
      await j.tapText('Discard');
      await j.tapKey('body-compare');
      await j.waitFor(find.byKey(const Key('body-compare-from')));
      await j.shot('body-03-compare');
      await back();
      await j.tapKey('body-all');
      await j.waitFor(find.textContaining('order not known'), what: 'the legacy entries in history');
      await j.shot('body-04-legacy-history');
      await back();
      return;
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    j.email = await account.readAsString();
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('nav-me')), what: 'the app after the process ended', seconds: 40);
    await openBody();
    expect(find.byKey(const Key('body-pending')), findsOneWidget, reason: 'the offline entry survived the restart, still waiting');
    debugPrint('GOHARD_NET:on');
    final token = await (() async {
      for (var i = 0; i < 60; i++) {
        await watch(1000);
        if (await j.apiReachable()) return j.apiToken();
      }
      fail('The API did not become reachable again.');
    })();
    await scope().read(syncProvider).flush();
    final expected = DateTime.now().day > 1 ? 5 : 4; // 2 seeded, today, (yesterday), offline
    await j.waitUntil(() async => (await metrics(token)).length == expected, what: 'every entry on the account');
    final onAccount = await metrics(token);
    expect(onAccount.where((m) => m['dayKey'] == today && m['weightKg'] != null).length, 2, reason: 'the offline entry arrived once, not twice');
    final corrected = onAccount.firstWhere((m) => m['dayKey'] == today && (m['waistCm'] as num?) != null);
    expect(((corrected['waistCm'] as num).toDouble(), corrected['revision']), (89.5, 2), reason: 'corrected in place');
    await j.waitUntil(() async => find.byKey(const Key('body-pending')).evaluate().isEmpty, what: 'the pending line to go');

    // Today has 198.0 lb and 197.6 lb (two entries, known order): the 7-day average takes their mean as one day.
    final before = tester.widget<Text>(find.byKey(const Key('body-average'))).data;
    await j.tapKey('body-all');
    await j.tap(find.textContaining('Weight 197.6 lb').first);
    await j.tapKey('body-delete');
    await j.confirmWith('Delete');
    await j.settle(4);
    await back();
    await j.waitUntil(() async => tester.widget<Text>(find.byKey(const Key('body-average'))).data != before, what: 'the average to be recalculated');
    debugPrint('GOHARD_BODY average before=$before after=${tester.widget<Text>(find.byKey(const Key('body-average'))).data}');
    await j.shot('body-05-after-sync-and-delete');
  });
}

String _dayMonth(String day) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = parseDayKey(day);
  return '${months[d.month - 1]} ${d.day}';
}
