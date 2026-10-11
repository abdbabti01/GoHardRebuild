import 'dart:math';

import '../../data/models.dart';

/// One location reading.
class Fix {
  const Fix(this.latitude, this.longitude, this.accuracyMeters, this.atUtc);
  final double latitude, longitude, accuracyMeters;
  final DateTime atUtc;
}

double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final a = pow(sin(rad(lat2 - lat1) / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(rad(lon2 - lon1) / 2), 2);
  return 2 * r * asin(sqrt(a.toDouble()));
}

/// Distance measured from real location readings, stored with the run's phone-only runtime so it survives a
/// restart. It only ever adds the distance between two consecutive trustworthy readings. When readings stop
/// (screen left, app closed, signal lost) the stretch in between is counted as a gap and left OUT of the
/// distance: missing points are never invented or bridged with a straight line.
extension type RunTrack(Json j) {
  static const maxAccuracyMeters = 35.0, maxGapSeconds = 20, minStepMeters = 2.0, maxSpeedMetersPerSecond = 12.0;

  double get distanceMeters => (j['distanceMeters'] as num?)?.toDouble() ?? 0;
  int get fixes => j['fixes'] as int? ?? 0;
  int get gaps => j['gaps'] as int? ?? 0;
  bool get hasDistance => fixes > 1 && distanceMeters > 0;

  RunTrack added(Fix f) {
    if (!f.accuracyMeters.isFinite || f.accuracyMeters > maxAccuracyMeters) return this; // too vague to trust
    final next = copyJson(j);
    void anchor() {
      next['lastLat'] = f.latitude;
      next['lastLon'] = f.longitude;
      next['lastAtUtc'] = f.atUtc.toIso8601String();
      next['fixes'] = fixes + 1;
    }

    if (j['lastAtUtc'] == null) {
      anchor();
      return RunTrack(next);
    }
    final seconds = f.atUtc.difference(DateTime.parse(j['lastAtUtc'] as String)).inMilliseconds / 1000;
    if (seconds <= 0) return this;
    if (seconds > maxGapSeconds) {
      next['gaps'] = gaps + 1; // readings stopped for a while: restart from here without adding the jump
      anchor();
      return RunTrack(next);
    }
    final step = haversineMeters((j['lastLat'] as num).toDouble(), (j['lastLon'] as num).toDouble(), f.latitude, f.longitude);
    if (step < minStepMeters) return this; // standing still: ignore jitter, keep the anchor
    if (step / seconds > maxSpeedMetersPerSecond) return this; // a position jump, not running
    next['distanceMeters'] = distanceMeters + step;
    anchor();
    return RunTrack(next);
  }

  /// Called when the run is paused or tracking stops: movement until the next reading is not counted.
  RunTrack detached() => RunTrack(copyJson(j)..['lastAtUtc'] = null);
}
