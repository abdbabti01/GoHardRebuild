using System.Security.Claims;
using System.Text.Json;
using GoHard.Api.Application;
using GoHard.Api.Application.AccountEmail;
using GoHard.Api.Application.Coach;
using GoHard.Api.Application.FoodDiscovery;
using GoHard.Api.Application.Restaurants;
using GoHard.Api.Application.Weather;
using GoHard.Api.Persistence;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Endpoints;

public static class GoHardEndpoints
{
    public const int ContractVersion = 2;
    /// <summary>What this build really supports. Clients gate features on these, never on assumptions.</summary>
    public static readonly string[] Capabilities =
    [
        "auth.password", "commands.idempotent", "plans.lifecycle", "plans.baseline-drafts", "plans.manual-drafts", "plans.proposals",
        "workouts.sets", "workouts.finish", "food.nullable-nutrients", "runs.manual", "body-metrics", "account.erasure",
        "profile.nutrition-goals", "food.sources", "food.saved", "food.barcode", "plans.builder", "exercises.custom",
        "water.entries", "profile.tracking-display", "runs.activity-type", "runs.routes", WeeklyGoalService.Capability,
        ActivityService.MeasurementsCapability, ExerciseIncrementService.Capability, AccountEmailRegistration.Capability, SavedMealService.Capability,
    ];
    /// <summary>Text search exists only where a USDA key is configured, so it is declared only there.</summary>
    public const string SearchCapability = "food.search";

    public static IServiceCollection AddGoHardModules(this IServiceCollection services, IConfiguration config) => services
        .AddSingleton<BaselineCatalog>()
        .AddSingleton<IPlanAssistant, NoPlanAssistant>()
        .AddFoodDiscovery(config)
        .AddWeather(config)
        .AddCoach(config)
        .AddSingleton<RestaurantService>()
        .AddSingleton<DailyCoachService>()
        .AddScoped<PlanService>().AddScoped<WorkoutService>().AddScoped<FoodService>().AddScoped<SavedFoodService>().AddScoped<SavedMealService>().AddScoped<WaterService>()
        .AddScoped<ActivityService>().AddScoped<AccountService>().AddScoped<ProposalService>().AddScoped<CustomExerciseService>().AddScoped<WeeklyGoalService>()
        .AddScoped<ExerciseIncrementService>();

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

    private static IResult Requested(CodeRequestResult r) => r.Status switch
    {
        CodeRequestStatus.Accepted => Results.Json(new { cooldownSeconds = r.Seconds }, statusCode: 202),
        CodeRequestStatus.InvalidEmail => Results.Json(new AuthError("INVALID_EMAIL"), statusCode: 400),
        CodeRequestStatus.Cooldown => Results.Json(new { code = "EMAIL_COOLDOWN", retryAfterSeconds = r.Seconds }, statusCode: 429),
        CodeRequestStatus.AlreadyVerified => Results.Json(new AuthError("ALREADY_VERIFIED"), statusCode: 409),
        CodeRequestStatus.Busy => Results.Json(new AuthError("EMAIL_BUSY"), statusCode: 503),
        _ => Results.Json(new AuthError("EMAIL_UNAVAILABLE"), statusCode: 503),
    };

    private static IResult Checked(CodeCheckStatus s) => s switch
    {
        CodeCheckStatus.Expired => Results.Json(new AuthError("CODE_EXPIRED"), statusCode: 400),
        CodeCheckStatus.TooManyAttempts => Results.Json(new AuthError("TOO_MANY_ATTEMPTS"), statusCode: 429),
        CodeCheckStatus.Unavailable => Results.Json(new AuthError("EMAIL_UNAVAILABLE"), statusCode: 503),
        _ => Results.Json(new AuthError("INVALID_CODE"), statusCode: 400),
    };

    private static IResult Changed(string? error) => error is null ? Results.NoContent()
        : Results.Json(new AuthError(error), statusCode: error == "EMAIL_UNAVAILABLE" ? 503 : 400);

    public static void MapGoHardEndpoints(this WebApplication app)
    {
        var api = app.MapGroup("/api/v1");
        // minimumClientContract rises only for a change an older app cannot live with. Added optional fields are not one.
        // 2: required email verification (an app before it cannot show the verification step; docs/AUTHENTICATION_EMAIL.md).
        api.MapGet("/capabilities", (FoodDiscoveryService food, WeatherService weather, CoachService coach, RestaurantService restaurants, EmailOptions email) => Results.Ok(new
        {
            contractVersion = ContractVersion, minimumClientContract = app.Configuration.GetValue("Compatibility:MinimumClientContract", 2),
            capabilities = Capabilities.Concat(food.SearchConfigured ? [SearchCapability] : [])
                .Concat(weather.Enabled ? [WeatherRegistration.Capability] : [])
                .Concat(coach.Enabled ? [CoachService.Capability, DailyCoachService.Capability] : [])
                .Concat(restaurants.Catalog is not null ? [RestaurantService.CatalogCapability] : [])
                .Concat(restaurants.InterpretEnabled ? [RestaurantService.InterpretCapability] : [])
                .Concat(email.Configured ? [AccountEmailRegistration.DeliveryCapability] : []).ToArray(),
        }));

        var auth = api.MapGroup("/auth").RequireRateLimiting("auth");
        auth.MapPost("/register", async (RegisterRequest r, AuthService s, AccountEmailService email, EmailOptions sender, CancellationToken ct) =>
        {
            // A new account must verify its address before it can use the app, so without a sender none is created.
            if (!sender.Configured) return Results.Json(new AuthError("EMAIL_UNAVAILABLE"), statusCode: 503);
            var (ok, error) = await s.RegisterAsync(r, ct);
            if (ok is null) return Results.Json(new AuthError(error!), statusCode: error == "EMAIL_IN_USE" ? 409 : 400);
            await email.OfferVerificationAsync(ok.Profile.UserId, r.Language); // queued only; never fails the registration
            return Results.Ok(ok);
        });
        auth.MapPost("/login", async (LoginRequest r, AuthService s, CancellationToken ct) =>
            await s.LoginAsync(r, ct) is { } ok ? Results.Ok(ok) : Results.Json(new AuthError("INVALID_CREDENTIALS"), statusCode: 401));
        auth.MapPost("/refresh", async (RefreshRequest r, AuthService s, CancellationToken ct) =>
            await s.RefreshAsync(r.RefreshToken, ct) is { } ok ? Results.Ok(ok) : Results.Json(new AuthError("INVALID_REFRESH_TOKEN"), statusCode: 401));

        // Emailed codes and password changes (docs/AUTHENTICATION_EMAIL.md). None of these answers is a session.
        var codes = api.MapGroup("").RequireRateLimiting("auth-email");
        codes.MapPost("/auth/password-reset/request", async (CodeRequest r, AccountEmailService s, CancellationToken ct) =>
            Requested(await s.RequestResetAsync(r.Email, r.Language, ct)));
        codes.MapPost("/auth/password-reset/verify", async (CodeVerifyRequest r, AccountEmailService s, CancellationToken ct) =>
        {
            var (status, grant) = await s.VerifyResetAsync(r.Email, r.Code, ct);
            return grant is not null ? Results.Ok(grant) : Checked(status);
        });
        codes.MapPost("/auth/password-reset/complete", async (ResetCompleteRequest r, AccountEmailService s, CancellationToken ct) =>
            Changed(await s.CompleteResetAsync(r.ResetToken, r.NewPassword, r.Language, ct)));
        // Signed in, verified or not: these are how an account becomes verified or recovers.
        var signedCodes = codes.MapGroup("").RequireAuthorization(AccountAccess.IdentityPolicy);
        signedCodes.MapPost("/account/email-verification/request", async (LanguageRequest r, ClaimsPrincipal u, AccountEmailService s, CancellationToken ct) =>
            Requested(await s.RequestVerificationAsync(u.UserId(), r.Language, ct)));
        signedCodes.MapPost("/account/email-verification/confirm", async (CodeConfirmRequest r, ClaimsPrincipal u, AccountEmailService s, CancellationToken ct) =>
        {
            var (status, profile) = await s.ConfirmVerificationAsync(u.UserId(), r.Code, ct);
            return profile is not null ? Results.Ok(profile) : Checked(status);
        });
        signedCodes.MapPost("/account/password", async (PasswordChangeRequest r, ClaimsPrincipal u, AccountEmailService s, CancellationToken ct) =>
            Changed(await s.ChangePasswordAsync(u.UserId(), r.CurrentPassword, r.NewPassword, r.Language, ct)));
        // Local mail capture (Development/Testing only; refused at startup anywhere else): the newest message to an address.
        if (app.Services.GetRequiredService<EmailOptions>().Provider == EmailOptions.Capture)
            app.MapGet("/dev/mail/latest", (string to, CaptureMailbox box) => box.Latest(to) is { } m
                ? Results.Ok(new { m.Subject, m.Text, code = System.Text.RegularExpressions.Regex.Match(m.Text, @"\b\d{8}\b").Value })
                : Results.NotFound());

        // The identity routes an account waiting for verification keeps (docs/AUTHENTICATION_EMAIL.md › Required verification).
        // Everything else is `me`: the default policy, which needs an eligible account.
        var identity = api.MapGroup("").RequireAuthorization(AccountAccess.IdentityPolicy);
        var me = api.MapGroup("").RequireAuthorization();
        identity.MapPost("/auth/logout", async (RefreshRequest r, ClaimsPrincipal u, AuthService s, CancellationToken ct) =>
        { await s.LogoutAsync(u.UserId(), r.RefreshToken, ct); return Results.NoContent(); });
        identity.MapGet("/me", async (ClaimsPrincipal u, GoHardDb db, AccountAccess access, CancellationToken ct) =>
            Results.Ok(access.Profile(await db.Users.AsNoTracking().FirstAsync(x => x.Id == u.UserId(), ct))));
        me.MapPut("/me", (ProfileUpdateRequest r, ClaimsPrincipal u, CommandRunner run, AccountService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "profile.update", r, () => s.UpdateProfileAsync(u.UserId(), r, ct), ct));
        identity.MapDelete("/account", async ([FromBody] DeleteAccountRequest r, ClaimsPrincipal u, AccountService s, CancellationToken ct) =>
            await s.DeleteOwnAccountAsync(u.UserId(), r.Password, ct) ? Results.NoContent() : Results.Json(new AuthError("WRONG_PASSWORD"), statusCode: 400));

        me.MapGet("/sync/snapshot", async (ClaimsPrincipal u, GoHardDb db, AccountAccess access, PlanService plans, WorkoutService workouts, FoodService food,
            ProposalService proposals, SavedFoodService saved, CustomExerciseService custom, WaterService water, WeeklyGoalService goals, ExerciseIncrementService increments, SavedMealService savedMeals, CancellationToken ct) =>
        {
            var id = u.UserId();
            return Results.Ok(new SnapshotDto(
                access.Profile(await db.Users.AsNoTracking().FirstAsync(x => x.Id == id, ct)),
                await plans.ContextAsync(id, ct), await workouts.ListAsync(id, ct), await food.ListAsync(id, null, ct),
                (await db.Runs.AsNoTracking().Where(x => x.UserId == id).OrderBy(x => x.StartedAtUtc).ToListAsync(ct)).Select(ActivityService.ToDto).ToList(),
                (await db.BodyMetrics.AsNoTracking().Where(x => x.UserId == id).OrderBy(x => x.DayKey).ToListAsync(ct)).Select(ActivityService.ToDto).ToList(),
                await proposals.ListAsync(id, ct),
                await db.CatalogExercises.AsNoTracking().OrderBy(c => c.Name).Select(c => new CatalogExerciseDto(c.Key, c.Name, c.Category, c.Equipment, c.IsTimed)).ToListAsync(ct),
                DateTime.UtcNow, await saved.ListAsync(id, ct), await custom.ListAsync(id, ct),
                await water.ListAsync(id, null, ct), await goals.ListAsync(id, ct), await increments.ListAsync(id, ct), await savedMeals.ListAsync(id, ct)));
        });

        // Plans
        me.MapPost("/plan-drafts", (PlanDraftRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.draft", r, () => s.CreateDraftAsync(u.UserId(), r, ct), ct));
        me.MapPut("/plan-drafts/{id:guid}", (Guid id, PlanDraftUpdateRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.draft.update", new { id, r }, () => s.UpdateDraftAsync(u.UserId(), id, r, ct), ct));
        // Built plans (docs/TRAINING_PLANS.md)
        me.MapPost("/plans", (PlanCreateRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.create", r, () => s.CreateAsync(u.UserId(), r, ct), ct));
        me.MapPut("/plans/{id:guid}", (Guid id, PlanReviseRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.revise", new { id, r }, () => s.ReviseAsync(u.UserId(), id, r, ct), ct));
        me.MapPut("/plans/{id:guid}/occasions/{occasionId:guid}", (Guid id, Guid occasionId, OccasionEditRequest r, ClaimsPrincipal u, CommandRunner run, PlanService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "plan.occasion", new { id, occasionId, r }, () => s.EditOccasionAsync(u.UserId(), id, occasionId, r, ct), ct));
        me.MapPut("/custom-exercises/{id:guid}", (Guid id, CustomExercisePutRequest r, ClaimsPrincipal u, CommandRunner run, CustomExerciseService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "customexercise.put", new { id, r }, () => s.PutAsync(u.UserId(), id, r, ct), ct));
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
        // A saved meal logged as one operation: all of its entries or none (docs/FOOD_DATA.md › Saved meals and recipes).
        me.MapPost("/food-entries/batch", (FoodBatchRequest r, ClaimsPrincipal u, CommandRunner run, FoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "food.batch", r, () => s.CreateManyAsync(u.UserId(), r, ct), ct));
        me.MapPut("/food-entries/{id:guid}", (Guid id, FoodUpdateRequest r, ClaimsPrincipal u, CommandRunner run, FoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "food.update", new { id, r }, () => s.UpdateAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/food-entries/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, FoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "food.delete", new { id, r }, () => s.DeleteAsync(u.UserId(), id, r, ct), ct));

        // Water, logged explicitly in millilitres
        me.MapGet("/water-entries", async (DateOnly date, ClaimsPrincipal u, WaterService s, CancellationToken ct) => Results.Ok(await s.ListAsync(u.UserId(), date, ct)));
        me.MapPost("/water-entries", (WaterCreateRequest r, ClaimsPrincipal u, CommandRunner run, WaterService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "water.create", r, () => s.CreateAsync(u.UserId(), r, ct), ct));
        me.MapPut("/water-entries/{id:guid}", (Guid id, WaterUpdateRequest r, ClaimsPrincipal u, CommandRunner run, WaterService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "water.update", new { id, r }, () => s.UpdateAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/water-entries/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, WaterService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "water.delete", new { id, r }, () => s.DeleteAsync(u.UserId(), id, r, ct), ct));

        // Weekly activity targets, one record per effective Monday (docs/PROGRESS.md)
        me.MapPut("/weekly-goals/{weekStart}", (DateOnly weekStart, WeeklyGoalPutRequest r, ClaimsPrincipal u, CommandRunner run, WeeklyGoalService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "weeklygoal.put", new { weekStart, r }, () => s.PutAsync(u.UserId(), weekStart, r, ct), ct));

        // The load step for one exercise identity (docs/PROGRESSION.md)
        me.MapPut("/exercise-increments/{key}", (string key, ExerciseIncrementPutRequest r, ClaimsPrincipal u, CommandRunner run, ExerciseIncrementService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "exerciseincrement.put", new { key, r }, () => s.PutAsync(u.UserId(), key, r, ct), ct));

        // Reusable foods and favourites
        me.MapPut("/saved-foods/{id:guid}", (Guid id, SavedFoodPutRequest r, ClaimsPrincipal u, CommandRunner run, SavedFoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "savedfood.put", new { id, r }, () => s.PutAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/saved-foods/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, SavedFoodService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "savedfood.delete", new { id, r }, () => s.DeleteAsync(u.UserId(), id, r, ct), ct));

        // Saved meals and recipes: templates, never food eaten
        me.MapPut("/saved-meals/{id:guid}", (Guid id, SavedMealPutRequest r, ClaimsPrincipal u, CommandRunner run, SavedMealService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "savedmeal.put", new { id, r }, () => s.PutAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/saved-meals/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, SavedMealService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "savedmeal.delete", new { id, r }, () => s.DeleteAsync(u.UserId(), id, r, ct), ct));

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

        // Ask GoHard (docs/COACH.md). Reads only, never a command. The body is read here so a malformed or oversized
        // one is COACH_INVALID, and so its size is bounded before anything is parsed.
        me.MapPost("/coach/ask", async (HttpRequest req, ClaimsPrincipal u, CoachService coach, GoHardDb db, CancellationToken ct) =>
        {
            if (req.HttpContext.Features.Get<IHttpMaxRequestBodySizeFeature>() is { IsReadOnly: false } limit) limit.MaxRequestBodySize = CoachService.MaxBodyBytes;
            CoachAskRequest? r = null;
            if (req.ContentLength is null or <= CoachService.MaxBodyBytes)
                try { r = await JsonSerializer.DeserializeAsync<CoachAskRequest>(req.Body, CommandRunner.Json, ct); }
                catch (Exception ex) when (ex is JsonException or BadHttpRequestException) { }
            var outcome = await coach.AskAsync(u.UserId(), r, db, ct);
            return outcome.Status switch
            {
                CoachStatus.Ok => Results.Json(outcome.Answer, CommandRunner.Json),
                CoachStatus.Invalid => Results.Json(new { code = "COACH_INVALID" }, statusCode: 400),
                CoachStatus.Limit => Results.Json(new { code = "COACH_LIMIT" }, statusCode: 429),
                // The provider's rate limit or overload: not the person's own limit, so not COACH_LIMIT.
                CoachStatus.Busy => Results.Json(new { code = "COACH_BUSY", retryAfterSeconds = outcome.RetryAfterSeconds }, statusCode: 503),
                _ => Results.Json(new { code = "COACH_UNAVAILABLE" }, statusCode: 503),
            };
        });

        // Help with today and food (docs/COACH.md › Help with today): words → a checked intent naming this account's own
        // saved items. Reads only, never a command; the same per-account limits and daily allowance as Ask GoHard.
        me.MapPost("/coach/daily", async (HttpRequest req, ClaimsPrincipal u, DailyCoachService s, GoHardDb db, CancellationToken ct) =>
        {
            if (req.HttpContext.Features.Get<IHttpMaxRequestBodySizeFeature>() is { IsReadOnly: false } limit) limit.MaxRequestBodySize = DailyCoachService.MaxBodyBytes;
            DailyCoachRequest? r = null;
            if (req.ContentLength is null or <= DailyCoachService.MaxBodyBytes)
                try { r = await JsonSerializer.DeserializeAsync<DailyCoachRequest>(req.Body, CommandRunner.Json, ct); }
                catch (Exception ex) when (ex is JsonException or BadHttpRequestException) { }
            var outcome = await s.InterpretAsync(u.UserId(), r, db, ct);
            return outcome.Status switch
            {
                DailyStatus.Ok => Results.Json(outcome.Answer, CommandRunner.Json),
                DailyStatus.Invalid => Results.Json(new { code = "COACH_INVALID" }, statusCode: 400),
                DailyStatus.Limit => Results.Json(new { code = "COACH_LIMIT" }, statusCode: 429),
                DailyStatus.Busy => Results.Json(new { code = "COACH_BUSY", retryAfterSeconds = outcome.RetryAfterSeconds }, statusCode: 503),
                _ => Results.Json(new { code = "COACH_UNAVAILABLE" }, statusCode: 503),
            };
        });

        // Eating out (docs/EATING_OUT.md). The reviewed catalog, read only; "have" = the version the phone holds.
        me.MapGet("/restaurants/catalog", (string? have, RestaurantService s) => s.Catalog is not { } c
            ? Results.Json(new { code = "RESTAURANTS_UNAVAILABLE" }, statusCode: 503)
            : have == c.Version ? Results.Ok(new { upToDate = true, version = c.Version }) : Results.Text(c.Json, "application/json"));
        // Words → checked preferences. Reads only, never a command; the same per-account limits as Ask GoHard.
        me.MapPost("/restaurants/interpret", async (HttpRequest req, ClaimsPrincipal u, RestaurantService s, CancellationToken ct) =>
        {
            if (req.HttpContext.Features.Get<IHttpMaxRequestBodySizeFeature>() is { IsReadOnly: false } limit) limit.MaxRequestBodySize = RestaurantService.MaxBodyBytes;
            RestaurantInterpretRequest? r = null;
            if (req.ContentLength is null or <= RestaurantService.MaxBodyBytes)
                try { r = await JsonSerializer.DeserializeAsync<RestaurantInterpretRequest>(req.Body, CommandRunner.Json, ct); }
                catch (Exception ex) when (ex is JsonException or BadHttpRequestException) { }
            var outcome = await s.InterpretAsync(u.UserId(), r, ct);
            return outcome.Status switch
            {
                RestaurantStatus.Ok => Results.Json(outcome.Answer, CommandRunner.Json),
                RestaurantStatus.Invalid => Results.Json(new { code = "RESTAURANT_INVALID" }, statusCode: 400),
                RestaurantStatus.Mismatch => Results.Json(new { code = "RESTAURANT_CATALOG_MISMATCH", catalogVersion = s.Catalog?.Version }, statusCode: 409),
                RestaurantStatus.Limit => Results.Json(new { code = "COACH_LIMIT" }, statusCode: 429),
                RestaurantStatus.Busy => Results.Json(new { code = "COACH_BUSY", retryAfterSeconds = outcome.RetryAfterSeconds }, statusCode: 503),
                _ => Results.Json(new { code = "COACH_UNAVAILABLE" }, statusCode: 503),
            };
        });

        // Supporting activities
        me.MapPost("/runs", (RunStartRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "run.start", r, () => s.StartRunAsync(u.UserId(), r, ct), ct));
        me.MapPost("/runs/{id:guid}/finish", (Guid id, RunFinishRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "run.finish", new { id, r }, () => s.FinishRunAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/runs/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "run.delete", new { id, r }, () => s.DeleteRunAsync(u.UserId(), id, r, ct), ct));
        me.MapPut("/runs/{id:guid}", (Guid id, RunUpdateRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "run.update", new { id, r }, () => s.UpdateRunAsync(u.UserId(), id, r, ct), ct));
        me.MapPut("/runs/{id:guid}/route/chunks/{index:int}", (Guid id, int index, RouteChunkRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "route.chunk", new { id, index, r }, () => s.PutRouteChunkAsync(u.UserId(), id, index, r, ct), ct));
        me.MapPost("/runs/{id:guid}/route/complete", (Guid id, RouteCompleteRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "route.complete", new { id, r }, () => s.CompleteRouteAsync(u.UserId(), id, r, ct), ct));
        me.MapGet("/runs/{id:guid}/route", async (Guid id, int? fromIndex, int? limit, ClaimsPrincipal u, ActivityService s, CancellationToken ct) =>
            await s.RoutePageAsync(u.UserId(), id, fromIndex ?? 0, limit ?? ActivityService.RoutePageLimit, ct) is { } page
                ? Results.Json(page, CommandRunner.Json) : Results.NotFound());
        me.MapPost("/body-metrics", (BodyMetricRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "metric.create", r, () => s.AddMetricAsync(u.UserId(), r, ct), ct));
        me.MapPut("/body-metrics/{id:guid}", (Guid id, BodyMetricUpdateRequest r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "metric.update", new { id, r }, () => s.UpdateMetricAsync(u.UserId(), id, r, ct), ct));
        me.MapPost("/body-metrics/{id:guid}/delete", (Guid id, RevisionCommand r, ClaimsPrincipal u, CommandRunner run, ActivityService s, CancellationToken ct) =>
            run.RunAsync(u.UserId(), r.OperationId, "metric.delete", new { id, r }, () => s.DeleteMetricAsync(u.UserId(), id, r, ct), ct));
    }
}
