using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Persistence;

public enum SchemaReadinessKind { Ready, PendingMigration, UnknownHistory, SchemaDrift, Unreachable }

public sealed record SchemaReadiness(SchemaReadinessKind Kind, string Detail)
{
    public bool IsReady => Kind == SchemaReadinessKind.Ready;
}

/// <summary>
/// Reads migration history and table metadata only. It never applies a migration, stamps history or
/// repairs schema; those happen through the explicit `migrate` command.
/// </summary>
public static class SchemaReadinessService
{
    public static async Task<SchemaReadiness> CheckAsync(GoHardDb db, CancellationToken ct)
    {
        try
        {
            var tables = await db.Database
                .SqlQuery<string>($"SELECT table_name AS \"Value\" FROM information_schema.tables WHERE table_schema = 'public'")
                .ToListAsync(ct);
            var expected = db.Model.GetEntityTypes().Select(t => t.GetTableName()!).Distinct().ToList();
            var known = db.Database.GetMigrations().ToList();

            if (!tables.Contains("__EFMigrationsHistory"))
                return tables.Intersect(expected).Any()
                    ? new(SchemaReadinessKind.SchemaDrift, "Application tables exist without migration history.")
                    : new(SchemaReadinessKind.PendingMigration, "No migration has been applied. Run scripts/setup.ps1.");

            var applied = await db.Database
                .SqlQuery<string>($"SELECT \"MigrationId\" AS \"Value\" FROM \"__EFMigrationsHistory\"").ToListAsync(ct);
            var unknown = applied.Except(known).ToList();
            if (unknown.Count > 0)
                return new(SchemaReadinessKind.UnknownHistory, $"History contains migrations this build does not know: {string.Join(", ", unknown)}.");
            var pending = known.Except(applied).ToList();
            if (pending.Count > 0)
                return new(SchemaReadinessKind.PendingMigration, $"Pending: {string.Join(", ", pending)}. Run scripts/setup.ps1.");
            var missing = expected.Except(tables).ToList();
            if (missing.Count > 0)
                return new(SchemaReadinessKind.SchemaDrift, $"Missing tables: {string.Join(", ", missing)}.");
            return new(SchemaReadinessKind.Ready, $"{applied.Count} migration(s) applied.");
        }
        catch (Exception ex) when (ex is Npgsql.NpgsqlException or InvalidOperationException or TimeoutException)
        {
            return new(SchemaReadinessKind.Unreachable, "Database is not reachable."); // no connection details in output
        }
    }
}

/// <summary>Explicit development seed of reference catalog data. Never creates accounts, workouts or food.</summary>
public static class CatalogSeeder
{
    public static async Task<int> SeedAsync(GoHardDb db, CancellationToken ct)
    {
        var json = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "Data", "exercise-catalog.json"), ct);
        var items = JsonSerializer.Deserialize<List<CatalogExercise>>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        var existing = await db.CatalogExercises.ToDictionaryAsync(c => c.Key, ct);
        foreach (var item in items)
        {
            if (existing.TryGetValue(item.Key, out var row))
                (row.Name, row.Category, row.Equipment, row.IsTimed) = (item.Name, item.Category, item.Equipment, item.IsTimed);
            else db.CatalogExercises.Add(item);
        }
        await db.SaveChangesAsync(ct);
        return items.Count;
    }
}
