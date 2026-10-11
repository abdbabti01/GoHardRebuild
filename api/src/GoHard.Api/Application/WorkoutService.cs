using GoHard.Api.Domain;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>
/// Actual workouts, sets and the single finish operation. There is deliberately no background job that
/// completes or deletes workouts: only explicit owner commands change them, however old they are.
/// </summary>
public sealed class WorkoutService(GoHardDb db)
{
    public static SetDto ToDto(WorkoutSet s) =>
        new(s.Id, s.ExerciseId, s.WorkoutId, s.Reps, s.LoadKg, s.DurationSeconds, s.PerformedAtUtc, s.Revision, s.DeletedAtUtc != null);

    public static WorkoutDto ToDto(Workout w) => new(w.Id, w.PlanId, w.OccasionId, w.Kind, w.Title, w.DayKey, w.StartedAtUtc, w.FinishedAtUtc,
        w.ActiveDurationSeconds, w.Outcome, w.PerformedSets, w.PerformedExercises, w.QualifiedOccasion, w.Revision, w.DeletedAtUtc != null,
        w.Exercises.OrderBy(e => e.Ordinal).Select(e => new ExerciseDto(e.Id, e.Ordinal, e.Name, e.CatalogKey, e.OccurrenceKey, e.IsPrescribed,
            e.IsTimed, e.TargetSets, e.TargetRepsMin, e.TargetRepsMax, e.TargetDurationSeconds, e.RestSeconds, e.SubstitutedForKey,
            e.DeletedAtUtc != null, e.Sets.OrderBy(s => s.PerformedAtUtc).Select(ToDto).ToList())).ToList());

    /// <summary>Normalizes an instant to UTC at PostgreSQL's microsecond precision, so an acknowledgement equals what is stored.</summary>
    public static DateTime Utc(DateTime t)
    {
        var utc = t.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(t, DateTimeKind.Utc) : t.ToUniversalTime();
        return new DateTime(utc.Ticks - utc.Ticks % 10, DateTimeKind.Utc);
    }

    private Task<Workout?> WorkoutAsync(Guid userId, Guid id, CancellationToken ct) =>
        db.Workouts.Include(w => w.Exercises).ThenInclude(e => e.Sets).FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId, ct);

    private static bool ValidSpec(ExerciseSpec e) => e.Id != Guid.Empty && !string.IsNullOrWhiteSpace(e.Name) && e.Name.Length <= 120 &&
        e.TargetSets is null or >= 0 and <= 50 && e.RestSeconds is null or >= 0 and <= 3600 &&
        e.TargetRepsMin is null or >= 0 && e.TargetRepsMax is null or >= 0 && e.TargetDurationSeconds is null or >= 0;

    private static WorkoutExercise ToEntity(ExerciseSpec e, Guid workoutId, Guid userId) => new()
    {
        Id = e.Id, WorkoutId = workoutId, UserId = userId, Ordinal = e.Ordinal, Name = e.Name.Trim(), CatalogKey = e.CatalogKey,
        OccurrenceKey = e.OccurrenceKey, IsPrescribed = e.IsPrescribed, IsTimed = e.IsTimed, TargetSets = e.TargetSets,
        TargetRepsMin = e.TargetRepsMin, TargetRepsMax = e.TargetRepsMax, TargetDurationSeconds = e.TargetDurationSeconds,
        RestSeconds = e.RestSeconds, SubstitutedForKey = e.SubstitutedForKey,
    };

    public async Task<Outcome<WorkoutDto>> StartAsync(Guid userId, StartWorkoutRequest r, CancellationToken ct)
    {
        if (r.WorkoutId == Guid.Empty || string.IsNullOrWhiteSpace(r.Title) || r.Title.Length > 120 || r.Kind is not ("planned" or "manual") ||
            (r.Exercises ?? []).Any(e => !ValidSpec(e)) || (r.Exercises ?? []).Select(e => e.Id).Distinct().Count() != (r.Exercises ?? []).Count)
            return Outcome.Rejected<WorkoutDto>(Ack.Invalid);
        if (await db.Workouts.AnyAsync(w => w.Id == r.WorkoutId, ct)) return Outcome.Conflict<WorkoutDto>("DUPLICATE_ID");

        Guid? planId = null;
        if (r.Kind == "planned")
        {
            var occasion = await db.Occasions.FirstOrDefaultAsync(o => o.Id == r.OccasionId && o.UserId == userId, ct);
            if (occasion is null) return Outcome.NotFound<WorkoutDto>();
            // Checked under the account lock, so a concurrent skip or second start cannot both win.
            var open = await db.Workouts.Include(w => w.Exercises).ThenInclude(e => e.Sets)
                .FirstOrDefaultAsync(w => w.OccasionId == occasion.Id && w.FinishedAtUtc == null && w.DeletedAtUtc == null, ct);
            if (occasion.IsSkipped || occasion.ResultOutcome != null || open != null)
                return Outcome.Conflict("OCCASION_NOT_ELIGIBLE", open?.Revision ?? 0, open is null ? null : ToDto(open));
            planId = occasion.PlanId;
        }
        else if (r.OccasionId is not null) return Outcome.Rejected<WorkoutDto>(Ack.Invalid); // manual work never links silently

        // The exercises sent at start are the frozen prescription snapshot for this workout.
        var workout = new Workout
        {
            Id = r.WorkoutId, UserId = userId, PlanId = planId, OccasionId = r.OccasionId, Kind = r.Kind, Title = r.Title.Trim(),
            DayKey = r.DayKey, StartedAtUtc = Utc(r.StartedAtUtc),
            Exercises = (r.Exercises ?? []).Select(e => ToEntity(e, r.WorkoutId, userId)).ToList(),
        };
        db.Workouts.Add(workout);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(workout.Revision, ToDto(workout));
    }

    public async Task<Outcome<WorkoutDto>> AddExerciseAsync(Guid userId, Guid workoutId, AddExerciseRequest r, CancellationToken ct)
    {
        var workout = await WorkoutAsync(userId, workoutId, ct);
        if (workout is null || workout.DeletedAtUtc != null) return Outcome.NotFound<WorkoutDto>();
        if (r.Exercise is null || !ValidSpec(r.Exercise)) return Outcome.Rejected<WorkoutDto>(Ack.Invalid);
        if (await db.WorkoutExercises.AnyAsync(e => e.Id == r.Exercise.Id, ct)) return Outcome.Conflict("DUPLICATE_ID", workout.Revision, ToDto(workout));
        // Anything added after start is extra actual work, never part of the prescription.
        db.WorkoutExercises.Add(ToEntity(r.Exercise with { IsPrescribed = false }, workout.Id, userId));
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(workout.Revision, ToDto(workout));
    }

    public async Task<Outcome<WorkoutDto>> RemoveExerciseAsync(Guid userId, Guid exerciseId, CancellationToken ct)
    {
        var exercise = await db.WorkoutExercises.FirstOrDefaultAsync(e => e.Id == exerciseId && e.UserId == userId, ct);
        if (exercise is null) return Outcome.NotFound<WorkoutDto>();
        var workout = (await WorkoutAsync(userId, exercise.WorkoutId, ct))!;
        if (exercise.Sets.Any(s => s.DeletedAtUtc == null)) return Outcome.Conflict("EXERCISE_HAS_SETS", workout.Revision, ToDto(workout));
        exercise.DeletedAtUtc ??= DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(workout.Revision, ToDto(workout));
    }

    private static bool ValidValues(int? reps, decimal? loadKg, int? durationSeconds) =>
        reps is null or >= 0 and <= 10000 && loadKg is null or >= 0 and <= 2000 && durationSeconds is null or >= 0 and <= 86400 &&
        (reps is > 0 || durationSeconds is > 0);

    public async Task<Outcome<SetDto>> CreateSetAsync(Guid userId, Guid exerciseId, SetCreateRequest r, CancellationToken ct)
    {
        var exercise = await db.WorkoutExercises.FirstOrDefaultAsync(e => e.Id == exerciseId && e.UserId == userId && e.DeletedAtUtc == null, ct);
        if (exercise is null) return Outcome.NotFound<SetDto>();
        if (r.SetId == Guid.Empty || !ValidValues(r.Reps, r.LoadKg, r.DurationSeconds)) return Outcome.Rejected<SetDto>(Ack.Invalid);
        if (await db.WorkoutSets.AnyAsync(s => s.Id == r.SetId, ct)) return Outcome.Conflict<SetDto>("DUPLICATE_ID");
        var set = new WorkoutSet
        {
            Id = r.SetId, ExerciseId = exercise.Id, WorkoutId = exercise.WorkoutId, UserId = userId, Reps = r.Reps, LoadKg = r.LoadKg,
            DurationSeconds = r.DurationSeconds, PerformedAtUtc = Utc(r.PerformedAtUtc),
        };
        db.WorkoutSets.Add(set);
        await db.SaveChangesAsync(ct);
        await RecomputeIfFinishedAsync(userId, set.WorkoutId, ct);
        return Outcome.Accepted(set.Revision, ToDto(set));
    }

    public Task<Outcome<SetDto>> UpdateSetAsync(Guid userId, Guid setId, SetUpdateRequest r, CancellationToken ct) =>
        MutateSetAsync(userId, setId, r.ExpectedRevision, ct, set =>
        {
            if (!ValidValues(r.Reps, r.LoadKg, r.DurationSeconds)) return false;
            (set.Reps, set.LoadKg, set.DurationSeconds) = (r.Reps, r.LoadKg, r.DurationSeconds);
            return true;
        });

    /// <summary>Deletion keeps a revisioned tombstone so a late acknowledgement cannot resurrect or duplicate the set.</summary>
    public Task<Outcome<SetDto>> DeleteSetAsync(Guid userId, Guid setId, RevisionCommand r, CancellationToken ct) =>
        MutateSetAsync(userId, setId, r.ExpectedRevision, ct, set => { set.DeletedAtUtc = DateTime.UtcNow; return true; });

    private async Task<Outcome<SetDto>> MutateSetAsync(Guid userId, Guid setId, int expectedRevision, CancellationToken ct, Func<WorkoutSet, bool> apply)
    {
        var set = await db.WorkoutSets.FirstOrDefaultAsync(s => s.Id == setId && s.UserId == userId, ct);
        if (set is null) return Outcome.NotFound<SetDto>();
        if (set.DeletedAtUtc != null) return Outcome.Conflict("SET_DELETED", set.Revision, ToDto(set));
        if (set.Revision != expectedRevision) return Outcome.Conflict(Ack.RevisionConflict, set.Revision, ToDto(set));
        if (!apply(set)) return Outcome.Rejected<SetDto>(Ack.Invalid);
        set.Revision++;
        await db.SaveChangesAsync(ct);
        await RecomputeIfFinishedAsync(userId, set.WorkoutId, ct);
        return Outcome.Accepted(set.Revision, ToDto(set));
    }

    /// <summary>A correction to finished history re-derives its result and flags proposals built on the old evidence.</summary>
    private async Task RecomputeIfFinishedAsync(Guid userId, Guid workoutId, CancellationToken ct)
    {
        var workout = (await WorkoutAsync(userId, workoutId, ct))!;
        if (workout.FinishedAtUtc is null) return;
        await ApplyResultAsync(workout, ct);
        if (workout.PlanId is { } planId)
            await db.Proposals.Where(p => p.PlanId == planId && p.State == "open")
                .ExecuteUpdateAsync(s => s.SetProperty(p => p.State, "needs_review").SetProperty(p => p.Revision, p => p.Revision + 1), ct);
        await db.SaveChangesAsync(ct);
    }

    private async Task ApplyResultAsync(Workout workout, CancellationToken ct)
    {
        var live = workout.Exercises.Where(e => e.DeletedAtUtc == null).ToList();
        var result = WorkoutResultRules.Evaluate(
            live.Where(e => e.IsPrescribed).Select(e => new PrescribedExercise(e.Id, e.TargetSets)).ToList(),
            live.SelectMany(e => e.Sets).Select(s => new PerformedSet(s.ExerciseId, s.Reps, s.LoadKg, s.DurationSeconds, s.DeletedAtUtc != null)).ToList(),
            workout.Kind == "manual");
        (workout.Outcome, workout.PerformedSets, workout.PerformedExercises) = (result.Outcome, result.PerformedSets, result.PerformedExercises);

        workout.QualifiedOccasion = false;
        if (workout.OccasionId is not { } occasionId) return;
        var occasion = await db.Occasions.FirstAsync(o => o.Id == occasionId, ct);
        var ownsCredit = occasion.ResultWorkoutId == workout.Id;
        if (result.QualifiesOccasion && (ownsCredit || (occasion.ResultOutcome == null && !occasion.IsSkipped)))
        {
            // One occasion is credited by exactly one workout, once. Partial stays visibly partial.
            (occasion.ResultOutcome, occasion.ResultWorkoutId) = (result.Outcome, workout.Id);
            workout.QualifiedOccasion = true;
        }
        else if (ownsCredit) (occasion.ResultOutcome, occasion.ResultWorkoutId) = (null, null); // no-data never satisfies an occasion
    }

    public async Task<Outcome<WorkoutDto>> FinishAsync(Guid userId, Guid workoutId, FinishRequest r, CancellationToken ct)
    {
        var workout = await WorkoutAsync(userId, workoutId, ct);
        if (workout is null || workout.DeletedAtUtc != null) return Outcome.NotFound<WorkoutDto>();
        if (r.ActiveDurationSeconds is < 0 or > 604800) return Outcome.Rejected<WorkoutDto>(Ack.Invalid);
        if (workout.FinishedAtUtc != null) return Outcome.Conflict("ALREADY_FINISHED", workout.Revision, ToDto(workout));
        if (workout.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, workout.Revision, ToDto(workout));
        // The finish must describe exactly the sets the server holds; it can never run ahead of or behind them.
        var live = workout.Exercises.SelectMany(e => e.Sets).Where(s => s.DeletedAtUtc == null).Select(s => (s.Id, s.Revision)).ToHashSet();
        var acked = (r.AcknowledgedSets ?? []).Select(s => (s.Id, s.Revision)).ToHashSet();
        if (!live.SetEquals(acked)) return Outcome.Conflict("SET_DEPENDENCY_MISMATCH", workout.Revision, ToDto(workout));

        workout.FinishedAtUtc = Utc(r.FinishedAtUtc);
        workout.ActiveDurationSeconds = r.ActiveDurationSeconds;
        await ApplyResultAsync(workout, ct);
        workout.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(workout.Revision, ToDto(workout));
    }

    /// <summary>Explicit owner removal. History is tombstoned, and any occasion credit it held is released.</summary>
    public async Task<Outcome<WorkoutDto>> DeleteAsync(Guid userId, Guid workoutId, RevisionCommand r, CancellationToken ct)
    {
        var workout = await WorkoutAsync(userId, workoutId, ct);
        if (workout is null) return Outcome.NotFound<WorkoutDto>();
        if (workout.DeletedAtUtc != null) return Outcome.Conflict("ALREADY_DELETED", workout.Revision, ToDto(workout));
        if (workout.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, workout.Revision, ToDto(workout));
        workout.DeletedAtUtc = DateTime.UtcNow;
        workout.Revision++;
        if (workout.OccasionId is { } occasionId)
        {
            var occasion = await db.Occasions.FirstAsync(o => o.Id == occasionId, ct);
            if (occasion.ResultWorkoutId == workout.Id) (occasion.ResultOutcome, occasion.ResultWorkoutId) = (null, null);
        }
        workout.QualifiedOccasion = false;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(workout.Revision, ToDto(workout));
    }

    public async Task<List<WorkoutDto>> ListAsync(Guid userId, CancellationToken ct) =>
        (await db.Workouts.AsNoTracking().Include(w => w.Exercises).ThenInclude(e => e.Sets).AsSplitQuery()
            .Where(w => w.UserId == userId).OrderBy(w => w.StartedAtUtc).ToListAsync(ct)).Select(ToDto).ToList();
}
