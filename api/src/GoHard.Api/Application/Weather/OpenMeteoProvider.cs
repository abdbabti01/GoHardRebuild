using System.Globalization;
using System.Net;
using System.Text.Json;
using GoHard.Api.Application.FoodDiscovery;

namespace GoHard.Api.Application.Weather;

/// <summary>
/// Current conditions for one coarse place, as every weather provider is normalized to. Only what the app's optional
/// Today background needs: a condition family, day or night at that place, and when the conditions are valid.
/// </summary>
/// <param name="Family">clear | cloudy | fog | rain | snow | storm | unknown</param>
/// <param name="Code">The provider's WMO weather code; null when it sent none.</param>
/// <param name="Description">The provider's own wording for <paramref name="Code"/>; null for a code it does not document.</param>
/// <param name="IsDay">Daylight at that place by the provider's reckoning; null when it did not say.</param>
/// <param name="ValidAtUtc">When the conditions are valid (model data), as a UTC instant.</param>
/// <param name="FetchedAtUtc">When this server received them. Never makes old conditions fresh.</param>
public sealed record WeatherNow(string Family, int? Code, string? Description, bool? IsDay, DateTime ValidAtUtc, DateTime FetchedAtUtc,
    decimal? TemperatureC, string? Timezone, double Latitude, double Longitude, string Source);

/// <summary>A geocoding result. <paramref name="Id"/> is the provider's identity for the place; a name alone is not one.</summary>
public sealed record WeatherPlace(string Id, string Name, string? Admin1, string? Country, string? CountryCode, double Latitude, double Longitude, string? Timezone);

public static class WeatherFamily
{
    public const string Clear = "clear", Cloudy = "cloudy", Fog = "fog", Rain = "rain", Snow = "snow", Storm = "storm", Unknown = "unknown";

    /// <summary>The WMO codes Open-Meteo documents (checked 2026-10-13). Anything else is unknown, never guessed clear.</summary>
    public static readonly IReadOnlyDictionary<int, (string Family, string Description)> Codes = new Dictionary<int, (string, string)>
    {
        [0] = (Clear, "Clear sky"), [1] = (Clear, "Mainly clear"), [2] = (Cloudy, "Partly cloudy"), [3] = (Cloudy, "Overcast"),
        [45] = (Fog, "Fog"), [48] = (Fog, "Depositing rime fog"),
        [51] = (Rain, "Light drizzle"), [53] = (Rain, "Moderate drizzle"), [55] = (Rain, "Dense drizzle"),
        [56] = (Rain, "Light freezing drizzle"), [57] = (Rain, "Dense freezing drizzle"),
        [61] = (Rain, "Slight rain"), [63] = (Rain, "Moderate rain"), [65] = (Rain, "Heavy rain"),
        [66] = (Rain, "Light freezing rain"), [67] = (Rain, "Heavy freezing rain"),
        [71] = (Snow, "Slight snowfall"), [73] = (Snow, "Moderate snowfall"), [75] = (Snow, "Heavy snowfall"), [77] = (Snow, "Snow grains"),
        [80] = (Rain, "Slight rain showers"), [81] = (Rain, "Moderate rain showers"), [82] = (Rain, "Violent rain showers"),
        [85] = (Snow, "Slight snow showers"), [86] = (Snow, "Heavy snow showers"),
        [95] = (Storm, "Thunderstorm"), [96] = (Storm, "Thunderstorm with slight hail"), [97] = (Storm, "Heavy thunderstorm"), [99] = (Storm, "Thunderstorm with heavy hail"),
    };
}

/// <summary>
/// Open-Meteo forecast (current conditions) and geocoding. The free API needs no key and is for non-commercial use;
/// a commercial key, when configured, is sent as the documented apikey parameter to the customer- hosts.
/// Data: CC BY 4.0, credited "Weather data by Open-Meteo.com" in the app. Places are GeoNames-based.
/// </summary>
public sealed class OpenMeteoProvider(HttpClient http, WeatherOptions options)
{
    public const string Source = "open-meteo";
    /// <summary>Model data a little ahead of the server clock is normal; anything further is not "current".</summary>
    public static readonly TimeSpan FutureTolerance = TimeSpan.FromMinutes(20);

    private string Key => string.IsNullOrWhiteSpace(options.ApiKey) ? "" : "&apikey=" + Uri.EscapeDataString(options.ApiKey.Trim());

    public async Task<Lookup<WeatherNow>> CurrentAsync(double lat, double lon, CancellationToken ct)
    {
        var url = new Uri(new Uri(options.ForecastBaseUrl), FormattableString.Invariant(
            $"forecast?latitude={lat}&longitude={lon}&current=weather_code,is_day,temperature_2m&timezone=auto{Key}"));
        using var response = await http.GetAsync(url, ct);
        if (response.StatusCode == HttpStatusCode.TooManyRequests) return Lookup<WeatherNow>.Fail(LookupStatus.RateLimited);
        if (!response.IsSuccessStatusCode) return Lookup<WeatherNow>.Fail(LookupStatus.Unavailable);
        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        return ParseCurrent(doc.RootElement, lat, lon, DateTime.UtcNow) is { } now ? Lookup<WeatherNow>.Ok(now) : Lookup<WeatherNow>.Fail(LookupStatus.Unavailable);
    }

    public async Task<Lookup<List<WeatherPlace>>> PlacesAsync(string query, CancellationToken ct)
    {
        var url = new Uri(new Uri(options.GeocodingBaseUrl), $"search?name={Uri.EscapeDataString(query)}&count=8&language=en&format=json{Key}");
        using var response = await http.GetAsync(url, ct);
        if (response.StatusCode == HttpStatusCode.TooManyRequests) return Lookup<List<WeatherPlace>>.Fail(LookupStatus.RateLimited);
        if (!response.IsSuccessStatusCode) return Lookup<List<WeatherPlace>>.Fail(LookupStatus.Unavailable);
        using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        return Lookup<List<WeatherPlace>>.Ok(ParsePlaces(doc.RootElement));
    }

    /// <summary>
    /// Null when the answer has no usable current time. current.time is wall-clock time AT THE PLACE (timezone=auto);
    /// utc_offset_seconds turns it into an instant. A time too far ahead of <paramref name="fetchedAtUtc"/> is rejected.
    /// </summary>
    public static WeatherNow? ParseCurrent(JsonElement root, double lat, double lon, DateTime fetchedAtUtc)
    {
        if (root.ValueKind != JsonValueKind.Object || !root.TryGetProperty("current", out var c) || c.ValueKind != JsonValueKind.Object) return null;
        if (!root.TryGetProperty("utc_offset_seconds", out var off) || !off.TryGetInt32(out var offset) || Math.Abs(offset) > 14 * 3600) return null;
        if (!c.TryGetProperty("time", out var t) || t.ValueKind != JsonValueKind.String ||
            !DateTime.TryParseExact(t.GetString(), ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss"], CultureInfo.InvariantCulture, DateTimeStyles.None, out var local)) return null;
        var validAt = DateTime.SpecifyKind(local.AddSeconds(-offset), DateTimeKind.Utc);
        if (validAt > fetchedAtUtc + FutureTolerance) return null;

        int? code = c.TryGetProperty("weather_code", out var w) && w.ValueKind == JsonValueKind.Number && w.TryGetInt32(out var wc) ? wc : null;
        var known = code is { } k && WeatherFamily.Codes.TryGetValue(k, out var entry) ? entry : ((string, string)?)null;
        bool? isDay = c.TryGetProperty("is_day", out var d) && d.ValueKind == JsonValueKind.Number && d.TryGetInt32(out var di) && di is 0 or 1 ? di == 1 : null;
        decimal? temp = c.TryGetProperty("temperature_2m", out var tt) && tt.ValueKind == JsonValueKind.Number && tt.TryGetDecimal(out var tv) ? tv : null;
        var zone = root.TryGetProperty("timezone", out var z) && z.ValueKind == JsonValueKind.String ? z.GetString() : null;
        return new WeatherNow(known?.Item1 ?? WeatherFamily.Unknown, code, known?.Item2, isDay, validAt, fetchedAtUtc, temp, zone, lat, lon, Source);
    }

    public static List<WeatherPlace> ParsePlaces(JsonElement root)
    {
        if (root.ValueKind != JsonValueKind.Object || !root.TryGetProperty("results", out var results) || results.ValueKind != JsonValueKind.Array) return [];
        var places = new List<WeatherPlace>();
        foreach (var r in results.EnumerateArray())
        {
            if (Text(r, "name") is not { } name || !r.TryGetProperty("id", out var id) || id.ValueKind != JsonValueKind.Number ||
                !r.TryGetProperty("latitude", out var la) || !la.TryGetDouble(out var lat) || !r.TryGetProperty("longitude", out var lo) || !lo.TryGetDouble(out var lon) ||
                WeatherService.Round(lat, lon) is not { } at) continue;
            places.Add(new WeatherPlace(id.GetRawText(), name, Text(r, "admin1"), Text(r, "country"), Text(r, "country_code"), at.Lat, at.Lon, Text(r, "timezone")));
        }
        return places;
    }

    private static string? Text(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(v.GetString()) ? v.GetString()!.Trim() : null;
}
