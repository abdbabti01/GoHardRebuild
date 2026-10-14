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
    public string? ApiKey { get; set; }
    public string UserAgent { get; set; } = "GoHardRebuild/0.1 (https://github.com/abdbabti01/GoHardRebuild)";
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
    private readonly WeatherOptions _options;
    private readonly ILogger<WeatherService> _log;
    private readonly MemoryCache _cache;
    private readonly ConcurrentDictionary<string, Lazy<Task<object>>> _inFlight = new();
    private readonly RateLimiter _budget;
    private readonly TimeProvider _time;
    private DateTimeOffset _quietUntil;
    private static readonly TimeSpan Quiet = TimeSpan.FromMinutes(5), Places = TimeSpan.FromHours(24);

    public WeatherService(OpenMeteoProvider provider, WeatherOptions options, ILogger<WeatherService> log, TimeProvider? time = null)
    {
        (_provider, _options, _log, _time) = (provider, options, log, time ?? TimeProvider.System);
        _cache = new MemoryCache(new MemoryCacheOptions { SizeLimit = options.CacheEntries });
        _budget = new FixedWindowRateLimiter(new() { PermitLimit = Math.Max(1, options.PerHour), Window = TimeSpan.FromHours(1), QueueLimit = 0, AutoReplenishment = true });
    }

    public bool Enabled => _options.Enabled;

    /// <summary>The coarse grid every coordinate is reduced to. Null when it is not a place on Earth.</summary>
    public static (double Lat, double Lon)? Round(double lat, double lon)
    {
        if (!double.IsFinite(lat) || !double.IsFinite(lon) || Math.Abs(lat) > 90 || Math.Abs(lon) > 180) return null;
        return (Math.Round(lat, 1, MidpointRounding.AwayFromZero) + 0.0, Math.Round(lon, 1, MidpointRounding.AwayFromZero) + 0.0);  // + 0.0: no "-0"
    }

    public Task<Lookup<WeatherNow>> CurrentAsync(double? lat, double? lon, CancellationToken ct)
    {
        if (lat is null || lon is null || Round(lat.Value, lon.Value) is not { } at) return Task.FromResult(Lookup<WeatherNow>.Fail(LookupStatus.Invalid));
        if (!_options.Enabled) return Task.FromResult(Lookup<WeatherNow>.Fail(LookupStatus.NotConfigured));
        return RememberAsync(FormattableString.Invariant($"now:{at.Lat}:{at.Lon}"), TimeSpan.FromMinutes(Math.Max(1, _options.CacheMinutes)),
            () => CallAsync(token => _provider.CurrentAsync(at.Lat, at.Lon, token)), ct);
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
    private async Task<Lookup<T>> CallAsync<T>(Func<CancellationToken, Task<Lookup<T>>> call)
    {
        for (var attempt = 1; ; attempt++)
        {
            if (_time.GetUtcNow() < _quietUntil) return Lookup<T>.Fail(LookupStatus.RateLimited);
            using var lease = _budget.AttemptAcquire();
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
                _log.LogWarning("Open-Meteo did not answer usefully ({Reason}), attempt {Attempt}", ex.GetType().Name, attempt);
                result = Lookup<T>.Fail(LookupStatus.Unavailable);
            }
            if (result.Status == LookupStatus.RateLimited)
            {
                _quietUntil = _time.GetUtcNow() + Quiet;
                _log.LogWarning("Open-Meteo reported its rate limit; pausing weather requests for {Minutes} minutes", Quiet.TotalMinutes);
            }
            if (result.Status != LookupStatus.Unavailable || attempt == 2) return result;
        }
    }

    public void Dispose()
    {
        _cache.Dispose();
        _budget.Dispose();
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
        services.AddSingleton<WeatherService>();
        return services;
    }
}
