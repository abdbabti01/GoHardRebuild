using System.Text.Json;
using System.Text.Json.Serialization;

namespace GoHard.Api.Application;

/// <summary>
/// A whole number that tells "not sent" from "sent as null". A client that predates the field leaves it out and
/// the stored value is kept; an explicit null clears it. The default value is "not sent".
/// </summary>
[JsonConverter(typeof(OptionalIntConverter))]
public readonly record struct OptionalInt(bool IsSet, int? Value)
{
    public int? OrKeep(int? current) => IsSet ? Value : current;
}

public sealed class OptionalIntConverter : JsonConverter<OptionalInt>
{
    public override bool HandleNull => true; // an explicit null must reach Read; a missing property never does

    public override OptionalInt Read(ref Utf8JsonReader reader, Type type, JsonSerializerOptions options) =>
        reader.TokenType == JsonTokenType.Null ? new(true, null) : new(true, reader.GetInt32());

    public override void Write(Utf8JsonWriter writer, OptionalInt value, JsonSerializerOptions options)
    {
        if (value.Value is { } v) writer.WriteNumberValue(v);
        else writer.WriteNullValue();
    }
}
