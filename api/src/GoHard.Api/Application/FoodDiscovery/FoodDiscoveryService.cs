using System.Collections.Concurrent;
using System.Threading.RateLimiting;
using Microsoft.Extensions.Caching.Memory;

namespace GoHard.Api.Application.FoodDiscovery;

/// <summary>Configuration section "FoodData". The USDA key is a server secret: GOHARD_FoodData__UsdaApiKey.</summary>
public sealed class FoodDataOptions
{
    public string? UsdaApiKey { get; set; }
    public string UsdaBaseUrl { get; set; } = "https://api.nal.usda.gov/fdc/v1/";
    public string OpenFoodFactsBaseUrl { get; set; } = "https://world.openfoodfacts.org/";
    /// <summary>Open Food Facts asks every app to identify itself as "Name/Version (contact)".</summary>
    public string UserAgent { get; set; } = "GoHardRebuild/0.1 (https://github.com/abdbabti01/GoHardRebuild)";
    public int TimeoutSeconds { get; set; } = 8;
    // Both providers count requests per calling IP, and every user of this API shares one. These stay under the
    // documented limits (Open Food Facts: 15 product reads a minute; USDA: 1,000 requests an hour).
    public int OpenFoodFactsPerMinute { get; set; } = 10;
    public int UsdaPerHour { get; set; } = 800;
    public int CacheEntries { get; set; } = 5000;

    /// <summary>DEMO_KEY is for trying the API by hand (30 requests an hour); it is never treated as configured.</summary>
    public bool UsdaConfigured => !string.IsNullOrWhiteSpace(UsdaApiKey) && !string.Equals(UsdaApiKey.Trim(), "DEMO_KEY", StringComparison.OrdinalIgnoreCase);
}

public sealed record FoodSearchResult(List<FoodItem> Results);

/// <summary>
/// The one door the app uses for food data. It remembers answers, lets identical requests in flight share one
/// provider call, and spends each provider's shared request budget carefully. It stores nothing per user.
/// </summary>
// ponytail: the cache lives in this process and empties on restart, and the budgets are per process. One instance is
// what runs today; a second instance needs a shared cache (a table or Redis) before the budgets mean anything.
public sealed class FoodDiscoveryService : IDisposable
{
    private readonly OpenFoodFactsProvider _off;
    private readonly UsdaProvider _usda;
    private readonly FoodDataOptions _options;
    private readonly ILogger<FoodDiscoveryService> _log;
    private readonly MemoryCache _cache;
    private readonly ConcurrentDictionary<string, Lazy<Task<object>>> _inFlight = new();
    private readonly RateLimiter _offBudget, _usdaBudget;
    private readonly TimeProvider _time;
    // After a provider says "too many requests" nothing more is sent to it for a while.
    private DateTimeOffset _offQuietUntil, _usdaQuietUntil;

    private static readonly TimeSpan Found = TimeSpan.FromHours(24), Missing = TimeSpan.FromHours(1), Quiet = TimeSpan.FromMinutes(5);

    public FoodDiscoveryService(OpenFoodFactsProvider off, UsdaProvider usda, FoodDataOptions options, ILogger<FoodDiscoveryService> log, TimeProvider? time = null)
    {
        (_off, _usda, _options, _log, _time) = (off, usda, options, log, time ?? TimeProvider.System);
        _cache = new MemoryCache(new MemoryCacheOptions { SizeLimit = options.CacheEntries });
        _offBudget = Window(options.OpenFoodFactsPerMinute, TimeSpan.FromMinutes(1));
        _usdaBudget = Window(options.UsdaPerHour, TimeSpan.FromHours(1));
    }

    private static RateLimiter Window(int permits, TimeSpan window) =>
        new FixedWindowRateLimiter(new() { PermitLimit = Math.Max(1, permits), Window = window, QueueLimit = 0, AutoReplenishment = true });

    public bool SearchConfigured => _options.UsdaConfigured;

    public Task<Lookup<FoodItem>> BarcodeAsync(string? raw, CancellationToken ct)
    {
        if (Barcodes.Normalize(raw) is not { } code) return Task.FromResult(Lookup<FoodItem>.Fail(LookupStatus.Invalid));
        return RememberAsync($"off:{code}", () => CallAsync(_offBudget, () => _offQuietUntil, t => _offQuietUntil = t, "Open Food Facts",
            token => _off.ProductAsync(code, token)), ct);
    }

    public Task<Lookup<FoodSearchResult>> SearchAsync(string? raw, CancellationToken ct)
    {
        var query = string.Join(' ', (raw ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        if (query.Length is < 2 or > 80) return Task.FromResult(Lookup<FoodSearchResult>.Fail(LookupStatus.Invalid));
        if (!_options.UsdaConfigured) return Task.FromResult(Lookup<FoodSearchResult>.Fail(LookupStatus.NotConfigured));
        return RememberAsync($"usda:{query.ToLowerInvariant()}", async () =>
        {
            // Basic foods first, then branded ones: asked for separately, because the branded catalogue is so much
            // larger that it would otherwise push every basic food off the first page.
            var generic = await UsdaAsync(query, UsdaProvider.Generic, 15);
            if (generic.Status != LookupStatus.Ok) return Lookup<FoodSearchResult>.Fail(generic.Status);
            var branded = await UsdaAsync(query, UsdaProvider.Branded, 10);
            // Branded results are an extra. Without them the basic foods are still a complete, honest answer.
            return Lookup<FoodSearchResult>.Ok(new([.. generic.Value!, .. branded.Value ?? []]));
        }, ct);
    }

    private Task<Lookup<List<FoodItem>>> UsdaAsync(string query, string dataTypes, int pageSize) =>
        CallAsync(_usdaBudget, () => _usdaQuietUntil, t => _usdaQuietUntil = t, "USDA FoodData Central", token => _usda.SearchAsync(query, dataTypes, pageSize, token));

    /// <summary>
    /// Returns a remembered answer, joins an identical request already in flight, or makes the call. The shared call
    /// is not tied to one caller's request: someone leaving the screen must not fail it for the others waiting.
    /// </summary>
    private async Task<Lookup<T>> RememberAsync<T>(string key, Func<Task<Lookup<T>>> load, CancellationToken ct)
    {
        if (_cache.TryGetValue(key, out Lookup<T>? cached)) return cached!;
        var shared = _inFlight.GetOrAdd(key, k => new Lazy<Task<object>>(async () =>
        {
            try
            {
                var result = await load();
                if (result.IsCacheable) _cache.Set(key, result, new MemoryCacheEntryOptions { Size = 1, AbsoluteExpirationRelativeToNow = result.Status == LookupStatus.Ok ? Found : Missing });
                return result;
            }
            finally { _inFlight.TryRemove(key, out _); }
        }));
        return (Lookup<T>)await shared.Value.WaitAsync(ct);
    }

    /// <summary>One provider call inside its budget, with a bounded wait and one retry for a failure that may pass.</summary>
    private async Task<Lookup<T>> CallAsync<T>(RateLimiter budget, Func<DateTimeOffset> quietUntil, Action<DateTimeOffset> setQuiet, string provider, Func<CancellationToken, Task<Lookup<T>>> call)
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
        _offBudget.Dispose();
        _usdaBudget.Dispose();
    }
}
