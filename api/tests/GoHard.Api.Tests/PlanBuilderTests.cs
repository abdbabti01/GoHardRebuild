using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GoHard.Api.Application;
using GoHard.Api.Domain;
using GoHard.Api.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace GoHard.Api.Tests;

/// <summary>Built plans (docs/TRAINING_PLANS.md): create, activate, rotate, revise, one-off edits, custom exercises, upgrade.</summary>
[Collection("api")]
public class PlanBuilderTests(PostgresFixture pg)
{
    private static readonly DateOnly Monday = new(2026, 10, 12);

    private static PrescriptionExercise Ex(string catalogKey = "bench-press", string name = "Bench press", string key = "e1", int sets = 3,
        decimal? load = null, string? notes = null) => new(key, catalogKey, name, false, sets, 8, 12, null, 90, load, notes);
    private static WorkoutDefinition Def(string name, params PrescriptionExercise[] exercises) => new(Guid.NewGuid(), name, null, [.. exercises]);
    private static PlanSchedule Fixed(params (int Day, WorkoutDefinition W)[] p) =>
        new(PlanRules.Fixed, [.. p.Select(x => new PlanPatternEntry(x.Day, x.W.Id))], [], [], 0);
    private static PlanSchedule Rotation(params WorkoutDefinition[] cycle) => new(PlanRules.Rotating, [], [.. cycle.Select(w => w.Id)], [], 0);
    private static PlanCreateRequest Create(List<WorkoutDefinition> workouts, PlanSchedule schedule, int? weeks = 2, string title = "My split") =>
        new(Guid.NewGuid(), Guid.NewGuid(), title, Monday, weeks, 45, "push-pull-legs", workouts, schedule);
    private static PlanReviseRequest Revise(PlanDto plan, DateOnly effective, List<WorkoutDefinition> workouts, PlanSchedule schedule) =>
        new(Guid.NewGuid(), plan.Revision, effective, plan.Title, plan.StartDate, plan.IsOngoing ? null : plan.BlockWeeks, plan.TimeBudgetMinutes, workouts, schedule);

    private static async Task<PlanDto> CreateAsync(Account a, PlanCreateRequest r)
    {
        var res = await a.PostAsync<PlanContextDto>("/plans", r);
        Assert.Equal("accepted", res.Status);
        return res.Data.Plans.Single(p => p.Id == r.PlanId);
    }

    private static async Task<PlanDto> ActivateAsync(Account a, PlanDto plan)
    {
        var res = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/activate", a.ActivateRequestFor(plan, (await a.ContextAsync()).ContextRevision));
        Assert.Equal("accepted", res.Status);
        return res.Data.Plans.Single(p => p.Id == plan.Id);
    }

    private static async Task<PlanDto> PlanAsync(Account a, Guid id) => (await a.ContextAsync()).Plans.Single(p => p.Id == id);

    private static List<ExerciseSpec> Specs(IEnumerable<PrescriptionExercise> p) => p.Select((e, i) => new ExerciseSpec(Guid.NewGuid(), i + 1, e.Name,
        e.CatalogKey, e.OccurrenceKey, true, e.IsTimed, e.TargetSets, e.TargetRepsMin, e.TargetRepsMax, e.TargetDurationSeconds, e.RestSeconds, null,
        e.TargetLoadKg, e.Notes)).ToList();

    private static StartWorkoutRequest StartStep(PlanDto plan, int k, WorkoutDefinition w, DateOnly day) => new(Guid.NewGuid(), Guid.NewGuid(), "planned",
        PlanRules.SequenceId(plan.Id, k), w.Name, day, DateTime.UtcNow, Specs(w.Exercises), plan.Id, k);

    private static async Task<AckResult<PlanContextDto>> SkipStepAsync(Account a, Guid planId, int k, DateOnly day, Guid? occasionId = null) =>
        await a.PostAsync<PlanContextDto>($"/plans/{planId}/schedule-changes", new ScheduleChangeRequest(Guid.NewGuid(), (await PlanAsync(a, planId)).Revision,
            "skip", occasionId ?? PlanRules.SequenceId(planId, k), null, day, k));

    private static async Task<CustomExerciseDto> CustomAsync(Account a, string name = "Sled push")
    {
        var res = await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{Guid.NewGuid()}", new CustomExercisePutRequest(Guid.NewGuid(), 0, name, "Legs", "Machine", false, false));
        Assert.Equal("accepted", res.Status);
        return res.Data;
    }

    // ------------------------------------------------------------------ plan.create

    [Fact]
    public async Task Plan_create_makes_an_independent_draft_with_one_id_per_occurrence_and_replays()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (push, pull, legs) = (Def("Push", Ex()), Def("Pull", Ex("barbell-row", "Barbell row")), Def("Legs", Ex("back-squat", "Back squat")));
        var request = Create([push, pull, legs], Fixed((1, push), (2, pull), (3, legs), (4, push), (5, pull), (6, legs)));

        var first = await a.PostAsync<PlanContextDto>("/plans", request);
        Assert.Equal("accepted", first.Status);
        var plan = first.Data.Plans.Single();
        Assert.Null(first.Data.PrimaryPlanId);                                    // a draft only: nothing becomes active
        Assert.Equal(("draft", 2, 0, false, 45, "push-pull-legs"), (plan.Lifecycle, plan.BlockWeeks, plan.MinRecoveryDays, plan.IsOngoing, plan.TimeBudgetMinutes, plan.TemplateId));
        Assert.Null(plan.Setup);
        Assert.Equal(3, plan.Workouts!.Count);
        Assert.Equal(PlanRules.Fixed, plan.Schedule!.Mode);
        Assert.Equal(12, plan.Occasions.Count);
        Assert.All(plan.Occasions.GroupBy(o => o.WeekNumber), w => Assert.Equal(6, w.Count()));
        Assert.Equal(12, plan.Occasions.Select(o => o.Id).Distinct().Count());
        Assert.All(plan.Occasions, o => Assert.Equal(PlanRules.FixedId(plan.Id, o.OriginalDate), o.Id));
        Assert.Equal(3, plan.Occasions.Select(o => o.WorkoutId).Distinct().Count());
        Assert.Equal(["Push", "Pull", "Legs", "Push", "Pull", "Legs"], plan.Occasions.Where(o => o.WeekNumber == 1).Select(o => o.Title));
        Assert.All(plan.Occasions, o => Assert.Equal(((int?)null, false), (o.SequenceIndex, o.IsCustomised)));

        var retry = await a.PostAsync<PlanContextDto>("/plans", request);
        Assert.Equal(first.Raw, retry.Raw);
        var changed = await a.PostAsync<PlanContextDto>("/plans", request with { Title = "Other" });
        Assert.Equal((HttpStatusCode.Conflict, Ack.PayloadMismatch), (changed.Http, changed.Code));
        var duplicate = await a.PostAsync<PlanContextDto>("/plans", request with { OperationId = Guid.NewGuid() });
        Assert.Equal(("conflict", "DUPLICATE_ID"), (duplicate.Status, duplicate.Code));
        Assert.Single((await a.ContextAsync()).Plans);

        // Another account choosing the same structure gets its own copy; changing it never touches the first.
        var b = await Account.RegisterAsync(pg.Api);
        var mine = await CreateAsync(b, request with { OperationId = Guid.NewGuid(), PlanId = Guid.NewGuid() });
        var revised = await b.PutAsync<PlanContextDto>($"/plans/{mine.Id}", Revise(mine, Monday, [push with { Name = "Mine" }, pull, legs], request.Schedule));
        Assert.Equal("accepted", revised.Status);
        var untouched = await PlanAsync(a, plan.Id);
        Assert.Equal((plan.Revision, "Push"), (untouched.Revision, untouched.Workouts![0].Name));
        Assert.Single((await b.ContextAsync()).Plans);
    }

    [Fact]
    public async Task Plan_create_rejects_invalid_plans_unknown_exercises_and_other_accounts_custom_exercises()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var b = await Account.RegisterAsync(pg.Api);
        var custom = await CustomAsync(a);

        async Task<AckResult<PlanContextDto>> Try(Account who, params PrescriptionExercise[] exercises)
        {
            var w = Def("Day", exercises);
            return await who.PostAsync<PlanContextDto>("/plans", Create([w], Rotation(w), weeks: null));
        }
        var unknown = await Try(a, Ex("no-such-move"));
        Assert.Equal(("rejected", PlanService.UnknownExercise), (unknown.Status, unknown.Code));
        Assert.Equal(PlanService.UnknownExercise, (await Try(a, Ex("custom:not-a-guid"))).Code);
        Assert.Equal(PlanService.UnknownExercise, (await Try(b, Ex($"custom:{custom.Id}", custom.Name))).Code); // someone else's exercise
        Assert.Equal(PlanRules.WorkoutsInvalid, (await Try(a, Ex() with { TargetRepsMin = 12, TargetRepsMax = 8 })).Code);
        var blank = Def("Day", Ex());
        Assert.Equal(PlanRules.TitleInvalid, (await a.PostAsync<PlanContextDto>("/plans", Create([blank], Rotation(blank), title: "  "))).Code);
        Assert.Equal(PlanRules.DurationInvalid, (await a.PostAsync<PlanContextDto>("/plans", Create([blank], Fixed((1, blank)), weeks: null))).Code);
        Assert.Empty((await a.ContextAsync()).Plans);
        Assert.Empty((await b.ContextAsync()).Plans);

        Assert.Equal("accepted", (await Try(a, Ex($"custom:{custom.Id}", custom.Name), Ex(null!, "Ad hoc stretch", "e2"))).Status);
        var archived = await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{custom.Id}", new CustomExercisePutRequest(Guid.NewGuid(), custom.Revision, custom.Name, "Legs", "Machine", false, true));
        Assert.True(archived.Data.IsArchived);
        Assert.Equal("accepted", (await Try(a, Ex($"custom:{custom.Id}", custom.Name))).Status); // archived stays valid
    }

    [Fact]
    public async Task Unusable_plan_cannot_be_activated_and_activation_retry_is_idempotent()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (push, extra) = (Def("Push"), Def("Unscheduled"));
        var draft = await CreateAsync(a, Create([push, extra], Fixed((1, push), (4, push))));
        var ctx = await a.ContextAsync();

        var refused = await a.PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", a.ActivateRequestFor(draft, ctx.ContextRevision));
        Assert.Equal((HttpStatusCode.UnprocessableEntity, PlanRules.NotUsable), (refused.Http, refused.Code));
        var after = await a.ContextAsync();
        Assert.Equal((ctx.ContextRevision, (Guid?)null), (after.ContextRevision, after.PrimaryPlanId));
        Assert.Equal(("draft", draft.Revision), (after.Plans.Single().Lifecycle, after.Plans.Single().Revision));

        var revised = await a.PutAsync<PlanContextDto>($"/plans/{draft.Id}", Revise(draft, Monday, [push with { Exercises = [Ex()] }, extra], draft.Schedule!));
        Assert.Equal("accepted", revised.Status);
        var usable = revised.Data.Plans.Single();
        var request = a.ActivateRequestFor(usable, revised.Data.ContextRevision);
        var first = await a.PostAsync<PlanContextDto>($"/plans/{usable.Id}/activate", request);
        var retry = await a.PostAsync<PlanContextDto>($"/plans/{usable.Id}/activate", request);
        Assert.Equal("accepted", first.Status);
        Assert.Equal(first.Raw, retry.Raw);
        var active = await a.ContextAsync();
        Assert.Equal((usable.Id, "active"), (active.PrimaryPlanId!.Value, active.Plans.Single().Lifecycle));
        Assert.Equal(first.Data.ContextRevision, active.ContextRevision);              // the retry changed nothing
    }

    // ------------------------------------------------------------------ rotating sequences

    [Fact]
    public async Task Rotating_start_materializes_its_step_once()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (push, pull) = (Def("Push", Ex(load: 60m, notes: "Pause at the bottom")), Def("Pull", Ex("barbell-row", "Barbell row")));
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([push, pull], Rotation(push, pull), weeks: null)));
        Assert.Empty(plan.Occasions);
        Assert.True(plan.IsOngoing);
        Assert.Equal(1, plan.BlockWeeks);

        var day = Monday.AddDays(9);
        var request = StartStep(plan, 0, push, day);
        var first = await a.PostAsync<WorkoutDto>("/workouts", request);
        Assert.Equal("accepted", first.Status);
        Assert.Equal((plan.Id, request.OccasionId), (first.Data.PlanId!.Value, first.Data.OccasionId));
        Assert.Equal((60m, "Pause at the bottom"), (first.Data.Exercises[0].TargetLoadKg!.Value, first.Data.Exercises[0].Notes));
        var step = (await PlanAsync(a, plan.Id)).Occasions.Single();
        Assert.Equal((PlanRules.SequenceId(plan.Id, 0), (int?)0, (Guid?)push.Id, "Push", day, day, 2, 1),
            (step.Id, step.SequenceIndex, step.WorkoutId, step.Title, step.OriginalDate, step.ScheduledDate, step.WeekNumber, step.Ordinal));
        Assert.Equal(60m, step.Prescription[0].TargetLoadKg);

        Assert.Equal(first.Raw, (await a.PostAsync<WorkoutDto>("/workouts", request)).Raw);  // a lost response replays
        var second = await a.PostAsync<WorkoutDto>("/workouts", StartStep(plan, 0, push, day)); // another device, same step
        Assert.Equal(("conflict", ScheduleRules.OccasionNotEligible), (second.Status, second.Code));
        Assert.Single((await PlanAsync(a, plan.Id)).Occasions);

        // Two starts of the next step at once: one occurrence, one winner.
        var racing = await Task.WhenAll(a.PostAsync<WorkoutDto>("/workouts", StartStep(plan, 1, pull, day)), a.PostAsync<WorkoutDto>("/workouts", StartStep(plan, 1, pull, day)));
        Assert.Single(racing, r => r.Status == "accepted");
        Assert.Equal(ScheduleRules.OccasionNotEligible, Assert.Single(racing, r => r.Status == "conflict").Code);
        Assert.Equal([0, 1], (await PlanAsync(a, plan.Id)).Occasions.Select(o => o.SequenceIndex!.Value).Order());

        var gap = await a.PostAsync<WorkoutDto>("/workouts", StartStep(plan, 3, pull, day));
        Assert.Equal(("conflict", ScheduleRules.OccasionNotEligible), (gap.Status, gap.Code));
        var wrongId = await a.PostAsync<WorkoutDto>("/workouts", StartStep(plan, 2, push, day) with { OccasionId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.NotFound, wrongId.Http);
        await using var db = pg.SharedDb();
        Assert.Equal(2, await db.Occasions.CountAsync(o => o.PlanId == plan.Id));
        Assert.Equal(2, await db.Workouts.CountAsync(w => w.PlanId == plan.Id));
    }

    [Fact]
    public async Task Rotating_progress_advances_only_by_a_credited_finish_or_a_skip()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (w1, w2, w3) = (Def("A", Ex(sets: 1)), Def("B", Ex("pull-up", "Pull-up", sets: 1)), Def("C", Ex("back-squat", "Back squat", sets: 1)));
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([w1, w2, w3], Rotation(w1, w2, w3), weeks: null)));
        var day = Monday;

        var started = (await a.PostAsync<WorkoutDto>("/workouts", StartStep(plan, 0, w1, day))).Data;
        var finished = await a.FinishAsync(started, [await a.AddSetAsync(started.Exercises[0].Id)]);
        Assert.True(finished.Data.QualifiedOccasion);
        Assert.Equal("full", (await PlanAsync(a, plan.Id)).Occasions.Single().ResultOutcome);

        var manual = await a.StartManualAsync();                                  // a manual workout never links
        await a.FinishAsync(manual, [await a.AddSetAsync(manual.Exercises[0].Id)]);
        Assert.Null((await a.SnapshotAsync()).Workouts.Single(w => w.Id == manual.Id).PlanId);
        Assert.Single((await PlanAsync(a, plan.Id)).Occasions);

        var empty = (await a.PostAsync<WorkoutDto>("/workouts", StartStep(plan, 1, w2, day))).Data;
        Assert.Equal("no_data", (await a.FinishAsync(empty, [])).Data.Outcome);   // a no-data finish leaves step 1 pending
        var pending = (await PlanAsync(a, plan.Id)).Occasions.Single(o => o.SequenceIndex == 1);
        Assert.Equal(((string?)null, false), (pending.ResultOutcome, pending.IsSkipped));
        var again = await a.StartPlannedAsync(pending);
        await a.FinishAsync(again, [await a.AddSetAsync(again.Exercises[0].Id)]);
        Assert.Equal(2, (await PlanAsync(a, plan.Id)).Occasions.Count(o => o.ResultOutcome != null)); // next step = materialized count

        var skip = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", new ScheduleChangeRequest(Guid.NewGuid(),
            (await PlanAsync(a, plan.Id)).Revision, "skip", PlanRules.SequenceId(plan.Id, 2), null, day.AddDays(3), 2));
        Assert.Equal("accepted", skip.Status);
        var skipped = skip.Data.Plans.Single().Occasions.Single(o => o.SequenceIndex == 2);
        Assert.Equal((true, (Guid?)w3.Id, day.AddDays(3), 3), (skipped.IsSkipped, skipped.WorkoutId, skipped.ScheduledDate, skipped.Ordinal));
        var replay = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes",
            new ScheduleChangeRequest(skip.Ack!.OperationId, plan.Revision, "skip", skipped.Id, null, day.AddDays(3), 2));
        Assert.Equal(skip.Raw, replay.Raw);                                       // the same skip retried replays; it never advances twice
        Assert.Equal(3, (await PlanAsync(a, plan.Id)).Occasions.Count);
        Assert.Equal(ScheduleRules.OccasionNotEligible, (await SkipStepAsync(a, plan.Id, 2, day)).Code);   // already skipped
        Assert.Equal(ScheduleRules.OccasionNotEligible, (await SkipStepAsync(a, plan.Id, 4, day)).Code);   // a gap
        Assert.Equal(ScheduleRules.OccasionNotFound, (await SkipStepAsync(a, plan.Id, 3, day, Guid.NewGuid())).Code); // not step 3's ID
        Assert.Equal(3, (await PlanAsync(a, plan.Id)).Occasions.Count);

        var move = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", new ScheduleChangeRequest(Guid.NewGuid(),
            (await PlanAsync(a, plan.Id)).Revision, "move", skipped.Id, skipped.ScheduledDate, skipped.ScheduledDate.AddDays(1)));
        Assert.Equal(("conflict", PlanService.NotMovable), (move.Status, move.Code));
        var proposal = await a.PostAsync<ProposalDto>("/proposals", new ProposalRequest(Guid.NewGuid(), Guid.NewGuid(), plan.Id, "schedule",
            [new ProposalMove(skipped.Id, skipped.ScheduledDate, skipped.ScheduledDate.AddDays(1))], null, null));
        Assert.Equal(("rejected", PlanService.NotMovable), (proposal.Status, proposal.Code));

        Assert.Equal("accepted", (await SkipStepAsync(a, plan.Id, 3, day)).Status);
        async Task<AckResult<PlanContextDto>> Unskip(int k) => await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes",
            new ScheduleChangeRequest(Guid.NewGuid(), (await PlanAsync(a, plan.Id)).Revision, "unskip", PlanRules.SequenceId(plan.Id, k), null, null));
        Assert.Equal(ScheduleRules.OccasionNotEligible, (await Unskip(2)).Code);   // step 3 is already materialized
        Assert.Equal("accepted", (await Unskip(3)).Status);
        Assert.False((await PlanAsync(a, plan.Id)).Occasions.Single(o => o.SequenceIndex == 3).IsSkipped);
    }

    [Fact]
    public async Task Skip_retry_of_a_virtual_step_replays_and_never_advances_twice()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var w = Def("A", Ex());
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([w], Rotation(w), weeks: null)));
        var request = new ScheduleChangeRequest(Guid.NewGuid(), plan.Revision, "skip", PlanRules.SequenceId(plan.Id, 0), null, Monday, 0);
        var first = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", request);
        var retry = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", request);
        Assert.Equal("accepted", first.Status);
        Assert.Equal(first.Raw, retry.Raw);
        var after = await PlanAsync(a, plan.Id);
        Assert.Equal(plan.Revision + 1, after.Revision);
        Assert.Equal(0, Assert.Single(after.Occasions).SequenceIndex);
        var paused = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/pause", new PauseRequest(Guid.NewGuid(), (await a.ContextAsync()).ContextRevision, after.Revision, Monday));
        Assert.Equal("accepted", paused.Status);
        Assert.Equal("PLAN_NOT_ACTIVE", (await SkipStepAsync(a, plan.Id, 1, Monday)).Code); // a paused rotation does not advance
    }

    // ------------------------------------------------------------------ revising

    private static async Task<string> RowsAsync(GoHardDb db, Guid workoutId, Guid occasionId) => JsonSerializer.Serialize(new
    {
        workout = await db.Workouts.AsNoTracking().Include(w => w.Exercises).ThenInclude(e => e.Sets).SingleAsync(w => w.Id == workoutId),
        occasion = await db.Occasions.AsNoTracking().SingleAsync(o => o.Id == occasionId),
    });

    [Fact]
    public async Task Accepted_substitution_also_changes_a_built_plans_own_workouts_but_not_recorded_ones()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (wa, wb) = (Def("A", Ex() with { TargetLoadKg = 100m }), Def("B", Ex("barbell-row", "Barbell row")));
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([wa, wb], Fixed((1, wa), (3, wb)))));
        var monday = plan.Occasions.First();
        var done = await a.StartPlannedAsync(monday);
        await a.FinishAsync(done, [await a.AddSetAsync(done.Exercises[0].Id)]);

        var proposal = await a.PostAsync<ProposalDto>("/proposals", new ProposalRequest(Guid.NewGuid(), Guid.NewGuid(), plan.Id, "substitution", null, "bench-press", "dumbbell-bench-press"));
        plan = await PlanAsync(a, plan.Id);
        var accepted = await a.PostAsync<ProposalResult>($"/proposals/{proposal.Data.Id}/accept", new ProposalDecision(Guid.NewGuid(), proposal.Data.Revision, plan.Revision));
        Assert.Equal("accepted", accepted.Status);
        var after = accepted.Data.Context!.Plans.Single();
        Assert.Equal("dumbbell-bench-press", after.Workouts!.Single(w => w.Id == wa.Id).Exercises[0].CatalogKey);
        Assert.Equal("bench-press", after.Occasions.Single(o => o.Id == monday.Id).Prescription[0].CatalogKey); // recorded: its own copy
        Assert.All(after.Occasions.Where(o => o.Id != monday.Id && o.WorkoutId == wa.Id), o => Assert.Equal(("dumbbell-bench-press", (decimal?)null), (o.Prescription[0].CatalogKey, o.Prescription[0].TargetLoadKg)));
        Assert.Null(after.Workouts!.Single(w => w.Id == wa.Id).Exercises[0].TargetLoadKg); // the old exercise's target is not the new one's
        Assert.Equal(100m, after.Occasions.Single(o => o.Id == monday.Id).Prescription[0].TargetLoadKg);
    }

    [Fact]
    public async Task Revise_never_removes_an_occurrence_a_no_data_attempt_points_at()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (wa, wb) = (Def("A", Ex()), Def("B", Ex("barbell-row", "Barbell row")));
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([wa, wb], Fixed((1, wa), (3, wb)))));
        var wednesday = plan.Occasions.Single(o => o.OriginalDate == Monday.AddDays(2));
        var attempt = await a.StartPlannedAsync(wednesday);
        Assert.Equal("no_data", (await a.FinishAsync(attempt, [])).Data.Outcome);    // finished, credits nothing: still pending

        plan = await PlanAsync(a, plan.Id);
        var revised = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}", Revise(plan, Monday.AddDays(1), [wa, wb], Fixed((1, wa)))); // no more Wednesdays
        Assert.Equal("accepted", revised.Status);
        var after = revised.Data.Plans.Single();
        Assert.Contains(after.Occasions, o => o.Id == wednesday.Id);                 // kept: a recorded workout points at it
        Assert.DoesNotContain(after.Occasions, o => o.OriginalDate == Monday.AddDays(9)); // the next Wednesday, with nothing attached, is gone
        Assert.Equal(wednesday.Id, (await a.SnapshotAsync()).Workouts.Single(w => w.Id == attempt.Id).OccasionId);
    }

    [Fact]
    public async Task Revise_keeps_history_open_work_moves_and_one_off_edits()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (wa, wb, wc) = (Def("A", Ex(sets: 1)), Def("B", Ex("barbell-row", "Barbell row")), Def("C", Ex("back-squat", "Back squat")));
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([wa, wb, wc], Fixed((1, wa), (3, wb), (5, wc)))));
        OccasionDto On(PlanDto p, int day) => p.Occasions.Single(o => o.OriginalDate == Monday.AddDays(day));

        var done = await a.StartPlannedAsync(On(plan, 0));                        // Mon: recorded and credited
        var doneFinish = await a.FinishAsync(done, [await a.AddSetAsync(done.Exercises[0].Id)]);
        Assert.True(doneFinish.Data.QualifiedOccasion);
        var open = await a.StartPlannedAsync(On(plan, 2));                        // Wed: in progress
        await a.AddSetAsync(open.Exercises[0].Id);
        plan = await PlanAsync(a, plan.Id);
        var moved = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes",
            new ScheduleChangeRequest(Guid.NewGuid(), plan.Revision, "move", On(plan, 4).Id, Monday.AddDays(4), Monday.AddDays(5)));
        Assert.Equal("accepted", moved.Status);                                   // Fri moved to Sat
        plan = moved.Data.Plans.Single();
        var edit = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}/occasions/{On(plan, 7).Id}",
            new OccasionEditRequest(Guid.NewGuid(), plan.Revision, " Light day ", [Ex(sets: 2)]));
        Assert.Equal("accepted", edit.Status);                                    // next Mon edited on its own
        plan = edit.Data.Plans.Single();
        Assert.True(On(plan, 7).IsCustomised);
        Assert.Equal("Light day", On(plan, 7).Title);
        var proposal = await a.PostAsync<ProposalDto>("/proposals", new ProposalRequest(Guid.NewGuid(), Guid.NewGuid(), plan.Id, "substitution", null, "bench-press", "dumbbell-bench-press"));
        Assert.Equal("open", proposal.Data.State);

        await using (var db = pg.SharedDb())
        {
            var before = await RowsAsync(db, done.Id, On(plan, 0).Id);
            var openBefore = JsonSerializer.Serialize((await a.SnapshotAsync()).Workouts.Single(w => w.Id == open.Id));
            var bv2 = wb with { Name = "B v2", Exercises = [Ex("pull-up", "Pull-up")] };
            var schedule = Fixed((1, wa), (3, bv2), (5, wc), (6, wa));

            var start = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}", Revise(plan, Monday.AddDays(2), [wa, bv2, wc], schedule) with { StartDate = Monday.AddDays(1) });
            Assert.Equal(("rejected", "START_LOCKED"), (start.Status, start.Code));
            var mode = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}", Revise(plan, Monday.AddDays(2), [wa, bv2, wc], Rotation(wa, bv2)) with { DurationWeeks = null });
            Assert.Equal(("rejected", "MODE_LOCKED"), (mode.Status, mode.Code));
            var stale = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}", Revise(plan, Monday.AddDays(2), [wa, bv2, wc], schedule) with { ExpectedPlanRevision = plan.Revision - 1 });
            Assert.Equal(("conflict", Ack.RevisionConflict), (stale.Status, stale.Code));
            Assert.Equal(plan.Revision, stale.Data.Plans.Single().Revision);     // the account's version, to compare with

            var revised = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}", Revise(plan, Monday.AddDays(2), [wa, bv2, wc], schedule));
            Assert.Equal("accepted", revised.Status);
            var after = revised.Data.Plans.Single();
            Assert.Equal(plan.Revision + 1, after.Revision);
            Assert.Equal(8, after.Occasions.Count);
            Assert.Equal(before, await RowsAsync(db, done.Id, On(plan, 0).Id));     // recorded workout, its sets and its credit: unchanged
            Assert.Equal(openBefore, JsonSerializer.Serialize((await a.SnapshotAsync()).Workouts.Single(w => w.Id == open.Id)));
            Assert.Equal(("B", "Barbell row"), (On(after, 2).Title, On(after, 2).Prescription[0].Name));          // open: unchanged
            Assert.Equal((Monday.AddDays(5), "C"), (On(after, 4).ScheduledDate, On(after, 4).Title));            // moved: keeps its date
            Assert.Equal(("Light day", 2), (On(after, 7).Title, On(after, 7).Prescription[0].TargetSets!.Value)); // one-off edit: untouched
            Assert.Equal(("B v2", "Pull-up"), (On(after, 9).Title, On(after, 9).Prescription[0].Name));          // pending: new content
            Assert.Equal((PlanRules.FixedId(plan.Id, Monday.AddDays(5)), "A", 4), (On(after, 5).Id, On(after, 5).Title, On(after, 5).Ordinal));
            Assert.Equal("A", On(after, 12).Title);
            Assert.Equal([1, 2, 3, 4], after.Occasions.Where(o => o.WeekNumber == 1).Select(o => o.Ordinal).Order());
            Assert.Equal("needs_review", (await a.SnapshotAsync()).Proposals.Single().State);
            Assert.Equal("B v2", after.Workouts!.Single(w => w.Id == wb.Id).Name);
        }

        // The open workout still finishes and credits its occasion.
        var openNow = (await a.SnapshotAsync()).Workouts.Single(w => w.Id == open.Id);
        Assert.Equal("accepted", (await a.FinishAsync(openNow, openNow.Exercises.SelectMany(e => e.Sets))).Status);
        Assert.NotNull(On(await PlanAsync(a, plan.Id), 2).ResultOutcome);
    }

    [Fact]
    public async Task Occasion_edit_is_for_pending_fixed_occurrences_only()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var w = Def("A", Ex());
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([w], Fixed((1, w)))));
        var started = await a.StartPlannedAsync(plan.Occasions[0]);
        plan = await PlanAsync(a, plan.Id);
        var busy = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}/occasions/{started.OccasionId}", new OccasionEditRequest(Guid.NewGuid(), plan.Revision, "X", [Ex()]));
        Assert.Equal(("conflict", ScheduleRules.OccasionNotEligible), (busy.Status, busy.Code));
        var bad = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}/occasions/{plan.Occasions[1].Id}", new OccasionEditRequest(Guid.NewGuid(), plan.Revision, "X", [Ex() with { RestSeconds = 901 }]));
        Assert.Equal(("rejected", PlanRules.WorkoutsInvalid), (bad.Status, bad.Code));
        var unknown = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}/occasions/{plan.Occasions[1].Id}", new OccasionEditRequest(Guid.NewGuid(), plan.Revision, "X", [Ex("nope")]));
        Assert.Equal(PlanService.UnknownExercise, unknown.Code);
        Assert.Equal(plan.Revision, (await PlanAsync(a, plan.Id)).Revision);

        var r = Def("R", Ex());
        var rotation = await CreateAsync(a, Create([r], Rotation(r), weeks: null));
        var refused = await a.PutAsync<PlanContextDto>($"/plans/{rotation.Id}/occasions/{PlanRules.SequenceId(rotation.Id, 0)}", new OccasionEditRequest(Guid.NewGuid(), rotation.Revision, "X", [Ex()]));
        Assert.Equal(PlanService.NotMovable, refused.Code);
    }

    // ------------------------------------------------------------------ ownership and older clients

    [Fact]
    public async Task Another_account_cannot_touch_plans_occasions_or_custom_exercises()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var b = await Account.RegisterAsync(pg.Api);
        var custom = await CustomAsync(a);
        var w = Def("A", Ex($"custom:{custom.Id}", custom.Name));
        var plan = await ActivateAsync(a, await CreateAsync(a, Create([w], Fixed((1, w)))));
        var rotation = await CreateAsync(a, Create([w], Rotation(w), weeks: null));
        var before = JsonSerializer.Serialize(await a.ContextAsync());

        var ops = new List<Guid>();
        async Task NotFound<T>(Func<Guid, Task<AckResult<T>>> call)
        {
            var op = Guid.NewGuid();
            ops.Add(op);
            Assert.Equal(HttpStatusCode.NotFound, (await call(op)).Http);
        }
        await NotFound(op => b.PostAsync<PlanContextDto>("/plans", Create([w], Fixed((1, w))) with { OperationId = op, PlanId = plan.Id }));
        await NotFound(op => b.PutAsync<PlanContextDto>($"/plans/{plan.Id}", Revise(plan, Monday, [w], plan.Schedule!) with { OperationId = op }));
        await NotFound(op => b.PutAsync<PlanContextDto>($"/plans/{plan.Id}/occasions/{plan.Occasions[0].Id}", new OccasionEditRequest(op, plan.Revision, "Mine", [Ex()])));
        await NotFound(op => b.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", new ScheduleChangeRequest(op, plan.Revision, "skip", plan.Occasions[0].Id, null, Monday)));
        await NotFound(op => b.PostAsync<PlanContextDto>($"/plans/{rotation.Id}/schedule-changes", new ScheduleChangeRequest(op, rotation.Revision, "skip", PlanRules.SequenceId(rotation.Id, 0), null, Monday, 0)));
        await NotFound(op => b.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(op, Guid.NewGuid(), "planned", plan.Occasions[0].Id, "A", Monday, DateTime.UtcNow, [])));
        await NotFound(op => b.PostAsync<WorkoutDto>("/workouts", StartStep(rotation, 0, w, Monday) with { OperationId = op }));
        await NotFound(op => b.PostAsync<PlanContextDto>($"/plans/{rotation.Id}/activate", b.ActivateRequestFor(rotation, 1, operationId: op)));
        await NotFound(op => b.PutAsync<CustomExerciseDto>($"/custom-exercises/{custom.Id}", new CustomExercisePutRequest(op, custom.Revision, "Mine", "Legs", "Machine", false, false)));
        await NotFound(op => b.PutAsync<CustomExerciseDto>($"/custom-exercises/{custom.Id}", new CustomExercisePutRequest(op, 0, "Mine", "Legs", "Machine", false, false)));
        var borrowed = await b.PostAsync<PlanContextDto>("/plans", Create([w], Fixed((1, w))));
        Assert.Equal(("rejected", PlanService.UnknownExercise), (borrowed.Status, borrowed.Code));

        await using var db = pg.SharedDb();
        Assert.False(await db.Operations.AnyAsync(o => ops.Contains(o.OperationId)));   // nothing recorded for any of them
        Assert.Equal(before, JsonSerializer.Serialize(await a.ContextAsync()));
        Assert.Equal(custom, (await a.SnapshotAsync()).CustomExercises!.Single());
        Assert.Empty((await b.SnapshotAsync()).CustomExercises!);
        Assert.Empty((await b.ContextAsync()).Plans);
    }

    [Fact]
    public async Task Custom_exercises_are_revisioned_like_saved_foods()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var id = Guid.NewGuid();
        var create = new CustomExercisePutRequest(Guid.NewGuid(), 0, "  Sled push ", "Legs", "Machine", false, false);
        var first = await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{id}", create);
        Assert.Equal(new CustomExerciseDto(id, "Sled push", "Legs", "Machine", false, false, 1), first.Data);
        Assert.Equal(first.Raw, (await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{id}", create)).Raw);
        var renamed = await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{id}", create with { OperationId = Guid.NewGuid(), ExpectedRevision = 1, Name = "Sled drive", IsTimed = true });
        Assert.Equal(("Sled drive", true, 2), (renamed.Data.Name, renamed.Data.IsTimed, renamed.Data.Revision));
        var stale = await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{id}", create with { OperationId = Guid.NewGuid(), ExpectedRevision = 1, Name = "Old" });
        Assert.Equal((HttpStatusCode.Conflict, Ack.RevisionConflict, "Sled drive"), (stale.Http, stale.Code, stale.Data.Name));
        Assert.Equal(CustomExerciseService.NameInvalid, (await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{Guid.NewGuid()}", create with { OperationId = Guid.NewGuid(), Name = " " })).Code);
        Assert.Equal(HttpStatusCode.NotFound, (await a.PutAsync<CustomExerciseDto>($"/custom-exercises/{Guid.NewGuid()}", create with { OperationId = Guid.NewGuid(), ExpectedRevision = 3 })).Http);
        Assert.Equal(renamed.Data, (await a.SnapshotAsync()).CustomExercises!.Single());
        var caps = await a.Http.GetStringAsync("/api/v1/capabilities");
        Assert.Contains("\"plans.builder\"", caps);
        Assert.Contains("\"exercises.custom\"", caps);
    }

    [Fact]
    public async Task Older_builds_cannot_rebuild_a_built_plan_and_their_recorded_commands_still_replay()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var w = Def("A", Ex());
        var plan = await CreateAsync(a, Create([w], Fixed((1, w), (4, w))));
        var update = await a.PutAsync<PlanContextDto>($"/plan-drafts/{plan.Id}", new PlanDraftUpdateRequest(Guid.NewGuid(), plan.Revision, Monday, [1, 3, 5], 4, null));
        Assert.Equal(("rejected", PlanService.NeedsNewerApp), (update.Status, update.Code));
        Assert.Equal(JsonSerializer.Serialize(plan), JsonSerializer.Serialize(await PlanAsync(a, plan.Id)));

        // A start sent by an older build (no planId / sequenceIndex / targetLoadKg / notes) and its retry by this build are one command.
        var (op, workoutId, exerciseId) = (Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid());
        var old = new
        {
            operationId = op, workoutId, kind = "manual", occasionId = (Guid?)null, title = "Old build", dayKey = Monday, startedAtUtc = new DateTime(2026, 10, 12, 7, 0, 0, DateTimeKind.Utc),
            exercises = new[] { new { id = exerciseId, ordinal = 1, name = "Push-up", catalogKey = "push-up", occurrenceKey = (string?)null, isPrescribed = false,
                isTimed = false, targetSets = (int?)null, targetRepsMin = (int?)null, targetRepsMax = (int?)null, targetDurationSeconds = (int?)null,
                restSeconds = (int?)null, substitutedForKey = (string?)null } },
        };
        var first = await a.PostAsync<WorkoutDto>("/workouts", old);
        Assert.Equal("accepted", first.Status);
        Assert.DoesNotContain("targetLoadKg", first.Raw);                          // omitted when null, as before
        var retry = await a.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(op, workoutId, "manual", null, "Old build", Monday, old.startedAtUtc,
            [new ExerciseSpec(exerciseId, 1, "Push-up", "push-up", null, false, false, null, null, null, null, null, null)]));
        Assert.Equal(first.Raw, retry.Raw);
    }

    // ------------------------------------------------------------------ upgrade and reference data

    [Fact]
    public async Task Upgrade_keeps_legacy_plans_workouts_and_open_sessions_working()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: false);
        await using (var db = PostgresFixture.NewDb(cs))
        {
            await db.GetService<IMigrator>().MigrateAsync("AddFoodDiscoveryAndGoals");
            await Legacy.InsertAsync(db);
            await db.Database.MigrateAsync();
            Assert.True((await SchemaReadinessService.CheckAsync(db, default)).IsReady);
            await CatalogSeeder.SeedAsync(db, default);
        }

        await using var api = new ApiFactory(cs);
        var http = api.CreateClient();
        var login = await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(Legacy.Email, Legacy.Password));
        var auth = (await login.Content.ReadFromJsonAsync<AuthResponse>(Account.Json))!;
        http.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);
        var a = new Account(http, auth, Legacy.Password);

        var snapshot = await a.SnapshotAsync();
        var plan = snapshot.Context.Plans.Single();
        Assert.Equal((Legacy.PlanId, "active", 1, 1, "baseline-a"), (plan.Id, plan.Lifecycle, plan.Revision, plan.MinRecoveryDays, plan.BaselineId));
        Assert.Equal(Account.Setup(Legacy.Start, 2) with { Weekdays = null! }, plan.Setup! with { Weekdays = null! });
        Assert.Equal([1, 3, 5], plan.Setup!.Weekdays);
        Assert.Null(plan.Workouts);
        Assert.Null(plan.Schedule);
        Assert.Equal((false, (int?)null, (string?)null), (plan.IsOngoing, plan.TimeBudgetMinutes, plan.TemplateId));
        Assert.Equal(5, plan.Occasions.Count);
        Assert.All(plan.Occasions, o => Assert.Equal(((Guid?)null, (int?)null, false), (o.WorkoutId, o.SequenceIndex, o.IsCustomised)));
        Assert.All(plan.Occasions, o => Assert.Equal(new PrescriptionExercise("e1", "bench-press", "Bench press", false, 1, 8, 12, null, 90), Assert.Single(o.Prescription)));
        Assert.Equal(("full", (Guid?)Legacy.Done), (plan.Occasions[0].ResultOutcome, plan.Occasions[0].ResultWorkoutId));
        var done = snapshot.Workouts.Single(w => w.Id == Legacy.Done);
        Assert.Equal(("full", 2, 1, 60m), (done.Outcome, done.Revision, done.PerformedSets, done.Exercises[0].Sets[0].LoadKg!.Value));
        Assert.Equal(((decimal?)null, (string?)null), (done.Exercises[0].TargetLoadKg, done.Exercises[0].Notes));
        Assert.Empty(snapshot.CustomExercises!);

        OccasionDto O(PlanDto p, Guid id) => p.Occasions.Single(o => o.Id == id);
        Assert.Equal("accepted", (await a.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "planned", Legacy.Next, "Session",
            Legacy.Start.AddDays(5), DateTime.UtcNow, Account.Snapshot(O(plan, Legacy.Next))))).Status);
        plan = (await a.ContextAsync()).Plans.Single();
        var move = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", new ScheduleChangeRequest(Guid.NewGuid(), plan.Revision, "move", Legacy.Movable,
            Legacy.Start.AddDays(7), Legacy.Start.AddDays(8)));
        Assert.Equal("accepted", move.Status);
        var skip = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", new ScheduleChangeRequest(Guid.NewGuid(), move.Data.Plans.Single().Revision, "skip",
            Legacy.Skippable, null, null));
        Assert.Equal("accepted", skip.Status);

        var openWorkout = (await a.SnapshotAsync()).Workouts.Single(w => w.Id == Legacy.Open);
        var finish = await a.FinishAsync(openWorkout, openWorkout.Exercises.SelectMany(e => e.Sets));
        Assert.Equal(("accepted", "full", true), (finish.Status, finish.Data.Outcome, finish.Data.QualifiedOccasion));

        var ctx = await a.ContextAsync();
        plan = ctx.Plans.Single();
        var paused = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/pause", new PauseRequest(Guid.NewGuid(), ctx.ContextRevision, plan.Revision, Legacy.Start.AddDays(8)));
        Assert.Equal("accepted", paused.Status);
        var resumed = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/resume", new ResumeRequest(Guid.NewGuid(), paused.Data.ContextRevision,
            paused.Data.Plans.Single().Revision, [new ScheduleChange(Legacy.Movable, Legacy.Start.AddDays(8), Legacy.Start.AddDays(12))], null, Legacy.Start.AddDays(9)));
        Assert.Equal("accepted", resumed.Status);
        Assert.Equal(Legacy.Start.AddDays(12), O(resumed.Data.Plans.Single(), Legacy.Movable).ScheduledDate);
        Assert.Equal(Legacy.Start.AddDays(7), O(resumed.Data.Plans.Single(), Legacy.Movable).OriginalDate);

        // Revised into a built fixed plan: pending legacy occasions from the effective date are replaced; the rest stay.
        plan = resumed.Data.Plans.Single();
        var w = Def("Full body", Ex());
        var built = await a.PutAsync<PlanContextDto>($"/plans/{plan.Id}", new PlanReviseRequest(Guid.NewGuid(), plan.Revision, Legacy.Start.AddDays(7), "Strength base",
            plan.StartDate, 2, null, [w], Fixed((1, w), (3, w), (5, w))));
        Assert.Equal("accepted", built.Status);
        var after = built.Data.Plans.Single();
        Assert.Equal(PlanRules.Fixed, after.Schedule!.Mode);
        Assert.DoesNotContain(after.Occasions, o => o.Id == Legacy.Movable);
        Assert.Equal(new[] { Legacy.Credited, Legacy.InProgress, Legacy.Next, Legacy.Skippable }.Order(), after.Occasions.Where(o => o.WorkoutId is null).Select(o => o.Id).Order());
        Assert.Equal(new[] { 7, 10, 12 }.Select(d => PlanRules.FixedId(plan.Id, Legacy.Start.AddDays(d))).Order(), after.Occasions.Where(o => o.WorkoutId == w.Id).Select(o => o.Id).Order());
    }

    /// <summary>Rows as the build before the plan builder wrote them.</summary>
    private static class Legacy
    {
        public const string Email = "legacy@example.test", Password = "correct horse battery";
        public static readonly DateOnly Start = new(2026, 10, 9);
        public static readonly Guid User = Guid.NewGuid(), PlanId = Guid.NewGuid(), Done = Guid.NewGuid(), Open = Guid.NewGuid(),
            Credited = Guid.NewGuid(), InProgress = Guid.NewGuid(), Next = Guid.NewGuid(), Movable = Guid.NewGuid(), Skippable = Guid.NewGuid();

        public static async Task InsertAsync(GoHardDb db)
        {
            const string setup = """{"direction":"strength","sessionsPerWeek":3,"minutesPerSession":45,"equipment":"full_gym","experience":"comfortable","limitations":null,"blockWeeks":2,"weekdays":[1,3,5],"startDate":"2026-10-09"}""";
            const string prescription = """[{"occurrenceKey":"e1","catalogKey":"bench-press","name":"Bench press","isTimed":false,"targetSets":1,"targetRepsMin":8,"targetRepsMax":12,"targetDurationSeconds":null,"restSeconds":90}]""";
            var hash = new PasswordHasher<User>().HashPassword(new User(), Password);
            await db.Database.ExecuteSqlAsync($"""INSERT INTO "Users" ("Id","Email","PasswordHash","DisplayName","Appearance","LoadUnit","RemindersEnabled","Revision","SecurityStamp","CreatedAtUtc") VALUES ({User},{Email},{hash},'Old','dark','kg',false,1,'stamp',now())""");
            await db.Database.ExecuteSqlAsync($"""INSERT INTO "Plans" ("Id","UserId","Title","Lifecycle","IsArchived","StartDate","BlockWeeks","MinRecoveryDays","SetupJson","BaselineId","Revision","CreatedAtUtc") VALUES ({PlanId},{User},'Strength base','active',false,{Start},2,1,{setup},'baseline-a',1,now())""");
            await db.Database.ExecuteSqlAsync($"""INSERT INTO "TrainingContexts" ("UserId","PrimaryPlanId","Revision") VALUES ({User},{PlanId},2)""");
            foreach (var (id, week, ordinal, day) in new[] { (Credited, 1, 1, 0), (InProgress, 1, 2, 3), (Next, 1, 3, 5), (Movable, 2, 1, 7), (Skippable, 2, 2, 10) })
                await db.Database.ExecuteSqlAsync($"""INSERT INTO "Occasions" ("Id","PlanId","UserId","WeekNumber","Ordinal","Title","OriginalDate","ScheduledDate","IsSkipped","PrescriptionJson") VALUES ({id},{PlanId},{User},{week},{ordinal},'Session',{Start.AddDays(day)},{Start.AddDays(day)},false,{prescription})""");
            await db.Database.ExecuteSqlAsync($"""UPDATE "Occasions" SET "ResultOutcome" = 'full', "ResultWorkoutId" = {Done} WHERE "Id" = {Credited}""");
            foreach (var (workout, occasion, finished) in new[] { (Done, Credited, true), (Open, InProgress, false) })
            {
                var exercise = Guid.NewGuid();
                if (finished)
                    await db.Database.ExecuteSqlAsync($"""INSERT INTO "Workouts" ("Id","UserId","PlanId","OccasionId","Kind","Title","DayKey","StartedAtUtc","FinishedAtUtc","ActiveDurationSeconds","Outcome","PerformedSets","PerformedExercises","QualifiedOccasion","Revision") VALUES ({workout},{User},{PlanId},{occasion},'planned','Session',{Start},now(),now(),1800,'full',1,1,true,2)""");
                else
                    await db.Database.ExecuteSqlAsync($"""INSERT INTO "Workouts" ("Id","UserId","PlanId","OccasionId","Kind","Title","DayKey","StartedAtUtc","PerformedSets","PerformedExercises","QualifiedOccasion","Revision") VALUES ({workout},{User},{PlanId},{occasion},'planned','Session',{Start.AddDays(3)},now(),0,0,false,1)""");
                await db.Database.ExecuteSqlAsync($"""INSERT INTO "WorkoutExercises" ("Id","WorkoutId","UserId","Ordinal","Name","CatalogKey","OccurrenceKey","IsPrescribed","IsTimed","TargetSets","TargetRepsMin","TargetRepsMax","RestSeconds") VALUES ({exercise},{workout},{User},1,'Bench press','bench-press','e1',true,false,1,8,12,90)""");
                await db.Database.ExecuteSqlAsync($"""INSERT INTO "WorkoutSets" ("Id","ExerciseId","WorkoutId","UserId","Reps","LoadKg","PerformedAtUtc","Revision") VALUES ({Guid.NewGuid()},{exercise},{workout},{User},8,60,now(),1)""");
            }
        }
    }

    [Fact]
    public async Task Seeding_the_catalog_twice_is_idempotent_and_keeps_existing_keys()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);                    // seeded once already
        await using var db = PostgresFixture.NewDb(cs);
        db.CatalogExercises.Add(new CatalogExercise { Key = "retired-move", Name = "Retired move", Category = "Back", Equipment = "Barbell" });
        await db.SaveChangesAsync();
        var shipped = await CatalogSeeder.SeedAsync(db, default);
        await CatalogSeeder.SeedAsync(db, default);
        var keys = await db.CatalogExercises.AsNoTracking().Select(c => c.Key).ToListAsync();
        Assert.Equal(shipped + 1, keys.Count);
        Assert.Contains("retired-move", keys);                                     // a key in use is never deleted
        Assert.Contains("dead-bug", keys);
    }
}
