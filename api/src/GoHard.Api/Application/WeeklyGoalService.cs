using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>
/// Weekly activity targets (docs/PROGRESS.md › Weekly goals). Each record is effective from its Monday until a later
/// one, so changing this week's goal never rewrites a completed week. Owned, revision-checked, never suggested.
/// </summary>
public sealed class WeeklyGoalService(GoHardDb db)
{
    public const string Capability = "goals.weekly";
    public const int MinTarget = 1, MaxTarget = 21;

    public static WeeklyGoalDto ToDto(WeeklyGoal g) => new(g.WeekStart, g.WorkoutsTarget, g.RunWalkTarget, g.Revision);

    private static bool ValidTarget(OptionalInt t) => t.Value is null or >= MinTarget and <= MaxTarget;

    /// <summary>
    /// A queued change keeps the week it was made in, however late it arrives, so any past Monday is accepted; a week
    /// more than one ahead of the server's date cannot have been chosen as "this week" and is refused.
    /// </summary>
    public async Task<Outcome<WeeklyGoalDto>> PutAsync(Guid userId, DateOnly weekStart, WeeklyGoalPutRequest r, CancellationToken ct)
    {
        if (weekStart.DayOfWeek != DayOfWeek.Monday || weekStart > DateOnly.FromDateTime(DateTime.UtcNow).AddDays(7) ||
            !ValidTarget(r.WorkoutsTarget) || !ValidTarget(r.RunWalkTarget) || r.ExpectedRevision < 0)
            return Outcome.Rejected<WeeklyGoalDto>(Ack.Invalid);
        var goal = await db.WeeklyGoals.FirstOrDefaultAsync(g => g.UserId == userId && g.WeekStart == weekStart, ct);
        if (goal is null)
        {
            if (r.ExpectedRevision != 0) return Outcome.Conflict<WeeklyGoalDto>(Ack.RevisionConflict);
            goal = new WeeklyGoal { UserId = userId, WeekStart = weekStart, Revision = 0 };
            db.WeeklyGoals.Add(goal);
        }
        // Another phone already chose this week's goal: its choice is kept and shown beside this one for review.
        else if (goal.Revision != r.ExpectedRevision) return Outcome.Conflict(Ack.RevisionConflict, goal.Revision, ToDto(goal));
        // An older client that leaves a field out keeps the stored value; an explicit null clears it.
        (goal.WorkoutsTarget, goal.RunWalkTarget) = (r.WorkoutsTarget.OrKeep(goal.WorkoutsTarget), r.RunWalkTarget.OrKeep(goal.RunWalkTarget));
        goal.UpdatedAtUtc = DateTime.UtcNow;
        goal.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(goal.Revision, ToDto(goal));
    }

    public async Task<List<WeeklyGoalDto>> ListAsync(Guid userId, CancellationToken ct) =>
        (await db.WeeklyGoals.AsNoTracking().Where(g => g.UserId == userId).OrderBy(g => g.WeekStart).ToListAsync(ct)).Select(ToDto).ToList();
}
