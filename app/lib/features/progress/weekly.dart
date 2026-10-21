import '../../core/clock.dart';
import '../../data/models.dart';
import '../workout/progress.dart';
import 'trends.dart';

/// Weekly progress (docs/PROGRESS.md): Monday–Sunday calendar weeks of recorded activity and the goals that applied
/// to each. The one projection the overview, the goal bars, the recap and the coach's facts all read.

/// The Monday of [dayKey]'s week, by calendar arithmetic on date-only keys (never 7 × 24 hours).
String mondayOf(String dayKey) => addDays(dayKey, 1 - parseDayKey(dayKey).weekday);

/// The input bound of a weekly target (not a recommendation).
const goalRange = (1, 21);

/// The goals that apply to the week starting [monday]: the latest record effective on or before it. Null when none
/// was ever set for that week (an older week is never measured against a later target).
WeeklyGoal? goalFor(String monday, Iterable<WeeklyGoal> goals) {
  WeeklyGoal? best;
  for (final g in goals) {
    if (g.weekStart.compareTo(monday) <= 0 && (best == null || g.weekStart.compareTo(best.weekStart) > 0)) best = g;
  }
  return best;
}

/// A saved Run / Walk that counts: finished, not deleted, with positive recorded active time. One interval session
/// is one activity.
bool countsAsActivity(Run r) => !r.isDeleted && !r.isOpen && (r.activeDurationSeconds ?? 0) > 0;

/// Sums that say when they are incomplete: [missing] activities had no recorded value and are not counted as zero.
class Total {
  const Total(this.value, this.counted, this.missing);
  final double value;
  final int counted, missing;
  bool get known => counted > 0;
  bool get incomplete => missing > 0;
}

Total _sum(Iterable<Run> runs, num? Function(Run) of) {
  var v = 0.0, counted = 0, missing = 0;
  for (final r in runs) {
    final x = of(r);
    if (x == null) {
      missing++;
    } else {
      v += x;
      counted++;
    }
  }
  return Total(v, counted, missing);
}

class WeekSummary {
  WeekSummary({required this.monday, required this.workouts, required this.activities, required this.goal, required this.isComplete});
  final String monday;

  /// Distinct performed workouts and counting Run / Walk activities on the week's day keys, oldest first.
  final List<Workout> workouts;
  final List<Run> activities;

  /// The record in effect for this week; null when no goal was ever set by then. A record with both targets null
  /// means goals were cleared.
  final WeeklyGoal? goal;

  /// The whole week is in the past (Sunday before today).
  final bool isComplete;

  String get sunday => addDays(monday, 6);
  int get workoutCount => workouts.length;
  int get activityCount => activities.length;
  List<Run> get runs => [for (final r in activities) if (!r.isWalk) r];
  List<Run> get walks => [for (final r in activities) if (r.isWalk) r];
  int? get workoutsTarget => goal?.workoutsTarget;
  int? get runWalkTarget => goal?.runWalkTarget;
  bool get hasGoals => workoutsTarget != null || runWalkTarget != null;
  bool get isEmpty => workouts.isEmpty && activities.isEmpty;

  Total get distance => _sum(activities, (r) => r.distanceMeters);
  Total get activeSeconds => _sum(activities, (r) => r.activeDurationSeconds);

  /// "Walking distance" only when every counted activity is a walk; "Running" likewise; otherwise "Run / Walk".
  ActivityMix get activityMix => activities.isNotEmpty && activities.every((r) => r.isWalk)
      ? ActivityMix.walking
      : activities.isNotEmpty && activities.every((r) => !r.isWalk)
          ? ActivityMix.running
          : ActivityMix.mixed;
}

/// Which activities a week's Run / Walk totals cover; shown as words by the recap.
enum ActivityMix { walking, running, mixed }

/// Builds the summary of the week starting [monday]. [workouts] and [runs] are the owner's records on this phone;
/// the same record is never counted twice, whatever retries or route chunks did.
WeekSummary summarizeWeek({required String monday, required String today, required List<Workout> workouts, required List<Run> runs, required List<WeeklyGoal> goals}) {
  final sunday = addDays(monday, 6);
  bool inWeek(String day) => day.compareTo(monday) >= 0 && day.compareTo(sunday) <= 0;
  final seenW = <String>{}, seenR = <String>{};
  final w = [for (final x in workouts) if (countsAsTraining(x) && !x.isOpen && inWeek(x.dayKey) && seenW.add(x.id)) x]..sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));
  final r = [for (final x in runs) if (countsAsActivity(x) && inWeek(x.dayKey) && seenR.add(x.id)) x]..sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));
  return WeekSummary(monday: monday, workouts: w, activities: r, goal: goalFor(monday, goals), isComplete: sunday.compareTo(today) < 0);
}

/// The completed weeks a recap can show, newest first: from last week back to the first week with any recorded
/// activity (last week is always offered, even when it is empty).
List<String> completedWeeks({required String today, required List<Workout> workouts, required List<Run> runs}) {
  final last = addDays(mondayOf(today), -7);
  var first = last;
  for (final d in [for (final w in workouts) if (countsAsTraining(w) && !w.isOpen) w.dayKey, for (final r in runs) if (countsAsActivity(r)) r.dayKey]) {
    final m = mondayOf(d);
    if (m.compareTo(first) < 0) first = m;
  }
  return [for (var m = last; m.compareTo(first) >= 0; m = addDays(m, -7)) m];
}

/// At most one factual strength highlight for a week: an exercise with at least two comparable sessions inside it
/// (same identity, same reps, the chart's top-set rule) whose latest load is higher than its first. Null when the
/// evidence is missing or flat: nothing is invented.
({ExerciseTrend trend, int reps, TrendPoint first, TrendPoint last})? strengthHighlight(WeekSummary week, TrendIndex index) {
  ({ExerciseTrend trend, int reps, TrendPoint first, TrendPoint last})? best;
  for (final t in index.trends.values) {
    if (t.metric != TrendMetric.load) continue;
    for (final reps in t.repOptions) {
      final pts = [for (final p in t.points(reps: reps)) if (p.dayKey.compareTo(week.monday) >= 0 && p.dayKey.compareTo(week.sunday) <= 0) p];
      if (pts.length < 2 || pts.last.value <= pts.first.value) continue;
      final gain = pts.last.value - pts.first.value;
      // The biggest recorded increase; ties go to the exercise recorded last, then its key, so the choice is stable.
      if (best == null || gain > best.last.value - best.first.value ||
          (gain == best.last.value - best.first.value && (pts.last.startedAtUtc.compareTo(best.last.startedAtUtc) > 0 || (pts.last.startedAtUtc == best.last.startedAtUtc && t.key.compareTo(best.trend.key) < 0)))) {
        best = (trend: t, reps: reps, first: pts.first, last: pts.last);
      }
    }
  }
  return best;
}
