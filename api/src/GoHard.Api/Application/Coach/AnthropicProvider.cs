using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GoHard.Api.Application.Coach;

/// <summary>
/// HTTP and parsing only, for the Anthropic Messages API (POST /v1/messages). The key travels in the x-api-key
/// header, is never logged and never reaches a client. The model gets no tools: a JSON-schema output format makes it
/// return one answer, cited source IDs and at most one proposal. Failures are typed and logged without the key.
/// </summary>
public sealed class AnthropicProvider(HttpClient http, CoachOptions options, ILogger<AnthropicProvider> log, TimeProvider? time = null) : ICoachProvider
{
    public const string DefaultModel = "claude-haiku-5-5";

    public async Task<CoachProviderResult> AskAsync(IReadOnlyList<string> system, IReadOnlyList<string> user, CancellationToken ct)
    {
        var body = new JsonObject
        {
            ["model"] = options.ModelId,
            ["max_tokens"] = options.MaxTokens,
            ["system"] = new JsonArray([.. system.Select(Block)]),
            ["messages"] = new JsonArray(new JsonObject { ["role"] = "user", ["content"] = new JsonArray([.. user.Select(Block)]) }),
            // Short grounded answers: low effort keeps latency and cost down; thinking stays adaptive.
            ["output_config"] = new JsonObject { ["effort"] = options.Effort, ["format"] = new JsonObject { ["type"] = "json_schema", ["schema"] = CoachReplySchema.Create() } },
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
            var code = CoachProviderResult.ErrorCode(text);
            log.LogWarning("Anthropic answered HTTP {Status} ({Type})", (int)response.StatusCode, code);
            return CoachProviderResult.FromStatus(response, code, time ?? TimeProvider.System);
        }
        return Parse(text, log) is { } reply ? new(reply) : CoachProviderResult.Bad;
    }

    private static JsonObject Block(string text) => new() { ["type"] = "text", ["text"] = text };

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
            return json.ValueKind == JsonValueKind.Object ? CoachModelReply.FromJson(json.GetProperty("text").GetString()) : null;
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            log.LogWarning("Anthropic response could not be read ({Reason})", ex.GetType().Name);
            return null;
        }
    }
}
