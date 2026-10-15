using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GoHard.Api.Application.Coach;

/// <summary>What the model returned, parsed but not yet trusted: the service filters sources and validates the proposal.</summary>
public sealed record CoachModelReply(string Answer, List<string> Sources, JsonElement? Proposal);

/// <summary>
/// HTTP and parsing only, for the Anthropic Messages API (POST /v1/messages). The key travels in the x-api-key
/// header, is never logged and never reaches a client. The model gets no tools: a JSON-schema output format makes it
/// return one answer, cited source IDs and at most one proposal. Any failure is null, logged without the key.
/// </summary>
public sealed class AnthropicProvider(HttpClient http, CoachOptions options, ILogger<AnthropicProvider> log)
{
    private static readonly JsonNode Nullable = JsonNode.Parse("""{"type":"null"}""")!;
    private static JsonNode Maybe(string type) => new JsonObject { ["anyOf"] = new JsonArray(new JsonObject { ["type"] = type }, Nullable.DeepClone()) };

    /// <summary>No numeric or length constraints: structured outputs do not support them, so the server checks those.</summary>
    internal static readonly JsonObject Schema = new()
    {
        ["type"] = "object", ["additionalProperties"] = false, ["required"] = new JsonArray("answer", "sources", "proposal"),
        ["properties"] = new JsonObject
        {
            ["answer"] = new JsonObject { ["type"] = "string" },
            ["sources"] = new JsonObject { ["type"] = "array", ["items"] = new JsonObject { ["type"] = "string" } },
            ["proposal"] = new JsonObject
            {
                ["anyOf"] = new JsonArray(Nullable.DeepClone(), new JsonObject
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

    /// <param name="system">Trusted parts, each its own labelled block: instructions, then reviewed references.</param>
    /// <param name="user">Untrusted parts of the one user turn, each its own labelled block; the question last.</param>
    public async Task<CoachModelReply?> AskAsync(IReadOnlyList<string> system, IReadOnlyList<string> user, CancellationToken ct)
    {
        var body = new JsonObject
        {
            ["model"] = options.Model,
            ["max_tokens"] = options.MaxTokens,
            ["system"] = new JsonArray([.. system.Select(Block)]),
            ["messages"] = new JsonArray(new JsonObject { ["role"] = "user", ["content"] = new JsonArray([.. user.Select(Block)]) }),
            // Short grounded answers: low effort keeps latency and cost down; thinking stays adaptive.
            ["output_config"] = new JsonObject { ["effort"] = options.Effort, ["format"] = new JsonObject { ["type"] = "json_schema", ["schema"] = Schema.DeepClone() } },
        };
        using var request = new HttpRequestMessage(HttpMethod.Post, "v1/messages") { Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json") };
        request.Headers.Add("x-api-key", options.AnthropicApiKey!.Trim());
        request.Headers.Add("anthropic-version", "2023-06-01");
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await http.SendAsync(request, ct);
        var text = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
        {
            // The provider's error type only (e.g. authentication_error, overloaded_error): never the request, never the key.
            log.LogWarning("Anthropic answered HTTP {Status} ({Type})", (int)response.StatusCode, ErrorType(text));
            return null;
        }
        return Parse(text, log);
    }

    private static JsonObject Block(string text) => new() { ["type"] = "text", ["text"] = text };

    private static string? ErrorType(string body)
    {
        try { return JsonDocument.Parse(body).RootElement.GetProperty("error").GetProperty("type").GetString(); }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException) { return null; }
    }

    /// <summary>The structured answer from a Messages API response, or null when it is not a complete, well-formed one.</summary>
    public static CoachModelReply? Parse(string responseBody, ILogger log)
    {
        try
        {
            var root = JsonDocument.Parse(responseBody).RootElement;
            var stop = root.TryGetProperty("stop_reason", out var s) ? s.GetString() : null;
            if (stop != "end_turn")
            {
                // refusal, max_tokens (the JSON may be cut off) or anything unexpected: no answer rather than a partial one.
                log.LogWarning("Anthropic stopped with {StopReason}", stop);
                return null;
            }
            var json = root.GetProperty("content").EnumerateArray().FirstOrDefault(b => b.GetProperty("type").GetString() == "text");
            if (json.ValueKind != JsonValueKind.Object) return null;
            var reply = JsonDocument.Parse(json.GetProperty("text").GetString()!).RootElement.Clone();
            if (!reply.TryGetProperty("answer", out var a) || a.ValueKind != JsonValueKind.String) return null;
            var sources = reply.TryGetProperty("sources", out var src) && src.ValueKind == JsonValueKind.Array
                ? src.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.String).Select(x => x.GetString()!).ToList() : [];
            JsonElement? proposal = reply.TryGetProperty("proposal", out var p) && p.ValueKind != JsonValueKind.Null ? p : null;
            return new(a.GetString()!, sources, proposal);
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            log.LogWarning("Anthropic response could not be read ({Reason})", ex.GetType().Name);
            return null;
        }
    }
}
