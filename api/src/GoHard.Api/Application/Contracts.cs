using GoHard.Api.Domain;

namespace GoHard.Api.Application;

// Wire contracts, contract version 1. Dates named *Date/DayKey are calendar "YYYY-MM-DD"; *AtUtc are UTC
// instants; *Seconds are seconds; *Kg are kilograms. Weekdays are ISO numbers, 1 = Monday … 7 = Sunday.

public sealed record PrescriptionExercise(string OccurrenceKey, string? CatalogKey, string Name, bool IsTimed,
    int? TargetSets, int? TargetRepsMin, int? TargetRepsMax, int? TargetDurationSeconds, int? RestSeconds);

public sealed record PlanSetup(string Direction, int SessionsPerWeek, int MinutesPerSession, string Equipment,
    string Experience, string? Limitations, int BlockWeeks, List<int> Weekdays, DateOnly StartDate);

public sealed record OccasionDto(Guid Id, int WeekNumber, int Ordinal, string Title, DateOnly OriginalDate,
    DateOnly ScheduledDate, bool IsSkipped, string? ResultOutcome, Guid? ResultWorkoutId, List<PrescriptionExercise> Prescription);

public sealed record PlanDto(Guid Id, string Title, string Lifecycle, string? ClosureIntent, bool IsArchived,
    DateOnly StartDate, int BlockWeeks, int MinRecoveryDays, PlanSetup? Setup, string? BaselineId,
    DateOnly? PausedOn, DateOnly? ClosedOn, int Revision, List<OccasionDto> Occasions);

public sealed record PlanContextDto(int ContextRevision, Guid? PrimaryPlanId, List<PlanDto> Plans);

public sealed record ManualWorkoutSpec(string Title, List<PrescriptionExercise> Exercises);
public sealed record PlanDraftRequest(Guid OperationId, Guid PlanId, PlanSetup Setup, string? Title, List<ManualWorkoutSpec>? ManualWorkouts);
public sealed record PlanDraftUpdateRequest(Guid OperationId, int ExpectedPlanRevision, DateOnly StartDate, List<int> Weekdays, int BlockWeeks, string? Title);
/// <param name="Kind">supported_draft | fit_feedback</param>
public sealed record PlanDraftResult(string Kind, PlanContextDto? Context, Guid? PlanId, List<string> Feedback);

public sealed record ReviewedDate(Guid OccasionId, DateOnly Date);
public sealed record ActivateRequest(Guid OperationId, int ExpectedContextRevision, int ExpectedPlanRevision, DateOnly StartDate,
    List<ReviewedDate> ReviewedDates, Guid? ReplacePrimaryId, bool ClosePrimary, DateOnly EffectiveDate);
public sealed record PauseRequest(Guid OperationId, int ExpectedContextRevision, int ExpectedPlanRevision, DateOnly EffectiveDate);
public sealed record ResumeRequest(Guid OperationId, int ExpectedContextRevision, int ExpectedPlanRevision,
    List<ScheduleChange> Changes, Guid? SwitchPrimaryFromId, DateOnly EffectiveDate);
/// <param name="Action">move | skip | unskip</param>
public sealed record ScheduleChangeRequest(Guid OperationId, int ExpectedPlanRevision, string Action, Guid OccasionId, DateOnly? From, DateOnly? To);
/// <param name="Intent">finish_for_now | stopped_early</param>
public sealed record CloseRequest(Guid OperationId, int ExpectedContextRevision, int ExpectedPlanRevision, string Intent, DateOnly EffectiveDate);
public sealed record ArchiveRequest(Guid OperationId, int ExpectedPlanRevision, bool IsArchived);
public sealed record ContinueRequest(Guid OperationId, Guid NewPlanId, DateOnly StartDate);

public sealed record ExerciseSpec(Guid Id, int Ordinal, string Name, string? CatalogKey, string? OccurrenceKey, bool IsPrescribed,
    bool IsTimed, int? TargetSets, int? TargetRepsMin, int? TargetRepsMax, int? TargetDurationSeconds, int? RestSeconds, string? SubstitutedForKey);
public sealed record SetDto(Guid Id, Guid ExerciseId, Guid WorkoutId, int? Reps, decimal? LoadKg, int? DurationSeconds,
    DateTime PerformedAtUtc, int Revision, bool IsDeleted);
public sealed record ExerciseDto(Guid Id, int Ordinal, string Name, string? CatalogKey, string? OccurrenceKey, bool IsPrescribed,
    bool IsTimed, int? TargetSets, int? TargetRepsMin, int? TargetRepsMax, int? TargetDurationSeconds, int? RestSeconds,
    string? SubstitutedForKey, bool IsDeleted, List<SetDto> Sets);
public sealed record WorkoutDto(Guid Id, Guid? PlanId, Guid? OccasionId, string Kind, string Title, DateOnly DayKey,
    DateTime StartedAtUtc, DateTime? FinishedAtUtc, int? ActiveDurationSeconds, string? Outcome, int PerformedSets,
    int PerformedExercises, bool QualifiedOccasion, int Revision, bool IsDeleted, List<ExerciseDto> Exercises);

/// <param name="Kind">planned | manual</param>
public sealed record StartWorkoutRequest(Guid OperationId, Guid WorkoutId, string Kind, Guid? OccasionId, string Title,
    DateOnly DayKey, DateTime StartedAtUtc, List<ExerciseSpec> Exercises);
public sealed record AddExerciseRequest(Guid OperationId, ExerciseSpec Exercise);
public sealed record OperationOnly(Guid OperationId);
public sealed record RevisionCommand(Guid OperationId, int ExpectedRevision);
public sealed record SetCreateRequest(Guid OperationId, Guid SetId, int? Reps, decimal? LoadKg, int? DurationSeconds, DateTime PerformedAtUtc);
public sealed record SetUpdateRequest(Guid OperationId, int ExpectedRevision, int? Reps, decimal? LoadKg, int? DurationSeconds);
public sealed record AcknowledgedSet(Guid Id, int Revision);
public sealed record FinishRequest(Guid OperationId, int ExpectedRevision, List<AcknowledgedSet> AcknowledgedSets,
    int ActiveDurationSeconds, DateTime FinishedAtUtc);

public sealed record Macros(decimal? Calories, decimal? Protein, decimal? Carbs, decimal? Fat);
/// <summary>Per nutrient: entered | unknown | imported.</summary>
public sealed record MacroProvenance(string Calories, string Protein, string Carbs, string Fat);
public sealed record FoodEntryDto(Guid Id, DateOnly DayKey, string Meal, string Name, string AmountDescription,
    Macros Macros, MacroProvenance Provenance, int Revision, bool IsDeleted);
public sealed record FoodCreateRequest(Guid OperationId, Guid EntryId, DateOnly DayKey, string Meal, string Name, string AmountDescription, Macros Macros);
public sealed record FoodUpdateRequest(Guid OperationId, int ExpectedRevision, DateOnly DayKey, string Meal, string Name, string AmountDescription, Macros Macros);

public sealed record RunDto(Guid Id, DateOnly DayKey, DateTime StartedAtUtc, DateTime? FinishedAtUtc, int? ActiveDurationSeconds,
    decimal? DistanceMeters, int Revision, bool IsDeleted);
public sealed record RunStartRequest(Guid OperationId, Guid RunId, DateOnly DayKey, DateTime StartedAtUtc);
public sealed record RunFinishRequest(Guid OperationId, int ExpectedRevision, int ActiveDurationSeconds, decimal? DistanceMeters, DateTime FinishedAtUtc);
public sealed record BodyMetricDto(Guid Id, DateOnly DayKey, decimal? WeightKg, decimal? BodyFatPercent, string? Note, int Revision, bool IsDeleted);
public sealed record BodyMetricRequest(Guid OperationId, Guid MetricId, DateOnly DayKey, decimal? WeightKg, decimal? BodyFatPercent, string? Note);

public sealed record ProfileUpdateRequest(Guid OperationId, int ExpectedRevision, string DisplayName, string Appearance, string LoadUnit,
    bool RemindersEnabled, string? ReminderLocalTime);
public sealed record DeleteAccountRequest(string Password);

public sealed record ProposalMove(Guid OccasionId, DateOnly From, DateOnly To);
public sealed record ProposalChange(List<ProposalMove> Moves, string? FromCatalogKey, string? ToCatalogKey, string? ToName, List<Guid> AffectedOccasionIds);
/// <param name="Kind">schedule | substitution</param>
public sealed record ProposalRequest(Guid OperationId, Guid ProposalId, Guid PlanId, string Kind, List<ProposalMove>? Moves,
    string? FromCatalogKey, string? ToCatalogKey);
public sealed record ProposalDto(Guid Id, Guid PlanId, string Kind, string State, int BasePlanRevision, ProposalChange Change,
    string Explanation, int Revision);
public sealed record ProposalDecision(Guid OperationId, int ExpectedProposalRevision, int? ExpectedPlanRevision);
public sealed record ProposalResult(ProposalDto Proposal, PlanContextDto? Context);

public sealed record CatalogExerciseDto(string Key, string Name, string Category, string Equipment, bool IsTimed);
public sealed record SnapshotDto(ProfileDto Profile, PlanContextDto Context, List<WorkoutDto> Workouts, List<FoodEntryDto> FoodEntries,
    List<RunDto> Runs, List<BodyMetricDto> BodyMetrics, List<ProposalDto> Proposals, List<CatalogExerciseDto> Catalog, DateTime ServerTimeUtc);
