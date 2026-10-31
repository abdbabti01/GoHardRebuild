using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using GoHard.Api.Application.Plus;
using GoHard.Api.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace GoHard.Api.Tests;

/// <summary>
/// The shared AI limits (docs/PLUS_PREVIEW.md › Shared limits): two API instances on one database, concurrent
/// reservations, an instance that dies mid-request, late and racing finalizes.
/// </summary>
public partial class CoachTests
{
    private static Dictionary<string, string> Limits(int daily, int monthly) => new(On) { ["Coach:DailyLimit"] = $"{daily}", ["Plus:FreeMonthlyAi"] = $"{monthly}" };

    /// <summary>The same account signed in on another instance (same database, same signing key).</summary>
    private static Account On2(ApiFactory other, Account a)
    {
        var http = other.CreateClient();
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", a.Auth.AccessToken);
        return new Account(http, a.Auth, a.Password);
    }

    private static async Task ExpireAsync(ApiFactory api, long id)
    {
        await using var db = PostgresFixture.NewDb(api.ConnectionString);
        await db.AiUsage.Where(u => u.Id == id).ExecuteUpdateAsync(x => x.SetProperty(u => u.LeaseUntilUtc, DateTime.UtcNow.AddMinutes(-1)));
    }

    [Fact]
    public async Task Two_instances_share_one_request_at_a_time_and_the_months_allowance()
    {
        var gate = new TaskCompletionSource();
        var fake1 = new FakeAnthropic();
        fake1.Respond = async n => { if (n == 1) await gate.Task; return Message(Structured("Fine.", [])); };
        var fake2 = new FakeAnthropic();
        await using var api1 = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(40, 2), Provider = fake1.Handler() };
        await using var api2 = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(40, 2), Provider = fake2.Handler() };
        var a = await Account.RegisterAsync(api1);
        var a2 = On2(api2, a);

        var first = Post(a, Ask());
        await fake1.Arrived.Task;
        var (busy, body) = await Post(a2, Ask());
        Assert.Equal((HttpStatusCode.TooManyRequests, "COACH_LIMIT", false), (busy, Code(body), body.TryGetProperty("reason", out _)));   // in flight elsewhere
        gate.SetResult();
        Assert.Equal(HttpStatusCode.OK, (await first).Status);

        Assert.Equal(HttpStatusCode.OK, (await Post(a2, Ask())).Status);                   // the month's 2nd, on the other instance
        var (capped, cappedBody) = await Post(a, Ask());
        Assert.Equal((HttpStatusCode.TooManyRequests, "monthly"), (capped, cappedBody.GetProperty("reason").GetString()));
        Assert.Equal((1, 1), (fake1.Calls.Count, fake2.Calls.Count));
        Assert.Equal(2, (await AllowanceOf(a2)).GetProperty("used").GetInt32());
    }

    [Fact]
    public async Task The_daily_guard_counts_attempts_on_every_instance()
    {
        var fake = new FakeAnthropic { Respond = n => Task.FromResult(n == 1 ? new HttpResponseMessage(HttpStatusCode.BadRequest) : Message(Structured("Fine.", []))) };
        await using var api1 = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(2, 15), Provider = fake.Handler() };
        await using var api2 = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(2, 15), Provider = fake.Handler() };
        var a = await Account.RegisterAsync(api1);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await Post(a, Ask())).Status);   // reached the provider, failed: not charged, but an attempt
        Assert.Equal(HttpStatusCode.OK, (await Post(On2(api2, a), Ask())).Status);
        var (status, body) = await Post(a, Ask());
        Assert.Equal((HttpStatusCode.TooManyRequests, false), (status, body.TryGetProperty("reason", out _)));   // the day, not the month
        Assert.Equal(1, (await AllowanceOf(a)).GetProperty("used").GetInt32());
        Assert.Equal(2, fake.Calls.Count);
    }

    [Fact]
    public async Task Concurrent_reservations_from_two_instances_admit_exactly_one()
    {
        await using var api1 = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(40, 15) };
        await using var api2 = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(40, 15) };
        var a = await Account.RegisterAsync(api1);
        var allowances = new[] { api1.Services.GetRequiredService<AiAllowance>(), api2.Services.GetRequiredService<AiAllowance>() };

        var results = await Task.WhenAll(Enumerable.Range(0, 20).Select(i => Task.Run(() => allowances[i % 2].ReserveAsync(a.UserId, "coach", Guid.NewGuid(), default))));
        var admitted = Assert.Single(results, r => r.Status == ReserveStatus.Ok);
        Assert.All(results.Where(r => r.Status != ReserveStatus.Ok), r => Assert.Equal(ReserveStatus.Busy, r.Status));

        // Released (it failed before reaching the provider): nothing consumed, the next one goes at once.
        await allowances[0].FinalizeAsync(admitted.Id, reached: false, counted: false);
        Assert.Equal(ReserveStatus.Ok, (await allowances[1].ReserveAsync(a.UserId, "coach", Guid.NewGuid(), default)).Status);
        await using var db = PostgresFixture.NewDb(api1.ConnectionString);
        Assert.Equal(2, await db.AiUsage.CountAsync(u => u.UserId == a.UserId));               // the 19 refused wrote nothing
        Assert.Equal(0, (await AllowanceOf(a)).GetProperty("used").GetInt32());
    }

    [Fact]
    public async Task A_reservation_left_by_a_dead_instance_blocks_only_until_its_lease_ends_and_never_uses_the_month()
    {
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(2, 1) };
        var a = await Account.RegisterAsync(api);
        var allowance = api.Services.GetRequiredService<AiAllowance>();

        var (_, dead) = await allowance.ReserveAsync(a.UserId, "coach", Guid.NewGuid(), default);   // the instance dies here
        Assert.Equal(ReserveStatus.Busy, (await allowance.ReserveAsync(a.UserId, "coach", Guid.NewGuid(), default)).Status);
        await ExpireAsync(api, dead);

        var (status, next) = await allowance.ReserveAsync(a.UserId, "coach", Guid.NewGuid(), default);
        Assert.Equal(ReserveStatus.Ok, status);                                                // the month's one request is still there
        await allowance.FinalizeAsync(next, reached: true, counted: true);
        Assert.Equal(1, (await AllowanceOf(a)).GetProperty("used").GetInt32());
        // The dead one may have reached the provider: it counts toward the day's attempts, never toward the month.
        Assert.Equal(ReserveStatus.Daily, (await allowance.ReserveAsync(a.UserId, "coach", Guid.NewGuid(), default)).Status);
    }

    [Fact]
    public async Task A_retry_after_a_lost_instance_is_charged_once_even_when_both_finish_and_race()
    {
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Settings = Limits(40, 1) };
        var a = await Account.RegisterAsync(api);
        var allowance = api.Services.GetRequiredService<AiAllowance>();
        var request = Guid.NewGuid();

        // Late finalize: the first instance stalled past its lease, the retry finished, then the first one did too.
        var (_, slow) = await allowance.ReserveAsync(a.UserId, "coach", request, default);
        await ExpireAsync(api, slow);
        var (_, retry) = await allowance.ReserveAsync(a.UserId, "coach", request, default);
        await allowance.FinalizeAsync(retry, reached: true, counted: true);
        await allowance.FinalizeAsync(slow, reached: true, counted: true);
        Assert.Equal(1, (await AllowanceOf(a)).GetProperty("used").GetInt32());
        // The month is used up, yet the same request may still be retried: it can never be charged again.
        Assert.Equal(ReserveStatus.Monthly, (await allowance.ReserveAsync(a.UserId, "coach", Guid.NewGuid(), default)).Status);
        var (again, third) = await allowance.ReserveAsync(a.UserId, "coach", request, default);
        Assert.Equal(ReserveStatus.Ok, again);
        await allowance.FinalizeAsync(third, reached: true, counted: true);

        // Racing finalizes of two live reservations of one request: the unique index lets exactly one charge.
        var b = await Account.RegisterAsync(api);
        var shared = Guid.NewGuid();
        var (_, x) = await allowance.ReserveAsync(b.UserId, "daily", shared, default);
        await ExpireAsync(api, x);
        var (_, y) = await allowance.ReserveAsync(b.UserId, "daily", shared, default);
        await Task.WhenAll(Task.Run(() => allowance.FinalizeAsync(x, true, true)), Task.Run(() => allowance.FinalizeAsync(y, true, true)));

        await using var db = PostgresFixture.NewDb(api.ConnectionString);
        foreach (var (who, id) in new[] { (a.UserId, request), (b.UserId, shared) })
        {
            var states = await db.AiUsage.Where(u => u.UserId == who && u.RequestId == id).Select(u => u.State).ToListAsync();
            Assert.Single(states, s => s == AiUsage.Counted);
            Assert.DoesNotContain(AiUsage.Reserved, states);
        }
        Assert.Equal(1, (await AllowanceOf(a)).GetProperty("used").GetInt32());
    }
}
