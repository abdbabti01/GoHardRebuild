using System.Security.Claims;
using GoHard.Api.Application;
using GoHard.Api.Application.ExerciseMedia;

namespace GoHard.Api.Endpoints;

/// <summary>Shared exercise demonstrations (docs/OWNER_EXERCISE_VIDEOS.md): a public catalogue for every signed-in
/// person, and management for the one configured owner. To anyone else management does not exist (404).</summary>
public static class MediaEndpoints
{
    public static IServiceCollection AddExerciseMedia(this IServiceCollection services, IConfiguration config)
    {
        var options = config.GetSection("ExerciseMedia").Get<MediaOptions>() ?? new();
        services.AddSingleton(options);
        services.AddScoped<MediaService>();
        if (!options.StorageConfigured) return services;
        services.AddSingleton<IMediaStorage>(new S3MediaStorage(options));
        services.AddSingleton<IMediaProcessor, FfmpegProcessor>();
        services.AddSingleton<MediaWorker>();
        if (options.WorkerEnabled) services.AddHostedService(sp => sp.GetRequiredService<MediaWorker>());
        return services;
    }

    private static Guid UserId(this ClaimsPrincipal p) => Guid.Parse(p.FindFirstValue("sub")!);
    private static IResult Code(string code, int status) => Results.Json(new { code }, statusCode: status);

    public static void MapMediaEndpoints(this RouteGroupBuilder me)
    {
        var media = me.MapGroup("/exercise-media");
        // Whether this account may manage, and whether the server is set up for it. Says nothing about who the owner is.
        media.MapGet("/access", (ClaimsPrincipal u, MediaService s) => Results.Ok(s.Access(u)));
        // Published demonstrations only. The ETag is the catalogue revision, so an unchanged catalogue costs a 304.
        media.MapGet("/catalog", async (HttpContext http, MediaService s, CancellationToken ct) =>
        {
            var etag = $"\"m{await s.RevisionAsync(ct)}\"";
            http.Response.Headers.ETag = etag;
            http.Response.Headers.CacheControl = "private, no-cache";
            if (http.Request.Headers.IfNoneMatch.ToString() == etag) return Results.StatusCode(304);
            return Results.Json(await s.CatalogAsync(ct), CommandRunner.Json);
        });

        var manage = media.MapGroup("/manage").AddEndpointFilter(async (ctx, next) =>
        {
            var s = ctx.HttpContext.RequestServices.GetRequiredService<MediaService>();
            if (!s.IsOwner(ctx.HttpContext.User)) return Results.NotFound();
            if (!s.Ready && ctx.HttpContext.Request.Method != "GET") return Code("STORAGE_NOT_CONFIGURED", 503);
            return await next(ctx);
        });
        manage.MapGet("", async (MediaService s, CancellationToken ct) => Results.Json(await s.ListAsync(ct), CommandRunner.Json));
        manage.MapPost("/drafts", (MediaDraftCreate r, ClaimsPrincipal u, CommandRunner run, MediaService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "media.draft", r, () => s.CreateAsync(u.UserId(), r, ct), ct));
        // Links are answers, not commands: a signed URL is never written to the operation log.
        manage.MapPost("/drafts/{id:guid}/upload-url", async (Guid id, MediaService s, CancellationToken ct) =>
            await s.UploadLinkAsync(id, ct) switch
            {
                ({ } link, _) => Results.Json(link, CommandRunner.Json),
                (_, Ack.NotFound) => Results.NotFound(),
                (_, var error) => Code(error!, 409),
            });
        manage.MapGet("/drafts/{id:guid}/preview", async (Guid id, MediaService s, CancellationToken ct) =>
            await s.PreviewAsync(id, ct) switch
            {
                ({ } preview, _) => Results.Json(preview, CommandRunner.Json),
                (_, Ack.NotFound) => Results.NotFound(),
                (_, var error) => Code(error!, 409),
            });
        manage.MapPost("/drafts/{id:guid}/complete", (Guid id, OperationOnly r, ClaimsPrincipal u, CommandRunner run, MediaService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "media.complete", new { id }, () => s.CompleteAsync(id, ct), ct));
        manage.MapPut("/drafts/{id:guid}/details", (Guid id, MediaDetails r, ClaimsPrincipal u, CommandRunner run, MediaService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "media.details", new { id, r }, () => s.DetailsAsync(id, r, ct), ct));
        manage.MapPost("/drafts/{id:guid}/retry", (Guid id, MediaRevisionCommand r, ClaimsPrincipal u, CommandRunner run, MediaService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "media.retry", new { id, r }, () => s.RetryAsync(id, r, ct), ct));
        manage.MapPost("/drafts/{id:guid}/publish", (Guid id, MediaRevisionCommand r, ClaimsPrincipal u, CommandRunner run, MediaService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "media.publish", new { id, r }, () => s.PublishAsync(id, r, ct), ct));
        manage.MapPost("/drafts/{id:guid}/delete", (Guid id, MediaRevisionCommand r, ClaimsPrincipal u, CommandRunner run, MediaService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "media.delete", new { id, r }, () => s.DeleteAsync(id, r, ct), ct));
        manage.MapPost("/keys/{key}/unpublish", (string key, MediaUnpublish r, ClaimsPrincipal u, CommandRunner run, MediaService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "media.unpublish", new { key, r }, () => s.UnpublishAsync(key, r, ct), ct));
    }
}
