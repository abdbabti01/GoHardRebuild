import '../../core/clock.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../today/daily.dart';

/// Completion of a plan or one of its weeks: workouts with a recorded result, out of the planned workouts that
/// are still expected. A skipped workout is neither completed nor expected. Elapsed time is not counted at all.
class Completion {
  const Completion(this.completed, this.eligible);
  final int completed, eligible;
  double get fraction => eligible == 0 ? 0 : completed / eligible;
  bool get isDone => eligible > 0 && completed >= eligible;

  static Completion of(Iterable<Occasion> occasions, Iterable<Workout> workouts) {
    var completed = 0, eligible = 0;
    for (final o in occasions) {
      if (o.isSkipped) continue;
      eligible++;
      if (occasionOutcome(o, workouts) != null) completed++;
    }
    return Completion(completed, eligible);
  }
}

/// One seven-day interval of the block, counted from the plan's accepted start date.
class PlanWeek {
  const PlanWeek({required this.number, required this.start, required this.end, required this.occasions, required this.completion, required this.isCurrent, required this.isPast});
  final int number;
  final String start, end;

  /// The workouts that belong to this training week. A moved workout keeps its week and shows its own date.
  final List<Occasion> occasions;
  final Completion completion;
  final bool isCurrent, isPast;

  /// "Oct 5 – 11", or "Sep 28 – Oct 4" across a month boundary.
  String get range => dateRange(start, end);
}

String dateRange(String start, String end) {
  final a = parseDayKey(start), b = parseDayKey(end);
  return '${monthShort(a.month)} ${a.day} – ${a.month == b.month ? '' : '${monthShort(b.month)} '}${b.day}';
}

/// Every week of the block. The count follows the plan: its length, or further if a workout was numbered later.
List<PlanWeek> planWeeks(Plan plan, String today, Iterable<Workout> workouts) {
  final occasions = plan.occasions;
  final count = occasions.fold(plan.blockWeeks, (m, o) => o.weekNumber > m ? o.weekNumber : m);
  return [
    for (var n = 1; n <= count; n++)
      () {
        final start = addDays(plan.startDate, 7 * (n - 1)), end = addDays(plan.startDate, 7 * n - 1);
        final mine = [for (final o in occasions) if (o.weekNumber == n) o];
        return PlanWeek(number: n, start: start, end: end, occasions: mine, completion: Completion.of(mine, workouts),
            isCurrent: today.compareTo(start) >= 0 && today.compareTo(end) <= 0, isPast: today.compareTo(end) > 0);
      }(),
  ];
}

/// The week to show first: the one containing today, the first before the plan starts, the last after it ends.
PlanWeek? focusWeek(List<PlanWeek> weeks) => weeks.isEmpty ? null : weeks.where((w) => w.isCurrent).firstOrNull ?? (weeks.first.isPast ? weeks.last : weeks.first);

/// Sets actually recorded against a workout's planned sets. Targets and prefilled suggestions are never counted,
/// and sets beyond a movement's target do not fill the rail for another movement.
class SetProgress {
  const SetProgress(this.recorded, this.planned, this.counted);

  /// Every recorded set, including extras and movements added during the workout.
  final int recorded;

  /// Planned sets, or null when the workout has no set targets (a manual workout).
  final int? planned;

  /// Recorded sets that count toward the plan, capped per movement at its target.
  final int counted;
  double get fraction => (planned ?? 0) == 0 ? 0 : counted / planned!;

  static SetProgress of(Workout workout, Iterable<WorkoutSet> sets) {
    final mine = [for (final s in sets) if (s.workoutId == workout.id && !s.isDeleted) s];
    var planned = 0, counted = 0;
    for (final e in workout.exercises) {
      final target = e.isPrescribed ? e.targetSets ?? 0 : 0;
      final done = mine.where((s) => s.exerciseId == e.id).length;
      planned += target;
      counted += done < target ? done : target;
    }
    return SetProgress(mine.length, planned == 0 ? null : planned, counted);
  }
}

const _directions = {'strength': 'Get stronger', 'muscle': 'Build muscle', 'fat_loss': 'Lose fat', 'general': 'General fitness'};
const _equipment = {'full_gym': 'Full gym', 'dumbbells': 'Dumbbells only', 'bodyweight': 'Bodyweight only'};

/// The wording of an older reviewed plan's setup answers.
String setupSummary(Json s) =>
    '${_directions[s['direction']] ?? s['direction']} · ${s['sessionsPerWeek']} a week · about ${s['minutesPerSession']} min · ${_equipment[s['equipment']] ?? s['equipment']}';

/// The plan's split: the starter it was copied from, the user's own, or an older plan's setup.
/// [templateName] looks a template's name up by ID (null while the templates are not loaded).
String planSplit(Plan plan, String? Function(String id) templateName) {
  if (!plan.isBuilt) return plan.setup == null ? 'Reviewed plan' : setupSummary(plan.setup!);
  final id = plan.templateId;
  return (id == null ? null : templateName(id)) ?? 'Your own split';
}

String scheduleMode(Plan plan) => plan.isRotating ? 'Rotating sequence' : 'Fixed weekdays';

/// The time the user chose for a session. It is a plan, never a measured or estimated duration.
int? plannedMinutes(Plan plan) => plan.timeBudgetMinutes ?? (plan.setup?['minutesPerSession'] as num?)?.toInt();

/// "3 × 8–12 · 90 s rest", "3 × 45 s", "3 sets", "8 reps", or "No target".
String prescriptionLine({int? sets, int? repsMin, int? repsMax, int? seconds, int? rest}) {
  final reps = seconds != null
      ? '$seconds s'
      : repsMin != null && repsMax != null && repsMin != repsMax
          ? '$repsMin–$repsMax'
          : (repsMin ?? repsMax)?.toString();
  final main = sets != null && reps != null
      ? '$sets × $reps'
      : sets != null
          ? '$sets ${sets == 1 ? 'set' : 'sets'}'
          : reps == null
              ? null
              : seconds != null ? reps : '$reps reps';
  final restText = (rest ?? 0) <= 0 ? null : rest! >= 120 && rest % 60 == 0 ? '${rest ~/ 60} min rest' : '$rest s rest';
  final parts = [?main, ?restText];
  return parts.isEmpty ? 'No target' : parts.join(' · ');
}

String prescriptionOf(Prescription e) =>
    prescriptionLine(sets: e.targetSets, repsMin: e.targetRepsMin, repsMax: e.targetRepsMax, seconds: e.targetDurationSeconds, rest: e.restSeconds);

/// Monday of the calendar week holding [day].
String weekStart(String day) => addDays(day, 1 - parseDayKey(day).weekday);

/// Sessions of a rotation credited in the calendar week (Monday to Sunday) holding [today]. A rotation has no
/// meaningful total, so this and the position in the cycle are its progress; there is no overall percentage.
int creditedThisWeek(List<Occasion> occasions, Iterable<Workout> workouts, String today) {
  final from = weekStart(today), to = addDays(from, 6);
  return occasions.where((o) => o.scheduledDate.compareTo(from) >= 0 && o.scheduledDate.compareTo(to) <= 0 && occasionOutcome(o, workouts) != null).length;
}

/// Where a recorded planned workout came from: plan, workout, its week or rotation step, and its date.
/// The plan may have been edited, paused, archived or closed since; the record keeps what was planned then.
String provenanceOf(Workout w, List<Plan> plans, List<Workout> workouts) {
  if (w.isManual || w.planId == null) return 'Manual workout · not part of a plan';
  final plan = plans.where((p) => p.id == w.planId).firstOrNull;
  if (plan == null) return 'From a plan that is no longer on this phone · ${w.title}';
  final o = (plan.isRotating ? planOccasions(plan, w.dayKey, workouts, ahead: 0) : plan.occasions).where((o) => o.id == w.occasionId).firstOrNull;
  final state = plan.isArchived ? ' (archived)' : plan.isClosed ? ' (closed)' : plan.isPaused ? ' (paused)' : '';
  final step = o == null ? null : o.sequenceIndex != null ? 'session ${o.sequenceIndex! + 1} of the rotation' : 'week ${o.weekNumber}';
  return 'From ${plan.title}$state · ${w.title}${step == null ? '' : ' · $step'} · ${longDate(o?.scheduledDate ?? w.dayKey)}';
}

/// "5 exercises · 18 sets" from a prescription; set count is left out when no movement has a target.
String prescriptionSummary(List<Prescription> prescription) {
  final sets = prescription.fold(0, (n, e) => n + (e.targetSets ?? 0));
  return '${prescription.length} ${prescription.length == 1 ? 'exercise' : 'exercises'}${sets == 0 ? '' : ' · $sets sets'}';
}
