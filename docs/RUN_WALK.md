# Run / Walk

Outdoor Run and Walk recording with a durable GPS route, one metric pipeline, background recording, route sync and
GPX export. The approved look is "Focus Dial" (`GoHard_Run_Walk_Focus_Dial/references/approved-focus-dial.png`,
17 Oct 2026): Ready → Recording (Stats / Map) → Saved. The board's routes, numbers, dates and accuracy are
illustrative; every value on screen comes from the device or from stored data.

Out of scope (not built, not promised): public feeds, leaderboards, competitive segments, route planning or
navigation, Strava, wearables and health platforms (beyond the one Health Connect step read below), heart rate,
cadence, VO2 max, calories, offline map downloads, snapping to roads. Since 18 Oct 2026: steps, intervals, voice and
alerts, personal bests (sections below).

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
| Steps (native adapter, activity tally, daily total) | `features/activity/steps.dart`; Android `MainActivity.kt` (channel `gohard/steps`, event channel `gohard/steps/live`); iOS `AppDelegate.swift` (`StepsBridge`) |
| Intervals (plan, position from the active clock, timeline) | `features/activity/intervals.dart` |
| Voice and alerts (cues from a recording, the one announcer, speech) | `features/activity/announcer.dart` |
| Personal bests (fastest stretches, projection, new records) | `features/activity/records.dart` |
| Run / Walk choices on this phone (voice, updates, intervals, steps, goal) | `features/activity/move_prefs.dart` (store `gohard.rebuild.move`) |
| Shared widgets (interval setup, phase bar, coach line, voice sheet, bests, steps row/settings) | `features/activity/move_widgets.dart` |
| Tests | `test/move_logic_test.dart` (intervals, steps, cues, records), `test/run_walk_extras_test.dart` (recorder + announcer on a real database), `test/move_ui_test.dart`, `test/move_render_test.dart` (renders, gated), `test/track_math_test.dart` (GPS fixtures), `test/run_walk_recorder_test.dart` (recorder + sync on a real database), `test/run_walk_ui_test.dart`, `api/tests/.../RunRouteTests.cs`, `integration_test/journey_runwalk_test.dart` |

## Activity record

The existing `run` record (kind `run`, `/runs`) is the activity, Run or Walk; there is no second table. Additive fields:

| Field | Meaning |
|---|---|
| `activityType` | `run` or `walk`. Chosen before Start, kept through restart, sync, history and export. Never changed automatically (slowing down does not turn a run into a walk); only the person's edit changes it. Missing = `run` (every older record was a run). |
| `title`, `notes` | Editable. Title defaults to "Morning/Afternoon/Evening/Night run/walk" from the local start time. |
| `activeDurationSeconds` | Active time (unchanged meaning, see Metrics). |
| `distanceMeters` | The distance the activity reports: GPS-measured, or the person's correction, or typed (manual). |
| `metrics` | Derived summary for lists and other devices, recomputable from the route: `elapsedSeconds`, `movingSeconds`, `gpsDistanceMeters`, `elevationGainMeters`, `elevationLossMeters`, `distanceSource` (`gps` · `corrected` · `manual` · `none`), `routeState` (`none` · `recorded` · `partial`), `pointCount`, `gaps`, `interrupted`. Since 18 Oct 2026, all optional: `stepsState` (`off` · `denied` · `unavailable` · `measured` · `partial`) and `steps` (only when measured or partial), `intervals` (`{plan, skips}`, at most 100 skips, so `metrics` stays under the API's 4,000 characters), `efforts` (`{"1000": s, "5000": s}`, fastest stretches). |

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

## Steps

Measured by the phone's motion hardware only: never estimated from GPS distance, pace or a stride length, and a
pedometer distance never replaces the GPS distance or its provenance.

**Where it is (18 Oct 2026, from GoHard_Steps_RunWalk_UX_Corrections).** One set of controls, the Steps sheet
(`steps_ui.dart` `showStepsSheet`: Count steps, the access state and its fix, the optional goal, **Show Steps on
Today**, what stays where), opened from three places backed by the same preferences: Today's **Steps** tile beside
Run / Walk, Me › **Activity & tracking › Steps**, and the **Steps** row on Run / Walk Ready. It is no longer in
Nutrition's Customize tracking. Choices made before the move (steps on, the goal) are kept: the store is the same.

**Turning on.** Off by default, per account, on this phone. **Enable** (Today's tile, Ready's row, the sheet's switch,
or the Today coach's one-time "Enable steps") asks for Motion & Fitness (iOS) or Physical activity (Android,
`ACTIVITY_RECOGNITION`), and on Android Health Connect's step read (`android.permission.health.READ_STEPS`) for the
daily total. Opening Today, Ready, Me or the sheet asks for nothing. After a refusal the fix is offered (Allow while
the phone will still ask; Settings once it will not), never a repeated prompt. Run / Walk records normally whatever the
answers.

**Today's tile.** Shown before steps are on, unless the person hides it (Show Steps on Today: display only, counting
and access unchanged): "Track your steps / Count with your phone." and Enable, no number and no bar. Once on: the
real count, the source and the time it was read; the goal bar only with a goal; distinct words for loading, access
not allowed (Allow), access off (Settings), not available, could not be read (Try again) and no step data today. Beside
the Run / Walk tile at ordinary sizes, stacked under it at large text or below 350 px; Run / Walk History under the
two. Tapping it opens the sheet.

**During a Run / Walk** (`StepTally`). Readings of the cumulative counter (Android `TYPE_STEP_COUNTER`, steps since
the phone started, each with the time of the steps even when delivered late in a batch; iOS `CMPedometer.startUpdates`,
steps since the updates began, plus a 0 reading at that moment) are received for the whole open recording, pauses
included. Each reading's increase over the previous one is counted by how much of that stretch was recorded
(`TrackAnalysis.recordingShare`, the recording windows): wholly recorded, all; wholly paused or interrupted, none; a
stretch across a pause boundary of at most 10 s is split by time; a longer one is left out, and the count is marked
**partial** when that leaves out more than 10 steps (a long stretch with a step or two is standing still around Pause
or Resume). A counter that goes backwards (the phone restarted) starts a new baseline and, when that cost recorded
time, marks the count partial; a sensor error marks it partial. A walk/recovery phase of an interval session is
recording time. The tally is checkpointed with the recorder state; after a restart (Interrupted) or after Finish →
Resume the next reading is a new baseline, so nothing during the gap is counted and nothing is counted twice.

| `stepsState` | Shown |
|---|---|
| `measured` | the number (0 is a real zero: the sensor was counting) |
| `partial` | the number, "(part of the time)" |
| `denied` / `unavailable` / `off` | "Not counted: motion access is off" / "… no step sensor" / "Not counted" |
| absent (saved before steps existed) | "Not recorded": unknown, never 0 |

Steps of an activity sync with it (inside `metrics`; no server change: the API keeps `metrics` as given, so older
apps and servers keep the fields; an edit merges into the existing metrics).

**Daily total** (Today, under Run / Walk, only when on). One authoritative source per platform, never added to
anything: iOS `CMPedometer.queryPedometerData` from local midnight ("This iPhone": steps this iPhone counted, about
7 days kept); Android Health Connect's aggregate `StepsRecord.COUNT_TOTAL` from local midnight ("Health Connect": it
resolves overlapping sources such as the phone, a watch and fitness apps). Recorded activity steps are never added to
it (the day's total already includes them), and two phones are never summed. When Health Connect has no step data at
all for the day, it says so instead of showing 0. Read when shown, on return to the foreground and every 5 minutes
while shown; local midnight is worked out on every read (midnight, a time-zone change and a restart start the right
day). The source and the time of the read are shown; an optional goal is the person's own number (no default, no
target implied). Daily totals stay on the phone: never stored, synced, logged or sent to the AI. Phone-only counts
miss walking without the phone (said in Customize tracking).

Android: minSdk 26 (Health Connect's client); Health Connect is part of Android 14+, an app before; without it the row
says daily steps need Health Connect. iOS: no HealthKit, no entitlement: Motion & Fitness works with a free Apple ID
and Sideloadly (`NSMotionUsageDescription`).

## Intervals

Optional, from Ready (**Intervals** in "Your setup", above Start; one tap on Start still records a free Run / Walk). Setup:
warm-up walk (0–30 min), Run and Walk/recover (15 s–60 min each), repeats (1–30), cool-down walk (0–30 min); the
starting point is week 1 of the NHS Couch to 5K plan (5 min walk, then 60 s run / 90 s walk × 8, then a 5 min walk),
editable. The preview draws the phases to scale and gives the programmed active time. The setup is kept on the phone
and reused (Ready says "Intervals on" with it); "Turn intervals off" keeps it for later.

An interval session is **one activity** of the type chosen (Run or Walk), never changed by its phases. Its plan and
skips are in the recorder state (checkpointed at once on Skip) and saved in `metrics.intervals`. The position is a pure
function `IntervalClock.at(plan, skips, activeMs)` of the recorder's active clock: pausing freezes it, an interruption
is not active time, and a rebuild, a tab change or a restart cannot move it. **Skip phase** ends the current phase at
that active time. Phase changes never pause, finish or log anything.

Recording shows the phase, its time left (the last three seconds large), the round ("Round 3 of 8"), the phase strip
and the next phase, under the dial (compact in the Map view), with Active time on the dial as before. After the last
phase: "Intervals finished" with **Continue freely** (recording goes on without prompts) or **Finish and review**;
the GPS recording never finishes by itself.

Auto-pause does not run during an interval session (walking to recover is not a pause); the person's Auto-pause
choice is kept for free runs and walks and Ready says so.

The details screen lists the phases as recorded (active seconds; "Ended early" for a skipped or unfinished one) and
how many runs were completed.

## Voice and alerts

One announcer (`Announcer` in `announcer.dart`) for everything said during a recording and after a save. Cues are
structured local events with a stable key (`<activity>:phase:<n>`, `<activity>:dist:<n>`, `<activity>:time:<n>`,
`<activity>:intervals:done`, `record:<activity>`); a key is said once.

* **Where they come from.** The recorder samples its own active clock every second while recording
  (`recordingCues`, pure). The first look after a start, a restart or taking an activity over only notes where it
  stands, so nothing due earlier is said: no replay on resume, no backlog after an interruption. The screen's 1 s
  redraw plays no part.
* **Words.** Phase prompts: "Warm up: walk for 5 minutes." · "Run for 2 minutes." · "Walk and recover for 1 minute."
  · "Final round. Run for 1 minute." · "Intervals finished. Continue freely, or finish and review." Updates, by distance
  (every 0.5, 1 or 2 km/mi) or active time (every 5, 10 or 15 min): distance, **active time** and **average moving
  pace** (named as such; spoken only once the pipeline has an honest pace, never as a made-up number), in the unit
  chosen in Me. A personal best after a save (below).
* **Policy.** Priority: phase prompt (3) > personal best (2) > update (1). A higher one cuts a lower one being spoken;
  a lower one waits, and is dropped if it would be more than 8 s late. A phase change and an update due at the same
  moment are one message, phase first. Pause, Finish, Discard, an account change and turning voice off stop speech
  and drop what was queued.
* **Presentation.** On screen always: the coach line under the dial: Leon or Leona's animated bust with the bubble
  from the mouth (the same rig as Today, compact; it nods at a new message and never re-enters) when Show coach on
  Train and Eat is on, the words alone otherwise; read by screen readers as it changes; never over the map or controls.
  Spoken only when **Voice updates** is on (Ready › Voice and alerts, or the speaker button while recording; off by
  default; never on account creation or opening Today). Vibration at a phase change when **Vibrate at interval
  changes** is on and Haptics is not Off; a tick for each of the last 3 seconds with **Countdown**.
* **Voice.** The phone's own text-to-speech (`flutter_tts`: AVSpeechSynthesizer / Android TextToSpeech), no network,
  no AI, no cloud voice, no microphone. The person may pick an installed voice in the app's language, or the phone's
  own. Only voices that work offline are offered: Android marks a voice that needs the network (`network_required`)
  and those are never listed or used (`offlineVoices`); a chosen voice that is gone or needs a connection falls back
  to the phone's own, and the sheet says so (also when no offline voice exists for the language). Whether the phone's
  own default voice is offline is the phone's setting (Settings › Text-to-speech); see the airplane-mode check below. Leon speaks a little
  lower, Leona a little higher (pitch), so the coach sounds the same every time. **Preview voice** says a short hello.
  The portrait does not lip-sync.
* **Audio.** Other audio is lowered while speaking and restored after: iOS shared session `playback` with
  `duckOthers` + `interruptSpokenAudioAndMixWithOthers`, deactivated with notify-others after each utterance; Android
  navigation-guidance audio attributes and transient may-duck focus, abandoned after. Music is not stopped. Calls and
  other interruptions are handled by the system (an utterance during a call may be dropped).
* **Background and lock screen.** Recording keeps running in the background as before; speech continues there
  (iOS: `UIBackgroundModes` gains `audio`, used only while speaking, no silent keep-alive; Android: the location
  foreground service keeps the process). Vibration with the screen locked: Android yes (system vibrator); iPhone only
  while GoHard is in front (Apple limits background vibration). No extra notification is posted: the Android
  recording notification stays as it was, and there is no avatar on the lock screen. A process killed by the system
  or force-quit records and says nothing; on reopening it is Interrupted (as before) and nothing is replayed.

## Personal bests

Projected, never stored as awards (`personalBests` in `records.dart`) from every saved activity on this phone (the
account snapshot is pulled whole, so the history is all or nothing; nothing is called a best before it is read).
Run and Walk are separate:

| Run | Walk |
|---|---|
| Longest run · Fastest 1 km · Fastest 5 km | Longest walk · Fastest 1 km |

* Longest uses the GPS-measured distance (`gpsDistanceMeters`). A fastest time is the quickest continuous stretch of
  that distance in counted GPS distance inside one recording segment, timed by **elapsed** time from its start to
  its end (`bestEfforts`, worked out at save and kept in `metrics.efforts`): a pause, auto-pause, interruption or
  GPS gap ends a segment, so a stretch never spans one and nothing is interpolated through missing GPS; only the
  start is placed inside the one counted step it falls in. Not the whole activity's average.
* Only saved activities whose distance GPS measured (`distanceSource = gps`, not legacy): typed, corrected and
  before-routes activities never count. Activities saved before 18 Oct 2026 have no `efforts`: they count for
  longest only, and the list says how many were not checked for times.
* Canonical metres and seconds: changing km/mi cannot change a record. Ties go to the earlier activity. An edit,
  a type change or a deletion changes the projection at once; saving or syncing again cannot award twice.
* Shown: History › **Personal bests** (one row, opening the list), Train › Progress (under the history, once
  something is saved), and on an activity's details ("Personal best · Fastest 1 km run") once at least two activities
  qualified in that category.
* **Celebration.** Only from a save's own success path (`Recorder._celebrate`, in memory), against the activities
  before it, and only when there was one to beat (a first walk is not a "best"): "Your longest walk so far, 4.00 km."
  The Saved screen's coach says it once (a bubble with Close; still under Reduce Motion) and the announcer speaks it
  when Voice is on.

**Auto-pause and records.** The documented auto-pause limitation (the ~10 m that confirms a resume is not counted;
the segment starts at the resume) means a stretch never spans an auto-pause; a benchmark after one is timed only from
the resume on. No correction was needed for records; no record crosses an auto-pause.

## Ready (18 Oct 2026, the approved "option 1" board)

From the top: Back and History; the title with Leon / Leona and the bubble beside it (words only: "Choose your setup.
Start when ready."); Run / Walk; a compact map (zoom −/+ top right, Expand map bottom right, recenter bottom left,
Google's notices moved right of it); GPS in one line ("GPS ready · ±5 m", or what is needed and its action); **Your
setup**: Intervals, Voice and alerts, Auto-pause; the **Steps** row (Steps off + Enable, Steps on, or what access
needs); then **Start**, in a bar of its own at the bottom with the safe area under it. Nothing is set below Start.

Each setup row is one tap target: the supplied glyph, the label, its real state ("Run 1 min · Walk 90 s · × 8",
"On · every 1 km", "Off", "Not used with intervals") and a chevron; it opens the existing editor (Auto-pause now has its
own small sheet with the switch). At large text or below 340 px the state and any action go under the label. The map
takes the height left on a phone once the rest is in view (measured: a 390 × 844 phone with its 47 px notch and 34 px
home indicator shows every row and Start without scrolling, coach on or off, `move_ui_test`); a short phone or large
text scrolls the page, from anywhere but the map, with Start staying put. Expand map opens a larger map following the
same position (Ready's one preview stream; nothing starts).

**Icons.** The supplied glyphs (`app/assets/icons`, from GoHard_Steps_RunWalk_UX_Corrections/icons: intervals,
voice, auto-pause, steps footprints, history, back, chevron, recenter, expand map, plus, minus, play), drawn by one
`GoIcon` (`core/go_icon.dart`, `flutter_svg`) in the theme's colour (`currentColor`), for these Run / Walk and Steps
controls only: Ready, the map buttons (also while recording and on details), Today's Start and Steps, Me › Steps.

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
