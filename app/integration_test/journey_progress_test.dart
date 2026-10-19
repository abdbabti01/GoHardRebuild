import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/app/providers.dart';
import 'package:gohard_rebuild/core/clock.dart';
import 'package:gohard_rebuild/core/widgets.dart';
import 'package:gohard_rebuild/features/progress/weekly.dart';
import 'package:gohard_rebuild/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'support.dart';

/// Train › Progress (docs/PROGRESS.md) on a real install against the local API, in two runs of this file by
/// scripts\test-android.ps1 -Only journey_progress_test.
///
/// Phase 1: a new account. Last week's history is SEEDED through the API as another device would send it (labelled
/// "Seeded" in its titles: two bench sessions, a walk, and last week's goals 3 workouts / 2 runs or walks); this week's
/// bench session is recorded in the app. Progress shows the counts against the inherited goal; the bench trend opens
/// a real session; last week's recap shows its own goals and highlight. Offline, this week's goals are changed to
/// 4 / 1 and saved on the phone. Phase 2 is a new process: the goals are still there, waiting; back online they reach
/// the account, last week's record is unchanged, and the recap still measures last week against 3.
const _phase = String.fromEnvironment('GOHARD_PHASE');
const _surface = MethodChannel('plugins.flutter.io/integration_test');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progress phase $_phase', (tester) async {
    final j = Journey(tester, binding);
    final today = dayKeyOf(DateTime.now());
    final thisMonday = mondayOf(today), lastMonday = addDays(mondayOf(today), -7);
    final account = File('${(await getApplicationDocumentsDirectory()).path}/progress-journey-account.txt');
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

    Finder inRow(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
    Future<Map<String, dynamic>?> goalOn(String token, String monday) async =>
        ((await j.snapshot(token))['weeklyGoals'] as List).cast<Map>().where((g) => g['weekStart'] == monday).firstOrNull?.cast<String, dynamic>();

    if (_phase == '1') {
      await j.start('Progress Journey');
      await account.writeAsString(j.email);

      // --- SEEDED fixture history for last week, sent through the API as another device would.
      final token = await j.apiToken();
      final auth = Options(headers: {'Authorization': 'Bearer $token'});
      const uuid = Uuid();
      Future<Map> send(String method, String path, Map<String, dynamic> body) async {
        final r = await j.api.request<Map>(path, data: {'operationId': uuid.v4(), ...body}, options: auth.copyWith(method: method));
        expect(r.data?['status'], 'accepted', reason: '$method $path: ${r.data}');
        return r.data!['data'] as Map;
      }

      String at(String day, int hour) => DateTime.parse('${day}T${hour.toString().padLeft(2, '0')}:00:00').toUtc().toIso8601String();
      final seeded = <String, String>{};
      for (final (name, day, kg) in [('two-weeks', addDays(lastMonday, -6), 85), ('last-mon', lastMonday, 88.5), ('last-thu', addDays(lastMonday, 3), 93)]) {
        final id = uuid.v4(), ex = uuid.v4(), set = uuid.v4();
        final w = await send('POST', '/workouts', {
          'workoutId': id, 'kind': 'manual', 'occasionId': null, 'title': 'Seeded bench session', 'dayKey': day, 'startedAtUtc': at(day, 17),
          'exercises': [{'id': ex, 'ordinal': 1, 'name': 'Bench press', 'catalogKey': 'bench-press', 'occurrenceKey': null, 'isPrescribed': false, 'isTimed': false,
              'targetSets': null, 'targetRepsMin': null, 'targetRepsMax': null, 'targetDurationSeconds': null, 'restSeconds': null, 'substitutedForKey': null}],
        });
        final s = await send('POST', '/exercises/$ex/sets', {'setId': set, 'reps': 8, 'loadKg': kg, 'durationSeconds': null, 'performedAtUtc': at(day, 17)});
        await send('POST', '/workouts/$id/finish', {'expectedRevision': w['revision'], 'acknowledgedSets': [{'id': set, 'revision': s['revision']}], 'activeDurationSeconds': 2400, 'finishedAtUtc': at(day, 18)});
        seeded[name] = id;
      }
      final walk = uuid.v4(), walkDay = addDays(lastMonday, 1);
      final started = await send('POST', '/runs', {'runId': walk, 'dayKey': walkDay, 'startedAtUtc': at(walkDay, 7), 'activityType': 'walk'});
      await send('POST', '/runs/$walk/finish', {'expectedRevision': started['revision'], 'activeDurationSeconds': 2280, 'distanceMeters': 3100, 'finishedAtUtc': at(walkDay, 8), 'title': 'Seeded walk'});
      await send('PUT', '/weekly-goals/$lastMonday', {'expectedRevision': 0, 'workoutsTarget': 3, 'runWalkTarget': 2});
      expect(await scope().read(syncProvider).pull(), isTrue, reason: 'the phone reads the account, as a refresh does');

      // --- This week's session, recorded in the app.
      await j.tapKey('nav-train');
      await j.tapKey('train-workouts');
      await j.tapKey('start-manual');
      await j.type('manual-title', 'Bench today');
      await j.tapKey('manual-add-exercise');
      await j.type('exercise-search', 'Bench press');
      await j.tap(find.descendant(of: find.byType(ListRow), matching: find.text('Bench press')));
      await j.tapKey('manual-start');
      await j.waitFor(find.byKey(const Key('complete-set')), what: 'the recorder');
      await j.type('set-load', '95');
      await j.type('set-reps', '8');
      await j.tapKey('complete-set');
      await j.settle(4);
      await j.tapKey('finish-workout');
      await j.tapKey('finish-confirm');
      await j.waitFor(find.byKey(const Key('workout-result')), what: 'the saved result');
      await j.tapKey('result-done');

      // --- The linked flow, recorded on the live surface.
      await _surface.invokeMethod<void>('revertFlutterImage');
      await j.tapKey('train-progress');
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
      await j.waitFor(inRow('goal-row-workouts', '1 of 3'), what: 'this week against the goal inherited from last week');
      debugPrint('GOHARD_REC:start:progress-flow');
      await watch(2000);
      expect(inRow('goal-row-runwalk', '0 of 2'), findsOneWidget);
      await j.tapKey('trend-preview-bench-press');
      await j.waitFor(find.text('Top set load · 8 reps'), what: 'the bench trend');
      for (final id in seeded.values) {
        expect(find.byKey(Key('trend-session-$id')), findsOneWidget, reason: 'every seeded session within 4 weeks');
      }
      await watch(1500);
      await j.tapKey('trend-session-${seeded['last-thu']}');
      await j.waitFor(find.text('Seeded bench session'), what: 'the recorded session itself');
      expect(find.text('1.  93 kg × 8'), findsOneWidget);
      await watch(1200);
      await back();
      await back();
      await j.tapKey('progress-recap');
      await j.waitFor(find.byKey(const Key('recap-goal-workouts')), what: 'last week\'s recap with its goals');
      expect(inRow('recap-goal-workouts', '2 of 3'), findsOneWidget);
      expect(inRow('recap-goal-runwalk', '1 of 2'), findsOneWidget);
      expect(find.text('88.5 kg × 8 → 93 kg × 8'), findsOneWidget);
      await watch(1500);
      await j.reveal(find.byKey(Key('recap-run-$walk')));
      await watch(1200);
      await back();

      // Offline: this week's goals change to 4 and 1, saved on the phone only.
      debugPrint('GOHARD_NET:off');
      await watch(4000);
      await j.tapKey('goals-edit');
      await j.type('goal-workouts', '4');
      await j.type('goal-runwalk', '1');
      FocusManager.instance.primaryFocus?.unfocus();
      await watch(1000);
      await j.tapKey('goals-save');
      await j.waitFor(inRow('goal-row-workouts', '1 of 4'), what: 'the new goal on the phone');
      await j.waitFor(find.byKey(const Key('goals-pending')), what: 'saved on this phone, waiting');
      await watch(2000);
      debugPrint('GOHARD_REC:stop');
      await watch(5000);

      // --- Captures of the four views.
      await _surface.invokeMethod<void>('convertFlutterSurfaceToImage');
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
      await j.shot('progress-01-weekly');
      await j.tapKey('goals-edit');
      await j.waitFor(find.byKey(const Key('goals-save')));
      FocusManager.instance.primaryFocus?.unfocus();
      await j.shot('progress-02-goal-sheet');
      Navigator.of(tester.element(find.byKey(const Key('goals-save')))).pop();
      await j.settle(4);
      await j.tapKey('trend-preview-bench-press');
      await j.waitFor(find.byKey(const Key('trend-chart')));
      await j.shot('progress-03-exercise-trend');
      await back();
      await j.tapKey('progress-recap');
      await j.waitFor(find.byKey(const Key('recap-goal-workouts')));
      await j.shot('progress-04-weekly-recap');
      await back();
      return;
    }

    expect(_phase, '2', reason: 'run this journey through scripts\\test-android.ps1, which sets the phase');
    // A new process, still offline: only what the previous one saved on the phone.
    j.email = await account.readAsString();
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await j.waitFor(find.byKey(const Key('nav-train')), what: 'the app after the process ended', seconds: 40);
    await j.tapKey('nav-train');
    await j.tapKey('train-progress');
    await j.waitFor(inRow('goal-row-workouts', '1 of 4'), what: 'the goal saved offline, after a restart');
    expect(find.byKey(const Key('goals-pending')), findsOneWidget);

    debugPrint('GOHARD_NET:on');
    final token = await (() async {
      for (var i = 0; i < 60; i++) {
        await watch(1000);
        if (await j.apiReachable()) return j.apiToken();
      }
      fail('The API did not become reachable again.');
    })();
    await scope().read(syncProvider).flush();
    await j.waitUntil(() async => (await goalOn(token, thisMonday))?['workoutsTarget'] == 4, what: 'this week\'s goal on the account');
    final now = (await goalOn(token, thisMonday))!, last = (await goalOn(token, lastMonday))!;
    expect((now['workoutsTarget'], now['runWalkTarget'], now['revision']), (4, 1, 1), reason: 'sent once');
    expect((last['workoutsTarget'], last['runWalkTarget']), (3, 2), reason: 'last week\'s record is untouched');
    await j.waitUntil(() async => find.byKey(const Key('goals-pending')).evaluate().isEmpty, what: 'the pending line to go');
    await j.tapKey('progress-recap');
    await j.waitFor(find.byKey(const Key('recap-goal-workouts')));
    expect(inRow('recap-goal-workouts', '2 of 3'), findsOneWidget, reason: 'last week is still measured against its own goal');
    await j.shot('progress-05-recap-after-sync');
  });
}

