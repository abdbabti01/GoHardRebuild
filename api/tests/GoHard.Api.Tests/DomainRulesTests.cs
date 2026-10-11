using System.Text.Json;
using System.Text.Json.Nodes;
using GoHard.Api.Application;
using GoHard.Api.Domain;

namespace GoHard.Api.Tests;

/// <summary>Pure rules driven by the fixture the Dart suite reads too (B1, W1 and the wire contract).</summary>
public class DomainRulesTests
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static IEnumerable<object[]> Cases(string section) =>
        Fixture.Root[section]!.AsArray().Select(c => new object[] { c!["name"]!.GetValue<string>() });

    private static JsonNode Case(string section, string name) =>
        Fixture.Root[section]!.AsArray().First(c => c!["name"]!.GetValue<string>() == name)!;

    [Theory, MemberData(nameof(Cases), "schedule")]
    public void Schedule_validation_matches_fixture(string name)
    {
        var c = Case("schedule", name);
        var occasions = c["occasions"].Deserialize<List<ScheduleOccasion>>(Json)!;
        var changes = c["changes"].Deserialize<List<ScheduleChange>>(Json)!;

        var result = ScheduleRules.Validate(occasions, changes, c["minimumRecoveryDays"]!.GetValue<int>());

        Assert.Equal(c["expectErrors"].Deserialize<List<string>>()!, result.Errors.Select(e => e.Code).ToList());
        var expected = c["expectChanged"]!.AsArray();
        Assert.Equal(expected.Count, result.Changed.Count);
        foreach (var (e, actual) in expected.Zip(result.Changed))
        {
            // A move keeps the occasion's identity, training week and original date.
            Assert.Equal(Guid.Parse(e!["id"]!.GetValue<string>()), actual.Id);
            Assert.Equal(Fixture.Date(e["originalDate"]), actual.OriginalDate);
            Assert.Equal(Fixture.Date(e["scheduledDate"]), actual.ScheduledDate);
            Assert.Equal(e["weekNumber"]!.GetValue<int>(), actual.WeekNumber);
        }
        Assert.Equal(Fixture.Date(c["expectBlockEnd"]), result.BlockEnd);
        Assert.Equal(occasions.Count, result.Projected.Count); // never adds or removes an occasion
    }

    [Theory, MemberData(nameof(Cases), "generate")]
    public void Schedule_generation_matches_fixture(string name)
    {
        var c = Case("generate", name);
        var weekdays = c["weekdays"].Deserialize<List<int>>()!.Select(d => (DayOfWeek)(d % 7)).ToList();

        var (errors, dates) = ScheduleRules.Generate(Fixture.Date(c["start"]), weekdays, c["sessionsPerWeek"]!.GetValue<int>(),
            c["blockWeeks"]!.GetValue<int>(), c["minimumRecoveryDays"]!.GetValue<int>());

        Assert.Equal(c["expectErrors"].Deserialize<List<string>>()!, errors.Select(e => e.Code).ToList());
        Assert.Equal(c["expectDates"]!.AsArray().Select(Fixture.Date).ToList(), dates.Select(d => d.Date).ToList());
    }

    [Theory, MemberData(nameof(Cases), "results")]
    public void Workout_result_matches_fixture(string name)
    {
        var c = Case("results", name);
        var result = WorkoutResultRules.Evaluate(c["prescription"].Deserialize<List<PrescribedExercise>>(Json)!,
            c["sets"].Deserialize<List<PerformedSet>>(Json)!, c["isManual"]!.GetValue<bool>());
        Assert.Equal(c["expect"].Deserialize<WorkoutResult>(Json), result);
    }

    [Fact]
    public void Wire_samples_round_trip_without_inventing_values()
    {
        var wire = Fixture.Root["wire"]!;
        var food = wire["foodEntry"].Deserialize<FoodEntryDto>(Json)!;
        Assert.Equal(0m, food.Macros.Calories);      // entered zero stays zero
        Assert.Null(food.Macros.Protein);            // blank stays unknown
        Assert.Equal("unknown", food.Provenance.Protein);
        Assert.Equal(new DateOnly(2026, 10, 9), food.DayKey);
        Assert.True(JsonNode.DeepEquals(wire["foodEntry"], JsonSerializer.SerializeToNode(food, Json)));

        var ack = wire["ackAccepted"].Deserialize<CommandAck<SetDto>>(Json)!;
        Assert.Equal(63.503m, ack.Data!.LoadKg);
        Assert.Equal(DateTimeKind.Utc, ack.Data.PerformedAtUtc.Kind);
        var conflict = wire["ackConflict"].Deserialize<CommandAck<SetDto>>(Json)!;
        Assert.Equal((Ack.Conflict, Ack.RevisionConflict, null), (conflict.Status, conflict.Code, conflict.Data));
        Assert.Equal(125, wire["finishRequest"].Deserialize<FinishRequest>(Json)!.ActiveDurationSeconds);
    }

    [Fact]
    public void Semantic_hash_ignores_order_and_number_format_but_not_values()
    {
        var a = SemanticHash.Compute("set.create", JsonNode.Parse("""{"reps":8,"loadKg":60.0,"id":"x","nested":{"b":1,"a":null}}""")!);
        var b = SemanticHash.Compute("set.create", JsonNode.Parse("""{ "id":"x", "nested":{"a":null,"b":1.00}, "loadKg":60, "reps":8 }""")!);
        var changed = SemanticHash.Compute("set.create", JsonNode.Parse("""{"reps":9,"loadKg":60.0,"id":"x","nested":{"b":1,"a":null}}""")!);
        var otherKind = SemanticHash.Compute("set.update", JsonNode.Parse("""{"reps":8,"loadKg":60.0,"id":"x","nested":{"b":1,"a":null}}""")!);
        Assert.Equal(a, b);
        Assert.NotEqual(a, changed);
        Assert.NotEqual(a, otherKind);
    }
}
