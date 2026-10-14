import '../../core/clock.dart';
import '../../data/models.dart';
import 'plan_rules.dart';

/// The outcome credited to an occasion: the account's value, or a locally finished workout not yet acknowledged.
String? occasionOutcome(Occasion o, Iterable<Workout> workouts) =>
    o.resultOutcome ?? workouts.where((w) => !w.isDeleted && w.occasionId == o.id && w.qualifiedOccasion).firstOrNull?.outcome;

Workout? openWorkoutFor(Occasion o, Iterable<Workout> workouts) => workouts.where((w) => w.isOpen && w.occasionId == o.id).firstOrNull;

/// The one list of a plan's occurrences that Today, Train and the occurrence sheet all read.
///
/// * Fixed-weekday and older plans: exactly their occasions.
/// * Rotating plans: occurrences the account has materialized, then ones started or credited on this phone that
///   the account has not confirmed yet, then the next `ahead` projected (virtual) occurrences. The sequence advances
///   only past an index that is credited or skipped; everything else stays next, whatever the date.
List<Occasion> planOccasions(Plan plan, String today, Iterable<Workout> workouts, {int ahead = 6}) {
  final schedule = plan.schedule;
  if (schedule == null || !schedule.isRotating) return plan.occasions;
  if (schedule.cycle.isEmpty) return const [];

  final materialized = {for (final o in plan.occasions) o.id: o};
  final linked = <String, List<Workout>>{};
  for (final w in workouts) {
    if (!w.isDeleted && w.planId == plan.id && w.occasionId != null) (linked[w.occasionId!] ??= []).add(w);
  }
  final defs = {for (final w in plan.workouts) w.id: w};
  final end = plan.endDate;

  // Every known index, plus room for gaps (a start that was later deleted on this phone).
  final highest = plan.occasions.fold<int>(-1, (m, o) => (o.sequenceIndex ?? -1) > m ? o.sequenceIndex! : m);
  final known = [materialized.length, highest + 1].reduce((a, b) => a > b ? a : b) + linked.length + 1;
  final out = <Occasion>[];
  final virtualIndexes = <int>[];
  for (var k = 0; k < known; k++) {
    final id = PlanRules.sequenceId(plan.id, k);
    final o = materialized[id];
    final ws = linked[id];
    if (o != null) {
      out.add(o);
    } else if (ws != null) {
      out.add(_fromWorkout(plan, id, k, ws, defs[PlanRules.workoutFor(schedule.cycle, schedule.cycleAnchor, k)]));
    } else {
      virtualIndexes.add(k);
    }
  }
  for (var k = known; virtualIndexes.length < ahead + known; k++) {
    virtualIndexes.add(k);
  }

  // Projected dates start after anything of this plan already started or done today or later, on the next training
  // day. A skip does not take a day: skipping today's workout makes the next one today's.
  var cursor = plan.startDate.compareTo(today) > 0 ? plan.startDate : today;
  for (final o in out) {
    if (!o.isSkipped && o.scheduledDate.compareTo(cursor) >= 0) cursor = addDays(o.scheduledDate, 1);
  }
  final days = schedule.trainingDays.toSet();
  var added = 0;
  for (final k in virtualIndexes) {
    if (added >= ahead) break;
    while (days.isNotEmpty && !days.contains(parseDayKey(cursor).weekday)) {
      cursor = addDays(cursor, 1);
    }
    if (end != null && cursor.compareTo(end) > 0) break;
    final def = defs[PlanRules.workoutFor(schedule.cycle, schedule.cycleAnchor, k)];
    if (def == null) break;
    out.add(Occasion({
      ...PlanRules.occurrence(id: PlanRules.sequenceId(plan.id, k), date: cursor, weekNumber: _weekOf(plan, cursor), ordinal: k + 1, workout: def.j, sequenceIndex: k),
      'isVirtual': true,
    }));
    cursor = addDays(cursor, 1);
    added++;
  }
  return out;
}

int _weekOf(Plan plan, String date) {
  final d = daysBetween(plan.startDate, date);
  return d < 0 ? 1 : d ~/ 7 + 1;
}

/// An occurrence this phone started (or finished) that the account has not materialized yet.
Occasion _fromWorkout(Plan plan, String id, int k, List<Workout> ws, WorkoutDefinition? def) {
  ws.sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));
  final credited = ws.where((w) => w.qualifiedOccasion && !w.isOpen).firstOrNull;
  final first = ws.first;
  return Occasion({
    'id': id, 'weekNumber': _weekOf(plan, first.dayKey), 'ordinal': k + 1, 'title': first.title, 'originalDate': first.dayKey, 'scheduledDate': first.dayKey,
    'isSkipped': false, 'resultOutcome': credited?.outcome, 'resultWorkoutId': credited?.id,
    'prescription': [
      for (final e in first.exercises)
        if (e.isPrescribed)
          {'occurrenceKey': e.occurrenceKey ?? '', 'catalogKey': e.catalogKey, 'name': e.name, 'isTimed': e.isTimed, 'targetSets': e.targetSets,
            'targetRepsMin': e.targetRepsMin, 'targetRepsMax': e.targetRepsMax, 'targetDurationSeconds': e.targetDurationSeconds, 'restSeconds': e.restSeconds,
            if (e.targetLoadKg != null) 'targetLoadKg': e.targetLoadKg, if (e.notes != null) 'notes': e.notes},
    ],
    'workoutId': def?.id, 'sequenceIndex': k, 'isCustomised': false,
  });
}

/// Where a rotating plan stands: the cycle, the next workout's position in it, and how many full cycles are done.
class Rotation {
  const Rotation({required this.cycle, required this.next, required this.position, required this.cyclesDone, required this.upcoming});

  /// The plan's workouts in cycle order (repeats included).
  final List<WorkoutDefinition> cycle;

  /// The next workout to do (a projected occurrence, or a materialized one still waiting with no open workout), or
  /// null at the plan's end.
  final Occasion? next;

  /// 0-based position of [next] in the cycle.
  final int position;

  /// Full passes through the cycle since it last changed.
  final int cyclesDone;

  /// [next] and the projected ones after it, in order.
  final List<Occasion> upcoming;
}

/// `occasions` is [planOccasions] for the same plan and workouts.
Rotation? rotationOf(Plan plan, List<Occasion> occasions, Iterable<Workout> workouts) {
  final s = plan.schedule;
  if (s == null || !s.isRotating || s.cycle.isEmpty) return null;
  final defs = {for (final w in plan.workouts) w.id: w};
  final pending = [for (final o in occasions) if (!o.isSkipped && occasionOutcome(o, workouts) == null) o];
  final next = pending.where((o) => openWorkoutFor(o, workouts) == null).firstOrNull;
  final k = next?.sequenceIndex ?? s.cycleAnchor;
  final since = k - s.cycleAnchor;
  return Rotation(
    cycle: [for (final id in s.cycle) if (defs[id] != null) defs[id]!],
    next: next, position: since < 0 ? 0 : since % s.cycle.length, cyclesDone: since < 0 ? 0 : since ~/ s.cycle.length,
    upcoming: [for (final o in pending) if (o.isVirtual) o],
  );
}
