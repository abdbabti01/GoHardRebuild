using System.Net;
using System.Net.Http.Json;
using GoHard.Api.Application;
using GoHard.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>B2–B6, R1, R2: primary context, reviewed lifecycle commands, drafts and proposals.</summary>
[Collection("api")]
public class PlanTests(PostgresFixture pg)
{
    [Fact]
    public async Task ReviewedFridaySurvivesRestart()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        Guid planId; string email; string password;
        await using (var first = new ApiFactory(cs))
        {
            var a = await Account.RegisterAsync(first);
            (email, password) = (a.Auth.Profile.Email, a.Password);
            var plan = await a.ActivePlanAsync(Account.Friday);
            planId = plan.Id;
            Assert.Equal(Account.Friday, plan.StartDate);                       // never snapped to Monday
            Assert.Equal(Account.Friday, plan.Occasions.Min(o => o.ScheduledDate));
        }
        for (var boot = 0; boot < 2; boot++)                                    // two more host starts change nothing
        {
            await using var api = new ApiFactory(cs);
            var http = api.CreateClient();
            var login = await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(email, password));
            var auth = await login.Content.ReadFromJsonAsync<AuthResponse>(Account.Json);
            http.DefaultRequestHeaders.Authorization = new("Bearer", auth!.AccessToken);
            var ctx = (await http.GetFromJsonAsync<SnapshotDto>("/api/v1/sync/snapshot", Account.Json))!.Context;
            var reloaded = ctx.Plans.Single(p => p.Id == planId);
            Assert.Equal(planId, ctx.PrimaryPlanId);
            Assert.Equal(Account.Friday, reloaded.StartDate);
            Assert.Equal("active", reloaded.Lifecycle);
        }
    }

    [Fact]
    public async Task ConcurrentAssignmentsHaveOneWinner()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var one = await a.DraftAsync();
        var two = await a.DraftAsync();
        var ctx = await a.ContextAsync();

        var results = await Task.WhenAll(
            a.PostAsync<PlanContextDto>($"/plans/{one.Id}/activate", a.ActivateRequestFor(one, ctx.ContextRevision)),
            a.PostAsync<PlanContextDto>($"/plans/{two.Id}/activate", a.ActivateRequestFor(two, ctx.ContextRevision)));

        Assert.Single(results, r => r.Status == "accepted");
        var loser = Assert.Single(results, r => r.Status == "conflict");
        Assert.Equal(Ack.RevisionConflict, loser.Code);
        var after = await a.ContextAsync();
        Assert.Single(after.Plans, p => p.Lifecycle == "active");
        Assert.Equal(after.Plans.Single(p => p.Lifecycle == "active").Id, after.PrimaryPlanId);
        Assert.Equal(2, after.Plans.Count);                                     // the losing draft is retained for review
    }

    [Fact]
    public async Task LostResponseRetryReturnsSameAssignment_and_changed_payload_is_a_mismatch()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var draft = await a.DraftAsync();
        var request = a.ActivateRequestFor(draft, (await a.ContextAsync()).ContextRevision);

        var first = await a.PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", request);
        // The context revision has already advanced; the same operation still returns the original decision.
        var retry = await a.PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", request);
        Assert.Equal("accepted", first.Status);
        Assert.Equal(first.Raw, retry.Raw);
        Assert.Equal(first.Data.PrimaryPlanId, retry.Data.PrimaryPlanId);

        var changed = await a.PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", request with { EffectiveDate = Account.Friday.AddDays(1) });
        Assert.Equal((HttpStatusCode.Conflict, Ack.PayloadMismatch), (changed.Http, changed.Code));
    }

    [Fact]
    public async Task Foreign_plan_is_not_found_and_reviewed_dates_must_match_the_draft()
    {
        var owner = await Account.RegisterAsync(pg.Api);
        var intruder = await Account.RegisterAsync(pg.Api);
        var draft = await owner.DraftAsync();
        var foreign = await intruder.PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", intruder.ActivateRequestFor(draft, 1));
        Assert.Equal(HttpStatusCode.NotFound, foreign.Http);

        var request = owner.ActivateRequestFor(draft, (await owner.ContextAsync()).ContextRevision);
        var tampered = request with { ReviewedDates = request.ReviewedDates.Select((d, i) => i == 0 ? d with { Date = d.Date.AddDays(3) } : d).ToList() };
        var stale = await owner.PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", tampered);
        Assert.Equal(("conflict", ScheduleRules.StaleReview), (stale.Status, stale.Code));
        Assert.Null((await owner.ContextAsync()).PrimaryPlanId);
    }

    [Fact]
    public async Task Replacement_requires_naming_the_current_primary_and_preserves_the_open_workout()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var current = await a.ActivePlanAsync();
        var open = await a.StartPlannedAsync(current.Occasions[0]);
        var set = await a.AddSetAsync(open.Exercises[0].Id, 5, 100m);
        var next = await a.DraftAsync(Account.Friday.AddDays(14));
        var ctx = await a.ContextAsync();

        var silent = await a.PostAsync<PlanContextDto>($"/plans/{next.Id}/activate", a.ActivateRequestFor(next, ctx.ContextRevision));
        Assert.Equal(("conflict", "PRIMARY_EXISTS"), (silent.Status, silent.Code));

        var replaced = await a.PostAsync<PlanContextDto>($"/plans/{next.Id}/activate", a.ActivateRequestFor(next, ctx.ContextRevision, replace: current.Id));
        Assert.Equal("accepted", replaced.Status);
        Assert.Equal(next.Id, replaced.Data.PrimaryPlanId);
        Assert.Equal("paused", replaced.Data.Plans.Single(p => p.Id == current.Id).Lifecycle);

        var workout = (await a.SnapshotAsync()).Workouts.Single();
        Assert.Null(workout.FinishedAtUtc);                                     // not finished, not deleted
        Assert.Equal((current.Id, current.Occasions[0].Id), (workout.PlanId, workout.OccasionId));
        Assert.Equal(set, workout.Exercises[0].Sets.Single());
    }

    [Fact]
    public async Task PauseLeavesOpenWorkoutUntouched_and_ResumeMovesOnlyPendingOccasions()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var (first, second, third) = (plan.Occasions[0], plan.Occasions[1], plan.Occasions[2]);
        var open = await a.StartPlannedAsync(first);
        await a.AddSetAsync(open.Exercises[0].Id);
        var skip = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", new ScheduleChangeRequest(Guid.NewGuid(), plan.Revision, "skip", second.Id, null, null));
        plan = skip.Data.Plans.Single();
        var before = (await a.SnapshotAsync()).Workouts.Single();

        var ctx = await a.ContextAsync();
        var paused = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/pause", new PauseRequest(Guid.NewGuid(), ctx.ContextRevision, plan.Revision, Account.Friday.AddDays(1)));
        Assert.Equal("accepted", paused.Status);
        plan = paused.Data.Plans.Single();
        Assert.Equal(("paused", plan.Id), (plan.Lifecycle, paused.Data.PrimaryPlanId)); // a paused primary keeps the slot
        Assert.Equivalent(before, (await a.SnapshotAsync()).Workouts.Single());

        // Resume a week later: every pending occasion shifts by seven days; open and skipped ones keep their dates.
        var pending = plan.Occasions.Where(o => o.Id != first.Id && o.Id != second.Id).ToList();
        var changes = pending.Select(o => new ScheduleChange(o.Id, o.ScheduledDate, o.ScheduledDate.AddDays(7))).ToList();
        var touchingOpen = changes.Append(new ScheduleChange(first.Id, first.ScheduledDate, first.ScheduledDate.AddDays(7))).ToList();
        var rejected = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/resume",
            new ResumeRequest(Guid.NewGuid(), paused.Data.ContextRevision, plan.Revision, touchingOpen, null, Account.Friday.AddDays(8)));
        Assert.Equal(("conflict", ScheduleRules.OccasionNotEligible), (rejected.Status, rejected.Code));

        var resumed = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/resume",
            new ResumeRequest(Guid.NewGuid(), paused.Data.ContextRevision, plan.Revision, changes, null, Account.Friday.AddDays(8)));
        Assert.Equal("accepted", resumed.Status);
        var after = resumed.Data.Plans.Single();
        Assert.Equal("active", after.Lifecycle);
        Assert.Equal(first.ScheduledDate, after.Occasions.Single(o => o.Id == first.Id).ScheduledDate);
        Assert.Equal(second.ScheduledDate, after.Occasions.Single(o => o.Id == second.Id).ScheduledDate);
        Assert.True(after.Occasions.Single(o => o.Id == second.Id).IsSkipped);
        var moved = after.Occasions.Single(o => o.Id == third.Id);
        Assert.Equal((third.ScheduledDate.AddDays(7), third.OriginalDate), (moved.ScheduledDate, moved.OriginalDate));
        Assert.Equivalent(before, (await a.SnapshotAsync()).Workouts.Single());
    }

    [Fact]
    public async Task MoveDoesNotCreateAnotherOccasion_and_SkipDoesNotAwardCompletion()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var target = plan.Occasions.First(o => o.WeekNumber == 2);
        var weekThree = plan.Occasions.Where(o => o.WeekNumber == 3).Select(o => (o.Id, o.ScheduledDate)).ToList();
        var to = target.ScheduledDate.AddDays(1);

        var moved = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes",
            new ScheduleChangeRequest(Guid.NewGuid(), plan.Revision, "move", target.Id, target.ScheduledDate, to));
        Assert.Equal("accepted", moved.Status);
        var after = moved.Data.Plans.Single();
        Assert.Equal(plan.Occasions.Select(o => o.Id).Order(), after.Occasions.Select(o => o.Id).Order());   // same occasions, no duplicate
        var same = after.Occasions.Single(o => o.Id == target.Id);
        Assert.Equal((2, target.OriginalDate, to), (same.WeekNumber, same.OriginalDate, same.ScheduledDate));
        Assert.Equal(weekThree, after.Occasions.Where(o => o.WeekNumber == 3).Select(o => (o.Id, o.ScheduledDate)).ToList());

        var collision = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes",
            new ScheduleChangeRequest(Guid.NewGuid(), after.Revision, "move", target.Id, to, after.Occasions.First(o => o.Id != target.Id && o.WeekNumber == 2).ScheduledDate));
        Assert.Equal(ScheduleRules.RecoveryCollision, collision.Code);

        var skipped = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes",
            new ScheduleChangeRequest(Guid.NewGuid(), after.Revision, "skip", target.Id, null, null));
        var occasion = skipped.Data.Plans.Single().Occasions.Single(o => o.Id == target.Id);
        Assert.True(occasion.IsSkipped);
        Assert.Null(occasion.ResultOutcome);                                    // skipped is not performed
        Assert.Empty((await a.SnapshotAsync()).Workouts);                       // no fabricated workout or sets

        var startSkipped = await a.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "planned", target.Id,
            "x", to, DateTime.UtcNow, Account.Snapshot(target)));
        Assert.Equal(("conflict", "OCCASION_NOT_ELIGIBLE"), (startSkipped.Status, startSkipped.Code));
    }

    [Fact]
    public async Task Start_and_skip_racing_for_one_occasion_cannot_both_win()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var target = plan.Occasions[0];
        var start = a.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "planned", target.Id, target.Title,
            target.ScheduledDate, DateTime.UtcNow, Account.Snapshot(target)));
        var skip = a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/schedule-changes", new ScheduleChangeRequest(Guid.NewGuid(), plan.Revision, "skip", target.Id, null, null));
        await Task.WhenAll(start, skip);
        Assert.Single(new[] { (await start).Status, (await skip).Status }, s => s == "accepted");
    }

    [Fact]
    public async Task CloseKeepsOpenWorkoutAttribution_and_ArchiveDoesNotChangeOutcome()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var open = await a.StartPlannedAsync(plan.Occasions[0]);
        var set = await a.AddSetAsync(open.Exercises[0].Id);
        var ctx = await a.ContextAsync();

        var primaryArchive = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/archive", new ArchiveRequest(Guid.NewGuid(), plan.Revision, true));
        Assert.Equal("PLAN_IS_PRIMARY", primaryArchive.Code);

        var closed = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/close", new CloseRequest(Guid.NewGuid(), ctx.ContextRevision, plan.Revision, "stopped_early", Account.Friday.AddDays(2)));
        Assert.Equal("accepted", closed.Status);
        Assert.Null(closed.Data.PrimaryPlanId);                                 // the primary slot is free
        var closedPlan = closed.Data.Plans.Single();
        Assert.Equal(("closed", "stopped_early"), (closedPlan.Lifecycle, closedPlan.ClosureIntent));

        // W4 joined case: the open workout still finishes, attributed to the closed block.
        var finished = await a.FinishAsync(open, [set]);
        Assert.Equal(("accepted", "partial", plan.Id), (finished.Status, finished.Data.Outcome, finished.Data.PlanId));
        Assert.True(finished.Data.QualifiedOccasion);

        var archived = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/archive", new ArchiveRequest(Guid.NewGuid(), closedPlan.Revision, true));
        var hidden = archived.Data.Plans.Single();
        Assert.Equal((true, "closed", "stopped_early"), (hidden.IsArchived, hidden.Lifecycle, hidden.ClosureIntent));
        Assert.Equal("partial", hidden.Occasions.Single(o => o.Id == plan.Occasions[0].Id).ResultOutcome);
        Assert.Single((await a.SnapshotAsync()).Workouts);                      // history survives close and archive
    }

    [Fact]
    public async Task UnsupportedSetupDoesNotActivateFallback_and_SupportedDraftNeedsNoAiCall()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var unsupported = await a.PostAsync<PlanDraftResult>("/plan-drafts", new PlanDraftRequest(Guid.NewGuid(), Guid.NewGuid(),
            Account.Setup() with { Equipment = "dumbbells_only", Limitations = "sore shoulder", SessionsPerWeek = 3 }, null, null));
        Assert.Equal(("accepted", "fit_feedback"), (unsupported.Status, unsupported.Data.Kind));
        Assert.Contains("UNSUPPORTED_EQUIPMENT", unsupported.Data.Feedback);
        Assert.Contains("UNREVIEWED_LIMITATION", unsupported.Data.Feedback);
        var ctx = await a.ContextAsync();
        Assert.Empty(ctx.Plans);                                                // no fabricated fallback plan
        Assert.Null(ctx.PrimaryPlanId);

        // The default host has no AI provider configured at all; a supported draft is still created.
        var draft = await a.DraftAsync(weeks: 8);
        Assert.Equal(("draft", "strength-full-gym-3x45-v1", 24), (draft.Lifecycle, draft.BaselineId, draft.Occasions.Count));
        Assert.All(draft.Occasions, o => Assert.NotEmpty(o.Prescription));
        Assert.Null((await a.ContextAsync()).PrimaryPlanId);                    // a draft never drives Today

        var invalidDays = await a.PostAsync<PlanDraftResult>("/plan-drafts", new PlanDraftRequest(Guid.NewGuid(), Guid.NewGuid(),
            Account.Setup() with { Weekdays = [1, 2, 3] }, null, null));
        Assert.Equal(("rejected", ScheduleRules.RecoveryCollision), (invalidDays.Status, invalidDays.Code));
    }

    [Fact]
    public async Task Duplicate_draft_submission_creates_one_plan_and_draft_edits_are_reviewable()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var request = new PlanDraftRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Setup(), null, null);
        var first = await a.PostAsync<PlanDraftResult>("/plan-drafts", request);
        var retry = await a.PostAsync<PlanDraftResult>("/plan-drafts", request);
        Assert.Equal(first.Raw, retry.Raw);
        var draft = (await a.ContextAsync()).Plans.Single();

        var edited = await a.PutAsync<PlanContextDto>($"/plan-drafts/{draft.Id}", new PlanDraftUpdateRequest(Guid.NewGuid(), draft.Revision, new DateOnly(2026, 10, 12), [2, 4, 6], 8, null));
        var plan = edited.Data.Plans.Single();
        Assert.Equal((new DateOnly(2026, 10, 12), 8, 24, draft.Revision + 1), (plan.StartDate, plan.BlockWeeks, plan.Occasions.Count, plan.Revision));
        Assert.Equal(new DateOnly(2026, 10, 13), plan.Occasions.Min(o => o.ScheduledDate));

        // Activating with the review made before the edit is refused: different content can never slip in.
        var staleActivate = await a.PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", a.ActivateRequestFor(draft, (await a.ContextAsync()).ContextRevision));
        Assert.Equal(Ack.RevisionConflict, staleActivate.Code);
    }

    [Fact]
    public async Task Manual_plan_drafts_work_without_a_baseline()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var manual = new List<ManualWorkoutSpec>
        {
            new("Push", [new("m1", "push-up", "Push-up", false, 3, 8, 12, null, 60)]),
            new("Hold", [new("m2", "plank", "Plank", true, null, null, null, 30, 45)]),
        };
        var id = Guid.NewGuid();
        var r = await a.PostAsync<PlanDraftResult>("/plan-drafts", new PlanDraftRequest(Guid.NewGuid(), id,
            new PlanSetup("custom", 2, 20, "bodyweight", "new", "anything", 2, [2, 6], Account.Friday), "Home plan", manual));
        var plan = r.Data.Context!.Plans.Single(p => p.Id == id);
        Assert.Equal(("supported_draft", "Home plan", null, 4), (r.Data.Kind, plan.Title, plan.BaselineId, plan.Occasions.Count));
        Assert.Equal(["Push", "Hold", "Push", "Hold"], plan.Occasions.Select(o => o.Title));
    }

    [Fact]
    public async Task BusyWeekOnlyChangesReviewedWeek_and_ContinuationDoesNotActivate()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var weekTwo = plan.Occasions.Where(o => o.WeekNumber == 2).OrderBy(o => o.ScheduledDate).ToList();
        var others = plan.Occasions.Where(o => o.WeekNumber != 2).Select(o => (o.Id, o.ScheduledDate)).ToList();
        var move = new ProposalMove(weekTwo[0].Id, weekTwo[0].ScheduledDate, weekTwo[0].ScheduledDate.AddDays(1));

        var proposed = await a.PostAsync<ProposalDto>("/proposals", new ProposalRequest(Guid.NewGuid(), Guid.NewGuid(), plan.Id, "schedule", [move], null, null));
        Assert.Equal(("accepted", "open"), (proposed.Status, proposed.Data.State));
        Assert.NotEmpty(proposed.Data.Explanation);
        // Generating a proposal changes nothing.
        Assert.Equal(plan.Revision, (await a.ContextAsync()).Plans.Single().Revision);

        var accepted = await a.PostAsync<ProposalResult>($"/proposals/{proposed.Data.Id}/accept", new ProposalDecision(Guid.NewGuid(), proposed.Data.Revision, plan.Revision));
        Assert.Equal("accepted", accepted.Status);
        var after = accepted.Data.Context!.Plans.Single();
        Assert.Equal(move.To, after.Occasions.Single(o => o.Id == move.OccasionId).ScheduledDate);
        Assert.Equal(others, after.Occasions.Where(o => o.WeekNumber != 2).Select(o => (o.Id, o.ScheduledDate)).ToList());

        var twice = await a.PostAsync<ProposalResult>($"/proposals/{proposed.Data.Id}/accept", new ProposalDecision(Guid.NewGuid(), accepted.Data.Proposal.Revision, after.Revision));
        Assert.Equal("PROPOSAL_NOT_OPEN", twice.Code);

        var newId = Guid.NewGuid();
        var continued = await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/continue", new ContinueRequest(Guid.NewGuid(), newId, plan.StartDate.AddDays(28)));
        Assert.Equal("draft", continued.Data.Plans.Single(p => p.Id == newId).Lifecycle);
        Assert.Equal(plan.Id, continued.Data.PrimaryPlanId);                    // nothing was activated or replaced
    }

    [Fact]
    public async Task HistoricalCorrectionInvalidatesProposalEvidence_and_declined_proposals_are_not_repeated()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var workout = await a.StartPlannedAsync(plan.Occasions[0]);
        var set = await a.AddSetAsync(workout.Exercises[0].Id, 8, 60m);
        await a.FinishAsync(workout, [set]);
        plan = (await a.ContextAsync()).Plans.Single();
        var openId = (await a.StartPlannedAsync(plan.Occasions[1])).Id;         // "Upper strength": contains the bench press
        var open = (await a.SnapshotAsync()).Workouts.Single(w => w.Id == openId);

        var request = new ProposalRequest(Guid.NewGuid(), Guid.NewGuid(), plan.Id, "substitution", null, "bench-press", "dumbbell-bench-press");
        var proposed = await a.PostAsync<ProposalDto>("/proposals", request);
        Assert.Equal("accepted", proposed.Status);
        Assert.DoesNotContain(plan.Occasions[1].Id, proposed.Data.Change.AffectedOccasionIds);   // open workout's occasion is out of scope
        Assert.DoesNotContain(plan.Occasions[0].Id, proposed.Data.Change.AffectedOccasionIds);   // recorded occasion too

        // Correcting recorded history flags the proposal instead of silently keeping or undoing it.
        var corrected = await a.PutAsync<SetDto>($"/sets/{set.Id}", new SetUpdateRequest(Guid.NewGuid(), set.Revision, 6, 62.5m, null));
        Assert.Equal("accepted", corrected.Status);
        var flagged = (await a.SnapshotAsync()).Proposals.Single();
        Assert.Equal("needs_review", flagged.State);
        var stale = await a.PostAsync<ProposalResult>($"/proposals/{flagged.Id}/accept", new ProposalDecision(Guid.NewGuid(), flagged.Revision, plan.Revision));
        Assert.Equal("PROPOSAL_NOT_OPEN", stale.Code);
        Assert.Equal(plan.Revision, (await a.ContextAsync()).Plans.Single().Revision);          // nothing applied

        // A fresh proposal on the new evidence can be declined; the identical one is then suppressed.
        var again = await a.PostAsync<ProposalDto>("/proposals", request with { OperationId = Guid.NewGuid(), ProposalId = Guid.NewGuid() });
        var declined = await a.PostAsync<ProposalResult>($"/proposals/{again.Data.Id}/decline", new ProposalDecision(Guid.NewGuid(), again.Data.Revision, null));
        Assert.Equal("declined", declined.Data.Proposal.State);
        var nag = await a.PostAsync<ProposalDto>("/proposals", request with { OperationId = Guid.NewGuid(), ProposalId = Guid.NewGuid() });
        Assert.Equal("PROPOSAL_DECLINED_UNCHANGED", nag.Code);

        var snapshotBefore = (await a.SnapshotAsync()).Workouts.Single(w => w.Id == open.Id);
        Assert.Equivalent(open, snapshotBefore);                                // the open snapshot never changed
    }

    [Fact]
    public async Task Accepted_substitution_rewrites_only_unstarted_future_prescriptions()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var upper = plan.Occasions.Where(o => o.Prescription.Any(e => e.CatalogKey == "bench-press")).OrderBy(o => o.ScheduledDate).ToList();
        var open = await a.StartPlannedAsync(upper[0]);

        var proposed = await a.PostAsync<ProposalDto>("/proposals", new ProposalRequest(Guid.NewGuid(), Guid.NewGuid(), plan.Id, "substitution", null, "bench-press", "dumbbell-bench-press"));
        var accepted = await a.PostAsync<ProposalResult>($"/proposals/{proposed.Data.Id}/accept", new ProposalDecision(Guid.NewGuid(), proposed.Data.Revision, plan.Revision));
        var after = accepted.Data.Context!.Plans.Single();

        Assert.Contains(after.Occasions.Single(o => o.Id == upper[0].Id).Prescription, e => e.CatalogKey == "bench-press");
        foreach (var later in upper.Skip(1))
        {
            var changed = after.Occasions.Single(o => o.Id == later.Id).Prescription.Single(e => e.OccurrenceKey == "b1");
            Assert.Equal(("dumbbell-bench-press", "Dumbbell bench press", 3), (changed.CatalogKey, changed.Name, changed.TargetSets));
        }
        Assert.Contains((await a.SnapshotAsync()).Workouts.Single(w => w.Id == open.Id).Exercises, e => e.CatalogKey == "bench-press");
    }
}
