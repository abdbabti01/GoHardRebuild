# Weather-aware Today background

An optional, device-only presentation setting: Me > Appearance > Today background = **Scenic** (default),
**Weather** or **Plain**. Only the Today header uses weather. Train and Eat headers use the static `ScenicBackdrop`
(dusk, or the page colour under Plain). Weather never affects the account, sync, readiness or the compatibility gate.

## Provider: Open-Meteo, through the API

Checked 2026-10-13/14 (open-meteo.com/en/docs, /en/docs/geocoding-api, /en/pricing, /en/terms):

- **Terms.** The free API is for **non-commercial use only**, with limits of 600 calls/minute, 5,000/hour,
  10,000/day and 300,000/month, **no uptime guarantee**, data "as is". This TESTING deployment is non-commercial, so
  the free endpoints are used, with no key. Data is CC BY 4.0: the settings page credits
  "Weather data by Open-Meteo.com (CC BY 4.0)". Places come from GeoNames via Open-Meteo's geocoding API.
- **For commercial use** (any paid, subscription or ad-supported release) a commercial plan is required. Then set,
  with no code change: `Weather__ForecastBaseUrl=https://customer-api.open-meteo.com/v1/`,
  `Weather__GeocodingBaseUrl=https://customer-geocoding-api.open-meteo.com/v1/` and the key
  `GOHARD_Weather__ApiKey=<key>` (sent as the documented `apikey` query parameter, server-side only).
- **Schema used.** `GET /v1/forecast?latitude=&longitude=&current=weather_code,is_day,temperature_2m&timezone=auto`.
  `current.time` is wall-clock time **at the place** (ISO without offset, e.g. `2026-10-13T23:15`);
  `utc_offset_seconds` (resolved at request time) turns it into an instant. `current.interval` is 900 s: current
  conditions are 15-minutely **model data**, not an observation. `is_day` is 1/0. Geocoding:
  `GET /v1/search?name=&count=8&language=en&format=json` -> `results[]` with `id`, `name`, `latitude`, `longitude`,
  `admin1`, `country`, `country_code`, `timezone`; no `results` key when nothing matches.
- **Live check, 2026-10-14 03:22 UTC** (three requests by hand with curl):
  Quebec City (46.8, -71.2): `utc_offset_seconds -14400`, `America/Toronto`, `time 2026-10-13T23:15`, code 3
  (Overcast), `is_day 0`, 5.1 °C -> valid 03:15 UTC. Sydney (-33.9, 151.2): `+39600`, `time 2026-10-14T14:15`, code 1,
  `is_day 1` -> the same 03:15 UTC instant. "Paris": Paris/Île-de-France Region/France (2988507), Paris/Texas/United
  States (4717560), then Tennessee, Kentucky... Recorded unchanged as `api/tests/GoHard.Api.Tests/Fixtures/openmeteo_*.json`.

WMO grouping (from the docs' table): 0, 1 clear; 2, 3 cloudy; 45, 48 fog; 51–57, 61–67, 80–82 rain; 71–77, 85, 86
snow; 95, 96, 97, 99 storm. Any other code is **unknown** (no description, never guessed clear). Missing/odd `is_day`
-> `isDay: null`. No offset, an unparseable time, or a time more than 20 min after the server's clock -> no answer
(503 `PROVIDER_UNAVAILABLE`).

## API

Both authenticated, under the per-user `food-data` rate limit (`FoodData:PerUserPerMinute`, default 30):

- `GET /api/v1/weather/current?lat=&lon=` -> `{ family, code, description, isDay, validAtUtc, fetchedAtUtc,
  temperatureC, timezone, latitude, longitude, source: "open-meteo" }` (latitude/longitude are the rounded grid point).
- `GET /api/v1/weather/places?q=` -> `{ results: [{ id, name, admin1, country, countryCode, latitude, longitude, timezone }] }`
  (up to 8, coordinates rounded).
- Errors use the food lookup shape: 422 `INVALID_QUERY`, 429 `PROVIDER_RATE_LIMITED`, 503 `PROVIDER_UNAVAILABLE` /
  `PROVIDER_NOT_CONFIGURED`.
- Capability `weather.current` is declared only while `Weather:Enabled` (default true). Contract version and
  `minimumClientContract` are unchanged; `/health/ready` never looks at weather.

Server behaviour (`Application/Weather/`): coordinates are rounded to **0.1° (~10 km)** before caching, forwarding
or anything else; coordinates and request URLs are never logged (HttpClient and ASP.NET request logging are at
Warning). In-process cache by rounded region (`Weather:CacheMinutes` 20, `Weather:CacheEntries` 2000; places 24 h),
identical requests in flight share one call, a shared budget of `Weather:PerHour` 400 (under the free hourly and
daily limits), `Weather:TimeoutSeconds` 5, one retry for a failure that may pass, a 5-minute pause after the provider
says 429. Config keys: `Weather:Enabled`, `ForecastBaseUrl`, `GeocodingBaseUrl`, `ApiKey`, `UserAgent`,
`TimeoutSeconds`, `CacheMinutes`, `CacheEntries`, `PerHour`.

Recorded responses: `scripts/start-api.ps1 -FoodFixtures` now also points both weather base URLs at
`http://localhost:5132/openmeteo/v1/` and `/openmeteo-geo/v1/`. The fixture server answers every place with the
recorded overcast night (UTC-4), re-dated to the current quarter hour so the app treats it as fresh, and "Paris…"
city searches with the recorded Paris list (anything else: no results). `scripts/verify-api.ps1` checks live current
weather (contract, rounding, age) and a city lookup when the server declares `weather.current`.

## App

`app/lib/features/weather/` (barrel `weather.dart`).

- **Preferences** (`WeatherStore`, platform secure store key `gohard.rebuild.today-background`): background,
  location mode, selected city (id, name, admin1, country, rounded lat/lon). Never in profile.update or the outbox.
  Nothing saved = Scenic, so a fresh install and an upgrade both start on Scenic and a saved choice is never changed.
  `restoreWeatherPrefs(SecretStore)` restores it before the first frame and returns the override for `main.dart`.
- **Device cache** (`gohard.rebuild.weather-cache`): the last answer, with its source (`auto` or `city:<id>`), its
  rounded region and the phone's fetch time. Survives restarts.
- **Freshness policy** (`WeatherPolicy`): when Weather is on, Today appearing, the app resuming or the Today tab
  being selected asks again only if the last fetch for this source is **30 min** old (or another source). Conditions
  are shown only while `validAtUtc` is within **60 min** (and not more than 20 min ahead); beyond that Today shows
  dusk with no weather label. The fetch time never makes old conditions fresh. A failed attempt keeps still-fresh
  data and is not retried for 5 min. Every preference/location change supersedes the request in flight (a token):
  a late answer for an old city or choice is dropped. No timers, polling or per-rebuild work; nothing at all while
  Weather is off (no permission check, no location, no network). App request timeout 10 s.
- **Location.** Automatic uses `LocationAccuracy.low`, one reading with a 10 s limit, or the phone's last known
  position when it is under 30 min old; the result is rounded to the grid before use. It only checks permission by
  itself. The system prompt appears only after the person picks Automatic (or "Use my location") in the settings page
  and reads why. Denied, permanently denied (Open Settings), services off (Location settings) and timeout are quiet
  text with the city option still there; Today keeps dusk. Never background/Always, never starts a run. On Android the
  app manifest already declares fine + coarse location for runs, so the prompt may offer precise; weather asks for
  low accuracy and rounds anyway. iOS `NSLocationWhenInUseUsageDescription` now names both uses.
- **Selected city**: search through the API on submit, disambiguating rows ("Paris" / "Texas, United States"), the
  chosen result's id and rounded coordinates are stored.
- **Scene resolver** (`resolveScene`, pure): preference + cached entry + now + available keys -> `SceneSpec {key,
  isWeather, label, family, isDay}`. Day/night comes only from the provider's `is_day` for that place (a distant
  city's night stays night whatever the phone's clock); missing -> the family's neutral treatment. Unknown family,
  stale, ahead of time, other source/region or missing artwork -> `dusk` with no label.
- **Backdrops.** `TodayBackdrop` (refresh-if-stale triggers + scene), `ScenicBackdrop` (static), `SceneBackdrop(spec)`
  (paints one spec; used by the settings preview). Decoded at the size shown (`cacheWidth`), a light page-coloured veil
  (16–34%, per scene) and a fade into `context.c.page`, crossfade (`Motion.progress`) only when the key changes, instant under reduced motion,
  undecodable photo -> page colour, excluded from semantics. No particles, lightning or looping animation.
- **Contrast.** The header text is drawn in the theme's text colour on TabHeader's own scrim (page colour at 66%,
  behind its lines only). `test/weather_contrast_test.dart` renders the real photograph under every treatment in
  all six looks with that scrim over the band the date, title and greeting occupy, and requires ≥ 7:1 against the
  worst pixel there. Above that band the scene shows with only the veil. (The first version put a 66–87% veil over
  the whole scene and the header scrim on top of it, which hid the scenes; changed on 14 October 2026.)

## Artwork and its limitation

There is **one** photograph: `app/assets/scenes/scenic-dusk.webp`, the package's generated northern-lake dusk
(1536 × 1024, copied unchanged; sha256 `8f2fcd85bce39c8004c9063c6d43e72c5f8f7b70d9e426c4b6c716a58c54f4be` matches the package manifest). It is decorative, generated
(built-in image tool, 2026-10-13), shows no UI or text and does not depict the user's location.

**The condition scenes are original artwork built on that one photograph** (no image-generation tool, no third-party
photos), so every scene keeps the same lake, hills, trees and camera; only the sky, light and weather change.
`scene_art.dart` maps each key (`<family>-day|night|neutral`) to a landscape grade and a painted `Sky`;
`sky_painter.dart` paints it in three static layers around the photograph (`backdrop.dart`):

1. **Back:** the painted sky (zenith-to-horizon gradient, then the lake as its reflection), sun glow, moon and stars,
   soft cloud masses (blurred ovals: lit tops over darker undersides).
2. **The photograph**, graded by a colour matrix whose alpha follows luminance (`silhouette()`): dark hills and trees
   stay opaque, the bright dusk sky and its reflection in the lake turn see-through, so the painted sky shows behind
   the silhouettes. (The alpha's constant term scales with source alpha: a fixed offset would make the unbounded
   colour-filter layer paint over the whole page; `weather_distinct_test` guards this.)
3. **Top:** the same sky over the upper part of the photograph (where its dusk sky is too dark to let through), faded
   out above the ridge. **Front:** mist bands at the horizon, layered fog banks, a pale snow lift over shore and lake,
   fine diagonal rain streaks, small snow dots.

| Family | Day | Night |
|---|---|---|
| clear | clean blue, soft sun glow high right | deep navy, ~90 faint stars, a waxing moon |
| cloudy | layered light-grey masses over the whole sky | lit slate masses |
| rain | low dark blue-grey cloud, streaks, misty horizon, desaturated | dark blue-green, streaks, mist |
| snow | pale cool overcast, whitened shore/lake, small flakes | blue-grey, pale ground, flakes |
| fog | warm grey banks hiding the far hills, very low contrast | dark warm grey banks |
| storm | very dark slate, heavy cloud, heavier rain (no lightning) | near black, heavy cloud, rain |

Neutral (the provider did not say day or night) is the day sky moved 45% toward night, without sun, moon or stars.
Dusk and Plain are unchanged. Everything is static: fixed random seeds, painted once inside a RepaintBoundary,
`shouldRepaint` only when the sky changes, no animation, particles or flashing; the existing crossfade on key change
(instant under reduced motion) is the only motion. The photograph stays decoded at display size (`cacheWidth`).
The veil is per scene: Light mode lifts the painted weather skies less than the dusk photograph (0.16 day, 0.22
night/rain/storm, dusk keeps 0.34) so night does not turn grey; Dark mode is unchanged.

**Measured, not asserted.** `test/weather_distinct_test.dart` renders every key at header size (390 x 280) in Light
and Dark and compares each pair of families in the same light, day vs night of each family, and each scene vs dusk
by mean per-pixel colour difference and an 8x8x8 colour histogram distance. Smallest values: per-pixel 0.034 (fog
vs snow by day, Dark) and histogram 0.19 (same pair); thresholds 0.03 / 0.15. The lower header fades into the page,
so per-pixel figures are diluted roughly by half. Contact sheets: `docs/evidence/design/state-weather-scenes-light.png`
and `-dark.png`; Today over all 12 family/light scenes: `state-today-weather-*`.

**Remaining limitation:** these are painted treatments of one dusk photograph, not separately photographed scenes.
Fog vs snow by day, and the night skies of clear / cloudy / rain / storm, are the closest pairs (told apart by
stars and moon, colour cast and streaks rather than by overall brightness). A proper art pack would replace
entries in the same key -> art table without touching the resolver or screens.

## Not verified here

On the Android emulator (`journey_more_test`, recorded provider answers): Weather chosen for a selected city in the
middle of an open workout, "Paris" listed as France / Texas / Tennessee / Kentucky / Illinois, the chosen one
stored, Today showing the overcast-night scene with the workout untouched, and the settings page saying "Overcast"
with its time and place (`docs/evidence/screenshots/62b-…`, `62c-…`, `62d-…`).

**Not verified:** the Automatic location path on a device (the OS permission prompt, denial, a real coarse fix);
real local weather accuracy (a scene in tests or an emulator does not prove it); low-brightness comfort and device
performance. These need a physical phone.
