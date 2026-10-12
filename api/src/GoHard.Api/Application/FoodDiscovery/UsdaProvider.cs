using System.Globalization;
using System.Net;
using System.Text.Json;

namespace GoHard.Api.Application.FoodDiscovery;

/// <summary>
/// Text search over USDA FoodData Central (api.nal.usda.gov/fdc/v1). The key stays on the server and travels in the
/// X-Api-Key header, never in a URL, so it cannot end up in a request log. Data is public domain (CC0); USDA asks
/// to be credited as the source.
/// </summary>
public sealed class UsdaProvider(HttpClient http)
{
    public const string Generic = "Foundation,SR Legacy,Survey (FNDDS)", Branded = "Branded";

    // FoodData Central nutrient IDs. Energy in kilocalories is 1008; Foundation foods carry Atwater energy instead.
    private const int Energy = 1008, EnergyAtwaterGeneral = 2047, EnergyAtwaterSpecific = 2048, Protein = 1003, Fat = 1004, Carbohydrate = 1005;

    public async Task<Lookup<List<FoodItem>>> SearchAsync(string query, string dataTypes, int pageSize, CancellationToken ct)
    {
        var url = $"foods/search?query={Uri.EscapeDataString(query)}&dataType={Uri.EscapeDataString(dataTypes)}&pageSize={pageSize}";
        using var response = await http.GetAsync(url, ct);
        if (response.StatusCode == HttpStatusCode.TooManyRequests) return Lookup<List<FoodItem>>.Fail(LookupStatus.RateLimited);
        // A refused key is a configuration fault of this server, not something the person searching can fix.
        if (response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized) return Lookup<List<FoodItem>>.Fail(LookupStatus.NotConfigured);
        if (!response.IsSuccessStatusCode) return Lookup<List<FoodItem>>.Fail(LookupStatus.Unavailable);
        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        return Lookup<List<FoodItem>>.Ok(Parse(doc.RootElement, DateTime.UtcNow));
    }

    public static List<FoodItem> Parse(JsonElement root, DateTime retrievedAtUtc) =>
        root.TryGetProperty("foods", out var foods) && foods.ValueKind == JsonValueKind.Array
            ? foods.EnumerateArray().Select(f => ParseFood(f, retrievedAtUtc)).OfType<FoodItem>().ToList()
            : [];

    private static FoodItem? ParseFood(JsonElement f, DateTime retrievedAtUtc)
    {
        if (!f.TryGetProperty("fdcId", out var id) || Text(f, "description") is not { } name) return null;
        var dataType = Text(f, "dataType");
        var servingUnit = Text(f, "servingSizeUnit")?.ToLowerInvariant();
        // Branded values are per 100 g, or per 100 ml when the label's serving is a volume. Everything else is per 100 g.
        var liquid = dataType == Branded && servingUnit is "ml" or "mlt";

        var values = new Dictionary<int, decimal>();
        if (f.TryGetProperty("foodNutrients", out var nutrients) && nutrients.ValueKind == JsonValueKind.Array)
            foreach (var n in nutrients.EnumerateArray())
            {
                if (!n.TryGetProperty("nutrientId", out var nid) || !nid.TryGetInt32(out var key) || !n.TryGetProperty("value", out var v) || !v.TryGetDecimal(out var value) || value < 0) continue;
                // The unit is checked, not assumed: energy also comes in kilojoules under another ID.
                var unit = Text(n, "unitName")?.ToUpperInvariant();
                if (unit == (key is Energy or EnergyAtwaterGeneral or EnergyAtwaterSpecific ? "KCAL" : "G")) values.TryAdd(key, value);
            }
        decimal? Of(params int[] ids) => ids.Where(values.ContainsKey).Select(i => (decimal?)values[i]).FirstOrDefault();

        var servings = new List<FoodServing>();
        if (f.TryGetProperty("servingSize", out var size) && size.TryGetDecimal(out var amount) && amount > 0 && servingUnit is "g" or "ml" or "mlt")
        {
            var unit = servingUnit == "g" ? "g" : "ml";
            var stated = $"{amount.ToString("G29", CultureInfo.InvariantCulture)} {unit}";
            servings.Add(new(Text(f, "householdServingFullText") is { } household ? $"{household} ({stated})" : stated, unit == "g" ? amount : null, unit == "ml" ? amount : null));
        }
        if (f.TryGetProperty("foodMeasures", out var measures) && measures.ValueKind == JsonValueKind.Array)
            foreach (var m in measures.EnumerateArray())
                if (Text(m, "disseminationText") is { } label && label != "Quantity not specified" && m.TryGetProperty("gramWeight", out var g) && g.TryGetDecimal(out var grams) && grams > 0)
                    servings.Add(new(label, grams, null));

        var description = string.Join(" · ", new[] { dataType == Branded ? null : dataType, Text(f, "foodCategory"), Text(f, "additionalDescriptions") }.Where(s => s is not null));
        return new FoodItem("usda", id.ToString(), Text(f, "gtinUpc"), name, Text(f, "brandName") ?? Text(f, "brandOwner"),
            description.Length == 0 ? null : description, liquid ? FoodBasis.Per100ml : FoodBasis.Per100g,
            new Macros(Of(Energy, EnergyAtwaterSpecific, EnergyAtwaterGeneral), Of(Protein), Of(Carbohydrate), Of(Fat)),
            servings, null, null, Text(f, "publishedDate"), "en", retrievedAtUtc);
    }

    private static string? Text(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(v.GetString()) ? v.GetString()!.Trim() : null;
}
