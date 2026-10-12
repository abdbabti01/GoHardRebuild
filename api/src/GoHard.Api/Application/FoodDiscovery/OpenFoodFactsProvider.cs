using System.Globalization;
using System.Net;
using System.Text.Json;

namespace GoHard.Api.Application.FoodDiscovery;

/// <summary>
/// Packaged products by barcode from Open Food Facts, API v3.6 (the documented current version; full-text search is
/// not part of it, so this adapter does lookup only). Reads need no account, only an identifying User-Agent.
/// Data: Open Database License. Images: CC BY-SA, credited wherever one is shown.
/// </summary>
public sealed class OpenFoodFactsProvider(HttpClient http)
{
    public const string Fields = "code,product_name,generic_name,brands,quantity,serving_size,serving_quantity,serving_quantity_unit,nutrition,image_front_small_url,lang,rev";
    private const decimal KilojoulesPerKilocalorie = 4.184m;

    public async Task<Lookup<FoodItem>> ProductAsync(string barcode, CancellationToken ct)
    {
        using var response = await http.GetAsync($"api/v3.6/product/{barcode}.json?fields={Fields}", ct);
        if (response.StatusCode == HttpStatusCode.TooManyRequests) return Lookup<FoodItem>.Fail(LookupStatus.RateLimited);
        // v3 answers an unknown code with 404 and a JSON body; anything else that is not success is the provider's trouble.
        if (response.StatusCode != HttpStatusCode.NotFound && !response.IsSuccessStatusCode) return Lookup<FoodItem>.Fail(LookupStatus.Unavailable);
        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        return Parse(doc.RootElement, DateTime.UtcNow) is { } item ? Lookup<FoodItem>.Ok(item) : Lookup<FoodItem>.Fail(LookupStatus.NotFound);
    }

    /// <summary>Null when the response holds no product.</summary>
    public static FoodItem? Parse(JsonElement root, DateTime retrievedAtUtc)
    {
        if (!root.TryGetProperty("product", out var p) || p.ValueKind != JsonValueKind.Object) return null;
        var code = Text(root, "code") ?? Text(p, "code");
        if (code is null) return null;

        var servingUnit = Text(p, "serving_quantity_unit")?.ToLowerInvariant();
        var servingQuantity = Number(p, "serving_quantity");
        var sets = p.TryGetProperty("nutrition", out var nutrition) && nutrition.TryGetProperty("input_sets", out var input) && input.ValueKind == JsonValueKind.Array
            ? input.EnumerateArray().ToList() : [];
        // The serving's size is sometimes only on the set of values the label gives per serving.
        if (servingQuantity is null && sets.FirstOrDefault(s => Text(s, "per") == "serving") is { ValueKind: JsonValueKind.Object } perServing)
            (servingQuantity, servingUnit) = (Number(perServing, "per_quantity"), Text(perServing, "per_unit")?.ToLowerInvariant());

        var (basis, nutrients) = Nutrients(nutrition, servingUnit);
        var servings = new List<FoodServing>();
        if (servingQuantity is > 0 && servingUnit is "g" or "ml")
        {
            var label = Text(p, "serving_size") ?? $"{servingQuantity.Value.ToString("G29", CultureInfo.InvariantCulture)} {servingUnit}";
            servings.Add(new(label, servingUnit == "g" ? servingQuantity : null, servingUnit == "ml" ? servingQuantity : null));
        }

        var prepared = nutrition.ValueKind == JsonValueKind.Object && nutrition.TryGetProperty("aggregated_set", out var set) && Text(set, "preparation") == "prepared";
        var description = string.Join(" · ", new[] { Text(p, "quantity"), prepared ? "Prepared" : null }.Where(s => s is not null));
        var image = Text(p, "image_front_small_url");
        return new FoodItem("off", code, code,
            // The name is the product's own, in the language it was entered in. It is never translated here.
            Text(p, "product_name") ?? Text(p, "generic_name") ?? $"Product {code}",
            Text(p, "brands"), description.Length == 0 ? null : description, basis, nutrients, servings,
            image, image is null ? null : "Photo: Open Food Facts contributors, CC BY-SA 3.0",
            p.TryGetProperty("rev", out var rev) ? rev.ToString() : null, Text(p, "lang"), retrievedAtUtc);
    }

    /// <summary>
    /// Reads the aggregated values. Each one says what it was stated per ("100g", "100ml" or "serving"); Open Food
    /// Facts files 100 ml under "100g", but a millilitre is not a gram, so the basis comes from the values themselves.
    /// Values estimated from the ingredient list are not label values and stay unknown.
    /// </summary>
    private static (string Basis, Macros Nutrients) Nutrients(JsonElement nutrition, string? servingUnit)
    {
        var none = (FoodBasis.Per100g, new Macros(null, null, null, null));
        if (nutrition.ValueKind != JsonValueKind.Object || !nutrition.TryGetProperty("aggregated_set", out var set) ||
            !set.TryGetProperty("nutrients", out var all) || all.ValueKind != JsonValueKind.Object) return none;

        string? BasisOf(JsonElement n) => Text(n, "source_per") switch
        {
            "100g" => FoodBasis.Per100g,
            "100ml" => FoodBasis.Per100ml,
            // A per-serving label value was converted to 100 of whatever the serving is measured in.
            "serving" => servingUnit switch { "g" => FoodBasis.Per100g, "ml" => FoodBasis.Per100ml, _ => null },
            _ => null,
        };
        JsonElement? Stated(string key) =>
            all.TryGetProperty(key, out var n) && n.ValueKind == JsonValueKind.Object && Text(n, "source") != "estimate" && Number(n, "value") is not null && BasisOf(n) is not null ? n : null;

        var kcal = Stated("energy-kcal");
        var kj = kcal is null ? Stated("energy-kj") ?? Stated("energy") : null;
        var parts = new[] { kcal ?? kj, Stated("proteins"), Stated("carbohydrates"), Stated("fat") };
        var basis = parts.Where(n => n is not null).Select(n => BasisOf(n!.Value)).FirstOrDefault();
        if (basis is null) return none;

        // A value stated on another basis cannot be mixed in, so it is left unknown.
        decimal? Value(JsonElement? n) => n is { } e && BasisOf(e) == basis ? Number(e, "value") : null;
        var energy = kcal is not null ? Value(kcal) : Value(kj) is { } kilojoules ? Math.Round(kilojoules / KilojoulesPerKilocalorie, 1) : null;
        return (basis, new Macros(energy, Value(parts[1]), Value(parts[2]), Value(parts[3])));
    }

    private static string? Text(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(v.GetString()) ? v.GetString()!.Trim() : null;

    /// <summary>Numbers arrive as numbers or as text ("330").</summary>
    private static decimal? Number(JsonElement e, string name)
    {
        if (e.ValueKind != JsonValueKind.Object || !e.TryGetProperty(name, out var v)) return null;
        if (v.ValueKind == JsonValueKind.Number && v.TryGetDecimal(out var d)) return d < 0 ? null : d;
        return v.ValueKind == JsonValueKind.String && decimal.TryParse(v.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var s) && s >= 0 ? s : null;
    }
}
