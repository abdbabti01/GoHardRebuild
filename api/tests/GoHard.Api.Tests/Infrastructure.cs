using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using GoHard.Api.Application;
using GoHard.Api.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Testcontainers.PostgreSql;

namespace GoHard.Api.Tests;

/// <summary>
/// One real, disposable PostgreSQL server for the whole run. If Docker is unavailable this throws and every
/// database test FAILS; nothing here can pass by skipping. SQLite/InMemory are deliberately not used.
/// </summary>
public sealed class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:17.6").Build();
    private string? _shared;
    private readonly SemaphoreSlim _gate = new(1, 1);
    public ApiFactory Api { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        _shared = await CreateDatabaseAsync(migrate: true);
        Api = new ApiFactory(_shared);
    }

    public async Task DisposeAsync()
    {
        await Api.DisposeAsync();
        await _container.DisposeAsync();
    }

    public async Task<string> CreateDatabaseAsync(bool migrate)
    {
        var name = "t_" + Guid.NewGuid().ToString("N");
        await _gate.WaitAsync();
        try
        {
            await using var admin = new NpgsqlConnection(_container.GetConnectionString());
            await admin.OpenAsync();
            await using var cmd = new NpgsqlCommand($"CREATE DATABASE \"{name}\"", admin);
            await cmd.ExecuteNonQueryAsync();
        }
        finally { _gate.Release(); }
        var cs = new NpgsqlConnectionStringBuilder(_container.GetConnectionString()) { Database = name }.ConnectionString;
        if (migrate) { await using var db = NewDb(cs); await db.Database.MigrateAsync(); await CatalogSeeder.SeedAsync(db, default); }
        return cs;
    }

    public static GoHardDb NewDb(string connectionString) =>
        new(new DbContextOptionsBuilder<GoHardDb>().UseNpgsql(connectionString).Options);

    public GoHardDb SharedDb() => NewDb(_shared!);
}

[CollectionDefinition("api")]
public sealed class ApiCollection : ICollectionFixture<PostgresFixture>;

public sealed class ApiFactory(string connectionString) : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        if (Environment is not null) builder.UseEnvironment(Environment);
        builder.UseSetting("ConnectionStrings:Default", connectionString);
        builder.UseSetting("Auth:SigningKey", "test-only-signing-key-0123456789-0123456789-abcdef");
        builder.UseSetting("Auth:RateLimitPerMinute", "1000000");
        foreach (var (key, value) in Settings ?? []) builder.UseSetting(key, value);
        // Outside providers are always replaced: by default with a recorded product, so no test run touches the network.
        builder.ConfigureServices(s => s.ConfigureAll<Microsoft.Extensions.Http.HttpClientFactoryOptions>(o =>
            o.HttpMessageHandlerBuilderActions.Add(b => b.PrimaryHandler = Provider ?? new StubProvider(_ => Task.FromResult(StubProvider.Json(StubProvider.Recorded("off_product_100g.json")))))));
        builder.ConfigureServices(s => Configure?.Invoke(s));
    }
    public Action<IServiceCollection>? Configure { get; init; }
    public Dictionary<string, string>? Settings { get; init; }
    public HttpMessageHandler? Provider { get; init; }
    public string? Environment { get; init; }
    public string ConnectionString => connectionString;
}

public sealed record AckResult<T>(HttpStatusCode Http, CommandAck<T>? Ack, string Raw)
{
    public T Data => Ack!.Data!;
    public string Status => Ack?.Status ?? "";
    public string? Code => Ack?.Code;
}

/// <summary>An authenticated test account talking to the real HTTP pipeline.</summary>
public sealed class Account(HttpClient http, AuthResponse auth, string password)
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public HttpClient Http => http;
    public AuthResponse Auth => auth;
    public string Password => password;
    public Guid UserId => auth.Profile.UserId;

    public static async Task<Account> RegisterAsync(ApiFactory api, string? name = null)
    {
        var http = api.CreateClient();
        var password = "correct horse battery";
        var response = await http.PostAsJsonAsync("/api/v1/auth/register",
            new RegisterRequest($"{Guid.NewGuid():N}@example.test", password, name ?? "Test Person"));
        response.EnsureSuccessStatusCode();
        var auth = (await response.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return new Account(http, auth, password);
    }

    public async Task<AckResult<T>> SendAsync<T>(HttpMethod method, string path, object body)
    {
        var response = await http.SendAsync(new HttpRequestMessage(method, "/api/v1" + path) { Content = JsonContent.Create(body, options: Json) });
        var raw = await response.Content.ReadAsStringAsync();
        var ack = raw.Contains("\"operationId\"") ? JsonSerializer.Deserialize<CommandAck<T>>(raw, Json) : null;
        return new(response.StatusCode, ack, raw);
    }

    public Task<AckResult<T>> PostAsync<T>(string path, object body) => SendAsync<T>(HttpMethod.Post, path, body);
    public Task<AckResult<T>> PutAsync<T>(string path, object body) => SendAsync<T>(HttpMethod.Put, path, body);
    public async Task<SnapshotDto> SnapshotAsync() => (await http.GetFromJsonAsync<SnapshotDto>("/api/v1/sync/snapshot", Json))!;
    public async Task<PlanContextDto> ContextAsync() => (await SnapshotAsync()).Context;

    // ---- Scenario helpers shared by the suites. The reviewed start is Friday 2026-10-09. ----
    public static readonly DateOnly Friday = new(2026, 10, 9);
    public static PlanSetup Setup(DateOnly? start = null, int weeks = 4) =>
        new("strength", 3, 45, "full_gym", "comfortable", null, weeks, [1, 3, 5], start ?? Friday);

    public async Task<PlanDto> DraftAsync(DateOnly? start = null, int weeks = 4)
    {
        var id = Guid.NewGuid();
        var r = await PostAsync<PlanDraftResult>("/plan-drafts", new PlanDraftRequest(Guid.NewGuid(), id, Setup(start, weeks), null, null));
        Assert.Equal("accepted", r.Status);
        return r.Data.Context!.Plans.Single(p => p.Id == id);
    }

    public ActivateRequest ActivateRequestFor(PlanDto plan, int contextRevision, Guid? replace = null, Guid? operationId = null) =>
        new(operationId ?? Guid.NewGuid(), contextRevision, plan.Revision, plan.StartDate,
            plan.Occasions.Select(o => new ReviewedDate(o.Id, o.ScheduledDate)).ToList(), replace, false, plan.StartDate);

    public async Task<PlanDto> ActivePlanAsync(DateOnly? start = null, int weeks = 4)
    {
        var draft = await DraftAsync(start, weeks);
        var ctx = await ContextAsync();
        var r = await PostAsync<PlanContextDto>($"/plans/{draft.Id}/activate", ActivateRequestFor(draft, ctx.ContextRevision));
        Assert.Equal("accepted", r.Status);
        return r.Data.Plans.Single(p => p.Id == draft.Id);
    }

    public static List<ExerciseSpec> Snapshot(OccasionDto occasion) => occasion.Prescription.Select((e, i) => new ExerciseSpec(
        Guid.NewGuid(), i + 1, e.Name, e.CatalogKey, e.OccurrenceKey, true, e.IsTimed, e.TargetSets, e.TargetRepsMin, e.TargetRepsMax,
        e.TargetDurationSeconds, e.RestSeconds, null)).ToList();

    public async Task<WorkoutDto> StartPlannedAsync(OccasionDto occasion)
    {
        var r = await PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "planned", occasion.Id,
            occasion.Title, occasion.ScheduledDate, DateTime.UtcNow, Snapshot(occasion)));
        Assert.Equal("accepted", r.Status);
        return r.Data;
    }

    public async Task<WorkoutDto> StartManualAsync(string title = "Extra session")
    {
        var exercise = new ExerciseSpec(Guid.NewGuid(), 1, "Push-up", "push-up", null, false, false, null, null, null, null, null, null);
        var r = await PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "manual", null, title,
            Friday, DateTime.UtcNow, [exercise]));
        Assert.Equal("accepted", r.Status);
        return r.Data;
    }

    public async Task<SetDto> AddSetAsync(Guid exerciseId, int? reps = 8, decimal? loadKg = 60m, int? seconds = null)
    {
        var r = await PostAsync<SetDto>($"/exercises/{exerciseId}/sets", new SetCreateRequest(Guid.NewGuid(), Guid.NewGuid(), reps, loadKg, seconds, DateTime.UtcNow));
        Assert.Equal("accepted", r.Status);
        return r.Data;
    }

    public async Task<AckResult<WorkoutDto>> FinishAsync(WorkoutDto workout, IEnumerable<SetDto> sets, int seconds = 125, Guid? operationId = null) =>
        await PostAsync<WorkoutDto>($"/workouts/{workout.Id}/finish", new FinishRequest(operationId ?? Guid.NewGuid(), workout.Revision,
            sets.Select(s => new AcknowledgedSet(s.Id, s.Revision)).ToList(), seconds, new DateTime(2026, 10, 10, 0, 5, 0, DateTimeKind.Utc)));
}

public static class Fixture
{
    public static readonly JsonNode Root = JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contract_fixture.json")))!;
    public static DateOnly Date(JsonNode? n) => DateOnly.ParseExact(n!.GetValue<string>(), "yyyy-MM-dd");
}
