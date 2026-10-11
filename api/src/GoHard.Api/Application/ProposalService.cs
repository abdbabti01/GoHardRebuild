using System.Text.Json;
using GoHard.Api.Domain;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Application;

/// <summary>
/// Optional server-side assistance. It may only word an explanation for an already validated proposal;
/// it never writes plans, sets, food or assignments. The default implementation does nothing.
/// </summary>
public interface IPlanAssistant
{
    Task<string?> ExplainAsync(string kind, ProposalChange change, CancellationToken ct);
}

public sealed class NoPlanAssistant : IPlanAssistant
{
    public Task<string?> ExplainAsync(string kind, ProposalChange change, CancellationToken ct) => Task.FromResult<string?>(null);
}

/// <summary>Future changes are inspectable proposals. Only an explicit accept applies exactly the reviewed scope.</summary>
public sealed class ProposalService(GoHardDb db, PlanService plans, IPlanAssistant assistant)
{
    private static readonly JsonSerializerOptions Json = CommandRunner.Json;

    private static ProposalDto ToDto(Proposal p, int planRevision) => new(p.Id, p.PlanId, p.Kind,
        // An open proposal reviewed against an older plan revision must be looked at again before it can apply.
        p.State == "open" && planRevision != p.BasePlanRevision ? "needs_review" : p.State,
        p.BasePlanRevision, JsonSerializer.Deserialize<ProposalChange>(p.ChangeJson, Json)!, p.Explanation, p.Revision);

    public async Task<List<ProposalDto>> ListAsync(Guid userId, CancellationToken ct)
    {
        var rows = await db.Proposals.AsNoTracking().Where(p => p.UserId == userId)
            .Join(db.Plans, p => p.PlanId, pl => pl.Id, (p, pl) => new { p, pl.Revision }).OrderBy(x => x.p.CreatedAtUtc).ToListAsync(ct);
        return rows.Select(x => ToDto(x.p, x.Revision)).ToList();
    }

    private async Task<string> EvidenceHashAsync(Guid planId, CancellationToken ct)
    {
        var evidence = await db.Workouts.AsNoTracking().Where(w => w.PlanId == planId && w.FinishedAtUtc != null && w.DeletedAtUtc == null)
            .OrderBy(w => w.Id).Select(w => new { w.Id, w.Revision, w.Outcome, w.PerformedSets }).ToListAsync(ct);
        var sets = await db.WorkoutSets.AsNoTracking().Where(s => db.Workouts.Any(w => w.Id == s.WorkoutId && w.PlanId == planId && w.FinishedAtUtc != null))
            .OrderBy(s => s.Id).Select(s => new { s.Id, s.Revision }).ToListAsync(ct);
        return SemanticHash.Compute("evidence", new { evidence, sets });
    }

    private async Task<(Plan Plan, List<ScheduleOccasion> Schedule)?> LoadAsync(Guid userId, Guid planId, CancellationToken ct)
    {
        var plan = await db.Plans.Include(p => p.Occasions).FirstOrDefaultAsync(p => p.Id == planId && p.UserId == userId, ct);
        if (plan is null) return null;
        var open = await db.Workouts.Where(w => w.PlanId == planId && w.FinishedAtUtc == null && w.DeletedAtUtc == null && w.OccasionId != null)
            .Select(w => w.OccasionId!.Value).ToListAsync(ct);
        return (plan, plan.Occasions.Select(o => new ScheduleOccasion(o.Id, o.OriginalDate, o.ScheduledDate, o.WeekNumber, o.IsSkipped,
            o.ResultOutcome != null, open.Contains(o.Id))).ToList());
    }

    public async Task<Outcome<ProposalDto>> ProposeAsync(Guid userId, ProposalRequest r, CancellationToken ct)
    {
        if (await LoadAsync(userId, r.PlanId, ct) is not (var plan, var schedule)) return Outcome.NotFound<ProposalDto>();
        if (r.ProposalId == Guid.Empty || plan.Lifecycle is not (PlanLifecycles.Active or PlanLifecycles.Paused)) return Outcome.Rejected<ProposalDto>(Ack.Invalid);
        if (await db.Proposals.AnyAsync(p => p.Id == r.ProposalId, ct)) return Outcome.Conflict<ProposalDto>("DUPLICATE_ID");

        ProposalChange change; string explanation;
        if (r.Kind == "schedule" && r.Moves is { Count: > 0 } moves)
        {
            var v = ScheduleRules.Validate(schedule, moves.Select(m => new ScheduleChange(m.OccasionId, m.From, m.To)).ToList(), plan.MinRecoveryDays);
            if (!v.IsValid) return Outcome.Rejected<ProposalDto>(v.Errors[0].Code);
            change = new(moves, null, null, null, moves.Select(m => m.OccasionId).ToList());
            var weeks = string.Join(", ", v.Changed.Select(o => o.WeekNumber).Distinct().Order());
            explanation = $"Moves {moves.Count} unstarted workout(s) in week {weeks}. Every other date, and anything recorded or in progress, stays as it is.";
        }
        else if (r.Kind == "substitution" && r.FromCatalogKey is { } from && r.ToCatalogKey is { } to)
        {
            var target = await db.CatalogExercises.AsNoTracking().FirstOrDefaultAsync(c => c.Key == to, ct);
            var eligible = schedule.Where(o => o.IsEligible).Select(o => o.Id).ToHashSet();
            var affected = plan.Occasions.Where(o => eligible.Contains(o.Id) && PlanService.ToDto(o).Prescription.Any(e => e.CatalogKey == from))
                .Select(o => o.Id).ToList();
            if (target is null || from == to || affected.Count == 0) return Outcome.Rejected<ProposalDto>("NOTHING_TO_CHANGE");
            change = new([], from, to, target.Name, affected);
            explanation = $"Replaces that movement with {target.Name} in {affected.Count} remaining unstarted workout(s). Targets stay the same; recorded and open workouts are unchanged.";
        }
        else return Outcome.Rejected<ProposalDto>(Ack.Invalid);

        var changeJson = JsonSerializer.Serialize(change, Json);
        var evidence = await EvidenceHashAsync(plan.Id, ct);
        // A declined proposal is not offered again until the change or the evidence is materially different.
        if (await db.Proposals.AnyAsync(p => p.PlanId == plan.Id && p.State == "declined" && p.ChangeJson == changeJson && p.EvidenceHash == evidence, ct))
            return Outcome.Conflict<ProposalDto>("PROPOSAL_DECLINED_UNCHANGED");

        var worded = await SafeExplainAsync(r.Kind, change, ct);
        var proposal = new Proposal
        {
            Id = r.ProposalId, UserId = userId, PlanId = plan.Id, Kind = r.Kind, BasePlanRevision = plan.Revision, EvidenceHash = evidence,
            ChangeJson = changeJson, Explanation = worded ?? explanation, CreatedAtUtc = DateTime.UtcNow,
        };
        db.Proposals.Add(proposal);
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(proposal.Revision, ToDto(proposal, plan.Revision));
    }

    /// <summary>Assistant output is optional wording only: failures, blanks and oversized text fall back to the deterministic text.</summary>
    private async Task<string?> SafeExplainAsync(string kind, ProposalChange change, CancellationToken ct)
    {
        try
        {
            var text = (await assistant.ExplainAsync(kind, change, ct))?.Trim();
            return text is { Length: > 0 and <= 600 } ? text : null;
        }
        catch (Exception ex) when (ex is not OperationCanceledException) { return null; }
    }

    public async Task<Outcome<ProposalResult>> AcceptAsync(Guid userId, Guid proposalId, ProposalDecision r, CancellationToken ct)
    {
        var proposal = await db.Proposals.FirstOrDefaultAsync(p => p.Id == proposalId && p.UserId == userId, ct);
        if (proposal is null || await LoadAsync(userId, proposal.PlanId, ct) is not (var plan, var schedule)) return Outcome.NotFound<ProposalResult>();
        Outcome<ProposalResult> Conflict(string code) => Outcome.Conflict(code, proposal.Revision, new ProposalResult(ToDto(proposal, plan.Revision), null));

        if (proposal.Revision != r.ExpectedProposalRevision) return Conflict(Ack.RevisionConflict);
        if (proposal.State != "open") return Conflict("PROPOSAL_NOT_OPEN");
        if (plan.Revision != proposal.BasePlanRevision || r.ExpectedPlanRevision != plan.Revision ||
            proposal.EvidenceHash != await EvidenceHashAsync(plan.Id, ct)) return Conflict("STALE_PROPOSAL");

        var change = JsonSerializer.Deserialize<ProposalChange>(proposal.ChangeJson, Json)!;
        if (proposal.Kind == "schedule")
        {
            var v = ScheduleRules.Validate(schedule, change.Moves.Select(m => new ScheduleChange(m.OccasionId, m.From, m.To)).ToList(), plan.MinRecoveryDays);
            if (!v.IsValid) return Conflict(v.Errors[0].Code);
            foreach (var c in v.Changed) plan.Occasions.First(o => o.Id == c.Id).ScheduledDate = c.ScheduledDate;
        }
        else
        {
            var eligible = schedule.Where(o => o.IsEligible).Select(o => o.Id).ToHashSet();
            if (!change.AffectedOccasionIds.All(eligible.Contains)) return Conflict(ScheduleRules.OccasionNotEligible);
            foreach (var occasion in plan.Occasions.Where(o => change.AffectedOccasionIds.Contains(o.Id)))
                occasion.PrescriptionJson = JsonSerializer.Serialize(PlanService.ToDto(occasion).Prescription
                    .Select(e => e.CatalogKey == change.FromCatalogKey ? e with { CatalogKey = change.ToCatalogKey, Name = change.ToName! } : e).ToList(), Json);
        }
        plan.Revision++;
        proposal.State = "accepted"; proposal.Revision++;
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(proposal.Revision, new ProposalResult(ToDto(proposal, plan.Revision), await plans.ContextAsync(userId, ct)));
    }

    public async Task<Outcome<ProposalResult>> DeclineAsync(Guid userId, Guid proposalId, ProposalDecision r, CancellationToken ct)
    {
        var proposal = await db.Proposals.FirstOrDefaultAsync(p => p.Id == proposalId && p.UserId == userId, ct);
        if (proposal is null) return Outcome.NotFound<ProposalResult>();
        var planRevision = await db.Plans.Where(p => p.Id == proposal.PlanId).Select(p => p.Revision).FirstAsync(ct);
        if (proposal.Revision != r.ExpectedProposalRevision || proposal.State is "accepted" or "declined")
            return Outcome.Conflict(Ack.RevisionConflict, proposal.Revision, new ProposalResult(ToDto(proposal, planRevision), null));
        proposal.State = "declined"; proposal.Revision++; // keeps the current plan exactly as it is
        await db.SaveChangesAsync(ct);
        return Outcome.Accepted(proposal.Revision, new ProposalResult(ToDto(proposal, planRevision), null));
    }
}
