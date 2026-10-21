/// Personal bests for Run and Walk (docs/RUN_WALK.md › Personal bests). Derived, never stored as awards: each saved
/// activity keeps its own fastest stretches (`metrics.efforts`), and the bests are projected from every saved
/// activity on this phone whenever they are shown, so an edit, a type change or a deletion is reflected at once, and
/// saving or syncing the same activity again can never award anything twice.
library;

import 'dart:math';

import '../../core/format.dart' show ltr, withUnit;
import '../../core/language.dart';
import '../../data/models.dart';
import 'track_math.dart';

/// A record category. [meters] is the benchmark distance; null for "longest distance".
class Benchmark {
  const Benchmark(this.id, this.type, this.meters);
  final String id, type;
  final double? meters;
  bool get longest => meters == null;
}

const benchmarks = [
  Benchmark('run.longest', 'run', null),
  Benchmark('run.1k', 'run', 1000),
  Benchmark('run.5k', 'run', 5000),
  Benchmark('walk.longest', 'walk', null),
  Benchmark('walk.1k', 'walk', 1000),
];

/// "Longest run", "Fastest 1 km walk": the category's name, from its [Benchmark.id].
String benchmarkLabel(AppLocalizations l, Benchmark b) => switch (b.id) {
      'run.longest' => l.runBestLongestRun,
      'run.1k' => l.runBestFastest1kRun,
      'run.5k' => l.runBestFastest5kRun,
      'walk.longest' => l.runBestLongestWalk,
      _ => l.runBestFastest1kWalk,
    };

/// The benchmark distances worked out for every activity, whatever its type (a type change needs no recomputation).
const effortMeters = [1000.0, 5000.0];

/// The fastest stretch of each distance, in seconds of elapsed time from the start of the stretch to its end.
/// Only counted GPS distance inside one recording segment is used: a pause, an auto-pause, an interruption or a GPS gap
/// ends a segment, so a stretch never crosses one (no time is excluded, and nothing is interpolated through missing
/// GPS). The start of a stretch is placed inside the counted step it falls in, between two measured fixes.
Map<String, double> bestEfforts(TrackAnalysis a, {List<double> meters = effortMeters}) {
  final out = <String, double>{};
  final pts = a.points;
  for (final target in meters) {
    double? best;
    var segStart = 0;
    for (var j = 0; j < pts.length; j++) {
      if (j > 0 && pts[j].seg != pts[j - 1].seg) segStart = j;
      final end = pts[j];
      final from = end.dist - target;
      if (from < pts[segStart].dist) continue;
      // The last counted point at or before `from`, in this segment.
      var lo = segStart, hi = j;
      while (lo < hi) {
        final mid = (lo + hi + 1) >> 1;
        if (pts[mid].dist <= from) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      final p = pts[lo], q = pts[min(lo + 1, j)];
      final f = q.dist > p.dist ? (from - p.dist) / (q.dist - p.dist) : 0.0;
      final startT = p.t + f * (q.t - p.t);
      final s = (end.t - startT) / 1000;
      if (s > 0 && (best == null || s < best)) best = s;
    }
    if (best != null) out[target.round().toString()] = (best * 10).round() / 10;
  }
  return out;
}

/// One record: the activity holding it and its value (metres for a longest, seconds for a fastest).
class Best {
  const Best(this.benchmark, this.run, this.value);
  final Benchmark benchmark;
  final Run run;
  final double value;
}

class Bests {
  const Bests(this.by, {required this.checked, required this.unchecked, this.qualifying = const {}});
  final Map<String, Best> by;

  /// How many activities qualified for each category: a best among one is not yet worth a badge.
  final Map<String, int> qualifying;

  /// Saved activities that could be checked, and ones that could not (recorded before personal bests were kept, or
  /// without a GPS-measured distance).
  final Map<String, int> checked, unchecked;
}

/// Measured by GPS and not corrected, typed or carried over from the build before routes.
bool _gpsMeasured(Run r) => r.distanceSource == 'gps' && r.metrics['legacyDistanceMeters'] == null && !r.isLegacy;

double? _value(Run r, Benchmark b) {
  if (r.isDeleted || r.isOpen || r.activityType != b.type || !_gpsMeasured(r)) return null;
  if (b.longest) return (r.metrics['gpsDistanceMeters'] as num?)?.toDouble();
  return ((r.metrics['efforts'] as Map?)?[b.meters!.round().toString()] as num?)?.toDouble();
}

bool _better(Benchmark b, double v, double than) => b.longest ? v > than + 1 : v < than - 0.05;

/// The bests among [runs]. Ties go to the earlier activity (it got there first).
Bests personalBests(Iterable<Run> runs) {
  final by = <String, Best>{};
  final qualifying = <String, int>{};
  final checked = {'run': 0, 'walk': 0}, unchecked = {'run': 0, 'walk': 0};
  final sorted = [...runs.where((r) => !r.isDeleted && !r.isOpen)]..sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));
  for (final r in sorted) {
    final ok = _gpsMeasured(r) && r.metrics['efforts'] is Map;
    (ok ? checked : unchecked).update(r.activityType, (n) => n + 1, ifAbsent: () => 1);
    for (final b in benchmarks) {
      final v = _value(r, b);
      if (v == null) continue;
      qualifying.update(b.id, (n) => n + 1, ifAbsent: () => 1);
      final cur = by[b.id];
      if (cur == null || _better(b, v, cur.value)) by[b.id] = Best(b, r, v);
    }
  }
  return Bests(by, checked: checked, unchecked: unchecked, qualifying: qualifying);
}

/// The records [saved] sets against the activities before it. A first activity of its type sets none: there is
/// nothing to beat yet, and it is not called a best.
List<Best> newRecords(Run saved, Iterable<Run> others) {
  final before = personalBests(others.where((r) => r.id != saved.id));
  return [
    for (final b in benchmarks)
      if (_value(saved, b) case final v? when before.by[b.id] != null && _better(b, v, before.by[b.id]!.value)) Best(b, saved, v),
  ];
}

/// "Your longest walk so far." / "A new best: fastest 1 km run, 5:42." Calm, once, from real data.
/// Built in [l] (the resolved language) when it is said.
String recordMessage(List<Best> records, String Function(double meters) distance, {AppLocalizations? l10n}) {
  final l = l10n ?? currentL10n;
  String one(Best r) => r.benchmark.longest
      ? l.runRecordLongest(r.benchmark.type, distance(r.value))
      : l.runRecordFastest(r.benchmark.type, withUnit('${(r.benchmark.meters! / 1000).round()}', l.unitKm), ltr(clockOf(r.value)));
  final p = records.map(one).toList();
  final text = switch (p.length) { 1 => p[0], 2 => l.runRecordsTwo(p[0], p[1]), _ => l.runRecordsThree(p[0], p[1], p.sublist(2).join(', ')) };
  return '${text[0].toUpperCase()}${text.substring(1)}.';
}

String clockOf(double seconds) {
  final s = seconds.round(), h = s ~/ 3600, m = (s % 3600) ~/ 60, r = s % 60;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}' : '$m:${r.toString().padLeft(2, '0')}';
}
