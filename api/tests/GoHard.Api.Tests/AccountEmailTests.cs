using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using GoHard.Api.Application;
using GoHard.Api.Application.AccountEmail;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace GoHard.Api.Tests;

/// <summary>
/// Password reset, email verification and password change (docs/AUTHENTICATION_EMAIL.md). Mail goes to the in-memory
/// capture transport (or a stubbed Resend endpoint); nothing here is real delivery. Time is a controlled clock and the
/// delivery worker is run pass by pass, so nothing waits on wall-clock time.
/// </summary>
[Collection("api")]
public sealed class AccountEmailTests(PostgresFixture pg)
{
    private const string NewPassword = "a brand new passphrase";
    private static readonly JsonSerializerOptions Json = Account.Json;

    private sealed class Env(ApiFactory api, TestTime time, LogSink logs) : IAsyncDisposable
    {
        public ApiFactory Api => api;
        public TestTime Time => time;
        public LogSink Logs => logs;
        public HttpClient Anonymous { get; } = api.CreateClient();
        public CaptureMailbox Box => api.Services.GetRequiredService<CaptureMailbox>();
        public Task<int> Deliver() => api.Services.GetRequiredService<MailWorker>().RunOnceAsync(default);

        /// <summary>The newest captured code of one kind (reset by default) sent to [email].</summary>
        public async Task<string> CodeFor(string email, bool reset = true)
        {
            await Deliver();
            var mail = Box.All.LastOrDefault(m => m.To == email && m.Subject.Contains(reset ? "reset" : "Verify")) ?? throw new InvalidOperationException("no mail captured");
            return Regex.Match(mail.Text, @"\b\d{8}\b").Value;
        }

        public Task<HttpResponseMessage> Post(string path, object body, string? bearer = null)
        {
            var r = new HttpRequestMessage(HttpMethod.Post, "/api/v1" + path) { Content = JsonContent.Create(body, options: Json) };
            if (bearer is not null) r.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearer);
            return Anonymous.SendAsync(r);
        }

        public Task<HttpResponseMessage> RequestReset(string email) => Post("/auth/password-reset/request", new { email, language = "en" });
        public Task<HttpResponseMessage> VerifyReset(string email, string code) => Post("/auth/password-reset/verify", new { email, code });
        public Task<HttpResponseMessage> CompleteReset(string token, string password) => Post("/auth/password-reset/complete", new { resetToken = token, newPassword = password });

        public async Task<string> Grant(string email, string code)
        {
            var r = await VerifyReset(email, code);
            Assert.Equal(HttpStatusCode.OK, r.StatusCode);
            return (await r.Content.ReadFromJsonAsync<ResetGrant>(Json))!.ResetToken;
        }

        public Task<HttpResponseMessage> Login(string email, string password) => Post("/auth/login", new LoginRequest(email, password));
        public Task<HttpResponseMessage> Refresh(string token) => Post("/auth/refresh", new RefreshRequest(token));
        public async Task<HttpStatusCode> Me(string bearer)
        {
            var r = new HttpRequestMessage(HttpMethod.Get, "/api/v1/me") { Headers = { Authorization = new("Bearer", bearer) } };
            return (await Anonymous.SendAsync(r)).StatusCode;
        }

        public ValueTask DisposeAsync() => api.DisposeAsync();
    }

    /// <summary>A fresh database and an API with the capture transport, a controlled clock and the worker off.</summary>
    private async Task<Env> Start(Dictionary<string, string>? extra = null, string? cs = null, HttpMessageHandler? provider = null, TestTime? time = null)
    {
        cs ??= await pg.CreateDatabaseAsync(migrate: true);
        time ??= new TestTime { Now = DateTimeOffset.UtcNow };
        var logs = new LogSink();
        var settings = new Dictionary<string, string>
        {
            ["Email:Provider"] = "Capture", ["Email:WorkerEnabled"] = "false", ["Email:CodeSecret"] = "test-only-code-secret-0123456789-abcdefghij",
            ["Email:PerIpPerHour"] = "100000",
        };
        foreach (var (k, v) in extra ?? []) settings[k] = v;
        var api = new ApiFactory(cs)
        {
            Settings = settings, Provider = provider,
            Configure = s => { s.AddSingleton<TimeProvider>(time); s.AddSingleton<ILoggerProvider>(logs); },
        };
        return new Env(api, time, logs);
    }

    private static async Task<string?> Code(HttpResponseMessage r) =>
        (await r.Content.ReadAsStringAsync()) is { Length: > 0 } s && JsonDocument.Parse(s).RootElement.TryGetProperty("code", out var c) ? c.GetString() : null;

    [Fact]
    public async Task Requests_look_the_same_for_existing_unknown_and_never_disclose_an_account()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;
        await e.Deliver(); // the registration's own verification email

        var known = await e.RequestReset(email);
        var unknown = await e.RequestReset("nobody-" + Guid.NewGuid().ToString("N") + "@example.test");
        Assert.Equal((HttpStatusCode.Accepted, HttpStatusCode.Accepted), (known.StatusCode, unknown.StatusCode));
        Assert.Equal(await known.Content.ReadAsStringAsync(), await unknown.Content.ReadAsStringAsync());

        var malformed = await e.RequestReset("not-an-address");
        Assert.Equal((HttpStatusCode.BadRequest, "INVALID_EMAIL"), (malformed.StatusCode, await Code(malformed)));

        // The cooldown answers identically too.
        var knownAgain = await e.RequestReset(email);
        var unknownAgain = await e.RequestReset("NOBODY2@example.test");
        Assert.Equal(HttpStatusCode.TooManyRequests, knownAgain.StatusCode);
        Assert.Equal("EMAIL_COOLDOWN", await Code(knownAgain));
        Assert.Equal(HttpStatusCode.Accepted, unknownAgain.StatusCode); // a different address: its own first request

        // Only the real account gets mail; the address is not stored in the challenge table.
        await e.Deliver();
        Assert.Equal(2, e.Box.All.Count(m => m.To == email)); // verification + reset
        Assert.DoesNotContain(e.Box.All, m => m.To.StartsWith("nobody"));
        await using (var db = PostgresFixture.NewDb(e.Api.ConnectionString))
        {
            var rows = await db.AuthChallenges.ToListAsync();
            Assert.Equal(4, rows.Count);
            Assert.All(rows, r => Assert.DoesNotContain("@", r.EmailKey));
            Assert.Equal(2, rows.Count(r => r.UserId == null));
        }

        // Guessing on an unknown address runs out exactly like on a known one.
        foreach (var target in new[] { email, "nobody2@example.test" })
        {
            var answers = new List<string?>();
            for (var i = 0; i < 6; i++) answers.Add(await Code(await e.VerifyReset(target, "00000000")));
            Assert.Equal(["INVALID_CODE", "INVALID_CODE", "INVALID_CODE", "INVALID_CODE", "TOO_MANY_ATTEMPTS", "TOO_MANY_ATTEMPTS"], answers);
        }
    }

    [Fact]
    public async Task Reset_sets_the_password_ends_every_session_and_defeats_refresh_recovery()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;
        // A rotated pair: the predecessor would normally still recover its replacement within the window.
        var rotated = (await (await e.Refresh(a.Auth.RefreshToken)).Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        var second = (await (await e.Login(email, a.Password)).Content.ReadFromJsonAsync<AuthResponse>(Json))!;

        Assert.Equal(HttpStatusCode.Accepted, (await e.RequestReset(email)).StatusCode);
        var code = await e.CodeFor(email);
        Assert.Matches("^[0-9]{8}$", code);
        var grant = await e.Grant(email, code);

        // The reset authorization is not a session, and requesting a code changed nothing.
        Assert.Equal(HttpStatusCode.Unauthorized, await e.Me(grant));
        Assert.Equal(HttpStatusCode.OK, await e.Me(rotated.AccessToken));

        var weak = await e.CompleteReset(grant, "too short");
        Assert.Equal("WEAK_PASSWORD", await Code(weak));
        var tooLong = await e.CompleteReset(grant, new string('x', PasswordPolicy.MaxLength + 1));
        Assert.Equal("PASSWORD_TOO_LONG", await Code(tooLong));
        Assert.Equal(HttpStatusCode.NoContent, (await e.CompleteReset(grant, NewPassword)).StatusCode); // a refused password did not spend it
        Assert.Equal("INVALID_RESET_TOKEN", await Code(await e.CompleteReset(grant, NewPassword)));    // single use

        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Login(email, a.Password)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, await e.Me(rotated.AccessToken));
        Assert.Equal(HttpStatusCode.Unauthorized, await e.Me(second.AccessToken));
        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Refresh(rotated.RefreshToken)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Refresh(a.Auth.RefreshToken)).StatusCode); // recovery of a revoked replacement
        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Refresh(second.RefreshToken)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await e.Login(email, NewPassword)).StatusCode);
        Assert.Equal("INVALID_CODE", await Code(await e.VerifyReset(email, code))); // the code is spent as well

        await e.Deliver();
        var notice = e.Box.Latest(email)!;
        Assert.Equal("Your GoHard password was changed", notice.Subject);
        Assert.DoesNotContain(NewPassword, notice.Text + notice.Html);
        Assert.DoesNotMatch(@"\d{8}", notice.Text);
    }

    [Fact]
    public async Task A_refresh_token_issued_under_an_old_stamp_is_refused_even_if_it_escaped_revocation()
    {
        // The race: a refresh that read the account before a password change inserts its replacement after the reset
        // revoked everything. Its stamp is the old one, so it never works.
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        string oldStamp;
        await using (var db = PostgresFixture.NewDb(e.Api.ConnectionString)) oldStamp = (await db.Users.SingleAsync(u => u.Id == a.UserId)).SecurityStamp;
        var change = await e.Post("/account/password", new { currentPassword = a.Password, newPassword = NewPassword }, a.Auth.AccessToken);
        Assert.Equal(HttpStatusCode.NoContent, change.StatusCode);
        const string escaped = "escaped-refresh-token";
        await using (var db = PostgresFixture.NewDb(e.Api.ConnectionString))
        {
            db.RefreshTokens.Add(new RefreshToken { Id = Guid.NewGuid(), UserId = a.UserId, TokenHash = AuthService.HashToken(escaped), ExpiresAtUtc = DateTime.UtcNow.AddDays(1), SecurityStamp = oldStamp });
            await db.SaveChangesAsync();
        }
        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Refresh(escaped)).StatusCode);
    }

    [Fact]
    public async Task Codes_are_bound_to_their_purpose_and_account_and_verification_changes_nothing_else()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        var b = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;
        var verifyCode = await e.CodeFor(email, reset: false); // queued at registration
        Assert.Equal("Verify your GoHard email", e.Box.Latest(email)!.Subject);
        Assert.Equal(HttpStatusCode.Accepted, (await e.RequestReset(email)).StatusCode);
        var resetCode = await e.CodeFor(email);
        Assert.NotEqual(verifyCode, resetCode);

        Assert.Equal("INVALID_CODE", await Code(await e.VerifyReset(email, verifyCode)));                                        // verification code cannot reset
        Assert.Equal("INVALID_CODE", await Code(await e.Post("/account/email-verification/confirm", new { code = resetCode }, a.Auth.AccessToken))); // reset code cannot verify
        Assert.Equal("INVALID_CODE", await Code(await e.Post("/account/email-verification/confirm", new { code = verifyCode }, b.Auth.AccessToken))); // nor another account

        var confirmed = await e.Post("/account/email-verification/confirm", new { code = verifyCode }, a.Auth.AccessToken);
        Assert.Equal(HttpStatusCode.OK, confirmed.StatusCode);
        Assert.True((await confirmed.Content.ReadFromJsonAsync<ProfileDto>(Json))!.EmailVerified);
        // No password change, no new session, the same address; the existing session goes on.
        Assert.Equal(HttpStatusCode.OK, await e.Me(a.Auth.AccessToken));
        Assert.Equal(HttpStatusCode.OK, (await e.Login(email, a.Password)).StatusCode);
        Assert.False((await b.Http.GetFromJsonAsync<ProfileDto>("/api/v1/me", Json))!.EmailVerified);
        Assert.Equal("ALREADY_VERIFIED", await Code(await e.Post("/account/email-verification/request", new { language = "fr-CA" }, a.Auth.AccessToken)));
    }

    [Fact]
    public async Task Expiry_attempt_limit_and_cooldown()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;
        await e.RequestReset(email);
        var code = await e.CodeFor(email);

        e.Time.Now += TimeSpan.FromMinutes(10) + TimeSpan.FromSeconds(1);
        Assert.Equal("CODE_EXPIRED", await Code(await e.VerifyReset(email, code)));

        Assert.Equal(HttpStatusCode.Accepted, (await e.RequestReset(email)).StatusCode); // cooldown long over
        var fresh = await e.CodeFor(email);
        var cooldown = await e.RequestReset(email);
        Assert.Equal(HttpStatusCode.TooManyRequests, cooldown.StatusCode);
        Assert.Equal(60, JsonDocument.Parse(await cooldown.Content.ReadAsStringAsync()).RootElement.GetProperty("retryAfterSeconds").GetInt32());

        var wrong = fresh == "11111111" ? "22222222" : "11111111";
        for (var i = 0; i < 4; i++) Assert.Equal("INVALID_CODE", await Code(await e.VerifyReset(email, wrong)));
        Assert.Equal("TOO_MANY_ATTEMPTS", await Code(await e.VerifyReset(email, wrong)));
        Assert.Equal("TOO_MANY_ATTEMPTS", await Code(await e.VerifyReset(email, fresh))); // the right code no longer helps
    }

    [Fact]
    public async Task Asking_again_resends_the_same_code_so_nobody_can_void_or_reset_a_live_one()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;
        await e.RequestReset(email);
        var first = await e.CodeFor(email);
        var wrong = first == "11111111" ? "22222222" : "11111111";
        for (var i = 0; i < 2; i++) await e.VerifyReset(email, wrong);

        // Someone else asks for this address again, after the cooldown: the same code goes out; attempts are kept.
        e.Time.Now += TimeSpan.FromSeconds(61);
        Assert.Equal(HttpStatusCode.Accepted, (await e.RequestReset(email)).StatusCode);
        Assert.Equal(first, await e.CodeFor(email));
        for (var i = 0; i < 2; i++) Assert.Equal("INVALID_CODE", await Code(await e.VerifyReset(email, wrong)));
        Assert.Equal(HttpStatusCode.OK, (await e.VerifyReset(email, first)).StatusCode); // 5th attempt, and still the person's code

        // At most five sends per address per hour.
        for (var i = 0; i < 3; i++)
        {
            e.Time.Now += TimeSpan.FromSeconds(61);
            Assert.Equal(HttpStatusCode.Accepted, (await e.RequestReset(email)).StatusCode);
        }
        e.Time.Now += TimeSpan.FromSeconds(61);
        Assert.Equal("EMAIL_COOLDOWN", await Code(await e.RequestReset(email)));
    }

    [Fact]
    public async Task A_code_and_a_reset_authorization_are_each_spent_once_under_concurrency()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;
        await e.RequestReset(email);
        var code = await e.CodeFor(email);

        var verifies = await Task.WhenAll(Enumerable.Range(0, 4).Select(_ => e.VerifyReset(email, code)));
        Assert.Single(verifies, r => r.StatusCode == HttpStatusCode.OK);
        var grant = (await verifies.Single(r => r.StatusCode == HttpStatusCode.OK).Content.ReadFromJsonAsync<ResetGrant>(Json))!.ResetToken;

        var completes = await Task.WhenAll(Enumerable.Range(0, 8).Select(i => e.CompleteReset(grant, NewPassword + " " + i)));
        Assert.Single(completes, r => r.StatusCode == HttpStatusCode.NoContent);
        var winner = Array.FindIndex(completes, r => r.StatusCode == HttpStatusCode.NoContent);
        Assert.Equal(HttpStatusCode.OK, (await e.Login(email, NewPassword + " " + winner)).StatusCode);
    }

    [Fact]
    public async Task Cooldowns_attempts_and_codes_survive_a_restart()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        var time = new TestTime { Now = DateTimeOffset.UtcNow };
        string email, code, password;
        await using (var e = await Start(cs: cs, time: time))
        {
            var a = await Account.RegisterAsync(e.Api);
            (email, password) = (a.Auth.Profile.Email, a.Password);
            await e.RequestReset(email);
            code = await e.CodeFor(email);
            await e.VerifyReset(email, code == "11111111" ? "22222222" : "11111111");
        }
        await using var after = await Start(cs: cs, time: time); // another process: nothing was in memory
        Assert.Equal("EMAIL_COOLDOWN", await Code(await after.RequestReset(email)));
        await using (var db = PostgresFixture.NewDb(cs)) Assert.Equal(1, (await db.AuthChallenges.SingleAsync(c => c.Purpose == AccountEmailService.Reset)).Attempts);
        Assert.Equal(HttpStatusCode.NoContent, (await after.CompleteReset(await after.Grant(email, code), NewPassword)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await after.Login(email, password)).StatusCode);
    }

    [Fact]
    public async Task Change_password_checks_the_current_one_and_ends_every_session()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;

        var wrong = await e.Post("/account/password", new { currentPassword = "not the password at all", newPassword = NewPassword }, a.Auth.AccessToken);
        Assert.Equal("WRONG_PASSWORD", await Code(wrong));
        var weak = await e.Post("/account/password", new { currentPassword = a.Password, newPassword = "short one" }, a.Auth.AccessToken);
        Assert.Equal("WEAK_PASSWORD", await Code(weak));
        // Neither changed anything: the session works, the old password signs in.
        Assert.Equal(HttpStatusCode.OK, await e.Me(a.Auth.AccessToken));
        Assert.Equal(HttpStatusCode.OK, (await e.Login(email, a.Password)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Post("/account/password", new { currentPassword = a.Password, newPassword = NewPassword })).StatusCode); // signed in only

        var ok = await e.Post("/account/password", new { currentPassword = a.Password, newPassword = NewPassword, language = "ar" }, a.Auth.AccessToken);
        Assert.Equal(HttpStatusCode.NoContent, ok.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, await e.Me(a.Auth.AccessToken));
        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Refresh(a.Auth.RefreshToken)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await e.Login(email, a.Password)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await e.Login(email, NewPassword)).StatusCode);

        await e.Deliver();
        var notice = e.Box.Latest(email)!;
        Assert.Equal("تم تغيير كلمة مرور GoHard", notice.Subject);
        Assert.Contains("dir=\"rtl\"", notice.Html);
    }

    [Fact]
    public async Task Verification_is_server_owned_and_older_clients_neither_clear_nor_grant_it()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api); // no language: an older app
        Assert.False(a.Auth.Profile.EmailVerified);
        // A profile update that tries to claim it, and one that predates it: neither changes it.
        var claim = await a.Http.PutAsync("/api/v1/me", JsonContent.Create(new
        {
            operationId = Guid.NewGuid(), expectedRevision = 1, displayName = "Claims", appearance = "dark", loadUnit = "kg", remindersEnabled = false, emailVerified = true,
        }));
        Assert.Equal(HttpStatusCode.OK, claim.StatusCode);
        Assert.False((await a.Http.GetFromJsonAsync<ProfileDto>("/api/v1/me", Json))!.EmailVerified);

        var code = await e.CodeFor(a.Auth.Profile.Email, reset: false);
        Assert.Equal(HttpStatusCode.OK, (await e.Post("/account/email-verification/confirm", new { code = ToArabic(code) }, a.Auth.AccessToken)).StatusCode);
        var older = await a.Http.PutAsync("/api/v1/me", JsonContent.Create(new
        {
            operationId = Guid.NewGuid(), expectedRevision = 2, displayName = "Older app", appearance = "dark", loadUnit = "kg", remindersEnabled = false,
        }));
        Assert.Equal(HttpStatusCode.OK, older.StatusCode);
        Assert.True((await a.Http.GetFromJsonAsync<ProfileDto>("/api/v1/me", Json))!.EmailVerified);
        Assert.True((await a.SnapshotAsync()).Profile.EmailVerified);
    }

    private static string ToArabic(string code) => string.Concat(code.Select(d => (char)('٠' + (d - '0'))));

    [Fact]
    public async Task Account_erasure_removes_its_challenges_and_unsent_mail()
    {
        await using var e = await Start();
        var a = await Account.RegisterAsync(e.Api);
        await e.RequestReset(a.Auth.Profile.Email); // two codes and two queued messages, none sent
        var del = new HttpRequestMessage(HttpMethod.Delete, "/api/v1/account") { Content = JsonContent.Create(new { password = a.Password }),
            Headers = { Authorization = new("Bearer", a.Auth.AccessToken) } };
        Assert.Equal(HttpStatusCode.NoContent, (await e.Anonymous.SendAsync(del)).StatusCode);
        await using var db = PostgresFixture.NewDb(e.Api.ConnectionString);
        Assert.Equal(0, await db.AuthChallenges.CountAsync(c => c.UserId == a.UserId));
        Assert.Equal(0, await db.MailMessages.CountAsync());
        Assert.Equal(0, await e.Deliver());
    }

    [Fact]
    public async Task Provider_trouble_retries_with_one_key_and_identical_content_and_expired_or_used_codes_are_never_sent()
    {
        var calls = new ConcurrentQueue<(string? Key, string Body)>();
        var answers = new ConcurrentQueue<Func<HttpResponseMessage>>();
        var resend = new StubProvider(async r =>
        {
            calls.Enqueue((r.Headers.TryGetValues("Idempotency-Key", out var k) ? k.Single() : null, await r.Content!.ReadAsStringAsync()));
            return answers.TryDequeue(out var next) ? next() : StubProvider.Json("{\"id\":\"re-1\"}");
        });
        await using var e = await Start(new()
        {
            ["Email:Provider"] = "Resend", ["Email:ResendApiKey"] = "re_test_secret_key_value", ["Email:FromAddress"] = "noreply@auth.example.test",
        }, provider: resend);
        var a = await Account.RegisterAsync(e.Api);
        var email = a.Auth.Profile.Email;

        // Ambiguous: the connection drops (perhaps sent), then a 500, then success. One key, one content, three calls.
        answers.Enqueue(() => throw new HttpRequestException("connection reset"));
        answers.Enqueue(() => StubProvider.Json("{\"name\":\"internal_server_error\"}", HttpStatusCode.InternalServerError));
        Assert.Equal(1, await e.Deliver());
        Assert.Equal(0, await e.Deliver()); // backing off: not due yet
        e.Time.Now += TimeSpan.FromSeconds(30);
        await e.Deliver();
        e.Time.Now += TimeSpan.FromSeconds(60);
        await e.Deliver();
        Assert.Equal(3, calls.Count);
        Assert.Single(calls.Select(c => c.Key).Distinct());
        Assert.Single(calls.Select(c => c.Body).Distinct());
        Assert.StartsWith("gohard-mail-", calls.First().Key);
        var body = JsonDocument.Parse(calls.First().Body).RootElement;
        Assert.Equal("\"GoHard\" <noreply@auth.example.test>", body.GetProperty("from").GetString());
        Assert.Equal(email, body.GetProperty("to")[0].GetString());
        Assert.False(body.TryGetProperty("reply_to", out _));
        await using (var db = PostgresFixture.NewDb(e.Api.ConnectionString))
            Assert.Equal(("sent", "re-1"), await db.MailMessages.Select(m => new { m.State, m.ProviderId }).SingleAsync() is var m ? (m.State, m.ProviderId) : default);

        // A permanent refusal stops at once.
        answers.Enqueue(() => StubProvider.Json("{\"name\":\"validation_error\"}", HttpStatusCode.UnprocessableEntity));
        e.Time.Now += TimeSpan.FromSeconds(61);
        await e.RequestReset(email);
        await e.Deliver();
        await using (var db = PostgresFixture.NewDb(e.Api.ConnectionString))
            Assert.Equal("422 validation_error", (await db.MailMessages.SingleAsync(m => m.Kind == AccountEmailService.Reset)).LastError);

        // Expired before it could go: never sent. And a code already used: never sent.
        calls.Clear();
        e.Time.Now += TimeSpan.FromSeconds(61);
        answers.Enqueue(() => StubProvider.Json("{}", HttpStatusCode.ServiceUnavailable));
        await e.RequestReset(email);                // the live code is resent (new message)
        await e.Deliver();                          // 503 → retry later
        e.Time.Now += TimeSpan.FromMinutes(11);     // past the code's expiry
        await e.Deliver();
        Assert.Single(calls);
        await using (var db = PostgresFixture.NewDb(e.Api.ConnectionString))
            Assert.Contains("expired", await db.MailMessages.Select(m => m.State).ToListAsync());

        // Nothing sensitive in the logs: no address, code, key or body.
        var logged = string.Join("\n", e.Logs.Lines);
        Assert.Contains("gohard", logged, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(email, logged);
        Assert.DoesNotContain("re_test_secret_key_value", logged);
        Assert.DoesNotMatch(@"\b\d{8}\b", logged);
        Assert.DoesNotContain(a.Password, logged);
    }

    [Fact]
    public async Task Without_a_sender_every_address_hears_unavailable_and_capture_is_refused_in_production()
    {
        var cs = await pg.CreateDatabaseAsync(migrate: true);
        await using (var plain = new ApiFactory(cs))
        {
            var http = plain.CreateClient();
            var caps = await http.GetStringAsync("/api/v1/capabilities");
            Assert.Contains("account.security", caps);
            Assert.DoesNotContain("\"account.email\"", caps);
            var a = await Account.RegisterAsync(plain);
            foreach (var address in new[] { a.Auth.Profile.Email, "unknown@example.test" })
            {
                var r = await http.PostAsJsonAsync("/api/v1/auth/password-reset/request", new { email = address });
                Assert.Equal((HttpStatusCode.ServiceUnavailable, "EMAIL_UNAVAILABLE"), (r.StatusCode, await Code(r)));
            }
            await using var db = PostgresFixture.NewDb(cs);
            Assert.Equal(0, await db.MailMessages.CountAsync()); // registration queued nothing
        }

        foreach (var settings in new Dictionary<string, string>[]
                 {
                     new() { ["Email:Provider"] = "Capture" },                                      // capture outside Development
                     new() { ["Email:Provider"] = "Resend", ["Email:FromAddress"] = "a@b.test", ["Email:CodeSecret"] = new string('k', 40) }, // no key
                     new() { ["Email:Provider"] = "Smtp" },
                 })
        {
            await using var refused = new ApiFactory(cs) { Settings = settings, Environment = "Production" };
            var ex = Assert.ThrowsAny<Exception>(() => refused.CreateClient());
            Assert.Contains("Email:", ex.ToString());
        }

        await using var capture = await Start(cs: cs);
        Assert.Contains("\"account.email\"", await capture.Anonymous.GetStringAsync("/api/v1/capabilities"));
    }

    [Fact]
    public async Task Per_address_ip_and_global_limits()
    {
        await using var e = await Start(new() { ["Email:PerIpPerHour"] = "3", ["Email:DeliveryBudgetPerHour"] = "1" });
        var a = await Account.RegisterAsync(e.Api); // its verification email uses the one message of the budget
        // The global budget: busy for a known and an unknown address alike.
        Assert.Equal("EMAIL_BUSY", await Code(await e.RequestReset(a.Auth.Profile.Email)));
        Assert.Equal("EMAIL_BUSY", await Code(await e.RequestReset("unknown@example.test")));
        // The per-IP limit on these routes (3 per hour here) is the fourth request.
        var limited = await e.RequestReset("third@example.test");
        Assert.Equal(HttpStatusCode.TooManyRequests, (await e.RequestReset("fourth@example.test")).StatusCode);
        Assert.Equal("EMAIL_BUSY", await Code(limited));
    }
}

public sealed class LogSink : ILoggerProvider
{
    public ConcurrentQueue<string> Lines { get; } = new();
    public ILogger CreateLogger(string category) => new Logger(this, category);
    public void Dispose() { }

    private sealed class Logger(LogSink sink, string category) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel level) => true;
        public void Log<TState>(LogLevel level, EventId id, TState state, Exception? ex, Func<TState, Exception?, string> format) =>
            sink.Lines.Enqueue($"{category}: {format(state, ex)} {ex}");
    }
}
