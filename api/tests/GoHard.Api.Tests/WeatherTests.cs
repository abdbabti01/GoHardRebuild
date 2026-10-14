using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using GoHard.Api.Application.FoodDiscovery;
using GoHard.Api.Application.Weather;
using Microsoft.Extensions.Logging.Abstractions;

namespace GoHard.Api.Tests;

/// <summary>Normalization of recorded Open-Meteo answers and the weather service's grid, cache and failures.</summary>
public class WeatherProviderTests
{
    private static readonly DateTime Fetched = new(2026, 10, 14, 3, 22, 0, DateTimeKind.Utc);
    private static JsonElement Recorded(string name) => JsonDocument.Parse(StubProvider.Recorded(name)).RootElement;

    /// <summary>The recorded night answer with its current block replaced.</summary>
    private static WeatherNow? With(string current, int offset = -14400, DateTime? fetched = null) => OpenMeteoProvider.ParseCurrent(JsonDocument.Parse(
        $$"""{"utc_offset_seconds":{{offset}},"timezone":"America/Toronto","current":{{current}}}""").RootElement, 46.8, -71.2, fetched ?? Fetched);

    [Fact]
    public void Recorded_answers_normalize_with_local_time_turned_into_an_instant()
    {
        var night = OpenMeteoProvider.ParseCurrent(Recorded("openmeteo_current_overcast_night.json"), 46.8, -71.2, Fetched)!;
        Assert.Equal(("cloudy", 3, "Overcast", false, "America/Toronto", "open-meteo", 5.1m), (night.Family, night.Code, night.Description, night.IsDay, night.Timezone, night.Source, night.TemperatureC));
        Assert.Equal(new DateTime(2026, 10, 14, 3, 15, 0, DateTimeKind.Utc), night.ValidAtUtc);    // 23:15 at UTC-4
        Assert.Equal(DateTimeKind.Utc, night.ValidAtUtc.Kind);

        var day = OpenMeteoProvider.ParseCurrent(Recorded("openmeteo_current_clear_day.json"), -33.9, 151.2, Fetched)!;
        Assert.Equal(("clear", "Mainly clear", true), (day.Family, day.Description, day.IsDay));
        Assert.Equal(night.ValidAtUtc, day.ValidAtUtc);                                        // 14:15 at UTC+11 is the same instant
    }

    [Theory]
    [InlineData(0, "clear")] [InlineData(1, "clear")] [InlineData(2, "cloudy")] [InlineData(3, "cloudy")]
    [InlineData(45, "fog")] [InlineData(48, "fog")]
    [InlineData(51, "rain")] [InlineData(57, "rain")] [InlineData(61, "rain")] [InlineData(67, "rain")] [InlineData(80, "rain")] [InlineData(82, "rain")]
    [InlineData(71, "snow")] [InlineData(77, "snow")] [InlineData(85, "snow")] [InlineData(86, "snow")]
    [InlineData(95, "storm")] [InlineData(96, "storm")] [InlineData(99, "storm")]
    [InlineData(4, "unknown")] [InlineData(100, "unknown")] [InlineData(-1, "unknown")]
    public void Every_documented_code_has_its_family_and_any_other_is_unknown(int code, string family)
    {
        var now = With($$"""{"time":"2026-10-13T23:15","weather_code":{{code}},"is_day":1}""")!;
        Assert.Equal(family, now.Family);
        if (family == "unknown") Assert.Null(now.Description);                                // no wording is invented
    }

    [Fact]
    public void Missing_values_stay_missing_and_bad_times_are_rejected()
    {
        var bare = With("""{"time":"2026-10-13T23:15"}""")!;
        Assert.Equal(("unknown", null, null, null), (bare.Family, bare.Code, bare.IsDay, bare.TemperatureC));   // not guessed clear or day
        Assert.Null(With("""{"time":"2026-10-13T23:15","weather_code":0,"is_day":2}""")!.IsDay);
        Assert.Null(With("""{"time":"2026-10-14T01:15","weather_code":0,"is_day":1}"""));      // 05:15 UTC: two hours ahead of the fetch
        Assert.NotNull(With("""{"time":"2026-10-13T23:30","weather_code":0,"is_day":1}"""));   // a model step ahead is normal
        Assert.Null(With("""{"time":"yesterday","weather_code":0}"""));
        Assert.Null(With("""{"weather_code":0}"""));
        Assert.Null(With("""{"time":"2026-10-13T23:15","weather_code":0}""", offset: 99999));
        Assert.Null(OpenMeteoProvider.ParseCurrent(JsonDocument.Parse("""{"current":{"time":"2026-10-13T23:15"}}""").RootElement, 0, 0, Fetched));  // no offset: no instant
    }

    [Fact]
    public void Places_keep_identity_and_enough_to_tell_namesakes_apart_on_a_coarse_grid()
    {
        var places = OpenMeteoProvider.ParsePlaces(Recorded("openmeteo_places_paris.json"));
        Assert.True(places.Count >= 3);
        Assert.Equal(new WeatherPlace("2988507", "Paris", "Île-de-France Region", "France", "FR", 48.9, 2.3, "Europe/Paris"), places[0]);
        Assert.Equal(("4717560", "Texas", "United States", 33.7, -95.6), (places[1].Id, places[1].Admin1, places[1].Country, places[1].Latitude, places[1].Longitude));
        Assert.Empty(OpenMeteoProvider.ParsePlaces(Recorded("openmeteo_places_empty.json")));
    }

    [Theory]
    [InlineData(46.81234, -71.21567, 46.8, -71.2)]
    [InlineData(46.85, -71.25, 46.9, -71.3)]
    [InlineData(-0.04, 0.04, 0.0, 0.0)]
    [InlineData(90, 180, 90.0, 180.0)]
    public void Coordinates_are_reduced_to_a_tenth_of_a_degree(double lat, double lon, double rlat, double rlon) =>
        Assert.Equal((rlat, rlon), WeatherService.Round(lat, lon));

    [Fact]
    public void Impossible_coordinates_are_not_a_place() =>
        Assert.All(new[] { (91.0, 0.0), (0.0, 181.0), (double.NaN, 0.0), (0.0, double.PositiveInfinity) }, p => Assert.Null(WeatherService.Round(p.Item1, p.Item2)));

    private static (WeatherService Service, StubProvider Stub) Service(Func<HttpRequestMessage, Task<HttpResponseMessage>>? respond = null, Action<WeatherOptions>? configure = null)
    {
        var options = new WeatherOptions { TimeoutSeconds = 1, MetNorwayBaseUrl = "" };   // no fallback unless a test asks for it
        configure?.Invoke(options);
        var stub = new StubProvider(respond ?? (r => Task.FromResult(StubProvider.Json(StubProvider.Recorded(
            r.RequestUri!.AbsolutePath.EndsWith("/search") ? "openmeteo_places_paris.json" : "openmeteo_current_overcast_night.json")))));
        var http = new HttpClient(stub);
        // MET Norway reads the hour from a clock fixed in the hour its recording covers (14:30 UTC, 14 October 2026).
        var metClock = new FixedTime(new DateTimeOffset(2026, 10, 14, 14, 30, 0, TimeSpan.Zero));
        return (new WeatherService(new OpenMeteoProvider(http, options), new MetNorwayProvider(http, options, metClock), options, NullLogger<WeatherService>.Instance), stub);
    }

    // The diagnosed cause of "wrong weather" on the phone: from the hosted server Open-Meteo answered 429 for every
    // place (its free tier limits per calling IP, and the cloud host's outbound IP is shared), so the app got no
    // weather. MET Norway now answers the same question, and says it did.
    [Fact]
    public async Task When_Open_Meteo_refuses_MET_Norway_answers_and_says_so()
    {
        var (service, stub) = Service(r => Task.FromResult(r.RequestUri!.Host == "api.met.no"
            ? StubProvider.Json(StubProvider.Recorded("metno_quebec_cloudy.json"))
            : new HttpResponseMessage(HttpStatusCode.TooManyRequests)), o => o.MetNorwayBaseUrl = "https://api.met.no/weatherapi/");
        var now = await service.CurrentAsync(46.81, -71.21, default);
        Assert.Equal(LookupStatus.Ok, now.Status);
        Assert.Equal(("met.no", "cloudy", 3), (now.Value!.Source, now.Value.Family, now.Value.Code));
        var met = stub.Requests.Single(r => r.RequestUri!.Host == "api.met.no").RequestUri!;
        Assert.Equal("?lat=46.8&lon=-71.2", met.Query);                                          // only the grid point travels
        Assert.Equal(2, stub.Requests.Count);

        await service.CurrentAsync(46.8, -71.2, default);                                         // remembered, whoever answered
        Assert.Equal(2, stub.Requests.Count);
        await service.CurrentAsync(48.85, 2.35, default);                                         // Open-Meteo is paused: straight to MET
        Assert.Equal(["api.open-meteo.com", "api.met.no", "api.met.no"], stub.Requests.Select(r => r.RequestUri!.Host));
    }

    // MET Norway's terms: no repeat request before Expires, then a conditional request (If-Modified-Since = the
    // last Last-Modified); a 304 reuses the kept answer.
    [Fact]
    public async Task MET_Norway_is_not_asked_again_before_Expires_and_then_only_conditionally()
    {
        var clock = new MovingTime(new DateTimeOffset(2026, 10, 14, 14, 30, 0, TimeSpan.Zero));
        var lastModified = new DateTimeOffset(2026, 10, 14, 14, 30, 12, TimeSpan.Zero);
        var sent = new List<(string Host, DateTimeOffset? Since)>();
        var stub = new StubProvider(r =>
        {
            sent.Add((r.RequestUri!.Query, r.Headers.IfModifiedSince));
            if (r.Headers.IfModifiedSince is not null) return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotModified) { Content = new ByteArrayContent([]) });
            var ok = StubProvider.Json(StubProvider.Recorded("metno_quebec_cloudy.json"));
            ok.Content.Headers.Expires = clock.GetUtcNow() + TimeSpan.FromMinutes(31);
            ok.Content.Headers.LastModified = lastModified;
            return Task.FromResult(ok);
        });
        var met = new MetNorwayProvider(new HttpClient(stub), new WeatherOptions(), clock);

        Assert.Equal(3, (await met.CurrentAsync(46.8, -71.2, default)).Value!.Code);   // 14:00 hour: cloudy
        clock.Advance(TimeSpan.FromMinutes(20));
        Assert.Equal(LookupStatus.Ok, (await met.CurrentAsync(46.8, -71.2, default)).Status);
        Assert.Single(sent);                                                          // before Expires: nothing sent

        clock.Advance(TimeSpan.FromMinutes(15));                                     // 15:05, past Expires
        var again = await met.CurrentAsync(46.8, -71.2, default);
        Assert.Equal(2, sent.Count);
        Assert.Equal(lastModified, sent[1].Since);                                   // conditional, with the last Last-Modified
        Assert.Equal((LookupStatus.Ok, 61, new DateTime(2026, 10, 14, 15, 0, 0, DateTimeKind.Utc)),
            (again.Status, again.Value!.Code, again.Value.ValidAtUtc));               // 304: the kept answer, read at the new hour

        await met.CurrentAsync(48.9, 2.3, default);                                  // another place is its own, plain request
        Assert.Equal(3, sent.Count);
        Assert.Null(sent[2].Since);
    }

    [Fact]
    public async Task MET_Norway_is_only_asked_when_Open_Meteo_fails_and_a_double_failure_says_what_Open_Meteo_said()
    {
        var (fine, f) = Service(configure: o => o.MetNorwayBaseUrl = "https://api.met.no/weatherapi/");
        Assert.Equal("open-meteo", (await fine.CurrentAsync(46.8, -71.2, default)).Value!.Source);
        Assert.DoesNotContain(f.Requests, r => r.RequestUri!.Host == "api.met.no");

        var (both, _) = Service(r => Task.FromResult(new HttpResponseMessage(r.RequestUri!.Host == "api.met.no" ? HttpStatusCode.BadGateway : HttpStatusCode.TooManyRequests)),
            o => o.MetNorwayBaseUrl = "https://api.met.no/weatherapi/");
        Assert.Equal(LookupStatus.RateLimited, (await both.CurrentAsync(46.8, -71.2, default)).Status);
    }

    [Fact]
    public void MET_Norway_current_hour_maps_to_the_same_codes_with_day_or_night_from_the_symbol_or_the_sun()
    {
        var now = MetNorwayProvider.ParseCurrent(Recorded("metno_quebec_cloudy.json"), 46.8, -71.2, new DateTime(2026, 10, 14, 14, 30, 0, DateTimeKind.Utc))!;
        Assert.Equal((new DateTime(2026, 10, 14, 14, 0, 0, DateTimeKind.Utc), 3, "Cloudy", "cloudy", true, 5.8m),
            (now.ValidAtUtc, now.Code, now.Description, now.Family, now.IsDay, now.TemperatureC));   // "cloudy" has no suffix: 10:00 at the place, the sun is up
        Assert.Equal((2, "Partly cloudy"), MetNorwayProvider.Map("partlycloudy_day"));
        Assert.Equal((0, "Clear sky"), MetNorwayProvider.Map("clearsky_night"));
        Assert.Equal((80, "Light rain showers"), MetNorwayProvider.Map("lightrainshowers_day"));
        Assert.Equal(95, MetNorwayProvider.Map("lightrainshowersandthunder_night").Code);
        Assert.Equal((85, "Snow showers"), MetNorwayProvider.Map("snowshowers_polartwilight"));
        Assert.Equal((null, null), MetNorwayProvider.Map("hailstorm"));
    }

    [Theory]
    [InlineData(46.8, -71.2, 2026, 10, 14, 16, 0, true)]    // Quebec City at local noon
    [InlineData(46.8, -71.2, 2026, 10, 14, 4, 0, false)]    // ...and at local midnight
    [InlineData(-33.9, 151.2, 2026, 10, 14, 3, 20, true)]   // Sydney mid-afternoon, at an hour that is night in Paris
    [InlineData(48.9, 2.3, 2026, 10, 14, 3, 20, false)]
    [InlineData(78.2, 15.6, 2026, 12, 21, 12, 0, false)]    // Svalbard in polar night, even at noon
    public void The_sun_says_day_or_night_for_the_place_not_the_server_clock(double lat, double lon, int y, int mo, int d, int h, int mi, bool day) =>
        Assert.Equal(day, Sun.IsDay(lat, lon, new DateTime(y, mo, d, h, mi, 0, DateTimeKind.Utc)));

    [Fact]
    public async Task Nearby_requests_share_one_rounded_provider_call_and_the_answer_is_remembered()
    {
        var gate = new TaskCompletionSource();
        var (service, stub) = Service(async _ => { await gate.Task; return StubProvider.Json(StubProvider.Recorded("openmeteo_current_overcast_night.json")); });
        var waiting = new[] { (46.81, -71.21), (46.79, -71.18), (46.8123, -71.2049) }.Select(p => service.CurrentAsync(p.Item1, p.Item2, default)).ToList();
        gate.SetResult();
        Assert.All(await Task.WhenAll(waiting), r => Assert.Equal("cloudy", r.Value!.Family));
        var sent = Assert.Single(stub.Requests).RequestUri!;
        Assert.Contains("latitude=46.8&longitude=-71.2&current=weather_code,is_day,temperature_2m&timezone=auto", sent.Query);   // only the grid point travels
        Assert.DoesNotContain("apikey", sent.Query);
        Assert.Equal("api.open-meteo.com", sent.Host);
        await service.CurrentAsync(46.8, -71.2, default);
        Assert.Single(stub.Requests);
        await service.CurrentAsync(48.85, 2.35, default);
        Assert.Equal(2, stub.Requests.Count);                                                  // another region is another call
    }

    [Fact]
    public async Task Provider_trouble_is_unavailable_retried_once_and_never_remembered()
    {
        var (down, stub) = Service(_ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.BadGateway)));
        Assert.Equal(LookupStatus.Unavailable, (await down.CurrentAsync(46.8, -71.2, default)).Status);
        Assert.Equal(2, stub.Requests.Count);
        await down.CurrentAsync(46.8, -71.2, default);
        Assert.Equal(4, stub.Requests.Count);

        var (future, _) = Service(_ => Task.FromResult(StubProvider.Json("""{"utc_offset_seconds":0,"current":{"time":"2099-01-01T00:00","weather_code":0,"is_day":1}}""")));
        Assert.Equal(LookupStatus.Unavailable, (await future.CurrentAsync(46.8, -71.2, default)).Status);   // never a "current" answer from the future

        var (slow, _) = Service(async _ => { await Task.Delay(TimeSpan.FromSeconds(30)); return StubProvider.Json("{}"); });
        Assert.Equal(LookupStatus.Unavailable, (await slow.CurrentAsync(46.8, -71.2, default)).Status);

        var (limited, l) = Service(_ => Task.FromResult(new HttpResponseMessage(HttpStatusCode.TooManyRequests)));
        Assert.Equal(LookupStatus.RateLimited, (await limited.CurrentAsync(46.8, -71.2, default)).Status);
        Assert.Equal(LookupStatus.RateLimited, (await limited.PlacesAsync("Paris", default)).Status);
        Assert.Single(l.Requests);                                                             // paused, not hammered

        var (budgeted, b) = Service(configure: o => o.PerHour = 1);
        await budgeted.CurrentAsync(1, 1, default);
        Assert.Equal(LookupStatus.RateLimited, (await budgeted.CurrentAsync(2, 2, default)).Status);
        Assert.Single(b.Requests);
    }

    [Fact]
    public async Task Bad_input_and_a_disabled_server_never_reach_the_provider_and_a_commercial_key_goes_to_the_configured_host()
    {
        var (service, stub) = Service();
        Assert.Equal(LookupStatus.Invalid, (await service.CurrentAsync(null, 2, default)).Status);
        Assert.Equal(LookupStatus.Invalid, (await service.CurrentAsync(95, 2, default)).Status);
        Assert.Equal(LookupStatus.Invalid, (await service.PlacesAsync(" a ", default)).Status);
        Assert.Empty(stub.Requests);

        var (off, none) = Service(configure: o => o.Enabled = false);
        Assert.Equal(LookupStatus.NotConfigured, (await off.CurrentAsync(46.8, -71.2, default)).Status);
        Assert.Equal(LookupStatus.NotConfigured, (await off.PlacesAsync("Paris", default)).Status);
        Assert.Empty(none.Requests);

        var (paid, p) = Service(configure: o => (o.ApiKey, o.ForecastBaseUrl, o.GeocodingBaseUrl) = ("k&1", "https://customer-api.open-meteo.com/v1/", "https://customer-geocoding-api.open-meteo.com/v1/"));
        await paid.CurrentAsync(46.8, -71.2, default);
        var found = await paid.PlacesAsync("  Paris ", default);
        Assert.Equal(("customer-api.open-meteo.com", "customer-geocoding-api.open-meteo.com"), (p.Requests[0].RequestUri!.Host, p.Requests[1].RequestUri!.Host));
        Assert.All(p.Requests, r => Assert.EndsWith("&apikey=k%261", r.RequestUri!.Query));
        Assert.Contains("name=Paris&count=8", p.Requests[1].RequestUri!.Query);
        Assert.Equal("2988507", found.Value![0].Id);
    }
}

/// <summary>The weather endpoints on the real host: optional, signed-in only, and unable to harm anything else.</summary>
[Collection("api")]
public class WeatherEndpointTests(PostgresFixture pg)
{
    private static StubProvider Recordings(HttpStatusCode weatherStatus = HttpStatusCode.OK) => new(r => Task.FromResult(
        r.RequestUri!.Host.Contains("open-meteo") is false ? StubProvider.Json(StubProvider.Recorded("off_product_100g.json"))
        : weatherStatus != HttpStatusCode.OK ? new HttpResponseMessage(weatherStatus)
        : StubProvider.Json(StubProvider.Recorded(r.RequestUri.AbsolutePath.EndsWith("/search") ? "openmeteo_places_paris.json" : "openmeteo_current_overcast_night.json"))));

    private static async Task<(HttpStatusCode, JsonElement)> Get(HttpClient http, string path)
    {
        var r = await http.GetAsync("/api/v1" + path);
        return (r.StatusCode, await r.Content.ReadFromJsonAsync<JsonElement>());
    }

    private static List<string?> Declared(JsonElement c) => c.GetProperty("capabilities").EnumerateArray().Select(x => x.GetString()).ToList();

    [Fact]
    public async Task Current_conditions_and_places_come_back_in_the_small_contract()
    {
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Provider = Recordings() };
        Assert.Equal(HttpStatusCode.Unauthorized, (await api.CreateClient().GetAsync("/api/v1/weather/current?lat=46.8&lon=-71.2")).StatusCode);
        var a = await Account.RegisterAsync(api);
        var (status, now) = await Get(a.Http, "/weather/current?lat=46.81234&lon=-71.21567");
        Assert.Equal(HttpStatusCode.OK, status);
        // The recorded answer is from 2026-10-14; validAtUtc is what the provider said, fetchedAtUtc is when this server asked.
        var expected = JsonNode.Parse("""{"family":"cloudy","code":3,"description":"Overcast","isDay":false,"validAtUtc":"2026-10-14T03:15:00Z","temperatureC":5.1,"timezone":"America/Toronto","latitude":46.8,"longitude":-71.2,"source":"open-meteo"}""")!.AsObject();
        var actual = JsonNode.Parse(now.GetRawText())!.AsObject();
        Assert.True(actual.Remove("fetchedAtUtc"));
        Assert.True(JsonNode.DeepEquals(expected, actual), actual.ToJsonString());

        var (_, places) = await Get(a.Http, "/weather/places?q=Paris");
        var first = places.GetProperty("results")[0];
        Assert.Equal(("2988507", "Paris", "Île-de-France Region", "France", 48.9), (first.GetProperty("id").GetString(), first.GetProperty("name").GetString(),
            first.GetProperty("admin1").GetString(), first.GetProperty("country").GetString(), first.GetProperty("latitude").GetDouble()));

        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await Get(a.Http, "/weather/current?lat=91&lon=0")).Item1);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await Get(a.Http, "/weather/places?q=x")).Item1);
        Assert.Contains(WeatherRegistration.Capability, Declared(await a.Http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities")));
    }

    [Fact]
    public async Task A_weather_outage_leaves_readiness_capabilities_and_the_account_alone()
    {
        await using var api = new ApiFactory(pg.Api.ConnectionString) { Provider = Recordings(HttpStatusCode.ServiceUnavailable) };
        var a = await Account.RegisterAsync(api);
        var (status, body) = await Get(a.Http, "/weather/current?lat=46.8&lon=-71.2");
        Assert.Equal((HttpStatusCode.ServiceUnavailable, "PROVIDER_UNAVAILABLE"), (status, body.GetProperty("code").GetString()));
        Assert.Equal(HttpStatusCode.OK, (await api.CreateClient().GetAsync("/health/ready")).StatusCode);
        var capabilities = await a.Http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities");
        Assert.Equal((1, 1), (capabilities.GetProperty("contractVersion").GetInt32(), capabilities.GetProperty("minimumClientContract").GetInt32()));
        Assert.Equal(HttpStatusCode.OK, (await a.Http.GetAsync("/api/v1/sync/snapshot")).StatusCode);

        await using var disabled = new ApiFactory(pg.Api.ConnectionString) { Settings = new() { ["Weather:Enabled"] = "false" }, Provider = Recordings() };
        var b = await Account.RegisterAsync(disabled);
        Assert.DoesNotContain(WeatherRegistration.Capability, Declared(await b.Http.GetFromJsonAsync<JsonElement>("/api/v1/capabilities")));
        Assert.Equal("PROVIDER_NOT_CONFIGURED", (await Get(b.Http, "/weather/places?q=Paris")).Item2.GetProperty("code").GetString());
        Assert.Equal(HttpStatusCode.OK, (await disabled.CreateClient().GetAsync("/health/ready")).StatusCode);
    }
}

/// A clock that always says the same instant.
file sealed class FixedTime(DateTimeOffset at) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => at;
}

/// A clock a test moves forward.
file sealed class MovingTime(DateTimeOffset start) : TimeProvider
{
    private DateTimeOffset _now = start;
    public override DateTimeOffset GetUtcNow() => _now;
    public void Advance(TimeSpan by) => _now += by;
}
