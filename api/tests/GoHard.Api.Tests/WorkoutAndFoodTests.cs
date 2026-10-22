using System.Net;
using System.Net.Http.Json;
using GoHard.Api.Application;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace GoHard.Api.Tests;

/// <summary>W2, W4, W8, N1, N2, R3: idempotent revision-checked actual records on real PostgreSQL.</summary>
[Collection("api")]
public class WorkoutAndFoodTests(PostgresFixture pg)
{
    [Fact]
    public async Task LostCreateResponseRetriesOneSet()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var workout = await a.StartManualAsync();
        var request = new SetCreateRequest(Guid.NewGuid(), Guid.NewGuid(), 8, 63.503m, null, new DateTime(2026, 10, 9, 23, 59, 30, DateTimeKind.Utc));
        var path = $"/exercises/{workout.Exercises[0].Id}/sets";

        var first = await a.PostAsync<SetDto>(path, request);
        var retry = await a.PostAsync<SetDto>(path, request);                   // the first response was "lost"
        var replayStorm = await Task.WhenAll(Enumerable.Range(0, 5).Select(_ => a.PostAsync<SetDto>(path, request)));

        Assert.Equal(first.Raw, retry.Raw);
        Assert.All(replayStorm, r => Assert.Equal(first.Raw, r.Raw));
        var stored = (await a.SnapshotAsync()).Workouts.Single().Exercises[0].Sets;
        Assert.Equal(first.Data.Id, Assert.Single(stored).Id);
        Assert.Equal((8, 63.503m), (stored[0].Reps, stored[0].LoadKg));          // canonical kg, exactly as sent

        var changed = await a.PostAsync<SetDto>(path, request with { Reps = 9 });
        Assert.Equal(Ack.PayloadMismatch, changed.Code);
        var sameIdNewOperation = await a.PostAsync<SetDto>(path, request with { OperationId = Guid.NewGuid() });
        Assert.Equal("DUPLICATE_ID", sameIdNewOperation.Code);
        Assert.Single((await a.SnapshotAsync()).Workouts.Single().Exercises[0].Sets);
    }

    [Fact]
    public async Task Concurrent_creates_under_one_operation_produce_exactly_one_set()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var workout = await a.StartManualAsync();
        var request = new SetCreateRequest(Guid.NewGuid(), Guid.NewGuid(), 5, 100m, null, DateTime.UtcNow);
        var results = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => a.PostAsync<SetDto>($"/exercises/{workout.Exercises[0].Id}/sets", request)));
        Assert.All(results, r => Assert.Equal("accepted", r.Status));
        Assert.Single(results.Select(r => r.Raw).Distinct());
        await using var db = pg.SharedDb();
        Assert.Equal(1, await db.WorkoutSets.CountAsync(s => s.UserId == a.UserId));
        Assert.Equal(1, await db.Operations.CountAsync(o => o.UserId == a.UserId && o.OperationId == request.OperationId));
    }

    [Fact]
    public async Task TwoEditsRetainConflict_and_deleted_sets_keep_a_tombstone()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var workout = await a.StartManualAsync();
        var set = await a.AddSetAsync(workout.Exercises[0].Id, 8, 60m);

        // Two devices edit revision 1 at the same moment.
        var edits = await Task.WhenAll(
            a.PutAsync<SetDto>($"/sets/{set.Id}", new SetUpdateRequest(Guid.NewGuid(), 1, 10, 60m, null)),
            a.PutAsync<SetDto>($"/sets/{set.Id}", new SetUpdateRequest(Guid.NewGuid(), 1, 8, 65m, null)));
        var winner = Assert.Single(edits, e => e.Status == "accepted");
        var loser = Assert.Single(edits, e => e.Status == "conflict");
        Assert.Equal(Ack.RevisionConflict, loser.Code);
        Assert.Equal(winner.Data, loser.Data);                                  // the conflict carries the current server value for review
        Assert.Equal(2, winner.Data.Revision);
        Assert.Single((await a.SnapshotAsync()).Workouts.Single().Exercises[0].Sets);   // resolution never needs another set

        var invalid = await a.PutAsync<SetDto>($"/sets/{set.Id}", new SetUpdateRequest(Guid.NewGuid(), 2, -1, 60m, null));
        Assert.Equal(("rejected", HttpStatusCode.UnprocessableEntity), (invalid.Status, invalid.Http));

        var deleted = await a.PostAsync<SetDto>($"/sets/{set.Id}/delete", new RevisionCommand(Guid.NewGuid(), 2));
        Assert.True(deleted.Data.IsDeleted);
        // An old edit arriving after the delete is told so; it cannot resurrect the set.
        var late = await a.PutAsync<SetDto>($"/sets/{set.Id}", new SetUpdateRequest(Guid.NewGuid(), 2, 12, 60m, null));
        Assert.Equal(("conflict", "SET_DELETED"), (late.Status, late.Code));
        Assert.True(Assert.Single((await a.SnapshotAsync()).Workouts.Single().Exercises[0].Sets).IsDeleted);
    }

    [Fact]
    public async Task ForeignParentIsRejected_without_disclosing_it()
    {
        var owner = await Account.RegisterAsync(pg.Api);
        var intruder = await Account.RegisterAsync(pg.Api);
        var workout = await owner.StartManualAsync();
        var set = await owner.AddSetAsync(workout.Exercises[0].Id);

        var create = await intruder.PostAsync<SetDto>($"/exercises/{workout.Exercises[0].Id}/sets", new SetCreateRequest(Guid.NewGuid(), Guid.NewGuid(), 5, 5m, null, DateTime.UtcNow));
        var edit = await intruder.PutAsync<SetDto>($"/sets/{set.Id}", new SetUpdateRequest(Guid.NewGuid(), 1, 1, 1m, null));
        var finish = await intruder.FinishAsync(workout, [set]);
        var missing = await intruder.PutAsync<SetDto>($"/sets/{Guid.NewGuid()}", new SetUpdateRequest(Guid.NewGuid(), 1, 1, 1m, null));

        Assert.All(new[] { create.Http, edit.Http, finish.Http, missing.Http }, s => Assert.Equal(HttpStatusCode.NotFound, s));
        Assert.Equal(set, (await owner.SnapshotAsync()).Workouts.Single().Exercises[0].Sets.Single());
        Assert.Empty((await intruder.SnapshotAsync()).Workouts);
    }

    [Fact]
    public async Task RetryFinishDoesNotDuplicateAwards_and_duration_is_explicit_seconds()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var workout = await a.StartPlannedAsync(plan.Occasions[0]);
        var sets = new List<SetDto>();
        foreach (var exercise in workout.Exercises)
            for (var i = 0; i < exercise.TargetSets; i++)
                sets.Add(await a.AddSetAsync(exercise.Id, exercise.IsTimed ? null : 8, exercise.IsTimed ? null : 50m, exercise.IsTimed ? 45 : null));
        var operation = Guid.NewGuid();

        var first = await a.FinishAsync(workout, sets, seconds: 125, operationId: operation);
        var retry = await a.FinishAsync(workout, sets, seconds: 125, operationId: operation);
        var secondLogicalFinish = await a.FinishAsync(workout, sets, seconds: 999);

        Assert.Equal(("accepted", "full", 125, true), (first.Status, first.Data.Outcome, first.Data.ActiveDurationSeconds, first.Data.QualifiedOccasion));
        Assert.Equal(first.Raw, retry.Raw);
        Assert.Equal(("conflict", "ALREADY_FINISHED", 125), (secondLogicalFinish.Status, secondLogicalFinish.Code, secondLogicalFinish.Data.ActiveDurationSeconds));
        var occasion = (await a.ContextAsync()).Plans.Single().Occasions.Single(o => o.Id == plan.Occasions[0].Id);
        Assert.Equal(("full", workout.Id), (occasion.ResultOutcome, occasion.ResultWorkoutId));

        // The resolved occasion is not offered as new training again.
        var again = await a.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "planned", occasion.Id, "x", Account.Friday, DateTime.UtcNow, []));
        Assert.Equal("OCCASION_NOT_ELIGIBLE", again.Code);
    }

    [Fact]
    public async Task NoDataAttemptDoesNotBlockNextAttempt()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var empty = await a.StartPlannedAsync(plan.Occasions[0]);

        var noData = await a.FinishAsync(empty, []);
        Assert.Equal(("accepted", "no_data", false, 0), (noData.Status, noData.Data.Outcome, noData.Data.QualifiedOccasion, noData.Data.PerformedSets));
        var occasion = (await a.ContextAsync()).Plans.Single().Occasions.Single(o => o.Id == plan.Occasions[0].Id);
        Assert.Null(occasion.ResultOutcome);                                    // honest record, no credit, not skipped
        Assert.False(occasion.IsSkipped);

        var real = await a.StartPlannedAsync(plan.Occasions[0]);
        var set = await a.AddSetAsync(real.Exercises[0].Id);
        var partial = await a.FinishAsync(real, [set]);
        Assert.Equal(("partial", true), (partial.Data.Outcome, partial.Data.QualifiedOccasion));
        Assert.Equal(2, (await a.SnapshotAsync()).Workouts.Count);              // both attempts are retained
        Assert.Equal(real.Id, (await a.ContextAsync()).Plans.Single().Occasions.Single(o => o.Id == occasion.Id).ResultWorkoutId);
    }

    [Fact]
    public async Task Finish_cannot_run_ahead_of_or_behind_its_sets()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var workout = await a.StartManualAsync();
        var set = await a.AddSetAsync(workout.Exercises[0].Id);
        var edited = (await a.PutAsync<SetDto>($"/sets/{set.Id}", new SetUpdateRequest(Guid.NewGuid(), 1, 9, 60m, null))).Data;

        var missingSet = await a.FinishAsync(workout, []);
        var staleRevision = await a.FinishAsync(workout, [set]);
        var unknownSet = await a.FinishAsync(workout, [edited, edited with { Id = Guid.NewGuid() }]);
        Assert.All(new[] { missingSet, staleRevision, unknownSet }, r => Assert.Equal(("conflict", "SET_DEPENDENCY_MISMATCH"), (r.Status, r.Code)));
        Assert.Null((await a.SnapshotAsync()).Workouts.Single().FinishedAtUtc); // nothing was partially completed

        var ok = await a.FinishAsync(workout, [edited]);
        Assert.Equal(("accepted", "manual_recorded", false), (ok.Status, ok.Data.Outcome, ok.Data.QualifiedOccasion));
    }

    [Fact]
    public async Task Manual_work_never_links_to_an_occasion_and_one_open_workout_per_occasion()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var linked = await a.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "manual", plan.Occasions[0].Id, "Sneaky", Account.Friday, DateTime.UtcNow, []));
        Assert.Equal("rejected", linked.Status);

        var first = await a.StartPlannedAsync(plan.Occasions[0]);
        var second = await a.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "planned", plan.Occasions[0].Id, "Again", Account.Friday, DateTime.UtcNow, []));
        Assert.Equal(("conflict", "OCCASION_NOT_ELIGIBLE", first.Id), (second.Status, second.Code, second.Data.Id));

        // A separate manual workout can be open at the same time; opening it never finishes the planned one.
        await a.StartManualAsync();
        Assert.All((await a.SnapshotAsync()).Workouts, w => Assert.Null(w.FinishedAtUtc));
    }

    [Fact]
    public async Task OldDraftWithEnteredSetsSurvivesHostRestart()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        var user = new User { Id = Guid.NewGuid(), Email = "old-draft@example.test", PasswordHash = "x", DisplayName = "Old", SecurityStamp = "s", CreatedAtUtc = DateTime.UtcNow.AddDays(-30) };
        var exerciseId = Guid.NewGuid();
        var workout = new Workout
        {
            Id = Guid.NewGuid(), UserId = user.Id, Title = "Seven days old", DayKey = Account.Friday.AddDays(-7), StartedAtUtc = DateTime.UtcNow.AddDays(-7),
            Exercises = [new WorkoutExercise { Id = exerciseId, UserId = user.Id, Ordinal = 1, Name = "Back squat",
                Sets = [new WorkoutSet { Id = Guid.NewGuid(), UserId = user.Id, Reps = 5, LoadKg = 100, PerformedAtUtc = DateTime.UtcNow.AddDays(-7) }] }],
        };
        workout.Exercises[0].Sets[0].WorkoutId = workout.Id;
        var emptyDraft = new Workout { Id = Guid.NewGuid(), UserId = user.Id, Title = "Empty and old", DayKey = Account.Friday.AddDays(-20), StartedAtUtc = DateTime.UtcNow.AddDays(-20) };
        var operation = new Operation { UserId = user.Id, OperationId = Guid.NewGuid(), Kind = "workout.start", RequestHash = "h", HttpStatus = 200, ResponseJson = "{}", CreatedAtUtc = DateTime.UtcNow.AddDays(-7) };
        await using (var seed = PostgresFixture.NewDb(cs)) { seed.AddRange(user, workout, emptyDraft, operation); await seed.SaveChangesAsync(); }

        for (var boot = 0; boot < 2; boot++)
        {
            await using var api = new ApiFactory(cs);
            Assert.Equal(HttpStatusCode.OK, (await api.CreateClient().GetAsync("/health/ready")).StatusCode);
            // No hosted background service exists that could reap, complete or rewrite workouts. (The account-mail sender
            // is the only one, and only where a sender is configured; it touches nothing but its own outbox.)
            Assert.DoesNotContain(api.Services.GetServices<Microsoft.Extensions.Hosting.IHostedService>(), s => s.GetType().Assembly == typeof(Program).Assembly);
        }

        await using var db = PostgresFixture.NewDb(cs);
        var kept = await db.Workouts.Include(w => w.Exercises).ThenInclude(e => e.Sets).SingleAsync(w => w.Id == workout.Id);
        Assert.Null(kept.FinishedAtUtc);
        Assert.Null(kept.DeletedAtUtc);
        Assert.Equal((5, 100m), (kept.Exercises[0].Sets[0].Reps, kept.Exercises[0].Sets[0].LoadKg));
        Assert.NotNull(await db.Workouts.SingleOrDefaultAsync(w => w.Id == emptyDraft.Id));          // even empty drafts are retained
        Assert.Equal(operation.OperationId, (await db.Operations.SingleAsync()).OperationId);
    }

    [Fact]
    public async Task Explicit_workout_delete_releases_occasion_credit_and_extra_exercises_are_never_prescribed()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var plan = await a.ActivePlanAsync();
        var workout = await a.StartPlannedAsync(plan.Occasions[0]);
        var extra = new ExerciseSpec(Guid.NewGuid(), 9, "Biceps curl", "biceps-curl", null, true, false, 3, 10, 12, null, 60, null);
        var added = await a.PostAsync<WorkoutDto>($"/workouts/{workout.Id}/exercises", new AddExerciseRequest(Guid.NewGuid(), extra));
        Assert.False(added.Data.Exercises.Single(e => e.Id == extra.Id).IsPrescribed);          // the client cannot inflate the prescription

        var set = await a.AddSetAsync(extra.Id, 12, 12.5m);
        var finished = await a.FinishAsync(workout, [set]);
        Assert.Equal("partial", finished.Data.Outcome);                                          // extra work counts as actual, not as the plan

        var removed = await a.PostAsync<WorkoutDto>($"/workouts/{workout.Id}/delete", new RevisionCommand(Guid.NewGuid(), finished.Data.Revision));
        Assert.True(removed.Data.IsDeleted);
        Assert.Null((await a.ContextAsync()).Plans.Single().Occasions.Single(o => o.Id == plan.Occasions[0].Id).ResultOutcome);
        Assert.True((await a.SnapshotAsync()).Workouts.Single().IsDeleted);                      // tombstone retained for other devices
    }

    [Fact]
    public async Task BlankAndZeroRoundTripDistinctly()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var id = Guid.NewGuid();
        var created = await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), id, Account.Friday, "Breakfast", " Greek yogurt ", "200 g",
            new Macros(0m, null, 9.5m, null)));
        Assert.Equal("accepted", created.Status);

        var roundTrip = (await a.Http.GetFromJsonAsync<List<FoodEntryDto>>($"/api/v1/food-entries?date=2026-10-09", Account.Json))!.Single();
        Assert.Equal(0m, roundTrip.Macros.Calories);                            // entered zero remains zero
        Assert.Null(roundTrip.Macros.Protein);                                  // blank remains unknown
        Assert.Null(roundTrip.Macros.Fat);
        Assert.Equal(new MacroProvenance("entered", "unknown", "entered", "unknown"), roundTrip.Provenance);
        Assert.Equal(("Greek yogurt", "200 g"), (roundTrip.Name, roundTrip.AmountDescription));

        // Clearing a value makes it unknown again; it is never coerced to zero.
        var cleared = await a.PutAsync<FoodEntryDto>($"/food-entries/{id}", new FoodUpdateRequest(Guid.NewGuid(), 1, Account.Friday, "Lunch", "Greek yogurt", "200 g", new Macros(null, 20m, 9.5m, 0m)));
        Assert.Null(cleared.Data.Macros.Calories);
        Assert.Equal((20m, 0m, "unknown", "entered", "Lunch", 2),
            (cleared.Data.Macros.Protein, cleared.Data.Macros.Fat, cleared.Data.Provenance.Calories, cleared.Data.Provenance.Fat, cleared.Data.Meal, cleared.Data.Revision));

        foreach (var bad in new[] { new Macros(-1m, null, null, null), new Macros(null, null, null, 1000000m) })
            Assert.Equal("rejected", (await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, "Snack", "Bad", "1", bad))).Status);
        Assert.Equal("rejected", (await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, "Brunch", "Eggs", "2", new Macros(null, null, null, null)))).Status);
        Assert.Equal("rejected", (await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, "Snack", " ", "2", new Macros(null, null, null, null)))).Status);
    }

    [Fact]
    public async Task LostResponseReturnsOneFood_and_edits_and_removal_are_revision_checked()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        var request = new FoodCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, "Dinner", "Rice bowl", "1 bowl", new Macros(400m, 25m, 50m, 11m));
        var first = await a.PostAsync<FoodEntryDto>("/food-entries", request);
        var retry = await a.PostAsync<FoodEntryDto>("/food-entries", request);
        var sibling = await a.PostAsync<FoodEntryDto>("/food-entries", request with { OperationId = Guid.NewGuid(), EntryId = Guid.NewGuid(), Name = "Toast" });
        Assert.Equal(first.Raw, retry.Raw);
        Assert.Equal(2, (await a.SnapshotAsync()).FoodEntries.Count);

        var foreignEdit = await other.PutAsync<FoodEntryDto>($"/food-entries/{request.EntryId}", new FoodUpdateRequest(Guid.NewGuid(), 1, Account.Friday, "Dinner", "Stolen", "1", new Macros(null, null, null, null)));
        Assert.Equal(HttpStatusCode.NotFound, foreignEdit.Http);
        Assert.Empty((await other.SnapshotAsync()).FoodEntries);

        var edit = new FoodUpdateRequest(Guid.NewGuid(), 1, Account.Friday.AddDays(1), "Lunch", "Rice bowl (large)", "1 large bowl", new Macros(550m, null, 70m, 11m));
        var edited = await a.PutAsync<FoodEntryDto>($"/food-entries/{request.EntryId}", edit);
        var stale = await a.PutAsync<FoodEntryDto>($"/food-entries/{request.EntryId}", edit with { OperationId = Guid.NewGuid(), Name = "From the other phone" });
        Assert.Equal((Account.Friday.AddDays(1), 2), (edited.Data.DayKey, edited.Data.Revision));     // an explicit date edit moves only that food
        Assert.Equal(("conflict", Ack.RevisionConflict, "Rice bowl (large)"), (stale.Status, stale.Code, stale.Data.Name));

        var removeRequest = new RevisionCommand(Guid.NewGuid(), 2);
        var removed = await a.PostAsync<FoodEntryDto>($"/food-entries/{request.EntryId}/delete", removeRequest);
        var removeRetry = await a.PostAsync<FoodEntryDto>($"/food-entries/{request.EntryId}/delete", removeRequest);
        Assert.Equal(removed.Raw, removeRetry.Raw);
        var entries = (await a.SnapshotAsync()).FoodEntries;
        Assert.True(entries.Single(e => e.Id == request.EntryId).IsDeleted);
        Assert.False(entries.Single(e => e.Id == sibling.Data.Id).IsDeleted);   // removing one food leaves the others untouched
        Assert.Single((await a.Http.GetFromJsonAsync<List<FoodEntryDto>>("/api/v1/food-entries?date=2026-10-09", Account.Json))!);
    }

    [Fact]
    public async Task Runs_and_body_metrics_are_owned_idempotent_records()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        var start = new RunStartRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, DateTime.UtcNow);
        var started = await a.PostAsync<RunDto>("/runs", start);
        Assert.Equal(started.Raw, (await a.PostAsync<RunDto>("/runs", start)).Raw);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsync<RunDto>($"/runs/{start.RunId}/finish", new RunFinishRequest(Guid.NewGuid(), 1, 10, null, DateTime.UtcNow))).Http);

        var finished = await a.PostAsync<RunDto>($"/runs/{start.RunId}/finish", new RunFinishRequest(Guid.NewGuid(), 1, 1500, null, DateTime.UtcNow));
        Assert.Equal(1500, finished.Data.ActiveDurationSeconds);
        Assert.Null(finished.Data.DistanceMeters);   // unknown distance stays unknown
        Assert.Equal("ALREADY_FINISHED", (await a.PostAsync<RunDto>($"/runs/{start.RunId}/finish", new RunFinishRequest(Guid.NewGuid(), 2, 9, 1m, DateTime.UtcNow))).Code);

        var metric = await a.PostAsync<BodyMetricDto>("/body-metrics", new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, 82.4m, null, null));
        Assert.Equal(82.4m, metric.Data.WeightKg);
        Assert.Null(metric.Data.BodyFatPercent);
        Assert.Equal("rejected", (await a.PostAsync<BodyMetricDto>("/body-metrics", new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, null, null, "nothing"))).Status);
        var snapshot = await a.SnapshotAsync();
        Assert.Single(snapshot.Runs);
        Assert.Single(snapshot.BodyMetrics);
        // Every seeded catalog entry, as many as the shipped catalog file holds (it grows with new builds).
        var shipped = System.Text.Json.Nodes.JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "exercise-catalog.json")))!.AsArray();
        Assert.Equal(shipped.Count, snapshot.Catalog.Count);
    }
}
