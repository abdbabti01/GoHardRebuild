using System.Collections.Concurrent;
using System.Threading.RateLimiting;
using GoHard.Api.Application.FoodDiscovery;
using Microsoft.Extensions.Caching.Memory;

namespace GoHard.Api.Application.Weather;

/// <summary>
/// Configuration section "Weather". The free Open-Meteo API needs no key and is for non-commercial use only. For
/// commercial use point both base URLs at the customer- hosts and set the key: GOHARD_Weather__ApiKey.
/// </summary>
public sealed class WeatherOptions
{
    /// <summary>Off: the endpoints answer PROVIDER_NOT_CONFIGURED and weather.current is not declared.</summary>
    public bool Enabled { get; set; } = true;
    public string ForecastBaseUrl { get; set; } = "https://api.open-meteo.com/v1/";
    public string GeocodingBaseUrl { get; set; } = "https://geocoding-api.open-meteo.com/v1/";
    /// <summary>Fallback for current conditions when Open-Meteo refuses (its free tier limits per calling IP, and a
    /// cloud host's outbound IP is shared with other tenants). Empty: no fallback.</summary>
    public string MetNorwayBaseUrl { get; set; } = "https://api.met.no/weatherapi/";
    public string? ApiKey { get; set; }
    /// <summary>MET Norway requires an identifying User-Agent with a contact; Open-Meteo is sent the same.</summary>
    /// Override with GOHARD_Weather__UserAgent to add an email address.
    public string UserAgent { get; set; } = "GoHardRebuild/0.1 (+https://github.com/abdbabti01)";
    public int TimeoutSeconds { get; set; } = 5;
    public int CacheMinutes { get; set; } = 10; // current conditions are 15-minute model data; with the phone's 15-minute refresh a scene is at most ~25 minutes behind
    public int CacheEntries { get; set; } = 2000;
    // Every user of this API shares one calling IP. 400 an hour stays under the free tier's 5,000 an hour and
    // 10,000 a day even if spent every hour.
    public int PerHour { get; set; } = 400;
}

/// <summary>
/// The one door for weather. Coordinates are rounded to a 0.1° grid (about 10 km) before anything else happens, so
/// the cache, the provider and any log only ever see a coarse region. Remembers answers, lets identical requests
/// share one provider call and spends the shared budget carefully. Nothing here is per user and nothing is logged
/// with a place in it.
/// </summary>
// ponytail: per-process cache and budget, like FoodDiscoveryService; a second instance needs a shared store.
public sealed class WeatherService : IDisposable
{
    private readonly OpenMeteoProvider _provider;
    private readonly MetNorwayProvider _met;
    private readonly WeatherOptions _options;
    private readonly ILogger<WeatherService> _log;
    private readonly MemoryCache _cache;
    private readonly ConcurrentDictionary<string, Lazy<Task<object>>> _inFlight = new();
    private readonly RateLimiter _budget, _metBudget;
    private readonly TimeProvider _time;
    private DateTimeOffset _quietUntil, _metQuietUntil;
    private static readonly TimeSpan Quiet = TimeSpan.FromMinutes(5), Places = TimeSpan.FromHours(24);

    public WeatherService(OpenMeteoProvider provider, MetNorwayProvider met, WeatherOptions options, ILogger<WeatherService> log, TimeProvider? time = null)
    {
        (_provider, _met, _options, _log, _time) = (provider, met, options, log, time ?? TimeProvider.System);
        _cache = new MemoryCache(new MemoryCacheOptions { SizeLimit = options.CacheEntries });
        _budget = new FixedWindowRateLimiter(new() { PermitLimit = Math.Max(1, options.PerHour), Window = TimeSpan.FromHours(1), QueueLimit = 0, AutoReplenishment = true });
        _metBudget = new FixedWindowRateLimiter(new() { PermitLimit = Math.Max(1, options.PerHour), Window = TimeSpan.FromHours(1), QueueLimit = 0, AutoReplenishment = true });
    }

    public bool Enabled => _options.Enabled;

    /// <summary>The coarse grid every coordinate is reduced to. Null when it is not a place on Earth.</summary>
    public static (double Lat, double Lon)? Round(double lat, double lon)
    {
        if (!double.IsFinite(lat) || !double.IsFinite(lon) || Math.Abs(lat) > 90 || Math.Abs(lon) > 180) return null;
        return (Math.Round(lat, 1, MidpointRounding.AwayFromZero) + 0.0, Math.Round(lon, 1, MidpointRounding.AwayFromZero) + 0.0);  // + 0.0: no "-0"
    }

    /// <param name="viaFallback">Ask MET Norway directly (verification of the fallback); otherwise Open-Meteo first.</param>
    public Task<Lookup<WeatherNow>> CurrentAsync(double? lat, double? lon, CancellationToken ct, bool viaFallback = false)
    {
        if (lat is null || lon is null || Round(lat.Value, lon.Value) is not { } at) return Task.FromResult(Lookup<WeatherNow>.Fail(LookupStatus.Invalid));
        if (!_options.Enabled) return Task.FromResult(Lookup<WeatherNow>.Fail(LookupStatus.NotConfigured));
        if (viaFallback)
        {
            if (string.IsNullOrWhiteSpace(_options.MetNorwayBaseUrl)) return Task.FromResult(Lookup<WeatherNow>.Fail(LookupStatus.NotConfigured));
            return RememberAsync(FormattableString.Invariant($"met:{at.Lat}:{at.Lon}"), TimeSpan.FromMinutes(Math.Max(1, _options.CacheMinutes)),
                () => CallAsync(token => _met.CurrentAsync(at.Lat, at.Lon, token), "MET Norway", () => _metQuietUntil, t => _metQuietUntil = t, _metBudget), ct);
        }
        return RememberAsync(FormattableString.Invariant($"now:{at.Lat}:{at.Lon}"), TimeSpan.FromMinutes(Math.Max(1, _options.CacheMinutes)), async () =>
        {
            var primary = await CallAsync(token => _provider.CurrentAsync(at.Lat, at.Lon, token));
            if (primary.Status is not (LookupStatus.RateLimited or LookupStatus.Unavailable) || string.IsNullOrWhiteSpace(_options.MetNorwayBaseUrl)) return primary;
            // Open-Meteo refused or failed: the same question to MET Norway. Its answer says it came from there.
            var fallback = await CallAsync(token => _met.CurrentAsync(at.Lat, at.Lon, token), "MET Norway", () => _metQuietUntil, t => _metQuietUntil = t, _metBudget);
            _log.LogInformation("Open-Meteo {Status}; MET Norway answered {Fallback}", primary.Status, fallback.Status);
            return fallback.Status == LookupStatus.Ok ? fallback : primary;
        }, ct);
    }

    public Task<Lookup<List<WeatherPlace>>> PlacesAsync(string? raw, CancellationToken ct)
    {
        var query = string.Join(' ', (raw ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        if (query.Length is < 2 or > 80) return Task.FromResult(Lookup<List<WeatherPlace>>.Fail(LookupStatus.Invalid));
        if (!_options.Enabled) return Task.FromResult(Lookup<List<WeatherPlace>>.Fail(LookupStatus.NotConfigured));
        return RememberAsync($"places:{query.ToLowerInvariant()}", Places, () => CallAsync(token => _provider.PlacesAsync(query, token)), ct);
    }

    private async Task<Lookup<T>> RememberAsync<T>(string key, TimeSpan keep, Func<Task<Lookup<T>>> load, CancellationToken ct)
    {
        if (_cache.TryGetValue(key, out Lookup<T>? cached)) return cached!;
        var shared = _inFlight.GetOrAdd(key, k => new Lazy<Task<object>>(async () =>
        {
            try
            {
                var result = await load();
                if (result.Status == LookupStatus.Ok) _cache.Set(key, result, new MemoryCacheEntryOptions { Size = 1, AbsoluteExpirationRelativeToNow = keep });
                return result;
            }
            finally { _inFlight.TryRemove(key, out _); }
        }));
        return (Lookup<T>)await shared.Value.WaitAsync(ct);
    }

    /// <summary>One provider call inside the budget, with a short bounded wait and one retry for a failure that may pass.</summary>
    private Task<Lookup<T>> CallAsync<T>(Func<CancellationToken, Task<Lookup<T>>> call) =>
        CallAsync(call, "Open-Meteo", () => _quietUntil, t => _quietUntil = t, _budget);

    private async Task<Lookup<T>> CallAsync<T>(Func<CancellationToken, Task<Lookup<T>>> call, string provider, Func<DateTimeOffset> quietUntil, Action<DateTimeOffset> setQuiet, RateLimiter budget)
    {
        for (var attempt = 1; ; attempt++)
        {
            if (_time.GetUtcNow() < quietUntil()) return Lookup<T>.Fail(LookupStatus.RateLimited);
            using var lease = budget.AttemptAcquire();
            if (!lease.IsAcquired) return Lookup<T>.Fail(LookupStatus.RateLimited);
            Lookup<T> result;
            try
            {
                using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(_options.TimeoutSeconds));
                result = await call(timeout.Token);
            }
            catch (Exception ex) when (ex is HttpRequestException or OperationCanceledException or System.Text.Json.JsonException)
            {
                // The reason only: the request URL holds a (coarse) place and is never written to the log.
                _log.LogWarning("{Provider} did not answer usefully ({Reason}), attempt {Attempt}", provider, ex.GetType().Name, attempt);
                result = Lookup<T>.Fail(LookupStatus.Unavailable);
            }
            if (result.Status == LookupStatus.RateLimited)
            {
                setQuiet(_time.GetUtcNow() + Quiet);
                _log.LogWarning("{Provider} reported its rate limit; pausing requests to it for {Minutes} minutes", provider, Quiet.TotalMinutes);
            }
            if (result.Status != LookupStatus.Unavailable || attempt == 2) return result;
        }
    }

    public void Dispose()
    {
        _cache.Dispose();
        _budget.Dispose();
        _metBudget.Dispose();
    }
}

public static class WeatherRegistration
{
    public const string Capability = "weather.current";

    public static IServiceCollection AddWeather(this IServiceCollection services, IConfiguration config)
    {
        var options = config.GetSection("Weather").Get<WeatherOptions>() ?? new();
        services.AddSingleton(options);
        services.AddHttpClient<OpenMeteoProvider>(c =>
        {
            c.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds + 2);   // backstop behind the service's own bound
            c.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
        }).ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler { PooledConnectionLifetime = TimeSpan.FromMinutes(5) });
        // MET Norway requires gzip support; its provider is a singleton so its Expires/Last-Modified memory lasts.
        services.AddHttpClient<MetNorwayProvider>(c =>
        {
            c.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds + 2);
            c.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
        }).ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            PooledConnectionLifetime = TimeSpan.FromMinutes(5),
            AutomaticDecompression = System.Net.DecompressionMethods.GZip | System.Net.DecompressionMethods.Deflate,
        });
        services.AddSingleton<WeatherService>();
        return services;
    }
}
