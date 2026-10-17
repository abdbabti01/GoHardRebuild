using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GoHard.Api.Application;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>Run / Walk activities and their routes on real PostgreSQL (docs/RUN_WALK.md › Sync contract).</summary>
[Collection("api")]
public class RunRouteTests(PostgresFixture pg)
{
    private static readonly DateTime Start = new(2026, 10, 9, 11, 20, 0, DateTimeKind.Utc);

    /// <summary>Entries seq [from, to] in the compact route shape (fix every second, walking north).</summary>
    private static List<JsonElement> Entries(int from, int to) => Enumerable.Range(from, to - from + 1).Select(s =>
        JsonSerializer.SerializeToElement(new Dictionary<string, object>
        {
            ["s"] = s, ["y"] = s == 0 ? "start" : "fix", ["g"] = 0, ["t"] = 1760008800000L + s * 1000L,
            ["la"] = 46.8 + s * 0.00001, ["lo"] = -71.2, ["a"] = 5.0,
        })).ToList();

    private static RouteChunkRequest Chunk(int index, int count) =>
        new(Guid.NewGuid(), index * 500, index * 500 + count - 1, Entries(index * 500, index * 500 + count - 1));

    private static async Task<RunDto> SavedWalkAsync(Account a)
    {
        var id = Guid.NewGuid();
        var started = await a.PostAsync<RunDto>("/runs", new RunStartRequest(Guid.NewGuid(), id, Account.Friday, Start, "walk"));
        Assert.Equal(("accepted", "walk"), (started.Status, started.Data.ActivityType));
        var metrics = JsonSerializer.SerializeToElement(new { movingSeconds = 1800, elapsedSeconds = 1900, distanceSource = "gps", routeState = "recorded" });
        var finished = await a.PostAsync<RunDto>($"/runs/{id}/finish",
            new RunFinishRequest(Guid.NewGuid(), 1, 1850, 2400.5m, Start.AddMinutes(32), "Morning walk", "Plains", metrics));
        Assert.Equal(("accepted", "Morning walk", 1800), (finished.Status, finished.Data.Title, finished.Data.Metrics!.Value.GetProperty("movingSeconds").GetInt32()));
        return finished.Data;
    }

    [Fact]
    public async Task Route_chunks_are_idempotent_ordered_owned_completed_and_erased_with_the_activity_and_account()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        Assert.Contains("\"runs.routes\"", await a.Http.GetStringAsync("/api/v1/capabilities"));
        var walk = await SavedWalkAsync(a);

        // A chunk retried after a lost response, and the same chunk under a new operation: one row, accepted both times.
        var c0 = Chunk(0, 500);
        var first = await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/0", c0);
        Assert.Equal(("accepted", 500), (first.Status, first.Data.EntryCount));
        Assert.Equal(first.Raw, (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/0", c0)).Raw);
        Assert.Equal("accepted", (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/0", c0 with { OperationId = Guid.NewGuid() })).Status);
        // Different content under the same index is a conflict, never a silent overwrite.
        var changed = c0 with { OperationId = Guid.NewGuid(), Entries = Entries(0, 499).Select((e, i) => i == 7 ? Entries(9, 9)[0] : e).ToList() };
        Assert.Equal("rejected", (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/0", changed)).Status); // seq order broken: invalid
        var altered = c0 with { OperationId = Guid.NewGuid(), Entries = Entries(0, 499).Select(e => JsonSerializer.SerializeToElement(new { s = e.GetProperty("s").GetInt32(), y = "fix", g = 0, t = 1L })).ToList() };
        Assert.Equal(("conflict", "ROUTE_CHUNK_MISMATCH"), ((await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/0", altered)).Status, (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/0", altered with { OperationId = Guid.NewGuid() })).Code));

        // Entries outside the chunk's seq range, too many, or out of order are refused.
        Assert.Equal("rejected", (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/1", Chunk(0, 10))).Status);
        Assert.Equal("rejected", (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/1", new RouteChunkRequest(Guid.NewGuid(), 500, 1000, Entries(500, 1000)))).Status);

        // A partial upload is not complete: completing early is a conflict, then the rest arrives and completes it.
        var early = await a.PostAsync<RunDto>($"/runs/{walk.Id}/route/complete", new RouteCompleteRequest(Guid.NewGuid(), 2, 620));
        Assert.Equal(("conflict", "ROUTE_INCOMPLETE", "uploading"), (early.Status, early.Code, early.Data.RouteState));
        Assert.Equal("accepted", (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/1", Chunk(1, 120))).Status);
        var done = await a.PostAsync<RunDto>($"/runs/{walk.Id}/route/complete", new RouteCompleteRequest(Guid.NewGuid(), 2, 620));
        Assert.Equal(("accepted", "complete", 2, walk.Revision), (done.Status, done.Data.RouteState, done.Data.RouteChunkCount, done.Data.Revision));

        // Read back in bounded pages, in order; the snapshot carries the summary but never the route.
        var page = (await a.Http.GetFromJsonAsync<RoutePage>($"/api/v1/runs/{walk.Id}/route?limit=1", Account.Json))!;
        Assert.Equal((1, 1, "complete"), (page.Chunks.Count, page.NextIndex, page.RouteState));
        var rest = (await a.Http.GetFromJsonAsync<RoutePage>($"/api/v1/runs/{walk.Id}/route?fromIndex=1", Account.Json))!;
        Assert.Equal((120, (int?)null), (rest.Chunks.Single().Entries.GetArrayLength(), rest.NextIndex));
        var snapshotJson = await a.Http.GetStringAsync("/api/v1/sync/snapshot");
        Assert.DoesNotContain("\"la\"", snapshotJson);
        var listed = (await a.SnapshotAsync()).Runs.Single();
        Assert.Equal(("walk", "complete", "Plains"), (listed.ActivityType, listed.RouteState, listed.Notes));

        // Another account cannot read, add to or complete it, and cannot tell it exists.
        Assert.Equal(HttpStatusCode.NotFound, (await other.Http.GetAsync($"/api/v1/runs/{walk.Id}/route")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/2", Chunk(2, 5))).Http);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsync<RunDto>($"/runs/{walk.Id}/route/complete", new RouteCompleteRequest(Guid.NewGuid(), 2, 620))).Http);

        // Deleting the activity erases its route; a late chunk finds nothing and nothing comes back.
        var deleted = await a.PostAsync<RunDto>($"/runs/{walk.Id}/delete", new RevisionCommand(Guid.NewGuid(), walk.Revision));
        Assert.Equal(("accepted", "none"), (deleted.Status, deleted.Data.RouteState));
        Assert.Equal(HttpStatusCode.NotFound, (await a.PutAsync<RouteChunkResult>($"/runs/{walk.Id}/route/chunks/2", Chunk(2, 5))).Http);
        Assert.Equal(HttpStatusCode.NotFound, (await a.Http.GetAsync($"/api/v1/runs/{walk.Id}/route")).StatusCode);
        await using (var db = pg.SharedDb()) Assert.False(await db.RouteChunks.AnyAsync(c => c.RunId == walk.Id));

        // Account erasure removes every route.
        var second = await SavedWalkAsync(a);
        Assert.Equal("accepted", (await a.PutAsync<RouteChunkResult>($"/runs/{second.Id}/route/chunks/0", Chunk(0, 3))).Status);
        var gone = await a.Http.SendAsync(new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(a.Password)) });
        Assert.Equal(HttpStatusCode.NoContent, gone.StatusCode);
        await using (var db = pg.SharedDb()) Assert.False(await db.RouteChunks.AnyAsync(c => c.UserId == a.UserId));
    }

    [Fact]
    public async Task Activity_type_edits_and_older_clients()
    {
        var a = await Account.RegisterAsync(pg.Api);

        // An older client's run: no type, title or metrics. It is a run, and finishing it the old way still works.
        var oldId = Guid.NewGuid();
        var old = await a.SendAsync<RunDto>(HttpMethod.Post, "/runs", new { operationId = Guid.NewGuid(), runId = oldId, dayKey = "2026-10-09", startedAtUtc = Start });
        Assert.Equal(("accepted", "run", "none"), (old.Status, old.Data.ActivityType, old.Data.RouteState));
        var oldFinish = await a.SendAsync<RunDto>(HttpMethod.Post, $"/runs/{oldId}/finish",
            new { operationId = Guid.NewGuid(), expectedRevision = 1, activeDurationSeconds = 900, distanceMeters = 2000m, finishedAtUtc = Start.AddMinutes(15) });
        Assert.Equal(("accepted", (string?)null), (oldFinish.Status, oldFinish.Data.Title));

        // Bad types and details are refused.
        Assert.Equal("rejected", (await a.PostAsync<RunDto>("/runs", new RunStartRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, Start, "swim"))).Status);

        // An open activity's route cannot be uploaded or edited; a saved one's type is changed only by an edit.
        var openId = Guid.NewGuid();
        await a.PostAsync<RunDto>("/runs", new RunStartRequest(Guid.NewGuid(), openId, Account.Friday, Start, "walk"));
        Assert.Equal(("conflict", "RUN_OPEN"), ((await a.PutAsync<RouteChunkResult>($"/runs/{openId}/route/chunks/0", Chunk(0, 3))).Status, (await a.PutAsync<RouteChunkResult>($"/runs/{openId}/route/chunks/0", Chunk(0, 3))).Code));

        var walk = await SavedWalkAsync(a);
        var corrected = JsonSerializer.SerializeToElement(new { gpsDistanceMeters = 2400.5, distanceSource = "corrected" });
        var edit = new RunUpdateRequest(Guid.NewGuid(), walk.Revision, "run", "Evening run", "", 2500m, corrected);
        var edited = await a.PutAsync<RunDto>($"/runs/{walk.Id}", edit);
        Assert.Equal(("accepted", "run", "Evening run", (string?)null, 2500m), (edited.Status, edited.Data.ActivityType, edited.Data.Title, edited.Data.Notes, edited.Data.DistanceMeters));
        Assert.Equal("corrected", edited.Data.Metrics!.Value.GetProperty("distanceSource").GetString());
        var stale = await a.PutAsync<RunDto>($"/runs/{walk.Id}", edit with { OperationId = Guid.NewGuid() });
        Assert.Equal(("conflict", Ack.RevisionConflict), (stale.Status, stale.Code));
        var tooLong = edit with { OperationId = Guid.NewGuid(), ExpectedRevision = edited.Data.Revision, Title = new string('x', 81) };
        Assert.Equal("rejected", (await a.PutAsync<RunDto>($"/runs/{walk.Id}", tooLong)).Status);
    }
}
