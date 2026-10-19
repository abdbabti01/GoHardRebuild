using System.Net;
using System.Net.Http.Json;
using System.Text;
using GoHard.Api.Application;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>Weekly activity targets: one record per effective Monday, on real PostgreSQL.</summary>
[Collection("api")]
public class WeeklyGoalTests(PostgresFixture pg)
{
    private static readonly DateOnly WeekA = new(2026, 10, 5), WeekB = new(2026, 10, 12);   // Mondays
    private static StringContent Raw(string json) => new(json, Encoding.UTF8, "application/json");
    private static WeeklyGoalPutRequest Put(int expected, int? workouts, int? runWalk) => new(Guid.NewGuid(), expected, new(true, workouts), new(true, runWalk));

    [Fact]
    public async Task Goals_are_per_week_idempotent_revision_checked_owned_and_erased_with_the_account()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        Assert.Contains("\"goals.weekly\"", await a.Http.GetStringAsync("/api/v1/capabilities"));
        Assert.Empty((await a.SnapshotAsync()).WeeklyGoals!);   // a fresh account has none; nothing is suggested

        // Week A: 3 workouts, no Run / Walk target. A lost response retried gives the same acknowledgement, one row.
        var first = Put(0, 3, null);
        var set = await a.PutAsync<WeeklyGoalDto>($"/weekly-goals/{WeekA:yyyy-MM-dd}", first);
        var retry = await a.PutAsync<WeeklyGoalDto>($"/weekly-goals/{WeekA:yyyy-MM-dd}", first);
        Assert.Equal(("accepted", 1, 3, (int?)null), (set.Status, set.Data.Revision, set.Data.WorkoutsTarget, set.Data.RunWalkTarget));
        Assert.Equal(set.Raw, retry.Raw);

        // Week B changes it to 4: week A's record is untouched.
        Assert.Equal("accepted", (await a.PutAsync<WeeklyGoalDto>($"/weekly-goals/{WeekB:yyyy-MM-dd}", Put(0, 4, 2))).Status);
        var goals = (await a.SnapshotAsync()).WeeklyGoals!;
        Assert.Equal([(WeekA, (int?)3, (int?)null), (WeekB, 4, 2)], goals.Select(g => (g.WeekStart, g.WorkoutsTarget, g.RunWalkTarget)));

        // A second phone that never saw week B's record (expected 0) is a conflict carrying the account's choice.
        var stale = await a.PutAsync<WeeklyGoalDto>($"/weekly-goals/{WeekB:yyyy-MM-dd}", Put(0, 5, null));
        Assert.Equal(("conflict", Ack.RevisionConflict, 4), (stale.Status, stale.Code, stale.Data.WorkoutsTarget));

        // An older client leaves a field out: the stored value is kept. An explicit null clears it, as a record of its own.
        var keep = await a.Http.PutAsync($"/api/v1/weekly-goals/{WeekB:yyyy-MM-dd}", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":1,"workoutsTarget":6}"""));
        Assert.Equal(HttpStatusCode.OK, keep.StatusCode);
        var clear = await a.Http.PutAsync($"/api/v1/weekly-goals/{WeekB:yyyy-MM-dd}", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":2,"workoutsTarget":null,"runWalkTarget":null}"""));
        Assert.Equal(HttpStatusCode.OK, clear.StatusCode);
        goals = (await a.SnapshotAsync()).WeeklyGoals!;
        Assert.Equal([(WeekA, (int?)3, (int?)null, 1), (WeekB, null, null, 3)], goals.Select(g => (g.WeekStart, g.WorkoutsTarget, g.RunWalkTarget, g.Revision)));

        // Whole numbers 1 to 21 on a Monday that is not ahead of the server's week.
        var tuesday = WeekA.AddDays(1);
        var future = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(30);
        future = future.AddDays(-(((int)future.DayOfWeek + 6) % 7));
        foreach (var (week, w, rw) in new[] { (WeekA, 0, 1), (WeekA, 22, 1), (WeekA, -1, 1), (WeekA, 1, 0), (tuesday, 3, 3), (future, 3, 3) })
        {
            var r = await a.PutAsync<WeeklyGoalDto>($"/weekly-goals/{week:yyyy-MM-dd}", Put(1, w, rw));
            Assert.Equal(("rejected", Ack.Invalid), (r.Status, r.Code));
        }
        var fraction = await a.Http.PutAsync($"/api/v1/weekly-goals/{WeekA:yyyy-MM-dd}", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":1,"workoutsTarget":2.5}"""));
        Assert.Equal(HttpStatusCode.BadRequest, fraction.StatusCode);
        Assert.Equal("accepted", (await a.PutAsync<WeeklyGoalDto>($"/weekly-goals/{WeekA:yyyy-MM-dd}", Put(1, 21, 1))).Status);

        // Another account cannot see or change them.
        Assert.Empty((await other.SnapshotAsync()).WeeklyGoals!);
        var foreign = await other.PutAsync<WeeklyGoalDto>($"/weekly-goals/{WeekA:yyyy-MM-dd}", Put(0, 9, 9));
        Assert.Equal(("accepted", 1), (foreign.Status, foreign.Data.Revision));   // its own record for that week
        Assert.Equal(21, (await a.SnapshotAsync()).WeeklyGoals!.Single(g => g.WeekStart == WeekA).WorkoutsTarget);

        var gone = await a.Http.SendAsync(new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(a.Password)) });
        Assert.Equal(HttpStatusCode.NoContent, gone.StatusCode);
        await using var db = pg.SharedDb();
        Assert.False(await db.WeeklyGoals.AnyAsync(g => g.UserId == a.UserId));
        Assert.True(await db.WeeklyGoals.AnyAsync(g => g.UserId == other.UserId));
    }
}
