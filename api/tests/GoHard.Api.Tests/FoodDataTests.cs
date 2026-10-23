using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using GoHard.Api.Application;
using GoHard.Api.Application.FoodDiscovery;
using GoHard.Api.Domain;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Logging.Abstractions;

namespace GoHard.Api.Tests;

/// <summary>A provider that answers from recorded responses. No test in this project reaches a real provider.</summary>
public sealed class StubProvider(Func<HttpRequestMessage, Task<HttpResponseMessage>> respond) : HttpMessageHandler
{
    public List<HttpRequestMessage> Requests { get; } = [];
    public static string Recorded(string name) => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", name));
    public static HttpResponseMessage Json(string body, HttpStatusCode status = HttpStatusCode.OK) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        lock (Requests) Requests.Add(request);
        return respond(request).WaitAsync(ct);   // like a real connection, it gives up when the caller does
    }
}

public sealed class TestTime : TimeProvider
{
    public DateTimeOffset Now { get; set; }
    public override DateTimeOffset GetUtcNow() => Now;
}

/// <summary>Normalization of recorded Open Food Facts and USDA responses, and the lookup service's budgets.</summary>
public class FoodProviderTests
{
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);
    private static readonly DateTime At = new(2026, 10, 12, 0, 0, 0, DateTimeKind.Utc);
    private static JsonElement Recorded(string name) => JsonDocument.Parse(StubProvider.Recorded(name)).RootElement;

    private static FoodItem Off(string nutrients, string product = "") => OpenFoodFactsProvider.Parse(JsonDocument.Parse(
        "{\"code\":\"00012345\",\"product\":{\"product_name\":\"Test\"" + product + ",\"nutrition\":{\"aggregated_set\":{\"per\":\"100g\",\"nutrients\":" + nutrients + "}}}}").RootElement, At)!;

    [Fact]
    public void Open_food_facts_product_normalizes_to_the_shared_wire_sample()
    {
        var item = OpenFoodFactsProvider.Parse(Recorded("off_product_100g.json"), At)!;
        Assert.True(JsonNode.DeepEquals(Fixture.Root["wire"]!["foodItem"], JsonSerializer.SerializeToNode(item, Web)),
            JsonSerializer.Serialize(item, Web));
    }

    [Fact]
    public void Values_stated_per_100_ml_are_not_filed_as_grams_and_a_stated_zero_stays_zero()
    {
        var cola = OpenFoodFactsProvider.Parse(Recorded("off_product_100ml.json"), At)!;
        Assert.Equal(FoodBasis.Per100ml, cola.Basis);                  // the provider files this set under "100g"
        Assert.Equal((42.4m, 0m, 10.6m, 0m), (cola.Nutrients.Calories, cola.Nutrients.Protein, cola.Nutrients.Carbs, cola.Nutrients.Fat));
        Assert.Equal(new FoodServing("1 portion (330 ml)", null, 330m), Assert.Single(cola.Servings));
        Assert.Equal("5449000000996", cola.Barcode);
    }

    [Fact]
    public void Missing_estimated_and_mixed_basis_values_stay_unknown()
    {
        const string label = """ "source":"packaging","source_per":"100g","unit":"g" """;
        var item = Off("{\"proteins\":{" + label + ""","value":0},"fat":{"source":"estimate","source_per":"100g","unit":"g","value":12},"carbohydrates":{"source":"packaging","source_per":"100ml","unit":"g","value":5}}""");
        Assert.Equal(FoodBasis.Per100g, item.Basis);
        Assert.Null(item.Nutrients.Calories);                           // not on the label at all
        Assert.Equal(0m, item.Nutrients.Protein);                       // a stated zero
        Assert.Null(item.Nutrients.Fat);                                // estimated from ingredients, not a label value
        Assert.Null(item.Nutrients.Carbs);                              // stated per 100 ml: cannot be mixed with per 100 g
        Assert.Empty(item.Servings);                                    // no serving size is invented
        Assert.Equal("00012345", item.Barcode);                         // leading zeros are significant
    }

    [Fact]
    public void Energy_given_only_in_kilojoules_is_converted_and_a_per_serving_label_needs_a_known_serving_unit()
    {
        var kj = Off("""{"energy-kj":{"source":"packaging","source_per":"100g","unit":"kJ","value":418.4}}""");
        Assert.Equal(100m, kj.Nutrients.Calories);
        const string perServing = """{"proteins":{"source":"packaging","source_per":"serving","unit":"g","value":8}}""";
        Assert.Null(Off(perServing).Nutrients.Protein);                 // per 100 of an unknown unit
        var ml = Off(perServing, ""","serving_quantity":"250","serving_quantity_unit":"ml" """);
        Assert.Equal((FoodBasis.Per100ml, 8m, 250m), (ml.Basis, ml.Nutrients.Protein, ml.Servings.Single().Milliliters));
        Assert.Null(OpenFoodFactsProvider.Parse(Recorded("off_not_found.json"), At));
    }

    [Fact]
    public void Usda_foods_keep_ids_units_and_only_the_portions_that_have_a_weight()
    {
        var generic = UsdaProvider.Parse(Recorded("usda_search_generic.json"), At);
        var foundation = generic.Single(f => f.SourceId == "2759004");
        Assert.Equal(new Macros(null, null, null, null), foundation.Nutrients);   // this record carries none of the four
        var legacy = generic.Single(f => f.SourceId == "171515");
        Assert.Equal(("Chicken breast tenders, breaded, uncooked", FoodBasis.Per100g, new Macros(263m, 14.7m, 15m, 15.8m)), (legacy.Name, legacy.Basis, legacy.Nutrients));
        Assert.Equal("SR Legacy · Poultry Products", legacy.Description);
        var rice = generic.Single(f => f.SourceId == "2708402");
        Assert.Equal(new FoodServing("1 cup, cooked", 158m, null), Assert.Single(rice.Servings)); // "Quantity not specified" is not a portion

        var branded = UsdaProvider.Parse(Recorded("usda_search_branded.json"), At);
        var craisins = branded[0];
        Assert.Equal(("031200037206", "OCEAN SPRAY", "usda"), (craisins.Barcode, craisins.Brand, craisins.Source));
        Assert.Equal(new FoodServing("2 Tbsp (30 g)", 30m, null), Assert.Single(craisins.Servings));
        Assert.Equal(0m, branded[1].Nutrients.Fat);                               // a stated zero, not a missing value
    }

    [Theory]
    [InlineData("034000470693", "0034000470693")]   // the documented example: UPC-A is stored as 13 digits
    [InlineData("0034000470693", "0034000470693")]
    [InlineData("3017620422003", "3017620422003")]
    [InlineData("0000000012345", "00012345")]
    [InlineData(" 96385074 ", "96385074")]
    [InlineData("12345", null)]
    [InlineData("301762042200X", null)]
    [InlineData("https://example.test/a", null)]
    [InlineData("0000000000000", null)]
    public void Barcodes_are_text_and_follow_the_documented_normalization(string raw, string? expected) =>
        Assert.Equal(expected, Barcodes.Normalize(raw));

    private static (FoodDiscoveryService Service, StubProvider Off, StubProvider Usda, TestTime Time) Service(
        Func<HttpRequestMessage, Task<HttpResponseMessage>>? off = null, Func<HttpRequestMessage, Task<HttpResponseMessage>>? usda = null, Action<FoodDataOptions>? configure = null)
    {
        var options = new FoodDataOptions { UsdaApiKey = "test-key", TimeoutSeconds = 1 };
        configure?.Invoke(options);
        var offStub = new StubProvider(off ?? (_ => Task.FromResult(StubProvider.Json(StubProvider.Recorded("off_product_100g.json")))));
        var usdaStub = new StubProvider(usda ?? (r => Task.FromResult(StubProvider.Json(StubProvider.Recorded(
            r.RequestUri!.Query.Contains("Branded") ? "usda_search_branded.json" : "usda_search_generic.json")))));
        var time = new TestTime { Now = new DateTimeOffset(At) };
        return (new FoodDiscoveryService(new(new HttpClient(offStub) { BaseAddress = new("https://off.test/") }),
            new(new HttpClient(usdaStub) { BaseAddress = new("https://usda.test/fdc/v1/") }), options, NullLogger<FoodDiscoveryService>.Instance, time), offStub, usdaStub, time);
    }

    [Fact]
    public async Task Identical_lookups_share_one_provider_call_and_the_answer_is_remembered()
    {
        var gate = new TaskCompletionSource();
        var (service, off, _, _) = Service(off: async _ => { await gate.Task; return StubProvider.Json(StubProvider.Recorded("off_product_100g.json")); });
        var waiting = Enumerable.Range(0, 10).Select(_ => service.BarcodeAsync("3017620422003", default)).ToList();
        gate.SetResult();
        var results = await Task.WhenAll(waiting);
        Assert.All(results, r => Assert.Equal("Nutella", r.Value!.Name));
        Assert.Single(off.Requests);
        Assert.Equal(LookupStatus.Ok, (await service.BarcodeAsync("3017620422003", default)).Status);
        Assert.Single(off.Requests);                                    // answered from memory
        Assert.Contains("api/v3.6/product/3017620422003.json", off.Requests[0].RequestUri!.ToString());
    }

    [Fact]
    public async Task Not_found_is_remembered_and_an_invalid_code_never_leaves_the_server()
    {
        var (service, off, _, _) = Service(off: _ => Task.FromResult(StubProvider.Json(StubProvider.Recorded("off_not_found.json"), HttpStatusCode.NotFound)));
        Assert.Equal(LookupStatus.NotFound, (await service.BarcodeAsync("96385074", default)).Status);
        Assert.Equal(LookupStatus.NotFound, (await service.BarcodeAsync("96385074", default)).Status);
        Assert.Single(off.Requests);
        Assert.Equal(LookupStatus.Invalid, (await service.BarcodeAsync("javascript:alert(1)", default)).Status);
        Assert.Single(off.Requests);
    }

    [Fact]
    public async Task A_provider_rate_limit_stops_further_calls_until_the_pause_ends()
    {
        var (service, off, _, time) = Service(off: _ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.TooManyRequests)));
        Assert.Equal(LookupStatus.RateLimited, (await service.BarcodeAsync("96385074", default)).Status);
        Assert.Equal(LookupStatus.RateLimited, (await service.BarcodeAsync("3017620422003", default)).Status);
        Assert.Single(off.Requests);                                    // the second was not sent at all
        time.Now += TimeSpan.FromMinutes(6);
        await service.BarcodeAsync("3017620422003", default);
        Assert.Equal(2, off.Requests.Count);
    }

    [Fact]
    public async Task The_shared_budget_is_never_overspent_and_a_failure_is_retried_once_and_not_remembered()
    {
        var (budgeted, off, _, _) = Service(configure: o => o.OpenFoodFactsPerMinute = 2);
        var statuses = new List<LookupStatus>();
        foreach (var code in new[] { "11111111", "22222222", "33333333" }) statuses.Add((await budgeted.BarcodeAsync(code, default)).Status);
        Assert.Equal([LookupStatus.Ok, LookupStatus.Ok, LookupStatus.RateLimited], statuses);
        Assert.Equal(2, off.Requests.Count);

        var (failing, down, _, _) = Service(off: _ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.BadGateway)));
        Assert.Equal(LookupStatus.Unavailable, (await failing.BarcodeAsync("96385074", default)).Status);
        Assert.Equal(2, down.Requests.Count);
        await failing.BarcodeAsync("96385074", default);
        Assert.Equal(4, down.Requests.Count);                           // tried again: an outage is not an answer

        var (slow, hung, _, _) = Service(off: async _ => { await Task.Delay(TimeSpan.FromSeconds(30)); return StubProvider.Json("{}"); });
        Assert.Equal(LookupStatus.Unavailable, (await slow.BarcodeAsync("96385074", default)).Status); // bounded by the 1 s timeout
    }

    [Fact]
    public async Task Search_puts_basic_foods_before_branded_and_needs_a_real_key()
    {
        var (service, _, usda, _) = Service();
        var found = await service.SearchAsync("  Chicken   breast ", default);
        Assert.Equal(LookupStatus.Ok, found.Status);
        Assert.Equal(["2759004", "171515", "174608", "2708356", "2708402", "2035482", "2038865"], found.Value!.Results.Select(r => r.SourceId));
        Assert.Equal(2, usda.Requests.Count);
        Assert.All(usda.Requests, r => Assert.DoesNotContain("api_key", r.RequestUri!.Query));   // the key never travels in a URL
        await service.SearchAsync("chicken breast", default);
        Assert.Equal(2, usda.Requests.Count);                           // same search, remembered
        Assert.Equal(LookupStatus.Invalid, (await service.SearchAsync("a", default)).Status);

        foreach (var key in new[] { null, "", "DEMO_KEY" })
        {
            var (unconfigured, _, none, _) = Service(configure: o => o.UsdaApiKey = key);
            Assert.Equal(LookupStatus.NotConfigured, (await unconfigured.SearchAsync("chicken", default)).Status);
            Assert.Empty(none.Requests);
        }

        var (partial, _, _, _) = Service(usda: r => Task.FromResult(r.RequestUri!.Query.Contains("Branded")
            ? new HttpResponseMessage(HttpStatusCode.BadGateway) : StubProvider.Json(StubProvider.Recorded("usda_search_generic.json"))));
        Assert.Equal(5, (await partial.SearchAsync("rice", default)).Value!.Results.Count);  // basic foods alone are still an honest answer
    }
}

/// <summary>Goals, food sources, reusable foods and the lookup endpoints on real PostgreSQL.</summary>
[Collection("api")]
public class FoodDataTests(PostgresFixture pg)
{
    private static StringContent Raw(string json) => new(json, Encoding.UTF8, "application/json");
    private static JsonElement Element(string json) => JsonDocument.Parse(json).RootElement;

    private static async Task<ProfileDto> ProfileAsync(Account a) => (await a.Http.GetFromJsonAsync<ProfileDto>("/api/v1/me", Account.Json))!;

    [Fact]
    public async Task Goals_are_set_kept_by_older_payloads_and_cleared_only_by_an_explicit_null()
    {
        var a = await Account.RegisterAsync(pg.Api);
        Assert.Equal((null, null), ((await ProfileAsync(a)).CalorieGoal, (await ProfileAsync(a)).ProteinGoal));   // none is suggested

        var set = await a.PutAsync<ProfileDto>("/me", new ProfileUpdateRequest(Guid.NewGuid(), 1, "Test Person", "dark", "kg", false, null, new(true, 2200), new(true, 140)));
        Assert.Equal(("accepted", 2200, 140), (set.Status, set.Data.CalorieGoal, set.Data.ProteinGoal));

        // The payload an app from before goals sends: no goal fields at all. Sent twice, as a lost response would be.
        var legacy = $$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":2,"displayName":"Renamed","appearance":"dark","loadUnit":"lb","remindersEnabled":false,"reminderLocalTime":null}""";
        var first = await a.Http.PutAsync("/api/v1/me", Raw(legacy));
        var retry = await a.Http.PutAsync("/api/v1/me", Raw(legacy));
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(await first.Content.ReadAsStringAsync(), await retry.Content.ReadAsStringAsync());
        var kept = await ProfileAsync(a);
        Assert.Equal(("Renamed", "lb", 2200, 140), (kept.DisplayName, kept.LoadUnit, kept.CalorieGoal, kept.ProteinGoal));

        // Explicit null clears one goal; the other, not sent, is kept.
        var cleared = await a.Http.PutAsync("/api/v1/me", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":3,"displayName":"Renamed","appearance":"dark","loadUnit":"lb","remindersEnabled":false,"reminderLocalTime":null,"calorieGoal":null}"""));
        Assert.Equal(HttpStatusCode.OK, cleared.StatusCode);
        Assert.Equal((null, 140), ((await ProfileAsync(a)).CalorieGoal, (await ProfileAsync(a)).ProteinGoal));

        foreach (var (calories, protein) in new[] { (499, 100), (10001, 100), (2000, 9), (2000, 501) })
        {
            var bad = await a.PutAsync<ProfileDto>("/me", new ProfileUpdateRequest(Guid.NewGuid(), 4, "Renamed", "dark", "lb", false, null, new(true, calories), new(true, protein)));
            Assert.Equal(("rejected", Ack.Invalid), (bad.Status, bad.Code));
        }
        Assert.Equal(140, (await a.SnapshotAsync()).Profile.ProteinGoal);
    }

    [Fact]
    public void Commands_from_before_the_new_fields_keep_their_semantic_hash()
    {
        var op = Guid.NewGuid();
        Assert.Equal(
            SemanticHash.Compute("profile.update", JsonNode.Parse($$"""{"operationId":"{{op}}","expectedRevision":1,"displayName":"A","appearance":"dark","loadUnit":"kg","remindersEnabled":false,"reminderLocalTime":null}""")!),
            SemanticHash.Compute("profile.update", new ProfileUpdateRequest(op, 1, "A", "dark", "kg", false, null)));
        Assert.NotEqual(
            SemanticHash.Compute("profile.update", new ProfileUpdateRequest(op, 1, "A", "dark", "kg", false, null)),
            SemanticHash.Compute("profile.update", new ProfileUpdateRequest(op, 1, "A", "dark", "kg", false, null, new(true, null))));   // clearing is a different command
        var entry = Guid.NewGuid();
        Assert.Equal(
            SemanticHash.Compute("food.create", JsonNode.Parse($$"""{"operationId":"{{op}}","entryId":"{{entry}}","dayKey":"2026-10-09","meal":"Lunch","name":"Soup","amountDescription":"1 bowl","macros":{"calories":0,"protein":null,"carbs":null,"fat":null} }""")!),
            SemanticHash.Compute("food.create", new FoodCreateRequest(op, entry, Account.Friday, "Lunch", "Soup", "1 bowl", new Macros(0m, null, null, null))));
    }

    private const string Snapshot = """{"item":{"source":"off","sourceId":"3017620422003","barcode":"3017620422003","name":"Nutella","basis":"100g","nutrients":{"calories":539,"protein":6.3,"carbs":57.5,"fat":30.9}},"quantity":30,"unit":"g"}""";

    [Fact]
    public async Task A_logged_food_keeps_its_own_snapshot_and_tells_imported_values_from_corrected_ones()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var id = Guid.NewGuid();
        // 30 g of a per-100 g food; the person corrected protein by hand and fat is unknown for this entry.
        var created = await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), id, Account.Friday, "Breakfast", "Nutella", "30 g",
            new Macros(161.7m, 2m, 17.25m, null), Element(Snapshot), new MacroProvenance("imported", "entered", "imported", "unknown")));
        Assert.Equal("accepted", created.Status);
        Assert.Equal(new MacroProvenance("imported", "entered", "imported", "unknown"), created.Data.Provenance);
        Assert.Equal("3017620422003", created.Data.Source!.Value.GetProperty("item").GetProperty("barcode").GetString());

        // A reusable copy of the same food is saved and then changed. The meal already logged does not move.
        var saved = Guid.NewGuid();
        Assert.Equal("accepted", (await a.PutAsync<SavedFoodDto>($"/saved-foods/{saved}", new SavedFoodPutRequest(Guid.NewGuid(), 0, Element("""{"name":"Nutella","basis":"100g","nutrients":{"calories":539}}"""), true))).Status);
        Assert.Equal("accepted", (await a.PutAsync<SavedFoodDto>($"/saved-foods/{saved}", new SavedFoodPutRequest(Guid.NewGuid(), 1, Element("""{"name":"Nutella","basis":"100g","nutrients":{"calories":999}}"""), true))).Status);
        var after = (await a.SnapshotAsync()).FoodEntries.Single();
        Assert.Equal((161.7m, 2m, 539m), (after.Macros.Calories, after.Macros.Protein, after.Source!.Value.GetProperty("item").GetProperty("nutrients").GetProperty("calories").GetDecimal()));

        // An edit from an app that predates sources is a deliberate change by the person: the values become entered.
        var legacyEdit = await a.Http.PutAsync($"/api/v1/food-entries/{id}", Raw($$"""{"operationId":"{{Guid.NewGuid()}}","expectedRevision":1,"dayKey":"2026-10-09","meal":"Breakfast","name":"Nutella","amountDescription":"40 g","macros":{"calories":215.6,"protein":null,"carbs":23,"fat":12.4} }"""));
        Assert.Equal(HttpStatusCode.OK, legacyEdit.StatusCode);
        var edited = (await a.SnapshotAsync()).FoodEntries.Single();
        Assert.Equal((new MacroProvenance("entered", "unknown", "entered", "entered"), 2), (edited.Provenance, edited.Revision));
        Assert.Null(edited.Source);

        foreach (var (macros, source, provenance) in new (Macros, JsonElement?, MacroProvenance)[]
        {
            (new(100m, null, null, null), null, new("imported", "unknown", "unknown", "unknown")),               // imported from nothing
            (new(100m, null, null, null), Element(Snapshot), new("imported", "imported", "unknown", "unknown")), // a missing value called imported
            (new(100m, 0m, null, null), Element(Snapshot), new("imported", "unknown", "unknown", "unknown")),    // a stated zero called unknown
            (new(100m, null, null, null), Element("[1]"), new("entered", "unknown", "unknown", "unknown")),      // not a snapshot
        })
            Assert.Equal("rejected", (await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, "Snack", "Bad", "1", macros, source, provenance))).Status);
    }

    [Fact]
    public async Task Saved_foods_are_owned_revision_checked_and_never_count_as_eaten()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        var id = Guid.NewGuid();
        var item = Element("""{"source":"user","name":"Overnight oats","basis":"serving","nutrients":{"calories":420,"protein":24,"carbs":null,"fat":0},"servings":[{"label":"1 jar","grams":null,"milliliters":null}]}""");
        var request = new SavedFoodPutRequest(Guid.NewGuid(), 0, item, false);

        var created = await a.PutAsync<SavedFoodDto>($"/saved-foods/{id}", request);
        var retry = await a.PutAsync<SavedFoodDto>($"/saved-foods/{id}", request);
        Assert.Equal(("accepted", 1, created.Raw), (created.Status, created.Data.Revision, retry.Raw));
        Assert.Empty((await a.SnapshotAsync()).FoodEntries);                          // saving is not eating
        var stored = (await a.SnapshotAsync()).SavedFoods!.Single();
        Assert.Equal(JsonValueKind.Null, stored.Item.GetProperty("nutrients").GetProperty("carbs").ValueKind);   // unknown stays unknown
        Assert.Equal(0, stored.Item.GetProperty("nutrients").GetProperty("fat").GetInt32());                    // zero stays zero

        var favourite = await a.PutAsync<SavedFoodDto>($"/saved-foods/{id}", request with { OperationId = Guid.NewGuid(), ExpectedRevision = 1, IsFavourite = true });
        Assert.Equal((2, true), (favourite.Data.Revision, favourite.Data.IsFavourite));
        var stale = await a.PutAsync<SavedFoodDto>($"/saved-foods/{id}", request with { OperationId = Guid.NewGuid(), ExpectedRevision = 1 });
        Assert.Equal(("conflict", Ack.RevisionConflict, true), (stale.Status, stale.Code, stale.Data.IsFavourite));

        // Another account can neither see, change nor remove it, and cannot tell it exists.
        Assert.Empty((await other.SnapshotAsync()).SavedFoods!);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PutAsync<SavedFoodDto>($"/saved-foods/{id}", request with { OperationId = Guid.NewGuid(), ExpectedRevision = 2 })).Http);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsync<SavedFoodDto>($"/saved-foods/{id}/delete", new RevisionCommand(Guid.NewGuid(), 2))).Http);

        Assert.Equal("rejected", (await a.PutAsync<SavedFoodDto>($"/saved-foods/{Guid.NewGuid()}", request with { OperationId = Guid.NewGuid(), Item = Element("""{"name":"  "}""") })).Status);
        var removed = await a.PostAsync<SavedFoodDto>($"/saved-foods/{id}/delete", new RevisionCommand(Guid.NewGuid(), 2));
        Assert.Equal(("accepted", true), (removed.Status, removed.Data.IsDeleted));
        Assert.True((await a.SnapshotAsync()).SavedFoods!.Single().IsDeleted);

        // Erasing the account erases its foods with it.
        var gone = await a.Http.SendAsync(new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(a.Password)) });
        Assert.Equal(HttpStatusCode.NoContent, gone.StatusCode);
        await using var db = pg.SharedDb();
        Assert.False(await db.SavedFoods.AnyAsync(f => f.UserId == a.UserId));
    }

    [Fact]
    public async Task Lookup_endpoints_need_a_sign_in_report_provider_trouble_truthfully_and_declare_search_only_with_a_key()
    {
        var a = await Account.RegisterAsync(pg.Api);
        Assert.Equal(HttpStatusCode.Unauthorized, (await pg.Api.CreateClient().GetAsync("/api/v1/foods/barcode/3017620422003")).StatusCode);

        var found = await a.Http.GetFromJsonAsync<JsonElement>("/api/v1/foods/barcode/3017620422003");
        Assert.Equal(("Nutella", "100g", 539m), (found.GetProperty("item").GetProperty("name").GetString(), found.GetProperty("item").GetProperty("basis").GetString(),
            found.GetProperty("item").GetProperty("nutrients").GetProperty("calories").GetDecimal()));
        Assert.Empty((await a.SnapshotAsync()).FoodEntries);                          // a lookup logs nothing

        async Task<(HttpStatusCode, string?)> Get(HttpClient http, string path)
        {
            var r = await http.GetAsync("/api/v1" + path);
            return (r.StatusCode, (await r.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        }
        Assert.Equal((HttpStatusCode.UnprocessableEntity, "INVALID_QUERY"), await Get(a.Http, "/foods/barcode/not-a-code"));
        Assert.Equal((HttpStatusCode.ServiceUnavailable, "PROVIDER_NOT_CONFIGURED"), await Get(a.Http, "/foods/search?q=chicken"));
        var capabilities = await a.Http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities");
        var declared = capabilities.GetProperty("capabilities").EnumerateArray().Select(c => c.GetString()).ToList();
        Assert.Contains("food.barcode", declared);
        Assert.Contains("profile.nutrition-goals", declared);
        Assert.DoesNotContain("food.search", declared);
        Assert.Equal(2, capabilities.GetProperty("minimumClientContract").GetInt32());   // additive fields do not raise it (2 = required verification)

        // A server with a key declares search and answers it; the same database, a separate host.
        await using var keyed = new ApiFactory(pg.Api.ConnectionString)
        {
            Settings = new() { ["FoodData:UsdaApiKey"] = "test-key", ["FoodData:PerUserPerMinute"] = "3" },
            Provider = new StubProvider(r => Task.FromResult(r.RequestUri!.Host.Contains("usda")
                ? StubProvider.Json(StubProvider.Recorded(r.RequestUri.Query.Contains("Branded") ? "usda_search_branded.json" : "usda_search_generic.json"))
                : StubProvider.Json(StubProvider.Recorded("off_not_found.json"), HttpStatusCode.NotFound))),
        };
        var b = await Account.RegisterAsync(keyed);
        Assert.Contains("food.search", (await b.Http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities")).GetProperty("capabilities").EnumerateArray().Select(c => c.GetString()));
        var results = (await b.Http.GetFromJsonAsync<JsonElement>("/api/v1/foods/search?q=chicken%20breast")).GetProperty("results");
        Assert.Equal(7, results.GetArrayLength());
        Assert.Equal((HttpStatusCode.NotFound, "NOT_FOUND"), await Get(b.Http, "/foods/barcode/96385074"));
        // One person cannot spend everyone's provider budget: the fourth request inside a minute is refused here.
        await b.Http.GetAsync("/api/v1/foods/search?q=chicken%20breast");
        Assert.Equal(HttpStatusCode.TooManyRequests, (await b.Http.GetAsync("/api/v1/foods/search?q=chicken%20breast")).StatusCode);
    }

    [Fact]
    public async Task Upgrade_adds_goals_sources_and_saved_foods_without_touching_existing_records()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: false);
        await using var db = PostgresFixture.NewDb(cs);
        await db.GetService<IMigrator>().MigrateAsync("AddActivitiesAndProposals");
        var userId = Guid.NewGuid();
        var foodId = Guid.NewGuid();
        await db.Database.ExecuteSqlAsync($"""INSERT INTO "Users" ("Id","Email","PasswordHash","DisplayName","Appearance","LoadUnit","RemindersEnabled","Revision","SecurityStamp","CreatedAtUtc") VALUES ({userId},'old@example.test','x','Old','dark','lb',false,4,'s',now())""");
        await db.Database.ExecuteSqlAsync($"""INSERT INTO "FoodEntries" ("Id","UserId","DayKey","Meal","Name","AmountDescription","Calories","CaloriesSource","ProteinSource","CarbsSource","FatSource","Revision","CreatedAtUtc") VALUES ({foodId},{userId},'2026-10-09','Lunch','Soup','1 bowl',0,'entered','unknown','unknown','unknown',2,now())""");

        await db.Database.MigrateAsync();

        Assert.True((await SchemaReadinessService.CheckAsync(db, default)).IsReady);
        var user = await db.Users.SingleAsync(u => u.Id == userId);
        Assert.Equal((4, "lb", null, null), (user.Revision, user.LoadUnit, user.CalorieGoal, user.ProteinGoalG));   // no goal appears by itself
        var food = await db.FoodEntries.SingleAsync(f => f.Id == foodId);
        Assert.Equal((0m, null, null, 2), (food.Calories, food.ProteinG, food.SourceJson, food.Revision));
        Assert.Empty(await db.SavedFoods.ToListAsync());
    }
}
