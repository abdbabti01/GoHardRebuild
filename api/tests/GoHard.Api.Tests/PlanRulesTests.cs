using System.Text.Json;
using System.Text.Json.Nodes;
using GoHard.Api.Application;
using GoHard.Api.Domain;

namespace GoHard.Api.Tests;

/// <summary>Built-plan rules driven by the same fixture the Dart suite reads (contracts/contract_fixture.json › plan*).</summary>
public class PlanRulesTests
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static IEnumerable<object[]> Cases(string section) =>
        Fixture.Root[section]!.AsArray().Select(c => new object[] { c!["name"]!.GetValue<string>() });

    private static JsonNode Case(string section, string name) =>
        Fixture.Root[section]!.AsArray().First(c => c!["name"]!.GetValue<string>() == name)!;

    private static Guid G(JsonNode? n) => Guid.Parse(n!.GetValue<string>());

    [Fact]
    public void Occurrence_ids_are_rfc4122_uuid5_and_match_the_fixture()
    {
        foreach (var c in Fixture.Root["planIds"]!.AsArray())
            Assert.Equal(G(c!["expect"]), PlanRules.Uuid5(G(c["planId"]), c["name"]!.GetValue<string>()));
        var plan = Guid.Parse("00000000-0000-4000-8000-0000000000a1");
        Assert.Equal(PlanRules.Uuid5(plan, "d:2026-10-12"), PlanRules.FixedId(plan, new(2026, 10, 12)));
        Assert.Equal(PlanRules.Uuid5(plan, "s:12"), PlanRules.SequenceId(plan, 12));
        // RFC 4122 test vector: uuid5(NAMESPACE_DNS, "python.org").
        Assert.Equal(Guid.Parse("886313e1-3b8a-5372-9b90-0c9aee199e5d"), PlanRules.Uuid5(Guid.Parse("6ba7b810-9dad-11d1-80b4-00c04fd430c8"), "python.org"));
    }

    [Theory, MemberData(nameof(Cases), "planFixed")]
    public void Fixed_occurrences_match_fixture(string name)
    {
        var c = Case("planFixed", name);
        var actual = PlanRules.FixedDates(G(c["planId"]), Fixture.Date(c["start"]), c["durationWeeks"]!.GetValue<int>(),
            c["pattern"].Deserialize<List<PlanPatternEntry>>(Json)!);
        var expected = c["expect"]!.AsArray().Select(e => new FixedOccurrence(G(e!["id"]), Fixture.Date(e["date"]),
            e["weekNumber"]!.GetValue<int>(), e["ordinal"]!.GetValue<int>(), G(e["workoutId"]))).ToList();
        Assert.Equal(expected, actual);
    }

    [Theory, MemberData(nameof(Cases), "planRotating")]
    public void Rotating_sequence_matches_fixture(string name)
    {
        var c = Case("planRotating", name);
        var cycle = c["cycle"].Deserialize<List<Guid>>(Json)!;
        foreach (var e in c["expect"]!.AsArray())
            Assert.Equal(G(e![1]), PlanRules.WorkoutFor(cycle, c["cycleAnchor"]!.GetValue<int>(), e[0]!.GetValue<int>()));
    }

    [Theory, MemberData(nameof(Cases), "planValidate")]
    public void Plan_validation_matches_fixture(string name)
    {
        var c = Case("planValidate", name);
        var p = c["plan"]!;
        var workouts = p["workouts"].Deserialize<List<WorkoutDefinition>>(Json);
        var schedule = p["schedule"].Deserialize<PlanSchedule>(Json);
        var errors = PlanRules.Validate(p["title"]?.GetValue<string>(), p["durationWeeks"]?.GetValue<int>(), p["timeBudgetMinutes"]?.GetValue<int>(),
            workouts, schedule);
        Assert.Equal(c["expectErrors"].Deserialize<List<string>>()!, errors);
        Assert.Equal(c["expectUsable"]!.GetValue<bool>(), PlanRules.Usable(workouts, schedule));
    }

    [Theory, MemberData(nameof(Cases), "planRevise")]
    public void Plan_revision_matches_fixture(string name)
    {
        var c = Case("planRevise", name);
        var occasions = c["occasions"]!.AsArray().Select(o => new RevisableOccasion(G(o!["id"]), Fixture.Date(o["originalDate"]),
            Fixture.Date(o["scheduledDate"]), o["weekNumber"]!.GetValue<int>(), o["ordinal"]!.GetValue<int>(), G(o["workoutId"]),
            o["title"]!.GetValue<string>(), o["prescription"].Deserialize<List<PrescriptionExercise>>(Json)!,
            o["isCustomised"]!.GetValue<bool>(), o["pending"]!.GetValue<bool>())).ToList();
        var result = PlanRules.Revise(G(c["planId"]), Fixture.Date(c["start"]), c["durationWeeks"]!.GetValue<int>(), Fixture.Date(c["effectiveDate"]),
            occasions, c["workouts"].Deserialize<List<WorkoutDefinition>>(Json)!, c["schedule"].Deserialize<PlanSchedule>(Json)!);
        var expected = c["expect"]!.AsArray().Select(e => (G(e!["id"]), Fixture.Date(e["originalDate"]), Fixture.Date(e["scheduledDate"]),
            (Guid?)G(e["workoutId"]), e["title"]!.GetValue<string>(), e["weekNumber"]!.GetValue<int>(), e["ordinal"]!.GetValue<int>(),
            e["firstExercise"]!.GetValue<string>())).ToList();
        Assert.Equal(expected, result.Select(o => (o.Id, o.OriginalDate, o.ScheduledDate, o.WorkoutId, o.Title, o.WeekNumber, o.Ordinal,
            o.Prescription[0].Name)).ToList());
    }

    [Fact]
    public void Every_starter_template_and_swap_names_a_catalog_exercise()
    {
        var catalog = JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "exercise-catalog.json")))!.AsArray()
            .Select(e => e!["key"]!.GetValue<string>()).ToHashSet();
        var templates = JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "plan-templates.json")))!;
        var keys = templates["templates"]!.AsArray().SelectMany(t => t!["workouts"]!.AsArray())
            .SelectMany(w => w!["exercises"]!.AsArray()).Select(e => e!["catalogKey"]!.GetValue<string>()).ToList();
        foreach (var (from, to) in templates["swaps"]!.AsObject())
        {
            keys.Add(from);
            keys.AddRange(to!.AsObject().Select(v => v.Value?.GetValue<string>()).OfType<string>()); // null = drop the exercise
        }
        Assert.NotEmpty(keys);
        Assert.Empty(keys.Where(k => !catalog.Contains(k)).Distinct());
    }

    // ---- additive contract fields leave the semantic hash of commands recorded by older builds unchanged ----

    [Fact]
    public void Older_workout_start_and_plan_draft_commands_keep_their_semantic_hash()
    {
        var (op, workoutId, occasionId, exerciseId) = (Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid());
        var started = new DateTime(2026, 10, 9, 7, 0, 0, DateTimeKind.Utc);
        var current = new StartWorkoutRequest(op, workoutId, "planned", occasionId, "Push", Account.Friday, started,
            [new ExerciseSpec(exerciseId, 1, "Bench press", "bench-press", "e1", true, false, 3, 8, 12, null, 90, null)]);
        var recorded = new
        {
            operationId = op, workoutId, kind = "planned", occasionId, title = "Push", dayKey = Account.Friday, startedAtUtc = started,
            exercises = new[] { new { id = exerciseId, ordinal = 1, name = "Bench press", catalogKey = "bench-press", occurrenceKey = "e1",
                isPrescribed = true, isTimed = false, targetSets = 3, targetRepsMin = 8, targetRepsMax = 12, targetDurationSeconds = (int?)null,
                restSeconds = 90, substitutedForKey = (string?)null } },
        };
        Assert.Equal(SemanticHash.Compute("workout.start", recorded), SemanticHash.Compute("workout.start", current));
        Assert.NotEqual(SemanticHash.Compute("workout.start", recorded), SemanticHash.Compute("workout.start", current with { SequenceIndex = 0 }));

        var planId = Guid.NewGuid();
        var draft = new PlanDraftRequest(op, planId, Account.Setup(), "Mine",
            [new ManualWorkoutSpec("A", [new PrescriptionExercise("e1", "bench-press", "Bench press", false, 3, 8, 12, null, 90)])]);
        var oldDraft = new
        {
            operationId = op, planId, setup = Account.Setup(), title = "Mine",
            manualWorkouts = new[] { new { title = "A", exercises = new[] { new { occurrenceKey = "e1", catalogKey = "bench-press", name = "Bench press",
                isTimed = false, targetSets = 3, targetRepsMin = 8, targetRepsMax = 12, targetDurationSeconds = (int?)null, restSeconds = 90 } } } },
        };
        Assert.Equal(SemanticHash.Compute("plan.draft", oldDraft), SemanticHash.Compute("plan.draft", draft));

        var schedule = new ScheduleChangeRequest(op, 3, "skip", occasionId, null, Account.Friday);
        var oldSchedule = new { operationId = op, expectedPlanRevision = 3, action = "skip", occasionId, from = (DateOnly?)null, to = Account.Friday };
        Assert.Equal(SemanticHash.Compute("plan.schedule", new { id = planId, r = oldSchedule }), SemanticHash.Compute("plan.schedule", new { id = planId, r = schedule }));
    }
}
