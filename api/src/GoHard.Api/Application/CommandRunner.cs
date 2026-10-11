using System.Text.Json;
using GoHard.Api.Domain;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>Wire acknowledgement of one command. Transport failure is separate and never produces one.</summary>
public sealed record CommandAck<T>(Guid OperationId, string Status, int Revision, T? Data, string? Code = null);

public static class Ack
{
    public const string Accepted = "accepted", Conflict = "conflict", Rejected = "rejected";
    public const string PayloadMismatch = "OPERATION_PAYLOAD_MISMATCH", RevisionConflict = "REVISION_CONFLICT",
        NotFound = "NOT_FOUND", Invalid = "VALIDATION_FAILED";
}

/// <summary>Outcome of a command body before it is bound to an operation ID.</summary>
public sealed record Outcome<T>(string Status, int Revision, T? Data, string? Code)
{
    public bool IsNotFound => Code == Ack.NotFound;
}

public static class Outcome
{
    public static Outcome<T> Accepted<T>(int revision, T data) => new(Ack.Accepted, revision, data, null);
    public static Outcome<T> Conflict<T>(string code, int revision = 0, T? data = default) => new(Ack.Conflict, revision, data, code);
    public static Outcome<T> Rejected<T>(string code) => new(Ack.Rejected, 0, default, code);
    public static Outcome<T> NotFound<T>() => new(Ack.Rejected, 0, default, Ack.NotFound);
}

/// <summary>
/// Runs every mutating command the same way: serialize per account, replay a terminal operation before
/// looking at revisions, compare the semantic hash, then execute and record atomically.
/// </summary>
public sealed class CommandRunner(GoHardDb db)
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public async Task<IResult> RunAsync<T>(
        Guid userId, Guid operationId, string kind, object semanticRequest,
        Func<Task<Outcome<T>>> body, CancellationToken ct)
    {
        if (operationId == Guid.Empty)
            return Results.Json(new CommandAck<T>(operationId, Ack.Rejected, 0, default, Ack.Invalid), Json, statusCode: 422);

        var hash = SemanticHash.Compute(kind, semanticRequest);
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // ponytail: one lock per account serializes all of that owner's commands; move to per-aggregate
        // row locks if a single account ever needs concurrent write throughput.
        await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock(hashtextextended({userId.ToString()}, 0))", ct);

        var prior = await db.Operations.AsNoTracking()
            .FirstOrDefaultAsync(o => o.UserId == userId && o.OperationId == operationId, ct);
        if (prior is not null)
        {
            if (prior.RequestHash != hash || prior.Kind != kind)
                return Results.Json(new CommandAck<T>(operationId, Ack.Rejected, 0, default, Ack.PayloadMismatch), Json, statusCode: 409);
            return Results.Content(prior.ResponseJson, "application/json", statusCode: prior.HttpStatus);
        }

        await tx.CreateSavepointAsync("body", ct);
        var outcome = await body();
        if (outcome.IsNotFound) return Results.NotFound(); // foreign and missing look the same; nothing recorded

        if (outcome.Status == Ack.Accepted) await db.SaveChangesAsync(ct);
        else { await tx.RollbackToSavepointAsync("body", ct); db.ChangeTracker.Clear(); }

        var ack = new CommandAck<T>(operationId, outcome.Status, outcome.Revision, outcome.Data, outcome.Code);
        var status = outcome.Status switch { Ack.Accepted => 200, Ack.Conflict => 409, _ => 422 };
        var json = JsonSerializer.Serialize(ack, Json);
        db.Operations.Add(new Operation
        {
            UserId = userId, OperationId = operationId, Kind = kind, RequestHash = hash,
            HttpStatus = status, ResponseJson = json, CreatedAtUtc = DateTime.UtcNow,
        });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Results.Content(json, "application/json", statusCode: status);
    }
}
