using System.Diagnostics;
using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application.ExerciseMedia;

public sealed record ProcessedMedia(string ClipPath, string PosterPath, long Bytes, string Sha256, double DurationSeconds, int Width, int Height);

/// <summary>Turns one complete local original into the published form. Throws <see cref="MediaRejected"/> for content
/// it refuses (the owner sees the code); anything else is a failed attempt that may be retried.</summary>
public interface IMediaProcessor
{
    Task<ProcessedMedia> ProcessAsync(string input, string workDirectory, CancellationToken ct);
}

/// <summary>
/// One bounded worker (docs/OWNER_EXERCISE_VIDEOS.md › Processing): claims the oldest queued draft (or one whose lease
/// ran out) with a database lease, so two workers never process the same draft and a restart picks it up again.
/// </summary>
public sealed class MediaWorker(IServiceScopeFactory scopes, MediaOptions options, IMediaStorage storage, IMediaProcessor processor, ILogger<MediaWorker> log)
    : BackgroundService
{
    private readonly Guid _me = Guid.NewGuid();
    private DateTime _lastCleanup = DateTime.MinValue;

    protected override async Task ExecuteAsync(CancellationToken stop)
    {
        while (!stop.IsCancellationRequested)
        {
            var worked = false;
            try
            {
                worked = await RunOnceAsync(stop);
                if (DateTime.UtcNow - _lastCleanup > TimeSpan.FromHours(1))
                {
                    await CleanupAsync(stop);
                    _lastCleanup = DateTime.UtcNow;
                }
            }
            catch (OperationCanceledException) when (stop.IsCancellationRequested) { return; }
            catch (Exception e) { log.LogWarning("Media worker pass failed: {Kind}", e.GetType().Name); } // no URLs or keys in logs
            if (!worked) await Task.Delay(TimeSpan.FromSeconds(5), stop).ContinueWith(_ => { }, CancellationToken.None);
        }
    }

    /// <summary>Processes at most one draft. True when one was claimed.</summary>
    public async Task<bool> RunOnceAsync(CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<GoHardDb>();
        var id = await ClaimAsync(db, _me, TimeSpan.FromMinutes(options.JobTimeoutMinutes), ct);
        if (id is null) return false;
        var d = await db.MediaDrafts.AsNoTracking().FirstAsync(x => x.Id == id, ct);
        if (d.Attempts > options.MaxAttempts)
        {
            await FinishAsync(db, d.Id, MediaStatus.Failed, "PROCESSING_GAVE_UP", null, ct);
            return true;
        }

        var work = Path.Combine(options.WorkDirectory.Length > 0 ? options.WorkDirectory : Path.GetTempPath(), "gohard-media", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(work);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromMinutes(options.JobTimeoutMinutes));
        try
        {
            if (new DriveInfo(Path.GetPathRoot(Path.GetFullPath(work))!).AvailableFreeSpace < 3 * (d.OriginalBytes ?? MediaOptions.MaxOriginalBytes))
                throw new MediaRejected("NO_WORKER_DISK");
            var input = Path.Combine(work, "input");
            await storage.DownloadAsync(options.StagingBucket, d.OriginalKey, input, MediaOptions.MaxOriginalBytes, timeout.Token);
            var result = await processor.ProcessAsync(input, work, timeout.Token);
            var clipKey = $"processed/{d.Id:N}/{result.Sha256}.mp4";
            var posterKey = $"processed/{d.Id:N}/{result.Sha256}.jpg";
            await storage.UploadAsync(options.StagingBucket, clipKey, result.ClipPath, "video/mp4", null, timeout.Token);
            await storage.UploadAsync(options.StagingBucket, posterKey, result.PosterPath, "image/jpeg", null, timeout.Token);
            await FinishAsync(db, d.Id, MediaStatus.Ready, null, x => x
                .SetProperty(y => y.ProcessedKey, clipKey).SetProperty(y => y.PosterKey, posterKey).SetProperty(y => y.Bytes, result.Bytes)
                .SetProperty(y => y.Sha256, result.Sha256).SetProperty(y => y.DurationSeconds, result.DurationSeconds)
                .SetProperty(y => y.Width, result.Width).SetProperty(y => y.Height, result.Height), ct);
        }
        catch (MediaRejected e) { await FinishAsync(db, d.Id, MediaStatus.Failed, e.Code, null, ct); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { await FinishAsync(db, d.Id, MediaStatus.Failed, "PROCESSING_TIMEOUT", null, ct); }
        catch (OperationCanceledException) { throw; } // shutting down: the lease runs out and another pass takes it again
        catch (Exception e)
        {
            // The type and the store's short error code only: messages can carry keys or URLs.
            log.LogWarning("Processing attempt {Attempt} failed: {Kind} {Code}", d.Attempts, e.GetType().Name, (e as Amazon.Runtime.AmazonServiceException)?.ErrorCode ?? (e.InnerException as Amazon.Runtime.AmazonServiceException)?.ErrorCode);
            // Back in the queue for another attempt (bounded by MaxAttempts), or failed for good.
            await FinishAsync(db, d.Id, d.Attempts >= options.MaxAttempts ? MediaStatus.Failed : MediaStatus.Queued,
                d.Attempts >= options.MaxAttempts ? "PROCESSING_FAILED" : null, null, ct);
        }
        finally
        {
            try { Directory.Delete(work, recursive: true); } catch (IOException) { } catch (UnauthorizedAccessException) { }
        }
        return true;
    }

    /// <summary>Claims one draft for <paramref name="worker"/>: the oldest queued one, or a processing one whose lease ran
    /// out. SKIP LOCKED means a competing worker takes the next one or none, never the same.</summary>
    public static async Task<Guid?> ClaimAsync(GoHardDb db, Guid worker, TimeSpan lease, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var until = now.Add(lease);
        var ids = await db.Database.SqlQuery<Guid>($"""
            UPDATE "MediaDrafts" SET "Status" = 'processing', "LeaseOwner" = {worker}, "LeaseUntilUtc" = {until},
                   "Attempts" = "Attempts" + 1, "Revision" = "Revision" + 1, "UpdatedAtUtc" = {now}
            WHERE "Id" = (SELECT "Id" FROM "MediaDrafts"
                          WHERE "Status" = 'queued' OR ("Status" = 'processing' AND "LeaseUntilUtc" < {now})
                          ORDER BY "UpdatedAtUtc" LIMIT 1 FOR UPDATE SKIP LOCKED)
            RETURNING "Id" AS "Value"
            """).ToListAsync(ct);
        return ids.Count == 0 ? null : ids[0];
    }

    /// <summary>Records the outcome only while this worker still holds the lease; a worker that lost it changes nothing.</summary>
    private async Task FinishAsync(GoHardDb db, Guid id, string status, string? error,
        Action<Microsoft.EntityFrameworkCore.Query.UpdateSettersBuilder<MediaDraft>>? more, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        await db.MediaDrafts.Where(x => x.Id == id && x.LeaseOwner == _me && x.Status == MediaStatus.Processing).ExecuteUpdateAsync(s =>
        {
            s.SetProperty(x => x.Status, status).SetProperty(x => x.Error, error).SetProperty(x => x.LeaseOwner, (Guid?)null)
                .SetProperty(x => x.LeaseUntilUtc, (DateTime?)null).SetProperty(x => x.Revision, x => x.Revision + 1).SetProperty(x => x.UpdatedAtUtc, now);
            more?.Invoke(s);
        }, ct);
    }

    /// <summary>
    /// Retires abandoned work: an upload never completed within a day is cancelled; a cancelled draft's staging files go;
    /// an original is deleted seven days after its video was published. The public bucket is never touched here.
    /// </summary>
    public async Task<int> CleanupAsync(CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<GoHardDb>();
        var now = DateTime.UtcNow;
        await db.MediaDrafts.Where(d => d.Status == MediaStatus.AwaitingUpload && d.UploadExpiresAtUtc < now.AddDays(-1))
            .ExecuteUpdateAsync(s => s.SetProperty(d => d.Status, MediaStatus.Cancelled).SetProperty(d => d.UpdatedAtUtc, now), ct);
        var removed = 0;
        foreach (var d in await db.MediaDrafts.Where(d => d.Status == MediaStatus.Cancelled && (!d.OriginalDeleted || d.ProcessedKey != null)).ToListAsync(ct))
        {
            foreach (var key in new[] { d.OriginalDeleted ? null : d.OriginalKey, d.ProcessedKey, d.PosterKey })
                if (key is not null) { await storage.DeleteAsync(options.StagingBucket, key, ct); removed++; }
            (d.OriginalDeleted, d.ProcessedKey, d.PosterKey) = (true, null, null);
        }
        foreach (var d in await db.MediaDrafts.Where(d => (d.Status == MediaStatus.Published || d.Status == MediaStatus.Withdrawn)
                     && !d.OriginalDeleted && d.PublishedAtUtc < now.AddDays(-7)).ToListAsync(ct))
        {
            await storage.DeleteAsync(options.StagingBucket, d.OriginalKey, ct);
            d.OriginalDeleted = true;
            removed++;
        }
        await db.SaveChangesAsync(ct);
        return removed;
    }
}

/// <summary>
/// FFmpeg/ffprobe (docs/OWNER_EXERCISE_VIDEOS.md › Processing): muted H.264 High, 8-bit yuv420p, MP4 with fast start,
/// at most 720p and 30 fps, aspect ratio and rotation kept, HDR (PQ/HLG) tone-mapped to SDR, metadata stripped. Tools
/// get argument arrays (no shell) and may only read local files.
/// </summary>
public sealed class FfmpegProcessor(MediaOptions options) : IMediaProcessor
{
    public async Task<ProcessedMedia> ProcessAsync(string input, string work, CancellationToken ct)
    {
        var probe = await ProbeAsync(input, ct) ?? throw new MediaRejected("NOT_A_VIDEO");
        var video = probe.Video ?? throw new MediaRejected("NOT_A_VIDEO");
        if (probe.Duration is not { } duration || duration < 0.5) throw new MediaRejected("NOT_A_VIDEO");
        if (duration > MediaOptions.MaxOriginalSeconds + 0.5) throw new MediaRejected("TOO_LONG");
        if (video.Width is <= 0 or > 8192 || video.Height is <= 0 or > 8192) throw new MediaRejected("BAD_DIMENSIONS");
        // Dolby Vision profile 5 has no HDR10/HLG base layer to tone-map from; publishing it would show wrong colours.
        if (video.DolbyVisionProfile == 5) throw new MediaRejected("UNSUPPORTED_HDR");

        var (w, h) = Math.Abs(video.Rotation) % 180 == 90 ? (video.Height, video.Width) : (video.Width, video.Height);
        var (tw, th) = Fit(w, h);
        var filters = new List<string>();
        if (video.Transfer is "smpte2084" or "arib-std-b67")
            filters.Add($"zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv");
        else if (video.Transfer is not (null or "" or "unknown" or "bt709" or "smpte170m" or "bt470bg" or "iec61966-2-1" or "gamma22" or "gamma28" or "smpte240m"))
            throw new MediaRejected("UNSUPPORTED_HDR");
        filters.Add($"scale={tw}:{th}:flags=lanczos");
        if (video.FrameRate > 30.5) filters.Add("fps=30");
        filters.Add("format=yuv420p");
        // Bitrate cap so even 120 s stays inside the 20 MiB phone limit.
        var cap = (long)Math.Min(2_500_000, MediaOptions.MaxClipBytes * 8 * 0.85 / Math.Max(duration, 1));

        var clip = Path.Combine(work, "clip.mp4");
        await RunAsync(options.FfmpegPath, ["-nostdin", "-hide_banner", "-loglevel", "error", "-protocol_whitelist", "file", "-i", input,
            "-map", "0:v:0", "-an", "-sn", "-dn", "-map_metadata", "-1", "-map_chapters", "-1", "-vf", string.Join(',', filters),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-maxrate", cap.ToString(CultureInfo.InvariantCulture),
            "-bufsize", (cap * 2).ToString(CultureInfo.InvariantCulture), "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p",
            "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709", "-movflags", "+faststart",
            "-t", "121", "-f", "mp4", clip], ct);
        var output = await ProbeAsync(clip, ct);
        if (output?.Video is not { Codec: "h264", PixelFormat: "yuv420p" } ov || output.Duration is not { } outDuration) throw new MediaRejected("OUTPUT_INVALID");
        var bytes = new FileInfo(clip).Length;
        if (bytes > MediaOptions.MaxClipBytes) throw new MediaRejected("OUTPUT_TOO_LARGE");

        var poster = Path.Combine(work, "poster.jpg");
        await RunAsync(options.FfmpegPath, ["-nostdin", "-hide_banner", "-loglevel", "error", "-protocol_whitelist", "file",
            "-ss", Math.Min(1.0, outDuration / 3).ToString("0.###", CultureInfo.InvariantCulture), "-i", clip,
            "-frames:v", "1", "-vf", "scale=640:-2", "-q:v", "4", "-f", "image2", poster], ct);
        if (!File.Exists(poster)) throw new MediaRejected("OUTPUT_INVALID");

        string sha;
        await using (var f = File.OpenRead(clip)) sha = Convert.ToHexStringLower(await SHA256.HashDataAsync(f, ct));
        return new(clip, poster, bytes, sha, Math.Round(outDuration, 2), ov.Width, ov.Height);
    }

    /// <summary>The largest even size within 1280 × 720 (either orientation), never larger than the source.</summary>
    public static (int W, int H) Fit(int w, int h)
    {
        var scale = Math.Min(1.0, Math.Min(720.0 / Math.Min(w, h), 1280.0 / Math.Max(w, h)));
        static int Even(double v) => Math.Max(2, (int)Math.Floor(v / 2) * 2);
        return (Even(w * scale), Even(h * scale));
    }

    public sealed record VideoStream(string Codec, int Width, int Height, string? PixelFormat, string? Transfer, double FrameRate, int Rotation, int? DolbyVisionProfile);
    public sealed record Probe(double? Duration, VideoStream? Video);

    public async Task<Probe?> ProbeAsync(string file, CancellationToken ct)
    {
        string json;
        try
        {
            json = await RunAsync(options.FfprobePath, ["-v", "error", "-protocol_whitelist", "file", "-print_format", "json", "-show_format", "-show_streams", file], ct);
        }
        catch (MediaRejected) { return null; }
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        double? Num(JsonElement e, string name) => e.TryGetProperty(name, out var v) && double.TryParse(v.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var d) ? d : null;
        var duration = root.TryGetProperty("format", out var format) ? Num(format, "duration") : null;
        VideoStream? video = null;
        foreach (var s in root.TryGetProperty("streams", out var streams) ? streams.EnumerateArray() : default)
        {
            if (s.GetProperty("codec_type").GetString() != "video" || (s.TryGetProperty("disposition", out var disp) && disp.TryGetProperty("attached_pic", out var ap) && ap.GetInt32() == 1)) continue;
            var rate = s.TryGetProperty("avg_frame_rate", out var r) ? r.GetString() ?? "0/1" : "0/1";
            var parts = rate.Split('/');
            var fps = parts.Length == 2 && double.TryParse(parts[0], CultureInfo.InvariantCulture, out var a) && double.TryParse(parts[1], CultureInfo.InvariantCulture, out var b) && b > 0 ? a / b : 0;
            int rotation = 0, dv = 0;
            if (s.TryGetProperty("side_data_list", out var side))
                foreach (var item in side.EnumerateArray())
                {
                    if (item.TryGetProperty("rotation", out var rot)) rotation = (int)rot.GetDouble();
                    if (item.TryGetProperty("dv_profile", out var p)) dv = p.GetInt32();
                }
            if (s.TryGetProperty("tags", out var tags) && tags.TryGetProperty("rotate", out var rt) && int.TryParse(rt.GetString(), out var tr)) rotation = tr;
            video = new(s.GetProperty("codec_name").GetString() ?? "", s.TryGetProperty("width", out var w) ? w.GetInt32() : 0,
                s.TryGetProperty("height", out var h) ? h.GetInt32() : 0, s.TryGetProperty("pix_fmt", out var pf) ? pf.GetString() : null,
                s.TryGetProperty("color_transfer", out var t) ? t.GetString() : null, fps, rotation, dv == 0 ? null : dv);
            break;
        }
        return new(duration ?? (video is null ? null : Num(root.GetProperty("streams")[0], "duration")), video);
    }

    /// <summary>Runs a tool with an argument list (never a shell), returning stdout. A non-zero exit is a refusal of the
    /// content; the tool's own messages are not passed on (they can contain paths).</summary>
    private static async Task<string> RunAsync(string tool, IReadOnlyList<string> args, CancellationToken ct)
    {
        var psi = new ProcessStartInfo(tool) { RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false };
        foreach (var a in args) psi.ArgumentList.Add(a);
        using var p = Process.Start(psi) ?? throw new InvalidOperationException("tool did not start");
        var stdout = p.StandardOutput.ReadToEndAsync(ct);
        var stderr = p.StandardError.ReadToEndAsync(ct);
        try { await p.WaitForExitAsync(ct); }
        catch (OperationCanceledException) { try { p.Kill(entireProcessTree: true); } catch (InvalidOperationException) { } throw; }
        await stderr;
        if (p.ExitCode != 0) throw new MediaRejected("PROCESSING_REJECTED");
        return await stdout;
    }
}
