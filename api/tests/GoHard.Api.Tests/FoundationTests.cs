using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using GoHard.Api.Application;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;

namespace GoHard.Api.Tests;

/// <summary>B0 + R6: explicit migrations, read-only readiness, authentication and account lifecycle on real PostgreSQL.</summary>
[Collection("api")]
public class FoundationTests(PostgresFixture pg)
{
    [Fact]
    public async Task Unmigrated_database_is_reported_and_never_repaired_by_startup()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: false);
        await using var api = new ApiFactory(cs);
        var http = api.CreateClient();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await http.GetAsync("/health/ready")).StatusCode);
        var blocked = await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest("a@example.test", "password1"));
        Assert.Equal(HttpStatusCode.ServiceUnavailable, blocked.StatusCode);

        await using var db = PostgresFixture.NewDb(cs);
        var state = await SchemaReadinessService.CheckAsync(db, default);
        Assert.Equal(SchemaReadinessKind.PendingMigration, state.Kind);
        // Booting and serving requests created nothing: no history table, no application tables.
        var tables = await db.Database.SqlQuery<int>($"SELECT count(*)::int AS \"Value\" FROM information_schema.tables WHERE table_schema='public'").SingleAsync();
        Assert.Equal(0, tables);

        await db.Database.MigrateAsync(); // the explicit step
        Assert.Equal(HttpStatusCode.OK, (await http.GetAsync("/health/ready")).StatusCode);
    }

    [Fact]
    public async Task Unknown_history_is_reported_without_repair()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        await using var db = PostgresFixture.NewDb(cs);
        await db.Database.ExecuteSqlAsync($"INSERT INTO \"__EFMigrationsHistory\" VALUES ('20990101000000_FromAnotherBuild', '10.0.0')");
        var before = await db.Database.SqlQuery<string>($"SELECT \"MigrationId\" AS \"Value\" FROM \"__EFMigrationsHistory\" ORDER BY 1").ToListAsync();

        await using var api = new ApiFactory(cs);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await api.CreateClient().GetAsync("/health/ready")).StatusCode);
        var state = await SchemaReadinessService.CheckAsync(db, default);

        Assert.Equal(SchemaReadinessKind.UnknownHistory, state.Kind);
        Assert.Equal(before, await db.Database.SqlQuery<string>($"SELECT \"MigrationId\" AS \"Value\" FROM \"__EFMigrationsHistory\" ORDER BY 1").ToListAsync());
    }

    [Fact]
    public async Task Missing_table_is_schema_drift_and_unreachable_database_is_not_ready()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        await using var db = PostgresFixture.NewDb(cs);
        await db.Database.ExecuteSqlAsync($"DROP TABLE \"FoodEntries\"");
        Assert.Equal(SchemaReadinessKind.SchemaDrift, (await SchemaReadinessService.CheckAsync(db, default)).Kind);

        await using var gone = PostgresFixture.NewDb("Host=127.0.0.1;Port=1;Database=x;Username=x;Password=x;Timeout=2");
        var unreachable = await SchemaReadinessService.CheckAsync(gone, default);
        Assert.Equal(SchemaReadinessKind.Unreachable, unreachable.Kind);
        Assert.DoesNotContain("Password", unreachable.Detail);
    }

    [Fact]
    public async Task Upgrade_from_initial_schema_preserves_existing_records_and_operations()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: false);
        await using var db = PostgresFixture.NewDb(cs);
        await db.GetService<IMigrator>().MigrateAsync("Initial");
        Assert.Equal(SchemaReadinessKind.PendingMigration, (await SchemaReadinessService.CheckAsync(db, default)).Kind);

        var user = new User { Id = Guid.NewGuid(), Email = "old@example.test", PasswordHash = "x", DisplayName = "Old", SecurityStamp = "s", CreatedAtUtc = DateTime.UtcNow };
        var workout = new Workout { Id = Guid.NewGuid(), UserId = user.Id, Title = "Before upgrade", DayKey = Account.Friday, StartedAtUtc = DateTime.UtcNow };
        var food = new FoodEntry { Id = Guid.NewGuid(), UserId = user.Id, DayKey = Account.Friday, Meal = "Lunch", Name = "Soup", AmountDescription = "1 bowl", Calories = 0, CaloriesSource = "entered", CreatedAtUtc = DateTime.UtcNow };
        var op = new Operation { UserId = user.Id, OperationId = Guid.NewGuid(), Kind = "food.create", RequestHash = "h", HttpStatus = 200, ResponseJson = "{}", CreatedAtUtc = DateTime.UtcNow };
        // Written as the first schema stored them: the current model has columns that schema does not know yet.
        await db.Database.ExecuteSqlAsync($"""INSERT INTO "Users" ("Id","Email","PasswordHash","DisplayName","Appearance","LoadUnit","RemindersEnabled","Revision","SecurityStamp","CreatedAtUtc") VALUES ({user.Id},{user.Email},'x','Old','dark','kg',false,1,'s',now())""");
        await db.Database.ExecuteSqlAsync($"""INSERT INTO "Workouts" ("Id","UserId","Kind","Title","DayKey","StartedAtUtc","PerformedSets","PerformedExercises","QualifiedOccasion","Revision") VALUES ({workout.Id},{user.Id},'manual',{workout.Title},'2026-10-09',now(),0,0,false,1)""");
        await db.Database.ExecuteSqlAsync($"""INSERT INTO "FoodEntries" ("Id","UserId","DayKey","Meal","Name","AmountDescription","Calories","CaloriesSource","ProteinSource","CarbsSource","FatSource","Revision","CreatedAtUtc") VALUES ({food.Id},{user.Id},'2026-10-09','Lunch','Soup','1 bowl',0,'entered','unknown','unknown','unknown',1,now())""");
        await db.Database.ExecuteSqlAsync($"""INSERT INTO "Operations" ("UserId","OperationId","Kind","RequestHash","HttpStatus","ResponseJson","CreatedAtUtc") VALUES ({user.Id},{op.OperationId},'food.create','h',200,'',now())""");

        await db.Database.MigrateAsync();

        Assert.True((await SchemaReadinessService.CheckAsync(db, default)).IsReady);
        db.ChangeTracker.Clear();
        Assert.Equal("Before upgrade", (await db.Workouts.SingleAsync(w => w.Id == workout.Id)).Title);
        var kept = await db.FoodEntries.SingleAsync(f => f.Id == food.Id);
        Assert.Equal(0m, kept.Calories);   // entered zero survives
        Assert.Null(kept.ProteinG);        // unknown survives as unknown
        Assert.Equal(op.OperationId, (await db.Operations.SingleAsync(o => o.UserId == user.Id)).OperationId);
        Assert.Empty(await db.Runs.ToListAsync());
    }

    [Fact]
    public async Task Register_login_refresh_and_owner_scoped_profile()
    {
        var a = await Account.RegisterAsync(pg.Api, "Alex Sample");
        var anonymous = pg.Api.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/v1/me")).StatusCode);

        var me = await a.Http.GetFromJsonAsync<ProfileDto>("/api/v1/me", Account.Json);
        Assert.Equal(("Alex Sample", "dark", "kg"), (me!.DisplayName, me.Appearance, me.LoadUnit));

        var wrong = await anonymous.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(me.Email, "not the password"));
        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);
        var login = await anonymous.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(me.Email.ToUpperInvariant(), a.Password));
        var tokens = (await login.Content.ReadFromJsonAsync<AuthResponse>(Account.Json))!;

        // Refresh rotates: the old refresh token stops working.
        var refreshed = await anonymous.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(tokens.RefreshToken));
        Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
        var replay = await anonymous.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(tokens.RefreshToken));
        Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);

        var duplicate = await anonymous.PostAsJsonAsync("/api/v1/auth/register", new RegisterRequest(me.Email, "another password", "Copy"));
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
        var weak = await anonymous.PostAsJsonAsync("/api/v1/auth/register", new RegisterRequest("weak@example.test", "short", "Weak"));
        Assert.Equal(HttpStatusCode.BadRequest, weak.StatusCode);
    }

    [Fact]
    public async Task Profile_update_is_revision_checked_and_idempotent()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var request = new ProfileUpdateRequest(Guid.NewGuid(), 1, "New Name", "light", "lb", true, "07:30");
        var first = await a.PutAsync<ProfileDto>("/me", request);
        var retry = await a.PutAsync<ProfileDto>("/me", request);
        Assert.Equal(("accepted", 2, "light", "lb"), (first.Status, first.Ack!.Revision, first.Data.Appearance, first.Data.LoadUnit));
        Assert.Equal(first.Raw, retry.Raw);

        var stale = await a.PutAsync<ProfileDto>("/me", request with { OperationId = Guid.NewGuid(), DisplayName = "Stale" });
        Assert.Equal(("conflict", Ack.RevisionConflict, "New Name"), (stale.Status, stale.Code, stale.Data.DisplayName));
        var changed = await a.PutAsync<ProfileDto>("/me", request with { DisplayName = "Different payload" });
        Assert.Equal(Ack.PayloadMismatch, changed.Code);
    }

    [Fact]
    public async Task WrongPasswordKeepsAccountAndPendingData_and_deleted_account_tokens_cannot_write()
    {
        var owner = await Account.RegisterAsync(pg.Api);
        var other = await Account.RegisterAsync(pg.Api);
        var workout = await owner.StartManualAsync();
        await owner.AddSetAsync(workout.Exercises[0].Id);
        await other.StartManualAsync();

        async Task<HttpResponseMessage> Delete(Account who, string password) => await who.Http.SendAsync(
            new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(password)) });

        Assert.Equal(HttpStatusCode.BadRequest, (await Delete(owner, "wrong password")).StatusCode);
        Assert.Single((await owner.SnapshotAsync()).Workouts);                      // nothing was erased
        Assert.Equal(HttpStatusCode.Unauthorized, (await pg.Api.CreateClient().SendAsync(
            new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new DeleteAccountRequest(owner.Password)) })).StatusCode);

        Assert.Equal(HttpStatusCode.NoContent, (await Delete(owner, owner.Password)).StatusCode);

        // The still-unexpired access token is rejected because its account no longer exists.
        Assert.Equal(HttpStatusCode.Unauthorized, (await owner.Http.GetAsync("/api/v1/me")).StatusCode);
        var write = await owner.Http.PostAsJsonAsync("/api/v1/workouts", new { });
        Assert.Equal(HttpStatusCode.Unauthorized, write.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await pg.Api.CreateClient().PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(owner.Auth.RefreshToken))).StatusCode);

        await using var db = pg.SharedDb();
        Assert.False(await db.Users.AnyAsync(u => u.Id == owner.UserId));
        Assert.False(await db.Workouts.AnyAsync(w => w.UserId == owner.UserId));
        Assert.False(await db.WorkoutSets.AnyAsync(s => s.UserId == owner.UserId));
        Assert.False(await db.Operations.AnyAsync(o => o.UserId == owner.UserId));
        Assert.Single((await other.SnapshotAsync()).Workouts);                      // the other account is untouched
    }

    [Fact]
    public async Task Logout_revokes_the_session_but_keeps_every_owned_record()
    {
        var a = await Account.RegisterAsync(pg.Api);
        await a.StartManualAsync();
        var logout = await a.Http.PostAsJsonAsync("/api/v1/auth/logout", new RefreshRequest(a.Auth.RefreshToken));
        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await pg.Api.CreateClient().PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(a.Auth.RefreshToken))).StatusCode);

        var http = pg.Api.CreateClient();
        var again = await (await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(a.Auth.Profile.Email, a.Password))).Content.ReadFromJsonAsync<AuthResponse>(Account.Json);
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", again!.AccessToken);
        Assert.Single((await http.GetFromJsonAsync<SnapshotDto>("/api/v1/sync/snapshot", Account.Json))!.Workouts);
    }

    [Fact]
    public async Task Capabilities_are_public_and_versioned()
    {
        var body = await pg.Api.CreateClient().GetStringAsync("/api/v1/capabilities");
        Assert.Contains("\"contractVersion\":1", body);
        Assert.Contains("food.nullable-nutrients", body);
    }
}

[Collection("api")]
public class IsolationGuardTests(PostgresFixture pg)
{
    /// <summary>The suite must never reach a developer database through appsettings.Local.json.</summary>
    [Fact]
    public void Api_under_test_uses_only_the_disposable_database()
    {
        using var scope = pg.Api.Services.CreateScope();
        var actual = scope.ServiceProvider.GetRequiredService<GoHardDb>().Database.GetConnectionString()!;
        using var expected = pg.SharedDb();
        Assert.Equal(new Npgsql.NpgsqlConnectionStringBuilder(expected.Database.GetConnectionString()).Database,
            new Npgsql.NpgsqlConnectionStringBuilder(actual).Database);
        Assert.StartsWith("t_", new Npgsql.NpgsqlConnectionStringBuilder(actual).Database);
    }
}
