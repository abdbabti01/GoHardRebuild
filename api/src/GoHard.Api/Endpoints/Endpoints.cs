using System.Security.Claims;
using GoHard.Api.Application;
using GoHard.Api.Application.FoodDiscovery;
using GoHard.Api.Application.Weather;
using GoHard.Api.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Endpoints;

public static class GoHardEndpoints
{
    public const int ContractVersion = 1;
    /// <summary>What this build really supports. Clients gate features on these, never on assumptions.</summary>
    public static readonly string[] Capabilities =
    [
        "auth.password", "commands.idempotent", "plans.lifecycle", "plans.baseline-drafts", "plans.manual-drafts", "plans.proposals",
        "workouts.sets", "workouts.finish", "food.nullable-nutrients", "runs.manual", "body-metrics", "account.erasure",
        "profile.nutrition-goals", "food.sources", "food.saved", "food.barcode",
    ];
    /// <summary>Text search exists only where a USDA key is configured, so it is declared only there.</summary>
    public const string SearchCapability = "food.search";

    public static IServiceCollection AddGoHardModules(this IServiceCollection services, IConfiguration config) => services
        .AddSingleton<BaselineCatalog>()
        .AddSingleton<IPlanAssistant, NoPlanAssistant>()
        .AddFoodDiscovery(config)
        .AddWeather(config)
        .AddScoped<PlanService>().AddScoped<WorkoutService>().AddScoped<FoodService>().AddScoped<SavedFoodService>()
        .AddScoped<ActivityService>().AddScoped<AccountService>().AddScoped<ProposalService>();

    /// <summary>Ownership always comes from the validated token, never from a client-supplied user ID.</summary>
    private static Guid UserId(this ClaimsPrincipal p) => Guid.Parse(p.FindFirstValue("sub")!);

    /// <summary>Provider trouble is reported as what it is, so the app can say something true and offer manual entry.</summary>
    private static IResult Lookup<T>(Lookup<T> lookup, Func<T, object> body) => lookup.Status switch
    {
        LookupStatus.Ok => Results.Json(body(lookup.Value!), CommandRunner.Json),
        LookupStatus.NotFound => Results.Json(new { code = "NOT_FOUND" }, statusCode: 404),
        LookupStatus.Invalid => Results.Json(new { code = "INVALID_QUERY" }, statusCode: 422),
        LookupStatus.RateLimited => Results.Json(new { code = "PROVIDER_RATE_LIMITED" }, statusCode: 429),
        LookupStatus.NotConfigured => Results.Json(new { code = "PROVIDER_NOT_CONFIGURED" }, statusCode: 503),
        _ => Results.Json(new { code = "PROVIDER_UNAVAILABLE" }, statusCode: 503),
    };

    public static void MapGoHardEndpoints(this WebApplication app)
    {
        var api = app.MapGroup("/api/v1");
        // minimumClientContract rises only for a change an older app cannot live with. Added optional fields are not one.
        api.MapGet("/capabilities", (FoodDiscoveryService food, WeatherService weather) => Results.Ok(new
        {
            contractVersion = ContractVersion, minimumClientContract = app.Configuration.GetValue("Compatibility:MinimumClientContract", 1),
            capabilities = Capabilities.Concat(food.SearchConfigured ? [SearchCapability] : [])
                .Concat(weather.Enabled ? [WeatherRegistration.Capability] : []).ToArray(),
        }));

        var auth = api.MapGroup("/auth").RequireRateLimiting("auth");
        auth.MapPost("/register", async (RegisterRequest r, AuthService s, CancellationToken ct) =>
        {
            var (ok, error) = await s.RegisterAsync(r, ct);
            return ok is not null ? Results.Ok(ok) : Results.Json(new AuthError(error!), statusCode: error == "EMAIL_IN_USE" ? 409 : 400);
        });
        auth.MapPost("/login", async (LoginRequest r, AuthService s, CancellationToken ct) =>
            await s.LoginAsync(r, ct) is { } ok ? Results.Ok(ok) : Results.Json(new AuthError("INVALID_CREDENTIALS"), statusCode: 401));
        auth.MapPost("/refresh", async (RefreshRequest r, AuthService s, CancellationToken ct) =>
            await s.RefreshAsync(r.RefreshToken, ct) is { } ok ? Results.Ok(ok) : Results.Json(new AuthError("INVALID_REFRESH_TOKEN"), statusCode: 401));

        var me = api.MapGroup("").RequireAuthorization();
        me.MapPost("/auth/logout", async (RefreshRequest r, ClaimsPrincipal u, AuthService s, CancellationToken ct) =>
        { await s.LogoutAsync(u.UserId(), r.RefreshToken, ct); return Results.NoContent(); });
        me.MapGet("/me", async (ClaimsPrincipal u, GoHardDb db, CancellationToken ct) =>
            Results.Ok(AuthService.ToProfile(await db.Users.AsNoTracking().FirstAsync(x => x.Id == u.UserId(), ct))));
        me.MapPut("/me", (ProfileUpdateRequest r, ClaimsPrincipal u, CommandRunner run, AccountService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "profile.update", r, () => s.UpdateProfileAsync(u.UserId(), r, ct), ct));
        me.MapDelete("/account", async ([FromBody] DeleteAccountRequest r, ClaimsPrincipal u, AccountService s, CancellationToken ct) =>
            await s.DeleteOwnAccountAsync(u.UserId(), r.Password, ct) ? Results.NoContent() : Results.Json(new AuthError("WRONG_PASSWORD"), statusCode: 400));

        me.MapGet("/sync/snapshot", async (ClaimsPrincipal u, GoHardDb db, PlanService plans, WorkoutService workouts, FoodService food,
            ProposalService proposals, SavedFoodService saved, CancellationToken ct) =>
        {
            var id = u.UserId();
            return Results.Ok(new SnapshotDto(
                AuthService.ToProfile(await db.Users.AsNoTracking().FirstAsync(x => x.Id == id, ct)),
                await plans.ContextAsync(id, ct), await workouts.ListAsync(id, ct), await food.ListAsync(id, null, ct),
                (await db.Runs.AsNoTracking().Where(x => x.UserId == id).OrderBy(x => x.StartedAtUtc).ToListAsync(ct)).Select(ActivityService.ToDto).ToList(),
                (await db.BodyMetrics.AsNoTracking().Where(x => x.UserId == id).OrderBy(x => x.DayKey).ToListAsync(ct)).Select(ActivityService.ToDto).ToList(),
                await proposals.ListAsync(id, ct),
                await db.CatalogExercises.AsNoTracking().OrderBy(c => c.Name).Select(c => new CatalogExerciseDto(c.Key, c.Name, c.Category, c.Equipment, c.IsTimed)).ToListAsync(ct),
                DateTime.UtcNow, await saved.ListAsync(id, ct)));
        });

        // Plans
        me.MapPost("/plan-drafts", (PlanDraftRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.draft", r, () => s.CreateDraftAsync(u.UserId(), r, ct), ct));
        me.MapPut("/plan-drafts/{id:guid}", (Guid id, PlanDraftUpdateRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.draft.update", new { id, r }, () => s.UpdateDraftAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/plans/{id:guid}/activate", (Guid id, ActivateRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.activate", new { id, r }, () => s.ActivateAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/plans/{id:guid}/pause", (Guid id, PauseRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.pause", new { id, r }, () => s.PauseAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/plans/{id:guid}/resume", (Guid id, ResumeRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.resume", new { id, r }, () => s.ResumeAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/plans/{id:guid}/schedule-changes", (Guid id, ScheduleChangeRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.schedule", new { id, r }, () => s.ChangeScheduleAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/plans/{id:guid}/close", (Guid id, CloseRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.close", new { id, r }, () => s.CloseAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/plans/{id:guid}/archive", (Guid id, ArchiveRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.archive", new { id, r }, () => s.ArchiveAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/plans/{id:guid}/continue", (Guid id, ContinueRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.continue", new { id, r }, () => s.ContinueAsync(u.UserId(), id, r, ct), ct));

        // Proposals
        me.MapPost("/proposals", (ProposalRequest r, ClaimsPrincipal u, CommandRunner run, ProposalService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "proposal.create", r, () => s.ProposeAsync(u.UserId(), r, ct), ct));
        me.MapPost("/proposals/{id:guid}/accept", (Guid id, ProposalDecision r, ClaimsPrincipal u, CommandRunner run, ProposalService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "proposal.accept", new { id, r }, () => s.AcceptAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/proposals/{id:guid}/decline", (Guid id, ProposalDecision r, ClaimsPrincipal u, CommandRunner run, ProposalService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "proposal.decline", new { id, r }, () => s.DeclineAsync(u.UserId(), id, r, ct), ct));

        // Workouts
        me.MapPost("/workouts", (StartWorkoutRequest r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "workout.start", r, () => s.StartAsync(u.UserId(), r, ct), ct));
        me.MapPost("/workouts/{id:guid}/exercises", (Guid id, AddExerciseRequest r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "exercise.add", new { id, r }, () => s.AddExerciseAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/exercises/{id:guid}/remove", (Guid id, OperationOnly r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "exercise.remove", new { id, r }, () => s.RemoveExerciseAsync(u.UserId(), id, ct), ct));
        me.MapPost("/exercises/{id:guid}/sets", (Guid id, SetCreateRequest r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "set.create", new { id, r }, () => s.CreateSetAsync(u.UserId(), id, r, ct), ct));
        me.MapPut("/sets/{id:guid}", (Guid id, SetUpdateRequest r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "set.update", new { id, r }, () => s.UpdateSetAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/sets/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "set.delete", new { id, r }, () => s.DeleteSetAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/workouts/{id:guid}/finish", (Guid id, FinishRequest r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "workout.finish", new { id, r }, () => s.FinishAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/workouts/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, WorkoutService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "workout.delete", new { id, r }, () => s.DeleteAsync(u.UserId(), id, r, ct), ct));

        // Food journal
        me.MapGet("/food-entries", async (DateOnly date, ClaimsPrincipal u, FoodService s, CancellationToken ct) => Results.Ok(await s.ListAsync(u.UserId(), date, ct)));
        me.MapPost("/food-entries", (FoodCreateRequest r, ClaimsPrincipal u, CommandRunner run, FoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "food.create", r, () => s.CreateAsync(u.UserId(), r, ct), ct));
        me.MapPut("/food-entries/{id:guid}", (Guid id, FoodUpdateRequest r, ClaimsPrincipal u, CommandRunner run, FoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "food.update", new { id, r }, () => s.UpdateAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/food-entries/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, FoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "food.delete", new { id, r }, () => s.DeleteAsync(u.UserId(), id, r, ct), ct));

        // Reusable foods and favourites
        me.MapPut("/saved-foods/{id:guid}", (Guid id, SavedFoodPutRequest r, ClaimsPrincipal u, CommandRunner run, SavedFoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "savedfood.put", new { id, r }, () => s.PutAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/saved-foods/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, SavedFoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "savedfood.delete", new { id, r }, () => s.DeleteAsync(u.UserId(), id, r, ct), ct));

        // Food data from outside providers. Reading only: nothing here records anything as eaten.
        var foods = me.MapGroup("/foods").RequireRateLimiting("food-data");
        foods.MapGet("/search", async (string? q, FoodDiscoveryService s, CancellationToken ct) => Lookup(await s.SearchAsync(q, ct), r => new { results = r.Results }));
        foods.MapGet("/barcode/{code}", async (string code, FoodDiscoveryService s, CancellationToken ct) => Lookup(await s.BarcodeAsync(code, ct), item => new { item }));

        // Optional weather for the Today background. Coarse places only; a failure here touches nothing else.
        var weather = me.MapGroup("/weather").RequireRateLimiting("food-data");
        // provider=met.no asks the fallback directly: how a deployment proves MET Norway answers from its own network
        // while Open-Meteo is fine. Same rounding, cache (its own key), budget and Expires rules. The app never sends it.
        weather.MapGet("/current", async (double? lat, double? lon, string? provider, WeatherService s, CancellationToken ct) =>
            Lookup(await s.CurrentAsync(lat, lon, ct, viaFallback: provider == MetNorwayProvider.Source), w => w));
        weather.MapGet("/places", async (string? q, WeatherService s, CancellationToken ct) => Lookup(await s.PlacesAsync(q, ct), r => new { results = r }));

        // Supporting activities
        me.MapPost("/runs", (RunStartRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "run.start", r, () => s.StartRunAsync(u.UserId(), r, ct), ct));
        me.MapPost("/runs/{id:guid}/finish", (Guid id, RunFinishRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "run.finish", new { id, r }, () => s.FinishRunAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/runs/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "run.delete", new { id, r }, () => s.DeleteRunAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/body-metrics", (BodyMetricRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "metric.create", r, () => s.AddMetricAsync(u.UserId(), r, ct), ct));
        me.MapPost("/body-metrics/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "metric.delete", new { id, r }, () => s.DeleteMetricAsync(u.UserId(), id, r, ct), ct));
    }
}
