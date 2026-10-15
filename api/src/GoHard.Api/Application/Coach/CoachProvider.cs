using System.Text.Json;
using System.Text.Json.Nodes;

namespace GoHard.Api.Application.Coach;

/// <summary>One model call: HTTP and parsing only. Limits, retries, validation and what the client sees live in CoachService.</summary>
public interface ICoachProvider
{
    /// <param name="system">Trusted parts, each its own labelled block: instructions, then reviewed references.</param>
    /// <param name="user">Untrusted parts of the one user turn, each its own labelled block; the question last.</param>
    /// <returns>A reply or a typed failure. Throws only for cancellation/timeout and transport errors (no response).</returns>
    Task<CoachProviderResult> AskAsync(IReadOnlyList<string> system, IReadOnlyList<string> user, CancellationToken ct);
}

/// <summary>What the model returned, parsed but not yet trusted: the service filters sources and validates the proposal.</summary>
public sealed record CoachModelReply(string Answer, List<string> Sources, JsonElement? Proposal)
{
    /// <summary>
    /// The structured output, or null when it is empty or does not follow <see cref="CoachReplySchema"/>: answer is a
    /// string, sources an array of strings, proposal present (its content is validated later by the service).
    /// Throws JsonException when the text is not JSON.
    /// </summary>
    public static CoachModelReply? FromJson(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var r = JsonDocument.Parse(text).RootElement.Clone();
        if (r.ValueKind != JsonValueKind.Object || !r.TryGetProperty("answer", out var a) || a.ValueKind != JsonValueKind.String ||
            !r.TryGetProperty("sources", out var s) || s.ValueKind != JsonValueKind.Array || s.EnumerateArray().Any(x => x.ValueKind != JsonValueKind.String) ||
            !r.TryGetProperty("proposal", out var p)) return null;
        return new(a.GetString()!, [.. s.EnumerateArray().Select(x => x.GetString()!)], p.ValueKind == JsonValueKind.Null ? null : p);
    }
}

public enum CoachFailure
{
    /// <summary>401/403: the server's key is wrong or lacks access.</summary>
    Credentials,
    /// <summary>404 or a model error code: the configured model is unknown or not available to this key. Never substituted.</summary>
    Model,
    /// <summary>Any other 4xx: the request itself was refused.</summary>
    Rejected,
    /// <summary>429: the provider's rate limit.</summary>
    RateLimited,
    /// <summary>498/503/529: provider capacity or overload.</summary>
    Overloaded,
    /// <summary>Other 5xx.</summary>
    ServerError,
    /// <summary>200 but cut off, refused, empty, not JSON or not the schema.</summary>
    BadReply,
}

/// <param name="RetryAfter">Set only for failures worth one retry (rate limit, overload, 5xx): the provider's retry-after,
/// or a short default for 5xx without one.</param>
public sealed record CoachProviderResult(CoachModelReply? Reply, CoachFailure? Failure = null, TimeSpan? RetryAfter = null)
{
    private static readonly TimeSpan ServerErrorPause = TimeSpan.FromMilliseconds(500);

    /// <summary>Client-facing: the provider is busy (COACH_BUSY) rather than unavailable.</summary>
    public bool Busy => Failure is CoachFailure.RateLimited or CoachFailure.Overloaded;

    public static CoachProviderResult Bad => new(null, CoachFailure.BadReply);

    /// <summary>A non-success HTTP response, classified. <paramref name="errorCode"/> is the provider's error type/code, if any.</summary>
    public static CoachProviderResult FromStatus(HttpResponseMessage response, string? errorCode, TimeProvider time)
    {
        var after = response.Headers.RetryAfter is { } h ? h.Delta ?? (h.Date - time.GetUtcNow()) : null;
        if (after < TimeSpan.Zero) after = TimeSpan.Zero;
        var failure = (int)response.StatusCode switch
        {
            401 or 403 => CoachFailure.Credentials,
            404 => CoachFailure.Model,
            429 => CoachFailure.RateLimited,
            498 or 503 or 529 => CoachFailure.Overloaded,
            >= 500 => CoachFailure.ServerError,
            _ when errorCode?.Contains("model", StringComparison.OrdinalIgnoreCase) == true => CoachFailure.Model,   // e.g. model_decommissioned
            _ => CoachFailure.Rejected,
        };
        var retry = failure switch
        {
            CoachFailure.RateLimited => after,   // no retry-after: no retry
            CoachFailure.Overloaded or CoachFailure.ServerError => after ?? ServerErrorPause,
            _ => null,
        };
        return new(null, failure, retry);
    }

    /// <summary>"type" and "code" of an OpenAI- or Anthropic-style {"error":{…}} body, for logs only. Never the message.</summary>
    public static string? ErrorCode(string body)
    {
        try
        {
            var e = JsonDocument.Parse(body).RootElement.GetProperty("error");
            string? Get(string n) => e.TryGetProperty(n, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
            return string.Join("/", new[] { Get("type"), Get("code") }.OfType<string>()) is { Length: > 0 } s ? s : null;
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException) { return null; }
    }
}

/// <summary>
/// The structured output both providers are held to. Written for strict mode: every property required, every object
/// additionalProperties:false, nullable via anyOf with {"type":"null"}, no numeric or length constraints (the server
/// checks those). Valid for Anthropic structured outputs and Groq strict json_schema alike.
/// </summary>
public static class CoachReplySchema
{
    private static JsonNode Null => new JsonObject { ["type"] = "null" };
    private static JsonNode Maybe(string type) => new JsonObject { ["anyOf"] = new JsonArray(new JsonObject { ["type"] = type }, Null) };

    public static JsonObject Create() => new()
    {
        ["type"] = "object", ["additionalProperties"] = false, ["required"] = new JsonArray("answer", "sources", "proposal"),
        ["properties"] = new JsonObject
        {
            ["answer"] = new JsonObject { ["type"] = "string" },
            ["sources"] = new JsonObject { ["type"] = "array", ["items"] = new JsonObject { ["type"] = "string" } },
            ["proposal"] = new JsonObject
            {
                ["anyOf"] = new JsonArray(Null, new JsonObject
                {
                    ["type"] = "object", ["additionalProperties"] = false, ["required"] = new JsonArray("summary", "scope", "operations"),
                    ["properties"] = new JsonObject
                    {
                        ["summary"] = new JsonObject { ["type"] = "string" },
                        ["scope"] = new JsonObject { ["type"] = "string", ["enum"] = new JsonArray("draft") },
                        ["operations"] = new JsonObject
                        {
                            ["type"] = "array",
                            ["items"] = new JsonObject
                            {
                                ["type"] = "object", ["additionalProperties"] = false,
                                ["required"] = new JsonArray("op", "workoutId", "occurrenceKey", "catalogKey", "targetSets", "targetRepsMin", "targetRepsMax", "targetDurationSeconds", "restSeconds"),
                                ["properties"] = new JsonObject
                                {
                                    ["op"] = new JsonObject { ["type"] = "string", ["enum"] = new JsonArray("replaceExercise", "setPrescription", "addExercise", "removeExercise") },
                                    ["workoutId"] = new JsonObject { ["type"] = "string" },
                                    ["occurrenceKey"] = Maybe("string"), ["catalogKey"] = Maybe("string"),
                                    ["targetSets"] = Maybe("integer"), ["targetRepsMin"] = Maybe("integer"), ["targetRepsMax"] = Maybe("integer"),
                                    ["targetDurationSeconds"] = Maybe("integer"), ["restSeconds"] = Maybe("integer"),
                                },
                            },
                        },
                    },
                }),
            },
        },
    };
}
