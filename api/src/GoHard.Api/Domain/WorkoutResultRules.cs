namespace GoHard.Api.Domain;

/// <param name="TargetSets">null = unknown target; an unknown target can never produce a full result.</param>
public sealed record PrescribedExercise(Guid ExerciseId, int? TargetSets);
public sealed record PerformedSet(Guid ExerciseId, int? Reps, decimal? LoadKg, int? DurationSeconds, bool IsDeleted = false);
public sealed record WorkoutResult(string Outcome, int PerformedSets, int PerformedExercises, bool QualifiesOccasion);

/// <summary>Actual submitted sets decide the result. Targets and prefills never count. Mirrored in Dart.</summary>
public static class WorkoutResultRules
{
    public const string Full = "full", Partial = "partial", NoData = "no_data", ManualRecorded = "manual_recorded";

    public static bool IsPerformed(PerformedSet s) =>
        !s.IsDeleted && (s.LoadKg is null or >= 0) && ((s.Reps is > 0) || (s.DurationSeconds is > 0))
        && s.Reps is null or >= 0 && s.DurationSeconds is null or >= 0;

    public static WorkoutResult Evaluate(IReadOnlyList<PrescribedExercise> prescription, IReadOnlyList<PerformedSet> sets, bool isManual)
    {
        var performed = sets.Where(IsPerformed).ToList();
        var exercises = performed.Select(s => s.ExerciseId).Distinct().Count();
        if (performed.Count == 0) return new(NoData, 0, 0, false);
        if (isManual) return new(ManualRecorded, performed.Count, exercises, false);
        var full = prescription.Count > 0 && prescription.All(p =>
            p.TargetSets is > 0 && performed.Count(s => s.ExerciseId == p.ExerciseId) >= p.TargetSets);
        return new(full ? Full : Partial, performed.Count, exercises, true);
    }
}
