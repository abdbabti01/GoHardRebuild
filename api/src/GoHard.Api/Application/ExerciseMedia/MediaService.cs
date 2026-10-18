using System.Security.Claims;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application.ExerciseMedia;

public static class MediaStatus
{
    public const string AwaitingUpload = "awaiting_upload", Queued = "queued", Processing = "processing", Ready = "ready",
        Failed = "failed", Published = "published", Withdrawn = "withdrawn", Cancelled = "cancelled";
}

public sealed record MediaDraftCreate(Guid OperationId, Guid DraftId, string CatalogKey, string ContentType, long Bytes);
public sealed record MediaDetails(Guid OperationId, int Revision, string Variant, string Title, string Creator, string RightsKind,
    string? LicenceName, string? LicenceUrl, string? SourceUrl, string RightsNotice, bool RightsConfirmed);
public sealed record MediaRevisionCommand(Guid OperationId, int Revision);
public sealed record MediaUnpublish(Guid OperationId, Guid VersionId);

public sealed record MediaDraftDto(Guid Id, string CatalogKey, string Status, string Variant, string Title, string Creator, string RightsKind,
    string? LicenceName, string? LicenceUrl, string? SourceUrl, string RightsNotice, bool RightsConfirmed, long DeclaredBytes, long? Bytes,
    double? DurationSeconds, int? Width, int? Height, string? Error, int Revision, DateTime CreatedAtUtc, DateTime UpdatedAtUtc, DateTime? PublishedAtUtc);
public sealed record MediaVersionDto(Guid Id, string CatalogKey, string ClipUrl, string PosterUrl, long Bytes, string Sha256, double DurationSeconds,
    int Width, int Height, string Variant, string Title, string Creator, string RightsKind, string? LicenceName, string? LicenceUrl,
    string? SourceUrl, string RightsNotice, DateTime PublishedAtUtc);
public sealed record MediaCatalogDto(int Revision, string MediaOrigin, IReadOnlyList<MediaVersionDto> Entries);
public sealed record MediaManageDto(IReadOnlyList<MediaDraftDto> Drafts, IReadOnlyList<MediaVersionDto> Active);
public sealed record MediaAccessDto(bool CanManage, bool Ready, string? Problem);
public sealed record MediaLink(string Url, string Method, IReadOnlyDictionary<string, string> Headers, DateTime ExpiresAtUtc);
public sealed record MediaPreviewDto(string ClipUrl, string PosterUrl, DateTime ExpiresAtUtc);

/// <summary>Owner-only management of shared demonstrations and the public catalogue (docs/OWNER_EXERCISE_VIDEOS.md).</summary>
public sealed class MediaService(GoHardDb db, MediaOptions options, IMediaStorage? storage = null)
{
    public const string ManageCapability = "exercises.media-manage", CatalogCapability = "exercises.media-catalog";
    private const string Immutable = "public, max-age=31536000, immutable";

    /// <summary>Ownership is the verified token's subject against the server's configured ID; nothing a client sends counts.</summary>
    public bool IsOwner(ClaimsPrincipal user) =>
        options.Owner is { } owner && Guid.TryParse(user.FindFirstValue("sub"), out var id) && id == owner;

    public bool Ready => options.StorageConfigured && storage is not null;

    public static readonly HashSet<string> VideoTypes = ["video/mp4", "video/quicktime", "video/x-m4v", "video/3gpp", "video/webm", "video/x-matroska"];

    public MediaAccessDto Access(ClaimsPrincipal user) => !IsOwner(user)
        ? new(false, false, null)
        : Ready ? new(true, true, null) : new(true, false, "STORAGE_NOT_CONFIGURED");

    public static MediaDraftDto ToDto(MediaDraft d) => new(d.Id, d.CatalogKey, d.Status, d.Variant, d.Title, d.Creator, d.RightsKind, d.LicenceName,
        d.LicenceUrl, d.SourceUrl, d.RightsNotice, d.RightsConfirmed, d.DeclaredBytes, d.Bytes, d.DurationSeconds, d.Width, d.Height, d.Error,
        d.Revision, d.CreatedAtUtc, d.UpdatedAtUtc, d.PublishedAtUtc);

    public MediaVersionDto ToDto(MediaVersion v) => new(v.Id, v.CatalogKey, options.PublicUrl(v.ClipKey), options.PublicUrl(v.PosterKey), v.Bytes,
        v.Sha256, v.DurationSeconds, v.Width, v.Height, v.Variant, v.Title, v.Creator, v.RightsKind, v.LicenceName, v.LicenceUrl, v.SourceUrl,
        v.RightsNotice, v.PublishedAtUtc);

    // ------------------------------------------------------------------ public catalogue

    public async Task<int> RevisionAsync(CancellationToken ct) =>
        await db.MediaCatalogStates.AsNoTracking().Where(s => s.Id == 1).Select(s => s.Revision).FirstOrDefaultAsync(ct);

    public async Task<MediaCatalogDto> CatalogAsync(CancellationToken ct)
    {
        var revision = await RevisionAsync(ct);
        var active = await db.MediaVersions.AsNoTracking().Where(v => v.IsActive).OrderBy(v => v.CatalogKey).ToListAsync(ct);
        return new(revision, options.PublicBaseUrl.TrimEnd('/'), active.Select(ToDto).ToList());
    }

    // ------------------------------------------------------------------ management (callers have checked IsOwner)

    public async Task<MediaManageDto> ListAsync(CancellationToken ct)
    {
        var drafts = await db.MediaDrafts.AsNoTracking().Where(d => d.Status != MediaStatus.Cancelled).OrderByDescending(d => d.UpdatedAtUtc).ToListAsync(ct);
        var active = await db.MediaVersions.AsNoTracking().Where(v => v.IsActive).OrderBy(v => v.CatalogKey).ToListAsync(ct);
        return new(drafts.Select(ToDto).ToList(), active.Select(ToDto).ToList());
    }

    public async Task<MediaDraft?> FindAsync(Guid id, CancellationToken ct) => await db.MediaDrafts.FirstOrDefaultAsync(d => d.Id == id, ct);

    public async Task<Outcome<MediaDraftDto>> CreateAsync(Guid owner, MediaDraftCreate r, CancellationToken ct)
    {
        if (!Ready) return Outcome.Rejected<MediaDraftDto>("STORAGE_NOT_CONFIGURED");
        var exercise = await db.CatalogExercises.AsNoTracking().FirstOrDefaultAsync(c => c.Key == r.CatalogKey, ct);
        if (exercise is null) return Outcome.Rejected<MediaDraftDto>("UNKNOWN_EXERCISE");
        if (!VideoTypes.Contains(r.ContentType)) return Outcome.Rejected<MediaDraftDto>("UNSUPPORTED_TYPE");
        if (r.Bytes is <= 0 or > MediaOptions.MaxOriginalBytes) return Outcome.Rejected<MediaDraftDto>("TOO_LARGE");
        if (await db.MediaDrafts.AnyAsync(d => d.Id == r.DraftId, ct)) return Outcome.Rejected<MediaDraftDto>("DRAFT_EXISTS");
        var now = DateTime.UtcNow;
        var draft = new MediaDraft
        {
            Id = r.DraftId, CatalogKey = exercise.Key, Status = MediaStatus.AwaitingUpload, ContentType = r.ContentType, DeclaredBytes = r.Bytes,
            Title = exercise.Name, Creator = "GoHard", RightsKind = "original", RightsNotice = "Original footage, published by GoHard.",
            // Opaque and server-chosen: nothing of the file name or the account is in it.
            OriginalKey = $"originals/{Guid.NewGuid():N}", UploadExpiresAtUtc = now.AddMinutes(options.UploadUrlMinutes),
            CreatedBy = owner, CreatedAtUtc = now, UpdatedAtUtc = now,
        };
        db.MediaDrafts.Add(draft);
        return Outcome.Accepted(draft.Revision, ToDto(draft));
    }

    /// <summary>A fresh one-object upload URL while the draft waits for its file. Not a command: it records nothing,
    /// so the signed URL is never stored.</summary>
    public async Task<(MediaLink? Link, string? Error)> UploadLinkAsync(Guid id, CancellationToken ct)
    {
        var d = await FindAsync(id, ct);
        if (d is null) return (null, Ack.NotFound);
        if (d.Status != MediaStatus.AwaitingUpload || storage is null) return (null, "NOT_AWAITING_UPLOAD");
        var expiry = TimeSpan.FromMinutes(options.UploadUrlMinutes);
        d.UploadExpiresAtUtc = DateTime.UtcNow.Add(expiry);
        await db.SaveChangesAsync(ct);
        var url = storage.PresignPut(options.StagingBucket, d.OriginalKey, d.ContentType, expiry);
        return (new(url.ToString(), "PUT", new Dictionary<string, string> { ["Content-Type"] = d.ContentType }, d.UploadExpiresAtUtc), null);
    }

    /// <summary>The phone says the upload finished. What is stored is checked (it exists, its real size); the content
    /// itself is probed by the worker. Repeating it changes nothing.</summary>
    public async Task<Outcome<MediaDraftDto>> CompleteAsync(Guid id, CancellationToken ct)
    {
        var d = await FindAsync(id, ct);
        if (d is null) return Outcome.NotFound<MediaDraftDto>();
        if (d.Status != MediaStatus.AwaitingUpload) return Outcome.Accepted(d.Revision, ToDto(d));
        var stored = await storage!.HeadAsync(options.StagingBucket, d.OriginalKey, ct);
        if (stored is null)
            return Outcome.Rejected<MediaDraftDto>(DateTime.UtcNow > d.UploadExpiresAtUtc ? "UPLOAD_EXPIRED" : "UPLOAD_MISSING");
        var error = stored.Bytes <= 0 ? "EMPTY" : stored.Bytes > MediaOptions.MaxOriginalBytes ? "TOO_LARGE" : stored.Bytes != d.DeclaredBytes ? "SIZE_MISMATCH" : null;
        d.OriginalBytes = stored.Bytes;
        if (error is not null)
        {
            await storage.DeleteAsync(options.StagingBucket, d.OriginalKey, ct);
            d.OriginalDeleted = true;
            Touch(d, MediaStatus.Failed, error);
        }
        else Touch(d, MediaStatus.Queued, null);
        return Outcome.Accepted(d.Revision, ToDto(d));
    }

    public async Task<Outcome<MediaDraftDto>> DetailsAsync(Guid id, MediaDetails r, CancellationToken ct)
    {
        var d = await FindAsync(id, ct);
        if (d is null) return Outcome.NotFound<MediaDraftDto>();
        if (d.Status is MediaStatus.Published or MediaStatus.Withdrawn or MediaStatus.Cancelled) return Outcome.Rejected<MediaDraftDto>("NOT_EDITABLE");
        if (r.Revision != d.Revision) return Outcome.Conflict(Ack.RevisionConflict, d.Revision, ToDto(d));
        if (ValidateDetails(r) is { } error) return Outcome.Rejected<MediaDraftDto>(error);
        (d.Variant, d.Title, d.Creator, d.RightsKind, d.RightsNotice, d.RightsConfirmed) =
            (r.Variant.Trim(), r.Title.Trim(), r.Creator.Trim(), r.RightsKind, r.RightsNotice.Trim(), r.RightsConfirmed);
        (d.LicenceName, d.LicenceUrl, d.SourceUrl) = (Blank(r.LicenceName), Blank(r.LicenceUrl), Blank(r.SourceUrl));
        Touch(d, d.Status, d.Error);
        return Outcome.Accepted(d.Revision, ToDto(d));
    }

    internal static string? ValidateDetails(MediaDetails r)
    {
        static bool Https(string? s) => Uri.TryCreate(s, UriKind.Absolute, out var u) && u.Scheme == "https";
        if (r.Variant.Trim().Length is 0 or > 200 || r.Title.Trim().Length is 0 or > 80 || r.Creator.Trim().Length is 0 or > 80 || r.RightsNotice.Length > 300)
            return "INVALID_DETAILS";
        if (r.RightsKind == "original") return null;
        // Someone else's footage keeps its real creator, source and exact licence.
        if (r.RightsKind != "licensed") return "INVALID_RIGHTS";
        if (Blank(r.LicenceName) is null || !Https(r.SourceUrl) || (Blank(r.LicenceUrl) is not null && !Https(r.LicenceUrl))) return "INVALID_RIGHTS";
        return null;
    }

    public async Task<Outcome<MediaDraftDto>> RetryAsync(Guid id, MediaRevisionCommand r, CancellationToken ct)
    {
        var d = await FindAsync(id, ct);
        if (d is null) return Outcome.NotFound<MediaDraftDto>();
        if (d.Status != MediaStatus.Failed) return d.Status is MediaStatus.Queued or MediaStatus.Processing
            ? Outcome.Accepted(d.Revision, ToDto(d)) : Outcome.Rejected<MediaDraftDto>("NOT_FAILED");
        if (r.Revision != d.Revision) return Outcome.Conflict(Ack.RevisionConflict, d.Revision, ToDto(d));
        d.Attempts = 0;
        // Without its original (rejected at upload) the only way on is a new upload.
        Touch(d, d.OriginalDeleted ? MediaStatus.AwaitingUpload : MediaStatus.Queued, null);
        if (d.OriginalDeleted) { d.OriginalKey = $"originals/{Guid.NewGuid():N}"; d.OriginalDeleted = false; d.OriginalBytes = null; }
        return Outcome.Accepted(d.Revision, ToDto(d));
    }

    public async Task<(MediaPreviewDto? Preview, string? Error)> PreviewAsync(Guid id, CancellationToken ct)
    {
        var d = await FindAsync(id, ct);
        if (d is null) return (null, Ack.NotFound);
        if (d.ProcessedKey is null || d.PosterKey is null || d.Status is not (MediaStatus.Ready or MediaStatus.Published or MediaStatus.Withdrawn)) return (null, "NOT_READY");
        var expiry = TimeSpan.FromMinutes(options.PreviewUrlMinutes);
        return (new(storage!.PresignGet(options.StagingBucket, d.ProcessedKey, expiry).ToString(),
            storage.PresignGet(options.StagingBucket, d.PosterKey, expiry).ToString(), DateTime.UtcNow.Add(expiry)), null);
    }

    /// <summary>Copies the processed clip and poster to immutable public names, checks them, and only then moves the
    /// key's active pointer and the catalogue revision in this transaction. Publishing again changes nothing.</summary>
    public async Task<Outcome<MediaVersionDto>> PublishAsync(Guid id, MediaRevisionCommand r, CancellationToken ct)
    {
        var d = await FindAsync(id, ct);
        if (d is null) return Outcome.NotFound<MediaVersionDto>();
        if (d.Status == MediaStatus.Published && d.PublishedVersionId is { } done)
            return Outcome.Accepted(d.Revision, ToDto(await db.MediaVersions.AsNoTracking().FirstAsync(v => v.Id == done, ct)));
        if (d.Status != MediaStatus.Ready) return Outcome.Rejected<MediaVersionDto>("NOT_READY");
        if (r.Revision != d.Revision) return Outcome.Conflict<MediaVersionDto>(Ack.RevisionConflict, d.Revision);
        if (!d.RightsConfirmed || d.Variant.Length == 0) return Outcome.Rejected<MediaVersionDto>("DETAILS_REQUIRED");

        var clipKey = $"clips/{d.CatalogKey}/{d.Sha256}.mp4";
        var posterKey = $"posters/{d.CatalogKey}/{d.Sha256}.jpg";
        await storage!.CopyAsync(options.StagingBucket, d.ProcessedKey!, options.PublicBucket, clipKey, "video/mp4", Immutable, ct);
        await storage.CopyAsync(options.StagingBucket, d.PosterKey!, options.PublicBucket, posterKey, "image/jpeg", Immutable, ct);
        var clip = await storage.HeadAsync(options.PublicBucket, clipKey, ct);
        if (clip?.Bytes != d.Bytes || await storage.HeadAsync(options.PublicBucket, posterKey, ct) is null)
            return Outcome.Rejected<MediaVersionDto>("PUBLISH_COPY_FAILED"); // nothing visible changed

        var now = DateTime.UtcNow;
        foreach (var old in await db.MediaVersions.Where(v => v.CatalogKey == d.CatalogKey && v.IsActive).ToListAsync(ct))
        {
            old.IsActive = false;
            old.WithdrawnAtUtc = now;
            await db.MediaDrafts.Where(x => x.Id == old.DraftId).ExecuteUpdateAsync(s => s.SetProperty(x => x.Status, MediaStatus.Withdrawn), ct);
        }
        await db.SaveChangesAsync(ct); // the old pointer goes first: the unique active index never sees two
        var version = new MediaVersion
        {
            Id = Guid.NewGuid(), CatalogKey = d.CatalogKey, DraftId = d.Id, IsActive = true, ClipKey = clipKey, PosterKey = posterKey,
            Bytes = d.Bytes!.Value, Sha256 = d.Sha256!, DurationSeconds = d.DurationSeconds!.Value, Width = d.Width!.Value, Height = d.Height!.Value,
            Variant = d.Variant, Title = d.Title, Creator = d.Creator, RightsKind = d.RightsKind, LicenceName = d.LicenceName,
            LicenceUrl = d.LicenceUrl, SourceUrl = d.SourceUrl, RightsNotice = d.RightsNotice, PublishedAtUtc = now,
        };
        db.MediaVersions.Add(version);
        d.PublishedVersionId = version.Id;
        d.PublishedAtUtc = now;
        Touch(d, MediaStatus.Published, null);
        await BumpAsync(ct);
        return Outcome.Accepted(d.Revision, ToDto(version));
    }

    /// <summary>Withdraws the key's active owner video (the bundled fallback shows again). The caller names the version
    /// it saw; another one active since then is a conflict, not silently withdrawn.</summary>
    public async Task<Outcome<MediaVersionDto?>> UnpublishAsync(string catalogKey, MediaUnpublish r, CancellationToken ct)
    {
        var active = await db.MediaVersions.FirstOrDefaultAsync(v => v.CatalogKey == catalogKey && v.IsActive, ct);
        if (active is null)
            return await db.MediaVersions.AnyAsync(v => v.Id == r.VersionId && v.CatalogKey == catalogKey, ct)
                ? Outcome.Accepted<MediaVersionDto?>(0, null) // already withdrawn: a retry
                : Outcome.NotFound<MediaVersionDto?>();
        if (active.Id != r.VersionId) return Outcome.Conflict<MediaVersionDto?>(Ack.RevisionConflict, 0, ToDto(active));
        active.IsActive = false;
        active.WithdrawnAtUtc = DateTime.UtcNow;
        await db.MediaDrafts.Where(x => x.Id == active.DraftId).ExecuteUpdateAsync(s => s.SetProperty(x => x.Status, MediaStatus.Withdrawn), ct);
        await BumpAsync(ct);
        return Outcome.Accepted<MediaVersionDto?>(0, null);
    }

    /// <summary>Discards an unpublished draft. Its staging files are removed by the cleanup pass.</summary>
    public async Task<Outcome<MediaDraftDto>> DeleteAsync(Guid id, MediaRevisionCommand r, CancellationToken ct)
    {
        var d = await FindAsync(id, ct);
        if (d is null) return Outcome.NotFound<MediaDraftDto>();
        if (d.Status == MediaStatus.Cancelled) return Outcome.Accepted(d.Revision, ToDto(d));
        if (d.Status is MediaStatus.Published or MediaStatus.Processing) return Outcome.Rejected<MediaDraftDto>("NOT_DELETABLE");
        if (r.Revision != d.Revision) return Outcome.Conflict(Ack.RevisionConflict, d.Revision, ToDto(d));
        Touch(d, MediaStatus.Cancelled, null);
        return Outcome.Accepted(d.Revision, ToDto(d));
    }

    private async Task BumpAsync(CancellationToken ct)
    {
        var state = await db.MediaCatalogStates.FirstAsync(s => s.Id == 1, ct);
        state.Revision++;
        state.UpdatedAtUtc = DateTime.UtcNow;
    }

    internal static void Touch(MediaDraft d, string status, string? error)
    {
        d.Status = status;
        d.Error = error;
        d.Revision++;
        d.UpdatedAtUtc = DateTime.UtcNow;
    }

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
