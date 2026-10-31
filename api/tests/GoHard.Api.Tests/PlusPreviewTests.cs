using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GoHard.Api.Application;
using GoHard.Api.Application.Coach;
using GoHard.Api.Application.Plus;
using GoHard.Api.Domain;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace GoHard.Api.Tests;

/// <summary>GoHard Plus preview (docs/PLUS_PREVIEW.md): the entitlement model, owner-only switching and creation limits.</summary>
[Collection("api")]
public class PlusPreviewTests(PostgresFixture pg)
{
    private static readonly DateOnly Monday = new(2026, 10, 12);

    /// <summary>An API whose preview owner the test names after registering the account.</summary>
    private static (ApiFactory Api, PlusOptions Plus) Api(PostgresFixture pg, Action<PlusOptions>? setup = null)
    {
        var plus = new PlusOptions();
        setup?.Invoke(plus);
        return (new ApiFactory(pg.Api.ConnectionString) { Configure = s => s.AddSingleton(plus) }, plus);
    }

    private static async Task<JsonElement> EntitlementAsync(Account a) => await a.Http.GetFromJsonAsync<JsonElement>("/api/v1/entitlement");
    private static async Task<HttpStatusCode> SetTierAsync(Account a, string tier) =>
        (await a.Http.PutAsJsonAsync("/api/v1/preview/entitlement", new { tier })).StatusCode;

    private static PlanCreateRequest Plan(string title = "My split")
    {
        var w = new WorkoutDefinition(Guid.NewGuid(), "Full body", null, [new("e1", "bench-press", "Bench press", false, 3, 8, 12, null, 90)]);
        return new(Guid.NewGuid(), Guid.NewGuid(), title, Monday, 2, 45, "custom", [w], new PlanSchedule(PlanRules.Fixed, [new(1, w.Id)], [], [], 0));
    }

    private static Task<AckResult<PlanContextDto>> CreatePlanAsync(Account a, string title = "My split") => a.PostAsync<PlanContextDto>("/plans", Plan(title));

    private static JsonElement Meal(string name) => JsonDocument.Parse($$$"""
        {"kind":"meal","name":"{{{name}}}","components":[{"item":{"source":"user","sourceId":"egg","name":"Egg","basis":"serving","nutrients":{"calories":72}},"quantity":2,"unit":"serving:0"}]}
        """).RootElement;

    private static Task<AckResult<SavedMealDto>> PutMealAsync(Account a, Guid id, int revision, string name) =>
        a.PutAsync<SavedMealDto>($"/saved-meals/{id}", new SavedMealPutRequest(Guid.NewGuid(), revision, Meal(name)));

    [Fact]
    public async Task Every_account_starts_on_free_with_its_limits_and_allowance_and_no_purchases()
    {
        var (api, _) = Api(pg);
        await using var _api = api;
        var a = await Account.RegisterAsync(api);
        Assert.Contains(EntitlementService.Capability, (await a.Http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities")).GetProperty("capabilities").EnumerateArray().Select(c => c.GetString()));

        var e = await EntitlementAsync(a);
        Assert.Equal(("free", "default", true, false, false), (e.GetProperty("tier").GetString(), e.GetProperty("source").GetString(),
            e.GetProperty("preview").GetBoolean(), e.GetProperty("purchasesAvailable").GetBoolean(), e.GetProperty("canManagePreview").GetBoolean()));
        Assert.Equal((3, 10), (e.GetProperty("limits").GetProperty("savedPlans").GetInt32(), e.GetProperty("limits").GetProperty("savedMeals").GetInt32()));
        Assert.Empty(e.GetProperty("features").EnumerateArray());
        var allowance = e.GetProperty("allowance");
        Assert.Equal((0, 15, 15, 40), (allowance.GetProperty("used").GetInt32(), allowance.GetProperty("limit").GetInt32(), allowance.GetProperty("remaining").GetInt32(), allowance.GetProperty("dailyGuard").GetInt32()));
        var resets = allowance.GetProperty("resetsAtUtc").GetDateTime();
        Assert.Equal((1, 0, 0), (resets.Day, resets.Hour, resets.Minute));                    // 00:00 UTC on the 1st
        Assert.Equal(72 * 3600, e.GetProperty("validForSeconds").GetInt32());
        var compare = e.GetProperty("compare");
        Assert.Equal((3, 10, 15, 300), (compare.GetProperty("free").GetProperty("savedPlans").GetInt32(), compare.GetProperty("free").GetProperty("savedMeals").GetInt32(),
            compare.GetProperty("free").GetProperty("monthlyAi").GetInt32(), compare.GetProperty("plus").GetProperty("monthlyAi").GetInt32()));
    }

    [Fact]
    public async Task Only_the_configured_owner_can_switch_and_nothing_a_client_sends_grants_plus()
    {
        var (api, plus) = Api(pg);
        await using var _api = api;
        var owner = await Account.RegisterAsync(api);
        var other = await Account.RegisterAsync(api);
        plus.PreviewOwnerUserId = owner.UserId.ToString();

        // Someone else: the routes do not exist for them, and their account stays Free.
        Assert.Equal(HttpStatusCode.NotFound, await SetTierAsync(other, "plus"));
        Assert.Equal(HttpStatusCode.NotFound, (await other.Http.PostAsync("/api/v1/preview/allowance/reset", null)).StatusCode);
        // Forged fields on ordinary routes are ignored.
        await other.Http.PutAsJsonAsync("/api/v1/me", new { operationId = Guid.NewGuid(), expectedRevision = 1, displayName = "X", tier = "plus", source = "preview_override", isPlus = true });
        await other.Http.GetAsync("/api/v1/entitlement?tier=plus");
        // A stray override row for a non-owner grants nothing.
        await using (var db = PostgresFixture.NewDb(api.ConnectionString))
        {
            db.PreviewOverrides.Add(new PreviewOverride { UserId = other.UserId, Tier = "plus", UpdatedAtUtc = DateTime.UtcNow });
            await db.SaveChangesAsync();
        }
        Assert.Equal("free", (await EntitlementAsync(other)).GetProperty("tier").GetString());
        Assert.False((await EntitlementAsync(other)).GetProperty("canManagePreview").GetBoolean());

        // The owner, through the protected route only.
        Assert.True((await EntitlementAsync(owner)).GetProperty("canManagePreview").GetBoolean());
        Assert.Equal(HttpStatusCode.BadRequest, await SetTierAsync(owner, "gold"));
        Assert.Equal(HttpStatusCode.OK, await SetTierAsync(owner, "plus"));
        var e = await EntitlementAsync(owner);
        Assert.Equal(("plus", "preview_override", 300), (e.GetProperty("tier").GetString(), e.GetProperty("source").GetString(), e.GetProperty("allowance").GetProperty("limit").GetInt32()));
        Assert.Equal(JsonValueKind.Null, e.GetProperty("limits").GetProperty("savedPlans").ValueKind);
        Assert.Equal([EntitlementService.Progression, EntitlementService.TrendExplorer], e.GetProperty("features").EnumerateArray().Select(f => f.GetString()));
        Assert.Equal("free", (await EntitlementAsync(other)).GetProperty("tier").GetString());   // accounts stay apart

        // An owner who is no longer configured keeps the row but loses the override.
        plus.PreviewOwnerUserId = null;
        Assert.Equal("free", (await EntitlementAsync(owner)).GetProperty("tier").GetString());
        Assert.Equal(HttpStatusCode.NotFound, await SetTierAsync(owner, "free"));
    }

    [Fact]
    public async Task Free_accounts_make_three_saved_plans_and_archiving_one_frees_a_place()
    {
        var (api, _) = Api(pg);
        await using var _api = api;
        var a = await Account.RegisterAsync(api);
        for (var i = 0; i < 3; i++) Assert.Equal("accepted", (await CreatePlanAsync(a, $"Plan {i}")).Status);

        var fourth = await CreatePlanAsync(a, "Plan 4");
        Assert.Equal(("rejected", EntitlementService.PlanLimit), (fourth.Status, fourth.Code));
        var plans = (await a.ContextAsync()).Plans;
        Assert.Equal(3, plans.Count);
        // Duplicating (Continue) and the setup draft are new definitions too.
        var cont = await a.PostAsync<PlanContextDto>($"/plans/{plans[0].Id}/continue", new ContinueRequest(Guid.NewGuid(), Guid.NewGuid(), Monday.AddDays(21)));
        Assert.Equal(("rejected", EntitlementService.PlanLimit), (cont.Status, cont.Code));
        var draft = await a.PostAsync<PlanDraftResult>("/plan-drafts", new PlanDraftRequest(Guid.NewGuid(), Guid.NewGuid(), Account.Setup(), null, null));
        Assert.Equal(("rejected", EntitlementService.PlanLimit), (draft.Status, draft.Code));

        // Existing plans keep working: edit, activate. Neither is creation.
        var first = plans[0];
        var activated = await a.PostAsync<PlanContextDto>($"/plans/{first.Id}/activate", a.ActivateRequestFor(first, (await a.ContextAsync()).ContextRevision));
        Assert.Equal("accepted", activated.Status);

        var archived = await a.PostAsync<PlanContextDto>($"/plans/{plans[2].Id}/archive", new ArchiveRequest(Guid.NewGuid(), plans[2].Revision, true));
        Assert.Equal("accepted", archived.Status);
        Assert.Equal("accepted", (await CreatePlanAsync(a, "Plan 4")).Status);
        Assert.Equal(4, (await a.ContextAsync()).Plans.Count);                                   // the archived one is still there
    }

    [Fact]
    public async Task A_downgraded_owner_keeps_every_plan_and_meal_and_can_use_them_but_not_add_more()
    {
        var (api, plus) = Api(pg);
        await using var _api = api;
        var a = await Account.RegisterAsync(api);
        plus.PreviewOwnerUserId = a.UserId.ToString();
        Assert.Equal(HttpStatusCode.OK, await SetTierAsync(a, "plus"));
        for (var i = 0; i < 5; i++) Assert.Equal("accepted", (await CreatePlanAsync(a, $"Plan {i}")).Status);
        var meals = new List<Guid>();
        for (var i = 0; i < 12; i++)
        {
            var id = Guid.NewGuid();
            Assert.Equal("accepted", (await PutMealAsync(a, id, 0, $"Meal {i}")).Status);
            meals.Add(id);
        }

        Assert.Equal(HttpStatusCode.OK, await SetTierAsync(a, "free"));
        var snapshot = await a.SnapshotAsync();
        Assert.Equal((5, 12), (snapshot.Context.Plans.Count, snapshot.SavedMeals!.Count(m => !m.IsDeleted)));   // nothing hidden or removed

        // Over the limit: edit, use and log still work; a new one explains the limit.
        Assert.Equal("accepted", (await PutMealAsync(a, meals[0], 1, "Meal 0, renamed")).Status);
        var batch = await a.PostAsync<FoodBatchResult>("/food-entries/batch", new FoodBatchRequest(Guid.NewGuid(),
            [new FoodBatchEntry(Guid.NewGuid(), Monday, "Breakfast", "Egg", "2 eggs", new Macros(144, 12, 1, 10))]));
        Assert.Equal("accepted", batch.Status);
        var plan = snapshot.Context.Plans[0];
        Assert.Equal("accepted", (await a.PostAsync<PlanContextDto>($"/plans/{plan.Id}/activate", a.ActivateRequestFor(plan, snapshot.Context.ContextRevision))).Status);
        Assert.Equal(EntitlementService.PlanLimit, (await CreatePlanAsync(a)).Code);
        Assert.Equal(EntitlementService.MealLimit, (await PutMealAsync(a, Guid.NewGuid(), 0, "One more")).Code);
        // Deleting always works.
        Assert.Equal("accepted", (await a.PostAsync<SavedMealDto>($"/saved-meals/{meals[1]}/delete", new RevisionCommand(Guid.NewGuid(), 1))).Status);

        // Plus again: ordinary access is back, nothing to repair.
        Assert.Equal(HttpStatusCode.OK, await SetTierAsync(a, "plus"));
        Assert.Equal("accepted", (await PutMealAsync(a, Guid.NewGuid(), 0, "One more")).Status);
        Assert.Equal("accepted", (await CreatePlanAsync(a)).Status);
    }

    [Fact]
    public async Task Free_accounts_save_ten_meals_or_recipes_and_deleting_one_frees_a_place()
    {
        var (api, _) = Api(pg);
        await using var _api = api;
        var a = await Account.RegisterAsync(api);
        var ids = new List<Guid>();
        for (var i = 0; i < 10; i++)
        {
            var id = Guid.NewGuid();
            Assert.Equal("accepted", (await PutMealAsync(a, id, 0, $"Meal {i}")).Status);
            ids.Add(id);
        }
        var refused = await PutMealAsync(a, Guid.NewGuid(), 0, "Eleventh");
        Assert.Equal(("rejected", EntitlementService.MealLimit), (refused.Status, refused.Code));
        Assert.Equal("accepted", (await a.PostAsync<SavedMealDto>($"/saved-meals/{ids[0]}/delete", new RevisionCommand(Guid.NewGuid(), 1))).Status);
        Assert.Equal("accepted", (await PutMealAsync(a, Guid.NewGuid(), 0, "Eleventh")).Status);
        // Another account has its own ten.
        var b = await Account.RegisterAsync(api);
        Assert.Equal("accepted", (await PutMealAsync(b, Guid.NewGuid(), 0, "Mine")).Status);
    }

    [Fact]
    public void The_month_is_the_utc_calendar_month()
    {
        Assert.Equal((new DateTime(2026, 10, 1, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 11, 1, 0, 0, 0, DateTimeKind.Utc)),
            EntitlementService.Month(new DateTime(2026, 10, 31, 23, 59, 59, DateTimeKind.Utc)));
        Assert.Equal((new DateTime(2026, 12, 1, 0, 0, 0, DateTimeKind.Utc), new DateTime(2027, 1, 1, 0, 0, 0, DateTimeKind.Utc)),
            EntitlementService.Month(new DateTime(2026, 12, 1, 0, 0, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public async Task Usage_counts_by_the_server_clock_inside_the_month_and_an_owner_reset_starts_again_without_deleting()
    {
        var (api, plus) = Api(pg);
        await using var _api = api;
        var a = await Account.RegisterAsync(api);
        var b = await Account.RegisterAsync(api);
        plus.PreviewOwnerUserId = a.UserId.ToString();
        var clock = new TestTime { Now = new DateTimeOffset(2026, 11, 1, 0, 0, 0, TimeSpan.Zero) };
        await using var db = PostgresFixture.NewDb(api.ConnectionString);
        foreach (var (at, counted) in new[] { (new DateTime(2026, 10, 31, 23, 59, 59, DateTimeKind.Utc), true), (new DateTime(2026, 11, 1, 0, 0, 0, DateTimeKind.Utc), true),
                     (new DateTime(2026, 11, 1, 0, 0, 1, DateTimeKind.Utc), false) })
            db.AiUsage.Add(new AiUsage { UserId = a.UserId, Scope = "coach", RequestId = Guid.NewGuid(), AtUtc = at, Counted = counted });
        await db.SaveChangesAsync();
        var service = new EntitlementService(db, plus, new CoachOptions(), clock);

        var free = await service.AllowanceAsync(a.UserId, new(Tier.Free, "default"), default);
        Assert.Equal((1, 14), (free.Used, free.Remaining));                          // October's request and the uncounted attempt do not count
        Assert.Equal(new DateTime(2026, 12, 1, 0, 0, 0, DateTimeKind.Utc), free.ResetsAtUtc);
        Assert.Equal(0, (await service.AllowanceAsync(b.UserId, new(Tier.Free, "default"), default)).Used);   // another account's use is its own

        clock.Now = clock.Now.AddMinutes(5);
        Assert.True(await service.ResetAllowanceAsync(a.UserId, default));
        Assert.False(await service.ResetAllowanceAsync(b.UserId, default));
        Assert.Equal(0, (await service.AllowanceAsync(a.UserId, new(Tier.Free, "default"), default)).Used);
        Assert.Equal(3, await db.AiUsage.CountAsync(u => u.UserId == a.UserId));    // kept for internal tracking
    }
}

public partial class CoachTests
{
    private static Dictionary<string, string> Allow(int free) => new(On) { ["Plus:FreeMonthlyAi"] = $"{free}" };
    private static async Task<JsonElement> AllowanceOf(Account a) => (await a.Http.GetFromJsonAsync<JsonElement>("/api/v1/entitlement")).GetProperty("allowance");

    [Fact]
    public async Task One_monthly_allowance_is_shared_by_ask_daily_and_eating_out_and_says_when_it_resets()
    {
        var fake = new FakeAnthropic();
        fake.Respond = n => Task.FromResult(Message(n switch { 2 => DailyIntent(kind: "today"), 3 => Intent(), _ => Structured("Fine.", []) }));
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Settings = Allow(3), Provider = fake.Handler() };
        var a = await Account.RegisterAsync(api);
        var b = await Account.RegisterAsync(api);

        Assert.Equal(HttpStatusCode.OK, (await Post(a, Ask())).Status);
        Assert.Equal(HttpStatusCode.OK, (await PostDaily(a, Daily("Help me with today"))).Status);
        Assert.Equal(HttpStatusCode.OK, (await PostInterpret(a, Interpret())).Status);
        Assert.Equal((3, 0), ((await AllowanceOf(a)).GetProperty("used").GetInt32(), (await AllowanceOf(a)).GetProperty("remaining").GetInt32()));

        foreach (var (status, body) in new[] { await Post(a, Ask()), await PostDaily(a, Daily("Help me with today")), await PostInterpret(a, Interpret()) })
        {
            Assert.Equal((HttpStatusCode.TooManyRequests, "COACH_LIMIT", "monthly"), (status, Code(body), body.GetProperty("reason").GetString()));
            Assert.Equal(0, body.GetProperty("allowance").GetProperty("remaining").GetInt32());
            Assert.Equal(1, body.GetProperty("allowance").GetProperty("resetsAtUtc").GetDateTime().Day);
        }
        Assert.Equal(3, fake.Calls.Count);                                                   // refused before the provider

        // Free features still answer, and charge nothing.
        Assert.Equal(HttpStatusCode.OK, (await a.Http.GetAsync("/api/v1/restaurants/catalog")).StatusCode);
        await a.Http.GetAsync("/api/v1/foods/barcode/0737628064502");
        Assert.Equal(3, (await AllowanceOf(a)).GetProperty("used").GetInt32());
        // Another account has its own allowance.
        Assert.Equal(HttpStatusCode.OK, (await Post(b, Ask())).Status);
        Assert.Equal(1, (await AllowanceOf(b)).GetProperty("used").GetInt32());
    }

    [Fact]
    public async Task Failures_unusable_answers_and_unsupported_requests_are_not_charged_but_are_recorded()
    {
        var fake = new FakeAnthropic();
        Func<HttpResponseMessage> reply = () => new HttpResponseMessage(HttpStatusCode.BadRequest);   // reached, refused (never retried)
        fake.Respond = _ => Task.FromResult(reply());
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Settings = Allow(1), Provider = fake.Handler() };
        var a = await Account.RegisterAsync(api);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await Post(a, Ask())).Status);
        reply = () => Message(Structured("   ", []));                                          // reached, nothing usable
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await Post(a, Ask())).Status);
        reply = () => Message(DailyIntent(kind: "unsupported"));                               // a reply, but no help
        var (status, body) = await PostDaily(a, Daily("Teleport me to the moon"));
        Assert.Equal((HttpStatusCode.OK, "unsupported"), (status, body.GetProperty("intent").GetProperty("kind").GetString()));
        reply = () => Message(Structured("Fine.", []));
        Assert.Equal(0, (await AllowanceOf(a)).GetProperty("used").GetInt32());
        Assert.Equal(HttpStatusCode.OK, (await Post(a, Ask())).Status);                        // the one usable answer
        Assert.Equal(1, (await AllowanceOf(a)).GetProperty("used").GetInt32());
        Assert.Equal(HttpStatusCode.TooManyRequests, (await Post(a, Ask())).Status);

        await using var db = PostgresFixture.NewDb(api.ConnectionString);
        var rows = await db.AiUsage.Where(u => u.UserId == a.UserId).OrderBy(u => u.Id).Select(u => u.Counted).ToListAsync();
        Assert.Equal([false, false, false, true], rows);                                      // actual provider use, tracked internally
    }

    [Fact]
    public async Task A_retried_or_concurrent_request_is_charged_once()
    {
        var gate = new TaskCompletionSource();
        var fake = new FakeAnthropic();
        fake.Respond = async n => { if (n == 1) await gate.Task; return Message(Structured("Fine.", [])); };
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Settings = Allow(5), Provider = fake.Handler() };
        var a = await Account.RegisterAsync(api);

        var request = Ask();
        var first = Post(a, request);
        await fake.Arrived.Task;
        Assert.Equal(HttpStatusCode.TooManyRequests, (await Post(a, Ask())).Status);        // one at a time; not charged
        var same = Post(a, request);                                                        // the same requestId shares the call
        gate.SetResult();
        Assert.Equal((HttpStatusCode.OK, HttpStatusCode.OK), ((await first).Status, (await same).Status));
        Assert.Equal(HttpStatusCode.OK, (await Post(a, request)).Status);                   // a later retry: the remembered answer
        Assert.Single(fake.Calls);
        Assert.Equal(1, (await AllowanceOf(a)).GetProperty("used").GetInt32());

        // Even if an answer were recorded twice (another instance, a restart), the database keeps one charge.
        var allowance = api.Services.GetRequiredService<AiAllowance>();
        await allowance.RecordAsync(a.UserId, "coach", request.RequestId, counted: true);
        await allowance.RecordAsync(a.UserId, "coach", request.RequestId, counted: true);
        Assert.Equal(1, (await AllowanceOf(a)).GetProperty("used").GetInt32());
    }

    [Fact]
    public async Task Usage_survives_a_downgrade_and_the_owners_reset_gives_a_fresh_count()
    {
        var plus = new PlusOptions { FreeMonthlyAi = 2 };
        var fake = new FakeAnthropic();
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Settings = On, Provider = fake.Handler(), Configure = s => s.AddSingleton(plus) };
        var a = await Account.RegisterAsync(api);
        plus.PreviewOwnerUserId = a.UserId.ToString();
        Assert.Equal(HttpStatusCode.OK, (await a.Http.PutAsJsonAsync("/api/v1/preview/entitlement", new { tier = "plus" })).StatusCode);
        for (var i = 0; i < 3; i++) Assert.Equal(HttpStatusCode.OK, (await Post(a, Ask())).Status);
        Assert.Equal((3, 300), ((await AllowanceOf(a)).GetProperty("used").GetInt32(), (await AllowanceOf(a)).GetProperty("limit").GetInt32()));

        Assert.Equal(HttpStatusCode.OK, (await a.Http.PutAsJsonAsync("/api/v1/preview/entitlement", new { tier = "free" })).StatusCode);
        Assert.Equal((3, 0), ((await AllowanceOf(a)).GetProperty("used").GetInt32(), (await AllowanceOf(a)).GetProperty("remaining").GetInt32()));
        Assert.Equal("monthly", (await Post(a, Ask())).Body.GetProperty("reason").GetString());

        Assert.Equal(HttpStatusCode.OK, (await a.Http.PostAsync("/api/v1/preview/allowance/reset", null)).StatusCode);
        Assert.Equal(0, (await AllowanceOf(a)).GetProperty("used").GetInt32());
        Assert.Equal(HttpStatusCode.OK, (await Post(a, Ask())).Status);
    }
}
