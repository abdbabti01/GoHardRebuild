import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/activity/activity_detail.dart';
import 'package:gohard_rebuild/features/activity/activity_history.dart';
import 'package:gohard_rebuild/features/activity/location_source.dart';
import 'package:gohard_rebuild/features/activity/recorder.dart';
import 'package:gohard_rebuild/features/activity/run_walk_screens.dart';
import 'package:gohard_rebuild/features/activity/track_math.dart';

import 'ui_support.dart';

/// Run / Walk screens over a fixed recorder state and SIMULATED location (no device GPS, no database).
const _day = '2026-10-09';

class _Rec extends Recorder {
  _Rec(this.view);
  final RecorderView view;
  final calls = <String>[];
  @override
  RecorderView build() => view;
  @override
  Future<void> adopt(Run run) async {}
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> finish() async => calls.add('finish');
}

/// A walk north at 1.4 m/s, one fix a second, for [seconds].
TrackAnalysis _walk(int seconds, {int start = 1760000000000}) {
  final a = TrackAnalysis()..add(TrackEntry(seq: 0, type: EntryType.start, segment: 0, t: start));
  for (var i = 1; i <= seconds; i++) {
    a.add(TrackEntry(seq: i, type: EntryType.fix, segment: 0, t: start + i * 1000, lat: 46.8 + i * 1.4 / 111320, lon: -71.2, acc: 5, speed: 1.4, alt: 50 + i * 0.02, altAcc: 3));
  }
  return a;
}

Json _run(String id, {String type = 'walk', bool open = false, Json? metrics, double? meters = 2400}) => {
      'id': id, 'dayKey': _day, 'startedAtUtc': '${_day}T11:20:00Z', 'finishedAtUtc': open ? null : '${_day}T11:52:00Z', 'activeDurationSeconds': open ? null : 1850,
      'distanceMeters': open ? null : meters, 'isDeleted': false, 'activityType': type, 'title': open ? null : 'Morning ${activityNoun(type)}', 'metrics': ?metrics,
    };

Future<List<Override>> _overrides(WidgetTester tester, {List<Json> runs = const [], RecorderView? view, _Rec? rec, LocationSource? gps}) async => [
      ...(await tester.runAsync(() => overridesFor(day: _day, runs: runs)))!,
      locationSourceProvider.overrideWithValue(gps ?? SimulatedLocationSource(const [(46.8, -71.2, 5.0, null)])),
      if (rec != null) recorderProvider.overrideWith(() => rec) else if (view != null) recorderProvider.overrideWith(() => _Rec(view)),
    ];

void main() {
  testWidgets('Ready: Run/Walk choice, the real GPS state, one Start, auto-pause off, and no recorded route', (tester) async {
    for (final (access, title) in [
      (GpsAccess.notAllowed, 'Location not allowed yet'),
      (GpsAccess.deniedForever, 'Location is blocked for GoHard'),
      (GpsAccess.servicesOff, 'Location is off'),
      (GpsAccess.approximate, 'Precise location is off'),
    ]) {
      await pumpApp(tester, await _overrides(tester, gps: SimulatedLocationSource(const [(46.8, -71.2, 5.0, null)], accessState: access)), home: const RunWalkScreen());
      expect(find.text(title), findsOneWidget, reason: '$access');
      await tester.pumpWidget(const SizedBox());
    }
    await pumpApp(tester, await _overrides(tester), home: const RunWalkScreen(), settle: false);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Run / Walk'), findsOneWidget);
    expect(find.text('GPS ready · ±5 m'), findsOneWidget, reason: 'the real accuracy, never a fixed "ready"');
    expect(find.text('Start run'), findsOneWidget);
    expect(find.byKey(const Key('map-fit')), findsNothing, reason: 'no route before recording, so nothing to fit');
    expect(find.text('Simulated GPS (test build)'), findsOneWidget, reason: 'simulated location is labelled');
    // The page scrolls from anywhere but the map, which keeps its own gestures; Start stays in its bar.
    await tester.dragUntilVisible(find.byKey(const Key('runwalk-steps-row')), find.byKey(const Key('runwalk-gps')), const Offset(0, -200));
    for (final (row, state) in [('runwalk-intervals', 'Off'), ('runwalk-voice', 'Off'), ('runwalk-autopause', 'Off')]) {
      expect(find.descendant(of: find.byKey(Key(row)), matching: find.text(state)), findsOneWidget,
          reason: '$row: intervals optional (one tap still starts a free run), voice only once turned on, auto-pause off');
    }
    expect(find.text('Steps off'), findsOneWidget);
    await tester.dragUntilVisible(find.byKey(const Key('activity-type-walk')), find.byKey(const Key('runwalk-gps')), const Offset(0, 200));
    await tester.tap(find.byKey(const Key('activity-type-walk')));
    await tester.pump();
    expect(find.text('Start walk'), findsOneWidget, reason: 'the same screen, with the walk words');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Recording: Stats and Map views and camera choices never touch the recording', (tester) async {
    final rec = _Rec(RecorderView(state: RecState.recording, run: Run(_run('r1', open: true)), analysis: _walk(600), gpsOn: true,
        last: Reading(lat: 46.8 + 840 / 111320, lon: -71.2, acc: 5, at: DateTime.utc(2026))));
    await pumpApp(tester, await _overrides(tester, rec: rec), home: const RunWalkScreen(), settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Walk'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Active time')), findsOneWidget, reason: 'the dial says what it measures');
    expect(find.text('Avg. moving pace'), findsOneWidget);
    expect(find.text('GPS · ±5 m'), findsOneWidget);
    expect(find.byKey(const Key('map-zoom-in')), findsNothing, reason: 'the preview stays uncluttered');
    expect(find.byKey(const Key('map-expand')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('map-expand')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-expand')));
    await tester.pump();
    expect(find.byKey(const Key('runwalk-map-full')), findsOneWidget);
    expect(find.byKey(const Key('runwalk-compact-stats')), findsOneWidget, reason: 'statistics stay in view');
    expect(find.bySemanticsLabel('Following your position'), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-zoom-in')));
    await tester.pump();
    expect(find.bySemanticsLabel('Recenter'), findsOneWidget, reason: 'a manual zoom leaves follow mode');
    await tester.tap(find.byKey(const Key('map-recenter')));
    await tester.pump();
    expect(find.bySemanticsLabel('Following your position'), findsOneWidget);
    expect(find.byKey(const Key('map-fit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('runwalk-view-false')));
    await tester.pump();
    expect(rec.calls, isEmpty, reason: 'switching views, zooming and recentering never pause, resume or finish');
    expect(find.byKey(const Key('runwalk-pause')), findsOneWidget);
    await tester.tap(find.byKey(const Key('runwalk-pause')));
    await tester.pump();
    expect(rec.calls, ['pause']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Paused and Interrupted say so and offer Resume and Finish', (tester) async {
    await pumpApp(tester, await _overrides(tester, view: RecorderView(state: RecState.paused, run: Run(_run('r1', type: 'run', open: true)), analysis: _walk(60))),
        home: const RunWalkScreen(), settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byKey(const Key('runwalk-resume')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await pumpApp(tester, await _overrides(tester, view: RecorderView(state: RecState.interrupted, run: Run(_run('r1', open: true)), analysis: _walk(60)..add(const TrackEntry(seq: 99, type: EntryType.interrupt, segment: 0, t: 1760000070000)))),
        home: const RunWalkScreen(), settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Interrupted'), findsOneWidget);
    expect(find.textContaining('Recording stopped when GoHard was closed'), findsOneWidget);
    expect(find.byKey(const Key('runwalk-resume')), findsOneWidget);
    expect(find.byKey(const Key('runwalk-finish')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Saved details: route, splits with a labelled partial, charts from measured data; a legacy run says Route not recorded', (tester) async {
    final metrics = {'elapsedSeconds': 1900, 'movingSeconds': 1800, 'gpsDistanceMeters': 2400.0, 'distanceSource': 'gps', 'routeState': 'recorded', 'pointCount': 600, 'rejectedCount': 0, 'gaps': 0, 'interrupted': 0};
    final a = _walk(1800);
    await pumpApp(tester, [
      ...await _overrides(tester, runs: [_run('r1', metrics: metrics)]),
      routeAnalysisProvider.overrideWith((ref, id) async => a),
    ], home: const ActivityDetailScreen(runId: 'r1'));
    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.textContaining('· Walk'), findsOneWidget);
    expect(find.byKey(const Key('activity-map')), findsOneWidget);
    expect(find.text('Moving time'), findsOneWidget);
    expect(find.textContaining('Elevation gain'), findsOneWidget);
    await tester.dragUntilVisible(find.byKey(const Key('activity-tab-splits')), find.byKey(const Key('activity-distance')), const Offset(0, -150));
    await tester.tap(find.byKey(const Key('activity-tab-splits')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Partial split'), find.byKey(const Key('activity-tab-splits')), const Offset(0, -150));
    expect(find.byKey(const Key('split-1')), findsOneWidget);
    expect(find.text('Partial split'), findsOneWidget, reason: 'the last part is labelled, not passed off as a whole km');
    await tester.tap(find.byKey(const Key('split-1')));
    await tester.pumpAndSettle();
    expect(find.text('Shown on the map'), findsOneWidget);
    await tester.dragUntilVisible(find.byKey(const Key('activity-tab-charts')), find.byKey(const Key('split-1')), const Offset(0, 150));
    await tester.tap(find.byKey(const Key('activity-tab-charts')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.byKey(const Key('chart-elevation')), find.byKey(const Key('activity-tab-charts')), const Offset(0, -150));
    expect(find.byKey(const Key('chart-pace')), findsOneWidget);
    expect(find.byKey(const Key('chart-elevation')), findsOneWidget);

    await pumpApp(tester, [
      ...await _overrides(tester, runs: [{'id': 'old', 'dayKey': _day, 'startedAtUtc': '${_day}T07:00:00Z', 'finishedAtUtc': '${_day}T07:30:00Z', 'activeDurationSeconds': 1800, 'distanceMeters': 5000, 'isDeleted': false}]),
      routeAnalysisProvider.overrideWith((ref, id) async => TrackAnalysis()),
    ], home: const ActivityDetailScreen(runId: 'old'));
    expect(find.text('Route not recorded'), findsOneWidget);
    expect(find.textContaining('Recorded before GoHard kept routes'), findsOneWidget);
    expect(find.text('5.00 km', findRichText: true), findsOneWidget, reason: 'its real distance is kept');
    expect(find.text('Avg. moving pace'), findsNothing, reason: 'no moving time was recorded, so no pace is made up');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1)); // lets the dropped providers finish disposing
  });

  testWidgets('History: All / Run / Walk, totals from saved activities, legacy rows say Route not recorded', (tester) async {
    await pumpApp(tester, [
      ...await _overrides(tester, runs: [
        _run('w1', metrics: {'movingSeconds': 1800}),
        _run('r1', type: 'run', meters: 5000, metrics: {'movingSeconds': 1500}),
        {'id': 'old', 'dayKey': '2026-10-01', 'startedAtUtc': '2026-10-01T07:00:00Z', 'finishedAtUtc': '2026-10-01T07:30:00Z', 'activeDurationSeconds': 1800, 'distanceMeters': 3000, 'isDeleted': false},
      ]),
      routeThumbProvider.overrideWith((ref, id) async => const []),
    ], home: const ActivityHistoryScreen());
    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.text('Morning run'), findsOneWidget);
    expect(find.textContaining('Route not recorded'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('history-month')), matching: find.text('10.40 km')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('history-week')), matching: find.text('7.40 km')), findsOneWidget);
    await tester.tap(find.byKey(const Key('history-filter-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.text('Morning run'), findsNothing);
  });
}
