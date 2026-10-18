import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/core/units.dart';
import 'package:gohard_rebuild/data/models.dart';
import 'package:gohard_rebuild/features/activity/announcer.dart';
import 'package:gohard_rebuild/features/activity/intervals.dart';
import 'package:gohard_rebuild/features/activity/move_prefs.dart';
import 'package:gohard_rebuild/features/activity/records.dart';
import 'package:gohard_rebuild/features/activity/steps.dart';
import 'package:gohard_rebuild/features/activity/track_math.dart';

/// Steps, intervals, cues and personal bests (docs/RUN_WALK.md › Steps, › Intervals, › Voice and alerts,
/// › Personal bests): the pure rules the recorder and screens use. Step readings and GPS tracks here are SYNTHETIC.
const _t0 = 1760700000000;
const _lat0 = 46.8065, _lon0 = -71.2140, _mPerDegLat = 111320.0;

/// A straight track east: one accepted fix per second at [speed] m/s. [events] are (second, type) recording events.
List<TrackEntry> _track(List<double> speeds, {Map<int, EntryType> events = const {}, int gapAt = -1}) {
  final out = <TrackEntry>[];
  var seq = 0, seg = 0, x = 0.0, t = _t0;
  final mPerDegLon = _mPerDegLat * cos(_lat0 * pi / 180);
  out.add(TrackEntry(seq: seq++, type: EntryType.start, segment: 0, t: t));
  for (var i = 0; i < speeds.length; i++) {
    t += i == gapAt ? 60000 : 1000;
    final e = events[i];
    if (e != null) {
      if (e == EntryType.resume) seg++;
      out.add(TrackEntry(seq: seq++, type: e, segment: seg, t: t));
    }
    x += speeds[i];
    out.add(TrackEntry(seq: seq++, type: EntryType.fix, segment: seg, t: t, acc: 4, speed: speeds[i], lat: _lat0, lon: _lon0 + x / mPerDegLon));
  }
  out.add(TrackEntry(seq: seq++, type: EntryType.finish, segment: seg, t: t + 1000));
  return out;
}

Run _run(String id, String type, {required String day, Map<String, dynamic>? metrics, String source = 'gps', bool deleted = false}) => Run({
      'id': id, 'dayKey': day, 'startedAtUtc': '${day}T08:00:00.000Z', 'finishedAtUtc': '${day}T09:00:00.000Z', 'activityType': type, 'isDeleted': deleted,
      'distanceMeters': (metrics?['gpsDistanceMeters'] as num?)?.toDouble(),
      'metrics': {'distanceSource': source, ...?metrics},
    });

void main() {
  group('intervals', () {
    const plan = IntervalPlan(warmup: 60, run: 30, walk: 20, reps: 3, cooldown: 40);

    test('phases, total programmed time and the position from the active clock', () {
      expect(plan.phases.map((p) => p.label), ['Warm-up', 'Run', 'Walk', 'Run', 'Walk', 'Run', 'Walk', 'Cool-down']);
      expect(plan.totalSeconds, 60 + 3 * 50 + 40);
      expect(IntervalClock.at(plan, const [], 0).phase!.kind, PhaseKind.warmup);
      final p = IntervalClock.at(plan, const [], 75000);
      expect((p.phase!.kind, p.phase!.round, p.remainingMs), (PhaseKind.run, 1, 15000));
      expect(IntervalClock.at(plan, const [], 60000 + 2 * 50000 + 1000).isLastRound, isTrue);
      expect(IntervalClock.at(plan, const [], 250000).done, isTrue);
    });

    test('a skip ends only the phase it falls in; later phases keep their full length', () {
      final p = IntervalClock.at(plan, const [10000], 10000);
      expect((p.phase!.kind, p.remainingMs), (PhaseKind.run, 30000));
      final tl = IntervalClock.timeline(plan, const [10000], 45000);
      expect(tl.first.skipped, isTrue);
      expect(tl.first.seconds, 10);
      expect(tl[1].seconds, 30);
    });

    test('pause freezes the phase: the position depends on active time only', () {
      final a = TrackAnalysis.of(_track(List.filled(40, 3.0), events: {10: EntryType.pause, 30: EntryType.resume}));
      // 40 s of wall time, 20 s of it paused: 20-ish active seconds, still in the warm-up.
      final active = a.activeMs(_t0 + 41000);
      expect(active, lessThan(25000));
      expect(IntervalClock.at(plan, const [], active).phase!.kind, PhaseKind.warmup);
    });

    test('a damaged saved setup is ignored, never turned into a strange session', () {
      expect(IntervalPlan.fromJson({'run': 5, 'walk': 60, 'reps': 3}), isNull);
      expect(IntervalPlan.fromJson({'run': 60, 'walk': 60, 'reps': 0}), isNull);
      expect(IntervalPlan.fromJson(IntervalPlan.preset.toJson()), IntervalPlan.preset);
    });
  });

  group('steps', () {
    // Recording from 0 to 60 s, paused 60–120 s, recording 120–180 s.
    final a = TrackAnalysis()
      ..add(const TrackEntry(seq: 0, type: EntryType.start, segment: 0, t: _t0))
      ..add(const TrackEntry(seq: 1, type: EntryType.pause, segment: 0, t: _t0 + 60000))
      ..add(const TrackEntry(seq: 2, type: EntryType.resume, segment: 1, t: _t0 + 120000))
      ..add(const TrackEntry(seq: 3, type: EntryType.finish, segment: 1, t: _t0 + 180000));

    StepTally feed(List<(int, int)> readings) {
      final s = StepTally();
      for (final (c, sec) in readings) {
        s.add((count: c, t: _t0 + sec * 1000), a.recordingShare);
      }
      return s;
    }

    test('only recorded time counts; steps while paused are left out', () {
      final s = feed([(1000, 0), (1050, 30), (1100, 58), (1102, 62), (1180, 90), (1200, 118), (1204, 122), (1260, 150), (1300, 170)]);
      // 0→58 s: 100; 58→62 s: half of 2; while paused: none; 118→122 s: half of 4; 122→170 s: 96.
      expect(s.steps, 100 + 1 + 2 + 96);
      expect(s.partial, isFalse);
    });

    test('standing still across Pause (a long stretch with a step or two) is left out without calling it partial', () {
      final s = feed([(1000, 0), (1100, 30), (1104, 150)]);
      expect((s.steps, s.partial), (100, false));
    });

    test('a short batch across the pause is split by time; a long one is left out and marked partial', () {
      expect(feed([(1000, 0), (1100, 55), (1120, 65)]).steps, 100 + 10); // half of the 10 s batch was recorded
      final long = feed([(1000, 0), (1100, 30), (1400, 150)]);
      expect(long.steps, 100);
      expect(long.partial, isTrue);
    });

    test('delayed readings, duplicates and a counter reset never produce duplicate or negative counts', () {
      final s = feed([(5000, 0), (5040, 20), (5040, 20), (5030, 25), (12, 40), (52, 50)]);
      expect(s.steps, 40 + 40);
      expect(s.steps, greaterThanOrEqualTo(0));
      expect(s.partial, isTrue); // the reset lost the steps between 25 s and 40 s
    });

    test('measured zero, not recorded and unknown read differently', () {
      expect(stepsText({'stepsState': 'measured', 'steps': 0}), '0');
      expect(stepsText({'stepsState': 'denied'}), 'Not counted: motion access is off');
      expect(stepsText(const {}), 'Not recorded'); // an activity from before steps
      expect(stepsText({'stepsState': 'partial', 'steps': 1234}), '1,234 (part of the time)');
    });

    test('a checkpoint restores the count; after a restart the next reading is a new baseline', () {
      final s = feed([(1000, 0), (1100, 30)]);
      final back = StepTally.fromJson(s.toJson())..rebase();
      back.add((count: 99999, t: _t0 + 150000), a.recordingShare); // the phone restarted meanwhile: a baseline
      back.add((count: 100050, t: _t0 + 160000), a.recordingShare);
      expect(back.steps, 100 + 51);
    });
  });

  group('cues', () {
    const plan = IntervalPlan(run: 60, walk: 30, reps: 2);
    CueStep at(CueMarks m, int activeS, {double? dist, MovePrefs prefs = const MovePrefs(), DistanceUnit unit = DistanceUnit.km}) => recordingCues(
        marks: m, activityId: 'a', plan: plan, skips: const [], activeMs: activeS * 1000, distanceMeters: dist, paceSecondsPerUnit: 360, unit: unit, prefs: prefs);

    test('the first look only notes where the recording is: nothing due earlier is said (no replay on resume)', () {
      final m = CueMarks();
      expect(at(m, 75, dist: 2100).cue, isNull);
      expect(at(m, 76, dist: 2150).cue, isNull);
      expect(at(m, 90, dist: 2200).cue!.text, 'Final round. Run for 1 minute.');
    });

    test('a phase change and a distance update due together are one message, the phase first', () {
      final m = CueMarks();
      at(m, 50, dist: 990);
      final c = at(m, 60, dist: 1001).cue!;
      expect(c.text, 'Walk and recover for 30 seconds. 1 km completed.');
      // A fractional distance keeps its decimal point in the merged message.
      final half = CueMarks();
      at(half, 50, dist: 400, prefs: const MovePrefs(everyDistance: 0.5));
      expect(at(half, 60, dist: 520, prefs: const MovePrefs(everyDistance: 0.5)).cue!.text, 'Walk and recover for 30 seconds. 0.5 km completed.');
      expect(c.priority, Cue.phase);
      expect(c.vibrate, isTrue);
    });

    test('units: miles are announced in miles; a missing pace is never spoken as a number', () {
      final m = CueMarks();
      recordingCues(marks: m, activityId: 'a', plan: null, skips: const [], activeMs: 0, distanceMeters: 0, paceSecondsPerUnit: null, unit: DistanceUnit.mi, prefs: const MovePrefs());
      final c = recordingCues(marks: m, activityId: 'a', plan: null, skips: const [], activeMs: 600000, distanceMeters: 1610, paceSecondsPerUnit: null, unit: DistanceUnit.mi, prefs: const MovePrefs()).cue!;
      expect(c.text, '1 mi completed. Active time 10:00.');
      expect(c.spoken, '1 mile. Active time 10 minutes.');
      expect(c.spoken, isNot(contains('pace')));
    });

    test('time-based updates say which pace they mean; updates off keeps the marks current', () {
      final m = CueMarks();
      const prefs = MovePrefs(updates: UpdateMode.time, everyMinutes: 5);
      recordingCues(marks: m, activityId: 'b', plan: null, skips: const [], activeMs: 0, distanceMeters: null, paceSecondsPerUnit: null, unit: DistanceUnit.km, prefs: prefs);
      final c = recordingCues(marks: m, activityId: 'b', plan: null, skips: const [], activeMs: 300000, distanceMeters: 900, paceSecondsPerUnit: 333, unit: DistanceUnit.km, prefs: prefs).cue!;
      expect(c.text, '5 min active. 0.90 km. Avg. moving pace 5:33 /km.');
      final off = CueMarks();
      const none = MovePrefs(updates: UpdateMode.off);
      recordingCues(marks: off, activityId: 'c', plan: null, skips: const [], activeMs: 0, distanceMeters: 0, paceSecondsPerUnit: null, unit: DistanceUnit.km, prefs: none);
      expect(recordingCues(marks: off, activityId: 'c', plan: null, skips: const [], activeMs: 0, distanceMeters: 3000, paceSecondsPerUnit: null, unit: DistanceUnit.km, prefs: none).cue, isNull);
      // Turning updates on afterwards announces the next kilometre, not the three already passed.
      final next = recordingCues(marks: off, activityId: 'c', plan: null, skips: const [], activeMs: 0, distanceMeters: 4000, paceSecondsPerUnit: null, unit: DistanceUnit.km, prefs: const MovePrefs()).cue!;
      expect(next.text, startsWith('4 km'));
    });

    test('a countdown ticks once per second for the last three seconds, and the end of the plan is said once', () {
      final m = CueMarks();
      at(m, 55);
      final ticks = [for (final s in [56, 57, 57, 58, 59]) at(m, s).tick];
      expect(ticks, [false, true, false, true, true]);
      final done = [at(m, 180).cue?.text, at(m, 181).cue?.text];
      expect(done.first, startsWith('Intervals finished.'));
      expect(done.last, isNull);
    });
  });

  group('personal bests', () {
    test('the fastest 1 km is the fastest stretch, not the average of the whole activity', () {
      // 600 m at 2.5 m/s, then 1,200 m at 4 m/s.
      final a = TrackAnalysis.of(_track([...List.filled(240, 2.5), ...List.filled(300, 4.0)]));
      final e = bestEfforts(a);
      expect(e['1000'], closeTo(250, 3)); // 1 km at 4 m/s
      expect(e.containsKey('5000'), isFalse);
      final whole = a.distance / 1000;
      expect(e['1000']!, lessThan(a.moving / whole));
    });

    test('a stretch never crosses a pause or a GPS gap', () {
      final paused = TrackAnalysis.of(_track(List.filled(400, 4.0), events: {200: EntryType.pause, 201: EntryType.resume}));
      expect(bestEfforts(paused).containsKey('1000'), isFalse); // 800 m either side
      final gap = TrackAnalysis.of(_track(List.filled(400, 4.0), gapAt: 200));
      expect(bestEfforts(gap).containsKey('1000'), isFalse);
    });

    Map<String, dynamic> m(double meters, double? k1) => {'gpsDistanceMeters': meters, 'efforts': {'1000': ?k1}};

    test('run and walk records are separate; typed, corrected and older activities never count', () {
      final runs = [
        _run('r1', 'run', day: '2026-10-01', metrics: m(5200, 300)),
        _run('w1', 'walk', day: '2026-10-02', metrics: m(8000, 560)),
        _run('r2', 'run', day: '2026-10-03', metrics: m(9000, 330)),
        _run('r3', 'run', day: '2026-10-04', metrics: m(20000, 200), source: 'manual'),
        _run('r4', 'run', day: '2026-10-05', metrics: m(30000, 100), source: 'corrected'),
        _run('r5', 'run', day: '2026-10-06', metrics: {'gpsDistanceMeters': 40000}), // before personal bests: no efforts
      ];
      final b = personalBests(runs);
      expect(b.by['run.longest']!.run.id, 'r5'); // its GPS distance was measured, so longest still applies
      expect(b.by['run.1k']!.run.id, 'r1');
      expect(b.by['walk.longest']!.run.id, 'w1');
      expect(b.by['walk.1k']!.value, 560);
      expect(b.unchecked['run'], 3);
    });

    test('a deletion or a type change is reflected at once; ties go to the earlier activity', () {
      final r1 = _run('r1', 'run', day: '2026-10-01', metrics: m(5000, 300));
      final r2 = _run('r2', 'run', day: '2026-10-02', metrics: m(5000, 300));
      expect(personalBests([r1, r2]).by['run.1k']!.run.id, 'r1');
      final deleted = _run('r1', 'run', day: '2026-10-01', metrics: m(5000, 300), deleted: true);
      expect(personalBests([deleted, r2]).by['run.1k']!.run.id, 'r2');
      final retyped = _run('r1', 'walk', day: '2026-10-01', metrics: m(5000, 300));
      final b = personalBests([retyped, r2]);
      expect((b.by['run.1k']!.run.id, b.by['walk.1k']!.run.id), ('r2', 'r1'));
    });

    test('a new record is named once against the others; a first activity of its type sets none', () {
      final first = _run('w1', 'walk', day: '2026-10-01', metrics: m(3000, 600));
      expect(newRecords(first, [first]), isEmpty);
      final second = _run('w2', 'walk', day: '2026-10-02', metrics: m(4000, 620));
      final recs = newRecords(second, [first, second]);
      expect(recs.map((r) => r.benchmark.id), ['walk.longest']);
      expect(recordMessage(recs, DistanceUnit.km.distance), 'Your longest walk so far, 4.00 km.');
      // Saved and synced again: nothing beats itself.
      expect(newRecords(second, [first, second, second]).length, 1);
    });
  });
}
