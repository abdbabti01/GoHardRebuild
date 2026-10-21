/// Actual submitted sets decide the result. Targets and prefills never count.
/// Mirrored from the API's `WorkoutResultRules` and checked against the same fixture.
library;

import '../../core/language.dart' show AppLocalizations, currentL10n;

class PrescribedExercise {
  const PrescribedExercise(this.exerciseId, this.targetSets);
  final String exerciseId;

  /// null = unknown target; an unknown target can never produce a full result.
  final int? targetSets;
}

class PerformedSet {
  const PerformedSet(this.exerciseId, {this.reps, this.loadKg, this.durationSeconds, this.isDeleted = false});
  final String exerciseId;
  final int? reps, durationSeconds;
  final double? loadKg;
  final bool isDeleted;
}

class WorkoutResult {
  const WorkoutResult(this.outcome, this.performedSets, this.performedExercises, this.qualifiesOccasion);
  final String outcome;
  final int performedSets, performedExercises;
  final bool qualifiesOccasion;
}

abstract final class WorkoutResultRules {
  static const full = 'full', partial = 'partial', noData = 'no_data', manualRecorded = 'manual_recorded';

  static bool isPerformed(PerformedSet s) =>
      !s.isDeleted &&
      (s.loadKg == null || (s.loadKg!.isFinite && s.loadKg! >= 0)) &&
      ((s.reps ?? 0) > 0 || (s.durationSeconds ?? 0) > 0) &&
      (s.reps == null || s.reps! >= 0) &&
      (s.durationSeconds == null || s.durationSeconds! >= 0);

  static WorkoutResult evaluate(List<PrescribedExercise> prescription, List<PerformedSet> sets, {required bool isManual}) {
    final performed = sets.where(isPerformed).toList();
    final exercises = performed.map((s) => s.exerciseId).toSet().length;
    if (performed.isEmpty) return const WorkoutResult(noData, 0, 0, false);
    if (isManual) return WorkoutResult(manualRecorded, performed.length, exercises, false);
    final isFull = prescription.isNotEmpty &&
        prescription.every((p) => (p.targetSets ?? 0) > 0 && performed.where((s) => s.exerciseId == p.exerciseId).length >= p.targetSets!);
    return WorkoutResult(isFull ? full : partial, performed.length, exercises, true);
  }

  /// The outcome as shown, in the resolved app language. Prefer [outcomeLabel] where a context is at hand.
  static String label(String? outcome) => outcomeLabel(currentL10n, outcome);
}

/// An outcome code as shown; the code itself is what is stored and compared.
String outcomeLabel(AppLocalizations l, String? outcome) => switch (outcome) {
      WorkoutResultRules.full => l.workoutOutcomeFull,
      WorkoutResultRules.partial => l.workoutOutcomePartial,
      WorkoutResultRules.noData => l.workoutOutcomeNoData,
      WorkoutResultRules.manualRecorded => l.workoutOutcomeManual,
      _ => l.workoutOutcomeOpen,
    };
