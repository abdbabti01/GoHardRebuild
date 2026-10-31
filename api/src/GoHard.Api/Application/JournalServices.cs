using System.Text.Json;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>Consumed food. One entry is one deliberate consumption; blank nutrients stay unknown.</summary>
public sealed class FoodService(GoHardDb db)
{
    public static readonly string[] Meals = ["Breakfast", "Lunch", "Dinner", "Snack"];

    public static FoodEntryDto ToDto(FoodEntry f) => new(f.Id, f.DayKey, f.Meal, f.Name, f.AmountDescription,
        new(f.Calories, f.ProteinG, f.CarbsG, f.FatG), new(f.CaloriesSource, f.ProteinSource, f.CarbsSource, f.FatSource),
        f.Revision, f.DeletedAtUtc != null, f.SourceJson is null ? null : JsonSerializer.Deserialize<JsonElement>(f.SourceJson));

    public const int SnapshotLimit = 16000;

    /// <summary>A recipe portion carries its whole batch (ingredients, yield, portion), so it may be larger; it is still bounded.</summary>
    public const int CompositeSnapshotLimit = 48000;

    /// <summary>The most entries one atomic log may hold (a saved meal's components).</summary>
    public const int MaxBatchEntries = 30;

    /// <summary>A snapshot is the owner's own record of where values came from: an object of bounded size, stored as given.</summary>
    public static bool ValidSnapshot(JsonElement? e) => e is null || (e.Value.ValueKind == JsonValueKind.Object &&
        e.Value.GetRawText().Length <= (e.Value.TryGetProperty("recipe", out _) ? CompositeSnapshotLimit : SnapshotLimit));

    private static bool Valid(string meal, string name, string amount, Macros? m, JsonElement? source, MacroProvenance? p) =>
        Meals.Contains(meal) && name?.Trim().Length is > 0 and <= 120 && amount?.Trim().Length is > 0 and <= 80 && m is not null &&
        new[] { m.Calories, m.Protein, m.Carbs, m.Fat }.All(v => v is null or >= 0 and <= 100000) && ValidSnapshot(source) &&
        // Stated provenance has to agree with the values: unknown exactly when there is none, and imported only with a source.
        (p is null || new[] { (m.Calories, p.Calories), (m.Protein, p.Protein), (m.Carbs, p.Carbs), (m.Fat, p.Fat) }.All(x =>
            x.Item1 is null ? x.Item2 == "unknown" : x.Item2 == "entered" || (x.Item2 == "imported" && source is not null)));

    private static void Apply(FoodEntry f, DateOnly day, string meal, string name, string amount, Macros m, JsonElement? source, MacroProvenance? p)
    {
        f.SourceJson = source?.GetRawText();
        (f.DayKey, f.Meal, f.Name, f.AmountDescription) = (day, meal, name.Trim(), amount.Trim());
        (f.Calories, f.ProteinG, f.CarbsG, f.FatG) = (m.Calories, m.Protein, m.Carbs, m.Fat);
        // Knowledge is recorded per nutrient: a value the user typed (including 0) is entered, a blank is unknown.
        static string Source(decimal? v) => v is null ? "unknown" : "entered";
        (f.CaloriesSource, f.ProteinSource, f.CarbsSource, f.FatSource) = p is null
            ? (Source(m.Calories), Source(m.Protein), Source(m.Carbs), Source(m.Fat))
            : (p.Calories, p.Protein, p.Carbs, p.Fat);
    }

    public async Task<Outcome<FoodEntryDto>> CreateAsync(Guid userId, FoodCreateRequest r, CancellationToken ct)
    {
        if (r.EntryId == Guid.Empty || !Valid(r.Meal, r.Name, r.AmountDescription, r.Macros, r.Source, r.Provenance)) return Outcome.Rejected<FoodEntryDto>(Ack.Invalid);
        if (await db.FoodEntries.AnyAsync(f => f.Id == r.EntryId, ct)) return Outcome.Conflict<FoodEntryDto>("DUPLICATE_ID");
        var entry = new FoodEntry { Id = r.EntryId, UserId = userId, CreatedAtUtc = DateTime.UtcNow };
        Apply(entry, r.DayKey, r.Meal, r.Name, r.AmountDescription, r.Macros, r.Source, r.Provenance);
        db.FoodEntries.Add(entry);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(entry.Revision, ToDto(entry));
    }

    /// <summary>
    /// A saved meal logged as one operation (inside the command's transaction): every entry is checked first, and one
    /// invalid entry or a reused ID records none of them.
    /// </summary>
    public async Task<Outcome<FoodBatchResult>> CreateManyAsync(Guid userId, FoodBatchRequest r, CancellationToken ct)
    {
        if (r.Entries is not { Count: > 0 and <= MaxBatchEntries } || r.Entries.Select(e => e.EntryId).Distinct().Count() != r.Entries.Count ||
            r.Entries.Any(e => e is null || e.EntryId == Guid.Empty || !Valid(e.Meal, e.Name, e.AmountDescription, e.Macros, e.Source, e.Provenance)))
            return Outcome.Rejected<FoodBatchResult>(Ack.Invalid);
        var ids = r.Entries.Select(e => e.EntryId).ToList();
        if (await db.FoodEntries.AnyAsync(f => ids.Contains(f.Id), ct)) return Outcome.Conflict<FoodBatchResult>("DUPLICATE_ID");
        var made = new List<FoodEntry>();
        var now = DateTime.UtcNow;
        foreach (var e in r.Entries)
        {
            var entry = new FoodEntry { Id = e.EntryId, UserId = userId, CreatedAtUtc = now.AddTicks(made.Count * 10) }; // 1 µs apart (the database keeps microseconds): the meal's order
            Apply(entry, e.DayKey, e.Meal, e.Name, e.AmountDescription, e.Macros, e.Source, e.Provenance);
            made.Add(entry);
        }
        db.FoodEntries.AddRange(made);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(1, new FoodBatchResult(made.Select(ToDto).ToList()));
    }

    public async Task<Outcome<FoodEntryDto>> UpdateAsync(Guid userId, Guid id, FoodUpdateRequest r, CancellationToken ct)
    {
        var entry = await db.FoodEntries.FirstOrDefaultAsync(f => f.Id == id && f.UserId == userId, ct);
        if (entry is null) return Outcome.NotFound<FoodEntryDto>();
        if (!Valid(r.Meal, r.Name, r.AmountDescription, r.Macros, r.Source, r.Provenance)) return Outcome.Rejected<FoodEntryDto>(Ack.Invalid);
        if (entry.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", entry.Revision, ToDto(entry));
        if (entry.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, entry.Revision, ToDto(entry));
        Apply(entry, r.DayKey, r.Meal, r.Name, r.AmountDescription, r.Macros, r.Source, r.Provenance);
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

/// <summary>Water the person logs on purpose, in canonical millilitres. Never counted from foods.</summary>
public sealed class WaterService(GoHardDb db)
{
    public static WaterEntryDto ToDto(WaterEntry w) => new(w.Id, w.DayKey, w.VolumeMl, w.Revision, w.DeletedAtUtc != null);

    private static bool Valid(decimal ml) => ml is > 0 and <= 5000 && decimal.Truncate(ml * 1000) == ml * 1000;   // at most 3 decimals

    public async Task<Outcome<WaterEntryDto>> CreateAsync(Guid userId, WaterCreateRequest r, CancellationToken ct)
    {
        if (r.EntryId == Guid.Empty || !Valid(r.VolumeMl)) return Outcome.Rejected<WaterEntryDto>(Ack.Invalid);
        if (await db.WaterEntries.AnyAsync(w => w.Id == r.EntryId, ct)) return Outcome.Conflict<WaterEntryDto>("DUPLICATE_ID");
        var entry = new WaterEntry { Id = r.EntryId, UserId = userId, DayKey = r.DayKey, VolumeMl = r.VolumeMl, CreatedAtUtc = DateTime.UtcNow };
        db.WaterEntries.Add(entry);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(entry.Revision, ToDto(entry));
    }

    public async Task<Outcome<WaterEntryDto>> UpdateAsync(Guid userId, Guid id, WaterUpdateRequest r, CancellationToken ct)
    {
        var entry = await db.WaterEntries.FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId, ct);
        if (entry is null) return Outcome.NotFound<WaterEntryDto>();
        if (!Valid(r.VolumeMl)) return Outcome.Rejected<WaterEntryDto>(Ack.Invalid);
        if (entry.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", entry.Revision, ToDto(entry));
        if (entry.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, entry.Revision, ToDto(entry));
        (entry.DayKey, entry.VolumeMl) = (r.DayKey, r.VolumeMl);
        entry.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(entry.Revision, ToDto(entry));
    }

    public async Task<Outcome<WaterEntryDto>> DeleteAsync(Guid userId, Guid id, RevisionCommand r, CancellationToken ct)
    {
        var entry = await db.WaterEntries.FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId, ct);
        if (entry is null) return Outcome.NotFound<WaterEntryDto>();
        if (entry.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", entry.Revision, ToDto(entry));
        if (entry.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, entry.Revision, ToDto(entry));
        entry.DeletedAtUtc = DateTime.UtcNow;
        entry.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(entry.Revision, ToDto(entry));
    }

    public async Task<List<WaterEntryDto>> ListAsync(Guid userId, DateOnly? day, CancellationToken ct) =>
        (await db.WaterEntries.AsNoTracking().Where(w => w.UserId == userId && (day == null || (w.DayKey == day && w.DeletedAtUtc == null)))
            .OrderBy(w => w.CreatedAtUtc).ToListAsync(ct)).Select(ToDto).ToList();
}

/// <summary>Reusable foods and favourites. Owned, revision-checked, and never a record of anything eaten.</summary>
public sealed class SavedFoodService(GoHardDb db)
{
    public static SavedFoodDto ToDto(SavedFood f) => new(f.Id, JsonSerializer.Deserialize<JsonElement>(f.ItemJson), f.IsFavourite, f.Revision, f.DeletedAtUtc != null);

    private static bool Valid(JsonElement item) =>
        FoodService.ValidSnapshot(item) && item.TryGetProperty("name", out var name) && name.ValueKind == JsonValueKind.String &&
        name.GetString()!.Trim().Length is > 0 and <= 120;

    public async Task<Outcome<SavedFoodDto>> PutAsync(Guid userId, Guid id, SavedFoodPutRequest r, CancellationToken ct)
    {
        if (id == Guid.Empty || !Valid(r.Item)) return Outcome.Rejected<SavedFoodDto>(Ack.Invalid);
        var food = await db.SavedFoods.FirstOrDefaultAsync(f => f.Id == id, ct);
        if (food is not null && food.UserId != userId) return Outcome.NotFound<SavedFoodDto>();
        if (food is null)
        {
            if (r.ExpectedRevision != 0) return Outcome.NotFound<SavedFoodDto>();
            food = new SavedFood { Id = id, UserId = userId, CreatedAtUtc = DateTime.UtcNow, Revision = 0 };
            db.SavedFoods.Add(food);
        }
        else if (food.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, food.Revision, ToDto(food));
        else if (food.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", food.Revision, ToDto(food));
        (food.ItemJson, food.IsFavourite) = (r.Item.GetRawText(), r.IsFavourite);
        food.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(food.Revision, ToDto(food));
    }

    public async Task<Outcome<SavedFoodDto>> DeleteAsync(Guid userId, Guid id, RevisionCommand r, CancellationToken ct)
    {
        var food = await db.SavedFoods.FirstOrDefaultAsync(f => f.Id == id && f.UserId == userId, ct);
        if (food is null) return Outcome.NotFound<SavedFoodDto>();
        if (food.DeletedAtUtc != null || food.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, food.Revision, ToDto(food));
        food.DeletedAtUtc = DateTime.UtcNow; food.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(food.Revision, ToDto(food));
    }

    public async Task<List<SavedFoodDto>> ListAsync(Guid userId, CancellationToken ct) =>
        (await db.SavedFoods.AsNoTracking().Where(f => f.UserId == userId).OrderBy(f => f.CreatedAtUtc).ToListAsync(ct)).Select(ToDto).ToList();
}

/// <summary>
/// Saved meals and recipes (docs/FOOD_DATA.md › Saved meals and recipes). Owned, revision-checked templates with
/// tombstones, like saved foods. Never a record of anything eaten, and never read to work out logged food.
/// </summary>
public sealed class SavedMealService(GoHardDb db, Plus.EntitlementService plus)
{
    public const string Capability = "food.saved-meals";
    public const int MaxComponents = 30, BodyLimit = FoodService.CompositeSnapshotLimit;

    public static SavedMealDto ToDto(SavedMeal m) => new(m.Id, JsonSerializer.Deserialize<JsonElement>(m.BodyJson), m.Revision, m.DeletedAtUtc != null);

    private static bool Positive(JsonElement e, string name, decimal max, bool optional = false) =>
        !e.TryGetProperty(name, out var v) || v.ValueKind == JsonValueKind.Null
            ? optional
            : v.ValueKind == JsonValueKind.Number && v.TryGetDecimal(out var d) && d > 0 && d <= max;

    /// <summary>A meal or a recipe with a name, 1–30 components (each a food snapshot with a positive amount and a unit),
    /// and for a recipe a positive yield; an optional prepared weight is positive too. Bounded in size.</summary>
    public static bool Valid(JsonElement body)
    {
        if (body.ValueKind != JsonValueKind.Object || body.GetRawText().Length > BodyLimit) return false;
        if (!body.TryGetProperty("kind", out var kind) || kind.GetString() is not ("meal" or "recipe")) return false;
        if (!body.TryGetProperty("name", out var name) || name.ValueKind != JsonValueKind.String || name.GetString()!.Trim().Length is 0 or > 120) return false;
        if (!body.TryGetProperty("components", out var parts) || parts.ValueKind != JsonValueKind.Array || parts.GetArrayLength() is 0 or > MaxComponents) return false;
        foreach (var p in parts.EnumerateArray())
        {
            if (p.ValueKind != JsonValueKind.Object || !p.TryGetProperty("item", out var item) || item.ValueKind != JsonValueKind.Object ||
                !item.TryGetProperty("name", out var n) || n.ValueKind != JsonValueKind.String || !Positive(p, "quantity", 100000) ||
                !p.TryGetProperty("unit", out var unit) || unit.ValueKind != JsonValueKind.String) return false;
        }
        return kind.GetString() == "meal" || (Positive(body, "servings", 1000) && Positive(body, "preparedWeightG", 100000, optional: true));
    }

    public async Task<Outcome<SavedMealDto>> PutAsync(Guid userId, Guid id, SavedMealPutRequest r, CancellationToken ct)
    {
        if (id == Guid.Empty || !Valid(r.Body)) return Outcome.Rejected<SavedMealDto>(Ack.Invalid);
        var meal = await db.SavedMeals.FirstOrDefaultAsync(m => m.Id == id, ct);
        if (meal is not null && meal.UserId != userId) return Outcome.NotFound<SavedMealDto>();
        if (meal is null)
        {
            if (r.ExpectedRevision != 0) return Outcome.NotFound<SavedMealDto>();
            // Only a new definition counts toward the limit; editing, using or deleting one never does (docs/PLUS_PREVIEW.md).
            if (await plus.MealRefusalAsync(userId, ct) is { } limit) return Outcome.Rejected<SavedMealDto>(limit);
            meal = new SavedMeal { Id = id, UserId = userId, CreatedAtUtc = DateTime.UtcNow, Revision = 0 };
            db.SavedMeals.Add(meal);
        }
        else if (meal.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, meal.Revision, ToDto(meal));
        else if (meal.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", meal.Revision, ToDto(meal));
        meal.BodyJson = r.Body.GetRawText();
        meal.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(meal.Revision, ToDto(meal));
    }

    /// <summary>Removes it from future use. Food logged from it keeps its own snapshot and is untouched.</summary>
    public async Task<Outcome<SavedMealDto>> DeleteAsync(Guid userId, Guid id, RevisionCommand r, CancellationToken ct)
    {
        var meal = await db.SavedMeals.FirstOrDefaultAsync(m => m.Id == id && m.UserId == userId, ct);
        if (meal is null) return Outcome.NotFound<SavedMealDto>();
        if (meal.DeletedAtUtc != null || meal.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, meal.Revision, ToDto(meal));
        meal.DeletedAtUtc = DateTime.UtcNow; meal.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(meal.Revision, ToDto(meal));
    }

    public async Task<List<SavedMealDto>> ListAsync(Guid userId, CancellationToken ct) =>
        (await db.SavedMeals.AsNoTracking().Where(m => m.UserId == userId).OrderBy(m => m.CreatedAtUtc).ToListAsync(ct)).Select(ToDto).ToList();
}

/// <summary>Supporting activity records: Run / Walk activities with their routes (docs/RUN_WALK.md) and optional body measurements.</summary>
public sealed class ActivityService(GoHardDb db)
{
    public static readonly string[] Types = ["run", "walk"];
    public const int ChunkSize = 500, MaxChunks = 10000, RoutePageLimit = 20;

    public static RunDto ToDto(Run r) => new(r.Id, r.DayKey, r.StartedAtUtc, r.FinishedAtUtc, r.ActiveDurationSeconds, r.DistanceMeters, r.Revision, r.DeletedAtUtc != null,
        r.ActivityType, r.Title, r.Notes, r.MetricsJson is null ? null : JsonSerializer.Deserialize<JsonElement>(r.MetricsJson), r.RouteState, r.RouteChunkCount);
    public static BodyMetricDto ToDto(BodyMetric m) => new(m.Id, m.DayKey, m.WeightKg, m.BodyFatPercent, m.Note, m.Revision, m.DeletedAtUtc != null,
        m.WaistCm, m.ChestCm, m.LeftUpperArmCm, m.RightUpperArmCm, m.LeftThighCm, m.RightThighCm, m.RecordedAtUtc);

    /// <summary>Title 1–80 characters, notes up to 1,000, metrics a JSON object of at most 4,000 characters; each optional.</summary>
    private static bool ValidDetails(string? title, string? notes, JsonElement? metrics) =>
        (title is null || title.Trim().Length is > 0 and <= 80) && (notes is null || notes.Length <= 1000) &&
        (metrics is null || (metrics.Value.ValueKind == JsonValueKind.Object && metrics.Value.GetRawText().Length <= 4000));

    private static void SetDetails(Run run, string? title, string? notes, JsonElement? metrics)
    {
        if (title is not null) run.Title = title.Trim();
        if (notes is not null) run.Notes = notes.Length == 0 ? null : notes;
        if (metrics is not null) run.MetricsJson = metrics.Value.GetRawText();
    }

    private Task<Run?> Owned(Guid userId, Guid id, CancellationToken ct) =>
        db.Runs.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId && x.DeletedAtUtc == null, ct);

    public async Task<Outcome<RunDto>> StartRunAsync(Guid userId, RunStartRequest r, CancellationToken ct)
    {
        if (r.RunId == Guid.Empty || (r.ActivityType is not null && !Types.Contains(r.ActivityType))) return Outcome.Rejected<RunDto>(Ack.Invalid);
        if (await db.Runs.AnyAsync(x => x.Id == r.RunId, ct)) return Outcome.Conflict<RunDto>("DUPLICATE_ID");
        var run = new Run { Id = r.RunId, UserId = userId, DayKey = r.DayKey, StartedAtUtc = WorkoutService.Utc(r.StartedAtUtc), ActivityType = r.ActivityType ?? "run" };
        db.Runs.Add(run);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    public async Task<Outcome<RunDto>> FinishRunAsync(Guid userId, Guid id, RunFinishRequest r, CancellationToken ct)
    {
        var run = await Owned(userId, id, ct);
        if (run is null) return Outcome.NotFound<RunDto>();
        if (r.ActiveDurationSeconds is < 0 or > 604800 || r.DistanceMeters is < 0 or > 1000000 || !ValidDetails(r.Title, r.Notes, r.Metrics)) return Outcome.Rejected<RunDto>(Ack.Invalid);
        if (run.FinishedAtUtc != null) return Outcome.Conflict("ALREADY_FINISHED", run.Revision, ToDto(run));
        if (run.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, run.Revision, ToDto(run));
        (run.FinishedAtUtc, run.ActiveDurationSeconds, run.DistanceMeters) = (WorkoutService.Utc(r.FinishedAtUtc), r.ActiveDurationSeconds, r.DistanceMeters);
        SetDetails(run, r.Title, r.Notes, r.Metrics);
        run.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    /// <summary>Edits a saved activity. The type changes only here, by the person's choice.</summary>
    public async Task<Outcome<RunDto>> UpdateRunAsync(Guid userId, Guid id, RunUpdateRequest r, CancellationToken ct)
    {
        var run = await Owned(userId, id, ct);
        if (run is null) return Outcome.NotFound<RunDto>();
        if (!Types.Contains(r.ActivityType) || r.DistanceMeters is < 0 or > 1000000 || !ValidDetails(r.Title, r.Notes, r.Metrics)) return Outcome.Rejected<RunDto>(Ack.Invalid);
        if (run.FinishedAtUtc == null) return Outcome.Conflict("RUN_OPEN", run.Revision, ToDto(run));
        if (run.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, run.Revision, ToDto(run));
        (run.ActivityType, run.DistanceMeters, run.Notes) = (r.ActivityType, r.DistanceMeters, string.IsNullOrEmpty(r.Notes) ? null : r.Notes);
        SetDetails(run, r.Title, null, r.Metrics);
        run.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    /// <summary>Deleting an activity erases its route on the account; a chunk arriving later finds no activity.</summary>
    public async Task<Outcome<RunDto>> DeleteRunAsync(Guid userId, Guid id, RevisionCommand r, CancellationToken ct)
    {
        var run = await db.Runs.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (run is null) return Outcome.NotFound<RunDto>();
        if (run.DeletedAtUtc != null || run.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, run.Revision, ToDto(run));
        await db.RouteChunks.Where(c => c.UserId == userId && c.RunId == id).ExecuteDeleteAsync(ct);
        run.DeletedAtUtc = DateTime.UtcNow; run.Revision++;
        (run.RouteState, run.RouteChunkCount) = ("none", 0);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    private static bool ValidEntries(int index, RouteChunkRequest r)
    {
        if (index is < 0 or >= MaxChunks || r.Entries is not { Count: > 0 and <= ChunkSize }) return false;
        int lo = index * ChunkSize, hi = lo + ChunkSize - 1, prev = -1;
        foreach (var e in r.Entries)
        {
            if (e.ValueKind != JsonValueKind.Object || !e.TryGetProperty("s", out var s) || !s.TryGetInt32(out var seq) || seq < lo || seq > hi || seq <= prev) return false;
            if (!e.TryGetProperty("t", out var t) || !t.TryGetInt64(out _) || !e.TryGetProperty("y", out var y) || y.ValueKind != JsonValueKind.String) return false;
            if (e.TryGetProperty("la", out var la) && (!la.TryGetDouble(out var lat) || lat is < -90 or > 90)) return false;
            if (e.TryGetProperty("lo", out var lg) && (!lg.TryGetDouble(out var lon) || lon is < -180 or > 180)) return false;
            prev = seq;
        }
        return r.FirstSeq == r.Entries[0].GetProperty("s").GetInt32() && r.LastSeq == prev;
    }

    /// <summary>Stores one route chunk. The same chunk again (a retry, a lost response) is accepted unchanged.</summary>
    public async Task<Outcome<RouteChunkResult>> PutRouteChunkAsync(Guid userId, Guid id, int index, RouteChunkRequest r, CancellationToken ct)
    {
        var run = await Owned(userId, id, ct);
        if (run is null) return Outcome.NotFound<RouteChunkResult>();
        if (!ValidEntries(index, r)) return Outcome.Rejected<RouteChunkResult>(Ack.Invalid);
        if (run.FinishedAtUtc == null) return Outcome.Conflict<RouteChunkResult>("RUN_OPEN", run.Revision);
        var json = JsonSerializer.Serialize(r.Entries);
        var sha = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(json)));
        var result = new RouteChunkResult(id, index, r.Entries.Count);
        var existing = await db.RouteChunks.AsNoTracking().FirstOrDefaultAsync(c => c.RunId == id && c.Index == index, ct);
        if (existing is not null)
            return existing.Sha256 == sha ? Outcome.Accepted(run.Revision, result) : Outcome.Conflict<RouteChunkResult>("ROUTE_CHUNK_MISMATCH", run.Revision);
        db.RouteChunks.Add(new RouteChunk
        {
            UserId = userId, RunId = id, Index = index, FirstSeq = r.FirstSeq, LastSeq = r.LastSeq, EntryCount = r.Entries.Count,
            EntriesJson = json, Sha256 = sha, CreatedAtUtc = DateTime.UtcNow,
        });
        run.RouteChunkCount++;
        if (run.RouteState == "none") run.RouteState = "uploading";
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, result);
    }

    /// <summary>Marks the route whole once every chunk 0 … n-1 is stored with the expected number of entries.</summary>
    public async Task<Outcome<RunDto>> CompleteRouteAsync(Guid userId, Guid id, RouteCompleteRequest r, CancellationToken ct)
    {
        var run = await Owned(userId, id, ct);
        if (run is null) return Outcome.NotFound<RunDto>();
        if (r.ChunkCount is < 1 or > MaxChunks || r.EntryCount < 1) return Outcome.Rejected<RunDto>(Ack.Invalid);
        var chunks = await db.RouteChunks.AsNoTracking().Where(c => c.RunId == id).Select(c => new { c.Index, c.EntryCount }).ToListAsync(ct);
        if (chunks.Count != r.ChunkCount || chunks.Any(c => c.Index >= r.ChunkCount) || chunks.Sum(c => c.EntryCount) != r.EntryCount)
            return Outcome.Conflict("ROUTE_INCOMPLETE", run.Revision, ToDto(run));
        run.RouteState = "complete";
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(run.Revision, ToDto(run));
    }

    /// <summary>A bounded page of an activity's route chunks, in order. Routes are never part of the account snapshot.</summary>
    public async Task<RoutePage?> RoutePageAsync(Guid userId, Guid id, int fromIndex, int limit, CancellationToken ct)
    {
        var run = await db.Runs.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId && x.DeletedAtUtc == null, ct);
        if (run is null) return null;
        limit = Math.Clamp(limit, 1, RoutePageLimit);
        var page = await db.RouteChunks.AsNoTracking().Where(c => c.RunId == id && c.UserId == userId && c.Index >= Math.Max(0, fromIndex))
            .OrderBy(c => c.Index).Take(limit + 1).ToListAsync(ct);
        var chunks = page.Take(limit).Select(c => new RouteChunkDto(c.Index, c.FirstSeq, c.LastSeq, JsonSerializer.Deserialize<JsonElement>(c.EntriesJson))).ToList();
        return new RoutePage(id, run.RouteState, run.RouteChunkCount, chunks, page.Count > limit ? page[limit].Index : null);
    }

    /// <summary>Circumferences, a correction command and a first-saved time per check-in (docs/BODY_PROGRESS.md).</summary>
    public const string MeasurementsCapability = "body-metrics.measurements";

    private static decimal? Round4(decimal? v) => v is null ? null : Math.Round(v.Value, 4, MidpointRounding.AwayFromZero);
    private static decimal?[] Lengths(BodyMetric m) => [m.WaistCm, m.ChestCm, m.LeftUpperArmCm, m.RightUpperArmCm, m.LeftThighCm, m.RightThighCm];

    /// <summary>At least one measurement (a note alone is not one); weight above 0 and at most 700 kg, body fat 0–100 %,
    /// circumferences above 0 and at most 500 cm (input bounds, not health ranges), a note of at most 200 characters,
    /// and no day after the latest calendar day anywhere on Earth right now.</summary>
    private static bool Valid(BodyMetric m) =>
        (m.WeightKg is not null || m.BodyFatPercent is not null || Lengths(m).Any(v => v is not null)) &&
        (m.WeightKg is null or (> 0 and <= 700)) && (m.BodyFatPercent is null or (>= 0 and <= 100)) &&
        Lengths(m).All(v => v is null or (> 0 and <= 500)) && (m.Note?.Length ?? 0) <= 200 &&
        m.DayKey <= DateOnly.FromDateTime(DateTime.UtcNow.AddHours(14));

    public async Task<Outcome<BodyMetricDto>> AddMetricAsync(Guid userId, BodyMetricRequest r, CancellationToken ct)
    {
        var m = new BodyMetric
        {
            Id = r.MetricId, UserId = userId, DayKey = r.DayKey, WeightKg = Round4(r.WeightKg), BodyFatPercent = r.BodyFatPercent, Note = r.Note,
            WaistCm = Round4(r.WaistCm), ChestCm = Round4(r.ChestCm), LeftUpperArmCm = Round4(r.LeftUpperArmCm), RightUpperArmCm = Round4(r.RightUpperArmCm),
            LeftThighCm = Round4(r.LeftThighCm), RightThighCm = Round4(r.RightThighCm),
            RecordedAtUtc = r.RecordedAtUtc is { } at ? WorkoutService.Utc(at) : null,
        };
        if (r.MetricId == Guid.Empty || !Valid(m)) return Outcome.Rejected<BodyMetricDto>(Ack.Invalid);
        if (await db.BodyMetrics.AnyAsync(x => x.Id == r.MetricId, ct)) return Outcome.Conflict<BodyMetricDto>("DUPLICATE_ID");
        db.BodyMetrics.Add(m);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(m.Revision, ToDto(m));
    }

    /// <summary>Corrects a check-in in place: same ID, same first-saved time. Fields left out keep their value.</summary>
    public async Task<Outcome<BodyMetricDto>> UpdateMetricAsync(Guid userId, Guid id, BodyMetricUpdateRequest r, CancellationToken ct)
    {
        var m = await db.BodyMetrics.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (m is null) return Outcome.NotFound<BodyMetricDto>();
        var next = new BodyMetric
        {
            DayKey = r.DayKey, WeightKg = Round4(r.WeightKg.OrKeep(m.WeightKg)), BodyFatPercent = r.BodyFatPercent.OrKeep(m.BodyFatPercent),
            WaistCm = Round4(r.WaistCm.OrKeep(m.WaistCm)), ChestCm = Round4(r.ChestCm.OrKeep(m.ChestCm)),
            LeftUpperArmCm = Round4(r.LeftUpperArmCm.OrKeep(m.LeftUpperArmCm)), RightUpperArmCm = Round4(r.RightUpperArmCm.OrKeep(m.RightUpperArmCm)),
            LeftThighCm = Round4(r.LeftThighCm.OrKeep(m.LeftThighCm)), RightThighCm = Round4(r.RightThighCm.OrKeep(m.RightThighCm)),
            Note = r.Note.IsSet ? (string.IsNullOrEmpty(r.Note.Value) ? null : r.Note.Value) : m.Note,
        };
        if (!Valid(next)) return Outcome.Rejected<BodyMetricDto>(Ack.Invalid);
        if (m.DeletedAtUtc != null) return Outcome.Conflict("ENTRY_DELETED", m.Revision, ToDto(m));
        if (m.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, m.Revision, ToDto(m));
        (m.DayKey, m.WeightKg, m.BodyFatPercent, m.Note) = (next.DayKey, next.WeightKg, next.BodyFatPercent, next.Note);
        (m.WaistCm, m.ChestCm, m.LeftUpperArmCm, m.RightUpperArmCm, m.LeftThighCm, m.RightThighCm) =
            (next.WaistCm, next.ChestCm, next.LeftUpperArmCm, next.RightUpperArmCm, next.LeftThighCm, next.RightThighCm);
        m.Revision++;
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

public sealed class AccountService(GoHardDb db, AccountAccess access)
{
    public async Task<Outcome<ProfileDto>> UpdateProfileAsync(Guid userId, ProfileUpdateRequest r, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        var name = (r.DisplayName ?? "").Trim();
        if (name.Length is 0 or > 80 || r.Appearance is not ("dark" or "light" or "system") || r.LoadUnit is not ("kg" or "lb") ||
            (r.ReminderLocalTime is not null && !TimeOnly.TryParseExact(r.ReminderLocalTime, "HH:mm", out _)) ||
            r.CalorieGoal.Value is < 500 or > 10000 || r.ProteinGoal.Value is < 10 or > 500 || r.WaterGoalMl.Value is < 100 or > 10000)
            return Outcome.Rejected<ProfileDto>(Ack.Invalid);
        if (user.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, user.Revision, access.Profile(user));
        (user.DisplayName, user.Appearance, user.LoadUnit, user.RemindersEnabled, user.ReminderLocalTime) =
            (name, r.Appearance, r.LoadUnit, r.RemindersEnabled, r.ReminderLocalTime);
        // A client that predates goals does not send them, and so cannot erase them.
        (user.CalorieGoal, user.ProteinGoalG, user.WaterGoalMl) =
            (r.CalorieGoal.OrKeep(user.CalorieGoal), r.ProteinGoal.OrKeep(user.ProteinGoalG), r.WaterGoalMl.OrKeep(user.WaterGoalMl));
        // Display choices likewise: only a client that sends one changes it.
        (user.ShowWater, user.ShowCarbs, user.ShowFat) = (r.ShowWater ?? user.ShowWater, r.ShowCarbs ?? user.ShowCarbs, r.ShowFat ?? user.ShowFat);
        user.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(user.Revision, access.Profile(user));
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
