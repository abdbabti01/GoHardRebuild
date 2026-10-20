using System.Net;
using System.Net.Http.Json;
using GoHard.Api.Application;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>Equipment increments: one record per account and exercise identity, on real PostgreSQL.</summary>
[Collection("api")]
public class ExerciseIncrementTests(PostgresFixture pg)
{
    private static ExerciseIncrementPutRequest Put(int expected, decimal? kg) => new(Guid.NewGuid(), expected, kg);

    [Fact]
    public async Task Increments_are_idempotent_revision_checked_validated_owned_and_erased_with_the_account()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        Assert.Contains("\"exercises.load-increment\"", await a.Http.GetStringAsync("/api/v1/capabilities"));
        Assert.Empty((await a.SnapshotAsync()).ExerciseIncrements!);   // nothing is preselected

        // 5 lb in kilograms. A lost response retried gives the same acknowledgement and one row.
        var first = Put(0, 2.26796m);
        var set = await a.PutAsync<ExerciseIncrementDto>("/exercise-increments/bench-press", first);
        var retry = await a.PutAsync<ExerciseIncrementDto>("/exercise-increments/bench-press", first);
        Assert.Equal(("accepted", 1, (decimal?)2.26796m), (set.Status, set.Data.Revision, set.Data.IncrementKg));
        Assert.Equal(set.Raw, retry.Raw);

        // Another phone that never saw it (expected 0) is a conflict carrying the account's value.
        var stale = await a.PutAsync<ExerciseIncrementDto>("/exercise-increments/bench-press", Put(0, 2.5m));
        Assert.Equal(("conflict", Ack.RevisionConflict, (decimal?)2.26796m), (stale.Status, stale.Code, stale.Data.IncrementKg));

        // An explicit null clears it; the record stays (revision 2), so an older value cannot come back.
        Assert.Equal(("accepted", 2), ((await a.PutAsync<ExerciseIncrementDto>("/exercise-increments/bench-press", Put(1, null))) is var c ? (c.Status, c.Data.Revision) : default));
        Assert.Null((await a.SnapshotAsync()).ExerciseIncrements!.Single().IncrementKg);

        // Above 0, at most 50 kg, at most 5 decimals, a known identity: the catalogue or the caller's own exercise.
        foreach (var kg in new decimal?[] { 0m, -1m, 50.5m, 1.123456m })
            Assert.Equal(("rejected", Ack.Invalid), (await a.PutAsync<ExerciseIncrementDto>("/exercise-increments/back-squat", Put(0, kg))) is var r ? (r.Status, r.Code) : default);
        Assert.Equal("UNKNOWN_EXERCISE", (await a.PutAsync<ExerciseIncrementDto>("/exercise-increments/not-a-movement", Put(0, 1m))).Code);
        var mine = Guid.NewGuid();
        Assert.Equal("accepted", (await other.PutAsync<CustomExerciseDto>($"/custom-exercises/{mine}", new CustomExercisePutRequest(Guid.NewGuid(), 0, "Sled push", "Legs", "Machine", false, false))).Status);
        Assert.Equal("UNKNOWN_EXERCISE", (await a.PutAsync<ExerciseIncrementDto>($"/exercise-increments/custom:{mine}", Put(0, 1m))).Code);   // someone else's
        Assert.Equal("accepted", (await other.PutAsync<ExerciseIncrementDto>($"/exercise-increments/custom:{mine}", Put(0, 1.25m))).Status);

        // Another account's records are its own.
        Assert.Equal(("accepted", 1), (await other.PutAsync<ExerciseIncrementDto>("/exercise-increments/bench-press", Put(0, 1m))) is var o ? (o.Status, o.Data.Revision) : default);
        Assert.Single((await a.SnapshotAsync()).ExerciseIncrements!);

        var gone = await a.Http.SendAsync(new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(a.Password)) });
        Assert.Equal(HttpStatusCode.NoContent, gone.StatusCode);
        await using var db = pg.SharedDb();
        Assert.False(await db.ExerciseIncrements.AnyAsync(x => x.UserId == a.UserId));
        Assert.Equal(2, await db.ExerciseIncrements.CountAsync(x => x.UserId == other.UserId));
    }
}
