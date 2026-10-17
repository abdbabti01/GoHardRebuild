using System.Net;
using System.Net.Http.Json;
using System.Text;
using GoHard.Api.Application;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>Explicitly logged water and the optional water goal on real PostgreSQL.</summary>
[Collection("api")]
public class WaterTests(PostgresFixture pg)
{
    private static StringContent Raw(string json) => new(json, Encoding.UTF8, "application/json");
    private static async Task<List<WaterEntryDto>> DayAsync(Account a, string date) =>
        (await a.Http.GetFromJsonAsync<List<WaterEntryDto>>($"/api/v1/water-entries?date={date}", Account.Json))!;

    [Fact]
    public async Task Water_is_idempotent_owned_revision_checked_and_erased_with_the_account()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        var request = new WaterCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, 250.125m);

        // A lost response retried: one row, the same acknowledgement.
        var first = await a.PostAsync<WaterEntryDto>("/water-entries", request);
        var retry = await a.PostAsync<WaterEntryDto>("/water-entries", request);
        Assert.Equal(("accepted", 1, 250.125m, Account.Friday), (first.Status, first.Data.Revision, first.Data.VolumeMl, first.Data.DayKey));
        Assert.Equal(first.Raw, retry.Raw);
        var changed = await a.PostAsync<WaterEntryDto>("/water-entries", request with { VolumeMl = 500m });
        Assert.Equal((HttpStatusCode.Conflict, Ack.PayloadMismatch), (changed.Http, changed.Code));
        var duplicate = await a.PostAsync<WaterEntryDto>("/water-entries", request with { OperationId = Guid.NewGuid() });
        Assert.Equal(("conflict", "DUPLICATE_ID"), (duplicate.Status, duplicate.Code));
        var sibling = await a.PostAsync<WaterEntryDto>("/water-entries", new WaterCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, 330m));

        // The day is kept as sent and read back by GET and the snapshot.
        Assert.Equal([request.EntryId, sibling.Data.Id], (await DayAsync(a, "2026-10-09")).Select(w => w.Id));
        Assert.Empty(await DayAsync(a, "2026-10-10"));
        Assert.Equal(250.125m, (await a.SnapshotAsync()).WaterEntries!.Single(w => w.Id == request.EntryId).VolumeMl);

        foreach (var bad in new[] { 0m, -1m, 5000.001m, 1.0001m })
        {
            var r = await a.PostAsync<WaterEntryDto>("/water-entries", new WaterCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, bad));
            Assert.Equal(("rejected", Ack.Invalid), (r.Status, r.Code));
        }
        Assert.Equal("accepted", (await a.PostAsync<WaterEntryDto>("/water-entries", new WaterCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday.AddDays(2), 5000m))).Status);

        // Another account cannot see, change or remove it, and cannot tell it exists.
        var id = request.EntryId;
        Assert.Equal(HttpStatusCode.NotFound, (await other.PutAsync<WaterEntryDto>($"/water-entries/{id}", new WaterUpdateRequest(Guid.NewGuid(), 1, Account.Friday, 1m))).Http);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsync<WaterEntryDto>($"/water-entries/{id}/delete", new RevisionCommand(Guid.NewGuid(), 1))).Http);
        Assert.Empty(await DayAsync(other, "2026-10-09"));
        Assert.Empty((await other.SnapshotAsync()).WaterEntries!);

        var edit = new WaterUpdateRequest(Guid.NewGuid(), 1, Account.Friday.AddDays(1), 400m);
        var edited = await a.PutAsync<WaterEntryDto>($"/water-entries/{id}", edit);
        Assert.Equal(("accepted", 2, Account.Friday.AddDays(1), 400m), (edited.Status, edited.Data.Revision, edited.Data.DayKey, edited.Data.VolumeMl));
        var stale = await a.PutAsync<WaterEntryDto>($"/water-entries/{id}", edit with { OperationId = Guid.NewGuid(), VolumeMl = 100m });
        Assert.Equal(("conflict", Ack.RevisionConflict, 400m), (stale.Status, stale.Code, stale.Data.VolumeMl));
        Assert.Equal("rejected", (await a.PutAsync<WaterEntryDto>($"/water-entries/{id}", edit with { OperationId = Guid.NewGuid(), ExpectedRevision = 2, VolumeMl = 0m })).Status);

        var staleDelete = await a.PostAsync<WaterEntryDto>($"/water-entries/{id}/delete", new RevisionCommand(Guid.NewGuid(), 1));
        Assert.Equal(("conflict", Ack.RevisionConflict), (staleDelete.Status, staleDelete.Code));
        var removed = await a.PostAsync<WaterEntryDto>($"/water-entries/{id}/delete", new RevisionCommand(Guid.NewGuid(), 2));
        Assert.Equal(("accepted", 3, true), (removed.Status, removed.Data.Revision, removed.Data.IsDeleted));
        Assert.Equal("ENTRY_DELETED", (await a.PutAsync<WaterEntryDto>($"/water-entries/{id}", edit with { OperationId = Guid.NewGuid(), ExpectedRevision = 3 })).Code);
        Assert.Empty(await DayAsync(a, "2026-10-10"));                                       // gone from the day
        Assert.True((await a.SnapshotAsync()).WaterEntries!.Single(w => w.Id == id).IsDeleted); // kept in the snapshot for sync

        var gone = await a.Http.SendAsync(new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(a.Password)) });
        Assert.Equal(HttpStatusCode.NoContent, gone.StatusCode);
        await using var db = pg.SharedDb();
        Assert.False(await db.WaterEntries.AnyAsync(w => w.UserId == a.UserId));
    }

    [Fact]
    public async Task Water_goal_is_set_kept_when_omitted_cleared_by_explicit_null_and_range_checked()
    {
        var a = await Account.RegisterAsync(pg.Api);
        Assert.Null((await a.SnapshotAsync()).Profile.WaterGoalMl);   // none is suggested
        Assert.Contains("\"water.entries\"", await a.Http.GetStringAsync("/api/v1/capabilities"));

        var set = await a.PutAsync<ProfileDto>("/me", new ProfileUpdateRequest(Guid.NewGuid(), 1, "Test Person", "dark", "kg", false, null, new(true, 2200), default, new(true, 2500)));
        Assert.Equal(("accepted", 2500, 2200), (set.Status, set.Data.WaterGoalMl, set.Data.CalorieGoal));

        // An app that predates water goals leaves the field out and cannot erase it.
        var legacy = await a.Http.PutAsync("/api/v1/me", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":2,"displayName":"Renamed","appearance":"dark","loadUnit":"kg","remindersEnabled":false,"reminderLocalTime":null,"calorieGoal":2000}"""));
        Assert.Equal(HttpStatusCode.OK, legacy.StatusCode);
        Assert.Equal((2500, 2000), ((await a.SnapshotAsync()).Profile.WaterGoalMl, (await a.SnapshotAsync()).Profile.CalorieGoal));

        foreach (var bad in new[] { 99, 10001 })
        {
            var r = await a.PutAsync<ProfileDto>("/me", new ProfileUpdateRequest(Guid.NewGuid(), 3, "Renamed", "dark", "kg", false, null, default, default, new(true, bad)));
            Assert.Equal(("rejected", Ack.Invalid), (r.Status, r.Code));
        }

        var cleared = await a.Http.PutAsync("/api/v1/me", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":3,"displayName":"Renamed","appearance":"dark","loadUnit":"kg","remindersEnabled":false,"reminderLocalTime":null,"waterGoalMl":null}"""));
        Assert.Equal(HttpStatusCode.OK, cleared.StatusCode);
        var profile = (await a.SnapshotAsync()).Profile;
        Assert.Equal((null, 2000), (profile.WaterGoalMl, profile.CalorieGoal));
    }

    [Fact]
    public async Task Tracking_display_is_unset_until_chosen_set_including_false_and_kept_when_omitted()
    {
        var a = await Account.RegisterAsync(pg.Api);
        Assert.Contains("\"profile.tracking-display\"", await a.Http.GetStringAsync("/api/v1/capabilities"));
        var fresh = (await a.SnapshotAsync()).Profile;
        Assert.Equal((null, null, null), (fresh.ShowWater, fresh.ShowCarbs, fresh.ShowFat)); // no choice is invented

        var set = await a.Http.PutAsync("/api/v1/me", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":1,"displayName":"Test Person","appearance":"dark","loadUnit":"kg","remindersEnabled":false,"reminderLocalTime":null,"waterGoalMl":2000,"showWater":true,"showCarbs":false,"showFat":true}"""));
        Assert.Equal(HttpStatusCode.OK, set.StatusCode);

        // An older app (no display fields) renames the account: the choices, the explicit false included, are kept.
        var legacy = await a.Http.PutAsync("/api/v1/me", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":2,"displayName":"Renamed","appearance":"dark","loadUnit":"kg","remindersEnabled":false,"reminderLocalTime":null}"""));
        Assert.Equal(HttpStatusCode.OK, legacy.StatusCode);
        var p = (await a.SnapshotAsync()).Profile;
        Assert.Equal((true, false, true, 2000, "Renamed"), (p.ShowWater, p.ShowCarbs, p.ShowFat, p.WaterGoalMl, p.DisplayName));

        // Hiding water changes only what is shown: the goal stays.
        var hide = await a.Http.PutAsync("/api/v1/me", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":3,"displayName":"Renamed","appearance":"dark","loadUnit":"kg","remindersEnabled":false,"reminderLocalTime":null,"showWater":false}"""));
        Assert.Equal(HttpStatusCode.OK, hide.StatusCode);
        p = (await a.SnapshotAsync()).Profile;
        Assert.Equal((false, false, true, 2000), (p.ShowWater, p.ShowCarbs, p.ShowFat, p.WaterGoalMl));

        // A stale revision is a conflict, not a silent overwrite.
        var stale = await a.PutAsync<ProfileDto>("/me", new ProfileUpdateRequest(Guid.NewGuid(), 1, "Renamed", "dark", "kg", false, null, ShowCarbs: true));
        Assert.Equal("conflict", stale.Status);
        Assert.False((await a.SnapshotAsync()).Profile.ShowCarbs);
    }
}
