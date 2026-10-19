using System.Net;
using System.Net.Http.Json;
using GoHard.Api.Application;
using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Tests;

/// <summary>
/// A refresh the server accepted whose response never reached the phone (docs/ARCHITECTURE.md › Sessions): the phone
/// still holds the previous refresh token and presents it again. Within a short window from the rotation, and only
/// while the replacement is unused, the server answers with that same replacement instead of signing the phone out.
/// </summary>
[Collection("api")]
public sealed class RefreshRecoveryTests(PostgresFixture pg)
{
    private static async Task<(HttpStatusCode Status, AuthResponse? Auth)> Refresh(HttpClient http, string token)
    {
        var r = await http.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(token));
        return (r.StatusCode, r.IsSuccessStatusCode ? await r.Content.ReadFromJsonAsync<AuthResponse>(Account.Json) : null);
    }

    private static string Hash(string token) => Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token)));

    /// <summary>Sets when a token was rotated, as if it had happened [ago] before now.</summary>
    private async Task RotatedAgo(string token, TimeSpan ago)
    {
        await using var db = pg.SharedDb();
        var hash = Hash(token);
        Assert.Equal(1, await db.RefreshTokens.Where(t => t.TokenHash == hash).ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAtUtc, DateTime.UtcNow - ago)));
    }

    private async Task<DateTime?> RotatedAt(string token)
    {
        await using var db = pg.SharedDb();
        var hash = Hash(token);
        return await db.RefreshTokens.Where(t => t.TokenHash == hash).Select(t => t.RevokedAtUtc).SingleAsync();
    }

    [Fact]
    public async Task a_lost_refresh_response_is_recovered_with_the_same_replacement_and_retries_change_nothing()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var http = pg.Api.CreateClient();
        var r1 = a.Auth.RefreshToken;

        var first = await Refresh(http, r1);           // accepted and rotated...
        Assert.Equal(HttpStatusCode.OK, first.Status); // ...but this answer is "lost": the phone never sees R2

        for (var i = 0; i < 3; i++)                    // the phone retries with what it still has, perhaps more than once
        {
            var retry = await Refresh(http, r1);
            Assert.Equal(HttpStatusCode.OK, retry.Status);
            Assert.Equal(first.Auth!.RefreshToken, retry.Auth!.RefreshToken); // the already-issued replacement, not a new chain
            Assert.Equal(a.UserId, retry.Auth.Profile.UserId);
            var me = new HttpRequestMessage(HttpMethod.Get, "/api/v1/me") { Headers = { Authorization = new("Bearer", retry.Auth.AccessToken) } };
            Assert.Equal(HttpStatusCode.OK, (await http.SendAsync(me)).StatusCode);
        }
        await using (var db = pg.SharedDb())
            Assert.Equal(2, await db.RefreshTokens.CountAsync(t => t.UserId == a.UserId)); // one chain: the original and its one replacement

        // The replacement goes on normally; once it is used, the old token is spent for good.
        var next = await Refresh(http, first.Auth!.RefreshToken);
        Assert.Equal(HttpStatusCode.OK, next.Status);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, r1)).Status);
    }

    [Fact]
    public async Task concurrent_refreshes_and_retries_all_get_the_one_replacement()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var results = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Refresh(pg.Api.CreateClient(), a.Auth.RefreshToken)));
        Assert.All(results, r => Assert.Equal(HttpStatusCode.OK, r.Status));
        Assert.Single(results.Select(r => r.Auth!.RefreshToken).Distinct());
        await using var db = pg.SharedDb();
        Assert.Equal(2, await db.RefreshTokens.CountAsync(t => t.UserId == a.UserId)); // never two chains for one sign-in
        Assert.Equal(1, await db.RefreshTokens.CountAsync(t => t.UserId == a.UserId && t.RevokedAtUtc == null));
    }

    [Fact]
    public async Task the_window_counts_from_the_rotation_and_retries_do_not_extend_it()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var http = pg.Api.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await Refresh(http, a.Auth.RefreshToken)).Status);
        await RotatedAgo(a.Auth.RefreshToken, TimeSpan.FromSeconds(200));
        var rotated = await RotatedAt(a.Auth.RefreshToken);
        Assert.Equal(HttpStatusCode.OK, (await Refresh(http, a.Auth.RefreshToken)).Status); // 200 s after: inside 300 s
        Assert.Equal(rotated, await RotatedAt(a.Auth.RefreshToken));                        // a retry moves nothing
        await RotatedAgo(a.Auth.RefreshToken, TimeSpan.FromSeconds(301));
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, a.Auth.RefreshToken)).Status);
    }

    [Fact]
    public async Task only_the_immediate_predecessor_qualifies()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var http = pg.Api.CreateClient();
        var r1 = a.Auth.RefreshToken;
        var r2 = (await Refresh(http, r1)).Auth!.RefreshToken;
        var r3 = (await Refresh(http, r2)).Auth!.RefreshToken;
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, r1)).Status); // two rotations back
        Assert.Equal(r3, (await Refresh(http, r2)).Auth!.RefreshToken);              // the immediate one still recovers
    }

    [Fact]
    public async Task logout_expiry_and_account_deletion_are_still_final()
    {
        // Logged out with the replacement: the previous token cannot bring it back.
        var a = await Account.RegisterAsync(pg.Api);
        var http = pg.Api.CreateClient();
        var r2 = (await Refresh(http, a.Auth.RefreshToken)).Auth!;
        var logout = new HttpRequestMessage(HttpMethod.Post, "/api/v1/auth/logout") { Content = JsonContent.Create(new RefreshRequest(r2.RefreshToken)),
            Headers = { Authorization = new("Bearer", r2.AccessToken) } };
        Assert.Equal(HttpStatusCode.NoContent, (await http.SendAsync(logout)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, a.Auth.RefreshToken)).Status);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, r2.RefreshToken)).Status);

        // A logged-out token itself never recovers anything.
        var b = await Account.RegisterAsync(pg.Api);
        var bye = new HttpRequestMessage(HttpMethod.Post, "/api/v1/auth/logout") { Content = JsonContent.Create(new RefreshRequest(b.Auth.RefreshToken)),
            Headers = { Authorization = new("Bearer", b.Auth.AccessToken) } };
        await http.SendAsync(bye);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, b.Auth.RefreshToken)).Status);

        // Expired (the 60 days) even inside the window.
        var c = await Account.RegisterAsync(pg.Api);
        Assert.Equal(HttpStatusCode.OK, (await Refresh(http, c.Auth.RefreshToken)).Status);
        await using (var db = pg.SharedDb())
            await db.RefreshTokens.Where(t => t.UserId == c.UserId).ExecuteUpdateAsync(s => s.SetProperty(t => t.ExpiresAtUtc, DateTime.UtcNow.AddSeconds(-1)));
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, c.Auth.RefreshToken)).Status);

        // A deleted account: nothing.
        var d = await Account.RegisterAsync(pg.Api);
        Assert.Equal(HttpStatusCode.OK, (await Refresh(http, d.Auth.RefreshToken)).Status);
        var del = new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new { password = d.Password }),
            Headers = { Authorization = new("Bearer", d.Auth.AccessToken) } };
        Assert.Equal(HttpStatusCode.NoContent, (await http.SendAsync(del)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, d.Auth.RefreshToken)).Status);
    }

    [Fact]
    public async Task recovery_stays_within_its_own_account()
    {
        var a = await Account.RegisterAsync(pg.Api);
        var b = await Account.RegisterAsync(pg.Api);
        var http = pg.Api.CreateClient();
        await Refresh(http, a.Auth.RefreshToken);
        await Refresh(http, b.Auth.RefreshToken);
        var ra = (await Refresh(http, a.Auth.RefreshToken)).Auth!;
        var rb = (await Refresh(http, b.Auth.RefreshToken)).Auth!;
        Assert.Equal((a.UserId, b.UserId), (ra.Profile.UserId, rb.Profile.UserId));
        Assert.NotEqual(ra.RefreshToken, rb.RefreshToken);
    }

    [Fact]
    public async Task a_window_of_zero_turns_recovery_off()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        await using var api = new ApiFactory(cs) { Settings = new() { ["Auth:RefreshRecoverySeconds"] = "0" } };
        var a = await Account.RegisterAsync(api);
        var http = api.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await Refresh(http, a.Auth.RefreshToken)).Status);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Refresh(http, a.Auth.RefreshToken)).Status);
    }
}
