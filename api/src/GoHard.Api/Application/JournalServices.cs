using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>Consumed food. One entry is one deliberate consumption; blank nutrients stay unknown.</summary>
public sealed class FoodService(GoHardDb db)
{
    public static readonly string[] Meals = ["Breakfast", "Lunch", "Dinner", "Snack"];

    public static FoodEntryDto ToDto(FoodEntry f) => new(f.Id, f.DayKey, f.Meal, f.Name, f.AmountDescription,
        new(f.Calories, f.ProteinG, f.CarbsG, f.FatG), new(f.CaloriesSource, f.ProteinSource, f.CarbsSource, f.FatSource),
        f.Revision, f.DeletedAtUtc != null);

    private static bool Valid(string meal, string name, string amount, Macros? m) =>
        Meals.Contains(meal) && name?.Trim().Length is > 0 and <= 120 && amount?.Trim().Length is > 0 and <= 80 && m is not null &&
        new[] { m.Calories, m.Protein, m.Carbs, m.Fat }.All(v => v is null or >= 0 and <= 100000);

    private static void Apply(FoodEntry f, DateOnly day, string meal, string name, string amount, Macros m)
    {
        (f.DayKey, f.Meal, f.Name, f.AmountDescription) = (day, meal, name.Trim(), amount.Trim());
        (f.Calories, f.ProteinG, f.CarbsG, f.FatG) = (m.Calories, m.Protein, m.Carbs, m.Fat);
        // Knowledge is recorded per nutrient: a value the user typed (including 0) is entered, a blank is unknown.
        static string Source(decimal? v) => v is null ? "unknown" : "entered";
        (f.CaloriesSource, f.ProteinSource, f.CarbsSource, f.FatSource) = (Source(m.Calories), Source(m.Protein), Source(m.Carbs), Source(m.Fat));
    }

    public async Task<Outcome<FoodEntryDto>> CreateAsync(Guid userId, FoodCreateRequest r, CancellationToken ct)
    {
        if (r.EntryId == Guid.Empty || !Valid(r.Meal, r.Name, r.AmountDescription, r.Macros)) return Outcome.Rejected<FoodEntryDto>(Ack.Invalid);
        if (await db.FoodEntries.AnyAsync(f => f.Id == r.EntryId, ct)) return Outcome.Conflict<FoodEntryDto>("DUPLICATE_ID");
        var entry = new FoodEntry { Id = r.EntryId, UserId = userId, CreatedAtUtc = DateTime.UtcNow };
        Apply(entry, r.DayKey, r.Meal, r.Name, r.AmountDescription, r.Macros);
        db.FoodEntries.Add(entry);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(entry.Revision, ToDto(entry));
    }

    public async Task<Outcome<FoodEntryDto>> UpdateAsync(Guid userId, Guid id, FoodUpdateRequest r, CancellationToken ct)
    {
        var entry = await db.FoodEntries.FirstOrDefaultAsync(f => f.Id == id && f.UserId == userId, ct);
        if (entry is null) return Outcome.NotFound<FoodEntryDto>();
        if (!Valid(r.Meal, r.Name, r.AmountDescription, r.Macros)) return Outcome.Rejected<FoodEntryDto>(Ack.Invalid);
        if (entry.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", entry.Revision, ToDto(entry));
        if (entry.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, entry.Revision, ToDto(entry));
        Apply(entry, r.DayKey, r.Meal, r.Name, r.AmountDescription, r.Macros);
        entry.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(entry.Revision, ToDto(entry));
    }

    public async Task<Outcome<FoodEntryDto>> DeleteAsync(Guid userId, Guid id, RevisionCommand r, CancellationToken ct)
    {
        var entry = await db.FoodEntries.FirstOrDefaultAsync(f => f.Id == id && f.UserId == userId, ct);
        if (entry is null) return Outcome.NotFound<FoodEntryDto>();
        if (entry.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", entry.Revision, ToDto(entry));
        if (entry.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, entry.Revision, ToDto(entry));
        entry.DeletedAtUtc = DateTime.UtcNow;
        entry.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(entry.Revision, ToDto(entry));
    }

    public async Task<List<FoodEntryDto>> ListAsync(Guid userId, DateOnly? day, CancellationToken ct) =>
        (await db.FoodEntries.AsNoTracking().Where(f => f.UserId == userId && (day == null || (f.DayKey == day && f.DeletedAtUtc == null)))
            .OrderBy(f => f.CreatedAtUtc).ToListAsync(ct)).Select(ToDto).ToList();
}

/// <summary>Supporting activity records: manually timed runs and optional body measurements.</summary>
public sealed class ActivityService(GoHardDb db)
{
    public static RunDto ToDto(Run r) => new(r.Id, r.DayKey, r.StartedAtUtc, r.FinishedAtUtc, r.ActiveDurationSeconds, r.DistanceMeters, r.Revision, r.DeletedAtUtc != null);
    public static BodyMetricDto ToDto(BodyMetric m) => new(m.Id, m.DayKey, m.WeightKg, m.BodyFatPercent, m.Note, m.Revision, m.DeletedAtUtc != null);

    public async Task<Outcome<RunDto>> StartRunAsync(Guid userId, RunStartRequest r, CancellationToken ct)
    {
        if (r.RunId == Guid.Empty) return Outcome.Rejected<RunDto>(Ack.Invalid);
        if (await db.Runs.AnyAsync(x => x.Id == r.RunId, ct)) return Outcome.Conflict<RunDto>("DUPLICATE_ID");
        var run = new Run { Id = r.RunId, UserId = userId, DayKey = r.DayKey, StartedAtUtc = WorkoutService.Utc(r.StartedAtUtc) };
        db.Runs.Add(run);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    public async Task<Outcome<RunDto>> FinishRunAsync(Guid userId, Guid id, RunFinishRequest r, CancellationToken ct)
    {
        var run = await db.Runs.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId && x.DeletedAtUtc == null, ct);
        if (run is null) return Outcome.NotFound<RunDto>();
        if (r.ActiveDurationSeconds is < 0 or > 604800 || r.DistanceMeters is < 0 or > 1000000) return Outcome.Rejected<RunDto>(Ack.Invalid);
        if (run.FinishedAtUtc != null) return Outcome.Conflict("ALREADY_FINISHED", run.Revision, ToDto(run));
        if (run.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, run.Revision, ToDto(run));
        (run.FinishedAtUtc, run.ActiveDurationSeconds, run.DistanceMeters) = (WorkoutService.Utc(r.FinishedAtUtc), r.ActiveDurationSeconds, r.DistanceMeters);
        run.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    public async Task<Outcome<RunDto>> DeleteRunAsync(Guid userId, Guid id, RevisionCommand r, CancellationToken ct)
    {
        var run = await db.Runs.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (run is null) return Outcome.NotFound<RunDto>();
        if (run.DeletedAtUtc != null || run.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, run.Revision, ToDto(run));
        run.DeletedAtUtc = DateTime.UtcNow; run.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    public async Task<Outcome<BodyMetricDto>> AddMetricAsync(Guid userId, BodyMetricRequest r, CancellationToken ct)
    {
        if (r.MetricId == Guid.Empty || (r.WeightKg is null && r.BodyFatPercent is null) || r.WeightKg is <= 0 or > 700 ||
            r.BodyFatPercent is < 0 or > 100 || r.Note?.Length > 200) return Outcome.Rejected<BodyMetricDto>(Ack.Invalid);
        if (await db.BodyMetrics.AnyAsync(x => x.Id == r.MetricId, ct)) return Outcome.Conflict<BodyMetricDto>("DUPLICATE_ID");
        var m = new BodyMetric { Id = r.MetricId, UserId = userId, DayKey = r.DayKey, WeightKg = r.WeightKg, BodyFatPercent = r.BodyFatPercent, Note = r.Note };
        db.BodyMetrics.Add(m);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(m.Revision, ToDto(m));
    }

    public async Task<Outcome<BodyMetricDto>> DeleteMetricAsync(Guid userId, Guid id, RevisionCommand r, CancellationToken ct)
    {
        var m = await db.BodyMetrics.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (m is null) return Outcome.NotFound<BodyMetricDto>();
        if (m.DeletedAtUtc != null || m.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, m.Revision, ToDto(m));
        m.DeletedAtUtc = DateTime.UtcNow; m.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(m.Revision, ToDto(m));
    }
}

public sealed class AccountService(GoHardDb db)
{
    public async Task<Outcome<ProfileDto>> UpdateProfileAsync(Guid userId, ProfileUpdateRequest r, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        var name = (r.DisplayName ?? "").Trim();
        if (name.Length is 0 or > 80 || r.Appearance is not ("dark" or "light" or "system") || r.LoadUnit is not ("kg" or "lb") ||
            (r.ReminderLocalTime is not null && !TimeOnly.TryParseExact(r.ReminderLocalTime, "HH:mm", out _)))
            return Outcome.Rejected<ProfileDto>(Ack.Invalid);
        if (user.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, user.Revision, AuthService.ToProfile(user));
        (user.DisplayName, user.Appearance, user.LoadUnit, user.RemindersEnabled, user.ReminderLocalTime) =
            (name, r.Appearance, r.LoadUnit, r.RemindersEnabled, r.ReminderLocalTime);
        user.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(user.Revision, AuthService.ToProfile(user));
    }

    /// <summary>
    /// Confirmed erasure of the authenticated account and everything it owns, in one transaction.
    /// Distinct from logout, which keeps all data. Returns false when the password is wrong.
    /// </summary>
    public async Task<bool> DeleteOwnAccountAsync(Guid userId, string password, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        if (!AuthService.VerifyPassword(user, password)) return false;
        await db.Users.Where(u => u.Id == userId).ExecuteDeleteAsync(ct); // owned rows cascade in the database
        return true;
    }
}
