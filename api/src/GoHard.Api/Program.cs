using System.Security.Claims;
using System.Threading.RateLimiting;
using GoHard.Api.Application;
using GoHard.Api.Endpoints;
using GoHard.Api.Persistence;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
// Local secrets live outside version control: appsettings.Local.json (written by scripts/setup.ps1) or GOHARD_* variables.
// The local file has the LOWEST precedence, so host settings (tests, command line) and GOHARD_* variables always win over it.
builder.Configuration.Sources.Insert(0, new Microsoft.Extensions.Configuration.Json.JsonConfigurationSource
    { Path = "appsettings.Local.json", Optional = true, FileProvider = builder.Environment.ContentRootFileProvider });
builder.Configuration.AddEnvironmentVariables("GOHARD_");

var connection = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured. Run scripts/setup.ps1.");
var auth = builder.Configuration.GetSection("Auth").Get<AuthOptions>() ?? new();
if (auth.SigningKey.Length < 32)
    throw new InvalidOperationException("Auth:SigningKey is missing or shorter than 32 characters. Run scripts/setup.ps1.");

builder.Services.AddDbContext<GoHardDb>(o => o.UseNpgsql(connection));
builder.Services.AddSingleton(auth);
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<CommandRunner>();
builder.Services.AddGoHardModules(builder.Configuration);
builder.Services.AddSingleton<ReadinessGate>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.MapInboundClaims = false;
    o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = auth.Issuer, ValidAudience = auth.Audience, IssuerSigningKey = auth.Key,
        ValidateIssuerSigningKey = true, ClockSkew = TimeSpan.FromSeconds(30),
    };
    // A token only works while its account still exists with the same security stamp.
    o.Events = new JwtBearerEvents
    {
        OnTokenValidated = async ctx =>
        {
            var db = ctx.HttpContext.RequestServices.GetRequiredService<GoHardDb>();
            var stamp = Guid.TryParse(ctx.Principal?.FindFirstValue("sub"), out var id)
                ? await db.Users.Where(u => u.Id == id).Select(u => u.SecurityStamp).FirstOrDefaultAsync(ctx.HttpContext.RequestAborted)
                : null;
            if (stamp is null || stamp != ctx.Principal!.FindFirstValue(AuthService.StampClaim)) ctx.Fail("Account is no longer valid.");
        },
    };
});
builder.Services.AddAuthorization();
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy("auth", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "local",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = builder.Configuration.GetValue("Auth:RateLimitPerMinute", 30), Window = TimeSpan.FromMinutes(1),
        }));
});

var app = builder.Build();

// Explicit maintenance commands. Normal startup below never changes schema or data.
if (args.Length > 0 && args[0] is "migrate" or "seed-catalog" or "readiness")
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<GoHardDb>();
    if (args[0] == "migrate") { await db.Database.MigrateAsync(); Console.WriteLine("Migrations applied."); }
    if (args[0] == "seed-catalog") Console.WriteLine($"Catalog entries: {await CatalogSeeder.SeedAsync(db, default)}");
    var state = await SchemaReadinessService.CheckAsync(db, default);
    Console.WriteLine($"Readiness: {state.Kind} - {state.Detail}");
    return state.IsReady ? 0 : 2;
}

app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health/live", () => Results.Ok(new { status = "live" }));
app.MapGet("/health/ready", async (ReadinessGate gate, GoHardDb db, CancellationToken ct) =>
{
    var s = await gate.CheckAsync(db, ct);
    return Results.Json(new { status = s.Kind.ToString(), detail = s.Detail }, statusCode: s.IsReady ? 200 : 503);
});
app.Use(async (ctx, next) =>
{
    if (ctx.Request.Path.StartsWithSegments("/api"))
    {
        var s = await ctx.RequestServices.GetRequiredService<ReadinessGate>()
            .CheckAsync(ctx.RequestServices.GetRequiredService<GoHardDb>(), ctx.RequestAborted);
        if (!s.IsReady)
        {
            ctx.Response.StatusCode = 503;
            await ctx.Response.WriteAsJsonAsync(new { code = "SCHEMA_NOT_READY", status = s.Kind.ToString() });
            return;
        }
    }
    await next();
});

app.MapGoHardEndpoints();
await app.RunAsync();
return 0;

/// <summary>Caches a Ready result; while not ready it re-reads so an explicit migration is noticed without a restart.</summary>
public sealed class ReadinessGate
{
    private SchemaReadiness? _ready;
    public async Task<SchemaReadiness> CheckAsync(GoHardDb db, CancellationToken ct)
    {
        if (_ready is not null) return _ready;
        var s = await SchemaReadinessService.CheckAsync(db, ct);
        if (s.IsReady) _ready = s;
        return s;
    }
}

public partial class Program;
