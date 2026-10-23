using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using GoHard.Api.Application;
using GoHard.Api.Application.AccountEmail;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace GoHard.Api.Tests;

/// <summary>
/// Required email verification at the API boundary (docs/AUTHENTICATION_EMAIL.md › Required verification): every data
/// route refuses an account that may not use its data, with its valid token, by direct request; the identity routes stay
/// open; nothing a client sends can grant eligibility; legacy grace is persisted once and expires.
/// </summary>
[Collection("api")]
public sealed class VerificationPolicyTests(PostgresFixture pg)
{
    private static readonly JsonSerializerOptions Json = Account.Json;

    private static async Task<string?> Code(HttpResponseMessage r) =>
        (await r.Content.ReadAsStringAsync()) is { Length: > 0 } s && JsonDocument.Parse(s).RootElement.TryGetProperty("code", out var c) ? c.GetString() : null;

    private static HttpRequestMessage Request(string method, string path, string bearer, object? body = null) =>
        new(new HttpMethod(method), path) { Content = JsonContent.Create(body ?? new { }), Headers = { Authorization = new AuthenticationHeaderValue("Bearer", bearer) } };

    /// <summary>Every signed-in route the API maps, with placeholders for its route values, and whether it is one of the
    /// identity routes a waiting account keeps.</summary>
    private static List<(string Method, string Path, bool Identity)> SignedInRoutes(ApiFactory api)
    {
        var routes = new List<(string, string, bool)>();
        foreach (var e in api.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>())
        {
            var authorize = e.Metadata.GetOrderedMetadata<IAuthorizeData>();
            if (authorize.Count == 0) continue;
            var path = "/" + string.Join("/", e.RoutePattern.PathSegments.Select(s => string.Concat(s.Parts.Select(p => p switch
            {
                Microsoft.AspNetCore.Routing.Patterns.RoutePatternLiteralPart l => l.Content,
                Microsoft.AspNetCore.Routing.Patterns.RoutePatternParameterPart { Name: "weekStart" } => "2026-10-19",
                Microsoft.AspNetCore.Routing.Patterns.RoutePatternParameterPart { Name: "index" } => "0",
                Microsoft.AspNetCore.Routing.Patterns.RoutePatternParameterPart => Guid.NewGuid().ToString(),
                _ => "",
            }))));
            var identity = authorize.Any(a => a.Policy == AccountAccess.IdentityPolicy);
            foreach (var method in e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods) routes.Add((method, path, identity));
        }
        return routes;
    }

    [Fact]
    public async Task A_new_account_reaches_only_the_identity_routes_until_it_verifies()
    {
        var waiting = await Account.RegisterAsync(pg.Api, verify: false);
        Assert.Equal((false, true, null), (waiting.Auth.Profile.EmailVerified, waiting.Auth.Profile.VerificationRequired, waiting.Auth.Profile.VerificationDueAtUtc));
        var routes = SignedInRoutes(pg.Api);
        // The exempt list is small and explicit; everything else signed in is data.
        Assert.Equal(
            ["DELETE /api/v1/account", "GET /api/v1/me", "POST /api/v1/account/email-verification/confirm", "POST /api/v1/account/email-verification/request",
             "POST /api/v1/account/password", "POST /api/v1/auth/logout"],
            routes.Where(r => r.Identity).Select(r => $"{r.Method} {r.Path}").Order());
        Assert.True(routes.Count(r => !r.Identity) > 40);

        var http = pg.Api.CreateClient();
        foreach (var (method, path, _) in routes.Where(r => !r.Identity))
        {
            // Query values a route needs; authorization runs first, so they only matter once access is granted.
            var r = await http.SendAsync(Request(method, path + "?date=2026-10-23&q=oats&lat=46.8&lon=-71.2", waiting.Auth.AccessToken));
            Assert.True(r.StatusCode == HttpStatusCode.Forbidden, $"{method} {path} answered {(int)r.StatusCode}");
            Assert.Equal("EMAIL_VERIFICATION_REQUIRED", await Code(r));
        }
        await using (var db = PostgresFixture.NewDb(pg.Api.ConnectionString))
            Assert.Equal(0, await db.Workouts.CountAsync(w => w.UserId == waiting.UserId) + await db.FoodEntries.CountAsync(f => f.UserId == waiting.UserId));

        // The identity routes answer for themselves (never the verification refusal).
        Assert.Equal(HttpStatusCode.OK, (await http.SendAsync(Request("GET", "/api/v1/me", waiting.Auth.AccessToken))).StatusCode);
        var resend = await http.SendAsync(Request("POST", "/api/v1/account/email-verification/request", waiting.Auth.AccessToken));
        Assert.Equal(("EMAIL_COOLDOWN"), await Code(resend)); // registration's own code is still in its cooldown: the same protection
        Assert.Equal("INVALID_CODE", await Code(await http.SendAsync(Request("POST", "/api/v1/account/email-verification/confirm", waiting.Auth.AccessToken, new { code = "00000000" }))));
        Assert.Equal("WRONG_PASSWORD", await Code(await http.SendAsync(Request("POST", "/api/v1/account/password", waiting.Auth.AccessToken, new { currentPassword = "wrong one entirely", newPassword = "a brand new passphrase" }))));
        Assert.Equal("WRONG_PASSWORD", await Code(await http.SendAsync(Request("DELETE", "/api/v1/account", waiting.Auth.AccessToken, new { password = "wrong one entirely" }))));
        Assert.Equal(HttpStatusCode.NoContent, (await http.SendAsync(Request("POST", "/api/v1/auth/logout", waiting.Auth.AccessToken, new { refreshToken = "none" }))).StatusCode);
        // Public routes stay public.
        Assert.Equal(HttpStatusCode.OK, (await http.GetAsync("/api/v1/capabilities")).StatusCode);

        // Verifying opens the data, with the same session.
        var profile = await Account.VerifyAsync(pg.Api, waiting.Http, waiting.UserId);
        Assert.Equal((true, false), (profile.EmailVerified, profile.VerificationRequired));
        Assert.Equal(HttpStatusCode.OK, (await waiting.Http.GetAsync("/api/v1/sync/snapshot")).StatusCode);
        Assert.Equal("accepted", (await waiting.PostAsync<WorkoutDto>("/workouts", new StartWorkoutRequest(Guid.NewGuid(), Guid.NewGuid(), "manual", null, "First",
            Account.Friday, DateTime.UtcNow, [new ExerciseSpec(Guid.NewGuid(), 1, "Push-up", "push-up", null, false, false, null, null, null, null, null, null)]))).Status);
    }

    [Fact]
    public async Task Invalid_sessions_keep_their_answers_and_a_forged_claim_grants_nothing()
    {
        var waiting = await Account.RegisterAsync(pg.Api, verify: false);
        var http = pg.Api.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await http.GetAsync("/api/v1/sync/snapshot")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await http.SendAsync(Request("GET", "/api/v1/sync/snapshot", "not-a-token"))).StatusCode);

        // A correctly signed token that carries the eligibility claim itself (as an old or crafted token might).
        string stamp;
        await using (var db = PostgresFixture.NewDb(pg.Api.ConnectionString)) stamp = (await db.Users.SingleAsync(u => u.Id == waiting.UserId)).SecurityStamp;
        var options = pg.Api.Services.GetRequiredService<AuthOptions>();
        var forged = new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(options.Issuer, options.Audience,
            [new Claim(JwtRegisteredClaimNames.Sub, waiting.UserId.ToString()), new Claim(AuthService.StampClaim, stamp), new Claim(AccountAccess.EligibleClaim, "1")],
            expires: DateTime.UtcNow.AddMinutes(5), signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.SigningKey)), SecurityAlgorithms.HmacSha256)));
        var r = await http.SendAsync(Request("GET", "/api/v1/sync/snapshot", forged));
        Assert.Equal((HttpStatusCode.Forbidden, "EMAIL_VERIFICATION_REQUIRED"), (r.StatusCode, await Code(r)));
    }

    [Fact]
    public async Task Refresh_sign_in_and_password_changes_do_not_bypass_it()
    {
        var waiting = await Account.RegisterAsync(pg.Api, verify: false);
        var http = pg.Api.CreateClient();
        async Task<HttpStatusCode> Snapshot(string token) => (await http.SendAsync(Request("GET", "/api/v1/sync/snapshot", token))).StatusCode;

        var refreshed = (await (await http.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(waiting.Auth.RefreshToken))).Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        Assert.True(refreshed.Profile.VerificationRequired);
        Assert.Equal(HttpStatusCode.Forbidden, await Snapshot(refreshed.AccessToken));

        // Signing in with the right password works and says what is required (not "wrong password").
        var login = await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(waiting.Auth.Profile.Email, waiting.Password));
        var signedIn = (await login.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        Assert.Equal((HttpStatusCode.OK, true), (login.StatusCode, signedIn.Profile.VerificationRequired));
        Assert.Equal(HttpStatusCode.Forbidden, await Snapshot(signedIn.AccessToken));

        // A password change keeps the 15-character rule, revokes sessions, and changes nothing about verification.
        Assert.Equal("WEAK_PASSWORD", await Code(await http.SendAsync(Request("POST", "/api/v1/account/password", signedIn.AccessToken, new { currentPassword = waiting.Password, newPassword = "too short" }))));
        Assert.Equal(HttpStatusCode.NoContent, (await http.SendAsync(Request("POST", "/api/v1/account/password", signedIn.AccessToken, new { currentPassword = waiting.Password, newPassword = "a brand new passphrase" }))).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, await Snapshot(signedIn.AccessToken));
        var after = (await (await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(waiting.Auth.Profile.Email, "a brand new passphrase"))).Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        Assert.Equal(HttpStatusCode.Forbidden, await Snapshot(after.AccessToken));

        // A password reset neither.
        Assert.Equal(HttpStatusCode.Accepted, (await http.PostAsJsonAsync("/api/v1/auth/password-reset/request", new { email = waiting.Auth.Profile.Email })).StatusCode);
        Guid challenge;
        await using (var db = PostgresFixture.NewDb(pg.Api.ConnectionString))
            challenge = await db.AuthChallenges.Where(c => c.UserId == waiting.UserId && c.Purpose == AccountEmailService.Reset).Select(c => c.Id).SingleAsync();
        var code = AccountEmailService.CodeFor(pg.Api.Services.GetRequiredService<EmailOptions>().CodeSecret, challenge);
        var grant = (await (await http.PostAsJsonAsync("/api/v1/auth/password-reset/verify", new { email = waiting.Auth.Profile.Email, code })).Content.ReadFromJsonAsync<ResetGrant>(Json))!;
        Assert.Equal(HttpStatusCode.NoContent, (await http.PostAsJsonAsync("/api/v1/auth/password-reset/complete", new { resetToken = grant.ResetToken, newPassword = "another long passphrase" })).StatusCode);
        var reset = (await (await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(waiting.Auth.Profile.Email, "another long passphrase"))).Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        Assert.Equal((false, true), (reset.Profile.EmailVerified, reset.Profile.VerificationRequired));
        Assert.Equal(HttpStatusCode.Forbidden, await Snapshot(reset.AccessToken));

        // An older app reads the contract and is told to update rather than meet these refusals with nothing to show.
        var capabilities = await http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities");
        Assert.Equal(2, capabilities.GetProperty("minimumClientContract").GetInt32());
    }

    [Fact]
    public async Task Legacy_accounts_get_a_persisted_grace_period_that_never_moves_and_never_verifies_them()
    {
        // Accounts as they were before the rollout: one verified, two not. Then the real migration runs.
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        var time = new TestTime { Now = DateTimeOffset.UtcNow };
        Account verified, legacy, other;
        await using (var before = new ApiFactory(cs) { Configure = s => s.AddSingleton<TimeProvider>(time) })
        {
            verified = await Account.RegisterAsync(before);
            legacy = await Account.RegisterAsync(before, verify: false);
            other = await Account.RegisterAsync(before, verify: false);
        }
        await using (var db = PostgresFixture.NewDb(cs))
        {
            var migrator = db.GetInfrastructure().GetRequiredService<IMigrator>();
            await migrator.MigrateAsync("AddAccountEmail"); // the schema before this change
            await migrator.MigrateAsync();                  // the rollout
        }
        DateTime graceFrom;
        await using (var db = PostgresFixture.NewDb(cs))
        {
            var users = await db.Users.AsNoTracking().ToDictionaryAsync(u => u.Id);
            Assert.Null(users[verified.UserId].VerificationGraceFromUtc);
            Assert.NotNull(users[verified.UserId].EmailVerifiedAtUtc);
            graceFrom = users[legacy.UserId].VerificationGraceFromUtc!.Value;
            Assert.Equal(graceFrom, users[other.UserId].VerificationGraceFromUtc);
            Assert.All(new[] { legacy, other }, a => Assert.Null(users[a.UserId].EmailVerifiedAtUtc)); // never marked verified
        }
        var due = graceFrom.AddDays(14);

        async Task<(AuthResponse Auth, HttpStatusCode Snapshot)> SignIn(ApiFactory api, Account a)
        {
            var http = api.CreateClient();
            var auth = (await (await http.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(a.Auth.Profile.Email, a.Password))).Content.ReadFromJsonAsync<AuthResponse>(Json))!;
            return (auth, (await http.SendAsync(Request("GET", "/api/v1/sync/snapshot", auth.AccessToken))).StatusCode);
        }

        time.Now = graceFrom.AddDays(3);
        await using (var api = new ApiFactory(cs) { Configure = s => s.AddSingleton<TimeProvider>(time) })
        {
            var (auth, snapshot) = await SignIn(api, legacy);
            Assert.Equal((false, false, due, HttpStatusCode.OK), (auth.Profile.EmailVerified, auth.Profile.VerificationRequired, auth.Profile.VerificationDueAtUtc, snapshot));
            // A new account created after the rollout has no grace.
            var fresh = await Account.RegisterAsync(api, verify: false);
            Assert.Equal((true, (DateTime?)null), (fresh.Auth.Profile.VerificationRequired, fresh.Auth.Profile.VerificationDueAtUtc));
            Assert.Equal(HttpStatusCode.Forbidden, (await fresh.Http.GetAsync("/api/v1/sync/snapshot")).StatusCode);
            // Asking for a code, signing in again and refreshing leave the deadline where it is.
            var http = api.CreateClient();
            Assert.Equal(HttpStatusCode.Accepted, (await http.SendAsync(Request("POST", "/api/v1/account/email-verification/request", auth.AccessToken))).StatusCode);
            var refreshed = (await (await http.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(auth.RefreshToken))).Content.ReadFromJsonAsync<AuthResponse>(Json))!;
            Assert.Equal(due, refreshed.Profile.VerificationDueAtUtc);
        }

        // Another process (a restart or redeploy), past the deadline: sign-in still works and says what is needed; data
        // access does not; the deadline did not move.
        time.Now = due.AddMinutes(1);
        await using (var restarted = new ApiFactory(cs) { Configure = s => s.AddSingleton<TimeProvider>(time) })
        {
            var (auth, snapshot) = await SignIn(restarted, legacy);
            Assert.Equal((false, true, due, HttpStatusCode.Forbidden), (auth.Profile.EmailVerified, auth.Profile.VerificationRequired, auth.Profile.VerificationDueAtUtc, snapshot));
            Assert.Equal(HttpStatusCode.OK, (await SignIn(restarted, verified)).Snapshot);
            await using (var db = PostgresFixture.NewDb(cs))
                Assert.Equal(graceFrom, (await db.Users.SingleAsync(u => u.Id == legacy.UserId)).VerificationGraceFromUtc);

            // The restricted account can still ask for a code and verify, which restores access.
            var http = restarted.CreateClient();
            http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
            Assert.Equal(HttpStatusCode.Accepted, (await http.PostAsJsonAsync("/api/v1/account/email-verification/request", new { })).StatusCode);
            var profile = await Account.VerifyAsync(restarted, http, legacy.UserId);
            Assert.Equal((true, false, (DateTime?)null), (profile.EmailVerified, profile.VerificationRequired, profile.VerificationDueAtUtc));
            Assert.Equal(HttpStatusCode.OK, (await http.GetAsync("/api/v1/sync/snapshot")).StatusCode);
        }
    }
}
