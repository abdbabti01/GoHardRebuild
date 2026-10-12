namespace GoHard.Api.Application.FoodDiscovery;

/// <summary>A named amount of a food. A weight or volume is present only when the provider states it.</summary>
public sealed record FoodServing(string Label, decimal? Grams, decimal? Milliliters);

/// <summary>
/// One food as every provider is normalized to. <paramref name="Nutrients"/> are for exactly one
/// <paramref name="Basis"/>: null is unknown, zero is a stated zero.
/// </summary>
/// <param name="Source">off | usda</param>
/// <param name="SourceId">Stable in the provider: the product code or the FDC ID.</param>
/// <param name="Barcode">Digits as text, so leading zeros survive.</param>
/// <param name="Basis">100g | 100ml | serving. For "serving", the first of <paramref name="Servings"/> is that serving.</param>
public sealed record FoodItem(string Source, string SourceId, string? Barcode, string Name, string? Brand, string? Description,
    string Basis, Macros Nutrients, List<FoodServing> Servings, string? ImageUrl, string? ImageAttribution,
    string? SourceVersion, string? Language, DateTime RetrievedAtUtc);

public static class FoodBasis
{
    public const string Per100g = "100g", Per100ml = "100ml", Serving = "serving";
}

public enum LookupStatus { Ok, NotFound, Invalid, NotConfigured, RateLimited, Unavailable }

public sealed record Lookup<T>(LookupStatus Status, T? Value = default)
{
    public static Lookup<T> Ok(T value) => new(LookupStatus.Ok, value);
    public static Lookup<T> Fail(LookupStatus status) => new(status);
    /// <summary>Only answers the provider actually gave are worth remembering.</summary>
    public bool IsCacheable => Status is LookupStatus.Ok or LookupStatus.NotFound;
}

public static class Barcodes
{
    /// <summary>
    /// Digits only, 6 to 14 of them (UPC-E, EAN-8, UPC-A, EAN-13, GTIN-14), kept as text. Then Open Food Facts'
    /// documented normalization: leading zeros are dropped and the code is padded back to 8 digits when it has
    /// 8 or fewer and to 13 otherwise, so "0012345678905" and "012345678905" are one product. Null when it is not a product code.
    /// </summary>
    public static string? Normalize(string? raw)
    {
        var code = (raw ?? "").Trim();
        if (code.Length is < 6 or > 14 || !code.All(char.IsAsciiDigit)) return null;
        var stripped = code.TrimStart('0');
        if (stripped.Length == 0) return null;
        return stripped.PadLeft(stripped.Length <= 8 ? 8 : 13, '0');
    }
}
