namespace GoHard.Api.Persistence;

// Units: *Kg = kilograms (canonical load), *Seconds = seconds, DayKey/…Date = calendar date (no zone),
// *AtUtc = UTC instant. Revision columns are server-controlled and increase by one per accepted change.

public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Appearance { get; set; } = "dark";
    public string LoadUnit { get; set; } = "kg";
    public bool RemindersEnabled { get; set; }
    public string? ReminderLocalTime { get; set; }
    // Optional daily goals the person set. Null = no goal; none is ever suggested or defaulted.
    public int? CalorieGoal { get; set; }
    public int? ProteinGoalG { get; set; }
    public int? WaterGoalMl { get; set; }
    // What the person chose to see in their nutrition (presentation only). Null = never chosen on the account.
    public bool? ShowWater { get; set; }
    public bool? ShowCarbs { get; set; }
    public bool? ShowFat { get; set; }
    public string? TrainingSetupJson { get; set; }
    public int Revision { get; set; } = 1;
    public string SecurityStamp { get; set; } = "";
    public DateTime CreatedAtUtc { get; set; }
}

public class RefreshToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = "";
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
    /// <summary>Set when revoked by rotation (not by logout): the row that replaced it. Marks the immediate predecessor that
    /// may recover its unused replacement within the recovery window (AuthService.RefreshAsync).</summary>
    public Guid? ReplacedById { get; set; }
}

/// <summary>Terminal record of one owner-scoped command. Retained so a lost response can be replayed.</summary>
public class Operation
{
    public Guid UserId { get; set; }
    public Guid OperationId { get; set; }
    public string Kind { get; set; } = "";
    public string RequestHash { get; set; } = "";
    public int HttpStatus { get; set; }
    public string ResponseJson { get; set; } = "";
    public DateTime CreatedAtUtc { get; set; }
}

public class TrainingContext
{
    public Guid UserId { get; set; }
    public Guid? PrimaryPlanId { get; set; }
    public int Revision { get; set; }
}

public class Plan
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Title { get; set; } = "";
    /// <summary>draft | active | paused | closed. Archive is visibility only.</summary>
    public string Lifecycle { get; set; } = PlanLifecycles.Draft;
    public string? ClosureIntent { get; set; }
    public bool IsArchived { get; set; }
    public DateOnly StartDate { get; set; }
    public int BlockWeeks { get; set; }
    public int MinRecoveryDays { get; set; }
    public string SetupJson { get; set; } = "{}";
    public string? BaselineId { get; set; }
    public DateOnly? PausedOn { get; set; }
    public DateOnly? ClosedOn { get; set; }
    // Built plans (docs/TRAINING_PLANS.md). All null/false on a plan from before the builder, which keeps SetupJson.
    /// <summary>The user's workout definitions, JSON list of WorkoutDefinition.</summary>
    public string? WorkoutsJson { get; set; }
    /// <summary>PlanSchedule JSON. Non-null marks a built (new-style) plan.</summary>
    public string? ScheduleJson { get; set; }
    public bool IsOngoing { get; set; }
    public int? TimeBudgetMinutes { get; set; }
    /// <summary>Display only: the starter template it was copied from. Nothing points back at the template.</summary>
    public string? TemplateId { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime CreatedAtUtc { get; set; }
    public List<Occasion> Occasions { get; set; } = [];
}

public static class PlanLifecycles
{
    public const string Draft = "draft", Active = "active", Paused = "paused", Closed = "closed";
}

public class Occasion
{
    public Guid Id { get; set; }
    public Guid PlanId { get; set; }
    public Guid UserId { get; set; }
    public int WeekNumber { get; set; }
    public int Ordinal { get; set; }
    public string Title { get; set; } = "";
    public DateOnly OriginalDate { get; set; }
    public DateOnly ScheduledDate { get; set; }
    public bool IsSkipped { get; set; }
    /// <summary>null until an actual workout qualifies it: full | partial.</summary>
    public string? ResultOutcome { get; set; }
    public Guid? ResultWorkoutId { get; set; }
    public string PrescriptionJson { get; set; } = "[]";
    /// <summary>The plan workout this occurrence was generated from (null on legacy occasions).</summary>
    public Guid? WorkoutId { get; set; }
    /// <summary>Rotating plans only: the position k in the sequence, unique within the plan.</summary>
    public int? SequenceIndex { get; set; }
    /// <summary>Edited on its own (plan.occasion); plan-wide revisions leave it as it is.</summary>
    public bool IsCustomised { get; set; }
}

public class Workout
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid? PlanId { get; set; }
    public Guid? OccasionId { get; set; }
    /// <summary>planned | manual</summary>
    public string Kind { get; set; } = "manual";
    public string Title { get; set; } = "";
    public DateOnly DayKey { get; set; }
    public DateTime StartedAtUtc { get; set; }
    public DateTime? FinishedAtUtc { get; set; }
    public int? ActiveDurationSeconds { get; set; }
    /// <summary>null while open: full | partial | no_data | manual_recorded.</summary>
    public string? Outcome { get; set; }
    public int PerformedSets { get; set; }
    public int PerformedExercises { get; set; }
    public bool QualifiedOccasion { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime? DeletedAtUtc { get; set; }
    public List<WorkoutExercise> Exercises { get; set; } = [];
}

public class WorkoutExercise
{
    public Guid Id { get; set; }
    public Guid WorkoutId { get; set; }
    public Guid UserId { get; set; }
    public int Ordinal { get; set; }
    public string Name { get; set; } = "";
    public string? CatalogKey { get; set; }
    public string? OccurrenceKey { get; set; }
    public bool IsPrescribed { get; set; }
    public bool IsTimed { get; set; }
    public int? TargetSets { get; set; }
    public int? TargetRepsMin { get; set; }
    public int? TargetRepsMax { get; set; }
    public int? TargetDurationSeconds { get; set; }
    public int? RestSeconds { get; set; }
    public string? SubstitutedForKey { get; set; }
    /// <summary>A target the user set in the plan. Never filled in by the app.</summary>
    public decimal? TargetLoadKg { get; set; }
    public string? Notes { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
    public List<WorkoutSet> Sets { get; set; } = [];
}

public class WorkoutSet
{
    public Guid Id { get; set; }
    public Guid ExerciseId { get; set; }
    public Guid WorkoutId { get; set; }
    public Guid UserId { get; set; }
    public int? Reps { get; set; }
    public decimal? LoadKg { get; set; }
    public int? DurationSeconds { get; set; }
    public DateTime PerformedAtUtc { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime? DeletedAtUtc { get; set; }
}

public class FoodEntry
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DateOnly DayKey { get; set; }
    public string Meal { get; set; } = "";
    public string Name { get; set; } = "";
    public string AmountDescription { get; set; } = "";
    // Null = unknown. Zero = the user entered zero. Never default these.
    public decimal? Calories { get; set; }
    public decimal? ProteinG { get; set; }
    public decimal? CarbsG { get; set; }
    public decimal? FatG { get; set; }
    // entered | unknown | imported
    public string CaloriesSource { get; set; } = "unknown";
    public string ProteinSource { get; set; } = "unknown";
    public string CarbsSource { get; set; } = "unknown";
    public string FatSource { get; set; } = "unknown";
    /// <summary>
    /// Where the values came from, as they were when this was logged: the food, its basis, the quantity eaten.
    /// A snapshot, so a later change at the provider or to a saved food never rewrites this meal. Null = typed by hand.
    /// </summary>
    public string? SourceJson { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
}

/// <summary>Water the person deliberately logged. Never derived from foods.</summary>
public class WaterEntry
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DateOnly DayKey { get; set; }
    public decimal VolumeMl { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
}

/// <summary>
/// A reusable food definition the person keeps: one they wrote, a provider food they corrected, or a favourite.
/// Saving one never records anything as eaten.
/// </summary>
public class SavedFood
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    /// <summary>The food in the normalized shape (name, basis, nutrients, servings, origin).</summary>
    public string ItemJson { get; set; } = "{}";
    public bool IsFavourite { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? DeletedAtUtc { get; set; }
}

/// <summary>An exercise the person defined. Private to its owner; prescriptions name it as "custom:&lt;id&gt;".</summary>
public class CustomExercise
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public string Equipment { get; set; } = "";
    public bool IsTimed { get; set; }
    /// <summary>Hidden from pickers; stays valid in existing plans and history.</summary>
    public bool IsArchived { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime CreatedAtUtc { get; set; }
}

public class CatalogExercise
{
    public string Key { get; set; } = "";
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public string Equipment { get; set; } = "";
    public bool IsTimed { get; set; }
}

public class Run
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DateOnly DayKey { get; set; }
    public DateTime StartedAtUtc { get; set; }
    public DateTime? FinishedAtUtc { get; set; }
    public int? ActiveDurationSeconds { get; set; }
    public decimal? DistanceMeters { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime? DeletedAtUtc { get; set; }
    /// <summary>run | walk (docs/RUN_WALK.md). Existing rows are runs.</summary>
    public string ActivityType { get; set; } = "run";
    public string? Title { get; set; }
    public string? Notes { get; set; }
    /// <summary>Derived summary (bounded JSON object), recomputable from the route.</summary>
    public string? MetricsJson { get; set; }
    /// <summary>none | uploading | complete. Changes with route uploads, not with the record's revision.</summary>
    public string RouteState { get; set; } = "none";
    public int RouteChunkCount { get; set; }
}

/// <summary>
/// A bounded, ordered piece of an activity's route: the entries with seq 500·Index … 500·Index+499, stored as sent.
/// Private account data, erased with the activity and with the account.
/// </summary>
public class RouteChunk
{
    public Guid UserId { get; set; }
    public Guid RunId { get; set; }
    public int Index { get; set; }
    public int FirstSeq { get; set; }
    public int LastSeq { get; set; }
    public int EntryCount { get; set; }
    public string EntriesJson { get; set; } = "[]";
    /// <summary>SHA-256 of the entries: the same chunk sent again is accepted, a different one is a conflict.</summary>
    public string Sha256 { get; set; } = "";
    public DateTime CreatedAtUtc { get; set; }
}

public class BodyMetric
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DateOnly DayKey { get; set; }
    public decimal? WeightKg { get; set; }
    public decimal? BodyFatPercent { get; set; }
    public string? Note { get; set; }
    public int Revision { get; set; } = 1;
    public DateTime? DeletedAtUtc { get; set; }
}

public class Proposal
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid PlanId { get; set; }
    /// <summary>schedule | substitution</summary>
    public string Kind { get; set; } = "";
    /// <summary>open | accepted | declined | needs_review</summary>
    public string State { get; set; } = "open";
    public int BasePlanRevision { get; set; }
    public string EvidenceHash { get; set; } = "";
    public string ChangeJson { get; set; } = "{}";
    public string Explanation { get; set; } = "";
    public int Revision { get; set; } = 1;
    public DateTime CreatedAtUtc { get; set; }
}
