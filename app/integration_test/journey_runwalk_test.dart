import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/activity/run_walk_screens.dart' show StatFigure;
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support.dart';

/// Run / Walk on a device (docs/RUN_WALK.md), in two runs of this file by scripts\test-android.ps1:
///
/// Phase 1: a walk is recorded from the real app with real geolocator readings, while the host feeds the emulator's
/// test location provider a walk north (SIMULATED GPS: no outdoor movement is involved). Stats and Map views, zoom,
/// Recenter and Pause never interrupt it; it keeps recording with another app in front and with the screen off (the
/// host presses Home / locks the phone on GOHARD_BG markers and captures the recording notification). The phase ends
/// while recording; the host force-stops the app.
///
/// Phase 2 is a new process: the walk is Interrupted, resumed, finished and saved with the phone offline, shown in
/// Saved, Splits, Charts and History; back online it syncs once, with its whole route. A short run follows for the
/// Run captures.
///
/// Captures are taken by the host (`GOHARD_SHOT:name`, adb screencap), so the Google map, a platform view, is in them;
/// GOHARD_REC:start/stop marks the screen recording.
const _phase = String.fromEnvironment('GOHARD_PHASE');
const _channel = MethodChannel('plugins.flutter.io/integration_test');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('run / walk phase $_phase', (tester) async {
    final j = Journey(tester, binding);

    /// Real time passes on a device only through real delays; frames are pumped meanwhile.
    Future<void> watch(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    }

    Future<void> shot(String name) async {
      await watch(1200);
      debugPrint('GOHARD_SHOT:$name');
      await watch(2500); // the host's screencap
    }

    double distance() {
      final f = find.byKey(const Key('runwalk-distance'));
      if (f.evaluate().isEmpty) return 0;
      return double.tryParse(tester.widget<StatFigure>(f).value) ?? 0;
    }

    Future<double> distanceAtLeast(double km, {int seconds = 120}) async {
      for (var i = 0; i < seconds * 2; i++) {
        if (distance() >= km) return distance();
        await watch(500);
      }
      fail('Distance stayed at ${distance()} km (wanted $km). On screen: ${j.onScreen}');
    }

    Future<void> waitText(String text, {int seconds = 60}) async {
      for (var i = 0; i < seconds * 2 && find.text(text).evaluate().isEmpty; i++) {
        await watch(500);
      }
      await j.waitFor(find.text(text), what: text);
    }

    // The account is created in phase 1; phase 2 (a new process) reads its email back to talk to the API as it.
    final account = File('${(await getApplicationDocumentsDirectory()).path}/runwalk-journey-account.txt');
    if (_phase == '1') {
      await j.start('Walk Journey');
      await account.writeAsString(j.email);
      await _channel.invokeMethod<void>('revertFlutterImage'); // the live surface, for screencap and screenrecord
      await shot('runwalk-01-today');

      await j.tapKey('today-run');
      await j.waitFor(find.byKey(const Key('runwalk-start')), what: 'Ready');
      await waitText('GPS ready', seconds: 90);
      expect(find.text('Simulated GPS (test build)'), findsNothing, reason: 'the device location source, fed by the host');
      await shot('runwalk-02-ready-run');
      await j.tapKey('activity-type-walk');
      await shot('runwalk-03-ready-walk');

      debugPrint('GOHARD_REC:start:runwalk-flow');
      await watch(1500);
      await j.tapKey('runwalk-start');
      await j.waitFor(find.byKey(const Key('runwalk-finish')), what: 'recording');
      await distanceAtLeast(0.03);
      await shot('runwalk-04-recording-stats');

      await j.tapKey('map-expand');
      await j.waitFor(find.byKey(const Key('runwalk-map-full')), what: 'the map view');
      await shot('runwalk-05-recording-map');
      await tester.tap(find.byKey(const Key('map-zoom-in')));
      await watch(4000); // new fixes arrive meanwhile
      expect(find.bySemanticsLabel('Recenter'), findsOneWidget, reason: 'a manual zoom is kept while fixes arrive');
      await tester.tap(find.byKey(const Key('map-recenter')));
      await watch(1500);
      expect(find.bySemanticsLabel('Following your position'), findsOneWidget);
      await j.tapKey('runwalk-view-false');
      await distanceAtLeast(0.04);
      await j.tapKey('runwalk-pause');
      await j.waitFor(find.text('Paused'), what: 'paused');
      await watch(1500); // fixes already on their way before the tap
      final paused = distance();
      await watch(8000); // the host keeps walking the position north meanwhile
      expect(distance(), paused, reason: 'nothing is counted while paused');
      await shot('runwalk-06-paused');
      await j.tapKey('runwalk-resume');
      await watch(3000);
      debugPrint('GOHARD_REC:stop');
      await watch(1500);

      // Another app in front, then the screen off: the recording goes on (foreground service).
      final d0 = distance();
      debugPrint('GOHARD_BG:home');
      await watch(26000);
      final d1 = distance();
      expect(d1, greaterThan(d0 + 0.015), reason: 'distance kept growing while another app was in front ($d0 → $d1 km)');
      debugPrint('GOHARD_BG:lock');
      await watch(26000);
      final d2 = distance();
      expect(d2, greaterThan(d1 + 0.015), reason: 'distance kept growing with the screen off ($d1 → $d2 km)');
      await shot('runwalk-08-after-background');
      debugPrint('GOHARD_PHASE1:recording-left-open distance=$d2');
      return; // the host force-stops the app while it records
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    j.email = await account.readAsString();
    await app.main();
    await _channel.invokeMethod<void>('revertFlutterImage');
    await waitText('Walk interrupted', seconds: 40);
    await shot('runwalk-09-today-interrupted');
    await j.tapKey('today-run');
    await j.waitFor(find.byKey(const Key('runwalk-resume')), what: 'the interrupted walk');
    expect(find.textContaining('Recording stopped when GoHard was closed'), findsOneWidget);
    await shot('runwalk-10-interrupted');
    final before = distance();
    await j.tapKey('runwalk-resume');
    await distanceAtLeast(before + 0.02);
    await j.tapKey('runwalk-finish');
    await j.waitFor(find.byKey(const Key('runwalk-save')), what: 'the save review');
    await shot('runwalk-11-review');

    // Saved with no connection: on the phone first.
    debugPrint('GOHARD_NET:off');
    await watch(5000);
    await j.tapKey('runwalk-save');
    await j.waitFor(find.byKey(const Key('activity-done')), what: 'Saved');
    await shot('runwalk-12-saved');
    await j.reveal(find.textContaining('waiting to upload'));
    expect(find.textContaining('waiting to upload'), findsOneWidget, reason: 'route not synced yet, said as such');
    await j.tapKey('activity-tab-splits');
    await shot('runwalk-13-splits');
    await j.tapKey('activity-tab-charts');
    await j.reveal(find.byKey(const Key('chart-pace')));
    await shot('runwalk-14-charts');
    await j.tapKey('activity-done');
    await waitText('Walk finished today');
    await j.tapKey('nav-train');
    await j.tapKey('train-run-history');
    await j.waitFor(find.text('History'), what: 'history');
    await shot('runwalk-15-history');
    await tester.pageBack();
    await watch(1500);

    // Online again: it syncs once, summary and whole route.
    debugPrint('GOHARD_NET:on');
    await watch(6000);
    final token = await j.apiToken();
    final auth = Options(headers: {'Authorization': 'Bearer $token'});
    late List runs;
    await j.waitUntil(() async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300)); // pull to refresh: sync now
      await watch(2000);
      runs = (await j.snapshot(token))['runs'] as List;
      return runs.isNotEmpty && (runs.single as Map)['routeState'] == 'complete';
    }, what: 'the walk and its whole route on the account', seconds: 120);
    final walk = runs.single as Map;
    expect(walk['activityType'], 'walk', reason: 'a walk is stored as a walk, not a run');
    expect(walk['title'], 'Morning walk');
    expect(walk['finishedAtUtc'], isNotNull);
    final route = (await j.api.get<Map>('/runs/${walk['id']}/route', options: auth)).data!;
    final entries = [for (final c in route['chunks'] as List) ...((c as Map)['entries'] as List)];
    expect(entries.length, greaterThan(60), reason: 'the stored route, start to finish');
    expect([for (final e in entries) (e as Map)['s']], [for (var i = 0; i < entries.length; i++) i], reason: 'ordered, no gaps or duplicates in sequence');
    expect(entries.where((e) => (e as Map)['y'] == 'interrupt'), hasLength(1), reason: 'the process ending is recorded as an interruption');
    debugPrint('GOHARD_SYNCED walk=${walk['id']} entries=${entries.length} distance=${walk['distanceMeters']}');

    // A short run for the Run captures.
    await j.tapKey('today-run');
    await j.waitFor(find.byKey(const Key('runwalk-start')), what: 'Ready');
    await j.tapKey('activity-type-run');
    await waitText('GPS ready');
    await j.tapKey('runwalk-start');
    await distanceAtLeast(0.03);
    await shot('runwalk-16-run-recording');
    await j.tapKey('map-expand');
    await shot('runwalk-17-run-map');
    await j.tapKey('runwalk-finish');
    await j.tapKey('runwalk-save');
    await j.waitFor(find.byKey(const Key('activity-done')), what: 'the saved run');
    await shot('runwalk-18-run-saved');
    await j.tapKey('activity-done');
    await waitText('Run finished today');
    final all = (await j.snapshot(token))['runs'] as List;
    expect(all.length, lessThanOrEqualTo(2), reason: 'no duplicate activities');
    await binding.convertFlutterSurfaceToImage(); // the first call in this process (phase 2 never called it)
    await j.shot('runwalk-19-today-after');
  });
}
