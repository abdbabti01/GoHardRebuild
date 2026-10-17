# Run / Walk

Outdoor Run and Walk recording with a durable GPS route, one metric pipeline, background recording, route sync and
GPX export. The approved look is "Focus Dial" (`GoHard_Run_Walk_Focus_Dial/references/approved-focus-dial.png`,
17 Oct 2026): Ready → Recording (Stats / Map) → Saved. The board's routes, numbers, dates and accuracy are
illustrative; every value on screen comes from the device or from stored data.

Out of scope (not built, not promised): public feeds, leaderboards, competitive segments, route planning or
navigation, Strava, wearables and health platforms, heart rate, steps, cadence, VO2 max, calories, personal records,
offline map downloads, snapping to roads.

## Code map

| Concern | Where |
|---|---|
| Metric pipeline (pure, shared by live display, details, history, export) | `app/lib/features/activity/track_math.dart` |
| Route storage (append-only entries, owner-scoped) | `app/lib/data/db.dart` (`TrackEntries`, schema v3), `features/activity/track_store.dart` |
| Location acquisition (the one GPS stream, permissions, platform settings) | `features/activity/location_source.dart` |
| Recorder (owns the active activity, state machine, checkpoints, auto-pause) | `features/activity/recorder.dart` |
| Summary/route sync, edit, delete, GPX | `features/activity/activity_repository.dart`, `features/activity/gpx.dart` |
| Map presentation (Google Maps, or a drawn route when the map is unavailable) | `features/activity/route_map.dart` |
| Screens: Ready, Recording, Save review, Saved details, History | `features/activity/run_walk_screens.dart`, `activity_detail.dart`, `activity_history.dart` |
| API | `Persistence/Entities.cs` (`Run`, `RouteChunk`), `Application/JournalServices.cs` (`ActivityService`), `Endpoints.cs`, migration `AddRunRoutes` |
| Native | Android `MainActivity.kt` (channel `gohard/maps`), `build.gradle.kts` (key placeholder), manifest; iOS `AppDelegate.swift`, `Info.plist`, `Podfile`, `Flutter/*.xcconfig` |
| Tests | `test/track_math_test.dart` (GPS fixtures), `test/run_walk_recorder_test.dart` (recorder + sync on a real database), `test/run_walk_ui_test.dart`, `api/tests/.../RunRouteTests.cs`, `integration_test/journey_runwalk_test.dart` |

## Activity record

The existing `run` record (kind `run`, `/runs`) is the activity, Run or Walk; there is no second table. Additive fields:

| Field | Meaning |
|---|---|
| `activityType` | `run` or `walk`. Chosen before Start, kept through restart, sync, history and export. Never changed automatically (slowing down does not turn a run into a walk); only the person's edit changes it. Missing = `run` (every older record was a run). |
| `title`, `notes` | Editable. Title defaults to "Morning/Afternoon/Evening/Night run/walk" from the local start time. |
| `activeDurationSeconds` | Active time (unchanged meaning, see Metrics). |
| `distanceMeters` | The distance the activity reports: GPS-measured, or the person's correction, or typed (manual). |
| `metrics` | Derived summary for lists and other devices, recomputable from the route: `elapsedSeconds`, `movingSeconds`, `gpsDistanceMeters`, `elevationGainMeters`, `elevationLossMeters`, `distanceSource` (`gps` · `corrected` · `manual` · `none`), `routeState` (`none` · `recorded` · `partial`), `pointCount`, `gaps`, `interrupted`. |

Legacy records (no `activityType`, no `metrics`) keep their real time and distance, show as Run and say
**Route not recorded**. Nothing is fabricated for them.

## Recording state machine

```
           Start (Run|Walk)                         Pause / auto-pause
 Ready ───────────────────────► Recording ◄──────────────────────────► Paused
   ▲                              │   ▲                                   │
   │                       app/process stops                              │
   │                              ▼   │ Resume (new segment)              │
   │                          Interrupted ───────────────────────────────┤
   │                                                                      │
   │              Finish (from Recording, Paused or Interrupted)          │
   └──── Saved ◄── Save review (title, notes, distance) ◄─────────────────┘
                     │ Discard (confirmed): activity deleted, route erased
                     └ Back: recording continues where it was
```

* **One recorder per device.** `RecorderController` (app lifetime, not a widget) owns the open activity, the GPS
  stream and the clock. Start while an activity is open resumes it instead of creating another.
* **Active vs saved open record.** The recorder knows whether it is live in this process. An open activity whose
  recorder is not live (the app was closed, the process was killed, the phone restarted) is **Interrupted**: the
  clock was frozen at the last checkpoint, the stretch since then is a gap, and the screen offers Resume or Finish.
  Recording after a force-quit is never promised.
* **Pause** freezes the clock, ends the segment and stores a `pause` event; GPS stays on so the map keeps showing
  the position. **Resume** stores `resume` and starts a new segment. Auto-pause/auto-resume store `autopause` /
  `autoresume` so they are distinguishable.
* **Finish** stops counting time (a `finish` event) and opens the save review. Save commits locally first, then
  stops location, then shows success. A failed save keeps everything and stays on the review.
* **Discard** asks first, deletes the activity (sync `run.delete`), erases its route and stops location.
* Opening a saved activity never starts location.

## Route format (local)

Table `track_entries`, one row per stored entry, primary key `(owner_id, activity_id, seq)`:

| Column | |
|---|---|
| `seq` | 0,1,2… per activity, strictly increasing, assigned by the recorder. Stable identity for sync. |
| `type` | `fix`, `start`, `pause`, `resume`, `autopause`, `autoresume`, `gap`, `finish`, `legacy` |
| `segment` | Segment index; a new segment starts after every pause, gap or interruption. |
| `t` | UTC epoch milliseconds (fix time from the device for fixes, wall clock for events). |
| `lat`, `lon`, `acc` | Degrees WGS84; horizontal accuracy in metres. |
| `alt`, `altAcc` | Metres; vertical accuracy (null when the device gives none). |
| `speed`, `speedAcc`, `heading` | As measured by the device; null when not provided. Kept for analysis, not trusted for distance. |

Every received fix is stored, including ones the pipeline later rejects: the pipeline is a pure function of the
stored entries, so the route and every number can be reproduced. Rows are written one at a time, in order, each in
its own transaction, before the screen uses the value; a write failure is shown ("Not saving GPS on this phone")
and the recorder keeps the unwritten entries in order and retries them before the next one. Memory is bounded by
distance, not time: the live analysis keeps a running accumulator and only the counted points (at least 4 m apart, so
about 2,500 for 10 km), never every fix; standing still adds none. History thumbnails use at most ~80 points.

An open run found after upgrading from the build without routes keeps its identity, start time, clock and the
distance it had measured; a `legacy` entry records that measured distance, the earlier part is shown as
"Recorded before routes were kept", and a new segment begins.

## Metrics (one pipeline)

`TrackAnalysis` folds the entries in `seq` order. Live display, the save review, details, history, GPX and tests all
use it. Canonical units: metres, seconds, UTC.

**Fix acceptance.** A fix is accepted when it is (a) inside a recording segment (not paused), (b) `acc ≤ 30 m`,
(c) later than the previous accepted fix (duplicates and out-of-order times are rejected), and (d) not an impossible
jump: implied speed from the previous accepted fix ≤ 12.5 m/s (45 km/h). Rejected fixes stay stored and are counted
as "rejected" in recording quality. When three fixes in a row are "impossible" from the last accepted one but
plausible among themselves, the last accepted one was the outlier (typically a bad first fix): the segment restarts
from them and they are accepted.

**Gaps.** Two accepted fixes more than 30 s apart, a pause, an auto-pause, or an interruption end the segment. No
distance is ever added across a segment boundary, no chart line is drawn through one, and the map draws each segment
as its own line.

**Distance (drift-resistant).** Positions are first smoothed: the mean of the last three accepted fixes of the
segment. The pipeline keeps an anchor (the last counted point). A smoothed position is counted when its distance from
the anchor is at least `max(4 m, 1.5 × max(anchor accuracy, fix accuracy))`, and, when the receiver reports its own
(Doppler) speed, that speed is at least 0.3 m/s; it then becomes the anchor. Standing still therefore adds (almost)
nothing, while slow walking still counts in full: the distance from the anchor grows until it crosses the threshold
and is then added whole. The recorder stores a speed only when the device reports its accuracy (Android reports 0.0
for "no speed"), so a missing speed never reads as "standing". Measured on the synthetic fixtures: 10 minutes standing
with ±6 m noise adds < 15 m with reported speed and < 120 m without it; 0.8 m/s walking is within 10 %; a steady run
within 3 %.

**Time.**
* *Elapsed*: start to finish, pauses included.
* *Active*: the clock's recording intervals (paused and interrupted stretches excluded). It is labelled
  **Active time** on the dial.
* *Moving*: for each counted step of `d` metres over `dt` seconds, `min(dt, d / 0.5 m/s)` is added. Moving at any
  real pace adds the full interval; time spent standing before a step adds at most what the step could take at
  0.5 m/s. Moving time is never labelled as active time and vice versa.

**Pace and speed.** Average moving pace = moving time ÷ distance; average speed = distance ÷ moving time. Shown
only once distance ≥ 50 m and moving time ≥ 20 s; before that, "—". Current pace uses the counted distance over the
last 30 s of moving time and is shown only when that distance is ≥ 20 m.

**Splits.** Every whole km (or mile) of counted distance. The moment a boundary is crossed is interpolated linearly
in time within the counted step that crosses it (both ends are measured fixes in one segment); never across a gap.
The last part is a labelled **partial** split with its own distance. A split's time is moving time.

**Pace profile.** Pace per 100 m of counted distance (per 0.1 mi in miles), broken at segment boundaries.

**Elevation.** Only fixes with an altitude and (when the device reports it) vertical accuracy ≤ 15 m are used.
Altitudes are smoothed with a centred 5-sample moving average inside each segment, then gain/loss is accumulated with
a 3 m hysteresis. Gain and loss are reported only when at least 60 % of the counted distance has usable altitude;
otherwise they are **unknown** (shown as "—" with a reason), never zero.

**Unknown vs zero.** A walk with no accepted fixes has unknown distance (timer only), not 0 km. Zero is shown only
when GPS measured and nothing was counted.

**Manual distance.** Without GPS the timer still runs and the save review asks for a distance (optional); the record
says "Distance typed, not measured by GPS". A correction of a GPS distance keeps the measured value in
`metrics.gpsDistanceMeters` and `distanceSource = corrected`; the route is never stretched, and splits/charts stay
the measured ones, labelled as GPS.

**Auto-pause (optional, default off).** Pauses after 12 s without a counted step while GPS is live (a fix in the
last 5 s), back-dated to the last counted step. Resumes after sustained movement: two fixes with accuracy ≤ 20 m,
within 15 s, both at least `max(10 m, pause accuracy + fix accuracy)` from the pause position. Hysteresis keeps
stationary jitter from resuming it. The confirming stretch (about 10 m) is not counted: the new segment starts at the
resume. Manual pause is never auto-resumed. Same rules for Run and Walk; `autopause`/`autoresume` are their own events.

**Units.** Stored canonical; shown in km or miles (Me › Units, device preference, default km): distance km/mi,
pace min/km or min/mi, speed km/h or mph, elevation m or ft.

## Location, background and permissions

* One stream (`LocationSource`): geolocator 14, best accuracy, Android every 1 s with no distance filter, iOS
  `ActivityType.fitness`. The Ready screen listens in the foreground only; Start switches to the recording stream.
* **Android**: geolocator's own foreground service (`foregroundServiceType="location"`, declared by the plugin) with
  a visible, ongoing notification "GoHard is recording your run/walk". The app declares `FOREGROUND_SERVICE` and
  `FOREGROUND_SERVICE_LOCATION`. The service is started from the visible app after a while-in-use grant, which is
  what Android allows without `ACCESS_BACKGROUND_LOCATION`, so background ("all the time") location is **not** asked
  for or declared.
* **iOS**: `UIBackgroundModes = location`, `allowBackgroundLocationUpdates`, the blue background indicator, no
  automatic pausing, `ActivityType.fitness`. When-In-Use authorization is enough for updates that start in the
  foreground; Always is never requested (`BYPASS_PERMISSION_LOCATION_ALWAYS=1` in the committed `Podfile` for CocoaPods
  plugins; the plugins built through Swift Package Manager do not take it). Reduced accuracy asks for temporary full
  accuracy with the `RouteRecording` purpose string.
* **One stream.** geolocator keeps one position stream per process; Ready's preview subscription is cancelled before
  Start, so the recording stream (with its foreground service) is the only one.
* Permission is asked in context (Ready's GPS card or Start). States shown truthfully: location off (Open settings),
  not allowed yet (Allow), denied permanently (Open app settings), approximate only (Allow precise location), waiting
  for a fix, ready with the real accuracy. Without GPS, Start offers **Start timer only**.
* Location stops on save, discard, and when Ready is left. Opening a saved activity starts nothing.

## Map

Google Maps for Flutter (`google_maps_flutter`). The map is presentation only: no map key, no tiles, a map error
or no connection never stops GPS or saving. Without a configured key the app shows the route drawn on a plain
surface ("Map unavailable: route drawn without a map") with the same zoom/pan gestures; on iOS the Google map is
never created without a key (the SDK aborts the app otherwise). Google's logo and legal notices are left visible
(map padding moves them above overlays). No Directions, Places, Static Maps or AI request is made to show a route.

Camera: **Follow** (Recording default) keeps the latest position centred. Any pinch, pan, double-tap or zoom
button switches to **Free** and stays there as new fixes arrive, until **Recenter** (back to Follow) or **Fit route**
(the whole route once, then Free). Map gestures are claimed eagerly so they never drag a sheet or scroll a page.
The live line ends at the latest accepted fix.

Keys (never committed; this repository is public):

| Platform | Local file (gitignored) | CI secret |
|---|---|---|
| Android | `app/android/secrets.properties`: `MAPS_API_KEY=…` | `ANDROID_GOOGLE_MAPS_API_KEY` |
| iOS | `app/ios/Flutter/Secrets.xcconfig`: `GOOGLE_MAPS_API_KEY=…` | `IOS_GOOGLE_MAPS_API_KEY` |

The native side reports whether a key is configured (channel `gohard/maps`); without one the drawn route is used.

### Setup, keys and deployment (account steps)

What was found (17 Oct 2026, probed without printing the key, through a free non-Maps endpoint): the old GoHard
app uses **one key for both platforms**, in Google Cloud project **342786702338**. It answers requests with no app
identity and with any iOS bundle ID, so it appears to have **no application restriction**; it has an API
restriction list. It is committed in plain text in `AndroidManifest.xml` of the **public** repository
`abdbabti01/GoHardAPP`. Which Maps SDKs are enabled and the billing state could not be read from here (no `gcloud`
or console access); Maps SDK for Android rendered with it on the emulator, so that SDK is enabled.

Recommended, in the Google Cloud console of project 342786702338 (no new paid service: Maps SDK for Android and for
iOS mobile map loads are unbilled; Directions, Places, Static Maps and the like are not used):

1. **Rotate the exposed key** (it is public in GoHardAPP's history); keep the old app working by giving it the new key.
2. Create **GoHard Rebuild Android** key: Application restriction *Android apps*: `com.gohard.rebuild` and
   `com.gohard.rebuild.debug`, each with the SHA-1 of the certificate that signs it (debug: `keytool -list -v
   -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`; release: the CI/Play
   signing certificate). API restriction: *Maps SDK for Android*.
3. Create **GoHard Rebuild iOS** key: Application restriction *iOS apps*: `com.gohard.rebuild.dev` (the bundle ID in
   this project). When sideloading with Sideloadly and a free Apple ID, check the bundle ID Sideloadly actually installs
   (Settings → General → VPN & Device Management, or Sideloadly's log); if it rewrites the ID, add that ID too. API
   restriction: *Maps SDK for iOS*.
4. Put them where the builds read them (never in git; this repository is public):
   * local Android: `app/android/secrets.properties` → `MAPS_API_KEY=…`
   * local iOS (Mac): `app/ios/Flutter/Secrets.xcconfig` → `GOOGLE_MAPS_API_KEY=…`
   * GitHub repository secrets: `ANDROID_GOOGLE_MAPS_API_KEY` (ci.yml APK), `IOS_GOOGLE_MAPS_API_KEY`
     (ios-unsigned-ipa.yml, ios-dev-ipa.yml).

On this machine the local `secrets.properties` currently holds the **old** key, copied for emulator checks only.
Replace it with the restricted Android key once created.

**Backend.** Additive migration `AddRunRoutes` (columns on `Runs`, table `RouteChunks`); Railway's pre-deploy
`migrate` applies it when `main` is deployed. Until then the hosted API lacks `runs.activity-type`/`runs.routes` and
the app keeps walks, edits and routes queued (runs' time and distance sync as before). No new configuration or secret.
Rollback: the previous API ignores the new columns and table; the app then keeps those commands queued.

## Sync contract

Capabilities (API): `runs.activity-type`, `runs.routes`. The app sends a Walk, a title/notes edit, metrics or
route chunks only to a server that declares them; to an older server those commands wait in the outbox (they are not
sent as a plain run). Unknown capabilities (no answer yet) also wait.

| Command | Route | Body |
|---|---|---|
| `run.start` | `POST /runs` | `runId, dayKey, startedAtUtc, activityType` |
| `run.finish` | `POST /runs/{id}/finish` | `expectedRevision, activeDurationSeconds, distanceMeters, finishedAtUtc, title, notes, metrics` |
| `run.update` | `PUT /runs/{id}` | `expectedRevision, activityType, title, notes, distanceMeters, metrics` |
| `run.delete` | `POST /runs/{id}/delete` | `expectedRevision` (also erases its route chunks) |
| `route.chunk` | `PUT /runs/{id}/route/chunks/{index}` | `firstSeq, lastSeq, entries[]` (≤ 500 entries) |
| `route.complete` | `POST /runs/{id}/route/complete` | `chunkCount, entryCount` |
| read | `GET /runs/{id}/route?fromIndex=&limit=` (≤ 20 chunks per page) | |

* Chunks are uploaded only after Save, in order, one command each, after `run.finish`. Chunk *n* holds entries
  `seq ∈ [500n, 500n+499]`, so a retry, a lost response or a second attempt produces the same chunk. The server
  stores the chunk with a SHA-256 of its entries: the same index with the same content is accepted again
  (idempotent); different content is a conflict.
* The local `route` record (kind `route`, id = activity id) says what was queued; it is `pending` until
  `route.complete` is acknowledged and then `synced`. **Summary synced** and **route synced** are separate states in
  details. Local entries are kept after upload (they are the canonical data for analysis and export) and are erased
  only by delete, discard or account erasure.
* Routes are never in `/sync/snapshot`. Another device reads a route page by page when its details are opened and
  keeps it locally.
* Delete erases the server's chunks; queued chunk commands for a deleted activity are withdrawn locally; a late chunk
  for a deleted run is refused (`NOT_FOUND`), so nothing is resurrected. Account erasure cascades.
* Ownership: every read and write is filtered by the token's user; another user's activity is `NOT_FOUND`.

## Privacy

Routes are private account data. Coordinates are never logged, sent to analytics or included in an AI request (the
coach on Run / Walk is local help text). The weather feature's ~10 km rounding is not applied to routes: the route is
stored as measured. GPX export is only on the person's request, through the system share sheet.

## History and export

History: All / Run / Walk, this week and this month totals (distance, moving time, count) from saved activities,
lazily built rows with a small drawn route preview. Details: route map (selecting a split highlights it), Overview /
Splits / Charts (pace and elevation, broken at gaps), recording quality (accepted/rejected fixes, gaps, GPS coverage),
sync state, edit (title, notes, type, distance correction), delete, Export GPX (GPX 1.1, one `<trkseg>` per segment,
`<time>` on every point, `<ele>` when measured).
