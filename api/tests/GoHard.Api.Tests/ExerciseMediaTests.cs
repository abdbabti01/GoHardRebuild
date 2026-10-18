using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using GoHard.Api.Application;
using GoHard.Api.Application.ExerciseMedia;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace GoHard.Api.Tests;

/// <summary>An object store in memory: what the phone would PUT is placed with <see cref="Put"/>.</summary>
public sealed class MemoryStorage : IMediaStorage
{
    public readonly ConcurrentDictionary<(string Bucket, string Key), (byte[] Bytes, string? Type, string? Cache)> Objects = new();
    public readonly List<string> Presigned = [];
    public void Put(string bucket, string key, int bytes, string type = "video/quicktime") => Objects[(bucket, key)] = (new byte[bytes], type, null);

    public Uri PresignPut(string bucket, string key, string contentType, TimeSpan expiry)
    {
        lock (Presigned) Presigned.Add(key);
        return new($"https://storage.test/{bucket}/{key}?X-Amz-Signature=test");
    }
    public Uri PresignGet(string bucket, string key, TimeSpan expiry) => new($"https://storage.test/{bucket}/{key}?X-Amz-Signature=get");
    public Task<StoredObject?> HeadAsync(string bucket, string key, CancellationToken ct) =>
        Task.FromResult(Objects.TryGetValue((bucket, key), out var o) ? new StoredObject(o.Bytes.Length, o.Type) : null);
    public async Task DownloadAsync(string bucket, string key, string path, long maxBytes, CancellationToken ct)
    {
        var o = Objects[(bucket, key)];
        if (o.Bytes.Length > maxBytes) throw new MediaRejected("TOO_LARGE");
        await File.WriteAllBytesAsync(path, o.Bytes, ct);
    }
    public async Task UploadAsync(string bucket, string key, string path, string contentType, string? cacheControl, CancellationToken ct) =>
        Objects[(bucket, key)] = (await File.ReadAllBytesAsync(path, ct), contentType, cacheControl);
    public Task CopyAsync(string fromBucket, string fromKey, string toBucket, string toKey, string contentType, string? cacheControl, CancellationToken ct)
    {
        Objects[(toBucket, toKey)] = (Objects[(fromBucket, fromKey)].Bytes, contentType, cacheControl);
        return Task.CompletedTask;
    }
    public Task DeleteAsync(string bucket, string key, CancellationToken ct)
    {
        Objects.TryRemove((bucket, key), out _);
        return Task.CompletedTask;
    }
}

/// <summary>Stands in for FFmpeg: writes a small clip and poster, or fails the way it is told to.</summary>
public sealed class FakeProcessor : IMediaProcessor
{
    public Func<Exception?> Fail = () => null;
    public int Calls;
    public async Task<ProcessedMedia> ProcessAsync(string input, string work, CancellationToken ct)
    {
        Interlocked.Increment(ref Calls);
        if (Fail() is { } e) throw e;
        var clip = Path.Combine(work, "clip.mp4");
        var poster = Path.Combine(work, "poster.jpg");
        var bytes = new byte[1234];
        Random.Shared.NextBytes(bytes);
        await File.WriteAllBytesAsync(clip, bytes, ct);
        await File.WriteAllBytesAsync(poster, [1, 2, 3], ct);
        return new(clip, poster, bytes.Length, Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(bytes)), 12.5, 1280, 720);
    }
}

[Collection("api")]
public sealed class ExerciseMediaTests(PostgresFixture pg)
{
    private const string Staging = "staging", Public = "public";
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private sealed record Setup(ApiFactory Api, Account Owner, Account Viewer, MemoryStorage Storage, FakeProcessor Processor, string Db);

    private static Dictionary<string, string> Settings(string? owner) => new()
    {
        ["ExerciseMedia:OwnerUserId"] = owner ?? "", ["ExerciseMedia:ServiceUrl"] = "https://storage.test", ["ExerciseMedia:AccessKeyId"] = "k",
        ["ExerciseMedia:SecretAccessKey"] = "s", ["ExerciseMedia:StagingBucket"] = Staging, ["ExerciseMedia:PublicBucket"] = Public,
        ["ExerciseMedia:PublicBaseUrl"] = "https://media.test", ["ExerciseMedia:WorkerEnabled"] = "false",
    };

    /// <summary>A fresh database whose configured owner is a real registered account, and an ordinary second account.</summary>
    private async Task<Setup> SetupAsync(Func<Guid, string?>? owner = null)
    {
        var db = await pg.CreateDatabaseAsync(migrate: true);
        await using var first = new ApiFactory(db);
        var ownerAccount = await Account.RegisterAsync(first, "Owner");
        var storage = new MemoryStorage();
        var processor = new FakeProcessor();
        var api = new ApiFactory(db)
        {
            Settings = Settings(owner is null ? ownerAccount.UserId.ToString() : owner(ownerAccount.UserId)),
            Configure = s => { s.AddSingleton<IMediaStorage>(storage); s.AddSingleton<IMediaProcessor>(processor); },
        };
        return new(api, await LoginAsync(api, ownerAccount), await Account.RegisterAsync(api, "Viewer"), storage, processor, db);
    }

    private static async Task<Account> LoginAsync(ApiFactory api, Account account)
    {
        var http = api.CreateClient();
        var r = await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(account.Auth.Profile.Email, account.Password));
        var auth = (await r.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return new Account(http, auth, account.Password);
    }

    private static async Task<MediaDraftDto> DraftAsync(Account a, string key = "bench-press", long bytes = 5_000_000)
    {
        var r = await a.PostAsync<MediaDraftDto>("/exercise-media/manage/drafts", new MediaDraftCreate(Guid.NewGuid(), Guid.NewGuid(), key, "video/quicktime", bytes));
        Assert.Equal("accepted", r.Status);
        return r.Data;
    }

    /// <summary>Gets an upload link, "uploads" <paramref name="bytes"/> to the key it names, and completes.</summary>
    private static async Task<AckResult<MediaDraftDto>> UploadAsync(Setup s, MediaDraftDto d, int? bytes = null)
    {
        var link = await s.Owner.Http.PostAsync($"/api/v1/exercise-media/manage/drafts/{d.Id}/upload-url", null);
        Assert.Equal(HttpStatusCode.OK, link.StatusCode);
        string key;
        lock (s.Storage.Presigned) key = s.Storage.Presigned[^1];
        s.Storage.Put(Staging, key, bytes ?? (int)d.DeclaredBytes);
        return await s.Owner.PostAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{d.Id}/complete", new OperationOnly(Guid.NewGuid()));
    }

    private static MediaWorker Worker(Setup s) => s.Api.Services.GetRequiredService<MediaWorker>();

    private static async Task<MediaDraftDto> ReadyAsync(Setup s, string key = "bench-press")
    {
        var d = await DraftAsync(s.Owner, key, 4096);
        Assert.Equal("queued", (await UploadAsync(s, d)).Data.Status);
        Assert.True(await Worker(s).RunOnceAsync(default));
        var details = await s.Owner.PutAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{d.Id}/details", new MediaDetails(Guid.NewGuid(),
            (await GetDraftAsync(s, d.Id)).Revision, "Flat bench, barbell, side view", "Bench press", "GoHard", "original", null, null, null,
            "Original footage, published by GoHard.", true));
        Assert.Equal("accepted", details.Status);
        Assert.Equal("ready", details.Data.Status);
        return details.Data;
    }

    private static async Task<MediaDraftDto> GetDraftAsync(Setup s, Guid id) =>
        (await s.Owner.Http.GetFromJsonAsync<MediaManageDto>("/api/v1/exercise-media/manage", Json))!.Drafts.Single(x => x.Id == id);

    private static async Task<MediaCatalogDto> CatalogAsync(Account a) => (await a.Http.GetFromJsonAsync<MediaCatalogDto>("/api/v1/exercise-media/catalog", Json))!;

    [Fact]
    public async Task only_the_configured_owner_can_manage_anyone_else_finds_nothing()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        var d = await DraftAsync(s.Owner);

        var anonymous = s.Api.CreateClient();
        foreach (var path in new[] { "/api/v1/exercise-media/access", "/api/v1/exercise-media/catalog", "/api/v1/exercise-media/manage" })
            Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync(path)).StatusCode);

        var access = await s.Viewer.Http.GetFromJsonAsync<MediaAccessDto>("/api/v1/exercise-media/access", Json);
        Assert.Equal(new MediaAccessDto(false, false, null), access);
        Assert.Equal(new MediaAccessDto(true, true, null), await s.Owner.Http.GetFromJsonAsync<MediaAccessDto>("/api/v1/exercise-media/access", Json));
        // Every management route, including reads and links, is 404 for an ordinary account: nothing reveals that management exists.
        var v = s.Viewer.Http;
        Assert.Equal(HttpStatusCode.NotFound, (await v.GetAsync("/api/v1/exercise-media/manage")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await v.PostAsync($"/api/v1/exercise-media/manage/drafts/{d.Id}/upload-url", null)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await v.GetAsync($"/api/v1/exercise-media/manage/drafts/{d.Id}/preview")).StatusCode);
        foreach (var (path, body) in new (string, object)[]
        {
            ("/exercise-media/manage/drafts", new MediaDraftCreate(Guid.NewGuid(), Guid.NewGuid(), "bench-press", "video/mp4", 100)),
            ($"/exercise-media/manage/drafts/{d.Id}/complete", new OperationOnly(Guid.NewGuid())),
            ($"/exercise-media/manage/drafts/{d.Id}/publish", new MediaRevisionCommand(Guid.NewGuid(), d.Revision)),
            ($"/exercise-media/manage/drafts/{d.Id}/delete", new MediaRevisionCommand(Guid.NewGuid(), d.Revision)),
            ("/exercise-media/manage/keys/bench-press/unpublish", new MediaUnpublish(Guid.NewGuid(), Guid.NewGuid())),
            // Forged fields name the owner; they are not part of any contract and change nothing.
            ("/exercise-media/manage/drafts", new { operationId = Guid.NewGuid(), draftId = Guid.NewGuid(), catalogKey = "dip", contentType = "video/mp4", bytes = 10, ownerUserId = s.Owner.UserId, role = "owner" }),
        })
            Assert.Equal(HttpStatusCode.NotFound, (await s.Viewer.PostAsync<object>(path, body)).Http);
        // Nothing the viewer sent created anything.
        await using var db = PostgresFixture.NewDb(s.Db);
        Assert.Equal(1, await db.MediaDrafts.CountAsync());
        // A profile update cannot make anyone the owner.
        var me = await s.Viewer.Http.GetFromJsonAsync<ProfileDto>("/api/v1/me", Json);
        await s.Viewer.PutAsync<object>("/me", new { operationId = Guid.NewGuid(), revision = me!.Revision, displayName = "Owner", userId = s.Owner.UserId, role = "owner" });
        Assert.Equal(HttpStatusCode.NotFound, (await v.GetAsync("/api/v1/exercise-media/manage")).StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-a-guid")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    public async Task missing_or_invalid_owner_configuration_grants_nobody(string configured)
    {
        var s = await SetupAsync(_ => configured);
        await using var _ = s.Api;
        Assert.False((await s.Owner.Http.GetFromJsonAsync<MediaAccessDto>("/api/v1/exercise-media/access", Json))!.CanManage);
        Assert.Equal(HttpStatusCode.NotFound, (await s.Owner.Http.GetAsync("/api/v1/exercise-media/manage")).StatusCode);
        var caps = await s.Owner.Http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities");
        var list = caps.GetProperty("capabilities").EnumerateArray().Select(x => x.GetString()).ToList();
        Assert.Contains(MediaService.CatalogCapability, list);
        Assert.DoesNotContain(MediaService.ManageCapability, list);
    }

    [Fact]
    public async Task without_storage_the_owner_is_told_and_nothing_can_be_started()
    {
        var db = await pg.CreateDatabaseAsync(migrate: true);
        await using var first = new ApiFactory(db);
        var owner = await Account.RegisterAsync(first);
        await using var api = new ApiFactory(db) { Settings = new() { ["ExerciseMedia:OwnerUserId"] = owner.UserId.ToString() } };
        var o = await LoginAsync(api, owner);
        Assert.Equal(new MediaAccessDto(true, false, "STORAGE_NOT_CONFIGURED"), await o.Http.GetFromJsonAsync<MediaAccessDto>("/api/v1/exercise-media/access", Json));
        var r = await o.PostAsync<MediaDraftDto>("/exercise-media/manage/drafts", new MediaDraftCreate(Guid.NewGuid(), Guid.NewGuid(), "dip", "video/mp4", 100));
        Assert.Equal(HttpStatusCode.ServiceUnavailable, r.Http);
        Assert.Empty((await CatalogAsync(o)).Entries); // the catalogue still answers
    }

    [Fact]
    public async Task drafts_accept_only_real_keys_video_types_and_the_size_limit()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        foreach (var (key, type, bytes, code) in new[]
        {
            ("Bench press", "video/mp4", 100L, "UNKNOWN_EXERCISE"), ("custom:abc", "video/mp4", 100L, "UNKNOWN_EXERCISE"),
            ("bench-press", "image/gif", 100L, "UNSUPPORTED_TYPE"), ("bench-press", "video/mp4", MediaOptions.MaxOriginalBytes + 1, "TOO_LARGE"),
            ("bench-press", "video/mp4", 0L, "TOO_LARGE"),
        })
        {
            var r = await s.Owner.PostAsync<MediaDraftDto>("/exercise-media/manage/drafts", new MediaDraftCreate(Guid.NewGuid(), Guid.NewGuid(), key, type, bytes));
            Assert.Equal(code, r.Code);
        }
    }

    [Fact]
    public async Task completion_checks_what_was_really_stored_and_is_idempotent()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;

        var missing = await DraftAsync(s.Owner);
        var r = await s.Owner.PostAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{missing.Id}/complete", new OperationOnly(Guid.NewGuid()));
        Assert.Equal("UPLOAD_MISSING", r.Code);

        // The phone declared 5 MB but stored more than the 200 MiB limit: refused, the object deleted.
        var big = await DraftAsync(s.Owner);
        var over = await UploadAsync(s, big, (int)MediaOptions.MaxOriginalBytes + 1);
        Assert.Equal(("failed", "TOO_LARGE"), (over.Data.Status, over.Data.Error));
        Assert.DoesNotContain(s.Storage.Objects.Keys, k => k.Bucket == Staging && k.Key.StartsWith("originals/") && s.Storage.Objects[k].Bytes.Length > 1000);

        var mismatch = await DraftAsync(s.Owner);
        Assert.Equal("SIZE_MISMATCH", (await UploadAsync(s, mismatch, 10)).Data.Error);

        // An upload link that expired before anything arrived.
        var expired = await DraftAsync(s.Owner);
        await using (var db = PostgresFixture.NewDb(s.Db))
            await db.MediaDrafts.Where(x => x.Id == expired.Id).ExecuteUpdateAsync(x => x.SetProperty(y => y.UploadExpiresAtUtc, DateTime.UtcNow.AddHours(-1)));
        Assert.Equal("UPLOAD_EXPIRED", (await s.Owner.PostAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{expired.Id}/complete", new OperationOnly(Guid.NewGuid()))).Code);
        // A new link revives it.
        Assert.Equal(HttpStatusCode.OK, (await s.Owner.Http.PostAsync($"/api/v1/exercise-media/manage/drafts/{expired.Id}/upload-url", null)).StatusCode);

        var ok = await DraftAsync(s.Owner);
        var done = await UploadAsync(s, ok);
        Assert.Equal("queued", done.Data.Status);
        var again = await s.Owner.PostAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{ok.Id}/complete", new OperationOnly(Guid.NewGuid()));
        Assert.Equal(("accepted", "queued", done.Data.Revision), (again.Status, again.Data.Status, again.Data.Revision));
        // No upload link once the file is in.
        Assert.Equal(HttpStatusCode.Conflict, (await s.Owner.Http.PostAsync($"/api/v1/exercise-media/manage/drafts/{ok.Id}/upload-url", null)).StatusCode);
        // Signed URLs are answers only: never kept in the operation log.
        await using var check = PostgresFixture.NewDb(s.Db);
        Assert.False(await check.Operations.AnyAsync(o => o.ResponseJson.Contains("Signature")));
    }

    [Fact]
    public async Task one_worker_claims_a_job_and_an_expired_lease_is_taken_again()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        var d = await DraftAsync(s.Owner, bytes: 4096);
        await UploadAsync(s, d);

        // Many competing claims on one queued draft: exactly one wins.
        var claims = await Task.WhenAll(Enumerable.Range(0, 8).Select(async _ =>
        {
            await using var db = PostgresFixture.NewDb(s.Db);
            return await MediaWorker.ClaimAsync(db, Guid.NewGuid(), TimeSpan.FromMinutes(5), default);
        }));
        Assert.Single(claims, c => c == d.Id);
        Assert.Equal(7, claims.Count(c => c is null));

        // That worker "died": while its lease runs nobody else takes it; after, another worker does.
        await using (var db = PostgresFixture.NewDb(s.Db))
            Assert.Null(await MediaWorker.ClaimAsync(db, Guid.NewGuid(), TimeSpan.FromMinutes(5), default));
        await using (var db = PostgresFixture.NewDb(s.Db))
            await db.MediaDrafts.Where(x => x.Id == d.Id).ExecuteUpdateAsync(x => x.SetProperty(y => y.LeaseUntilUtc, DateTime.UtcNow.AddMinutes(-1)));
        Assert.True(await Worker(s).RunOnceAsync(default));
        var after = await GetDraftAsync(s, d.Id);
        Assert.Equal("ready", after.Status);
        Assert.Equal(1, s.Processor.Calls);
    }

    [Fact]
    public async Task processing_failures_are_bounded_reported_and_retryable()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        var d = await DraftAsync(s.Owner, bytes: 4096);
        await UploadAsync(s, d);

        // A crash is retried (back in the queue) until the attempt limit, then reported.
        s.Processor.Fail = () => new IOException("disk");
        for (var i = 0; i < 3; i++) Assert.True(await Worker(s).RunOnceAsync(default));
        var failed = await GetDraftAsync(s, d.Id);
        Assert.Equal(("failed", "PROCESSING_FAILED"), (failed.Status, failed.Error));
        Assert.False(await Worker(s).RunOnceAsync(default), "nothing left to claim");

        // Content the pipeline refuses fails at once with its reason.
        var bad = await DraftAsync(s.Owner, "dip", 4096);
        await UploadAsync(s, bad);
        s.Processor.Fail = () => new MediaRejected("TOO_LONG");
        await Worker(s).RunOnceAsync(default);
        Assert.Equal(("failed", "TOO_LONG"), ((await GetDraftAsync(s, bad.Id)).Status, (await GetDraftAsync(s, bad.Id)).Error));

        // The owner retries; it works this time.
        s.Processor.Fail = () => null;
        var retry = await s.Owner.PostAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{d.Id}/retry", new MediaRevisionCommand(Guid.NewGuid(), failed.Revision));
        Assert.Equal("queued", retry.Data.Status);
        await Worker(s).RunOnceAsync(default);
        Assert.Equal("ready", (await GetDraftAsync(s, d.Id)).Status);
    }

    [Fact]
    public async Task a_draft_is_private_until_published_and_publishing_once_is_enough()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        var ready = await ReadyAsync(s);
        var before = await CatalogAsync(s.Viewer);
        Assert.Empty(before.Entries);
        Assert.Equal(HttpStatusCode.OK, (await s.Owner.Http.GetAsync($"/api/v1/exercise-media/manage/drafts/{ready.Id}/preview")).StatusCode);
        Assert.DoesNotContain(s.Storage.Objects.Keys, k => k.Bucket == Public);

        // Publishing needs the rights confirmed.
        var unconfirmed = await ReadyAsync(s, "dip");
        await s.Owner.PutAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{unconfirmed.Id}/details", new MediaDetails(Guid.NewGuid(), unconfirmed.Revision,
            "Parallel bars", "Dip", "GoHard", "original", null, null, null, "", false));
        Assert.Equal("DETAILS_REQUIRED", (await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{unconfirmed.Id}/publish",
            new MediaRevisionCommand(Guid.NewGuid(), (await GetDraftAsync(s, unconfirmed.Id)).Revision))).Code);

        // A stale revision conflicts instead of publishing something other than what was reviewed.
        Assert.Equal("conflict", (await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{ready.Id}/publish",
            new MediaRevisionCommand(Guid.NewGuid(), ready.Revision - 1))).Status);

        var op = Guid.NewGuid();
        var published = await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{ready.Id}/publish", new MediaRevisionCommand(op, ready.Revision));
        Assert.Equal("accepted", published.Status);
        var v = published.Data;
        Assert.StartsWith("https://media.test/clips/bench-press/", v.ClipUrl);
        Assert.Equal(("video/mp4", "public, max-age=31536000, immutable"), (s.Storage.Objects[(Public, $"clips/bench-press/{v.Sha256}.mp4")].Type, s.Storage.Objects[(Public, $"clips/bench-press/{v.Sha256}.mp4")].Cache));

        // The same operation replays; a new one on a published draft returns the same version. No second publication.
        Assert.Equal(v.Id, (await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{ready.Id}/publish", new MediaRevisionCommand(op, ready.Revision))).Data.Id);
        Assert.Equal(v.Id, (await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{ready.Id}/publish", new MediaRevisionCommand(Guid.NewGuid(), 999))).Data.Id);

        var catalog = await CatalogAsync(s.Viewer);
        Assert.Equal(before.Revision + 1, catalog.Revision);
        var entry = Assert.Single(catalog.Entries);
        Assert.Equal(("bench-press", "original", "GoHard", "https://media.test"), (entry.CatalogKey, entry.RightsKind, entry.Creator, catalog.MediaOrigin));
        // Only published metadata: no staging keys, original names, actors or links.
        var raw = await s.Viewer.Http.GetStringAsync("/api/v1/exercise-media/catalog");
        foreach (var secret in new[] { "originals/", "processed/", s.Owner.UserId.ToString(), "Signature", Staging + "/" }) Assert.DoesNotContain(secret, raw);
        // ...and none of it in a person's sync snapshot.
        Assert.DoesNotContain("exercise-media", await s.Viewer.Http.GetStringAsync("/api/v1/sync/snapshot"));
    }

    [Fact]
    public async Task the_catalogue_answers_304_until_it_changes()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        var first = await s.Viewer.Http.GetAsync("/api/v1/exercise-media/catalog");
        var etag = first.Headers.ETag!;
        var again = new HttpRequestMessage(HttpMethod.Get, "/api/v1/exercise-media/catalog");
        again.Headers.IfNoneMatch.Add(etag);
        Assert.Equal(HttpStatusCode.NotModified, (await s.Viewer.Http.SendAsync(again)).StatusCode);

        var ready = await ReadyAsync(s);
        await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{ready.Id}/publish", new MediaRevisionCommand(Guid.NewGuid(), ready.Revision));
        var changed = new HttpRequestMessage(HttpMethod.Get, "/api/v1/exercise-media/catalog");
        changed.Headers.IfNoneMatch.Add(etag);
        var r = await s.Viewer.Http.SendAsync(changed);
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        Assert.NotEqual(etag, r.Headers.ETag);
    }

    [Fact]
    public async Task a_replacement_takes_over_atomically_and_unpublishing_restores_the_fallback()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        var first = await ReadyAsync(s);
        var v1 = (await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{first.Id}/publish", new MediaRevisionCommand(Guid.NewGuid(), first.Revision))).Data;

        // A replacement that fails processing leaves the published one untouched.
        var broken = await DraftAsync(s.Owner, bytes: 4096);
        await UploadAsync(s, broken);
        s.Processor.Fail = () => new MediaRejected("NOT_A_VIDEO");
        await Worker(s).RunOnceAsync(default);
        s.Processor.Fail = () => null;
        Assert.Equal(v1.Id, Assert.Single((await CatalogAsync(s.Viewer)).Entries).Id);

        var second = await ReadyAsync(s);
        var v2 = (await s.Owner.PostAsync<MediaVersionDto>($"/exercise-media/manage/drafts/{second.Id}/publish", new MediaRevisionCommand(Guid.NewGuid(), second.Revision))).Data;
        var entry = Assert.Single((await CatalogAsync(s.Viewer)).Entries);
        Assert.Equal(v2.Id, entry.Id);
        Assert.NotEqual(v1.ClipUrl, v2.ClipUrl); // a new immutable object, never an overwrite at a cached URL
        Assert.True(s.Storage.Objects.ContainsKey((Public, $"clips/bench-press/{v1.Sha256}.mp4")), "the old object stays for phones that still have it");
        await using (var db = PostgresFixture.NewDb(s.Db))
        {
            Assert.Equal(1, await db.MediaVersions.CountAsync(x => x.IsActive && x.CatalogKey == "bench-press"));
            Assert.Equal("withdrawn", (await db.MediaDrafts.FirstAsync(x => x.Id == first.Id)).Status);
        }

        // Unpublishing names what it saw: the older version is a conflict, not a silent withdrawal of the newer one.
        Assert.Equal("conflict", (await s.Owner.PostAsync<object>("/exercise-media/manage/keys/bench-press/unpublish", new MediaUnpublish(Guid.NewGuid(), v1.Id))).Status);
        Assert.Equal("accepted", (await s.Owner.PostAsync<object>("/exercise-media/manage/keys/bench-press/unpublish", new MediaUnpublish(Guid.NewGuid(), v2.Id))).Status);
        Assert.Empty((await CatalogAsync(s.Viewer)).Entries);
        Assert.Equal("accepted", (await s.Owner.PostAsync<object>("/exercise-media/manage/keys/bench-press/unpublish", new MediaUnpublish(Guid.NewGuid(), v2.Id))).Status);
    }

    [Fact]
    public async Task licensed_footage_keeps_its_creator_source_and_licence_and_deleting_a_draft_cleans_staging()
    {
        var s = await SetupAsync();
        await using var _ = s.Api;
        var d = await ReadyAsync(s, "dip");
        var invalid = await s.Owner.PutAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{d.Id}/details", new MediaDetails(Guid.NewGuid(), d.Revision,
            "Parallel bars", "Dip", "Goulart", "licensed", null, null, "https://wger.de/en/exercise/194/view-base", "", true));
        Assert.Equal("INVALID_RIGHTS", invalid.Code);
        var ok = await s.Owner.PutAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{d.Id}/details", new MediaDetails(Guid.NewGuid(), d.Revision,
            "Parallel bars", "Dip", "Goulart", "licensed", "CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/",
            "https://wger.de/en/exercise/194/view-base", "Transcoded to H.264 by GoHard.", true));
        Assert.Equal(("licensed", "CC BY-SA 4.0"), (ok.Data.RightsKind, ok.Data.LicenceName));

        var del = await s.Owner.PostAsync<MediaDraftDto>($"/exercise-media/manage/drafts/{d.Id}/delete", new MediaRevisionCommand(Guid.NewGuid(), ok.Data.Revision));
        Assert.Equal("cancelled", del.Data.Status);
        Assert.Contains(s.Storage.Objects.Keys, k => k.Bucket == Staging);
        await Worker(s).CleanupAsync(default);
        Assert.DoesNotContain(s.Storage.Objects.Keys, k => k.Bucket == Staging);
    }
}
