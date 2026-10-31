import '../../data/models.dart';
import 'progress.dart';
import 'result_rules.dart';

/// Next-target suggestions from recorded sessions (docs/PROGRESSION.md). Pure and deterministic: no request, no AI,
/// works offline. These are GoHard product rules, not a clinically validated algorithm.

enum ProgressionDecision {
  /// Both of the newest two comparable sessions reached the top of the range at the target: one increment up.
  increase,

  /// Two comparable sessions exist at the current target, but they do not both qualify.
  keepCurrent,

  /// Fewer than two comparable sessions at the current target.
  moreSessions,

  /// It would qualify, but no increment is saved for this exercise.
  configureIncrement,

  /// The saved increment is more than [ProgressionRules.maxStepFraction] of the target: left to a manual review.
  incrementTooLarge,

  /// Supported, but there is no positive load target or no set count and rep range to compare against.
  setBaseline,

  /// Timed, bodyweight or assisted, or no stable identity: manual targets only, never a calculated load.
  unsupported,
}

/// Why a session did not qualify (or why there is no suggestion), for short factual explanations.
enum ProgressionReason {
  none, timed, bodyweight, assisted, noIdentity, noLoadTarget, noRange,
  fewerSessions, targetChanged, partialWorkout, missingExercise, setsMissing, extraSets, loadUnknown, loadDiffers, belowTop,
  /// Suggested today (reps): a set outside the planned range, or every set already at the top of it.
  outsideRange, atTop,
}

/// What "Suggested today" offers for one exercise of an open workout (docs/PLAN_LIBRARY_OVERLOAD.md › 5).
enum TodayKind {
  /// No personalised suggestion: the plan and the last session are shown as they are.
  none,

  /// The existing two-session rule qualifies: one saved increment more, for the planned reps.
  weight,

  /// The newest session qualifies for one more rep in total, at the same weight.
  reps,

  /// The weight rule qualifies but no increment is saved: the increment editor, never an invented step.
  chooseIncrement,
}

class TodaySuggestion {
  const TodaySuggestion(this.kind, this.reason, {this.loadKg, this.lastTotal, this.sets, this.repsMin, this.repsMax, this.sessions = const [], this.weight});
  final TodayKind kind;

  /// Why there is no suggestion ([ProgressionReason.none] when there is one).
  final ProgressionReason reason;

  /// weight: the suggested load; reps: the load kept from the last session.
  final double? loadKg;

  /// reps: the total recorded across the planned sets last time (the aim is one more).
  final int? lastTotal;
  final int? sets, repsMin, repsMax;

  /// The sessions the suggestion comes from, newest first.
  final List<ProgressionSession> sessions;

  /// The next-target result it reuses, when the weight rule decided.
  final ProgressionResult? weight;
  int? get aimTotal => lastTotal == null ? null : lastTotal! + 1;
}

/// One comparable session: the workout, its frozen exercise and the sets recorded for it, in order.
class ProgressionSession {
  const ProgressionSession(this.workout, this.exercise, this.sets, this.reason);
  final Workout workout;
  final WorkoutExercise? exercise;
  final List<WorkoutSet> sets;

  /// [ProgressionReason.none] when this session qualifies.
  final ProgressionReason reason;
  bool get qualifies => reason == ProgressionReason.none;
}

class ProgressionResult {
  const ProgressionResult(this.decision, this.reason, {this.targetKg, this.proposedKg, this.incrementKg, this.sets, this.repsMin, this.repsMax, this.sessions = const [], this.lastLoadKg});
  final ProgressionDecision decision;
  final ProgressionReason reason;
  final double? targetKg, proposedKg, incrementKg;
  final int? sets, repsMin, repsMax;

  /// The newest two comparable sessions (or fewer), newest first: the evidence shown with the result.
  final List<ProgressionSession> sessions;

  /// The last known load recorded for this exercise in this plan workout: only ever copied into a form on request.
  final double? lastLoadKg;

  /// Shown after a workout and in the preview: something the person can act on.
  bool get actionable => decision == ProgressionDecision.increase || decision == ProgressionDecision.configureIncrement;

  /// The newest supporting session: a "Keep current target" is remembered against it.
  String? get sourceWorkoutId => sessions.firstOrNull?.workout.id;

  /// Changes whenever the evidence changes (a corrected set, a removed workout), so a dismissed suggestion comes back
  /// only when it would be computed from different facts.
  String get fingerprint => [
        decision.name, targetKg, proposedKg,
        for (final s in sessions) ...[s.workout.id, for (final x in s.sets) '${x.id}:${x.loadKg}:${x.reps}'],
      ].join('|');
}

abstract final class ProgressionRules {
  /// Product guard: one automatic step may be at most 5% of the current target. Not a medical safety threshold.
  static const maxStepFraction = 0.05;

  /// Loads are stored to the gram; anything closer than this is the same load.
  static const _sameLoadKg = 0.01;

  static bool sameLoad(double? a, double? b) => a != null && b != null && (a - b).abs() < _sameLoadKg;

  /// Rounded to the precision the account stores, so a target and a set typed in the same unit compare equal.
  static double round3(double kg) => (kg * 1000).roundToDouble() / 1000;

  /// Whether a load can be suggested for this exercise at all. [equipment] is the catalogue's or the owner's own.
  static ProgressionReason support(Prescription rx, String? equipment) {
    if (rx.catalogKey == null) return ProgressionReason.noIdentity;
    if (rx.isTimed) return ProgressionReason.timed;
    if ((equipment ?? '').toLowerCase() == 'bodyweight') return ProgressionReason.bodyweight;
    if ('${rx.catalogKey} ${rx.name}'.toLowerCase().contains('assist')) return ProgressionReason.assisted;
    return ProgressionReason.none;
  }

  /// [rx] is the exercise as the plan's workout definition [definitionId] holds it now. [definitionOf] names the plan
  /// definition a workout's occasion belongs to (null: unknown, so not comparable). [sets] must already exclude
  /// deleted sets and sets awaiting conflict review. [incrementKg] is the person's saved step for this exercise.
  static ProgressionResult evaluate({
    required String planId,
    required String definitionId,
    required Prescription rx,
    required String? equipment,
    required List<Workout> workouts,
    required List<WorkoutSet> sets,
    required String? Function(String occasionId) definitionOf,
    required double? incrementKg,
  }) {
    final unsupported = support(rx, equipment);
    if (unsupported != ProgressionReason.none) return ProgressionResult(ProgressionDecision.unsupported, unsupported);
    final comparable = _comparable(planId, definitionId, workouts, definitionOf);
    double? lastLoad;
    for (final w in comparable) {
      final e = _exercise(w, rx);
      final loads = [for (final s in sets) if (e != null && s.exerciseId == e.id && !s.isDeleted && (s.loadKg ?? 0) > 0) s]..sort((a, b) => a.performedAtUtc.compareTo(b.performedAtUtc));
      if (loads.isNotEmpty) {
        lastLoad = loads.last.loadKg;
        break;
      }
    }
    final target = rx.targetLoadKg, n = rx.targetSets, lo = rx.targetRepsMin, hi = rx.targetRepsMax;
    if (target == null || target <= 0) return ProgressionResult(ProgressionDecision.setBaseline, ProgressionReason.noLoadTarget, sets: n, repsMin: lo, repsMax: hi, lastLoadKg: lastLoad);
    if (n == null || lo == null || hi == null) return ProgressionResult(ProgressionDecision.setBaseline, ProgressionReason.noRange, targetKg: target, sets: n, repsMin: lo, repsMax: hi, lastLoadKg: lastLoad);

    // Only the newest two are judged: an older success is never reached past a newer session that did not qualify.
    final sessions = [for (final w in comparable.take(2)) _session(w, rx, sets)];
    ProgressionResult result(ProgressionDecision d, ProgressionReason r, {double? proposed}) => ProgressionResult(d, r,
        targetKg: target, proposedKg: proposed, incrementKg: incrementKg, sets: n, repsMin: lo, repsMax: hi, sessions: sessions, lastLoadKg: lastLoad);

    // A session on another prescription is not evidence for this one: the newest one decides "more needed".
    final onCurrent = sessions.takeWhile((s) => s.reason != ProgressionReason.targetChanged).length;
    if (onCurrent < 2) return result(ProgressionDecision.moreSessions, sessions.isNotEmpty && onCurrent == 0 ? ProgressionReason.targetChanged : ProgressionReason.fewerSessions);
    final failed = sessions.where((s) => !s.qualifies).firstOrNull;
    if (failed != null) return result(ProgressionDecision.keepCurrent, failed.reason);
    if (incrementKg == null || incrementKg <= 0) return result(ProgressionDecision.configureIncrement, ProgressionReason.none);
    if (incrementKg > target * maxStepFraction + 1e-9) return result(ProgressionDecision.incrementTooLarge, ProgressionReason.none);
    return result(ProgressionDecision.increase, ProgressionReason.none, proposed: round3(target + incrementKg));
  }

  /// The finished sessions of this plan workout that count as training, newest first.
  static List<Workout> _comparable(String planId, String definitionId, List<Workout> workouts, String? Function(String occasionId) definitionOf) => [
        for (final w in workouts)
          if (countsAsTraining(w) && !w.isOpen && w.planId == planId && w.occasionId != null && definitionOf(w.occasionId!) == definitionId) w,
      ]..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));

  /// Suggested today for one exercise of an open workout. [rx] is the prescription frozen into this workout (never the
  /// plan's later edits), so the suggestion is about what this workout plans. The weight rule is [evaluate] unchanged;
  /// only when it does not apply, the newest comparable session alone may suggest one more rep in total.
  static TodaySuggestion today({
    required String planId,
    required String definitionId,
    required Prescription rx,
    required String? equipment,
    required List<Workout> workouts,
    required List<WorkoutSet> sets,
    required String? Function(String occasionId) definitionOf,
    required double? incrementKg,
  }) {
    final w = evaluate(planId: planId, definitionId: definitionId, rx: rx, equipment: equipment, workouts: workouts, sets: sets, definitionOf: definitionOf, incrementKg: incrementKg);
    final n = rx.targetSets, lo = rx.targetRepsMin, hi = rx.targetRepsMax;
    TodaySuggestion none(ProgressionReason r, [List<ProgressionSession> s = const []]) => TodaySuggestion(TodayKind.none, r, sets: n, repsMin: lo, repsMax: hi, sessions: s, weight: w);
    if (w.decision == ProgressionDecision.unsupported) return none(w.reason);
    if (w.decision == ProgressionDecision.increase) {
      return TodaySuggestion(TodayKind.weight, ProgressionReason.none, loadKg: w.proposedKg, sets: n, repsMin: lo, repsMax: hi, sessions: w.sessions, weight: w);
    }
    if (w.decision == ProgressionDecision.configureIncrement) {
      return TodaySuggestion(TodayKind.chooseIncrement, ProgressionReason.none, sets: n, repsMin: lo, repsMax: hi, sessions: w.sessions, weight: w);
    }
    // Weight is not suggested now (a step too large stays a manual review); the newest session decides reps.
    if (w.decision == ProgressionDecision.incrementTooLarge || n == null || lo == null || hi == null) return none(ProgressionReason.noRange);
    final newest = _comparable(planId, definitionId, workouts, definitionOf).firstOrNull;
    if (newest == null) return none(ProgressionReason.fewerSessions);
    final e = _exercise(newest, rx);
    if (e == null) return none(ProgressionReason.missingExercise, [ProgressionSession(newest, null, const [], ProgressionReason.missingExercise)]);
    final mine = [for (final s in sets) if (s.exerciseId == e.id && !s.isDeleted) s]..sort((a, b) => a.performedAtUtc.compareTo(b.performedAtUtc));
    ProgressionSession session(ProgressionReason r) => ProgressionSession(newest, e, mine, r);
    TodaySuggestion refuse(ProgressionReason r) => none(r, [session(r)]);
    final sameTarget = rx.targetLoadKg == null ? e.targetLoadKg == null : sameLoad(e.targetLoadKg, rx.targetLoadKg);
    if (!sameTarget || e.targetSets != n || e.targetRepsMin != lo || e.targetRepsMax != hi) return refuse(ProgressionReason.targetChanged);
    if (newest.outcome == WorkoutResultRules.partial) return refuse(ProgressionReason.partialWorkout);
    if (mine.length < n) return refuse(ProgressionReason.setsMissing);
    if (mine.length > n) return refuse(ProgressionReason.extraSets);
    if (mine.any((x) => x.loadKg == null || x.loadKg! <= 0)) return refuse(ProgressionReason.loadUnknown);
    final load = mine.first.loadKg!;
    // One weight on every set, and the one this workout plans when it plans one: otherwise the reps are not comparable.
    if (mine.any((x) => !sameLoad(x.loadKg, load)) || (rx.targetLoadKg != null && !sameLoad(load, rx.targetLoadKg))) return refuse(ProgressionReason.loadDiffers);
    if (mine.any((x) => x.reps == null || x.reps! < lo || x.reps! > hi)) return refuse(ProgressionReason.outsideRange);
    final total = mine.fold(0, (a, x) => a + x.reps!);
    if (total >= n * hi) return refuse(ProgressionReason.atTop);
    return TodaySuggestion(TodayKind.reps, ProgressionReason.none, loadKg: load, lastTotal: total, sets: n, repsMin: lo, repsMax: hi, sessions: [session(ProgressionReason.none)], weight: w);
  }

  /// The same exercise in the same place of the workout: its occurrence key and identity, as planned (not a swap).
  static WorkoutExercise? _exercise(Workout w, Prescription rx) =>
      w.exercises.where((x) => x.isPrescribed && x.occurrenceKey == rx.occurrenceKey && x.catalogKey == rx.catalogKey && x.substitutedForKey == null).firstOrNull;

  static ProgressionSession _session(Workout w, Prescription rx, List<WorkoutSet> all) {
    final e = _exercise(w, rx);
    if (e == null) return ProgressionSession(w, null, const [], ProgressionReason.missingExercise);
    final mine = [for (final s in all) if (s.exerciseId == e.id && !s.isDeleted) s]..sort((a, b) => a.performedAtUtc.compareTo(b.performedAtUtc));
    ProgressionSession s(ProgressionReason r) => ProgressionSession(w, e, mine, r);
    // Its frozen prescription must be the one being judged: same load, set count and rep range.
    if (!sameLoad(e.targetLoadKg, rx.targetLoadKg) || e.targetSets != rx.targetSets || e.targetRepsMin != rx.targetRepsMin || e.targetRepsMax != rx.targetRepsMax) {
      return s(ProgressionReason.targetChanged);
    }
    if (w.outcome == WorkoutResultRules.partial) return s(ProgressionReason.partialWorkout);
    if (mine.length < rx.targetSets!) return s(ProgressionReason.setsMissing);
    // Warm-ups are not marked, so a set beyond the plan makes the comparison ambiguous.
    if (mine.length > rx.targetSets!) return s(ProgressionReason.extraSets);
    if (mine.any((x) => x.loadKg == null)) return s(ProgressionReason.loadUnknown); // unknown, never zero
    if (mine.any((x) => !sameLoad(x.loadKg, rx.targetLoadKg))) return s(ProgressionReason.loadDiffers);
    if (mine.any((x) => (x.reps ?? 0) < rx.targetRepsMax!)) return s(ProgressionReason.belowTop);
    return s(ProgressionReason.none);
  }
}
