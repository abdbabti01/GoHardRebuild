using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>
/// The load step the person confirmed for one exercise (docs/PROGRESSION.md › Equipment increments). Per account and
/// exercise identity, revision-checked, never preselected. Used only to size a suggested next target on the phone.
/// </summary>
public sealed class ExerciseIncrementService(GoHardDb db)
{
    public const string Capability = "exercises.load-increment";
    public const decimal MaxIncrementKg = 50m;

    public static ExerciseIncrementDto ToDto(ExerciseIncrement x) => new(x.ExerciseKey, x.IncrementKg, x.Revision);

    /// <param name="key">A catalogue key, or <c>custom:&lt;id&gt;</c> naming one of the caller's own exercises.</param>
    public async Task<Outcome<ExerciseIncrementDto>> PutAsync(Guid userId, string key, ExerciseIncrementPutRequest r, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(key) || key.Length > 80 || r.ExpectedRevision < 0 ||
            r.IncrementKg is { } kg && (kg <= 0 || kg > MaxIncrementKg || decimal.Round(kg, 5) != kg))
            return Outcome.Rejected<ExerciseIncrementDto>(Ack.Invalid);
        var known = key.StartsWith("custom:")
            ? Guid.TryParse(key[7..], out var id) && await db.CustomExercises.AnyAsync(e => e.Id == id && e.UserId == userId, ct)
            : await db.CatalogExercises.AnyAsync(c => c.Key == key, ct);
        if (!known) return Outcome.Rejected<ExerciseIncrementDto>(PlanService.UnknownExercise);
        var row = await db.ExerciseIncrements.FirstOrDefaultAsync(x => x.UserId == userId && x.ExerciseKey == key, ct);
        if (row is null)
        {
            if (r.ExpectedRevision != 0) return Outcome.Conflict<ExerciseIncrementDto>(Ack.RevisionConflict);
            row = new ExerciseIncrement { UserId = userId, ExerciseKey = key, Revision = 0 };
            db.ExerciseIncrements.Add(row);
        }
        // Chosen on another phone meanwhile: that choice is kept and shown beside this one for review.
        else if (row.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, row.Revision, ToDto(row));
        row.IncrementKg = r.IncrementKg; // null = explicitly cleared
        row.UpdatedAtUtc = DateTime.UtcNow;
        row.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(row.Revision, ToDto(row));
    }

    public async Task<List<ExerciseIncrementDto>> ListAsync(Guid userId, CancellationToken ct) =>
        (await db.ExerciseIncrements.AsNoTracking().Where(x => x.UserId == userId).OrderBy(x => x.ExerciseKey).ToListAsync(ct)).Select(ToDto).ToList();
}
