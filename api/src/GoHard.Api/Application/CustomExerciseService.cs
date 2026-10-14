using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>The person's own exercises. Private to the owner; renaming or archiving never rewrites recorded workouts.</summary>
public sealed class CustomExerciseService(GoHardDb db)
{
    public const string NameInvalid = "EXERCISE_NAME_INVALID";

    public static CustomExerciseDto ToDto(CustomExercise e) => new(e.Id, e.Name, e.Category, e.Equipment, e.IsTimed, e.IsArchived, e.Revision);

    public async Task<Outcome<CustomExerciseDto>> PutAsync(Guid userId, Guid id, CustomExercisePutRequest r, CancellationToken ct)
    {
        if (id == Guid.Empty || r.Category is not { Length: <= 40 } || r.Equipment is not { Length: <= 40 }) return Outcome.Rejected<CustomExerciseDto>(Ack.Invalid);
        var name = (r.Name ?? "").Trim();
        if (name.Length is 0 or > 80) return Outcome.Rejected<CustomExerciseDto>(NameInvalid);
        var exercise = await db.CustomExercises.FirstOrDefaultAsync(e => e.Id == id, ct);
        if (exercise is not null && exercise.UserId != userId) return Outcome.NotFound<CustomExerciseDto>(); // someone else's looks missing
        if (exercise is null)
        {
            if (r.ExpectedRevision != 0) return Outcome.NotFound<CustomExerciseDto>();
            exercise = new CustomExercise { Id = id, UserId = userId, CreatedAtUtc = DateTime.UtcNow, Revision = 0 };
            db.CustomExercises.Add(exercise);
        }
        else if (exercise.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, exercise.Revision, ToDto(exercise));
        (exercise.Name, exercise.Category, exercise.Equipment, exercise.IsTimed, exercise.IsArchived) =
            (name, r.Category.Trim(), r.Equipment.Trim(), r.IsTimed, r.IsArchived);
        exercise.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(exercise.Revision, ToDto(exercise));
    }

    public async Task<List<CustomExerciseDto>> ListAsync(Guid userId, CancellationToken ct) =>
        (await db.CustomExercises.AsNoTracking().Where(e => e.UserId == userId).OrderBy(e => e.CreatedAtUtc).ToListAsync(ct)).Select(ToDto).ToList();
}
