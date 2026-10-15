using System.Text.Json;
using System.Text.Json.Nodes;

namespace GoHard.Api.Application.Coach;

// Wire contract: docs/COACH.md › POST /api/v1/coach/ask.

public sealed record CoachTurn(string? Role, string? Text);
public sealed record CoachDraft(string? Title, int? DurationWeeks, int? TimeBudgetMinutes, PlanSchedule? Schedule, List<WorkoutDefinition>? Workouts);
/// <param name="Focus">plan | split | workout | exercise</param>
public sealed record CoachContext(string? Label, string? Focus, string? TemplateId, Guid? WorkoutId, string? OccurrenceKey, string? CatalogKey,
    CoachDraft? Draft, string? DraftRevision);
public sealed record CoachAskRequest(Guid RequestId, string? Question, List<CoachTurn>? History, CoachContext? Context);

/// <param name="Operations">Each exactly as docs/COACH.md lists it for its op; built by the server, never passed through.</param>
public sealed record CoachProposal(string Summary, string Scope, List<JsonObject> Operations);
public sealed record CoachAnswer(Guid RequestId, string Kind, string Answer, List<string> Sources, CoachProposal? Proposal, string? DraftRevision);

// Reviewed content: Data/coach-guide.json (docs/COACH.md › coach-guide.json).

public sealed record CoachSource(string Id, string Title, string Publisher, string Url);
public sealed record CoachSplit(string TemplateId, string Name, string Summary, string Organisation, string Days,
    List<string> Benefits, List<string> Limitations, List<string> Sources);
public sealed record CoachExercise(string CatalogKey, List<string> Muscles, string Equipment, string Role, List<string> Cues,
    List<string> Benefits, List<string> Limitations, List<string> Alternatives, List<string> Sources);
public sealed record CoachTerm(string Id, string Term, string Text);

public sealed record CoachGuide(int Version, List<CoachSource> Sources, List<CoachSplit> Splits, List<CoachExercise> Exercises, List<CoachTerm> Terms)
{
    /// <summary>The reviewed content, or null when the file is missing or does not follow the schema. Never throws.</summary>
    public static CoachGuide? Load(string path, ILogger log)
    {
        try
        {
            var guide = JsonSerializer.Deserialize<CoachGuide>(File.ReadAllText(path), CommandRunner.Json);
            if (guide?.Valid() == true) return guide;
            log.LogError("Coach guide {Path} does not follow the schema; Ask GoHard is unavailable", path);
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            log.LogError("Coach guide {Path} could not be read ({Reason}); Ask GoHard is unavailable", path, ex.GetType().Name);
        }
        return null;
    }

    private static bool Text(string? s) => !string.IsNullOrWhiteSpace(s);
    private static bool Texts(List<string>? l) => l is not null && l.All(Text);

    private bool Valid()
    {
        if (Version < 1 || Sources is null || Splits is null || Exercises is null || Terms is null) return false;
        var ids = Sources.Select(s => s?.Id).ToHashSet();
        bool Cites(List<string>? l) => l is not null && l.All(ids.Contains);
        return ids.Count == Sources.Count &&
            Sources.All(s => s is not null && Text(s.Id) && Text(s.Title) && Text(s.Publisher) && Uri.TryCreate(s.Url, UriKind.Absolute, out var u) && u.Scheme == "https") &&
            Splits.All(s => s is not null && Text(s.TemplateId) && Text(s.Name) && Text(s.Summary) && Text(s.Organisation) && Text(s.Days) &&
                Texts(s.Benefits) && Texts(s.Limitations) && Cites(s.Sources)) &&
            Exercises.All(e => e is not null && Text(e.CatalogKey) && Texts(e.Muscles) && Text(e.Equipment) && e.Role is "main" or "accessory" &&
                Texts(e.Cues) && Texts(e.Benefits) && Texts(e.Limitations) && Texts(e.Alternatives) && Cites(e.Sources)) &&
            Terms.All(t => t is not null && Text(t.Id) && Text(t.Term) && Text(t.Text));
    }
}
