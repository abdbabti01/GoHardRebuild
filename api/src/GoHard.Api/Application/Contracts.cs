using System.Text.Json;
using System.Text.Json.Serialization;
using GoHard.Api.Domain;

namespace GoHard.Api.Application;

// Wire contracts, contract version 1. Dates named *Date/DayKey are calendar "YYYY-MM-DD"; *AtUtc are UTC
// instants; *Seconds are seconds; *Kg are kilograms. Weekdays are ISO numbers, 1 = Monday … 7 = Sunday.

public sealed record PrescriptionExercise(string OccurrenceKey, string? CatalogKey, string Name, bool IsTimed,
    int? TargetSets, int? TargetRepsMin, int? TargetRepsMax, int? TargetDurationSeconds, int? RestSeconds,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? TargetLoadKg = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Notes = null);
// Fields marked with JsonIgnore(WhenWritingNull) are additive: left out when null, so a command recorded before them
// keeps its semantic hash. docs/TRAINING_PLANS.md › Wire contract.

public sealed record WorkoutDefinition(Guid Id, string Name, string? Notes, List<PrescriptionExercise> Exercises);
public sealed record PlanPatternEntry(int Weekday, Guid WorkoutId);
/// <param name="Mode">fixed | rotating</param>
public sealed record PlanSchedule(string Mode, List<PlanPatternEntry> Pattern, List<Guid> Cycle, List<int> TrainingDays, int CycleAnchor);

public sealed record PlanSetup(string Direction, int SessionsPerWeek, int MinutesPerSession, string Equipment,
    string Experience, string? Limitations, int BlockWeeks, List<int> Weekdays, DateOnly StartDate);

public sealed record OccasionDto(Guid Id, int WeekNumber, int Ordinal, string Title, DateOnly OriginalDate,
    DateOnly ScheduledDate, bool IsSkipped, string? ResultOutcome, Guid? ResultWorkoutId, List<PrescriptionExercise> Prescription,
    Guid? WorkoutId = null, int? SequenceIndex = null, bool IsCustomised = false);

public sealed record PlanDto(Guid Id, string Title, string Lifecycle, string? ClosureIntent, bool IsArchived,
    DateOnly StartDate, int BlockWeeks, int MinRecoveryDays, PlanSetup? Setup, string? BaselineId,
    DateOnly? PausedOn, DateOnly? ClosedOn, int Revision, List<OccasionDto> Occasions,
    List<WorkoutDefinition>? Workouts = null, PlanSchedule? Schedule = null, bool IsOngoing = false, int? TimeBudgetMinutes = null, string? TemplateId = null);

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
public sealed record ScheduleChangeRequest(Guid OperationId, int ExpectedPlanRevision, string Action, Guid OccasionId, DateOnly? From, DateOnly? To,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] int? SequenceIndex = null);
/// <param name="Intent">finish_for_now | stopped_early</param>
public sealed record CloseRequest(Guid OperationId, int ExpectedContextRevision, int ExpectedPlanRevision, string Intent, DateOnly EffectiveDate);
public sealed record ArchiveRequest(Guid OperationId, int ExpectedPlanRevision, bool IsArchived);
public sealed record ContinueRequest(Guid OperationId, Guid NewPlanId, DateOnly StartDate);
/// <param name="DurationWeeks">null = ongoing (rotating only).</param>
public sealed record PlanCreateRequest(Guid OperationId, Guid PlanId, string Title, DateOnly StartDate, int? DurationWeeks, int? TimeBudgetMinutes,
    string? TemplateId, List<WorkoutDefinition> Workouts, PlanSchedule Schedule);
public sealed record PlanReviseRequest(Guid OperationId, int ExpectedPlanRevision, DateOnly EffectiveDate, string Title, DateOnly StartDate,
    int? DurationWeeks, int? TimeBudgetMinutes, List<WorkoutDefinition> Workouts, PlanSchedule Schedule);
public sealed record OccasionEditRequest(Guid OperationId, int ExpectedPlanRevision, string Title, List<PrescriptionExercise> Prescription);
public sealed record CustomExerciseDto(Guid Id, string Name, string Category, string Equipment, bool IsTimed, bool IsArchived, int Revision);
/// <param name="ExpectedRevision">0 creates the exercise; otherwise the revision being replaced.</param>
public sealed record CustomExercisePutRequest(Guid OperationId, int ExpectedRevision, string Name, string Category, string Equipment, bool IsTimed, bool IsArchived);

public sealed record ExerciseSpec(Guid Id, int Ordinal, string Name, string? CatalogKey, string? OccurrenceKey, bool IsPrescribed,
    bool IsTimed, int? TargetSets, int? TargetRepsMin, int? TargetRepsMax, int? TargetDurationSeconds, int? RestSeconds, string? SubstitutedForKey,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? TargetLoadKg = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Notes = null);
public sealed record SetDto(Guid Id, Guid ExerciseId, Guid WorkoutId, int? Reps, decimal? LoadKg, int? DurationSeconds,
    DateTime PerformedAtUtc, int Revision, bool IsDeleted);
public sealed record ExerciseDto(Guid Id, int Ordinal, string Name, string? CatalogKey, string? OccurrenceKey, bool IsPrescribed,
    bool IsTimed, int? TargetSets, int? TargetRepsMin, int? TargetRepsMax, int? TargetDurationSeconds, int? RestSeconds,
    string? SubstitutedForKey, bool IsDeleted, List<SetDto> Sets,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? TargetLoadKg = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Notes = null);
public sealed record WorkoutDto(Guid Id, Guid? PlanId, Guid? OccasionId, string Kind, string Title, DateOnly DayKey,
    DateTime StartedAtUtc, DateTime? FinishedAtUtc, int? ActiveDurationSeconds, string? Outcome, int PerformedSets,
    int PerformedExercises, bool QualifiedOccasion, int Revision, bool IsDeleted, List<ExerciseDto> Exercises);

/// <param name="Kind">planned | manual</param>
public sealed record StartWorkoutRequest(Guid OperationId, Guid WorkoutId, string Kind, Guid? OccasionId, string Title,
    DateOnly DayKey, DateTime StartedAtUtc, List<ExerciseSpec> Exercises,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] Guid? PlanId = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] int? SequenceIndex = null);
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
    Macros Macros, MacroProvenance Provenance, int Revision, bool IsDeleted,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] JsonElement? Source = null);
// Source and Provenance are additive: a client that predates them leaves them out, and they are then left out of
// the command's semantic hash too, so a retry of an older command still matches what was recorded.
/// <param name="Source">Snapshot of the food and quantity the values were taken from; absent when typed by hand.</param>
/// <param name="Provenance">Absent: every given value counts as entered. Present: imported values are told from corrected ones.</param>
public sealed record FoodCreateRequest(Guid OperationId, Guid EntryId, DateOnly DayKey, string Meal, string Name, string AmountDescription, Macros Macros,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] JsonElement? Source = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] MacroProvenance? Provenance = null);
public sealed record FoodUpdateRequest(Guid OperationId, int ExpectedRevision, DateOnly DayKey, string Meal, string Name, string AmountDescription, Macros Macros,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] JsonElement? Source = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] MacroProvenance? Provenance = null);

public sealed record SavedFoodDto(Guid Id, JsonElement Item, bool IsFavourite, int Revision, bool IsDeleted);
/// <param name="ExpectedRevision">0 creates the food; otherwise the revision being replaced.</param>
public sealed record SavedFoodPutRequest(Guid OperationId, int ExpectedRevision, JsonElement Item, bool IsFavourite);

/// <param name="VolumeMl">Canonical millilitres, above 0 and at most 5,000 per entry, up to 3 decimals.</param>
public sealed record WaterEntryDto(Guid Id, DateOnly DayKey, decimal VolumeMl, int Revision, bool IsDeleted);
public sealed record WaterCreateRequest(Guid OperationId, Guid EntryId, DateOnly DayKey, decimal VolumeMl);
public sealed record WaterUpdateRequest(Guid OperationId, int ExpectedRevision, DateOnly DayKey, decimal VolumeMl);

/// <summary>A Run or Walk (docs/RUN_WALK.md). The fields after IsDeleted are additive: an older client ignores them.</summary>
/// <param name="ActivityType">run | walk. Every record from before Run / Walk is a run.</param>
/// <param name="Metrics">Derived summary for lists and other devices (bounded object), recomputable from the route.</param>
/// <param name="RouteState">none | uploading | complete: whether the account holds the whole route.</param>
public sealed record RunDto(Guid Id, DateOnly DayKey, DateTime StartedAtUtc, DateTime? FinishedAtUtc, int? ActiveDurationSeconds,
    decimal? DistanceMeters, int Revision, bool IsDeleted, string ActivityType = "run",
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Title = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Notes = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] JsonElement? Metrics = null,
    string RouteState = "none", int RouteChunkCount = 0);
public sealed record RunStartRequest(Guid OperationId, Guid RunId, DateOnly DayKey, DateTime StartedAtUtc,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? ActivityType = null);
public sealed record RunFinishRequest(Guid OperationId, int ExpectedRevision, int ActiveDurationSeconds, decimal? DistanceMeters, DateTime FinishedAtUtc,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Title = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Notes = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] JsonElement? Metrics = null);
/// <summary>An edit of a saved activity: type, title, notes and the reported distance (a correction keeps the GPS value in Metrics).</summary>
public sealed record RunUpdateRequest(Guid OperationId, int ExpectedRevision, string ActivityType, string? Title, string? Notes, decimal? DistanceMeters, JsonElement? Metrics);
/// <summary>Route chunk n holds the entries with seq 500n … 500n+499, in order (docs/RUN_WALK.md › Sync contract).</summary>
public sealed record RouteChunkRequest(Guid OperationId, int FirstSeq, int LastSeq, List<JsonElement> Entries);
public sealed record RouteChunkResult(Guid RunId, int Index, int EntryCount);
public sealed record RouteCompleteRequest(Guid OperationId, int ChunkCount, int EntryCount);
public sealed record RouteChunkDto(int Index, int FirstSeq, int LastSeq, JsonElement Entries);
public sealed record RoutePage(Guid RunId, string RouteState, int ChunkCount, List<RouteChunkDto> Chunks, int? NextIndex);
public sealed record BodyMetricDto(Guid Id, DateOnly DayKey, decimal? WeightKg, decimal? BodyFatPercent, string? Note, int Revision, bool IsDeleted);
public sealed record BodyMetricRequest(Guid OperationId, Guid MetricId, DateOnly DayKey, decimal? WeightKg, decimal? BodyFatPercent, string? Note);

/// <param name="CalorieGoal">Left out: the stored goal is kept. Null: it is cleared. A number: it is set (500 to 10,000 kcal).</param>
/// <param name="ProteinGoal">Same three cases, 10 to 500 g.</param>
/// <param name="WaterGoalMl">Same three cases, 100 to 10,000 mL.</param>
/// <param name="ShowWater">Left out or null: the stored choice is kept. True or false: it is set. Hiding never touches records or goals.</param>
public sealed record ProfileUpdateRequest(Guid OperationId, int ExpectedRevision, string DisplayName, string Appearance, string LoadUnit,
    bool RemindersEnabled, string? ReminderLocalTime,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)] OptionalInt CalorieGoal = default,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)] OptionalInt ProteinGoal = default,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)] OptionalInt WaterGoalMl = default,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] bool? ShowWater = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] bool? ShowCarbs = null,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] bool? ShowFat = null);
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
    List<RunDto> Runs, List<BodyMetricDto> BodyMetrics, List<ProposalDto> Proposals, List<CatalogExerciseDto> Catalog, DateTime ServerTimeUtc, List<SavedFoodDto>? SavedFoods = null,
    List<CustomExerciseDto>? CustomExercises = null, List<WaterEntryDto>? WaterEntries = null);
