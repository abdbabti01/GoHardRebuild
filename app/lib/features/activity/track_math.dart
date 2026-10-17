/// The one Run / Walk metric pipeline (docs/RUN_WALK.md › Metrics). A pure fold over the stored entries in `seq`
/// order: live display, save review, details, history, GPX and tests all use it, so a number is the same wherever it
/// is shown and can be reproduced from the stored route. Canonical units: metres, seconds, UTC epoch milliseconds.
library;

import 'dart:math';

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final a = pow(sin(rad(lat2 - lat1) / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(rad(lon2 - lon1) / 2), 2);
  return 2 * r * asin(sqrt(min(1.0, a.toDouble())));
}

enum EntryType { fix, start, pause, resume, autopause, autoresume, interrupt, finish, legacy }

/// One stored route entry: a location fix or a recording event. `t` is UTC epoch milliseconds.
class TrackEntry {
  const TrackEntry({required this.seq, required this.type, required this.segment, required this.t,
      this.lat, this.lon, this.acc, this.alt, this.altAcc, this.speed, this.speedAcc, this.heading, this.meta});
  final int seq, segment, t;
  final EntryType type;
  final double? lat, lon, acc, alt, altAcc, speed, speedAcc, heading;

  /// Event details: `legacy` carries {distanceMeters, activeMs, startedAtMs}; `interrupt` carries {reason}.
  final Map<String, dynamic>? meta;

  /// The compact wire/storage shape used in route chunks.
  Map<String, dynamic> toJson() => {
        's': seq, 'y': type.name, 'g': segment, 't': t,
        if (lat != null) 'la': lat, if (lon != null) 'lo': lon, if (acc != null) 'a': acc,
        if (alt != null) 'al': alt, if (altAcc != null) 'aa': altAcc, if (speed != null) 'sp': speed,
        if (speedAcc != null) 'sa': speedAcc, if (heading != null) 'h': heading, if (meta != null) 'm': meta,
      };

  static double? _d(Object? v) => (v as num?)?.toDouble();
  factory TrackEntry.fromJson(Map<String, dynamic> j) => TrackEntry(
        seq: j['s'] as int, type: EntryType.values.byName(j['y'] as String), segment: j['g'] as int, t: j['t'] as int,
        lat: _d(j['la']), lon: _d(j['lo']), acc: _d(j['a']), alt: _d(j['al']), altAcc: _d(j['aa']),
        speed: _d(j['sp']), speedAcc: _d(j['sa']), heading: _d(j['h']), meta: (j['m'] as Map?)?.cast<String, dynamic>(),
      );
}

/// A counted point of the route: a fix that moved the distance on (or opened a segment).
/// [dist] and [moving] are cumulative at this point; [seg] is the drawn segment (a pause or gap starts a new one).
class TrackPoint {
  const TrackPoint(this.lat, this.lon, this.t, this.dist, this.moving, this.seg, {this.alt});
  final double lat, lon, dist, moving;
  final int t, seg;

  /// Usable altitude (vertical accuracy good enough), or null.
  final double? alt;
}

/// A whole unit (km or mile) of counted distance, or the labelled partial one at the end.
class TrackSplit {
  const TrackSplit(this.number, this.distanceMeters, this.movingSeconds, this.startMeters, {required this.partial});
  final int number;
  final double distanceMeters, movingSeconds, startMeters;
  final bool partial;
  double get endMeters => startMeters + distanceMeters;

  /// Moving seconds per metre × unit length. Null for a split too short to say.
  double? paceFor(double unitMeters) => distanceMeters < 50 ? null : movingSeconds / distanceMeters * unitMeters;
}

class TrackAnalysis {
  TrackAnalysis();

  /// Builds the analysis of a stored route.
  factory TrackAnalysis.of(Iterable<TrackEntry> entries) {
    final a = TrackAnalysis();
    for (final e in entries) {
      a.add(e);
    }
    return a;
  }

  // Thresholds, documented in docs/RUN_WALK.md › Metrics.
  static const maxAccuracy = 30.0, maxGapMs = 30000, maxSpeed = 12.5, minStep = 4.0, minMovingSpeed = 0.5;
  static const noiseFactor = 1.5, stillSpeed = 0.3, maxAltAccuracy = 15.0, gainHysteresis = 3.0, minAltCoverage = 0.6, jumpResetAfter = 3;

  final points = <TrackPoint>[];

  /// The drawn segment the newest accepted fix belongs to (GPX puts each in its own track segment).
  int get segmentIndex => _seg;
  double distance = 0, moving = 0;
  int accepted = 0, rejected = 0, whilePaused = 0, gaps = 0, interruptions = 0, fixes = 0;
  int? startT, finishT, openSince, lastCountedT;
  int closedActiveMs = 0;
  bool recording = false;
  bool get finished => finishT != null;

  /// Distance and time recorded by the build before routes were kept (an upgraded open run).
  double legacyDistance = 0;
  bool get hasLegacy => _legacy;
  bool _legacy = false;

  /// The newest fix received (any quality): the current-position dot and the accuracy shown.
  TrackEntry? lastFix;

  /// The newest accepted fix: where the live line ends.
  TrackEntry? lastAccepted;
  TrackPoint? _anchor;
  double _anchorAcc = 0;
  int _seg = -1, _jumps = 0;
  final _jumpRun = <TrackEntry>[], _recent = <TrackEntry>[];
  static const smoothing = 3;

  void add(TrackEntry e) {
    switch (e.type) {
      case EntryType.start:
        startT ??= e.t;
        _open(e.t);
      case EntryType.resume || EntryType.autoresume:
        _open(e.t);
      case EntryType.pause || EntryType.autopause:
        _close(e.t);
      case EntryType.interrupt:
        interruptions++;
        _close(e.t);
      case EntryType.finish:
        _close(e.t);
        finishT = e.t;
      case EntryType.legacy:
        _legacy = true;
        legacyDistance += (e.meta?['distanceMeters'] as num?)?.toDouble() ?? 0;
        closedActiveMs += (e.meta?['activeMs'] as num?)?.toInt() ?? 0;
        startT ??= (e.meta?['startedAtMs'] as num?)?.toInt() ?? e.t;
      case EntryType.fix:
        _fix(e);
    }
  }

  void _open(int t) {
    if (recording) return;
    recording = true;
    openSince = t;
    _break();
  }

  void _close(int t) {
    if (!recording) return;
    closedActiveMs += max(0, t - openSince!);
    recording = false;
    openSince = null;
    _break();
  }

  void _break() {
    _recent.clear();
    _anchor = null;
    lastAccepted = null;
    _jumps = 0;
    _jumpRun.clear();
  }

  void _fix(TrackEntry e) {
    if (e.lat == null || e.lon == null) return;
    fixes++;
    lastFix = e;
    if (!recording) {
      whilePaused++;
      return;
    }
    final acc = e.acc;
    if (acc == null || !acc.isFinite || acc > maxAccuracy) {
      rejected++;
      return;
    }
    final prev = lastAccepted;
    if (prev != null) {
      final dt = e.t - prev.t;
      if (dt <= 0) {
        rejected++; // duplicate or out of order
        return;
      }
      if (dt > maxGapMs) {
        gaps++; // readings stopped: a new segment, nothing added across
        _break();
      } else if (haversineMeters(prev.lat!, prev.lon!, e.lat!, e.lon!) / (dt / 1000) > maxSpeed) {
        // An impossible jump. When several fixes in a row agree with each other but not with the last accepted
        // one, the last accepted one was the outlier: restart the segment from the new position.
        rejected++;
        _jumpRun.add(e);
        if (++_jumps < jumpResetAfter) return;
        final run = _jumpRun.sublist(_jumpRun.length - jumpResetAfter);
        if (!_consistent(run)) return;
        rejected -= run.length;
        _break();
        gaps++;
        for (final f in run) {
          _accept(f);
        }
        return;
      }
    }
    _jumps = 0;
    _jumpRun.clear();
    _accept(e);
  }

  static bool _consistent(List<TrackEntry> run) {
    for (var i = 1; i < run.length; i++) {
      final dt = (run[i].t - run[i - 1].t) / 1000;
      if (dt <= 0 || haversineMeters(run[i - 1].lat!, run[i - 1].lon!, run[i].lat!, run[i].lon!) / dt > maxSpeed) return false;
    }
    return true;
  }

  double? _usableAlt(TrackEntry e) {
    final alt = e.alt, va = e.altAcc;
    if (alt == null || !alt.isFinite) return null;
    if (va != null && va > 0 && va > maxAltAccuracy) return null;
    return alt;
  }

  void _accept(TrackEntry e) {
    accepted++;
    lastAccepted = e;
    // Distance is measured between smoothed positions: the mean of the last three accepted fixes of the segment.
    _recent.add(e);
    if (_recent.length > smoothing) _recent.removeAt(0);
    final lat = _recent.fold(0.0, (s, x) => s + x.lat!) / _recent.length, lon = _recent.fold(0.0, (s, x) => s + x.lon!) / _recent.length;
    final a = _anchor;
    if (a == null) {
      _seg++;
      _anchor = TrackPoint(lat, lon, e.t, distance, moving, _seg, alt: _usableAlt(e));
      _anchorAcc = e.acc!;
      points.add(_anchor!);
      return;
    }
    final d = haversineMeters(a.lat, a.lon, lat, lon);
    if (d < max(minStep, noiseFactor * max(_anchorAcc, e.acc!))) return; // inside the noise: standing still adds nothing
    // The receiver's own (Doppler) speed says the phone is not moving: a wandering position is drift. The recorder
    // stores a speed only when the device reports its accuracy, so a missing speed is null here, never 0.
    final s = e.speed;
    if (s != null && s >= 0 && s < stillSpeed) return;
    final dt = (e.t - a.t) / 1000;
    distance += d;
    moving += min(dt, d / minMovingSpeed);
    lastCountedT = e.t;
    _anchor = TrackPoint(lat, lon, e.t, distance, moving, _seg, alt: _usableAlt(e));
    _anchorAcc = e.acc!;
    points.add(_anchor!);
  }

  // ------------------------------------------------------------------ derived values

  int activeMs(int nowMs) => closedActiveMs + (recording && openSince != null ? max(0, nowMs - openSince!) : 0);
  int? elapsedMs(int nowMs) => startT == null ? null : max(0, (finishT ?? nowMs) - startT!);

  /// GPS measured something (at least one accepted fix while recording).
  bool get measured => accepted > 0;

  double? avgMovingPace(double unitMeters) => distance < 50 || moving < 20 ? null : moving / distance * unitMeters;
  double? avgSpeedMps() => distance < 50 || moving < 20 ? null : distance / moving;

  /// Seconds per unit over the last 30 s of moving time; null when stopped or too little was counted.
  double? currentPace(double unitMeters, int nowMs) {
    if (points.isEmpty || !recording || lastCountedT == null || nowMs - lastCountedT! > 15000) return null;
    final last = points.last;
    var i = points.length - 1;
    while (i > 0 && points[i - 1].seg == last.seg && last.moving - points[i - 1].moving <= 30) {
      i--;
    }
    final d = last.dist - points[i].dist, s = last.moving - points[i].moving;
    return d < 20 || s <= 0 ? null : s / d * unitMeters;
  }

  /// The drawn route: one list per segment; the live tail runs to the newest accepted fix and no further.
  List<List<TrackPoint>> get segments {
    final out = <List<TrackPoint>>[];
    for (final p in points) {
      if (out.isEmpty || out.last.last.seg != p.seg) out.add([]);
      out.last.add(p);
    }
    final tail = lastAccepted;
    if (tail != null && out.isNotEmpty && _anchor != null && tail.t > out.last.last.t) {
      out.last.add(TrackPoint(tail.lat!, tail.lon!, tail.t, distance, moving, _seg));
    }
    return out;
  }

  /// Whole units of counted distance, then the labelled partial unit. The crossing moment is interpolated in time
  /// within the one counted step that crosses it (both ends measured fixes of one segment).
  List<TrackSplit> splits(double unitMeters) {
    final out = <TrackSplit>[];
    var startDist = 0.0, startMoving = 0.0;
    var next = unitMeters;
    for (var i = 1; i < points.length; i++) {
      final p = points[i - 1], q = points[i];
      if (q.seg != p.seg) continue; // no distance across segments
      while (q.dist >= next && q.dist > p.dist) {
        final f = (next - p.dist) / (q.dist - p.dist);
        final m = p.moving + f * (q.moving - p.moving);
        out.add(TrackSplit(out.length + 1, unitMeters, m - startMoving, startDist, partial: false));
        startDist = next;
        startMoving = m;
        next += unitMeters;
      }
    }
    final rest = distance - startDist;
    if (rest >= 1) out.add(TrackSplit(out.length + 1, rest, moving - startMoving, startDist, partial: true));
    return out;
  }

  /// Pace (seconds per unit) every [bucketMeters] of counted distance, one series per segment, so a chart is never
  /// drawn through a gap. x = distance in metres at the bucket's middle.
  List<List<(double, double)>> paceProfile(double bucketMeters, double unitMeters) {
    final out = <List<(double, double)>>[];
    for (final seg in _bySegment()) {
      if (seg.length < 2) continue;
      final series = <(double, double)>[];
      var from = seg.first;
      for (var i = 1; i < seg.length; i++) {
        final q = seg[i];
        if (q.dist - from.dist >= bucketMeters) {
          series.add(((from.dist + q.dist) / 2, (q.moving - from.moving) / (q.dist - from.dist) * unitMeters));
          from = q;
        }
      }
      if (series.isNotEmpty) out.add(series);
    }
    return out;
  }

  Iterable<List<TrackPoint>> _bySegment() sync* {
    var cur = <TrackPoint>[];
    for (final p in points) {
      if (cur.isNotEmpty && cur.last.seg != p.seg) {
        yield cur;
        cur = [];
      }
      cur.add(p);
    }
    if (cur.isNotEmpty) yield cur;
  }

  /// Smoothed usable altitude per segment: (distance m, altitude m). Points without usable altitude break a series.
  List<List<(double, double)>> elevationProfile() {
    final out = <List<(double, double)>>[];
    for (final seg in _bySegment()) {
      var run = <TrackPoint>[];
      void flush() {
        if (run.length >= 2) out.add(_smooth(run));
        run = [];
      }

      for (final p in seg) {
        if (p.alt == null) {
          flush();
        } else {
          run.add(p);
        }
      }
      flush();
    }
    return out;
  }

  static List<(double, double)> _smooth(List<TrackPoint> run) => [
        for (var i = 0; i < run.length; i++)
          (run[i].dist, () {
            final lo = max(0, i - 2), hi = min(run.length - 1, i + 2);
            var sum = 0.0;
            for (var k = lo; k <= hi; k++) {
              sum += run[k].alt!;
            }
            return sum / (hi - lo + 1);
          }()),
      ];

  /// Share of counted distance between two points that both have usable altitude.
  double get altitudeCoverage {
    if (distance <= 0) return 0;
    var covered = 0.0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].seg == points[i - 1].seg && points[i].alt != null && points[i - 1].alt != null) covered += points[i].dist - points[i - 1].dist;
    }
    return covered / distance;
  }

  /// (gain, loss) in metres, or null when altitude is too sparse or poor to say (unknown, not zero).
  (double, double)? elevationGainLoss() {
    if (altitudeCoverage < minAltCoverage) return null;
    var gain = 0.0, loss = 0.0;
    for (final series in elevationProfile()) {
      var ref = series.first.$2;
      for (final (_, v) in series) {
        if (v - ref >= gainHysteresis) {
          gain += v - ref;
          ref = v;
        } else if (ref - v >= gainHysteresis) {
          loss += ref - v;
          ref = v;
        }
      }
    }
    return (gain, loss);
  }
}

/// Optional auto-pause (docs/RUN_WALK.md › Auto-pause). Pure rules; the recorder applies them and stores the events.
abstract final class AutoPauseRule {
  static const stillMs = 12000, resumeWindowMs = 15000, freshFixMs = 5000;
  static const resumeMeters = 10.0, resumeAccuracy = 20.0;

  /// When to pause (back-dated to the last counted step), or null. Needs live GPS and a position in this segment.
  static int? pauseAt(TrackAnalysis a, int nowMs) {
    if (!a.recording || a.lastAccepted == null || a.lastFix == null || nowMs - a.lastFix!.t > freshFixMs) return null;
    final since = max(a.openSince ?? 0, a.lastCountedT ?? a.lastAccepted!.t);
    return nowMs - since >= stillMs ? since : null;
  }

  /// Sustained movement away from [from]: true when [fix] confirms a candidate seen at most 15 s earlier.
  /// Returns the new candidate time (or null) through [candidate].
  static ({bool resume, int? candidate}) check(TrackEntry from, TrackEntry fix, int? candidate) {
    final acc = fix.acc ?? double.infinity;
    if (acc > resumeAccuracy) return (resume: false, candidate: candidate);
    final away = haversineMeters(from.lat!, from.lon!, fix.lat!, fix.lon!) >= max(resumeMeters, (from.acc ?? 0) + acc);
    if (!away) return (resume: false, candidate: null);
    if (candidate != null && fix.t > candidate && fix.t - candidate <= resumeWindowMs) return (resume: true, candidate: null);
    return (resume: false, candidate: fix.t);
  }
}
