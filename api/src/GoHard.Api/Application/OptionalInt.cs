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

/// <summary>The same three cases for any nullable value (<c>Optional&lt;decimal?&gt;</c>, <c>Optional&lt;string?&gt;</c>).</summary>
[JsonConverter(typeof(OptionalConverterFactory))]
public readonly record struct Optional<T>(bool IsSet, T? Value)
{
    public T? OrKeep(T? current) => IsSet ? Value : current;
}

public sealed class OptionalConverterFactory : JsonConverterFactory
{
    public override bool CanConvert(Type type) => type.IsGenericType && type.GetGenericTypeDefinition() == typeof(Optional<>);
    public override JsonConverter CreateConverter(Type type, JsonSerializerOptions options) =>
        (JsonConverter)Activator.CreateInstance(typeof(OptionalConverter<>).MakeGenericType(type.GetGenericArguments()[0]))!;
}

public sealed class OptionalConverter<T> : JsonConverter<Optional<T>>
{
    public override bool HandleNull => true;
    public override Optional<T> Read(ref Utf8JsonReader reader, Type type, JsonSerializerOptions options) =>
        new(true, reader.TokenType == JsonTokenType.Null ? default : JsonSerializer.Deserialize<T>(ref reader, options));
    public override void Write(Utf8JsonWriter writer, Optional<T> value, JsonSerializerOptions options) => JsonSerializer.Serialize(writer, value.Value, options);
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
