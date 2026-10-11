namespace GoHard.Api.Domain;

public sealed record ScheduleOccasion(
    Guid Id, DateOnly OriginalDate, DateOnly ScheduledDate, int WeekNumber,
    bool IsSkipped = false, bool IsRecorded = false, bool IsOpen = false)
{
    /// <summary>Only pending occasions may be moved, skipped or shifted by a resume.</summary>
    public bool IsEligible => !IsSkipped && !IsRecorded && !IsOpen;
}

public sealed record ScheduleChange(Guid OccasionId, DateOnly From, DateOnly To);
public sealed record ScheduleError(string Code, Guid? OccasionId = null);

public sealed record ScheduleValidation(
    IReadOnlyList<ScheduleError> Errors,
    IReadOnlyList<ScheduleOccasion> Projected,
    IReadOnlyList<ScheduleOccasion> Changed,
    DateOnly? BlockEnd)
{
    public bool IsValid => Errors.Count == 0;
}

/// <summary>Pure calendar-date rules shared by activation, resume, move and adaptation. Mirrored in Dart.</summary>
public static class ScheduleRules
{
    public const string DuplicateOccasion = "DUPLICATE_OCCASION", OccasionNotFound = "OCCASION_NOT_FOUND",
        OccasionNotEligible = "OCCASION_NOT_ELIGIBLE", StaleReview = "STALE_REVIEW",
        RecoveryCollision = "RECOVERY_COLLISION", InvalidWeekdayCount = "INVALID_WEEKDAY_COUNT";

    public static ScheduleValidation Validate(
        IReadOnlyList<ScheduleOccasion> all, IReadOnlyList<ScheduleChange> changes, int minimumRecoveryDays)
    {
        var errors = new List<ScheduleError>();
        var projected = all.ToDictionary(o => o.Id);
        var changedIds = new List<Guid>();
        foreach (var c in changes)
        {
            if (changedIds.Contains(c.OccasionId)) { errors.Add(new(DuplicateOccasion, c.OccasionId)); continue; }
            if (!projected.TryGetValue(c.OccasionId, out var o)) { errors.Add(new(OccasionNotFound, c.OccasionId)); continue; }
            if (!o.IsEligible) { errors.Add(new(OccasionNotEligible, c.OccasionId)); continue; }
            if (o.ScheduledDate != c.From) { errors.Add(new(StaleReview, c.OccasionId)); continue; }
            changedIds.Add(c.OccasionId);
            projected[c.OccasionId] = o with { ScheduledDate = c.To };
        }
        // Spacing is only judged for occasions this change touches; retained history is never re-litigated.
        foreach (var id in changedIds)
        {
            var moved = projected[id];
            var collides = projected.Values.Any(o => o.Id != id && !o.IsSkipped &&
                Math.Abs(o.ScheduledDate.DayNumber - moved.ScheduledDate.DayNumber) <= minimumRecoveryDays);
            if (collides) errors.Add(new(RecoveryCollision, id));
        }
        var list = all.Select(o => projected[o.Id]).ToList();
        return new(errors, list, changedIds.Select(id => projected[id]).ToList(),
            list.Count == 0 ? null : list.Max(o => o.ScheduledDate));
    }

    /// <summary>Dates for a new block: each chosen weekday on or after the start, repeated every seven days.</summary>
    public static (IReadOnlyList<ScheduleError> Errors, IReadOnlyList<(int Week, int Ordinal, DateOnly Date)> Dates) Generate(
        DateOnly start, IReadOnlyList<DayOfWeek> weekdays, int sessionsPerWeek, int blockWeeks, int minimumRecoveryDays)
    {
        var errors = new List<ScheduleError>();
        var distinct = weekdays.Distinct().ToList();
        if (distinct.Count != weekdays.Count || distinct.Count != sessionsPerWeek || distinct.Count == 0)
            return ([new(InvalidWeekdayCount)], []);
        var firstWeek = distinct
            .Select(d => start.AddDays(((int)d - (int)start.DayOfWeek + 7) % 7))
            .OrderBy(d => d).ToList();
        for (var i = 0; i < firstWeek.Count; i++)
        {
            var next = i + 1 < firstWeek.Count ? firstWeek[i + 1] : firstWeek[0].AddDays(7);
            if (firstWeek.Count > 1 && next.DayNumber - firstWeek[i].DayNumber <= minimumRecoveryDays)
            { errors.Add(new(RecoveryCollision)); break; }
        }
        if (errors.Count > 0) return (errors, []);
        var dates = new List<(int, int, DateOnly)>();
        for (var w = 0; w < blockWeeks; w++)
            for (var i = 0; i < firstWeek.Count; i++)
                dates.Add((w + 1, i + 1, firstWeek[i].AddDays(7 * w)));
        return (errors, dates);
    }
}
