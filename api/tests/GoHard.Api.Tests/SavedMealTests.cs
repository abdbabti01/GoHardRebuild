using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GoHard.Api.Application;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>Saved meals and recipes, and logging a saved meal as one operation (docs/FOOD_DATA.md › Saved meals and recipes).</summary>
[Collection("api")]
public class SavedMealTests(PostgresFixture pg)
{
    private static JsonElement Element(string json) => JsonDocument.Parse(json).RootElement;

    private const string Egg = """{"source":"user","sourceId":"egg","name":"Egg","basis":"serving","nutrients":{"calories":72,"protein":6.3,"carbs":null,"fat":4.8},"servings":[{"label":"1 egg","grams":50}]}""";
    private static JsonElement Breakfast(string name = "Breakfast", int eggs = 2) => Element(
        $$"""{"kind":"meal","name":"{{name}}","components":[{"item":{{Egg}},"quantity":{{eggs}},"unit":"serving:0"}]}""");

    private static FoodBatchEntry Entry(Guid id, string name = "Egg", decimal? kcal = 144) =>
        new(id, Account.Friday, "Breakfast", name, "2 eggs", new Macros(kcal, 12.6m, null, 9.6m));

    [Fact]
    public async Task Saved_meals_are_owned_revision_checked_templates_that_never_log_food()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        var id = Guid.NewGuid();
        var put = new SavedMealPutRequest(Guid.NewGuid(), 0, Breakfast());

        var created = await a.PutAsync<SavedMealDto>($"/saved-meals/{id}", put);
        var retry = await a.PutAsync<SavedMealDto>($"/saved-meals/{id}", put);
        Assert.Equal(("accepted", 1, created.Raw), (created.Status, created.Data.Revision, retry.Raw));
        var snapshot = await a.SnapshotAsync();
        Assert.Empty(snapshot.FoodEntries);   // saving a meal is not eating it
        Assert.Equal("Breakfast", snapshot.SavedMeals!.Single().Body.GetProperty("name").GetString());

        var updated = await a.PutAsync<SavedMealDto>($"/saved-meals/{id}", new SavedMealPutRequest(Guid.NewGuid(), 1, Breakfast(eggs: 3)));
        Assert.Equal(2, updated.Data.Revision);
        var stale = await a.PutAsync<SavedMealDto>($"/saved-meals/{id}", new SavedMealPutRequest(Guid.NewGuid(), 1, Breakfast(eggs: 4)));
        Assert.Equal(("conflict", Ack.RevisionConflict), (stale.Status, stale.Code));
        Assert.Equal(3, stale.Data.Body.GetProperty("components")[0].GetProperty("quantity").GetInt32()); // the account's version comes back for review

        // Another account cannot see, change or remove it.
        Assert.Empty((await other.SnapshotAsync()).SavedMeals!);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PutAsync<SavedMealDto>($"/saved-meals/{id}", new SavedMealPutRequest(Guid.NewGuid(), 2, Breakfast()))).Http);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsync<SavedMealDto>($"/saved-meals/{id}/delete", new RevisionCommand(Guid.NewGuid(), 2))).Http);

        var removed = await a.PostAsync<SavedMealDto>($"/saved-meals/{id}/delete", new RevisionCommand(Guid.NewGuid(), 2));
        Assert.Equal(("accepted", true), (removed.Status, removed.Data.IsDeleted));
        Assert.True((await a.SnapshotAsync()).SavedMeals!.Single().IsDeleted);   // a tombstone, so other phones learn of it

        // Account erasure takes its definitions with it.
        var gone = await a.Http.SendAsync(new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(a.Password)) });
        Assert.Equal(HttpStatusCode.NoContent, gone.StatusCode);
        await using var db = pg.SharedDb();
        Assert.False(await db.SavedMeals.AnyAsync(m => m.UserId == a.UserId));
    }

    [Theory]
    [InlineData("""{"kind":"meal","name":"  ","components":[{"item":{"name":"Egg"},"quantity":1,"unit":"g"}]}""")]
    [InlineData("""{"kind":"meal","name":"Empty","components":[]}""")]
    [InlineData("""{"kind":"snack","name":"Odd","components":[{"item":{"name":"Egg"},"quantity":1,"unit":"g"}]}""")]
    [InlineData("""{"kind":"meal","name":"Zero","components":[{"item":{"name":"Egg"},"quantity":0,"unit":"g"}]}""")]
    [InlineData("""{"kind":"meal","name":"Negative","components":[{"item":{"name":"Egg"},"quantity":-2,"unit":"g"}]}""")]
    [InlineData("""{"kind":"meal","name":"No unit","components":[{"item":{"name":"Egg"},"quantity":1}]}""")]
    [InlineData("""{"kind":"recipe","name":"No yield","components":[{"item":{"name":"Egg"},"quantity":1,"unit":"g"}]}""")]
    [InlineData("""{"kind":"recipe","name":"Zero yield","servings":0,"components":[{"item":{"name":"Egg"},"quantity":1,"unit":"g"}]}""")]
    [InlineData("""{"kind":"recipe","name":"Bad weight","servings":4,"preparedWeightG":-1,"components":[{"item":{"name":"Egg"},"quantity":1,"unit":"g"}]}""")]
    public async Task Invalid_definitions_are_refused(string body)
    {
        var a = await Account.RegisterAsync(pg.Api);
        Assert.Equal("rejected", (await a.PutAsync<SavedMealDto>($"/saved-meals/{Guid.NewGuid()}", new SavedMealPutRequest(Guid.NewGuid(), 0, Element(body)))).Status);
    }

    [Fact]
    public async Task Definitions_are_bounded_in_components_and_size()
    {
        var a = await Account.RegisterAsync(pg.Api);
        string Parts(int n, string item) => string.Join(",", Enumerable.Repeat($$"""{"item":{{item}},"quantity":1,"unit":"serving:0"}""", n));
        Assert.Equal("accepted", (await a.PutAsync<SavedMealDto>($"/saved-meals/{Guid.NewGuid()}",
            new SavedMealPutRequest(Guid.NewGuid(), 0, Element($$"""{"kind":"recipe","name":"Big","servings":8,"preparedWeightG":1200,"components":[{{Parts(30, Egg)}}]}""")))).Status);
        Assert.Equal("rejected", (await a.PutAsync<SavedMealDto>($"/saved-meals/{Guid.NewGuid()}",
            new SavedMealPutRequest(Guid.NewGuid(), 0, Element($$"""{"kind":"meal","name":"Too many","components":[{{Parts(31, Egg)}}]}""")))).Status);
        var huge = $$"""{"name":"Egg","description":"{{new string('x', 2000)}}"}""";
        Assert.Equal("rejected", (await a.PutAsync<SavedMealDto>($"/saved-meals/{Guid.NewGuid()}",
            new SavedMealPutRequest(Guid.NewGuid(), 0, Element($$"""{"kind":"meal","name":"Too large","components":[{{Parts(30, huge)}}]}""")))).Status);
    }

    [Fact]
    public async Task A_meal_is_logged_whole_or_not_at_all_and_a_retry_replays_it()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var (egg, oats) = (Guid.NewGuid(), Guid.NewGuid());
        var batch = new FoodBatchRequest(Guid.NewGuid(), [Entry(egg), Entry(oats, "Oats", null)]);

        var logged = await a.PostAsync<FoodBatchResult>("/food-entries/batch", batch);
        Assert.Equal(("accepted", 2), (logged.Status, logged.Data.Entries.Count));
        Assert.Null(logged.Data.Entries[1].Macros.Calories);                           // unknown stays unknown
        Assert.Equal(new[] { egg, oats }, (await a.SnapshotAsync()).FoodEntries.Select(f => f.Id)); // in the meal's order

        // A lost answer: the same operation again replays the first answer and records nothing more.
        var again = await a.PostAsync<FoodBatchResult>("/food-entries/batch", batch);
        Assert.Equal(logged.Raw, again.Raw);
        Assert.Equal(2, (await a.SnapshotAsync()).FoodEntries.Count);

        // One invalid component: nothing of that meal is recorded.
        var bad = new FoodBatchRequest(Guid.NewGuid(), [Entry(Guid.NewGuid()), Entry(Guid.NewGuid(), "Bad", -5)]);
        Assert.Equal("rejected", (await a.PostAsync<FoodBatchResult>("/food-entries/batch", bad)).Status);
        // A reused entry ID (another phone's operation, say): nothing either.
        var reused = new FoodBatchRequest(Guid.NewGuid(), [Entry(Guid.NewGuid()), Entry(egg)]);
        var dup = await a.PostAsync<FoodBatchResult>("/food-entries/batch", reused);
        Assert.Equal(("conflict", "DUPLICATE_ID"), (dup.Status, dup.Code));
        var same = Guid.NewGuid();
        Assert.Equal("rejected", (await a.PostAsync<FoodBatchResult>("/food-entries/batch", new FoodBatchRequest(Guid.NewGuid(), [Entry(same), Entry(same)]))).Status);
        Assert.Equal("rejected", (await a.PostAsync<FoodBatchResult>("/food-entries/batch",
            new FoodBatchRequest(Guid.NewGuid(), [.. Enumerable.Range(0, 31).Select(_ => Entry(Guid.NewGuid()))]))).Status);
        Assert.Equal(2, (await a.SnapshotAsync()).FoodEntries.Count);
    }

    [Fact]
    public async Task A_recipe_portion_keeps_its_larger_snapshot_within_a_bound_and_template_changes_never_touch_it()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var recipeId = Guid.NewGuid();
        var recipe = Element($$"""{"kind":"recipe","name":"Chili","servings":4,"components":[{"item":{{Egg}},"quantity":8,"unit":"serving:0"}]}""");
        await a.PutAsync<SavedMealDto>($"/saved-meals/{recipeId}", new SavedMealPutRequest(Guid.NewGuid(), 0, recipe));

        // A snapshot over the ordinary 16,000 limit is taken for a recipe portion, up to its own bound.
        var big = new string('x', 20000);
        var source = JsonSerializer.SerializeToElement(new
        {
            recipe = new { id = recipeId, revision = 1, name = "Chili", servings = 4, note = big, components = Array.Empty<object>() },
            portion = new { quantity = 1, unit = "serving" }, partial = new { carbs = 0 },
        });
        var entry = Guid.NewGuid();
        var macros = new Macros(144, 12.6m, null, 9.6m);
        var logged = await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), entry, Account.Friday, "Dinner", "Chili", "1 serving", macros, source));
        Assert.Equal("accepted", logged.Status);
        var plain = Element($$"""{"item":{"name":"Egg","note":"{{big}}"},"quantity":1,"unit":"g"}""");
        Assert.Equal("rejected", (await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, "Dinner", "Egg", "1", macros, plain))).Status);
        var tooBig = JsonSerializer.SerializeToElement(new { recipe = new { note = new string('x', 50000) } });
        Assert.Equal("rejected", (await a.PostAsync<FoodEntryDto>("/food-entries", new FoodCreateRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Friday, "Dinner", "Chili", "1", macros, tooBig))).Status);

        // Editing and then deleting the recipe leaves the logged portion exactly as it was.
        var before = (await a.SnapshotAsync()).FoodEntries.Single(f => f.Id == entry);
        await a.PutAsync<SavedMealDto>($"/saved-meals/{recipeId}", new SavedMealPutRequest(Guid.NewGuid(), 1, Element($$"""{"kind":"recipe","name":"Chili v2","servings":6,"components":[{"item":{{Egg}},"quantity":2,"unit":"serving:0"}]}""")));
        await a.PostAsync<SavedMealDto>($"/saved-meals/{recipeId}/delete", new RevisionCommand(Guid.NewGuid(), 2));
        var after = (await a.SnapshotAsync()).FoodEntries.Single(f => f.Id == entry);
        Assert.Equal(JsonSerializer.Serialize(before), JsonSerializer.Serialize(after));
    }

    [Fact]
    public async Task The_server_declares_saved_meals()
    {
        var caps = await pg.Api.CreateClient().GetFromJsonAsync<JsonElement>("/api/v1/capabilities");
        Assert.Contains(SavedMealService.Capability, caps.GetProperty("capabilities").EnumerateArray().Select(c => c.GetString()));
    }
}
