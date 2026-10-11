using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GoHard.Api.Domain;

/// <summary>
/// Versioned hash of what a command means: kind + request with sorted keys and invariant numbers.
/// Field order, whitespace and 1 vs 1.0 do not change it; any changed value does.
/// </summary>
public static class SemanticHash
{
    public const string Version = "v1";
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    public static string Compute(string kind, object request)
    {
        var node = request as JsonNode ?? JsonSerializer.SerializeToNode(request, Web);
        var sb = new StringBuilder(Version).Append('|').Append(kind).Append('|');
        Write(node, sb);
        return Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(sb.ToString())));
    }

    private static void Write(JsonNode? node, StringBuilder sb)
    {
        switch (node)
        {
            case null: sb.Append("null"); break;
            case JsonObject o:
                sb.Append('{');
                foreach (var (k, v) in o.OrderBy(p => p.Key, StringComparer.Ordinal))
                { sb.Append(JsonSerializer.Serialize(k)).Append(':'); Write(v, sb); sb.Append(','); }
                sb.Append('}');
                break;
            case JsonArray a:
                sb.Append('[');
                foreach (var v in a) { Write(v, sb); sb.Append(','); }
                sb.Append(']');
                break;
            case JsonValue v when v.GetValueKind() == JsonValueKind.Number:
                sb.Append(decimal.Parse(v.ToJsonString(), NumberStyles.Float, CultureInfo.InvariantCulture)
                    .ToString("G29", CultureInfo.InvariantCulture));
                break;
            default: sb.Append(node.ToJsonString()); break;
        }
    }
}
