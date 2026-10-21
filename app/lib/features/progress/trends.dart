import '../../core/clock.dart';
import '../../core/language.dart' show currentL10n;
import '../../data/models.dart';
import '../workout/progress.dart';
import '../workout/result_rules.dart';

/// Exercise trends (docs/PROGRESS.md › Exercise trends): one exercise's comparable recorded results over time. Built
/// once per change of the records (a provider), never per widget build, and only from performed workouts and trusted
/// sets. The recorder's "last time" ([exerciseHistory]) keeps its own occurrence rule; this groups by identity.

/// What the chart plots. [load]: the heaviest recorded load at one exact rep count; [reps]: the most reps in one set
/// with no added load; [duration]: the longest recorded time of a timed exercise; [none]: no comparable measure.
enum TrendMetric { load, reps, duration, none }

enum TrendRange {
  weeks4(28),
  weeks12(84),
  all(null);

  const TrendRange(this.days);

  /// "4 weeks", "12 weeks", "All" in the resolved app language; [name] stays the identifier.
  String get label => switch (this) { weeks4 => currentL10n.progressRange4Weeks, weeks12 => currentL10n.progressRange12Weeks, all => currentL10n.progressRangeAll };

  /// Calendar days including today; null = all history.
  final int? days;

  String? from(String today) => days == null ? null : addDays(today, 1 - days!);
}

/// One plotted result: the chosen set of one workout.
class TrendPoint {
  const TrendPoint(this.workout, this.set, this.value);
  final Workout workout;
  final WorkoutSet set;

  /// Kilograms, repetitions or seconds, by the trend's metric.
  final double value;
  String get workoutId => workout.id;
  String get dayKey => workout.dayKey;
  String get startedAtUtc => workout.startedAtUtc;
}

/// One workout's recorded sets of the exercise (every appearance of it in that workout), in the order performed.
class TrendSession {
  const TrendSession(this.workout, this.sets);
  final Workout workout;
  final List<WorkoutSet> sets;
}

bool _loaded(WorkoutSet s) => (s.reps ?? 0) > 0 && (s.loadKg ?? 0) > 0;
bool _bodyweight(WorkoutSet s) => (s.reps ?? 0) > 0 && (s.loadKg == null || s.loadKg == 0);
bool _timed(WorkoutSet s) => (s.durationSeconds ?? 0) > 0;

/// The greater of two candidate sets; ties go to the one performed first, then the lower ID, so a choice never flips.
WorkoutSet _top(WorkoutSet a, WorkoutSet b, double Function(WorkoutSet) v) {
  if (v(a) != v(b)) return v(a) > v(b) ? a : b;
  final t = a.performedAtUtc.compareTo(b.performedAtUtc);
  if (t != 0) return t < 0 ? a : b;
  return a.id.compareTo(b.id) <= 0 ? a : b;
}

class ExerciseTrend {
  ExerciseTrend(this.key, this.name, this.isTimed, this.sessions) {
    final all = [for (final s in sessions) ...s.sets];
    metric = all.any(_loaded)
        ? TrendMetric.load
        : (isTimed || !all.any(_bodyweight)) && all.any(_timed)
            ? TrendMetric.duration
            : all.any(_bodyweight)
                ? TrendMetric.reps
                : TrendMetric.none;
    repOptions = ({for (final s in all) if (_loaded(s)) s.reps!}.toList()..sort());
    // The rep count of the most recent loaded set: sessions are oldest first, sets in the order performed.
    defaultReps = metric == TrendMetric.load ? [for (final s in sessions) for (final x in s.sets) if (_loaded(x)) x].last.reps : null;
    excluded = switch (metric) {
      TrendMetric.load => all.where((s) => !_loaded(s)).length,
      TrendMetric.reps => all.where((s) => !_bodyweight(s)).length,
      TrendMetric.duration => all.where((s) => !_timed(s)).length,
      TrendMetric.none => all.length,
    };
  }

  /// The stable identity: a catalog key or a private `custom:<id>`. Never a name.
  final String key;

  /// The name in the most recent session.
  final String name;
  final bool isTimed;

  /// Every performed workout with recorded sets of this exercise, oldest first.
  final List<TrendSession> sessions;
  late final TrendMetric metric;

  /// Rep counts that have a loaded set somewhere in the history, ascending.
  late final List<int> repOptions;
  late final int? defaultReps;

  /// Recorded sets the metric cannot use (no load, no reps, …): they stay in the sessions, never in the chart.
  late final int excluded;

  String get latestAtUtc => sessions.last.workout.startedAtUtc;

  /// One point per workout, oldest first, at the workout's own time. A session without a set that fits gives none.
  List<TrendPoint> points({int? reps}) => [
        for (final s in sessions)
          if (switch (metric) {
            TrendMetric.load => s.sets.where((x) => _loaded(x) && x.reps == reps).fold<WorkoutSet?>(null, (a, b) => a == null ? b : _top(a, b, (x) => x.loadKg!)),
            TrendMetric.reps => s.sets.where(_bodyweight).fold<WorkoutSet?>(null, (a, b) => a == null ? b : _top(a, b, (x) => x.reps!.toDouble())),
            TrendMetric.duration => s.sets.where(_timed).fold<WorkoutSet?>(null, (a, b) => a == null ? b : _top(a, b, (x) => x.durationSeconds!.toDouble())),
            TrendMetric.none => null,
          } case final top?)
            TrendPoint(s.workout, top, switch (metric) {
              TrendMetric.load => top.loadKg!,
              TrendMetric.reps => top.reps!.toDouble(),
              _ => top.durationSeconds!.toDouble(),
            }),
      ];
}

/// Points inside [range] (counted back from [today], inclusive).
List<TrendPoint> inRange(List<TrendPoint> points, TrendRange range, String today) {
  final from = range.from(today);
  return from == null ? points : [for (final p in points) if (p.dayKey.compareTo(from) >= 0) p];
}

/// The signed change from the first to the latest point, only when there are at least two.
double? changeOf(List<TrendPoint> points) => points.length < 2 ? null : points.last.value - points.first.value;

/// Every exercise with recorded evidence, by identity.
class TrendIndex {
  const TrendIndex(this.trends);
  final Map<String, ExerciseTrend> trends;

  /// Most recently recorded first.
  List<ExerciseTrend> get recent => trends.values.toList()..sort((a, b) => b.latestAtUtc.compareTo(a.latestAtUtc));

  /// [sets] must already exclude records awaiting conflict review ([trustedSetsProvider]).
  static TrendIndex build({required List<Workout> workouts, required List<WorkoutSet> sets}) {
    final byExercise = <String, List<WorkoutSet>>{};
    for (final s in sets) {
      if (!s.isDeleted && WorkoutResultRules.isPerformed(PerformedSet(s.exerciseId, reps: s.reps, loadKg: s.loadKg, durationSeconds: s.durationSeconds))) {
        (byExercise[s.exerciseId] ??= []).add(s);
      }
    }
    final trained = [for (final w in workouts) if (countsAsTraining(w) && !w.isOpen) w]
      ..sort((a, b) => a.startedAtUtc == b.startedAtUtc ? a.id.compareTo(b.id) : a.startedAtUtc.compareTo(b.startedAtUtc));
    final sessions = <String, List<TrendSession>>{}, names = <String, String>{}, timed = <String, bool>{};
    for (final w in trained) {
      final perKey = <String, List<WorkoutSet>>{};
      for (final e in w.exercises) {
        final key = e.catalogKey;
        final performed = byExercise[e.id];
        if (key == null || performed == null) continue; // free text gets no guessed history
        (perKey[key] ??= []).addAll(performed);
        names[key] = e.name;
        timed[key] = (timed[key] ?? false) || e.isTimed;
      }
      for (final MapEntry(:key, :value) in perKey.entries) {
        (sessions[key] ??= []).add(TrendSession(w, value..sort((a, b) => a.performedAtUtc.compareTo(b.performedAtUtc))));
      }
    }
    return TrendIndex({for (final MapEntry(:key, :value) in sessions.entries) key: ExerciseTrend(key, names[key]!, timed[key]!, value)});
  }
}
