import 'dart:async';

/// The only source of "now". Event instants are UTC; calendar commitments are local day keys.
abstract interface class AppClock {
  DateTime utcNow();
}

class SystemClock implements AppClock {
  const SystemClock();
  @override
  DateTime utcNow() => DateTime.now().toUtc();
}

String dayKeyOf(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

/// Parses a `YYYY-MM-DD` key as a plain calendar date (UTC-midnight carrier, never zone-converted).
DateTime parseDayKey(String key) {
  final p = key.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String addDays(String key, int days) => dayKeyOf(parseDayKey(key).add(Duration(days: days)));
int daysBetween(String from, String to) => parseDayKey(to).difference(parseDayKey(from)).inDays;

/// Shared local calendar date for Today and Eat. It changes at local midnight and on app resume.
/// Open forms and workouts pin their own day key when they open, so a date change never retargets them.
class BusinessDateService {
  BusinessDateService(this._clock, [DateTime Function(DateTime utc)? toLocal]) : _toLocal = toLocal ?? ((utc) => utc.toLocal()) {
    _dayKey = _compute();
    _schedule();
  }

  final AppClock _clock;
  final DateTime Function(DateTime utc) _toLocal;
  final _changes = StreamController<String>.broadcast();
  Timer? _timer;
  late String _dayKey;
  bool _disposed = false;

  String get dayKey => _dayKey;
  Stream<String> get changes => _changes.stream;

  String _compute() => dayKeyOf(_toLocal(_clock.utcNow()));

  /// Call on app resume and after any clock change. Emits only when the local date really changed.
  void refresh() {
    if (_disposed) return;
    final next = _compute();
    if (next != _dayKey) {
      _dayKey = next;
      _changes.add(next);
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final local = _toLocal(_clock.utcNow());
    // Wall-clock next midnight, so DST days of 23 or 25 hours still roll over at local midnight.
    final nextMidnight = DateTime(local.year, local.month, local.day + 1);
    final wait = nextMidnight.difference(DateTime(local.year, local.month, local.day, local.hour, local.minute, local.second));
    _timer = Timer(wait + const Duration(seconds: 1), refresh);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _changes.close();
  }
}
