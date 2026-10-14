using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using GoHard.Api.Application;

namespace GoHard.Api.Domain;

public sealed record FixedOccurrence(Guid Id, DateOnly Date, int WeekNumber, int Ordinal, Guid WorkoutId);

/// <summary>An existing occasion as `Revise` sees it. `IsPending` = not skipped, not credited, no open workout.</summary>
public sealed record RevisableOccasion(Guid Id, DateOnly OriginalDate, DateOnly ScheduledDate, int WeekNumber, int Ordinal, Guid? WorkoutId,
    string Title, List<PrescriptionExercise> Prescription, bool IsCustomised, bool IsPending);

/// <summary>
/// Pure rules for built plans (workout definitions + fixed or rotating schedule). Mirrored by the phone's
/// `plan_rules.dart` and checked against the same fixture (`contracts/contract_fixture.json` › plan*).
/// Contract and reasoning: docs/TRAINING_PLANS.md.
/// </summary>
public static class PlanRules
{
    public const string TitleInvalid = "TITLE_INVALID", DurationInvalid = "DURATION_INVALID", TimeBudgetInvalid = "TIME_BUDGET_INVALID",
        WorkoutsInvalid = "WORKOUTS_INVALID", ScheduleInvalid = "SCHEDULE_INVALID", NotUsable = "PLAN_NOT_USABLE";
    public const string Fixed = "fixed", Rotating = "rotating";

    /// <summary>RFC 4122 version 5: SHA-1 over the namespace bytes in network order, then the UTF-8 name.</summary>
    public static Guid Uuid5(Guid ns, string name)
    {
        var bytes = new byte[16 + Encoding.UTF8.GetByteCount(name)];
        ns.TryWriteBytes(bytes, bigEndian: true, out _);
        Encoding.UTF8.GetBytes(name, bytes.AsSpan(16));
        var hash = SHA1.HashData(bytes);
        hash[6] = (byte)((hash[6] & 0x0F) | 0x50);
        hash[8] = (byte)((hash[8] & 0x3F) | 0x80);
        return new Guid(hash.AsSpan(0, 16), bigEndian: true);
    }

    public static Guid FixedId(Guid planId, DateOnly date) => Uuid5(planId, "d:" + date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
    public static Guid SequenceId(Guid planId, int k) => Uuid5(planId, "s:" + k.ToString(CultureInfo.InvariantCulture));

    private static int Iso(DateOnly d) => d.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)d.DayOfWeek;

    /// <summary>Every occurrence of a fixed-weekday plan: each pattern day in order of its offset from the start, every week.</summary>
    public static List<FixedOccurrence> FixedDates(Guid planId, DateOnly start, int weeks, IEnumerable<PlanPatternEntry> pattern)
    {
        var entries = pattern.Select(p => (Offset: (p.Weekday - Iso(start) + 7) % 7, p.WorkoutId)).OrderBy(e => e.Offset).ToList();
        var list = new List<FixedOccurrence>();
        for (var w = 0; w < weeks; w++)
            for (var i = 0; i < entries.Count; i++)
            {
                var date = start.AddDays(entries[i].Offset + 7 * w);
                list.Add(new(FixedId(planId, date), date, w + 1, i + 1, entries[i].WorkoutId));
            }
        return list;
    }

    /// <summary>The workout at sequence index k of a rotating plan; the cycle's first workout applies at `anchor`.</summary>
    public static Guid WorkoutFor(IReadOnlyList<Guid> cycle, int anchor, int k) => cycle[(((k - anchor) % cycle.Count) + cycle.Count) % cycle.Count];

    // ---------------------------------------------------------------- validation

    private static bool Len(string? s, int min, int max) => s is not null && s.Trim().Length >= min && s.Trim().Length <= max;
    private static bool Range(decimal? v, decimal min, decimal max) => v is null || (v >= min && v <= max);

    /// <summary>Error codes, at most one per group, in contract order.</summary>
    public static List<string> Validate(string? title, int? durationWeeks, int? timeBudgetMinutes, IReadOnlyList<WorkoutDefinition>? workouts, PlanSchedule? schedule)
    {
        var errors = new List<string>();
        var rotating = schedule?.Mode == Rotating;
        if (!Len(title, 1, 60)) errors.Add(TitleInvalid);
        if (durationWeeks is null ? !rotating : durationWeeks is < 1 or > 52) errors.Add(DurationInvalid);
        if (timeBudgetMinutes is < 10 or > 240) errors.Add(TimeBudgetInvalid);
        var list = workouts ?? [];
        var ids = list.Select(w => w.Id).ToHashSet();
        if (list.Count is 0 or > 20 || ids.Count != list.Count || !list.All(WorkoutOk)) errors.Add(WorkoutsInvalid);
        if (schedule is null || !ScheduleOk(schedule, ids)) errors.Add(ScheduleInvalid);
        return errors;
    }

    private static bool WorkoutOk(WorkoutDefinition w)
    {
        var exercises = w.Exercises ?? [];
        return w.Id != Guid.Empty && Len(w.Name, 1, 60) && (w.Notes is null || Len(w.Notes, 0, 500)) && exercises.Count <= 30 &&
            exercises.Select(e => e.OccurrenceKey).Distinct().Count() == exercises.Count && exercises.All(ExerciseOk);
    }

    public static bool ExerciseOk(PrescriptionExercise e) =>
        Len(e.OccurrenceKey, 1, 64) && Len(e.Name, 1, 120) && Range(e.TargetSets, 1, 20) && Range(e.TargetRepsMin, 1, 100) && Range(e.TargetRepsMax, 1, 100) &&
        (e.TargetRepsMin is null || e.TargetRepsMax is null || e.TargetRepsMin <= e.TargetRepsMax) && Range(e.TargetDurationSeconds, 1, 3600) &&
        Range(e.RestSeconds, 0, 900) && Range(e.TargetLoadKg, 0, 2000) && (e.Notes is null || Len(e.Notes, 0, 500));

    private static bool ScheduleOk(PlanSchedule s, HashSet<Guid> ids)
    {
        switch (s.Mode)
        {
            case Fixed:
                var pattern = s.Pattern ?? [];
                return pattern.Count is >= 1 and <= 7 && pattern.Select(p => p.Weekday).Distinct().Count() == pattern.Count &&
                    pattern.All(p => p.Weekday is >= 1 and <= 7 && ids.Contains(p.WorkoutId));
            case Rotating:
                var cycle = s.Cycle ?? [];
                var days = s.TrainingDays ?? [];
                return cycle.Count is >= 1 and <= 30 && cycle.All(ids.Contains) && days.Distinct().Count() == days.Count &&
                    days.All(d => d is >= 1 and <= 7) && s.CycleAnchor >= 0;
            default: return false;
        }
    }

    /// <summary>The workouts the schedule uses.</summary>
    public static HashSet<Guid> Scheduled(PlanSchedule s) =>
        (s.Mode == Rotating ? s.Cycle ?? [] : (s.Pattern ?? []).Select(p => p.WorkoutId)).ToHashSet();

    /// <summary>Can be activated: every workout the schedule uses is defined and has at least one exercise.</summary>
    public static bool Usable(IReadOnlyList<WorkoutDefinition>? workouts, PlanSchedule? schedule)
    {
        if (schedule is null) return false;
        var byId = (workouts ?? []).GroupBy(w => w.Id).ToDictionary(g => g.Key, g => g.First());
        return Scheduled(schedule).All(id => byId.TryGetValue(id, out var w) && (w.Exercises ?? []).Count > 0);
    }

    // ---------------------------------------------------------------- revising

    /// <summary>
    /// A plan-wide edit from `effective` on (docs/TRAINING_PLANS.md › Revising). Kept occasions are returned as the
    /// same prescription instance, so a caller can tell a content change by reference. Rotating plans keep everything.
    /// </summary>
    public static List<RevisableOccasion> Revise(Guid planId, DateOnly start, int? weeks, DateOnly effective,
        IReadOnlyList<RevisableOccasion> occasions, IReadOnlyList<WorkoutDefinition> workouts, PlanSchedule schedule)
    {
        if (schedule.Mode == Rotating || weeks is not { } w) return occasions.ToList();
        var byId = workouts.GroupBy(x => x.Id).ToDictionary(g => g.Key, g => g.First());
        var generated = FixedDates(planId, start, w, schedule.Pattern ?? []).Where(g => g.Date >= effective).ToList();
        var genIds = generated.Select(g => g.Id).ToHashSet();
        var existing = occasions.ToDictionary(o => o.Id);
        static bool Replaceable(RevisableOccasion o) => o.IsPending && !o.IsCustomised;
        static RevisableOccasion WithContent(RevisableOccasion o, WorkoutDefinition d) =>
            o with { WorkoutId = d.Id, Title = d.Name, Prescription = (d.Exercises ?? []).ToList() };

        var output = new List<RevisableOccasion>();
        foreach (var o in occasions)
        {
            if (!Replaceable(o)) output.Add(o);
            else if (genIds.Contains(o.Id)) continue;                 // taken from the generated list below
            else if (o.OriginalDate >= effective) continue;           // the new pattern no longer has it
            else if (o.ScheduledDate >= effective && o.WorkoutId is { } wid && byId.TryGetValue(wid, out var d)) output.Add(WithContent(o, d));
            else output.Add(o);
        }
        foreach (var g in generated)
        {
            existing.TryGetValue(g.Id, out var o);
            if (o is not null && !Replaceable(o)) continue;
            var d = byId[g.WorkoutId];
            output.Add(o is null
                ? new(g.Id, g.Date, g.Date, g.WeekNumber, g.Ordinal, d.Id, d.Name, (d.Exercises ?? []).ToList(), false, true)
                : WithContent(o, d) with { WeekNumber = g.WeekNumber });
        }
        // Ordinals are a display key only: renumbered within each week so kept and added occurrences never share one.
        var sorted = output.OrderBy(o => o.WeekNumber).ThenBy(o => o.OriginalDate)
            .ThenBy(o => o.Id.ToString(), StringComparer.Ordinal).ToList();
        var result = new List<RevisableOccasion>();
        for (var i = 0; i < sorted.Count; i++)
        {
            var n = i == 0 || sorted[i - 1].WeekNumber != sorted[i].WeekNumber ? 1 : result[i - 1].Ordinal + 1;
            result.Add(sorted[i] with { Ordinal = n });
        }
        return result;
    }
}
