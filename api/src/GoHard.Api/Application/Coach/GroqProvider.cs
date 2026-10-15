using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GoHard.Api.Application.Coach;

/// <summary>
/// HTTP and parsing only, for Groq's OpenAI-compatible Chat Completions (POST {GroqBaseUrl}/chat/completions).
/// The key travels as Authorization: Bearer, is never logged and never reaches a client. The model id is sent
/// verbatim; there is no fallback model.
///
/// Groq docs relied on (read 15 Oct 2026):
/// - https://console.groq.com/docs/openai : base URL https://api.groq.com/openai/v1; logprobs, logit_bias,
///   top_logprobs, messages[].name return 400 (none sent).
/// - https://console.groq.com/docs/api-reference : Authorization: Bearer; max_completion_tokens (max_tokens deprecated);
///   reasoning_effort low|medium|high for openai/gpt-oss-120b (default medium); include_reasoning and reasoning_format
///   are mutually exclusive; response_format {type:"json_schema", json_schema:{…}}.
/// - https://console.groq.com/docs/structured-outputs : strict:true supported on openai/gpt-oss-120b; strict needs every
///   property in "required" and additionalProperties:false on every object; nullable via ["t","null"] or anyOf with
///   {"type":"null"}; supported: string, number, boolean, integer, object, array, enum, anyOf. Streaming and tool use
///   are not supported with Structured Outputs (neither is sent).
/// - https://console.groq.com/docs/reasoning : gpt-oss does not support reasoning_format; use include_reasoning;
///   reasoning arrives in message.reasoning, the answer in message.content.
/// - https://console.groq.com/docs/rate-limits : 429 with retry-after in seconds (set only on 429).
/// - https://console.groq.com/docs/errors : {"error":{"message","type"}}; 401 bad key, 403 permission, 404 not found,
///   498 flex capacity exceeded, 500/502/503 server side.
/// - https://console.groq.com/docs/models : openai/gpt-oss-120b is a production model, 65,536 max completion tokens.
/// </summary>
public sealed class GroqProvider(HttpClient http, CoachOptions options, ILogger<GroqProvider> log, TimeProvider? time = null) : ICoachProvider
{
    public const string DefaultModel = "openai/gpt-oss-120b";

    public async Task<CoachProviderResult> AskAsync(IReadOnlyList<string> system, IReadOnlyList<string> user, CancellationToken ct)
    {
        var body = new JsonObject
        {
            ["model"] = options.ModelId,
            ["messages"] = new JsonArray(
                new JsonObject { ["role"] = "system", ["content"] = string.Join("\n\n", system) },
                new JsonObject { ["role"] = "user", ["content"] = string.Join("\n\n", user) }),
            ["response_format"] = new JsonObject
            {
                ["type"] = "json_schema",
                ["json_schema"] = new JsonObject { ["name"] = "coach_reply", ["strict"] = true, ["schema"] = CoachReplySchema.Create() },
            },
            // Reasoning tokens count toward this bound; a cut-off reply (finish_reason "length") is a failure.
            ["max_completion_tokens"] = options.MaxTokens,
            ["reasoning_effort"] = options.Effort,
            ["include_reasoning"] = false,
        };
        using var request = new HttpRequestMessage(HttpMethod.Post, "chat/completions") { Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json") };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", options.GroqApiKey!.Trim());
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await http.SendAsync(request, ct);
        var text = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
        {
            // Status and the provider's error type/code only: never the message, the request or the key.
            var code = CoachProviderResult.ErrorCode(text);
            log.LogWarning("Groq answered HTTP {Status} ({Type})", (int)response.StatusCode, code);
            return CoachProviderResult.FromStatus(response, code, time ?? TimeProvider.System);
        }
        return Parse(text, log) is { } reply ? new(reply) : CoachProviderResult.Bad;
    }

    /// <summary>The structured answer from a Chat Completions response, or null when it is not a complete, well-formed one.</summary>
    public static CoachModelReply? Parse(string responseBody, ILogger log)
    {
        try
        {
            var choice = JsonDocument.Parse(responseBody).RootElement.GetProperty("choices")[0];
            var finish = choice.TryGetProperty("finish_reason", out var f) ? f.GetString() : null;
            if (finish != "stop")
            {
                // length (the JSON may be cut off), tool_calls or anything unexpected: no answer rather than a partial one.
                log.LogWarning("Groq stopped with {FinishReason}", finish);
                return null;
            }
            var message = choice.GetProperty("message");
            if (message.TryGetProperty("refusal", out var refusal) && refusal.ValueKind != JsonValueKind.Null)
            {
                log.LogWarning("Groq refused");
                return null;
            }
            var reply = CoachModelReply.FromJson(message.TryGetProperty("content", out var c) && c.ValueKind == JsonValueKind.String ? c.GetString() : null);
            if (reply is null) log.LogWarning("Groq reply was empty or did not follow the schema");
            return reply;
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException or IndexOutOfRangeException)
        {
            log.LogWarning("Groq response could not be read ({Reason})", ex.GetType().Name);
            return null;
        }
    }
}
