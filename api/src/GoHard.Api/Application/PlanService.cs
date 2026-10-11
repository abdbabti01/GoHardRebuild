using System.Text.Json;
using GoHard.Api.Domain;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

public sealed record Baseline(string Id, string Title, string Direction, string Equipment, int SessionsPerWeek, int MinutesMin,
    int MinutesMax, List<string> Experience, List<int> BlockWeeks, int MinRecoveryDays, List<ManualWorkoutSpec> Workouts);

/// <summary>Curated baselines whose declared coverage is exactly what the file contains. No AI involved.</summary>
public sealed class BaselineCatalog
{
    private sealed record File(int Version, List<Baseline> Baselines);
    public IReadOnlyList<Baseline> Baselines { get; } = JsonSerializer.Deserialize<File>(
        System.IO.File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "baselines.json")), CommandRunner.Json)!.Baselines;

    /// <summary>Returns the matching baseline, or the honest reasons none fits.</summary>
    public (Baseline? Match, List<string> Feedback) Fit(PlanSetup s)
    {
        var feedback = new List<string>();
        foreach (var b in Baselines)
        {
            feedback.Clear();
            if (s.Direction != b.Direction) feedback.Add("UNSUPPORTED_DIRECTION");
            if (s.Equipment != b.Equipment) feedback.Add("UNSUPPORTED_EQUIPMENT");
            if (s.SessionsPerWeek != b.SessionsPerWeek) feedback.Add("UNSUPPORTED_SESSIONS_PER_WEEK");
            if (s.MinutesPerSession < b.MinutesMin || s.MinutesPerSession > b.MinutesMax) feedback.Add("UNSUPPORTED_SESSION_LENGTH");
            if (!b.Experience.Contains(s.Experience)) feedback.Add("UNSUPPORTED_EXPERIENCE");
            if (!string.IsNullOrWhiteSpace(s.Limitations)) feedback.Add("UNREVIEWED_LIMITATION");
            if (!b.BlockWeeks.Contains(s.BlockWeeks)) feedback.Add("UNSUPPORTED_BLOCK_LENGTH");
            if (feedback.Count == 0) return (b, feedback);
        }
        return (null, feedback);
    }
}

public sealed class PlanService(GoHardDb db, BaselineCatalog baselines)
{
    private static readonly JsonSerializerOptions Json = CommandRunner.Json;

    public static OccasionDto ToDto(Occasion o) => new(o.Id, o.WeekNumber, o.Ordinal, o.Title, o.OriginalDate, o.ScheduledDate,
        o.IsSkipped, o.ResultOutcome, o.ResultWorkoutId, JsonSerializer.Deserialize<List<PrescriptionExercise>>(o.PrescriptionJson, Json)!);

    public static PlanDto ToDto(Plan p) => new(p.Id, p.Title, p.Lifecycle, p.ClosureIntent, p.IsArchived, p.StartDate, p.BlockWeeks,
        p.MinRecoveryDays, JsonSerializer.Deserialize<PlanSetup>(p.SetupJson, Json), p.BaselineId, p.PausedOn, p.ClosedOn, p.Revision,
        p.Occasions.OrderBy(o => o.ScheduledDate).ThenBy(o => o.Ordinal).Select(ToDto).ToList());

    public async Task<PlanContextDto> ContextAsync(Guid userId, CancellationToken ct)
    {
        var ctx = await db.TrainingContexts.AsNoTracking().FirstAsync(c => c.UserId == userId, ct);
        var plans = await db.Plans.AsNoTracking().Include(p => p.Occasions).Where(p => p.UserId == userId)
            .OrderBy(p => p.CreatedAtUtc).ToListAsync(ct);
        return new(ctx.Revision, ctx.PrimaryPlanId, plans.Select(ToDto).ToList());
    }

    private Task<Plan?> PlanAsync(Guid userId, Guid planId, CancellationToken ct) =>
        db.Plans.Include(p => p.Occasions).FirstOrDefaultAsync(p => p.Id == planId && p.UserId == userId, ct);

    private async Task<Outcome<PlanContextDto>> SavedAsync(Guid userId, CancellationToken ct)
    {
        await db.SaveChangesAsync(ct);
        var dto = await ContextAsync(userId, ct);
        return Outcome.Accepted(dto.ContextRevision, dto);
    }

    private async Task<Outcome<PlanContextDto>> ConflictAsync(Guid userId, string code, CancellationToken ct)
    {
        db.ChangeTracker.Clear();
        var dto = await ContextAsync(userId, ct);
        return Outcome.Conflict(code, dto.ContextRevision, dto);
    }

    /// <summary>An occasion is open while an unfinished, undeleted workout is attached to it.</summary>
    private async Task<List<ScheduleOccasion>> ScheduleAsync(Plan plan, CancellationToken ct)
    {
        var open = await db.Workouts.Where(w => w.PlanId == plan.Id && w.FinishedAtUtc == null && w.DeletedAtUtc == null && w.OccasionId != null)
            .Select(w => w.OccasionId!.Value).ToListAsync(ct);
        return plan.Occasions.Select(o => new ScheduleOccasion(o.Id, o.OriginalDate, o.ScheduledDate, o.WeekNumber,
            o.IsSkipped, o.ResultOutcome != null, open.Contains(o.Id))).ToList();
    }

    private static List<DayOfWeek> Weekdays(IEnumerable<int> iso) => iso.Select(d => (DayOfWeek)(d % 7)).ToList();

    private static (string? Error, List<Occasion> Occasions) BuildOccasions(Plan plan, PlanSetup setup, List<ManualWorkoutSpec> workouts)
    {
        if (setup.Weekdays is null || setup.Weekdays.Any(d => d is < 1 or > 7)) return (ScheduleRules.InvalidWeekdayCount, []);
        var (errors, dates) = ScheduleRules.Generate(setup.StartDate, Weekdays(setup.Weekdays), setup.SessionsPerWeek, setup.BlockWeeks, plan.MinRecoveryDays);
        if (errors.Count > 0) return (errors[0].Code, []);
        var list = dates.Select((d, i) =>
        {
            var w = workouts[(d.Ordinal - 1) % workouts.Count];
            return new Occasion
            {
                Id = Guid.NewGuid(), PlanId = plan.Id, UserId = plan.UserId, WeekNumber = d.Week, Ordinal = d.Ordinal, Title = w.Title,
                OriginalDate = d.Date, ScheduledDate = d.Date, PrescriptionJson = JsonSerializer.Serialize(w.Exercises, Json),
            };
        }).ToList();
        return (null, list);
    }

    public async Task<Outcome<PlanDraftResult>> CreateDraftAsync(Guid userId, PlanDraftRequest r, CancellationToken ct)
    {
        var s = r.Setup;
        if (s is null || s.BlockWeeks is < 1 or > 52 || s.SessionsPerWeek is < 1 or > 7) return Outcome.Rejected<PlanDraftResult>(Ack.Invalid);
        if (await db.Plans.AnyAsync(p => p.Id == r.PlanId, ct)) return Outcome.Conflict<PlanDraftResult>("DUPLICATE_ID");

        List<ManualWorkoutSpec> workouts; string title; string? baselineId = null; var recovery = 1;
        if (r.ManualWorkouts is { Count: > 0 } manual)
        {
            if (manual.Any(w => string.IsNullOrWhiteSpace(w.Title) || w.Exercises is not { Count: > 0 } ||
                    w.Exercises.Any(e => string.IsNullOrWhiteSpace(e.Name) || e.TargetSets is < 0 || e.RestSeconds is < 0)))
                return Outcome.Rejected<PlanDraftResult>(Ack.Invalid);
            (workouts, title) = (manual, string.IsNullOrWhiteSpace(r.Title) ? "My plan" : r.Title.Trim());
        }
        else
        {
            var (match, feedback) = baselines.Fit(s);
            // Unsupported setup is honest fit feedback. It never activates or fabricates a fallback plan.
            if (match is null) return Outcome.Accepted(0, new PlanDraftResult("fit_feedback", null, null, feedback));
            (workouts, title, baselineId, recovery) = (match.Workouts, r.Title?.Trim() is { Length: > 0 } t ? t : match.Title, match.Id, match.MinRecoveryDays);
        }

        var plan = new Plan
        {
            Id = r.PlanId, UserId = userId, Title = title, StartDate = s.StartDate, BlockWeeks = s.BlockWeeks, MinRecoveryDays = recovery,
            SetupJson = JsonSerializer.Serialize(s, Json), BaselineId = baselineId, CreatedAtUtc = DateTime.UtcNow,
        };
        var (error, occasions) = BuildOccasions(plan, s, workouts);
        if (error is not null) return Outcome.Rejected<PlanDraftResult>(error);
        plan.Occasions = occasions;
        db.Plans.Add(plan);
        // The answers are retained with the account so later setup never asks again.
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        user.TrainingSetupJson = plan.SetupJson;
        await db.SaveChangesAsync(ct);
        var ctx = await ContextAsync(userId, ct);
        return Outcome.Accepted(plan.Revision, new PlanDraftResult("supported_draft", ctx, plan.Id, []));
    }

    public async Task<Outcome<PlanContextDto>> UpdateDraftAsync(Guid userId, Guid planId, PlanDraftUpdateRequest r, CancellationToken ct)
    {
        var plan = await PlanAsync(userId, planId, ct);
        if (plan is null) return Outcome.NotFound<PlanContextDto>();
        if (plan.Lifecycle != PlanLifecycles.Draft) return await ConflictAsync(userId, "PLAN_NOT_DRAFT", ct);
        if (plan.Revision != r.ExpectedPlanRevision) return await ConflictAsync(userId, Ack.RevisionConflict, ct);
        var old = JsonSerializer.Deserialize<PlanSetup>(plan.SetupJson, Json)!;
        var setup = old with { StartDate = r.StartDate, Weekdays = r.Weekdays, BlockWeeks = r.BlockWeeks };
        if (plan.BaselineId is not null && !baselines.Baselines.First(b => b.Id == plan.BaselineId).BlockWeeks.Contains(r.BlockWeeks))
            return Outcome.Rejected<PlanContextDto>("UNSUPPORTED_BLOCK_LENGTH");
        // Week-one prescriptions are the block's content; the draft has no recorded work to preserve.
        var workouts = plan.Occasions.Where(o => o.WeekNumber == 1).OrderBy(o => o.Ordinal)
            .Select(o => new ManualWorkoutSpec(o.Title, ToDto(o).Prescription)).ToList();
        plan.StartDate = r.StartDate; plan.BlockWeeks = r.BlockWeeks;
        var (error, occasions) = BuildOccasions(plan, setup, workouts);
        if (error is not null) return Outcome.Rejected<PlanContextDto>(error);
        db.Occasions.RemoveRange(plan.Occasions);
        db.Occasions.AddRange(occasions);
        plan.SetupJson = JsonSerializer.Serialize(setup, Json);
        if (!string.IsNullOrWhiteSpace(r.Title)) plan.Title = r.Title.Trim();
        plan.Revision++;
        return await SavedAsync(userId, ct);
    }

    public async Task<Outcome<PlanContextDto>> ActivateAsync(Guid userId, Guid planId, ActivateRequest r, CancellationToken ct)
    {
        var plan = await PlanAsync(userId, planId, ct);
        if (plan is null) return Outcome.NotFound<PlanContextDto>();
        var ctx = await db.TrainingContexts.FirstAsync(c => c.UserId == userId, ct);
        if (ctx.Revision != r.ExpectedContextRevision || plan.Revision != r.ExpectedPlanRevision)
            return await ConflictAsync(userId, Ack.RevisionConflict, ct);
        if (plan.Lifecycle != PlanLifecycles.Draft) return await ConflictAsync(userId, "PLAN_NOT_DRAFT", ct);
        // Activation commits exactly what was reviewed: same start, same occasions, same dates.
        var reviewed = (r.ReviewedDates ?? []).ToDictionary(d => d.OccasionId, d => d.Date);
        if (r.StartDate != plan.StartDate || reviewed.Count != plan.Occasions.Count ||
            plan.Occasions.Any(o => !reviewed.TryGetValue(o.Id, out var d) || d != o.ScheduledDate))
            return await ConflictAsync(userId, ScheduleRules.StaleReview, ct);

        if (ctx.PrimaryPlanId is { } currentId && currentId != plan.Id)
        {
            if (r.ReplacePrimaryId != currentId) return await ConflictAsync(userId, "PRIMARY_EXISTS", ct);
            var current = await db.Plans.FirstAsync(p => p.Id == currentId, ct);
            if (r.ClosePrimary) (current.Lifecycle, current.ClosureIntent, current.ClosedOn) = (PlanLifecycles.Closed, "finish_for_now", r.EffectiveDate);
            else if (current.Lifecycle == PlanLifecycles.Active) (current.Lifecycle, current.PausedOn) = (PlanLifecycles.Paused, r.EffectiveDate);
            current.Revision++;
        }
        plan.Lifecycle = PlanLifecycles.Active; plan.Revision++;
        ctx.PrimaryPlanId = plan.Id; ctx.Revision++;
        return await SavedAsync(userId, ct);
    }

    public async Task<Outcome<PlanContextDto>> PauseAsync(Guid userId, Guid planId, PauseRequest r, CancellationToken ct)
    {
        var plan = await PlanAsync(userId, planId, ct);
        if (plan is null) return Outcome.NotFound<PlanContextDto>();
        var ctx = await db.TrainingContexts.FirstAsync(c => c.UserId == userId, ct);
        if (ctx.Revision != r.ExpectedContextRevision || plan.Revision != r.ExpectedPlanRevision)
            return await ConflictAsync(userId, Ack.RevisionConflict, ct);
        if (plan.Lifecycle != PlanLifecycles.Active || ctx.PrimaryPlanId != plan.Id) return await ConflictAsync(userId, "PLAN_NOT_ACTIVE", ct);
        // Freezes future expectations only. Workouts, sets and the workout clock are not touched.
        (plan.Lifecycle, plan.PausedOn) = (PlanLifecycles.Paused, r.EffectiveDate);
        plan.Revision++; ctx.Revision++;
        return await SavedAsync(userId, ct);
    }

    public async Task<Outcome<PlanContextDto>> ResumeAsync(Guid userId, Guid planId, ResumeRequest r, CancellationToken ct)
    {
        var plan = await PlanAsync(userId, planId, ct);
        if (plan is null) return Outcome.NotFound<PlanContextDto>();
        var ctx = await db.TrainingContexts.FirstAsync(c => c.UserId == userId, ct);
        if (ctx.Revision != r.ExpectedContextRevision || plan.Revision != r.ExpectedPlanRevision)
            return await ConflictAsync(userId, Ack.RevisionConflict, ct);
        if (plan.Lifecycle != PlanLifecycles.Paused) return await ConflictAsync(userId, "PLAN_NOT_PAUSED", ct);
        if (ctx.PrimaryPlanId is { } currentId && currentId != plan.Id)
        {
            if (r.SwitchPrimaryFromId != currentId) return await ConflictAsync(userId, "PRIMARY_EXISTS", ct);
            var current = await db.Plans.FirstAsync(p => p.Id == currentId, ct);
            if (current.Lifecycle == PlanLifecycles.Active) { (current.Lifecycle, current.PausedOn) = (PlanLifecycles.Paused, r.EffectiveDate); current.Revision++; }
        }
        var validation = ScheduleRules.Validate(await ScheduleAsync(plan, ct), r.Changes ?? [], plan.MinRecoveryDays);
        if (!validation.IsValid) return await ConflictAsync(userId, validation.Errors[0].Code, ct);
        foreach (var c in validation.Changed) plan.Occasions.First(o => o.Id == c.Id).ScheduledDate = c.ScheduledDate;
        (plan.Lifecycle, plan.PausedOn) = (PlanLifecycles.Active, null);
        plan.Revision++;
        ctx.PrimaryPlanId = plan.Id; ctx.Revision++;
        return await SavedAsync(userId, ct);
    }

    public async Task<Outcome<PlanContextDto>> ChangeScheduleAsync(Guid userId, Guid planId, ScheduleChangeRequest r, CancellationToken ct)
    {
        var plan = await PlanAsync(userId, planId, ct);
        if (plan is null) return Outcome.NotFound<PlanContextDto>();
        if (plan.Revision != r.ExpectedPlanRevision) return await ConflictAsync(userId, Ack.RevisionConflict, ct);
        if (plan.Lifecycle is not (PlanLifecycles.Active or PlanLifecycles.Paused)) return await ConflictAsync(userId, "PLAN_NOT_ACTIVE", ct);
        var schedule = await ScheduleAsync(plan, ct);
        var target = schedule.FirstOrDefault(o => o.Id == r.OccasionId);
        var occasion = plan.Occasions.FirstOrDefault(o => o.Id == r.OccasionId);
        if (target is null || occasion is null) return await ConflictAsync(userId, ScheduleRules.OccasionNotFound, ct);

        switch (r.Action)
        {
            case "move" when r.From is { } from && r.To is { } to:
                var v = ScheduleRules.Validate(schedule, [new(r.OccasionId, from, to)], plan.MinRecoveryDays);
                if (!v.IsValid) return await ConflictAsync(userId, v.Errors[0].Code, ct);
                occasion.ScheduledDate = to; // same occasion, same week, original date retained
                break;
            case "skip":
                if (!target.IsEligible) return await ConflictAsync(userId, ScheduleRules.OccasionNotEligible, ct);
                occasion.IsSkipped = true; // no sets, no workout, no completion credit
                break;
            case "unskip":
                if (!occasion.IsSkipped) return await ConflictAsync(userId, ScheduleRules.OccasionNotEligible, ct);
                occasion.IsSkipped = false;
                break;
            default: return Outcome.Rejected<PlanContextDto>(Ack.Invalid);
        }
        plan.Revision++;
        return await SavedAsync(userId, ct);
    }

    public async Task<Outcome<PlanContextDto>> CloseAsync(Guid userId, Guid planId, CloseRequest r, CancellationToken ct)
    {
        if (r.Intent is not ("finish_for_now" or "stopped_early")) return Outcome.Rejected<PlanContextDto>(Ack.Invalid);
        var plan = await PlanAsync(userId, planId, ct);
        if (plan is null) return Outcome.NotFound<PlanContextDto>();
        var ctx = await db.TrainingContexts.FirstAsync(c => c.UserId == userId, ct);
        if (ctx.Revision != r.ExpectedContextRevision || plan.Revision != r.ExpectedPlanRevision)
            return await ConflictAsync(userId, Ack.RevisionConflict, ct);
        if (plan.Lifecycle is not (PlanLifecycles.Active or PlanLifecycles.Paused)) return await ConflictAsync(userId, "PLAN_NOT_ACTIVE", ct);
        // Frees the primary slot. Open workouts keep their plan and occasion links and can finish later.
        (plan.Lifecycle, plan.ClosureIntent, plan.ClosedOn) = (PlanLifecycles.Closed, r.Intent, r.EffectiveDate);
        plan.Revision++;
        if (ctx.PrimaryPlanId == plan.Id) ctx.PrimaryPlanId = null;
        ctx.Revision++;
        return await SavedAsync(userId, ct);
    }

    public async Task<Outcome<PlanContextDto>> ArchiveAsync(Guid userId, Guid planId, ArchiveRequest r, CancellationToken ct)
    {
        var plan = await PlanAsync(userId, planId, ct);
        if (plan is null) return Outcome.NotFound<PlanContextDto>();
        if (plan.Revision != r.ExpectedPlanRevision) return await ConflictAsync(userId, Ack.RevisionConflict, ct);
        var ctx = await db.TrainingContexts.AsNoTracking().FirstAsync(c => c.UserId == userId, ct);
        if (r.IsArchived && ctx.PrimaryPlanId == plan.Id) return await ConflictAsync(userId, "PLAN_IS_PRIMARY", ct);
        plan.IsArchived = r.IsArchived; // visibility only: lifecycle and closure intent are untouched
        plan.Revision++;
        return await SavedAsync(userId, ct);
    }

    /// <summary>Continuing a goal produces a separate draft. It never activates anything.</summary>
    public async Task<Outcome<PlanContextDto>> ContinueAsync(Guid userId, Guid planId, ContinueRequest r, CancellationToken ct)
    {
        var source = await PlanAsync(userId, planId, ct);
        if (source is null) return Outcome.NotFound<PlanContextDto>();
        if (await db.Plans.AnyAsync(p => p.Id == r.NewPlanId, ct)) return await ConflictAsync(userId, "DUPLICATE_ID", ct);
        var setup = JsonSerializer.Deserialize<PlanSetup>(source.SetupJson, Json)! with { StartDate = r.StartDate };
        var plan = new Plan
        {
            Id = r.NewPlanId, UserId = userId, Title = source.Title, StartDate = r.StartDate, BlockWeeks = source.BlockWeeks,
            MinRecoveryDays = source.MinRecoveryDays, SetupJson = JsonSerializer.Serialize(setup, Json), BaselineId = source.BaselineId,
            CreatedAtUtc = DateTime.UtcNow,
        };
        var workouts = source.Occasions.Where(o => o.WeekNumber == 1).OrderBy(o => o.Ordinal)
            .Select(o => new ManualWorkoutSpec(o.Title, ToDto(o).Prescription)).ToList();
        var (error, occasions) = BuildOccasions(plan, setup, workouts);
        if (error is not null) return Outcome.Rejected<PlanContextDto>(error);
        plan.Occasions = occasions;
        db.Plans.Add(plan);
        return await SavedAsync(userId, ct);
    }
}
