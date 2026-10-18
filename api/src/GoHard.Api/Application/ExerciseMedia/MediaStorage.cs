using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;

namespace GoHard.Api.Application.ExerciseMedia;

/// <summary>GOHARD_ExerciseMedia__* (docs/OWNER_EXERCISE_VIDEOS.md). Missing or invalid owner/storage settings turn
/// management off for everyone; the public catalogue still answers.</summary>
public sealed class MediaOptions
{
    /// <summary>The one account allowed to manage shared demonstrations: its user ID from GET /api/v1/me.</summary>
    public string OwnerUserId { get; set; } = "";
    /// <summary>S3 API endpoint: https://&lt;account&gt;.r2.cloudflarestorage.com for R2, http://localhost:9000 for MinIO.</summary>
    public string ServiceUrl { get; set; } = "";
    /// <summary>Optional, development only: the host the phone uses to reach the store when it differs from the
    /// API's (an emulator reaching MinIO at 10.0.2.2). Only signing uses it; nothing connects to it.</summary>
    public string PresignServiceUrl { get; set; } = "";
    public string Region { get; set; } = "auto";
    public string AccessKeyId { get; set; } = "";
    public string SecretAccessKey { get; set; } = "";
    /// <summary>Private: originals and unpublished processed files.</summary>
    public string StagingBucket { get; set; } = "";
    /// <summary>Public, read-only through <see cref="PublicBaseUrl"/>: published clips and posters only.</summary>
    public string PublicBucket { get; set; } = "";
    /// <summary>The approved media origin the app trusts, e.g. https://media.example.com (an R2 custom domain).</summary>
    public string PublicBaseUrl { get; set; } = "";
    /// <summary>Run the processing worker in this process. Turn it off here and on in a separate service to split them.</summary>
    public bool WorkerEnabled { get; set; } = true;
    public string FfmpegPath { get; set; } = "ffmpeg";
    public string FfprobePath { get; set; } = "ffprobe";
    public string WorkDirectory { get; set; } = "";
    public int JobTimeoutMinutes { get; set; } = 15;
    public int MaxAttempts { get; set; } = 3;
    public int UploadUrlMinutes { get; set; } = 30;
    public int PreviewUrlMinutes { get; set; } = 10;

    public const long MaxOriginalBytes = 200L * 1024 * 1024;
    public const double MaxOriginalSeconds = 120;
    public const long MaxClipBytes = 20L * 1024 * 1024;

    public Guid? Owner => Guid.TryParse(OwnerUserId, out var id) && id != Guid.Empty ? id : null;
    public bool StorageConfigured =>
        Uri.TryCreate(ServiceUrl, UriKind.Absolute, out _) && AccessKeyId.Length > 0 && SecretAccessKey.Length > 0 &&
        StagingBucket.Length > 0 && PublicBucket.Length > 0 && StagingBucket != PublicBucket &&
        Uri.TryCreate(PublicBaseUrl, UriKind.Absolute, out _);
    public string PublicUrl(string key) => $"{PublicBaseUrl.TrimEnd('/')}/{key}";
}

public sealed record StoredObject(long Bytes, string? ContentType);

/// <summary>The object store as this feature uses it. Write credentials never leave the server; the phone only ever
/// receives one short-lived URL for one object.</summary>
public interface IMediaStorage
{
    Uri PresignPut(string bucket, string key, string contentType, TimeSpan expiry);
    Uri PresignGet(string bucket, string key, TimeSpan expiry);
    Task<StoredObject?> HeadAsync(string bucket, string key, CancellationToken ct);
    /// <summary>Streams the object to <paramref name="path"/>, refusing more than <paramref name="maxBytes"/>.</summary>
    Task DownloadAsync(string bucket, string key, string path, long maxBytes, CancellationToken ct);
    Task UploadAsync(string bucket, string key, string path, string contentType, string? cacheControl, CancellationToken ct);
    Task CopyAsync(string fromBucket, string fromKey, string toBucket, string toKey, string contentType, string? cacheControl, CancellationToken ct);
    Task DeleteAsync(string bucket, string key, CancellationToken ct);
}

/// <summary>S3 protocol: Cloudflare R2 in production, MinIO locally.</summary>
public sealed class S3MediaStorage : IMediaStorage, IDisposable
{
    private readonly AmazonS3Client _s3, _signer;
    private readonly bool _https;

    public S3MediaStorage(MediaOptions o)
    {
        AmazonS3Client Client(string url) => new(new BasicAWSCredentials(o.AccessKeyId, o.SecretAccessKey), new AmazonS3Config
        {
            ServiceURL = url, ForcePathStyle = true, AuthenticationRegion = o.Region,
            // R2 rejects the SDK's default extra checksums on some calls; send them only when an operation needs them.
            RequestChecksumCalculation = RequestChecksumCalculation.WHEN_REQUIRED,
            ResponseChecksumValidation = ResponseChecksumValidation.WHEN_REQUIRED,
        });
        _s3 = Client(o.ServiceUrl);
        _https = o.ServiceUrl.StartsWith("https://", StringComparison.Ordinal);
        _signer = o.PresignServiceUrl.Length > 0 ? Client(o.PresignServiceUrl) : _s3;
    }

    private Uri Presign(string bucket, string key, HttpVerb verb, string? contentType, TimeSpan expiry) => new(_signer.GetPreSignedURL(new GetPreSignedUrlRequest
    {
        BucketName = bucket, Key = key, Verb = verb, ContentType = contentType, Expires = DateTime.UtcNow.Add(expiry),
        Protocol = _signer.Config.ServiceURL.StartsWith("http://", StringComparison.Ordinal) ? Protocol.HTTP : Protocol.HTTPS,
    }));

    public Uri PresignPut(string bucket, string key, string contentType, TimeSpan expiry) => Presign(bucket, key, HttpVerb.PUT, contentType, expiry);
    public Uri PresignGet(string bucket, string key, TimeSpan expiry) => Presign(bucket, key, HttpVerb.GET, null, expiry);

    public async Task<StoredObject?> HeadAsync(string bucket, string key, CancellationToken ct)
    {
        try
        {
            var r = await _s3.GetObjectMetadataAsync(bucket, key, ct);
            return new(r.ContentLength, r.Headers.ContentType);
        }
        catch (AmazonS3Exception e) when (e.StatusCode == System.Net.HttpStatusCode.NotFound) { return null; }
    }

    public async Task DownloadAsync(string bucket, string key, string path, long maxBytes, CancellationToken ct)
    {
        using var r = await _s3.GetObjectAsync(bucket, key, ct);
        if (r.ContentLength > maxBytes) throw new MediaRejected("TOO_LARGE");
        await using var file = File.Create(path);
        var buffer = new byte[81920];
        long total = 0;
        int n;
        while ((n = await r.ResponseStream.ReadAsync(buffer, ct)) > 0)
        {
            total += n;
            if (total > maxBytes) throw new MediaRejected("TOO_LARGE");
            await file.WriteAsync(buffer.AsMemory(0, n), ct);
        }
    }

    public Task UploadAsync(string bucket, string key, string path, string contentType, string? cacheControl, CancellationToken ct)
    {
        // Unsigned payloads (no second read of the file to hash it) are only allowed over HTTPS, as with R2.
        var request = new PutObjectRequest { BucketName = bucket, Key = key, FilePath = path, ContentType = contentType, DisablePayloadSigning = _https,
            // One plainly signed body, not aws-chunked streaming: accepted by R2 and by local S3-compatible stores alike.
            UseChunkEncoding = false };
        if (cacheControl is not null) request.Headers.CacheControl = cacheControl;
        return _s3.PutObjectAsync(request, ct);
    }

    public Task CopyAsync(string fromBucket, string fromKey, string toBucket, string toKey, string contentType, string? cacheControl, CancellationToken ct)
    {
        var request = new CopyObjectRequest
        {
            SourceBucket = fromBucket, SourceKey = fromKey, DestinationBucket = toBucket, DestinationKey = toKey,
            ContentType = contentType, MetadataDirective = S3MetadataDirective.REPLACE,
        };
        if (cacheControl is not null) request.Headers.CacheControl = cacheControl;
        return _s3.CopyObjectAsync(request, ct);
    }

    public Task DeleteAsync(string bucket, string key, CancellationToken ct) => _s3.DeleteObjectAsync(bucket, key, ct);

    public void Dispose()
    {
        _s3.Dispose();
        if (!ReferenceEquals(_signer, _s3)) _signer.Dispose();
    }
}

/// <summary>Content the pipeline refuses, with a short code the owner sees (never tool output).</summary>
public sealed class MediaRejected(string code) : Exception(code)
{
    public string Code => Message;
}
