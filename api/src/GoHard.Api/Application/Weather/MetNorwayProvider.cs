using System.Collections.Concurrent;
using System.Globalization;
using System.Net;
using System.Text.Json;
using GoHard.Api.Application.FoodDiscovery;

namespace GoHard.Api.Application.Weather;

/// <summary>
/// MET Norway Locationforecast 2.0 (api.met.no), the fallback when Open-Meteo refuses. Free, including commercial
/// use, no key. Its terms (api.met.no/doc/TermsOfService, checked 14 October 2026), all followed here: an identifying
/// User-Agent with contact details; no repeat request before the answer's Expires time, then a conditional request
/// with If-Modified-Since = the last Last-Modified (304 reuses the kept answer); gzip; at most 4 decimals; HTTPS.
/// Data: CC BY 4.0 / NLOD, credited "Weather data from MET Norway". Its symbol for the current hour is mapped onto
/// the same WMO codes and families Open-Meteo uses, so the app needs nothing new.
/// </summary>
public sealed class MetNorwayProvider(HttpClient http, WeatherOptions options, TimeProvider? time = null)
{
    public const string Source = "met.no";

    /// <summary>The last answer per coarse place, with its Expires and Last-Modified, so the place is not asked again
    /// before Expires and is then asked conditionally. Bounded; the oldest are dropped.</summary>
    private readonly ConcurrentDictionary<string, Kept> _kept = new();
    private sealed record Kept(string Body, DateTimeOffset Expires, DateTimeOffset? LastModified);
    private const int MaxKept = 2000;

    public async Task<Lookup<WeatherNow>> CurrentAsync(double lat, double lon, CancellationToken ct)
    {
        var now = (time ?? TimeProvider.System).GetUtcNow();
        var key = FormattableString.Invariant($"{lat}:{lon}");
        _kept.TryGetValue(key, out var kept);
        string body;
        if (kept is not null && now < kept.Expires)
        {
            body = kept.Body;                                                    // not before Expires: the kept answer
        }
        else
        {
            var url = new Uri(new Uri(options.MetNorwayBaseUrl), FormattableString.Invariant($"locationforecast/2.0/compact?lat={lat}&lon={lon}"));
            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            if (kept?.LastModified is { } since) request.Headers.IfModifiedSince = since;
            using var response = await http.SendAsync(request, ct);
            if (response.StatusCode == HttpStatusCode.TooManyRequests) return Lookup<WeatherNow>.Fail(LookupStatus.RateLimited);
            if (response.StatusCode == HttpStatusCode.NotModified && kept is not null)
            {
                body = kept.Body;
            }
            else if (response.IsSuccessStatusCode)
            {
                body = await response.Content.ReadAsStringAsync(ct);
            }
            else
            {
                return Lookup<WeatherNow>.Fail(LookupStatus.Unavailable);
            }
            // Without an Expires header, wait at least the polling interval MET asks for (10 minutes).
            var expires = response.Content.Headers.Expires ?? now + TimeSpan.FromMinutes(10);
            var lastModified = response.Content.Headers.LastModified ?? kept?.LastModified;
            if (_kept.Count >= MaxKept) _kept.Clear();                           // ponytail: crude bound; an LRU if many places
            _kept[key] = new Kept(body, expires, lastModified);
        }
        using var doc = JsonDocument.Parse(body);
        return ParseCurrent(doc.RootElement, lat, lon, now.UtcDateTime) is { } result ? Lookup<WeatherNow>.Ok(result) : Lookup<WeatherNow>.Fail(LookupStatus.Unavailable);
    }

    /// <summary>
    /// The latest hourly entry starting at or before <paramref name="fetchedAtUtc"/> (MET times are UTC instants) and its
    /// next-hour symbol. Day or night: the symbol's _day/_night suffix when it has one, otherwise the sun's elevation
    /// at that place and instant. Null when there is no usable entry.
    /// </summary>
    public static WeatherNow? ParseCurrent(JsonElement root, double lat, double lon, DateTime fetchedAtUtc)
    {
        if (!root.TryGetProperty("properties", out var props) || !props.TryGetProperty("timeseries", out var series) || series.ValueKind != JsonValueKind.Array) return null;
        JsonElement? pick = null;
        DateTime validAt = default;
        foreach (var e in series.EnumerateArray())
        {
            if (!e.TryGetProperty("time", out var t) || !DateTime.TryParse(t.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out var at)) continue;
            if (at > fetchedAtUtc) break;   // hourly entries: the one now in progress, never the next hour's
            (pick, validAt) = (e, DateTime.SpecifyKind(at, DateTimeKind.Utc));
        }
        if (pick is not { } entry || !entry.TryGetProperty("data", out var data)) return null;
        var symbol = data.TryGetProperty("next_1_hours", out var n1) && n1.TryGetProperty("summary", out var s) && s.TryGetProperty("symbol_code", out var sc) ? sc.GetString() : null;
        decimal? temp = data.TryGetProperty("instant", out var inst) && inst.TryGetProperty("details", out var det) && det.TryGetProperty("air_temperature", out var at2) && at2.TryGetDecimal(out var tv) ? tv : null;

        var (code, description) = symbol is null ? ((int?)null, (string?)null) : Map(symbol);
        var family = code is { } c && WeatherFamily.Codes.TryGetValue(c, out var known) ? known.Family : WeatherFamily.Unknown;
        bool isDay = symbol?.EndsWith("_day", StringComparison.Ordinal) == true || (symbol?.EndsWith("_night", StringComparison.Ordinal) != true &&
            symbol?.EndsWith("_polartwilight", StringComparison.Ordinal) != true && Sun.IsDay(lat, lon, validAt));
        return new WeatherNow(family, code, description, isDay, validAt, fetchedAtUtc, temp, null, lat, lon, Source);
    }

    /// <summary>MET symbol (without its _day/_night suffix) -> the WMO code Open-Meteo would use, and MET's own words.</summary>
    public static (int? Code, string? Description) Map(string symbol)
    {
        var name = symbol.Split('_')[0];
        if (name.Contains("thunder", StringComparison.Ordinal)) return (95, Words(name));
        int? code = name switch
        {
            "clearsky" => 0, "fair" => 1, "partlycloudy" => 2, "cloudy" => 3, "fog" => 45,
            "lightrain" => 61, "rain" => 63, "heavyrain" => 65,
            "lightrainshowers" => 80, "rainshowers" => 81, "heavyrainshowers" => 82,
            "lightsleet" or "lightsleetshowers" => 66, "sleet" or "heavysleet" or "sleetshowers" or "heavysleetshowers" => 67,
            "lightsnow" => 71, "snow" => 73, "heavysnow" => 75,
            "lightsnowshowers" or "snowshowers" => 85, "heavysnowshowers" => 86,
            _ => null,
        };
        return (code, code is null ? null : Words(name));
    }

    /// <summary>"lightrainshowers" -> "Light rain showers", "partlycloudy" -> "Partly cloudy".</summary>
    private static string Words(string name)
    {
        var s = name;
        foreach (var w in new[] { "light", "heavy", "rain", "showers", "sleet", "snow", "and", "thunder", "partly", "cloudy", "clear", "sky", "fair", "fog" })
            s = s.Replace(w, w + " ", StringComparison.Ordinal);
        s = string.Join(' ', s.Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return s.Length == 0 ? name : char.ToUpperInvariant(s[0]) + s[1..];
    }
}

/// <summary>
/// Whether the sun is up at a place and instant, from its elevation (NOAA's simplified solar position; good to well
/// under a degree, which is what "day or night" needs). Used only when a provider does not say.
/// </summary>
public static class Sun
{
    public static double Elevation(double lat, double lon, DateTime utc)
    {
        var day = utc.DayOfYear;
        var hours = utc.Hour + utc.Minute / 60.0 + utc.Second / 3600.0;
        var g = 2 * Math.PI / 365 * (day - 1 + (hours - 12) / 24);   // fractional year
        var eqTime = 229.18 * (0.000075 + 0.001868 * Math.Cos(g) - 0.032077 * Math.Sin(g) - 0.014615 * Math.Cos(2 * g) - 0.040849 * Math.Sin(2 * g));
        var decl = 0.006918 - 0.399912 * Math.Cos(g) + 0.070257 * Math.Sin(g) - 0.006758 * Math.Cos(2 * g) + 0.000907 * Math.Sin(2 * g)
                   - 0.002697 * Math.Cos(3 * g) + 0.00148 * Math.Sin(3 * g);
        var trueSolarMinutes = hours * 60 + eqTime + 4 * lon;
        var hourAngle = (trueSolarMinutes / 4 - 180) * Math.PI / 180;
        var phi = lat * Math.PI / 180;
        var cosZenith = Math.Sin(phi) * Math.Sin(decl) + Math.Cos(phi) * Math.Cos(decl) * Math.Cos(hourAngle);
        return 90 - Math.Acos(Math.Clamp(cosZenith, -1, 1)) * 180 / Math.PI;
    }

    /// <summary>Sunrise and sunset are when the upper limb crosses the horizon, refraction included: -0.833°.</summary>
    public static bool IsDay(double lat, double lon, DateTime utc) => Elevation(lat, lon, utc) > -0.833;
}
