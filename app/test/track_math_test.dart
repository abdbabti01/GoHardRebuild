import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gohard_rebuild/features/activity/track_math.dart';

/// GPS fixtures for the metric pipeline (docs/RUN_WALK.md › Metrics). They are SYNTHETIC: seeded tracks with
/// accuracy-scaled noise at 1 Hz, built to reproduce the patterns real phones record (drift while standing, slow
/// walking, poor fixes, jumps, gaps). No real recorded track exists in this repository yet.
const _lat0 = 46.8065, _lon0 = -71.2140;
const _mPerDegLat = 111320.0;
double get _mPerDegLon => _mPerDegLat * cos(_lat0 * pi / 180);

class _Fixture {
  _Fixture(int seed) : _r = Random(seed);
  final Random _r;
  final entries = <TrackEntry>[];
  int seq = 0, seg = 0, t = 1760700000000;
  double x = 0, y = 0; // metres east/north of the origin

  double _gauss() {
    final u = max(1e-9, _r.nextDouble()), v = _r.nextDouble();
    return sqrt(-2 * log(u)) * cos(2 * pi * v); // Box-Muller
  }

  // A phone's fused position error wanders rather than jumping independently every second: AR(1) noise with a
  // stationary standard deviation of [sd] per axis, plus a small independent part.
  double _ex = 0, _ey = 0;
  static const _phi = 0.9;
  (double, double) _noise(double sd) {
    final k = sd * sqrt(1 - _phi * _phi);
    _ex = _phi * _ex + k * _gauss();
    _ey = _phi * _ey + k * _gauss();
    return (_ex + 0.3 * sd * _gauss(), _ey + 0.3 * sd * _gauss());
  }

  void event(EntryType type, {Map<String, dynamic>? meta}) {
    if (type == EntryType.resume || type == EntryType.autoresume) seg++;
    entries.add(TrackEntry(seq: seq++, type: type, segment: seg, t: t, meta: meta));
  }

  /// Reported (Doppler) speed: true speed with ±0.15 m/s noise; null models a device that reports none.
  bool reportSpeed = true;

  void fix({double acc = 5, double? alt, double? altAcc, double noise = -1, int? at, double speed = 0}) {
    final (nx, ny) = _noise(noise < 0 ? acc / 2 : noise);
    entries.add(TrackEntry(seq: seq++, type: EntryType.fix, segment: seg, t: at ?? t, acc: acc, alt: alt, altAcc: altAcc,
        speed: reportSpeed ? max(0, speed + 0.15 * _gauss()) : null,
        lat: _lat0 + (y + ny) / _mPerDegLat, lon: _lon0 + (x + nx) / _mPerDegLon));
  }

  /// Moves east at [speed] m/s for [seconds], one fix per second.
  void move(double speed, int seconds, {double acc = 5, double Function(int i)? alt, bool fixes = true}) {
    for (var i = 0; i < seconds; i++) {
      t += 1000;
      x += speed;
      if (fixes) fix(acc: acc, alt: alt?.call(i), altAcc: alt == null ? null : 3, speed: speed);
    }
  }

  TrackAnalysis get analysis => TrackAnalysis.of(entries);
}

void main() {
  test('a steady 3.2 km run: distance, whole splits and a labelled partial split', () {
    final f = _Fixture(1)..event(EntryType.start);
    f.move(3.0, 1067); // 3.2 km at 5:33 /km
    f.event(EntryType.finish);
    final a = f.analysis;
    expect(a.distance, closeTo(3200, 3200 * 0.03));
    final splits = a.splits(1000);
    expect(splits.where((s) => !s.partial), hasLength(3));
    expect(splits.last.partial, isTrue);
    expect(splits.last.distanceMeters, closeTo(200, 100));
    for (final s in splits.where((s) => !s.partial)) {
      expect(s.paceFor(1000), closeTo(333, 333 * 0.06));
    }
    expect(a.avgMovingPace(1000), closeTo(333, 333 * 0.05));
    expect(a.moving, closeTo(1067, 1067 * 0.05));
  });

  test('standing still with GPS drift adds almost nothing', () {
    final f = _Fixture(2)..event(EntryType.start);
    f.move(0, 600, acc: 6);
    final a = f.analysis;
    expect(a.distance, lessThan(15), reason: 'ten minutes of drift');
    expect(a.moving, lessThan(30));
    expect(a.avgMovingPace(1000), isNull, reason: 'too little to state a pace');
  });

  test('standing still on a device that reports no speed: drift stays bounded by the accuracy threshold', () {
    final f = _Fixture(16)
      ..reportSpeed = false
      ..event(EntryType.start);
    f.move(0, 600, acc: 6);
    // ponytail: without a reported speed only the accuracy threshold guards drift; auto-pause or a pause is the
    // remedy for long stops on such devices. Bound measured on this fixture, not a guarantee.
    expect(f.analysis.distance, lessThan(120));
  });

  test('slow walking at 0.8 m/s is still measured in full', () {
    final f = _Fixture(3)..event(EntryType.start);
    f.move(0.8, 600, acc: 5);
    final a = f.analysis;
    expect(a.distance, closeTo(480, 480 * 0.10));
    expect(a.moving, greaterThan(500), reason: 'slow walking is moving time');
  });

  test('vague, duplicate, out-of-order and impossible fixes are rejected and change nothing', () {
    final f = _Fixture(4)..event(EntryType.start);
    f.move(3, 60);
    final clean = TrackAnalysis.of(f.entries).distance;
    final last = f.entries.last;
    f.fix(acc: 80); // too vague
    f.entries.add(TrackEntry(seq: f.seq++, type: EntryType.fix, segment: 0, t: last.t, lat: last.lat, lon: last.lon, acc: 5)); // duplicate time
    f.entries.add(TrackEntry(seq: f.seq++, type: EntryType.fix, segment: 0, t: last.t - 5000, lat: last.lat, lon: last.lon, acc: 5)); // out of order
    f.t += 1000;
    f.entries.add(TrackEntry(seq: f.seq++, type: EntryType.fix, segment: 0, t: f.t, lat: last.lat! + 0.02, lon: last.lon, acc: 5)); // 2 km in 1 s
    final a = f.analysis;
    expect(a.rejected, 4);
    expect(a.distance, closeTo(clean, 0.001));
  });

  test('a wrong first fix is dropped once the following fixes agree with each other', () {
    final f = _Fixture(5)..event(EntryType.start);
    f.y = 600;
    f.fix(); // 600 m off
    f.y = 0;
    f.move(3, 120);
    final a = f.analysis;
    expect(a.distance, closeTo(360, 360 * 0.08), reason: 'the outlier is never joined to the route');
  });

  test('a gap in fixes adds no straight line and breaks the route and charts', () {
    final f = _Fixture(6)..event(EntryType.start);
    f.move(3, 300);
    f.move(3, 60, fixes: false); // 180 m with no readings
    f.move(3, 300);
    final a = f.analysis;
    expect(a.gaps, 1);
    expect(a.distance, closeTo(1800, 1800 * 0.04), reason: 'the 180 m without readings is left out');
    expect(a.segments, hasLength(2));
    expect(a.paceProfile(100, 1000), hasLength(2));
  });

  test('pause and resume: active time excludes the pause, elapsed includes it, paused movement is not counted', () {
    final f = _Fixture(7)..event(EntryType.start);
    f.move(3, 300);
    f.event(EntryType.pause);
    f.move(3, 120); // walking around while paused, fixes keep arriving
    f.event(EntryType.resume);
    f.move(3, 300);
    f.event(EntryType.finish);
    final a = f.analysis;
    expect(a.activeMs(f.t), 600000);
    expect(a.elapsedMs(f.t), 720000);
    expect(a.whilePaused, 120);
    expect(a.distance, closeTo(1800, 1800 * 0.04));
    expect(a.segments, hasLength(2));
  });

  test('miles: splits per mile and pace per mile', () {
    final f = _Fixture(8)..event(EntryType.start);
    f.move(3.0, 1200);
    final a = f.analysis;
    final splits = a.splits(1609.344);
    expect(splits.first.partial, isFalse);
    expect(splits.last.partial, isTrue);
    expect(splits.first.paceFor(1609.344), closeTo(536, 536 * 0.06));
  });

  test('elevation: gain from smoothed altitude, unknown without usable altitude', () {
    final f = _Fixture(9)..event(EntryType.start);
    final r = Random(99);
    f.move(2.5, 400, alt: (i) => 50 + i * 0.075 + (r.nextDouble() - 0.5) * 2); // +30 m with ±1 m noise
    final a = f.analysis;
    final gl = a.elevationGainLoss()!;
    expect(gl.$1, closeTo(30, 5));
    expect(gl.$2, lessThan(4));

    final flat = _Fixture(10)..event(EntryType.start);
    flat.move(2.5, 400);
    expect(flat.analysis.elevationGainLoss(), isNull, reason: 'no altitude is unknown, never 0 m');
  });

  test('a short activity without fixes has unknown distance and no pace', () {
    final f = _Fixture(11)..event(EntryType.start);
    f.t += 10000;
    f.event(EntryType.finish);
    final a = f.analysis;
    expect(a.measured, isFalse);
    expect(a.avgMovingPace(1000), isNull);
    expect(a.activeMs(f.t), 10000);
  });

  test('interruption and legacy: earlier measured time and distance are kept, nothing is joined across', () {
    final f = _Fixture(12);
    f.event(EntryType.legacy, meta: {'distanceMeters': 1234.5, 'activeMs': 600000, 'startedAtMs': f.t - 900000});
    f.event(EntryType.resume);
    f.move(3, 100);
    f.event(EntryType.interrupt);
    f.t += 300000;
    f.event(EntryType.resume);
    f.move(3, 100);
    final a = f.analysis;
    expect(a.legacyDistance, 1234.5);
    expect(a.activeMs(f.t), 600000 + 200000);
    expect(a.interruptions, 1);
    expect(a.segments, hasLength(2));
  });

  test('replaying a prefix and then the rest gives the same numbers as one pass (restart recovery)', () {
    final f = _Fixture(13)..event(EntryType.start);
    f.move(2.8, 500);
    final whole = f.analysis;
    final split = TrackAnalysis();
    for (final e in f.entries.take(200)) {
      split.add(e);
    }
    for (final e in f.entries.skip(200)) {
      split.add(e);
    }
    expect(split.distance, whole.distance);
    expect(split.moving, whole.moving);
  });

  test('auto-pause: pauses after 12 s still, drift does not resume it, walking away does', () {
    final f = _Fixture(14)..event(EntryType.start);
    f.move(1.2, 60);
    f.move(0, 20, acc: 5);
    final a = f.analysis;
    final at = AutoPauseRule.pauseAt(a, f.t);
    expect(at, isNotNull);
    expect(f.t - at!, greaterThanOrEqualTo(12000));

    final from = a.lastAccepted!;
    int? candidate;
    var resumed = false;
    for (var i = 0; i < 120; i++) {
      f.t += 1000;
      f.fix(acc: 5);
      final c = AutoPauseRule.check(from, f.entries.last, candidate);
      candidate = c.candidate;
      resumed |= c.resume;
    }
    expect(resumed, isFalse, reason: 'two minutes of stationary drift');
    for (var i = 0; i < 20 && !resumed; i++) {
      f.t += 1000;
      f.x += 1.2;
      f.fix(acc: 5);
      final c = AutoPauseRule.check(from, f.entries.last, candidate);
      candidate = c.candidate;
      resumed |= c.resume;
    }
    expect(resumed, isTrue, reason: 'slow walking away resumes it');
  });

  test('the live line ends at the newest accepted fix, never beyond', () {
    final f = _Fixture(15)..event(EntryType.start);
    f.move(1, 30);
    final a = f.analysis;
    final end = a.segments.last.last;
    expect(end.t, a.lastAccepted!.t);
  });

  test('entries survive the compact wire shape unchanged', () {
    const e = TrackEntry(seq: 3, type: EntryType.fix, segment: 1, t: 5, lat: 1.5, lon: -2.25, acc: 4, alt: 10, altAcc: 2);
    expect(TrackEntry.fromJson(e.toJson()).toJson(), e.toJson());
  });
}
