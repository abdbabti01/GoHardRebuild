using GoHard.Api.Application.Coach;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application.Plus;

/// <summary>
/// Configuration section "Plus" (docs/PLUS_PREVIEW.md). Testing values, not commercial quotas. PreviewOwnerUserId is the
/// one account that may switch its own tier through the preview routes; empty means nobody can.
/// </summary>
public sealed class PlusOptions
{
    public string? PreviewOwnerUserId { get; set; }
    public int FreeMonthlyAi { get; set; } = 15;
    public int PlusMonthlyAi { get; set; } = 300;
    public int FreeSavedPlans { get; set; } = 3;
    public int FreeSavedMeals { get; set; } = 10;
    /// <summary>Technical safety caps for every tier.</summary>
    public int MaxSavedPlans { get; set; } = 200;
    public int MaxSavedMeals { get; set; } = 500;
    /// <summary>How long the app may use its last answer (docs/PLUS_PREVIEW.md › App).</summary>
    public int CacheHours { get; set; } = 72;

    public Guid? Owner => Guid.TryParse(PreviewOwnerUserId, out var id) && id != Guid.Empty ? id : null;
}

public enum Tier { Free, Plus }

/// <summary>What an account may use, and where that came from. The one model every check reads.</summary>
public sealed record Entitlement(Tier Tier, string Source)
{
    public bool IsPlus => Tier == Tier.Plus;
}

public sealed record AllowanceDto(int Used, int Limit, int Remaining, DateTime PeriodStartUtc, DateTime ResetsAtUtc, int DailyGuard);
/// <summary>Product creation limits; null = none (the technical caps still apply).</summary>
public sealed record PlusLimitsDto(int? SavedPlans, int? SavedMeals);
/// <summary>What each tier includes, for the comparison: product limits (null = none) and the monthly AI allowance.</summary>
public sealed record TierDto(int? SavedPlans, int? SavedMeals, int MonthlyAi);
public sealed record EntitlementDto(string Tier, string Source, bool Preview, bool PurchasesAvailable, PlusLimitsDto Limits,
    IReadOnlyList<string> Features, AllowanceDto Allowance, bool CanManagePreview, DateTime IssuedAtUtc, int ValidForSeconds,
    IReadOnlyDictionary<string, TierDto> Compare);
public sealed record PreviewTierRequest(string? Tier);

/// <summary>
/// Resolves an account's entitlement from its sources and enforces what it allows. Today the only source besides the
/// Free default is the owner's preview override; a verified purchase becomes another source here, and nothing that
/// reads <see cref="Entitlement"/> changes. Nothing a client sends is ever a source.
/// </summary>
public sealed class EntitlementService(GoHardDb db, PlusOptions options, CoachOptions coach, TimeProvider time)
{
    public const string Capability = "account.entitlement";
    public const string PlanLimit = "PLAN_LIMIT", MealLimit = "MEAL_LIMIT";
    public const string Progression = "progression.suggestions", TrendExplorer = "trends.explorer";

    public async Task<Entitlement> ResolveAsync(Guid userId, CancellationToken ct)
    {
        // The override counts only for the configured owner: a row left behind for anyone else grants nothing.
        if (options.Owner == userId && await db.PreviewOverrides.AsNoTracking().AnyAsync(o => o.UserId == userId && o.Tier == "plus", ct))
            return new(Tier.Plus, "preview_override");
        return new(Tier.Free, "default");
    }

    /// <summary>The calendar month (UTC) holding <paramref name="nowUtc"/>: [start, next month's start).</summary>
    public static (DateTime Start, DateTime End) Month(DateTime nowUtc)
    {
        var start = new DateTime(nowUtc.Year, nowUtc.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        return (start, start.AddMonths(1));
    }

    public int MonthlyLimit(Entitlement e) => e.IsPlus ? options.PlusMonthlyAi : options.FreeMonthlyAi;

    /// <summary>This month's successful provider-backed requests, by the server's clock only.</summary>
    public async Task<AllowanceDto> AllowanceAsync(Guid userId, Entitlement e, CancellationToken ct)
    {
        var (start, end) = Month(time.GetUtcNow().UtcDateTime);
        var reset = await db.PreviewOverrides.AsNoTracking().Where(o => o.UserId == userId).Select(o => o.AllowanceResetAtUtc).FirstOrDefaultAsync(ct);
        var from = reset is { } r && r > start ? r : start;
        var used = await db.AiUsage.CountAsync(u => u.UserId == userId && u.Counted && u.AtUtc >= from && u.AtUtc < end, ct);
        var limit = MonthlyLimit(e);
        return new(used, limit, Math.Max(0, limit - used), from, end, coach.DailyLimit);
    }

    public async Task<bool> HasAllowanceAsync(Guid userId, CancellationToken ct) =>
        (await AllowanceAsync(userId, await ResolveAsync(userId, ct), ct)).Remaining > 0;

    public async Task<EntitlementDto> DescribeAsync(Guid userId, CancellationToken ct)
    {
        var e = await ResolveAsync(userId, ct);
        return new(e.IsPlus ? "plus" : "free", e.Source, Preview: true, PurchasesAvailable: false,
            e.IsPlus ? new(null, null) : new(options.FreeSavedPlans, options.FreeSavedMeals),
            e.IsPlus ? [Progression, TrendExplorer] : [], await AllowanceAsync(userId, e, ct), options.Owner == userId,
            time.GetUtcNow().UtcDateTime, options.CacheHours * 3600, new Dictionary<string, TierDto>
            {
                ["free"] = new(options.FreeSavedPlans, options.FreeSavedMeals, options.FreeMonthlyAi), ["plus"] = new(null, null, options.PlusMonthlyAi),
            });
    }

    // ---------------------------------------------------------------- creation limits (inside the command's account lock)

    /// <summary>PLAN_LIMIT when one more saved plan (not archived, any lifecycle) would pass this account's limit.</summary>
    public async Task<string?> PlanRefusalAsync(Guid userId, CancellationToken ct)
    {
        var limit = (await ResolveAsync(userId, ct)).IsPlus ? options.MaxSavedPlans : Math.Min(options.FreeSavedPlans, options.MaxSavedPlans);
        return await db.Plans.CountAsync(p => p.UserId == userId && !p.IsArchived, ct) >= limit ? PlanLimit : null;
    }

    /// <summary>MEAL_LIMIT when one more saved meal or recipe (not deleted) would pass this account's limit.</summary>
    public async Task<string?> MealRefusalAsync(Guid userId, CancellationToken ct)
    {
        var limit = (await ResolveAsync(userId, ct)).IsPlus ? options.MaxSavedMeals : Math.Min(options.FreeSavedMeals, options.MaxSavedMeals);
        return await db.SavedMeals.CountAsync(m => m.UserId == userId && m.DeletedAtUtc == null, ct) >= limit ? MealLimit : null;
    }

    // ---------------------------------------------------------------- preview management (the configured owner only)

    /// <summary>False (and nothing written) unless <paramref name="userId"/> is the configured preview owner.</summary>
    public async Task<bool> SetPreviewTierAsync(Guid userId, string tier, CancellationToken ct) =>
        await ChangeAsync(userId, o => o.Tier = tier, ct);

    public async Task<bool> ResetAllowanceAsync(Guid userId, CancellationToken ct) =>
        await ChangeAsync(userId, o => o.AllowanceResetAtUtc = time.GetUtcNow().UtcDateTime, ct);

    private async Task<bool> ChangeAsync(Guid userId, Action<PreviewOverride> change, CancellationToken ct)
    {
        if (options.Owner != userId) return false;
        var row = await db.PreviewOverrides.FirstOrDefaultAsync(o => o.UserId == userId, ct);
        if (row is null) db.PreviewOverrides.Add(row = new PreviewOverride { UserId = userId });
        change(row);
        row.UpdatedAtUtc = time.GetUtcNow().UtcDateTime;
        await db.SaveChangesAsync(ct);
        return true;
    }
}

/// <summary>
/// The monthly AI allowance as the singleton coach sees it: checked before a provider call and recorded after one, each
/// in its own short database scope. A request is charged at most once (partial unique index), whatever retries do.
/// </summary>
public sealed class AiAllowance(IServiceScopeFactory scopes, TimeProvider time, ILogger<AiAllowance> log)
{
    public async Task<bool> HasRoomAsync(Guid userId, CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<EntitlementService>().HasAllowanceAsync(userId, ct);
    }

    /// <summary>Records one request that reached the provider. Never throws: a lost record must not lose the answer.</summary>
    public async Task RecordAsync(Guid userId, string scope, Guid requestId, bool counted)
    {
        try
        {
            await using var s = scopes.CreateAsyncScope();
            var db = s.ServiceProvider.GetRequiredService<GoHardDb>();
            var at = time.GetUtcNow().UtcDateTime;
            await db.Database.ExecuteSqlAsync($"""
                INSERT INTO "AiUsage" ("UserId", "Scope", "RequestId", "AtUtc", "Counted") VALUES ({userId}, {scope}, {requestId}, {at}, {counted})
                ON CONFLICT ("UserId", "Scope", "RequestId") WHERE "Counted" DO NOTHING
                """);
        }
        catch (Exception ex) { log.LogError(ex, "AI usage could not be recorded"); }
    }
}

public static class PlusRegistration
{
    public static IServiceCollection AddPlus(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(config.GetSection("Plus").Get<PlusOptions>() ?? new());
        services.AddScoped<EntitlementService>();
        services.AddSingleton<AiAllowance>();
        return services;
    }
}
