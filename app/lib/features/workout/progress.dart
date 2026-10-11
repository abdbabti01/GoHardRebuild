import '../../core/clock.dart';
import '../../data/models.dart';
import '../today/daily.dart';
import 'result_rules.dart';

/// Workouts that count as performed training: finished with actual sets, and not deleted.
bool countsAsTraining(Workout w) =>
    !w.isDeleted && const [WorkoutResultRules.full, WorkoutResultRules.partial, WorkoutResultRules.manualRecorded].contains(w.outcome);

/// The sets an earlier session recorded for the same movement in the same position.
class PreviousPerformance {
  const PreviousPerformance(this.dayKey, this.sets);
  final String dayKey;
  final List<WorkoutSet> sets;
}

/// Previous performance by identity: same catalog movement and the same occurrence ordinal within the
/// workout, from the most recent earlier session that counts as training. A movement without a catalog
/// identity has no history; names are never used to guess.
PreviousPerformance? previousPerformance(Workout current, WorkoutExercise exercise, List<Workout> workouts, List<WorkoutSet> sets) {
  final key = exercise.catalogKey;
  if (key == null) return null;
  int ordinalOf(Workout w, String exerciseId) => w.exercises.where((e) => e.catalogKey == key).toList().indexWhere((e) => e.id == exerciseId);
  final ordinal = ordinalOf(current, exercise.id);
  final earlier = workouts.where((w) => w.id != current.id && countsAsTraining(w) && w.startedAtUtc.compareTo(current.startedAtUtc) < 0).toList()
    ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
  for (final w in earlier) {
    final same = w.exercises.where((e) => e.catalogKey == key).toList();
    if (ordinal < 0 || ordinal >= same.length) continue;
    final performed = sets.where((s) => s.exerciseId == same[ordinal].id && !s.isDeleted).toList()..sort((a, b) => a.performedAtUtc.compareTo(b.performedAtUtc));
    if (performed.isNotEmpty) return PreviousPerformance(w.dayKey, performed);
  }
  return null;
}

class ExerciseInsight {
  const ExerciseInsight(this.name, this.sessions, this.firstDay, this.first, this.latestDay, this.latest);
  final String name;
  final int sessions;
  final String firstDay, latestDay;
  final WorkoutSet first, latest;
}

class TrainingProgress {
  const TrainingProgress({required this.sessions, required this.dueOccasions, required this.recorded, required this.full, required this.partial,
      required this.skipped, required this.missed, required this.weeks, required this.insights});
  final int sessions;

  /// Follow-through of the primary plan: unique intended occasions that are due, never repeats of a workout.
  final int dueOccasions, recorded, full, partial, skipped, missed;

  /// Distinct training days in each of the last eight local weeks, oldest first, keyed by the week's Monday.
  final List<(String monday, int days)> weeks;
  final List<ExerciseInsight> insights;
  bool get hasEvidence => sessions > 0;
}

/// A set's comparable strength, most important first: load, then reps, then time held.
List<num> _strength(WorkoutSet s) => [s.loadKg ?? 0, s.reps ?? 0, s.durationSeconds ?? 0];

bool _stronger(WorkoutSet a, WorkoutSet b) {
  final x = _strength(a), y = _strength(b);
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return x[i] > y[i];
  }
  return false;
}

/// Progress derived only from actual recorded work. With no evidence it returns empty answers, never zeros
/// dressed up as results. `sets` must already exclude records awaiting conflict review.
abstract final class TrainingProgressProjection {
  static TrainingProgress build({required String today, required Plan? primary, required List<Workout> workouts, required List<WorkoutSet> sets}) {
    final trained = workouts.where(countsAsTraining).toList()..sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));

    var due = 0, full = 0, partial = 0, skipped = 0, missed = 0;
    if (primary != null) {
      for (final o in primary.occasions) {
        final status = statusOf(o, primary, today, workouts);
        if (o.scheduledDate.compareTo(today) > 0 && status != OccasionStatus.finished && status != OccasionStatus.partial) continue;
        switch (status) {
          case OccasionStatus.finished: due++; full++;
          case OccasionStatus.partial: due++; partial++;
          case OccasionStatus.skipped: due++; skipped++;
          case OccasionStatus.missed: due++; missed++;
          default: break; // due today, in progress or paused: not yet an outcome
        }
      }
    }

    final thisMonday = addDays(today, 1 - parseDayKey(today).weekday);
    final days = trained.map((w) => w.dayKey).toSet();
    final weeks = [
      for (var i = 7; i >= 0; i--)
        (addDays(thisMonday, -7 * i), days.where((d) => d.compareTo(addDays(thisMonday, -7 * i)) >= 0 && d.compareTo(addDays(thisMonday, -7 * i + 7)) < 0).length),
    ];

    // Strength evidence: the best set of the first and of the latest session for each catalog movement.
    final best = <String, List<(String day, String name, WorkoutSet set)>>{};
    for (final w in trained) {
      for (final e in w.exercises.where((e) => e.catalogKey != null)) {
        final performed = sets.where((s) => s.exerciseId == e.id && !s.isDeleted).toList();
        if (performed.isEmpty) continue;
        final top = performed.reduce((a, b) => _stronger(b, a) ? b : a);
        final list = best.putIfAbsent(e.catalogKey!, () => []);
        if (list.isNotEmpty && list.last.$1 == w.dayKey) {
          if (_stronger(top, list.last.$3)) list[list.length - 1] = (w.dayKey, e.name, top);
        } else {
          list.add((w.dayKey, e.name, top));
        }
      }
    }
    final insights = [
      for (final e in best.values)
        if (e.length >= 2) ExerciseInsight(e.last.$2, e.length, e.first.$1, e.first.$3, e.last.$1, e.last.$3),
    ]..sort((a, b) => b.sessions.compareTo(a.sessions));

    return TrainingProgress(sessions: trained.length, dueOccasions: due, recorded: full + partial, full: full, partial: partial,
        skipped: skipped, missed: missed, weeks: weeks, insights: insights);
  }
}
