using System.Net;
using System.Net.Http.Json;
using System.Text;
using GoHard.Api.Application;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>Body check-ins with optional side-specific circumferences, corrected in place (docs/BODY_PROGRESS.md).</summary>
[Collection("api")]
public class BodyMetricTests(PostgresFixture pg)
{
    private static readonly DateOnly Oct5 = new(2026, 10, 5), Oct19 = new(2026, 10, 19);
    private static StringContent Raw(string json) => new(json, Encoding.UTF8, "application/json");
    private static Optional<decimal?> Set(decimal? v) => new(true, v);

    [Fact]
    public async Task Check_ins_keep_every_field_correct_in_place_and_stay_owned()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        Assert.Contains($"\"{ActivityService.MeasurementsCapability}\"", await a.Http.GetStringAsync("/api/v1/capabilities"));

        // A measurement-only check-in (no weight) with a quarter inch (16.25 in = 41.275 cm) and a first-saved time.
        var at = new DateTime(2026, 10, 5, 7, 30, 0, DateTimeKind.Utc);
        var create = new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Oct5, null, null, null, WaistCm: 91.44m, LeftUpperArmCm: 41.275m, RecordedAtUtc: at);
        var made = await a.PostAsync<BodyMetricDto>("/body-metrics", create);
        var retry = await a.PostAsync<BodyMetricDto>("/body-metrics", create);   // a lost response retried
        Assert.Equal(("accepted", 1), (made.Status, made.Data.Revision));
        Assert.Equal(made.Raw, retry.Raw);
        var stored = (await a.SnapshotAsync()).BodyMetrics.Single();
        Assert.Equal((91.44m, 41.275m, (decimal?)null, (decimal?)null, at), (stored.WaistCm, stored.LeftUpperArmCm, stored.RightUpperArmCm, stored.WeightKg, stored.RecordedAtUtc));

        // An older client's create (weight, body fat, note only) still works and has no first-saved time.
        var legacy = await a.Http.PostAsync("/api/v1/body-metrics", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","metricId":"{{Guid.NewGuid()}}","dayKey":"2026-10-19","weightKg":89.8113,"bodyFatPercent":21.5,"note":"after travel"}"""));
        Assert.Equal(HttpStatusCode.OK, legacy.StatusCode);
        var old = (await a.SnapshotAsync()).BodyMetrics.Single(m => m.DayKey == Oct19);
        Assert.Equal((89.8113m, 21.5m, "after travel", (DateTime?)null, (decimal?)null), (old.WeightKg, old.BodyFatPercent, old.Note, old.RecordedAtUtc, old.WaistCm));

        // Correction in place: same ID, revision checked; a field left out is kept, an explicit null clears, a value sets.
        var id = create.MetricId;
        var edit = await a.PutAsync<BodyMetricDto>($"/body-metrics/{id}", new BodyMetricUpdateRequest(Guid.NewGuid(), 1, Oct5, WaistCm: Set(90.17m), RightUpperArmCm: Set(41.91m)));
        Assert.Equal(("accepted", 2, 90.17m, 41.275m, 41.91m, at), (edit.Status, edit.Data.Revision, edit.Data.WaistCm, edit.Data.LeftUpperArmCm, edit.Data.RightUpperArmCm, edit.Data.RecordedAtUtc));
        var keep = await a.Http.PutAsync($"/api/v1/body-metrics/{id}", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":2,"dayKey":"2026-10-05","waistCm":null}"""));
        Assert.Equal(HttpStatusCode.OK, keep.StatusCode);
        stored = (await a.SnapshotAsync()).BodyMetrics.Single(m => m.Id == id);
        Assert.Equal(((decimal?)null, 41.275m, 41.91m, 3), (stored.WaistCm, stored.LeftUpperArmCm, stored.RightUpperArmCm, stored.Revision));

        // A stale edit is a conflict carrying the account's version; an edit that would leave nothing measured is refused.
        var stale = await a.PutAsync<BodyMetricDto>($"/body-metrics/{id}", new BodyMetricUpdateRequest(Guid.NewGuid(), 1, Oct5, ChestCm: Set(109.22m)));
        Assert.Equal(("conflict", Ack.RevisionConflict, 3), (stale.Status, stale.Code, stale.Data.Revision));
        var empty = await a.PutAsync<BodyMetricDto>($"/body-metrics/{id}", new BodyMetricUpdateRequest(Guid.NewGuid(), 3, Oct5, LeftUpperArmCm: Set(null), RightUpperArmCm: Set(null)));
        Assert.Equal(("rejected", Ack.Invalid), (empty.Status, empty.Code));

        // Input bounds, the same as the app's: circumferences above 0 and at most 500 cm, a note alone is not a measurement,
        // no future day.
        foreach (var bad in new[]
                 {
                     new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Oct5, null, null, null, ChestCm: 0m),
                     new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Oct5, null, null, null, LeftThighCm: 500.01m),
                     new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Oct5, null, null, "a note only"),
                     new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Oct5, 700.01m, null, null),
                     new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), DateOnly.FromDateTime(DateTime.UtcNow).AddDays(2), 80m, null, null),
                 })
        {
            var r = await a.PostAsync<BodyMetricDto>("/body-metrics", bad);
            Assert.Equal(("rejected", Ack.Invalid), (r.Status, r.Code));
        }
        Assert.Equal("accepted", (await a.PostAsync<BodyMetricDto>("/body-metrics", new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Oct5, null, null, null, RightThighCm: 500m))).Status);

        // Another account cannot read, edit or delete it.
        Assert.Empty((await other.SnapshotAsync()).BodyMetrics);
        var foreign = await other.Http.PutAsJsonAsync($"/api/v1/body-metrics/{id}", new BodyMetricUpdateRequest(Guid.NewGuid(), 3, Oct5, WaistCm: Set(80m)), Account.Json);
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);

        // Delete, then an edit of the deleted check-in is a conflict, not a resurrection.
        Assert.Equal("accepted", (await a.PostAsync<BodyMetricDto>($"/body-metrics/{id}/delete", new RevisionCommand(Guid.NewGuid(), 3))).Status);
        Assert.Equal("ENTRY_DELETED", (await a.PutAsync<BodyMetricDto>($"/body-metrics/{id}", new BodyMetricUpdateRequest(Guid.NewGuid(), 4, Oct5, WaistCm: Set(80m)))).Code);

        // Erased with the account; the other account's data stays.
        await other.PostAsync<BodyMetricDto>("/body-metrics", new BodyMetricRequest(Guid.NewGuid(), Guid.NewGuid(), Oct5, null, null, null, WaistCm: 80m));
        var gone = await a.Http.SendAsync(new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(a.Password)) });
        Assert.Equal(HttpStatusCode.NoContent, gone.StatusCode);
        await using var db = pg.SharedDb();
        Assert.False(await db.BodyMetrics.AnyAsync(m => m.UserId == a.UserId));
        Assert.True(await db.BodyMetrics.AnyAsync(m => m.UserId == other.UserId));
    }
}
