import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../data/models.dart';

/// One generated fixed-weekday occurrence.
typedef FixedOccurrence = ({String id, String date, int weekNumber, int ordinal, String workoutId});

/// Pure rules for built plans, mirrored from the API's `PlanRules` and checked against the same fixture
/// (`contracts/contract_fixture.json` › plan*). Contract and reasoning: docs/TRAINING_PLANS.md.
abstract final class PlanRules {
  static const titleInvalid = 'TITLE_INVALID', durationInvalid = 'DURATION_INVALID', timeBudgetInvalid = 'TIME_BUDGET_INVALID',
      workoutsInvalid = 'WORKOUTS_INVALID', scheduleInvalid = 'SCHEDULE_INVALID', notUsable = 'PLAN_NOT_USABLE';

  static const _uuid = Uuid();
  static final _ids = <String, String>{};

  /// Occurrence IDs are UUIDv5 in the plan's namespace, so the phone, the account and every retry agree on them.
  static String fixedId(String planId, String date) => _ids.putIfAbsent('$planId|d:$date', () => _uuid.v5(planId, 'd:$date'));
  static String sequenceId(String planId, int k) => _ids.putIfAbsent('$planId|s:$k', () => _uuid.v5(planId, 's:$k'));

  /// Every occurrence of a fixed-weekday plan: each pattern day in order of its offset from the start, every week.
  static List<FixedOccurrence> fixedDates(String planId, String start, int weeks, List<({int weekday, String workoutId})> pattern) {
    final startWeekday = parseDayKey(start).weekday;
    final entries = [for (final p in pattern) (offset: (p.weekday - startWeekday + 7) % 7, workoutId: p.workoutId)]..sort((a, b) => a.offset.compareTo(b.offset));
    return [
      for (var w = 0; w < weeks; w++)
        for (final (i, e) in entries.indexed)
          (id: fixedId(planId, addDays(start, e.offset + 7 * w)), date: addDays(start, e.offset + 7 * w), weekNumber: w + 1, ordinal: i + 1, workoutId: e.workoutId),
    ];
  }

  /// The plan workout at sequence index `k` of a rotating plan. The cycle continues across weeks; `anchor` is where
  /// its first workout applies (it moves only when the user changes the cycle).
  static String workoutFor(List<String> cycle, int anchor, int k) => cycle[(k - anchor) % cycle.length];

  // ---------------------------------------------------------------- validation

  static bool _len(Object? s, int min, int max) => s is String && s.trim().length >= min && s.trim().length <= max;
  static bool _range(Object? v, num min, num max) => v == null || (v is num && v >= min && v <= max);

  /// Error codes for a plan body `{title, durationWeeks, timeBudgetMinutes, workouts, schedule}`, at most one per group.
  static List<String> validate(Json plan) {
    final errors = <String>[];
    final schedule = plan['schedule'] is Map ? plan['schedule'] as Json : const <String, dynamic>{};
    final rotating = schedule['mode'] == 'rotating';
    if (!_len(plan['title'], 1, 60)) errors.add(titleInvalid);
    final weeks = plan['durationWeeks'];
    if (weeks == null ? !rotating : !(weeks is int && weeks >= 1 && weeks <= 52)) errors.add(durationInvalid);
    final budget = plan['timeBudgetMinutes'];
    if (!(budget == null || (budget is int && budget >= 10 && budget <= 240))) errors.add(timeBudgetInvalid);

    final workouts = [for (final w in plan['workouts'] as List? ?? const []) w as Json];
    final ids = {for (final w in workouts) w['id']};
    if (workouts.isEmpty || workouts.length > 20 || ids.length != workouts.length || workouts.any((w) => !_workoutOk(w))) errors.add(workoutsInvalid);

    if (!_scheduleOk(schedule, ids)) errors.add(scheduleInvalid);
    return errors;
  }

  static bool _workoutOk(Json w) {
    final exercises = [for (final e in w['exercises'] as List? ?? const []) e as Json];
    final keys = {for (final e in exercises) e['occurrenceKey']};
    return _len(w['id'], 1, 64) && _len(w['name'], 1, 60) && (w['notes'] == null || _len(w['notes'], 0, 500)) &&
        exercises.length <= 30 && keys.length == exercises.length && exercises.every(_exerciseOk);
  }

  static bool _exerciseOk(Json e) {
    final lo = e['targetRepsMin'], hi = e['targetRepsMax'];
    return _len(e['occurrenceKey'], 1, 64) && _len(e['name'], 1, 120) && _range(e['targetSets'], 1, 20) && _range(lo, 1, 100) && _range(hi, 1, 100) &&
        (lo == null || hi == null || (lo as num) <= (hi as num)) && _range(e['targetDurationSeconds'], 1, 3600) && _range(e['restSeconds'], 0, 900) &&
        _range(e['targetLoadKg'], 0, 2000) && (e['notes'] == null || _len(e['notes'], 0, 500));
  }

  static bool _scheduleOk(Json s, Set<Object?> ids) {
    switch (s['mode']) {
      case 'fixed':
        final pattern = [for (final p in s['pattern'] as List? ?? const []) p as Json];
        final days = {for (final p in pattern) p['weekday']};
        return pattern.isNotEmpty && pattern.length <= 7 && days.length == pattern.length &&
            pattern.every((p) => p['weekday'] is int && (p['weekday'] as int) >= 1 && (p['weekday'] as int) <= 7 && ids.contains(p['workoutId']));
      case 'rotating':
        final cycle = s['cycle'] as List? ?? const [];
        final days = [for (final d in s['trainingDays'] as List? ?? const []) d];
        final anchor = s['cycleAnchor'];
        return cycle.isNotEmpty && cycle.length <= 30 && cycle.every(ids.contains) && days.toSet().length == days.length &&
            days.every((d) => d is int && d >= 1 && d <= 7) && anchor is int && anchor >= 0;
      default:
        return false;
    }
  }

  /// The workouts the schedule uses.
  static Set<String> scheduled(Json schedule) => schedule['mode'] == 'rotating'
      ? {for (final c in schedule['cycle'] as List? ?? const []) c as String}
      : {for (final p in schedule['pattern'] as List? ?? const []) (p as Json)['workoutId'] as String};

  /// Can be activated: every workout the schedule uses has at least one exercise. Otherwise it is a draft.
  static bool usable(Json plan) {
    final byId = {for (final w in plan['workouts'] as List? ?? const []) (w as Json)['id']: w};
    return scheduled(plan['schedule'] as Json).every((id) => ((byId[id]?['exercises'] as List?) ?? const []).isNotEmpty);
  }

  // ---------------------------------------------------------------- occurrences

  /// A new occurrence's own copy of its workout. Later edits to the workout change it only as `revise` allows.
  static Json occurrence({required String id, required String date, required int weekNumber, required int ordinal, required Json workout, int? sequenceIndex}) => {
        'id': id, 'weekNumber': weekNumber, 'ordinal': ordinal, 'title': workout['name'], 'originalDate': date, 'scheduledDate': date,
        'isSkipped': false, 'resultOutcome': null, 'resultWorkoutId': null, 'prescription': [for (final e in workout['exercises'] as List) copyJson(e as Map)],
        'workoutId': workout['id'], 'sequenceIndex': sequenceIndex, 'isCustomised': false,
      };

  /// Every occurrence of a new fixed-weekday plan.
  static List<Json> generate(String planId, String start, int weeks, Json schedule, List<Json> workouts) {
    final byId = {for (final w in workouts) w['id'] as String: w};
    return [
      for (final g in fixedDates(planId, start, weeks, PlanSchedule(schedule).pattern))
        occurrence(id: g.id, date: g.date, weekNumber: g.weekNumber, ordinal: g.ordinal, workout: byId[g.workoutId]!),
    ];
  }

  /// A plan-wide edit from `effective` on (docs/TRAINING_PLANS.md › Revising). `pending` are the IDs of occurrences
  /// that are not skipped, not credited and have no open workout. Recorded, skipped, open, earlier and individually
  /// edited occurrences keep their content and dates. Rotating plans keep every materialized occurrence.
  static List<Json> revise({required String planId, required String start, required int? weeks, required String effective,
      required List<Json> occasions, required Set<String> pending, required List<Json> workouts, required Json schedule}) {
    if (schedule['mode'] == 'rotating' || weeks == null) return [for (final o in occasions) copyJson(o)];
    final byId = {for (final w in workouts) w['id'] as String: w};
    final generated = [for (final g in fixedDates(planId, start, weeks, PlanSchedule(schedule).pattern)) if (g.date.compareTo(effective) >= 0) g];
    final genIds = {for (final g in generated) g.id};
    final existing = {for (final o in occasions) o['id'] as String: o};
    bool replaceable(Json o) => pending.contains(o['id']) && !(o['isCustomised'] as bool? ?? false);
    Json withContent(Json o, Json w) => copyJson(o)
      ..['workoutId'] = w['id']
      ..['title'] = w['name']
      ..['prescription'] = [for (final e in w['exercises'] as List) copyJson(e as Map)];

    final out = <Json>[];
    for (final o in occasions) {
      final id = o['id'] as String;
      if (!replaceable(o)) {
        out.add(copyJson(o));
      } else if (genIds.contains(id)) {
        continue; // taken from the generated list below
      } else if ((o['originalDate'] as String).compareTo(effective) >= 0 && (o['scheduledDate'] as String).compareTo(effective) >= 0) {
        continue; // the new pattern no longer has it (one moved to before the effective date is kept as it is)
      } else if ((o['scheduledDate'] as String).compareTo(effective) >= 0 && byId[o['workoutId']] != null) {
        out.add(withContent(o, byId[o['workoutId']]!)); // moved past the effective date: it follows its workout's new content
      } else {
        out.add(copyJson(o));
      }
    }
    for (final g in generated) {
      final o = existing[g.id];
      if (o != null && !replaceable(o)) continue;
      final fresh = occurrence(id: g.id, date: g.date, weekNumber: g.weekNumber, ordinal: g.ordinal, workout: byId[g.workoutId]!);
      out.add(o == null ? fresh : (withContent(o, byId[g.workoutId]!)..['weekNumber'] = g.weekNumber));
    }
    // Ordinals are a display key only: renumbered within each week so kept and added occurrences never share one.
    out.sort((a, b) {
      final c = (a['weekNumber'] as int).compareTo(b['weekNumber'] as int);
      if (c != 0) return c;
      final d = (a['originalDate'] as String).compareTo(b['originalDate'] as String);
      return d != 0 ? d : (a['id'] as String).compareTo(b['id'] as String);
    });
    var week = -1, n = 0;
    for (final o in out) {
      if (o['weekNumber'] != week) (week, n) = (o['weekNumber'] as int, 0);
      o['ordinal'] = ++n;
    }
    return out;
  }

  static String describe(String code) => switch (code) {
        titleInvalid => 'Give the plan a name of up to 60 characters.',
        durationInvalid => 'Choose a length between 1 and 52 weeks. Only a rotating sequence can run without an end.',
        timeBudgetInvalid => 'Choose a planned time between 10 and 240 minutes, or none.',
        workoutsInvalid => 'Check the workouts: each needs a name, and sets, reps, rest and weights must be in range.',
        scheduleInvalid => 'Check the schedule: every day or step needs a workout, with one workout per weekday.',
        notUsable => 'Add at least one exercise to every scheduled workout before you activate the plan.',
        'PLAN_NEEDS_NEWER_APP' => 'This plan was made with a newer version of the app. Update the app to change it.',
        'UNKNOWN_EXERCISE' => 'An exercise in this plan is not available to your account.',
        'START_LOCKED' => 'An active plan keeps its start date. Duplicate it to start again on another day.',
        'MODE_LOCKED' => 'An active plan keeps its schedule type. Duplicate it to switch between weekdays and a rotation.',
        'OCCASION_NOT_MOVABLE' => 'A rotating plan has no fixed dates. Skip the workout, or do it next time you train.',
        'EXERCISE_NAME_INVALID' => 'Give the exercise a name of up to 80 characters.',
        'PLAN_CHANGED_SINCE_EDIT' => 'This plan changed after you started editing it. Start again from the plan as it is now.',
        'PLAN_NOT_ACTIVE' => 'This plan is closed. Duplicate it to train with it again.',
        'TARGET_CONTEXT_CHANGED' => 'This exercise is no longer in that plan workout, so its target was not changed. Review the plan instead.',
        'TARGET_CHANGED_SINCE' => 'This target was changed again since then, so the earlier one was not restored. Edit it instead.',
        _ => 'That change could not be applied ($code).',
      };
}
