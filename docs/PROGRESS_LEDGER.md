# Progress ledger

Machine: Windows 10 Home, .NET SDK 10.0.401, Flutter 3.47.6 / Dart 3.13.5, Docker 29.8.1, Android emulator `Pixel_7`
(Android 16, 1080×2400). Dates are the build session of 10–11 October 2026. Every result below was produced by
this rebuild's own code; nothing is carried over from the original project.

## Isolation checks

| Check | Result |
|---|---|
| Workspace `C:\dev\GoHardRebuild` | did not exist; created new, own git repository (no remote) |
| Existing containers `gohard-qa-postgres`, `quebec-receptionist-postgres-1`, `ps0`, `agitated_dubinsky` and their volumes | never referenced, started or modified by the scripts. Docker Desktop was started (it was stopped), which let containers with a restart policy come up on their own |
| Ports | 5432/5433/5434 were taken or reserved by other things; this project uses **5435** (database) and **5131** (API), both free |
| Original GoHard app on the emulator (`com.example.go_hard_app`) | still installed; this app uses `com.gohard.rebuild(.debug)` |
| .NET SDKs 6.0.402 and 8.0.205 | untouched; 10.0.401 was already installed |

One mistake made and corrected: an early API test run read `appsettings.Local.json` and created 4 test accounts in the
development database. Fixed by giving that file the lowest configuration precedence, adding the guard test
`Api_under_test_uses_only_the_disposable_database`, and deleting those 4 rows. No other database was involved.

## Commands and results

| Command | Result |
|---|---|
| `scripts\setup.ps1` | container healthy; `Migrations applied.`; `Readiness: Ready - 2 migration(s) applied.`; `Catalog entries: 26` |
| `scripts\start-api.ps1` → `GET /health/ready` | `200` |
| `scripts\test.ps1` (final run) | API build 0 warnings (warnings are errors) → **58 passed, 0 failed, 0 skipped** on disposable PostgreSQL 17.6 → release publish OK → codegen → `flutter analyze`: **No issues found** → **57 Flutter tests passed** |
| `flutter build apk --debug --dart-define=GOHARD_API_BASE=http://10.0.2.2:5131` | built `app-debug.apk` |
| `flutter drive … integration_test/journey_test.dart -d emulator-5554` (what `scripts\test-android.ps1` runs) | **All tests passed** (2 m 50 s), 22 screenshots written |
| `flutter build apk --release --dart-define=GOHARD_API_BASE=http://10.0.2.2:5131` | built `app-release.apk` (60.6 MB), debug-key signed. Compile/packaging proof only: it was not installed or run, and a release build blocks cleartext HTTP, so a usable one needs an HTTPS API origin |

Test inventory: API 58 = domain rules on the shared fixture (21 theory cases + 2), foundation/auth/readiness/upgrade/
erasure (10), isolation guard (1), plans and proposals (13), workouts/food/activities (11). Flutter 57 = shared-fixture
rules (24), real-Drift data layer (19), projections and clock (8), widgets (6).

## Native Android evidence (`docs/evidence/screenshots/`)

One journey, one fresh account registered through the real API into the real development PostgreSQL:

`01` sign-in · `02` Today for a new account (no invented data) · `03` plan setup · `04` plan review · `05` Today with the
due workout · `06` Train › Plan · `07` set entry · `08` rest countdown · `09` target reached plus an extra set ·
`10` finish review (partial) · `11` result · `12` Today "Done for today" · `13` food form · `14` Today known totals ·
`15` Eat journal · `16` specific removal confirmation · `17`/`18` Me dark/light · `19` Today light · `20` Progress ·
`21` Workouts · `22` Today after sign-out, a wrong password, and signing in again.

The green rectangles in some captures are the test harness's accessibility-focus highlight, not app UI. Captures are
of the Flutter surface, so the Android status bar is not shown.

### Natively exercised

Registration; sign-out; wrong password; sign-in; all four tabs; retained Train section; setup → reviewed draft →
activation; planned workout start; entering load/reps; rest and skip; extra set after target; deliberate next
exercise; partial finish and result; one credit on Today; food add with blank and zero nutrients; edit-cancel; edit;
second entry; confirmed removal; dark and light appearance; progress.

Also observed, not scripted: after `adb install -r` and relaunch, the app restored the signed-in session and showed
"Your 4 recorded sets are waiting for you — Resume workout" for a workout left open by an interrupted run.

### NOT exercised on a device (verified only at the layer shown)

| Scenario | Where it is verified instead |
|---|---|
| Offline entry → process kill → reconnect with one result | real-Drift tests `offline_finish_waits_for_actual_sets`, `restart_retains_work…`, `lost_set_ack_does_not_duplicate` |
| Two-device plan/set/food conflicts and their resolution | API tests + real-Drift tests; the review screen itself is untested |
| Account switch on one phone | real-Drift test `account_switch_rejects_ack…` |
| Midnight and DST with a form or workout open | unit tests of `BusinessDateService` and `WorkoutRuntime`; pinned-date design |
| No-data finish, manual workout, pause, save for later, set edit/undo, substitution | rules/API tests; screens built |
| Plan pause/resume/move/skip/close/replace, proposals, fit feedback, manual plan builder | API tests + local-rule tests; screens built |
| Account deletion, name edit, unit switch, runs, body measurements | API tests; screens built |
| System appearance, TalkBack, reduced motion, physical device, 320 px native width | 320 px at 2× text is covered by a widget test only |
| iOS | not built: no Mac, signing identity or device. `.github/workflows/ci.yml` has an unsigned `flutter build ios` job that has never run |

## Defects found by testing and fixed

| Found by | Defect | Fix |
|---|---|---|
| API tests | acknowledgement timestamps had more precision than PostgreSQL stores | normalise instants to microseconds on input |
| API tests | local config file could override test configuration | lowest precedence + guard test |
| Drift tests | a background dispatch could race a closing database and surface as an unhandled error | single-flight `flush()` whose callers await the running pass; `idle()` before close |
| Widget test | a food-journal read failure hid the training action on Today | training no longer depends on the food stream |
| Native run | `ref` used during `dispose` of the workout screen; draft written back after finish | repository captured once; writes blocked after finish/remove |
| Native run | the "set saved · Undo" snackbar covered the result screen's Done button | cleared on finish; 4 s duration |
| Native run | after signing in again the shell reopened on the previous tab | shell state resets per owner |
| `scripts\test.ps1` | could not build while `start-api.ps1` was running (locked Debug output) | tests build and run in Release |

One observation left open: in the native journey the final sign-in only succeeded once the test re-typed the email
after the failed password attempt. The API accepted the same credentials directly. It may be a test-input artefact
or a real field-state issue on the sign-in screen after an error; it has not been reproduced by hand.

## Open items (honest list)

1. Screens listed above as "built, not exercised" need widget or native coverage before they are called verified.
2. Not implemented: OS reminders, GPS run tracking, social, health sync, music, an AI provider, workout reopen,
   nutrition targets, food database/barcode, body-metric edit, exercise reorder.
3. Baseline plan content (`api/src/GoHard.Api/Data/baselines.json`) and the exercise catalog were written for this
   build and need review by the owner or a coach before real use.
4. `dart format` was not run across the project; CI does not enforce formatting yet.
5. CI workflow has never executed (no remote repository).
6. Client does not yet enforce a minimum contract version from `/capabilities`.
7. Conflict review offers "use the account's version" for plan conflicts; re-applying the local plan decision means
   repeating the action.
8. A rejected (not conflicting) local change can only be removed, not edited and resubmitted in place.

## Commits

`Foundation: .NET 10 API…` · `Flutter app: Evening Club shell…` · `Flutter tests…` · `Native Android journey test…` ·
final documentation and scripts commit.

## Update — 11 October 2026

**Second native journey added and passing:** `integration_test/journey_secondary_test.dart` (screenshots `30`–`42`).
`scripts\test-android.ps1` now runs both journeys, each from a clean install; final run: both **All tests passed**
(2 m 55 s and 2 m 51 s), 36 screenshots in total. `flutter analyze` clean and 57 Flutter tests still pass.

Now exercised on the device as well: manual workout with a bodyweight set (no load typed), workout pause/resume,
save for later and resume from Train, parked workout not taking over Today, manual result, no-data finish, plan
pause (Today shows "Plan paused", no planned start), reviewed resume, skip with its confirmation, block review and
stop early (primary slot freed, block listed as "Stopped early"), name edit, workout history, account deletion
refused on a wrong password, real deletion, and the deleted credentials failing to sign in.

Still not exercised on a device: moving an occasion, replacing a primary plan, archive, proposals/substitution,
fit feedback and the manual plan builder, conflict review, set edit/undo, in-workout substitution, pounds, runs,
body measurements, offline/reconnect, account switch, midnight/DST, system appearance, TalkBack, iOS.

Defects found by the second journey and fixed:

| Defect | Fix |
|---|---|
| "Save for later" was overwritten when the workout screen closed, so the workout still read "In progress" and stayed in the foreground | the parked state is now the last write; later draft writes are blocked |
| The "plan started" message could sit over the bottom navigation bar and swallow taps | it is shown after returning to the shell, above the bar |
| `run-android.ps1` / `test-android.ps1` picked the first emulator, which could be an unsupported 32-bit x86 image | scripts choose an x86_64/arm64 emulator and reject unsupported running devices with instructions |

## Update — reminders and GPS (11 October 2026)

Added packages: `flutter_local_notifications` 22.3.1, `timezone` 0.11.1, `flutter_timezone` 5.1.1, `geolocator` 14.1.1.
Android: notification, boot and location permissions, the plugin's receivers, core-library desugaring.
iOS: `NSLocationWhenInUseUsageDescription` (still never built).

**Reminders** (`features/me/reminders.dart`, switch and time in Me). One notification per pending workout of the
active primary plan, at the chosen local time in the phone's current zone. Permission is asked only when the switch
is turned on. None for a paused, closed or draft plan; none for skipped, recorded or in-progress workouts; all removed
on sign-out. Re-timed on app resume so a zone change moves reminders, never plan dates.

**GPS** (`features/activity/run_tracking.dart`, run screen). Distance is the sum of consecutive trustworthy readings
while the run screen is open. Vague readings, standing jitter and position jumps add nothing; a stretch without
readings is counted as a gap and left out; movement while paused is not counted. Typed distance still wins.

| Command | Result |
|---|---|
| `flutter analyze` / `flutter test` | No issues / **64 passed** (7 new in `reminders_gps_test.dart`) |
| `scripts\test-android.ps1` (journeys 1 and 2, after these changes) | both **All tests passed** |
| `scripts\test-android.ps1 -Only journey_device_test` | **All tests passed** (1 m 36 s); screenshots `50`–`52` |

What the device journey proves: the operating system's own pending-notification list is 0 with no plan, 23–24 with an
active 8-week plan, 0 after pausing, back after resuming, 0 after sign-out; and a run's distance grows from positions
fed through Android's test location provider and is saved with the run.

What it does not prove: a reminder actually appearing at its time (only that it is scheduled); GPS behaviour on a
physical phone outdoors (accuracy, battery, signal loss); iOS. API tests were not re-run (no API change).

Defects found on the device and fixed:

| Defect | Fix |
|---|---|
| Signing out left the previous owner's 24 reminders scheduled | removal is decided inside the one provider that schedules, keyed on the signed-in owner; replacements are serialized so an older request cannot re-add them |
| No readings arrived through Google's fused provider with simulated positions | run tracking reads the GPS provider directly and asks for a reading every 2 s |

Observed, not fixed: floating messages ("Plan paused.", "plan started") sit over the bottom of a list for about four
seconds and swallow taps there; the journeys wait them out. One device run was aborted because the original GoHard
app came to the foreground on the emulator by itself; its process was stopped (its data was not touched). One run
failed on a navigation tap that passed in every other run.

## Update — remaining screens, offline and conflicts on the device (11 October 2026)

Two more native journeys, sharing `integration_test/support.dart`. `scripts\test-android.ps1` now runs five
(`journey_test`, `journey_secondary_test`, `journey_more_test`, `journey_offline_test`, `journey_device_test`).

**`journey_more_test`** (screenshots `60`–`67`): fit feedback for an unsupported setup with nothing created; building
my own plan and saving it as a draft; pounds at entry and display with the same record reading 45.4 kg afterwards;
Undo of a recorded set; editing a set; a body measurement; moving a workout with its review ("originally" kept);
a movement replacement reviewed and accepted, visible in a remaining workout; replacing the primary plan with an
explicit confirmation; archiving the displaced plan.

**`journey_offline_test`** (screenshots `70`–`73`): the script switches the emulator's Wi-Fi and mobile data off when
the test asks. Offline: a manual workout with two sets and a food entry are recorded, shown as "sync pending", Today
shows the offline notice, Me shows work waiting. Back online: the account then holds exactly one workout, two sets,
one finish and one food entry (checked through the API). Then a second device changes the same food through the
API while the phone has an edit ready; the phone's save conflicts; the review screen shows both versions; "keep the
version on this phone" is chosen; the account ends with the phone's version and still exactly one entry.

| Run | Result |
|---|---|
| `flutter analyze` / `flutter test` | No issues / 64 passed |
| Combined `scripts\test-android.ps1` | journeys 1 and 2 passed; journey 3 failed on a test tap made while a sheet was closing (fixed in the test) |
| Journeys 3, 4, 5 run individually afterwards | all **All tests passed** (3 m 41 s, 1 m 35 s, 1 m 46 s) |

Not yet done: one clean combined run of all five after the last test-helper changes.

Defects found and fixed in the app:

| Defect | Fix |
|---|---|
| Fit feedback appeared at the end of the long setup form, off screen, so "Preview my plan" looked like it did nothing | the form scrolls to the feedback |
| Pop-up messages covered the bottom of a list for about four seconds | plain confirmations now last about two seconds and can be swiped away |
| Nutrition heading read "Known totals" when food was logged with no nutrition at all | reads "No nutrition entered for this food yet" |

Resolved observation: the earlier "email needs retyping after a wrong password" was the test's simulated typing being
dropped on the device (the field still held the old text right after the test typed). The journeys now focus the
field, verify what was typed and retry. Journey 1 additionally asserts the email is still present after a failed
sign-in, and passes.

Test-environment notes: the emulator stopped launching the test app after several hours and needed a cold restart;
the original GoHard app starts itself on emulator boot and can take the foreground, so the script now presses Home
first; one run died in the Flutter tool with an RPC error before any step ran.

Still not exercised on a device: set and plan conflicts through the review screen, in-workout movement replacement,
account switch on one phone, a process kill while offline, midnight/DST, system appearance, TalkBack, a physical
phone, iOS.

## 12 October 2026 — Calm Momentum redesign (branch `design/calm-momentum`)

The interface was rebuilt on a new design system: Inter throughout, three accents (Blue, Green, Pink) in Light, Dark
and System, a photographic workout feature on Today, a training pass and week grid on Train › Plan, and an Appearance
page. Data contracts, the API and the deployment configuration are unchanged. Details and the differences from the
approved references: `docs/DESIGN.md`.

| Command | Result |
|---|---|
| `scripts\test.ps1 -SkipApi` | codegen → `flutter analyze`: **No issues found** → **93 Flutter tests passed** (was 64) |
| `flutter test test/render_test.dart --dart-define=GOHARD_RENDER=true` | 22 renders written to `docs/evidence/design/` |
| `flutter build apk --debug --dart-define=GOHARD_API_BASE=http://10.0.2.2:5131` | built `app-debug.apk` |
| `scripts\test-android.ps1 -Only <journey>`, each of the five, Pixel_7 emulator, local API | all five **All tests passed** on the final code |
| `journey_device_test` with the emulator in dark mode (`adb shell cmd uimode night yes`) | passed; a fresh install opened dark showing "Blue · System" (`50-me-reminders-on.png`) |

API tests were not rerun: no API file changed.

New automated coverage (`app/test/theme_test.dart`): measured contrast of every token pair in all six themes and
their increased-contrast variants; rendered text contrast, tap-target size and labels on the four tabs in all six
themes; fresh-install default, persistence across a restart, an unreadable saved value; choices applying at once
without resetting navigation; System following an OS change while keeping the accent; week boundaries for a mid-week
start and a 12-week block; completion counting recorded results only; recorded-set progress never counting targets.
`journey_more_test` now changes accent and mode in the middle of a workout and checks the typed, unsaved entry is
still there and nothing was saved by itself.

Defects found by running the app and fixed:

| Found by | Defect | Fix |
|---|---|---|
| Native journey | In a form, tapping a field low on the page while the keyboard opened could drop that field from the page (the lazily built list discarded it as the page shrank) | pages with a pinned action keep every field built |
| Tap-target check | the three-way switch was 42 px high | 48 px |
| Contrast test | accent-coloured text on the selection tint was under 4.5:1 for light Blue and Pink | accents darkened slightly |
| Renders | week dates wrapped unevenly four across; a workout row orphaned "sets" | three tiles across with equal heights; date and summary on their own lines |

Tool notes: two journey runs ended with the Flutter tool's "Service has disappeared" after the on-device tests had
passed, and later runs could not connect at all until the emulator was cold-restarted (the same emulator ageing
noted above). Editing `app/lib` while a journey is building breaks that build.

Not verified, and why:

| Item | Status |
|---|---|
| iOS build with the new launch background (`LaunchBackground.colorset`, storyboard named colour) | written by hand on Windows, never compiled; the first `ios-unsigned-ipa` / `ios-dev-ipa` run will show whether Xcode accepts it |
| Display brightness comfort, smoothness and frame timing on the iPhone 13 | needs the phone; checklist in `docs/IPHONE_TESTING.md` |
| VoiceOver / TalkBack by ear, Reduce Motion and Increased Contrast on a device | implemented and covered by semantics and token tests only |
| Launch screen colour when the app is set to Light but the phone is Dark (or the reverse) | the launch screen follows the phone, because the OS draws it before the app can read its setting |
| Profile-mode performance measurements | not run: the emulator is not representative |
| `dart format` | not applied; the repository's wide-line style is kept and CI does not enforce it |

## 12 October 2026 — iPhone build preparation for the redesign

Branch `design/calm-momentum` was pushed (not merged into `main`). GitHub state found: repository variables 0,
repository secrets 0, so the signed workflow had never been able to run.

| Run | Commit | Result |
|---|---|---|
| `ci` (push) | `d2b67e3`, `aecbc0b` | success: API build and tests, app analyze and tests, debug APK |
| `ios-unsigned-ipa` on the branch | `d2b67e3`, `aecbc0b` | success on macOS. The hand-edited launch storyboard compiled: the built app contains the `LaunchBackground` colour in `Assets.car` and the compiled storyboard refers to it |
| `ios-dev-ipa` (signed) on the branch | `aecbc0b` | stopped at "Check configuration": secrets `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64` are not set. No signed IPA exists |

Done here: repository variable `GOHARD_TESTING_API_BASE` set to `https://gohardrebuild-production.up.railway.app`
(the address the unsigned workflow already used). That API answered from this PC and from the GitHub runner: readiness
200, contract 1 (the app's), sign-in with bad credentials 401. The unsigned IPA was downloaded and inspected: bundle
ID `com.gohard.rebuild.dev`, API address `https://gohardrebuild-production.up.railway.app/api/v1`, no emulator or
loopback address.

Appearance migration changed: an install that was already signed in keeps its old Dark, Light or Match-this-phone
exactly (previously Dark was dropped as "the old default"). A fresh install is still Blue + System. New native
journey `journey_upgrade_test` reproduces the old version's state on the emulator (signed-in session, appearance
saved the way the old Me screen saved it, no device record), restarts the app and checks Dark stays Dark and Light
stays Light, then that a later choice on the device survives a restart: **All tests passed**. Flutter tests: 97.

Emulator captures in `docs/evidence/screenshots/` were all regenerated on the new design and looked through. One
inconsistency fixed: when a dialog's two actions did not fit on one line, the text link sat above the main button;
the main button is now on top. A stale capture from the old design was removed and misleading file names corrected.

Still pending, not done by anyone yet: the signed IPA; installing and running on the iPhone 13; display brightness
comfort; VoiceOver; smoothness and profile-mode performance.

Remaining feature, not part of this redesign: **editable nutrition goals with calorie and protein progress**. The
approved layout shows goals and progress bars on Today and Eat; the app has nowhere to set or store a goal yet, so
those bars are deliberately absent. It needs a goal setting, storage that syncs, and the progress display.

(Done on the same day: see the next section.)

## 12 October 2026 — food search, barcode scanning, reusable foods, nutrition goals, compatibility gate

Branch `feature/food-discovery`, on top of `design/calm-momentum`. How it works, the provider rules, limits and
configuration: `docs/FOOD_DATA.md`. The design additions: `docs/DESIGN.md`.

What was added: `Log food` now opens one place to find a food (search, barcode, favourites, recent, own foods,
manual), and every path opens the one existing food form, which logs only on its confirmation. A logged food keeps
its own copy of the source food, the amount and per-nutrient provenance. Optional calorie and protein goals on the
profile, with progress on Today and Eat. The app is blocked, with its outbox kept, when the server's minimum
contract is above its own.

| Command | Result |
|---|---|
| `scripts\test.ps1` | API build 0 warnings → **83 API tests passed** (was 58) on disposable PostgreSQL → release publish → codegen → `flutter analyze`: **No issues found** → **134 Flutter tests passed** (was 97) |
| `flutter test test/render_test.dart --dart-define=GOHARD_RENDER=true` | 35 render tests passed; `docs/evidence/design/` (55 images) now holds the new screens in all six themes and at large text |
| `scripts\test-android.ps1` (all seven journeys, one run, final code, Pixel_7 emulator, local API with `-FoodFixtures`) | **all seven passed**: main 3 m 12 s, secondary 2 m 41 s, more 3 m 40 s, offline 1 m 40 s, device 1 m 19 s, upgrade 39 s, food 1 m 51 s |
| `scripts\verify-api.ps1 -BaseUrl http://127.0.0.1:5131` (local API on recorded provider responses) | all checks passed, including goals set / kept by an older payload / cleared, a saved food, barcode found and not found, search |
| GitHub `ci` on the branch | API build and tests, app analyze and tests, debug APK: success |
| GitHub `ios-unsigned-ipa` on the branch | success on macOS: the app compiles for iOS with the scanner and the camera permission text |

New automated coverage:

- **Provider adapters on recorded responses** (`FoodProviderTests`, no network): the shared wire sample; per-100 ml
  values not filed as grams; a stated zero stays zero; missing, estimated and mixed-basis values stay unknown;
  kilojoule-only energy; a per-serving label with and without a known serving unit; USDA IDs, units and only the
  portions that have a weight; barcode normalization; identical lookups sharing one call; cache; a provider rate
  limit pausing further calls; the shared budget; one retry and a bounded timeout; search needing a real key.
- **API on real PostgreSQL** (`FoodDataTests`): goals kept by a payload without goal fields and cleared only by an
  explicit null; older commands keep their semantic hash; a logged food keeps its snapshot when the saved food it
  came from changes; imported and corrected values told apart; saved foods owned, revision-checked, invisible to
  another account, erased with the account; lookup endpoints need a sign-in and report provider trouble as what it
  is; `food.search` declared only with a key; one person cannot spend the shared budget; upgrade from the previous
  schema keeps existing rows.
- **App on the real Drift database** (`food_test`): scaling and units; offline logging of a found food and its
  restart; a manual entry sent in exactly the old shape; saved foods offline, retried once, private per account;
  search and barcode cache used offline; six detections of one barcode are one request; goals offline and across
  restart; the compatibility gate (unknown is not a block, a confirmed block survives an offline restart and keeps
  the queue, a passing check lifts it).
- **Screens** (`food_ui_test`): search → amount → log produces one entry; cancelling logs nothing and keeps the
  search; repeated detections and a web-link code; a double tap logs once; camera refused; unknown barcode; offline;
  recent and favourite reuse; corrections kept while the amount changes; goal progress rules; Today and Eat agree;
  the update notice over an open form with the form intact afterwards; contrast, tap targets and labels in all six
  themes; twice the text size at 320 px.

Defects found by this testing and fixed:

| Found by | Defect | Fix |
|---|---|---|
| Real-database test | a lookup's shared future waited on itself, so the first search or scan never finished | the cleanup no longer returns that future |
| Real-database test | an invalid barcode or query was thrown instead of reported as a failed lookup | lookups always fail as lookups |
| Large-text test | the Meal dropdown overflowed by 59 px at twice the text size on a 320 px phone (older than this work) | it uses the full width |
| Native journey | on the scanner the typed-barcode field could be dropped from the page when the keyboard opened (the same kind of defect fixed earlier on forms) | the scanner's actions are pinned, which keeps every field built |
| Native journey | a food returned by the online search was listed twice, once as "seen before" | listed once, under Online |
| Reading the code | a stored value such as 17.25 was put back into its field as 17.3, so opening and saving an entry could change it | fields show up to two decimals, the precision stored |
| CI | the hosted runner ran out of disk building the APK with the scanner | unused toolchains are removed first |

Test-tool note: two combined emulator runs stalled with the Flutter tool unable to connect to the app after the
first journey ("taking an unusually long time to connect to the VM"), both right after the emulator was cold
restarted. The run recorded above was made on the already-running emulator and went through all seven without a
stall. An earlier combined run passed six and failed the food journey on the scanner defect listed above.

Not verified, and why:

| Item | Status |
|---|---|
| Reading a real barcode with a camera | not possible without a phone. The emulator opens the real camera view (`screenshots/97-scanner.png`) but has nothing to scan, so journeys type the digits. Repeated detections are tested with a simulated camera only |
| The camera permission prompt, refusal and return from Settings on a phone | implemented; tested with a simulated refusal. Checklist in `docs/IPHONE_TESTING.md` |
| Torch | implemented; the emulator has no torch |
| Live USDA search with a configured key | no key exists in any configuration. The adapter was written against live responses fetched once with the public demo key while building, and is tested on recordings of them |
| Signed iOS build, anything on the iPhone | unchanged: signing secrets are not set |
| TalkBack / VoiceOver by ear on the new screens | covered by label and semantics tests only |
| Emulator journeys against the live providers | by design they use recordings; the live check is `verify-api.ps1` against a deployed API (see below) |

### Merge and hosted testing API (12 October 2026)

`main` was fast-forwarded to this work (it now also contains the Calm Momentum redesign) and pushed after CI passed.
Before pushing, the Railway target was confirmed to be the rebuild's own: `gohardrebuild-production.up.railway.app`
reported exactly this project's two migrations and capability list. Railway then deployed from `main`; its
pre-deploy step applied the third migration, and the address reported `3 migration(s) applied` and the new
capabilities within a few minutes.

`scripts\verify-api.ps1` against the hosted API, with an account it creates and deletes:

| Check | Result |
|---|---|
| Readiness, contract, registration, sign-in, refusals, idempotent save | pass |
| Goals: saved, read back, kept by a payload without goal fields, cleared | pass |
| A saved food, with the journal unchanged | pass |
| **Live** barcode lookup through Open Food Facts (3017620422003) | pass: Nutella, 539 kcal per 100 g |
| Unknown barcode | pass: 404, nothing invented |
| Food search | not configured: no USDA key is set on the service, so `food.search` is not declared and search was not checked |
| Exercise catalog seeded | **fail: the hosted catalog is empty** |

The empty catalog is not part of this change (the seeding code and `api/railway.json` are untouched, and locally the
catalog has 26 movements), but it means the hosted API offers no movements to pick for a manual workout. The
migration half of the pre-deploy command ran, so the likely cause is a pre-deploy command set in the Railway
dashboard that says only `migrate`. It needs the service's pre-deploy command to be
`dotnet GoHard.Api.dll migrate seed-catalog`, or that command run once. This could not be done from here, and
whether the catalog was already empty before this deployment is not known.

To finish the hosted setup: add the variable `GOHARD_FoodData__UsdaApiKey` on the Railway service (free key from
fdc.nal.usda.gov/api-key-signup), fix the catalog seeding, then run `verify-api.ps1` again.

### Hosted API after the USDA key and the catalog were set (12 October 2026)

The owner added `GOHARD_FoodData__UsdaApiKey` on the Railway service and seeded the catalog. `scripts\verify-api.ps1`
against `https://gohardrebuild-production.up.railway.app` then passed every check:

| Check | Result |
|---|---|
| Declared capabilities | 17, now including `food.search` |
| **Live** food search through USDA FoodData Central ("chicken breast") | pass: 25 results, first "Lunchmeat, chicken breast, sliced" |
| **Live** barcode lookup through Open Food Facts (3017620422003) | pass: Nutella, 539 kcal per 100 g |
| Exercise catalog | pass: 26 movements |
| Goals, saved food, unknown barcode, idempotent save, cleanup | pass |

This is the live-provider check the fixture tests are not. It supersedes the two "not configured" and "empty catalog"
rows above.

The pre-deploy command was also verified in the API's own container image against a throwaway PostgreSQL:
`dotnet GoHard.Api.dll migrate seed-catalog` runs both steps (`Migrations applied.`, `Catalog entries: 26`,
`Readiness: Ready - 3 migration(s) applied.`, exit 0), repeating it leaves 26 rows, `migrate` alone leaves the
catalog empty, and a failed step exits non-zero. Passing the whole command as one argument starts the web server
instead of running either step.

## 12 October 2026 — Today refined (branch `feature/today-refine`)

Today now holds the day's training action, a short nutrition summary and what was recorded; the week calendar is
in Train › Plan only and Body measurements in Me only. The layout is described in `docs/DESIGN.md` ("Today: what it
holds"). App only: no API, contract or stored-data change.

| Change | Where |
|---|---|
| Compact workout card: state, name, counts, up to three movement names, recorded-set progress, one button; the title row opens the workout sheet. "View workout" row and the "Workout preview" section removed | `features/today/today_screen.dart` |
| "Your week" removed from Today; the selected week in Train › Plan gained the progress rail and percentage it had on Today | `features/plans/train_screen.dart` |
| `NutritionSummary`: calories and protein from the same coverage as Eat, goal rails only for set goals, "Some nutrition values are missing" opening Eat | `features/nutrition/nutrition_surface.dart` |
| "Recorded today" shown only when something was recorded; run and manual-workout actions sit quietly under the card; an open run reads "Continue your run" | `features/today/today_screen.dart` |
| One-line "Can't reach your account" with the waiting-changes count, expandable to the explanation and "Try again" | `features/today/today_screen.dart` |
| The food form names the amount its values are for ("Nutrition for 1 g · optional") | `features/nutrition/food_form.dart` |

Three things were looked into rather than assumed:

- **"About 45 min".** It is `setup.minutesPerSession`, the "Time available" answer from plan setup, not a figure
  worked out from the exercises. It now reads "45 min planned".
- **The connection notice.** `connectionProvider` is false whenever the last `SyncEngine.pull()` did not complete:
  no network, but also any non-success answer from the server. So "Offline" was sometimes the wrong word; the
  notice now says the account could not be reached and names both causes. What sets the state was not changed.
  Me still says "Offline right now" under the sync row.
- **A food logged as 1 g.** No calculation defect: 1 g of a per-100 g food is a hundredth of its values. A new
  entry starts at one serving (or 100 g when the food has none), and choosing "g" in the unit list keeps the "1",
  which is how 1 serving becomes 1 g. Nothing is converted and no stored entry is touched; the form now spells
  out the amount beside the values.

Checked on the final code: `flutter analyze` clean; `flutter test` 139 passed (six new in `widget_test`'s
"compact Today" group, three existing ones updated); the design renders regenerated in `docs/evidence/design/`
and looked at (six themes, twice the text size at 320 px, due, in progress, rest day, new account, Train › Plan).
On the Android emulator against the local API with recorded food responses: `journey_test`, `journey_more_test`,
`journey_offline_test`, `journey_device_test`, `journey_upgrade_test` and `journey_food_test` passed with their
captures saved. `journey_secondary_test` passed its steps on three runs, but each time Windows refused to
overwrite one screenshot that was open elsewhere on the PC (`38-plan-with-skipped.png`, then `39-block-review.png`),
so the script reported failure and the captures from 39 onward in that journey are the previous ones.

Not checked: any physical phone (safe areas with a notch or home indicator, the phone's own largest text setting,
real connectivity changes), and iPhone at all.

## 13 October 2026 — run button, natural food units, shared sync wording, journey screenshots

Second part of `feature/today-refine`. App and scripts only: the API, the contract and both database schemas are
unchanged (the server stores a food as given, so the two new optional fields on a serving need nothing from it).

| Change | Where |
|---|---|
| Today's run action is an outlined button with the running icon under the training card: "Start run" / "Continue your run". It shows on every kind of day, reads any open run from the saved records (so also after a restart or past midnight), and is the only way into a run on Today: a run still going is no longer also a row under "Recorded today" | `features/today/today_screen.dart` |
| Counting units ("2 eggs", "½ slice", "2 cups, cooked", "1 serving (15 g)"), exact conversion when the unit changes, the amount spelled out with its weight before logging and in the journal, and portions the user defines themselves | `features/nutrition/food_item.dart` (`FoodScaling`), `food_form.dart`, `food_repository.dart`, `log_food_screen.dart`; rules in `docs/FOOD_DATA.md` |
| "Can't sync right now" in Today and Me from one constant; Me no longer says "Offline right now", nor "Everything is saved to your account" while the account cannot be asked | `app/providers.dart`, `features/me/me_screen.dart`, `features/today/today_screen.dart` |
| Journey screenshots are written to a fresh folder per run and copied into the evidence folder only after the journey passed, each copy read back; a file that stays locked fails the run by name | `app/test_driver/integration_test.dart`, `scripts/test-android.ps1` |

Findings behind those changes:

- **"Offline".** The app has no way to know it. `SyncEngine.pull()` returns false for a refused connection, a
  timeout and any non-success answer alike, and nothing in the app watches the phone's connectivity. So no screen
  claims it now. The connection logic itself was left alone: it reports what it knows (the last attempt failed),
  and no defect was found in that. The food search screen still says "You are offline" when a lookup cannot reach
  the server; that wording was outside this change and has the same weakness.
- **1 serving becoming 1 g.** Reproduced as described on 12 October: the number stayed when the unit changed. The
  unit list now converts, and because every unit offered is defined against the food's one basis there is no
  pair of units without a conversion. A serving with no stated weight never offered grams and still does not.
- **The screenshot lock.** Reproduced outside the journeys: rewriting the tracked PNGs while `git status` runs
  fails a few times in every ten thousand writes with the same Windows error (1224, a file with a mapped section
  open). Git maps a changed file into memory to hash it, and the editor's source-control view runs `git status`
  whenever a file in the repository changes, which is exactly when a journey is writing its captures.
- **Restart in a journey** means running the app's `main()` again in the same process, as `journey_food_test`
  already did. The run, its clock and its measured distance are read back from the phone's database; an actual
  process kill by the system is not exercised.

Checked on the final code:

| Check | Result |
|---|---|
| `scripts\test.ps1` (the required final suite) | API build with warnings as errors, 83 of 83 API tests on disposable PostgreSQL, release publish, `flutter analyze` with no issues, 147 of 147 Flutter tests |
| New Flutter tests | `food_test`: counting units and fractions; unit changes both ways with equal values; unknown conversions not offered; user-defined portions; a portion kept offline, across restart, to the account and on the favourite, with the earlier meal byte-for-byte unchanged. `food_ui_test`: unit change in the form; defining a portion; a food met again offers it; a draft survives a theme change. `widget_test`: the run button on a day without a plan and on a rest day with an open run; Today and Me wording |
| Existing guideline tests (contrast, 48 px / 44 pt targets, labels) on the food form in six themes, and no overflow at twice the text size on 320 px | pass, now including the amount line and "Add your own portion" |
| Design renders | regenerated and looked at: Today and the food form in six themes and at large text |
| Android emulator, local API with recorded food responses | all seven journeys pass and exit 0, every capture fresh: secondary 13, main 26, food 13, offline 5, more 10, upgrade 3, device 4 |

The device journey leaves an open run, sees "Continue your run", restarts, continues the same run with its
distance kept, and finishes it (`screenshots/51b-today-continue-run.png`). The food journey changes one cup to
158 g and back and defines "1 spoon = 20 g" (`93a-…`, `98b-…`). The offline journey reads the same words on Today
and Me (`71-…`, `71b-…`).

Twice during these runs the Flutter tool could not attach to the app on the emulator ("Service has disappeared",
"taking an unusually long time to connect") before any step ran; no crash was recorded on the device. Restarting
the emulator cleared it, and the affected journeys then passed.

Still not checked, and not claimed: anything on a physical phone (notch and home-indicator safe areas, the phone's
own largest text size, TalkBack or VoiceOver by ear, the on-screen keyboard over the portion dialog on a small
phone, a real walk with GPS, real loss of signal) and anything on an iPhone beyond the unsigned build compiling.


### CI and merge (13 October 2026)

CI run 18 passed on `31a4a81` (API job and app job, including the debug APK build). This note was then added as a
documentation-only commit, which went through CI again before `main` was fast-forwarded to it and pushed. The API
code is unchanged, so the hosted testing API redeploys the same service; before the push it reported
`Ready, 3 migration(s) applied`. The unsigned iOS build is started from that final commit with the
`ios-unsigned-ipa` workflow; its run and artifact are in the Actions tab under that commit.

## 13 October 2026 — Today with photo cards (branch `feature/today-photo-cards`)

Built from the brief in `gohard-today-photo-design/` (kept in the repository with its references and its
`ASSETS.md`). Flutter presentation and bundled assets only: no API, contract, sync or stored-data change. The final
layout and its rules are in `docs/DESIGN.md` ("Today: what it holds").

| Change | Where |
|---|---|
| Workout card: photograph header with WORKOUT, the real name and the state; below it a summary, up to three movements with their prescription, per-movement recorded counts while in progress, the recorded-set rail, one Start or Resume button; "See all N exercises" or "Workout details" opens the existing sheet or record | `features/today/today_screen.dart` (`_WorkoutCard`) |
| Rest day, paused plan, not started, block review, draft and no plan keep a card without a photograph | `_PlainCard` |
| Run card: photograph, real state, "Start run" or "Continue run" for the saved open run; the only run entry on Today | `_RunCard` |
| Nutrition card: photograph, "No food logged today" or the same calories, protein, goal rails and missing-values line as before, "Food journal" link, "Log food" | `_NutritionCard`; `NutritionSummary` in `features/nutrition/nutrition_surface.dart` now returns the values only |
| Run and Nutrition side by side while both are short, stacked for logged food, large text or a narrow phone | `TodayScreen.build` |
| Three supplied WebP photographs added; `evening-gym-hero.jpg` removed | `app/assets/images/` |
| A two-phase journey for a real cold start | `integration_test/journey_coldstart_test.dart`, `scripts/test-android.ps1` |

**Photographs.** The three files are byte-for-byte the ones in the brief (SHA-256 as in its `assets-manifest.json`),
1536 × 1024 WebP, 688,604 bytes together; the JPEG they replace was 200,936 bytes, so the app's assets grow by
about 0.49 MB. They are generated editorial illustrations made for this design, not stock, and not anyone's
workout, route or meal. Decoded at the phone's width (at most 1536 px wide), one decode per image shared by every
layout; that is about 4 MB of pixels per image on a 3× phone. Measured memory on a device was not taken.

**Decisions the brief left open.** Movement rows are not buttons, because the app has no page for a single
movement. Nothing marks a movement as current or complete; only counts are shown. Companion cards use outlined
buttons so the workout keeps the one filled button. The two cards stack once food is logged rather than squeezing
goal rails into half a screen. A single finished run is said on the Run card and no longer also listed under
"Recorded today". "Run history" was added as a quiet link in the side-by-side Run card; it opens the existing
screen.

Checked on the final code:

| Check | Result |
|---|---|
| `scripts\test.ps1` | API build with warnings as errors, 83 of 83 API tests, release publish, `flutter analyze` with no issues, 150 of 150 Flutter tests |
| New or rewritten Today tests (`widget_test`) | due workout with three rows, prescriptions and "See all 5"; in progress with per-movement and total counts, 33%, one Resume, rows not tappable, no completion icon; manual workout with unknown total (no percentage, no "of"), a long name at 320 px, four movements, none yet; completed and rest-day states; Start run / Continue run with real time and distance; side by side against stacked for empty, goals, logged food, 160% text, 320 px, and 200% text with food |
| Existing guideline tests on Today in six themes | rendered-pixel text contrast, 48 px and 44 pt targets, labelled controls: pass |
| Renders (`docs/evidence/design/`), regenerated and looked at | `six-themes-today`, `today-blue-light`, `today-blue-dark`, `state-full-today-light`, `-dark`, `state-today-due-light`, `state-today-due-no-food-open-run-pink-dark`, `state-today-due-no-food-green-light`, `state-today-done-light`, `state-today-rest-dark`, `state-today-manual-one-exercise-dark`, `state-today-narrow-320-no-food`, `state-large-text-today-320`, `state-new-account-today` |
| Android emulator, local API with recorded food responses | all eight journeys pass and exit 0 with fresh captures written to a new folder per run and copied only after passing |

**Cold start.** `journey_coldstart_test` runs twice on one install. Phase 1 leaves a manual workout open with one
set, one logged food and an open run; the script then force-stops the app, confirms no process is left and the
install is still there. Phase 2 is a new process: with no sign-in it shows "Continue run", "Resume workout",
"1 set recorded" and "1 food logged", continues and finishes that run, and reopens the workout with its set
(`screenshots/110-…`, `111-…`, `112-…`). This is a real process restart, unlike the other journeys' second call of
`main()` in one process. Two things were learned on the way: the Flutter tool uninstalls the app when a drive run
ends (so phase 1 keeps it running and the script kills it), and the first run's debugger port forward has to be
removed or the tool cannot attach to the new process.

During these runs the tool again failed once to attach to the app before any step ran; the journey passed when
run again. One journey step still said "No food logged yet" and was updated to the new wording.

Not checked, and not claimed: anything on a physical phone (how the three photographs crop on real screen sizes,
notch and home-indicator safe areas, the phone's largest text size, TalkBack or VoiceOver by ear, memory while
scrolling, a real run with GPS) and anything on an iPhone beyond the unsigned build compiling. The side-by-side
layout was rendered at 390 px and on the emulator's 411 px; other widths between 350 and 430 px were not rendered.


## 13 October 2026 — refined design on all four tabs, motion and haptics, common-food search (branch `feature/ui-food-search-refine`)

From the brief in `C:\dev\GoHard_UI_Food_Search` (`CLAUDE_PROMPT.md`, `FOOD_SEARCH_DETAILS.md`, `RESEARCH.md`,
`ASSETS.md`, five reference concepts). Started from `main` at `76623f7`; baseline `scripts\test.ps1` on that commit:
83/83 API tests, analyze clean, 150/150 Flutter tests. Built by four agents in separate worktrees (visual system and
Me; food discovery; Today and Eat; Train and workouts), each merged and checked by the lead. No API, contract,
database or migration change: the hosted API needs no redeploy for this work.

| Change | Where |
|---|---|
| Calmer tokens (pearl and charcoal surfaces), rounded-rectangle buttons, flat pass, one motion system (press 100 ms at 0.98, content 200 ms, sheets 280 ms, progress 360 ms only on a real change), shared `Pressable`, `TabHeader`, `IconTile`, `GroupCard`/`GroupRow`, `showGoSheet` | `core/theme.dart`, `core/widgets.dart` |
| Me › Motion & haptics: Motion Device/Reduced, Haptics Device/Off, a device setting (not the profile); Reduced behaves like the OS setting everywhere | `core/device_prefs.dart`, `app/app.dart`, `main.dart` |
| Me: identity, Personal, Preferences, Account with a truthful sync status; no training dashboard (moved to Train) | `features/me/me_screen.dart` |
| Today: three balanced modules (workout, run, nutrition) with small photo crops; text-first states without photos; no exercise list | `features/today/today_screen.dart` |
| Train: pass, every week of any plan length, Done only from recorded results, dated schedule with labelled states; Workout and Run history always in Workouts | `features/plans/*`, `features/workout/*` |
| Eat: one overview card, one Log food, each meal a group with one row per logged food | `features/nutrition/eat_screen.dart`, `nutrition_surface.dart` |
| Add food: meal selector, quiet scopes, category chips, plain rows, "Search more foods", truthful failure states, stale answers dropped | `features/nutrition/log_food_screen.dart`, `food_search.dart` |
| 74 common foods, each a USDA FDC record taken from the hosted API's search, bundled for offline use; relevance with English and French aliases | `app/assets/data/common-foods.json`, `scripts/build-common-foods.mjs`, `docs/COMMON_FOODS_COMPARISON.md` |
| The food form keeps the exact quantity when the unit changes (100 g → cup → 100 g, was 99.54) | `features/nutrition/food_form.dart`, `FoodScaling.exact` |

**Catalog.** 74 foods cover 75 of the original 76 names; "Protein bar" has no generic USDA record and "String
cheese" is the part-skim mozzarella record. Records were chosen by review (whole egg, cooked skinless breast, plain
cooked rice), not by first hit. 120 searches through three disposable accounts on the hosted testing API, each
deleted afterwards. Values that differ from the original seed (ground beef cooked vs raw, firm tofu, whey) follow
the record. No gram-to-millilitre density or portion was invented; records without a count portion start at 100 g.

**Found by the native journeys and fixed in the app** (each with a test that fails without the fix):
- After recording a set, the Undo message never timed out (an action makes a SnackBar persist) and covered
  "Save for later". It now times out after 4 s.
- A food the wider search had just returned moved into "Your foods" as soon as it was cached as seen.
  It now stays under "More foods".
- A planned workout done today appeared in the Workout module and again under "Recorded today". The credited
  workout is now left out of that list by its identity; manual work and other attempts stay listed.

**Journey corrections** (the app was right):
- The reschedule step tapped a day number that the Train page underneath also shows, which closed the date picker.
  The tap is now scoped to the picker; the date-picker and move-review steps are unchanged.
- The offline wording check now reads only Today's connection notice and Me's sync row, so the account name
  "Offline Tester" cannot trip it.
- Cold start checks the food's calories, since Today no longer counts foods.
- After a restart the food journey checks a never-logged common food, and that the logged eggs appear once as the
  account's own.

Checked on the final code:

| Check | Result |
|---|---|
| `scripts\test.ps1` | API build, 83/83 API tests, release publish, analyze clean, 238/238 Flutter tests |
| Renders (`docs/evidence/design/`), regenerated and looked at | every main screen in six themes, large text at 320 px, new account, 8/12/16-week plans, sheets, Add food with results and preview |
| Android emulator, local API with recorded food responses | all eight pass on f72e258: main, secondary, more, offline, device, upgrade and food in one serial run; cold start (both phases, a real process restart) on its own straight after, because in the serial run the Flutter tool hung attaching to phase 2's new process before any step ran. Earlier attempts on the same code also hit the tool's attach failures ("Service has disappeared", a stale adb port forward left by the cold-start journey); clearing the forwards fixed them. No app step failed in the final runs |
| Reduced motion | every animation's duration goes through `context.motion`; nothing repeats; the tab fade keeps the `IndexedStack` (source review plus `motion_test`) |

Not checked, and not claimed: anything on a physical phone (brightness comfort, real haptics, the photographs on
real screens, VoiceOver/TalkBack by ear, scrolling smoothness and image memory, the camera reading a real barcode),
profile-mode frame timing, and anything on an iPhone beyond the unsigned build compiling.

**Release (13 October 2026).** `feature/ui-food-search-refine` pushed; `ci` passed on `af0594d`
(run 38503391974). `main` fast-forwarded from `76623f7` to `af0594d` and pushed; `ci` on `main` passed (run
38504519886). Hosted testing API (`https://gohardrebuild-production.up.railway.app`, no API code changed):
`verify-api.ps1` passed every check, including live USDA search ("chicken breast", 25 results) and a live Open Food
Facts barcode, and deleted its account. Unsigned IPA built from `af0594d` by `ios-unsigned-ipa` (run 38504529395,
artifact `GoHard-Dev-unsigned-ipa`): it compiles; it is not signed and was not installed on an iPhone.

## 14 October 2026 — Daily Rhythm design and weather-aware Today (branch `feature/daily-rhythm-weather`)

From `C:\dev\GoHard_Daily_Rhythm_Weather` (brief, weather requirements, assets, food behaviour to keep, seven
references). Started from released `main` at `af0594d`. Five agents in separate worktrees (visual system and Me;
weather end to end; Train; food search and portion form; Today, Eat and run), each merged and checked by the lead.

| Change | Where |
|---|---|
| Warm light and charcoal-plum dark tokens; DM Serif Display (SIL OFL 1.1, from the official Google Fonts repository, sha256 in `app/assets/PROVENANCE.md`) for page titles only; floating rounded navigation; `ProgressRing`, `RhythmTimeline`, `ChoiceCard`, round icon tiles | `core/*`, `features/shell/*`, `app/assets/fonts/` |
| Me and Appearance per the references; Appearance has a static preview that starts nothing and a "Today background" row | `features/me/*` |
| Today: scene header, a continuous rhythm of Workout (ring of recorded planned sets), Run and Nutrition | `features/today/today_screen.dart` |
| Train and Eat: static scenic headers, serif titles, the pass, the calorie ring, grouped meals | `features/plans/*`, `features/nutrition/eat_screen.dart`, `nutrition_surface.dart` |
| Add food and the portion form: the reference layout, with source details behind "Food details" and a nutrition read-out you can correct | `log_food_screen.dart`, `food_form.dart` |
| Weather: Open-Meteo through the API (coordinates rounded to 0.1° before cache or provider, never logged; 20-minute region cache; 400 calls an hour; optional capability `weather.current`); device setting Scenic / Weather / Plain with Automatic or Selected city; 30-minute refresh, 60-minute freshness; graded scenes of the one dusk photograph | `api/.../Application/Weather/*`, `app/lib/features/weather/*`, `docs/WEATHER.md` |

**Fixed during integration:** the first backdrop laid a 66–87% veil over the scene and the header's own scrim on top
of it, so every weather scene looked the same. The veil is now 18–34% and the contrast test measures the scene with
the header scrim where the text is, keeping 7:1 in all six looks.

**Provider.** Open-Meteo's free API is for non-commercial use (this testing deployment), with daily limits and no
uptime guarantee; data CC BY 4.0, credited in the setting. Live check 14 October 2026 03:22 UTC: Quebec City and
Sydney at the same UTC instant, and "Paris" returning France, Texas, Tennessee and others; those answers are the
recorded fixtures.

Checked on the final code (`a6ab9d7`):

| Check | Result |
|---|---|
| `scripts\test.ps1` | API build, 118/118 API tests (35 weather), release publish, analyze clean, 283/283 Flutter tests |
| Renders, looked at against the references | six themes for every tab, Appearance, Add food, the portion form; Today over clear day/night, rain, snow, fog and storm in light and dark; large text at 320 px; 8/12/16-week plans |
| Android emulator, local API with recorded food and weather answers | all eight journeys pass: seven in one serial run (main, secondary, more, offline, device, upgrade, food); cold start (both phases, a real process restart) in a separate run, after the Flutter tool hung attaching to phase 2 and then lost phase 1's connection ("Service has disappeared") before any step. `journey_more_test` now chooses Weather for a city mid-workout |

Not checked, and not claimed: the Automatic weather location on a device (permission prompt, denial, a real fix),
real local weather accuracy, brightness comfort, real-device safe areas, haptics, screen readers by ear,
performance and image memory, a real barcode with a camera, and anything on an iPhone beyond the unsigned build.

## 14 October 2026 — visual follow-up (branch `feature/rhythm-visual-followup`; `main` stays at `e6e43a8`)

| Change | Where |
|---|---|
| Real-app capture journey: Today, Train › Plan, Eat, Me, food search and the portion form in Blue Light and Pink Dark, each from its top | `integration_test/journey_captures_test.dart`; captures in `docs/evidence/captures/release-e6e43a8/` (before) and `docs/evidence/captures/followup/` (after) |
| Weather scenes: painted skies behind the one photograph's silhouettes, so clear (sun / stars and moon), cloudy, rain (static streaks), snow (static flakes, whitened shore), fog (haze bands) and storm each have a distinct day and night look; static, no animation | `features/weather/sky_painter.dart`, `scene_art.dart`, `backdrop.dart`; `test/weather_distinct_test.dart` measures every pair |
| Scene behind the status bar on Today, Train and Eat, with a status-bar veil; Me starts below the inset | `features/shell/home_shell.dart` (`StatusBarVeil`), `TabHeader.topOnBackdrop`, the three headers, `me_screen.dart` |
| Today's Run and Nutrition put their photo beside the label; the due summary no longer wraps | `features/today/today_screen.dart` |
| Calories shown in whole kilocalories, grouped, everywhere (display only); Me's goal reads "2,200 kcal" like Eat | `formatKcal` in `nutrition_surface.dart`, `eat_screen.dart`, `me_screen.dart` |

Measured: status-bar icons ≥ 11.2:1 and header text ≥ 9.0:1 against the worst pixel of every scene in all six looks;
smallest scene-to-scene difference 0.034 per pixel / 0.19 histogram (threshold 0.03 / 0.15). Today at 390 × 844 with
a 47 px status bar: workout 232, run 145, nutrition 213 in the fullest state; nutrition's calorie line ends above the
navigation bar.

Checked on `a3091f1`:

| Check | Result |
|---|---|
| `scripts\test.ps1` | 118/118 API tests, analyze clean, 287/287 Flutter tests |
| Renders | regenerated; six themes, scene contact sheets (6 weathers × day/night/neutral, Light and Dark), large text at 320 px |
| Android emulator | all eight journeys pass: main, secondary, more, offline and device in one serial run; upgrade, food and cold start (both phases) one by one straight after, because the Flutter tool hung connecting to the app before the upgrade journey's first step (as before: tool-side, no app step failed). Capture journey passes |

Not checked: the scenes on a physical phone (brightness comfort, real status-bar heights and notches, performance),
anything on an iPhone. The scenes remain painted treatments of one photograph, not separate photographs.

## 14 October 2026 — weather diagnosis and moving skies (branch `feature/weather-motion`, from `main` at `28a66c5`)

The reported problem: on the iPhone (IPA build 11 = `main` at `28a66c5`, which includes the visual follow-up),
Today's background showed the wrong weather and had none of Apple Weather's look or motion. Diagnosis and fixes are
in `docs/WEATHER.md` ("Diagnosis"); in short:

| Cause | Fix | Regression test |
|---|---|---|
| The hosted API answered `PROVIDER_RATE_LIMITED` for every place (Open-Meteo limits per calling IP; the cloud IP is shared) | MET Norway answers when Open-Meteo refuses or fails; day/night from its symbol or the sun at the place | `WeatherTests.When_Open_Meteo_refuses_MET_Norway_answers_and_says_so`, `…double_failure…`, `MET_Norway_current_hour_maps…`, `The_sun_says_day_or_night…` |
| WMO 2 (partly cloudy) painted as overcast | scene chosen by WMO code; a partly cloudy sky of its own | `weather_scene_test: the scene follows the WMO code…`, `today_ui_test: the sky line names real weather…` |
| A silent fallback that looked like weather | "Scenic view · <reason>" on Today; "What the scene is based on" in the setting | `weather_scene_test: … says why`, `today_ui_test: the sky line …` |
| Night at the place looked like day in Light mode | header text, scrim and status bar follow the sky | `weather_scene_test: a dark sky follows …`, `today_ui_test: a clear night stays a night …`, `weather_contrast_test` |
| Automatic kept an answer for where the phone was before | re-ask when the last known position is in another area; 15-minute refresh, 10-minute server cache | `weather_refresh_test: Automatic asks again when the phone has moved …` |

Also: moving skies (drifting clouds, falling rain and snow, sliding fog, twinkling stars) that stop for Reduce Motion,
a hidden tab, a page on top and the background (`weather_motion_test`); the iOS build stamps commit and run number,
shown on Me.

Checked on the final code (`70ee36b` for the app and API; later commits are docs, evidence and a capture journey):

| Check | Result |
|---|---|
| `scripts\test.ps1` | 126/126 API tests (8 new weather), analyze clean, 296/296 Flutter tests |
| Android emulator, recorded provider answers | all eight journeys pass, one after another; journey_test and journey_device_test each needed one retry after the Flutter tool lost its connection (journey_test's app side had already reported "All tests passed!") |
| Live, emulator against the local API with the real providers | Halifax fog (WMO 45), Quebec City overcast, Sydney partly cloudy at night: screenshots `docs/evidence/screenshots/live-*.png`; recording `docs/evidence/recordings/today-weather-live.mp4` (116 s, three cities, the moving skies) |
| Hosted API before the fix | `PROVIDER_RATE_LIMITED` for three cities, while Open-Meteo answered directly |

Not checked: the iPhone itself (the user's location permission and mode, the scenes on its screen, motion smoothness
and battery, ProMotion), and the hosted API with the fix until it is deployed from `main`.

## 15 October 2026 — full-screen weather on Today (branch `feature/full-screen-weather`, from `main` at `2ae6660`)

The approved direction: weather fills the whole of Today with readable content; the other tabs share the visual
system on calm backgrounds. Design notes: `docs/DESIGN.md` › Today, Train, Eat.

| Change | Where | Regression test |
|---|---|---|
| Today's scene fills the tab: top edge, behind the status bar, sections and floating bar; fixed while the page scrolls; no fade into a solid body | `today_screen.dart` (`Stack` + const `TodayBackdrop`), `backdrop.dart` (even veil, no fade), shell `extendBody` | `today_ui_test: Today's scene fills the whole screen … stays put while the page scrolls` |
| One translucent surface for Workout, Run, Nutrition and Recorded today: app-mode surface at 92% over one 18 px blur | `_Surface` in `today_screen.dart`, `GoColors.panelOpacity` | `weather_contrast_test: Today's surface keeps its text readable …` (all six looks × 22 scenes, worst pixel, blur not counted): text ≥ 11:1, secondary ≥ 5.8:1, accent ≥ 4.6:1 |
| Sections keep the app's look whatever the sky; header follows the sky | `_Header` | `today_ui_test: weather light/dark: every scene changes the backdrop only …` |
| Only Today has a scene: `ScenicBackdrop` removed; Train and Eat on a calm wash, Me on the plain page; one title position on all tabs (`TabHeader.topInset`) | `widgets.dart` (`QuietBackground`), `theme.dart` (`GoColors.wash`), `train_screen.dart`, `eat_screen.dart`, `me_screen.dart` | `today_ui_test: only Today has a scene …`, `theme_test` (text, secondary, status and accent on the wash), `eat_ui_test` |
| Every list ends above the floating bar | the four tabs | `today_ui_test` (Today's surface and Me's Sign out clear the bar) |
| Buttons 18 px side padding (was 22), so "Resume workout" stays on one line on the surface; Today's photos 84 px (was 92) | `theme.dart`, `_Module` | `today_ui_test` heights: workout 244, run 145, nutrition 213 |

Unchanged: condition selection, provider fallback, location privacy, caching, freshness, day/night, motion gating
(Reduce Motion, the app's Motion setting, hidden tab, covered route, background), food, portions, goals, history, sync,
recovery, API and database.

Evidence (`docs/evidence/`):

- Before / after app captures from the Android emulator with a real account on the local API, Blue Light and Pink Dark:
  `captures/full-screen-weather/before/` (made from `main` at `2ae6660` in a separate worktree) and `.../after/`:
  Today, Train › Plan, Eat, Me, food search, the portion form, and Today scrolled to its end. **Simulated weather:**
  the API ran with `-FoodFixtures`, so every place gets the recorded Open-Meteo answer (overcast, night).
- `recordings/today-full-screen-scroll.mp4` (30 s, emulator, same recorded overcast night): Today held still, then
  scrolled down and back while the clouds move. **Simulated weather.**
- `design/state-today-weather-*-{light,dark}.png` (every family, day and night), `six-themes-*.png`,
  `state-large-text-*-320.png`, `state-new-account-*.png`: widget renders with fixture data and fake weather.
  **Simulated.**
- No new live-provider evidence in this change; the earlier live captures (`screenshots/live-*.png`,
  `recordings/today-weather-live.mp4`) show the provider path, which is unchanged.

Not checked: scrolling smoothness, blur cost and battery on a physical iPhone (ProMotion, Impeller) — the emulator
reported long frames ("Davey!") during the journeys, which it does on `main` too and says nothing about a phone.

Checked on the final code of this branch:

| Check | Result |
|---|---|
| `scripts\test.ps1` | API: release build, 128/128 tests on disposable PostgreSQL, publish. App: analyze clean, 303/303 Flutter tests |
| Android emulator, recorded provider answers | all eight journeys pass. In the serial run `journey_offline_test` timed out once waiting for the conflict review notice (the save had not yet come back as a conflict) and passed when run again alone; the script stops at a failure, so device, upgrade, food and cold start were then run one by one, all passing. `journey_captures_test` passes (before and after captures, recording) |
| Renders | `render_test` with `GOHARD_RENDER=true`: 98 renders, six looks, every weather family day and night, large text at 320 px, new account |

## 16 October 2026 — plan builder: templates, own plans, fixed weekdays and rotating sequences (branch `feature/train-plan-builder`, from `main` at `0364df0`)

Design, wire contract and rules: `docs/TRAINING_PLANS.md`. Task rows T1–T6 in `docs/TASK_MATRIX.md`. Work was split by
file ownership: the lead wrote the contract, the shared fixture cases, the starter templates and the phone-side domain
core (`plan_rules`, `plan_projection`, `plan_draft`, repository commands); one agent built the API side
(`agent/plan-api`), one the builder screens (`agent/plan-builder`), one the Train/Today/workout integration
(`agent/plan-train`); a fourth reviewed the integrated branch. Every branch was merged and re-checked as a whole.

What changed for the user:

- Train › Plan › Create plan: "Start from a template" (Full Body, Upper / Lower, Push / Pull / Legs, Push / Pull with
  legs, Upper / Lower + PPL, Body-part split, Custom; suggested by available days, equipment variants) or "Build my
  own"; four steps (Availability, Structure, Workouts, Review) saved on the phone after every change.
- Workout definitions apart from occurrences: three definitions on six days are six independently completable
  occurrences (UUIDv5 IDs computed identically on phone and server). Fixed weekdays (finite) or a rotating sequence
  (finite or ongoing) that advances only on a credited finish or an explicit skip.
- Workout editor: rename, duplicate, delete, reorder by buttons; add, replace, remove, reorder exercises; sets, rep
  range or time, rest, optional weight target, notes; copy from another workout; private custom exercises.
- Edits apply from an effective date (never before today) or to one occurrence; recorded, skipped, in-progress and
  earlier occurrences and every recorded workout stay as they were. A reviewed swap also updates a fixed plan's
  workouts. Edit drafts made before the plan changed elsewhere are not saved over it.
- Today and Train read one projection; rotations show cycle position and this week, never an overall percentage.
  The workout screen shows the plan's target apart from the last performance; history shows which plan and session.

Decisions: additive migration `20261014220940_AddPlanBuilder` (new nullable columns, one table, unique
`(PlanId, SequenceIndex)`); capabilities `plans.builder`, `exercises.custom`; contract version stays 1 (older builds
keep working; `plan.draft.update` on a built plan → `PLAN_NEEDS_NEWER_APP`; older commands keep their semantic hash);
25 catalog movements added by the idempotent `seed-catalog`; the old setup questionnaire is gone from the app (the
server keeps it for older builds).

Review findings fixed before merge (`8a691ca`, `6b1f8c5`): a saved-for-later step advanced the rotation in Train;
a stale edit draft could overwrite newer plan content or use a past effective date; a swap kept the old exercise's
weight target on occurrences; rotation undo-skip ignored later steps started offline; a step moved before the
effective date could be dropped; a revise could remove an occurrence a no-data attempt pointed at.

Checked on the final code:

| Check | Result |
|---|---|
| `scripts\test.ps1` | API release build, 162/162 tests on disposable PostgreSQL (34 new), publish. App: analyze clean, 387/387 Flutter tests (60+ new) |
| `verify-api.ps1` against the local API on the new schema | every check passes, including the new plan-builder check (custom exercise, rotating plan, step 0 started and credited, revise), account deleted |
| Native `journey_plan_test` (new, two processes) | passed. Phase 1 offline: template preview, customisation (4 sets, 60 kg target, replaced exercise, own exercise), activation, a set recorded; force-stop; phase 2: plan and open set recovered, synced once, finished, move, edit from today, own rotating plan replacing the first after confirmation, skip advances one step, dark captures. Earlier attempts: one tooling hang before any step ("unusually long time to connect to the VM", stopped), two assertion fixes in the journey itself |
| Native, the eight existing journeys (adapted to Create plan) | all pass, in separate runs: a serial run passed `journey_test`, `journey_secondary_test`; `journey_more_test` reported "All tests passed!" on the app side and then the driver lost the VM service ("Service has disappeared"), so it was re-run alone and passed; then `journey_offline_test`, `journey_device_test`, `journey_upgrade_test`, `journey_food_test`, `journey_coldstart_test` each passed alone |
| Native `journey_plan_large_test` (captures only) | emulator at font scale 1.5 and 360 dp wide: builder steps, prescription sheet, Plan, Today; settings restored afterwards |

Evidence (`docs/evidence/screenshots/`, all native Android emulator captures against the local API; weather answers are
recorded responses, not live): `p01`–`p08` template path and recovery (light), `p09` edit scope, `p10`–`p14` own
rotation and Today, `p15`–`p19` dark, `L1`–`L7` large text on a narrow phone. The green outline around a focused
element in captures is the emulator's focus highlight from the test driver (present in earlier captures too). Fixture
renders are separate (`docs/evidence/design/`) and were not regenerated for this change.

Not checked: anything on a physical iPhone (VoiceOver, keyboard, safe areas, comfort, performance).

Release (same day): CI `ci` passed on the branch (run 43) and on `main` (run 44) at `95331ca`; `main` fast-forwarded
`0364df0..95331ca` and pushed. The hosted testing API (Railway, pre-deploy `migrate seed-catalog`) reported
"4 migration(s) applied" and `plans.builder`; `verify-api.ps1 -BaseUrl https://gohardrebuild-production.up.railway.app`
passed every check, including the plan-builder check and "Exercise catalog is seeded - 50 movements", and deleted its
disposable account. Unsigned IPA: `ios-unsigned-ipa` run 38669092093 (run number 15) on `main` at `95331ca`, artifact
`GoHard-Dev-unsigned-ipa` (`GoHard-Dev-unsigned-15.ipa`); Me shows "build 15 · commit 95331ca". Not signed: install
with Sideloadly and your Apple ID. Physical-iPhone checks of the plan builder have not been performed.

## 15 October 2026 — truthful Today, Guide me, Ask GoHard, Leon and Leona (branch `feature/coach-today`, from `main` at `1e3991e`)

Reported from an iPhone (build 15): users need help choosing splits and exercises; a manual workout made the planned
workout disappear from Today; skipping today's workout put the next one in its place; rest days were not said.
Semantics: `docs/TRAINING_PLANS.md` › Today; guide/AI split and contract: `docs/COACH.md`; design: `docs/DESIGN.md`.
Task rows T7, C1–C3.

**Diagnosis first** (reproduced through the real repository on real Drift with the fake account, state dumped
before/after; the reproduction failed on the old code and is now `today_states_test`):

| Report | Stored state before → after | Layer |
|---|---|---|
| Manual workout hides plan | plan JSON byte-identical; occurrence still Due; manual session has no occurrence link | Today selection: any open workout replaced the plan card |
| Rotating skip | k=0 materialized Skipped, rotation advanced exactly once (correct); successor k=1 projected date moved 14 → 12 Oct | phone projection: "a skip takes no day" (Train affected too) |
| Fixed skip | occurrence Skipped, later dates unchanged | Today selection: fell through to "Rest today" |

No server, sync-replay or stale-cache cause. Fixed in `resolveTraining`/`planOccasions`, the shared code Today, Train
and the occurrence sheet all read. Three older tests and two journeys asserted the reported behaviour and were changed.

**Team**: the lead wrote the contracts (`docs/COACH.md`, `coach_contract.dart`, avatar stubs) and did the Today work;
four agents in separate worktrees built the API (`agent/coach-api`), the avatars and hints (`agent/coach-avatar`),
Ask GoHard (`agent/coach-ask`) and Guide me / Quick guide (`agent/coach-guide`). Integration found and fixed: Ask
GoHard built its network client on open (now only at Send); the hint floated over the Structure step (now in the
page flow); journeys had to choose "I know what I want" first; the guide's content replaced the API placeholder.

**Checks** (actual results):

- `scripts\test.ps1`: API build + 171/171 tests (9 new coach tests) on disposable PostgreSQL, release publish; Flutter
  analyze clean; Flutter 451/451 after the integration fixes (first integrated run: 450/451, the failure above).
- Native, Android emulator against the local API on this branch (`-FoodFixtures`, no AI key): all nine default journeys passed — `journey_test` in the full run (after changing its "Done for today" to the now-correct "Partly completed"); the full run then stopped when `journey_secondary_test` passed every step and the driver lost the VM service ("Service has disappeared"); the rest were run one at a time with `-Only`: secondary, more, offline, device, upgrade, food (second attempt; the first hung 27 min attaching), cold start (second attempt, both phases; the first hung in phase 2), plan (both phases: rotation skip keeps "Skipped today", "Next in your rotation: Pull day · Saturday", Train this now, Undo skip — `p14-today-after-skip`). New `journey_coach_test` (not default) passed on its third attempt (first: attach hang; second: the journey's own sheet-closing tap hit the builder's back arrow, fixed): Leona chosen, Create plan choices, guided suggestion with the in-page hint, Compare, Why, Ask GoHard unavailable with the question kept, exercise quick help, planned rest day with a manual workout open (captures `c01`–`c13`).
- CI `ci` on `e983487`: success. CI on the final commit `3ed8a87`: success (run 38765795876). `main` fast-forwarded to `3ed8a87` and pushed; Railway deployed it (ready, 4 migrations — no new migration). Hosted `verify-api.ps1`: first run all PASS except food search (USDA answered 503 PROVIDER_UNAVAILABLE; a direct retry gave 200, 200, 503 — upstream, intermittent); second run passed every check; coach reported NOT CONFIGURED. Both runs deleted their accounts. A manual retry with wrong routes left one empty disposable account (verify-<8 hex>@example.test, no data) that could not be deleted without its email. IPA: `ios-unsigned-ipa.yml` on `main`, build 16, commit `3ed8a87`, artifact `GoHard-Dev-unsigned-ipa` (11.8 MB, unsigned), https://github.com/abdbabti01/GoHardRebuild/actions/runs/38767961986.

**AI**: not configured anywhere. Every AI answer in tests is a fixture; the native coach journey verified only the
honest unavailable state. Live AI is **not verified**. To enable: `GOHARD_Coach__AnthropicApiKey` on the API (Railway
service variable, or `Coach:AnthropicApiKey` in `appsettings.Local.json`); model `claude-haiku-5-5` by default
(`Coach:Model`), 40 questions per account per day (`Coach:DailyLimit`). An `OPENAI_API_KEY` present on this machine
was deliberately not used. During the API work Docker Desktop needed a restart (WSL update); other containers
came back unchanged.

**Artwork**: originals in `design/coach/` (sha256 match the handoff manifest); runtime PNGs (alpha kept) — Leon
avatar 192² 63,005 B, Leona avatar 192² 56,359 B, Leon full 202 × 420 116,520 B, Leona full 202 × 420 108,286 B.
Decoded at drawn size. Motion: only the hint's 200 ms fade/scale entrance (instant under reduced motion). Static
art: nothing talks, blinks or walks. Known limits: charcoal clothing is low-contrast on dark surfaces for the full
figure (the avatar has a backdrop); Appearance previews are 36 px.

**Content**: `coach-guide.json` (7 splits, 50 exercises, 10 terms; sources ACSM 2009 PMID 19204579 and PMID 38595233)
is written against those sources and awaits owner/coach review; the ACSM rest and load-progression figures in two
terms were written from the position stand's abstract-level recommendations and should be confirmed.

Not verified: a physical iPhone (any of this), live AI, VoiceOver/TalkBack by ear, real keyboard behaviour.

## 15 October 2026 (afternoon) — Groq for Ask GoHard, guide source audit, Leon/Leona refinements, verification cleanup (branch `feature/coach-groq`, from `main` at `e85993a`)

Baseline checked first: `main` = `e85993a`, CI green, clean tree; Today regressions (116 tests) passed before any change.
Four agents in separate worktrees (all four were interrupted once by a usage limit and resumed with their context;
nothing was lost): `agent/groq` (API provider + client mapping), `agent/guide-audit` (content), `agent/avatar-ui`
(Appearance + art), `agent/verify-tools` (verification scripts). The lead kept Today, shared docs, journeys, release.

- **Groq** (`docs/COACH.md`): `ICoachProvider` with `AnthropicProvider` and `GroqProvider` (Chat Completions at
  `https://api.groq.com/openai/v1`, Bearer key, `response_format` strict `json_schema`, no streaming/tools,
  `max_completion_tokens`, `reasoning_effort: low`, `include_reasoning: false`; `finish_reason` ≠ `stop`, refusal,
  malformed or off-schema replies are failures). Selection by `Coach:Provider`; no fallback to another provider or
  model. Failures typed; provider 429/498/503/529 → `503 COACH_BUSY {retryAfterSeconds}` (app: "busy right now",
  question kept, Retry); auth/model/other → `COACH_UNAVAILABLE`; at most one retry (≤ 5 s, within the 20 s budget);
  the daily cap (40) counts only requests that reached the provider. Env vars verified to bind through the real host.
- **Guide audit** (`docs/COACH_SOURCES.md`): sources now ACSM 2009 (full text read), ACSM 2026 position stand
  (PMID 41843416, full text), Ramos-Campo 2024 (abstract), Schoenfeld 2016 rest (abstract), Schoenfeld 2019
  frequency (abstract); PMIDs re-checked against PubMed by the lead. The two figures written from memory (rest 2–3 /
  1–2 min; 2–10 % load increase) were right but lacked their goal/experience/trigger conditions — now stated, with
  the 2026 stand's finding that rest length made no consistent strength difference. Ten exercise sentences softened
  (one safety claim removed). Exercise cues remain general descriptions; no professional review has happened.
- **Leon/Leona**: Appearance cards with 64 px previews (56 px stacked above 1.5× text); full figures get a 2 px
  25 % warm rim baked by `build-coach-art.ps1` (leon-full 124,607 B, leona-full 117,166 B; avatars unchanged
  63,005 / 56,359 B). New tests: a closed hint stays closed across route cover, guide switch and tab change; showing a
  hint makes no network call; previews meet target/label guidelines in six themes at 320 px 2×.
- **Verification**: `verify-api.ps1` records each throwaway account (git-ignored `scripts/.verify-accounts.log`),
  always cleans up in `finally` (success, failed check, Ctrl+C; re-signs in if the token expired), reports cleanup
  separately (exit 2 if it failed); `delete-verify-account.ps1` deletes one exact verify email. Fixed verification
  password with a 16-hex email. Live coach checks behind `-Coach`. The earlier orphan (`verify-<8 hex>@example.test`,
  'Verify', ~16:30–16:40 UTC, empty) cannot be identified without database access; the operator task is documented in
  `docs/RELEASE_AND_ROLLBACK.md`. Hosted run by the tooling agent: all checks passed, its account deleted.

**Checks**: `scripts\test.ps1` — API 184/184 (22 coach), release publish, Flutter analyze clean, Flutter 455/455.
Native, emulator, local API (`-FoodFixtures`, no AI key), each journey alone with `-Only`: coach, journey_test,
more, offline, device, upgrade, cold start (both phases) passed. food and plan (both phases) passed every app step,
then the driver lost the VM service after the test ("Service has disappeared"). secondary: first two attempts lost the
service before/at startup (no app step failed), passed on the third after an emulator reboot. plan needed three
attempts (attach hang; then registration timed out right after the reboot while the emulator network came up).
CI `ci`: success on `81f03f3`, `2ce933f`, `6874338`. Live Groq: see below.

**Live Groq (hosted testing API, `GOHARD_Coach__Provider=Groq`, model `openai/gpt-oss-120b`, key set by the owner in
Railway; never seen here).** After `main` reached `1cdf1e0`, `/capabilities` declared `coach.ask`.

- First `verify-api.ps1 -Coach`: split question PASS (but exactly 1200 chars: cut), follow-up 400 (the script sent the
  model's "–"/"…" in PowerShell 5.1's legacy codepage — fixed by sending UTF-8 bytes), third question `COACH_BUSY`
  (Groq 8K tokens/minute). Fixed in `95d5430`/`dc2cd79`: completion budget 1500, lean prompt (bounded by a test),
  ≤ 120-word answers cut after a whole sentence, "source-checked" label. Final run: split question (872 chars,
  sources ramos-campo-2024, acsm-2009), follow-up (736), exercise explanation (567) all PASS; a fourth question in the
  same minute was `COACH_BUSY` (plan limit, handled); account deleted. Food search was 503 once from USDA in between
  (intermittent upstream; passed on the next run).
- Real app on the emulator against the hosted API (`journey_coach_live_test`, run with `flutter drive` directly because
  `test-android.ps1` deliberately refuses non-local APIs; questions paced 25 s apart): passed on the fifth attempt —
  earlier attempts were journey faults (driver needed GOHARD_SHOT_DIR; answer counting in a lazy list; reopened
  conversation not scrolled). Real split answer and follow-up (`l01`, `l02`, answers keep general info / draft facts /
  optional suggestion apart), exercise answer (`l03`), a real server-validated proposal "Replace Back squat with Goblet
  squat in Full body A" previewed with before→after, 3 × 6–10 · 150 s, Draft only (`l04`), Keep current, a draft edit
  (5 sets), the preview flagged "Your draft changed since this suggestion" (`l05`), rebuilt, applied to the draft
  (`l06`, nothing activated), undone with the newer 5-set edit kept (`l07`). Each run's account was deleted (204).
  Not confirmed: on the reopened Ask screen the journey's first two Send taps did not register (likely the keyboard
  moving the composer in real time while the test pumps); to check by hand on the iPhone.
- Invalid/unauthorised IDs against the live model: the model did not propose any in these runs; the server rule that
  drops them is covered by fixture tests (17 bad-proposal cases), not by a live attempt.

IPA: run 17 (`1cdf1e0`) failed on GitHub's runner (timed out downloading the Flutter SDK, before any build step);
run 18 from `95d5430` succeeded — the final client code (later commits change API, scripts and docs only).

## 16 October 2026 — animated Leon/Leona companion (branch `feature/coach-companion`, from `main` at `dc8c967`)

What changed (docs/COACH.md › Companion): Leon or Leona peeks into Today's header from the right edge beside the
greeting (head and upper shoulders, mirrored to look in, leaning around the edge, faded over the shoulders), in a
reserved slot of the header's own `Stack`; the greeting gained one factual line from Today's projection
(`today_greeting.dart`, worked out on the phone); Ask GoHard moved into Today's title row and is always there; Me ›
Appearance › Show coach on Today; Hide for today; once-a-day greeting per account; a finished workout acknowledged
once; the Ask GoHard header portrait is attentive only while a request is in flight.

Animation approach: **not Rive.** No Rive editor is available here to author or maintain a rig, and the approved art
is a painted raster, so a `.riv` would have been invented. Instead a Flutter-native rig (`coach_rig.dart`): the
approved avatar source drawn as a skinned mesh (`Canvas.drawVertices`, 18 × 18 grid) with a head bone (turn and nod
on the neck, weights easing to zero, no seam), brow bones, breathing, and painted eyelids (blink, smile squint) in
colours sampled from the fur; motion (`coach_companion.dart`) is a set of damped springs, so every interruption
blends from the pose on screen. `RigPortrait` is the only renderer entry point (a Rive or other renderer can replace
it behind the same pose). Assets: `leon-bust.png` 255,942 B, `leona-bust.png` 222,852 B (400 × 400, from the
existing sources by `build-coach-art.ps1`; nothing new drawn or downloaded; regeneration in PROVENANCE.md).

Pipeline proof first: `coach_rig_render_test.dart` frame strips of both guides — entrance, greeting tilt and brows,
nod, blink, acknowledgement, exit — on a light and a dark sky (`docs/evidence/coach/companion-frames.png`). Test
engine renders, not device captures.

Tests: `coach_companion_test` (15), a new pending-pose test in `coach_ask_test` (19 total), updated `today_ui_test`
and `weather_contrast_test` (the header text band is 71–201 px, was 197: the greeting's one summary line; the
contrast check now covers it), `coach_avatar_test` (scrolls to the guide cards, which moved down by one row).
`scripts\test.ps1`: API 184/184, app analysis clean, 470 app tests passed (before the review fixes; re-run below).

Independent review (read-only agent): no high-severity findings; fixed — Reduce Motion switched on during the tuck
never finished leaving (now leaves at once; test added), the tap target was an unlabelled semantics node (now
excluded), `ref` read after an await in the workout finish, `onGreeted` through `ref` after the frame, a greeting
could start while the header was built off screen (now measured first), attentive pose lost under Reduce Motion,
per-frame `Vertices`/gradient objects (disposed / cached), the hide target clipped, and a latent ever-breathing loop.

Real app on the emulator (`emulator-5554`, Android x86_64 image, debug build, local API with live Open-Meteo,
Halifax clear night), `journey_companion_test` with `adb screenrecord` driven by GOHARD_REC markers (the
`return` part presses Home for real and relaunches). Recordings in `docs/evidence/recordings/`:
`companion-leon.mp4` (entrance ≈ 450 ms with a slight settle, greeting tilt, blink, a tap's acknowledgement),
`companion-scroll.mp4` (the portrait scrolls away with the header; Train, Eat, Me and back show it settled at once,
no replay; the night sky moving behind), `companion-return.mp4` (Home, launcher, relaunch: settled, no replay),
`companion-leon-hide.mp4` (Hide for today: tucks away, the header reflows, Ask GoHard stays), `companion-leona.mp4`
(the same for Leona; blinks visible mid-close), `companion-reduced.mp4` (Motion › Reduced: still portrait at once,
hidden without the tuck). Inspected frame by frame (WinRT thumbnails): no seams, clipping or snapping; found and
fixed from the footage — the hide × showed before the guide arrived and lingered after the tuck (it now fades with
the guide), and the recorder lost the end of a part (padded). The green outline and crosshairs in the clips are the
test harness's tap highlights, not app UI. Journey runs on the way: the first recorded only the integration-test
placeholder (`convertFlutterSurfaceToImage` hides the live surface; the journey now reverts it), one had two
recorders writing the same files (a stale watcher), the last two passed with all six parts recorded.

Not measured: frame timing, raster cost beside the weather sky and battery. There is no physical device here and
Flutter has no profile mode on the x86 emulator; nothing in this entry is a performance claim. Pending on a phone:
`flutter run --profile` on Today with the weather sky and the companion greeting (DevTools frame chart, raster
thread), VoiceOver/TalkBack by ear (the companion is excluded; the greeting reads as one line; Hide coach for today
is a labelled button), and the art on a real screen.

Final checks on the finished code: `scripts\test.ps1 -SkipApi` passed (analysis clean, 472 app tests; the API part,
184/184, passed earlier the same evening and no API code changed). Render `six themes: today`, Today states, large
text, narrow and all weather scenes regenerated (`docs/evidence/design/`, Today and Appearance renders only; the
greeting now wraps at large text instead of being cut). Emulator journeys against the local API with recorded
provider responses, one at a time (several attach hangs — "isolate taking unusually long" — were stopped and retried
after an adb restart, and once after an emulator reboot; none reached an app step):
journey_secondary, journey_more, journey_device (GPS run recovery), journey_upgrade, journey_coldstart,
journey_offline, journey_food, journey_coach passed cleanly. journey_test passed every step on its second run; its
first run failed once at the Me › Sign out tap right after a theme change (not reproduced; no companion involvement),
and both of its runs ended with the driver's "Service has disappeared" after the test (the known harness issue; all
steps passed). journey_plan: phase 1 (template customised and activated offline, moved, edited, replaced by a rotation) passed in three separate runs; phase 2 (new process, same install) never reached an app step in any of them (driver could not attach: "Service has disappeared", "Flutter Driver extension is taking a long time", VM service connection refused), including once after an emulator reboot, so **phase 2 is unverified for this branch** (the cold-start recovery it checks is also exercised by journey_coldstart, which passed). The first full pass also left the emulator offline after journey_plan's
offline phase died in teardown, which made that pass's journey_coach fail at sign-up ("The server cannot be
reached"); Wi-Fi and data were re-enabled and the re-run passed. journey_companion_test needs the live weather
API (it searches Halifax) and passed there three times; against the recordings it cannot find the city.

Commit `138daa8` pushed to `feature/coach-companion` (main untouched). CI `ci` run 63: success (api, app). Unsigned IPA
`ios-unsigned-ipa.yml` dispatched on the branch: run 19 success, artifact `GoHard-Dev-unsigned-ipa` (12,353,059 bytes,
expires 30 Oct 2026). A successful iOS build says nothing about iPhone smoothness or battery.

## 16 October 2026 (evening) — the coach speaks through attached bubbles (branch `feature/coach-companion`, continued)

What changed (docs/COACH.md › Companion): one recognisable guide who speaks through an attached speech bubble of
native text. Today: the guide peeks in from the right edge, nods, and its bubble says "Good evening, Babti!" with
Today's factual line (or "Need a hand with today?") ending in "Ask me ›"; no second Ask GoHard beside the title while
it speaks; × hides guide and bubble for the day and Ask GoHard returns to the title row. Elsewhere, shared pieces in
`coach_bubble.dart` (CoachSay, CoachBubble, CoachSpeaker, CoachSpot, CoachHelpEntry; one open bubble at a time; a help
sheet for focused activities) speak on Train without a plan, the builder's three steps (Compare splits on the split
step), the exercise sets sheet (About this exercise), food search, food portions, nutrition goals and Appearance, and
as user-opened sheets while recording sets or a run. CoachHint is gone (replaced). Introductions are once per account
(`owner|context`), only when really in view; manual help works with Coaching hints off; Today's greeting is governed by
Show coach on Today (no longer by hints). Requested help appears settled; introductions arrive with the guide and are
announced once. Nothing shown calls the AI; food, goals, appearance and runs have no Ask me (outside the coach server
contract). Kept the existing renderer (the skinned mesh) — no new library.

Found and fixed while building (all with tests): an introduction would have been marked seen on a hidden tab (the
shell builds every tab; now TickerMode must be on); inside a Scaffold the keyboard inset is stripped from MediaQuery,
so "no keyboard" was always true (now the view's inset; the old hint had the same flaw); an introduction blocked by
the keyboard no longer pops in as it closes; AnimatedSize with no duration under Reduce Motion; CoachSpot cleanup after
the provider container was gone; the food search introduction moved under the field (it pushed the field off short
screens) and steps aside while typing.

Independent visual and interaction review (read-only agent, 12 findings, none blocking): applied — Train's duplicate
"Guide me" removed (Create my plan is just above), help copy shortened to 1–2 sentences, the help entry dims and says
"expanded" while its bubble is open (one character on screen), requested help shown settled and tappable at once,
Today's tail anchored to the bubble's foot (tracks the face when the bubble grows), "Ask me ›" read cleanly (no
glyph), live-region announcement only for introductions and nothing in the semantics tree before the bubble arrives,
the sets sheet's extra caption removed, button row aligned with the words, one "Ask me" look, the coach render now
shows the close button. Not applied: 4 px more header padding (nutrition-on-first-screen has 1 px to spare).

Deliberate trade-off for review: Today's header is about 30 px taller than the one-line greeting. At 390 × 844 the
three sections and the nutrition label still start on the first screen; the Run button (tallest state) and Log food
(quiet day) are now a short scroll away. today_ui_test records this (the old "actions on the first screen" checks
became "sections start on the first screen"), and weather_contrast_test's header band is 71–290 px (was 71–201).

Tests: 478 app tests (coach_avatar_test 15, coach_companion_test 16, new builder and food coach tests). Renders
regenerated: `six themes: today`, `six themes: coach`, Today states, large text, weather scenes (`docs/evidence/design/`;
unrelated renders restored to `main`).

Real app on the emulator (`emulator-5554`, Android x86_64, debug build, local API with live Open-Meteo, Halifax clear
night), `journey_companion_test` (rewritten; not in the default run), recordings `docs/evidence/recordings/coach-*.mp4`
(the previous `companion-*.mp4` replaced): `today-leon` (peek, nod, bubble arriving as it settles, acknowledgement),
`scroll-return` (scroll, tabs, real Home and relaunch: no replay; the sky moving), `split-help` (Train's introduction,
the split step's introduction, Compare splits), `exercise-help` (help in the sets sheet appears settled, the entry dims,
About this exercise, the typed 5 kept), `food-portion` (search introduction under the field, gone when typing; the
portion guidance on eggs), `hide-today` (bubble fades, guide tucks, plain greeting and one Ask GoHard), `hints-off`
(Nutrition goals: nothing by itself, help on request), `today-leona`, `reduced` (settled portrait and bubble at once).
Inspected frame by frame: no clipping or snapping; the round portrait's backdrop shows for a moment before the guide
peeks into it (reads as the window it appears in; left as is). Green outlines and crosshairs are the harness's tap
highlights. The journey's own assertions passed (bubble present, no second Ask, hidden for today, hints off).

Not measured: frame timing and battery (no physical device; no profile mode on the x86 emulator).

Checks and journeys on the finished code (commit after `e1000f0`): `scripts\test.ps1` passed (API 184/184, analysis
clean, 478 app tests). CI `ci` run 65 success and unsigned IPA run 20 success (`GoHard-Dev-unsigned-ipa`, 12,360,035
bytes) on `e1000f0`; the last commit adds the non-breaking "Ask me ›" (the real-app capture showed it split as
"Ask" / "me ›" at 360 dp), two journey waits and this ledger (CI/IPA re-run on it, below). Emulator journeys against the
local API with recorded provider responses, one at a time, network restored before each:
journey_food, journey_device (GPS run, now with the run help entry in its app bar), journey_secondary, journey_more,
journey_offline, journey_upgrade, journey_coldstart passed cleanly. journey_coach failed twice at closing the split
introduction: the device test advances animation only on pumped frames, so the bubble (which ignores taps until it
has arrived) had not arrived during a 2 s wait without pumping — the journey now pumps real frames while waiting, and
then passed. journey_test failed 3 times in 6 runs at Me › Sign out right after the theme and accent change (the row
was found, scrolled into view and gone two frames later); a diagnostic run showed Me intact and passed; on `main` it
passed its one comparison run. The journey now pumps real frames for 0.6 s before that tap; it is recorded here as an
intermittent harness race, not proven absent. journey_plan: phase 1 passed again; phase 2 (new process) again failed to
attach ("Service has disappeared") before any step — **still unverified**, as on 16 Oct. journey_companion_test passed
against the live weather API (recordings above).

On `a613cf4`: CI `ci` run 66 success; unsigned IPA run 21 success (`GoHard-Dev-unsigned-ipa`, 12,359,935 bytes, expires
30 Oct 2026). `main` untouched. A successful iOS build says nothing about iPhone smoothness or battery.

## 16 October 2026 (night) — a living companion: moving eyes, the bubble from the mouth, Today until turned off, the guide as Ask GoHard (branch `feature/coach-companion`, continued)

These requirements supersede the earlier rounds where they differ (docs/COACH.md › Companion; TASK_MATRIX C6).

What changed:
- **Eyes.** The paintings have irises clearly inside their lash lines, so independent eyes are possible without new
  art: per eye (`RigIris`, measured on the 1254 px originals) an opening polygon inside the lash line, the iris disc and
  the white's sampled tone. The original iris is toned to the white inside the opening and the same painted iris is
  redrawn from the texture, moved by the gaze (≤ 30 % of its radius across, 18 % vertically) and turned with the head.
  Nothing is stretched. The round 1 oval eyelids showed as flat discs when closed (seen on the new pose sheet), so the
  lids were redone inside the opening: the upper lid covers the painted lash ring, feathered into the fur, with a lash
  line that rests on the eye's lower contour as a gentle curve.
- **Motion.** Gaze springs. At rest a timer wakes one natural moment: a blink (35 %), a small look (40 %) or a glance
  at the bubble with a touch of head (25 %), back to the user after 0.6–1.5 s. Wakes come every 2.5–6 s at first, then
  every 5–11 s, with no frames in between. The greeting glances at the words as they arrive and then back at the user.
  Reduce Motion: still, looking at the user, no blink. It pauses off-screen, when covered, on another tab and in the
  background, as before.
- **Bubble from the mouth.** `CoachSpeech` draws the tail every frame from the bubble's edge to the muzzle's edge at
  the mouth's height (`RigArt.mouth`/`front` through `RigGeometry.point`, posed as now), stopping 4 px short of the
  lips. The bubble's first line is level with the settled mouth, and the portrait's empty side tucks under the bubble.
  No screen coordinates are used. The first version aimed at the mouth's centre and covered the near lip; this was
  caught in the render and fixed.
- **Today stays.** The ×, "Hide coach for today", the stored `hidden` and `_AskButton` are gone. The old JSON key is
  ignored, not converted. Show coach on Today is the only switch. Narrow phones now get a 68 × 84 guide and large text a
  taller bubble; before, the guide, and with it Today's Ask access, disappeared below 340 px or above 1.3× text.
- **Ask GoHard is the guide.** The entry points were audited:
  - Today: the portrait (`coach-avatar-launcher`, button semantics with a tap action; it had none, which was caught by
    the new test) and Ask me.
  - Train header: `CoachAskLauncher`, the guide's avatar, there whether or not Today shows the guide.
  - Speaker portraits in bubbles and help sheets that have Ask me.
  - Why this suggestion and About this exercise: their text-only Ask buttons now carry the guide's avatar.
  - The conversation: each answer is headed by the guide's avatar and name instead of the generic ✦ icon.
  - Appearance's "off" subtitle said "Ask GoHard stays on Today" and now says it is still the guide, on Train.
  - Nothing opened or shown calls the AI.
- **Rendering details found on the device.** A hard grey line under the portrait came from mesh content outside the
  box: the device's layer bounds don't clip. The canvas is now clipped to the box; confirmed gone in the second
  recording. At 2× text "›" wrapped alone from a fallback font, so "Ask me ›" is now one unbreakable inline piece,
  without double text scaling.

Trade-off accepted per the brief (comfortable spacing over a first-viewport target): Today's header is about 285 px
at 390 × 844 with a notch. The workout section and its action are whole on the first screen, and nutrition is a short
scroll away. `today_ui_test` and `widget_test` (320 px, 2×) now say so.

Tests: 480 app tests. coach_companion_test has 19, including:
- an old "hidden for today" is ignored, and an upgraded account sees the guide again the same day;
- nothing "hidden" is written;
- the guide and Ask me open Ask GoHard with the same guide;
- the labelled button;
- the eyes' moments at rest with no frames in between;
- Show coach on Today off and on, with the Train launcher;
- Reduce Motion: no blink or gaze;
- narrow and 2× text keep the guide.

coach_ask_test covers the answer's identity. The test fixture gained `restDaysProvider`, which Ask's context needed.
`scripts\test.ps1` passed: API 184/184, analysis clean, 480 app tests.

Renders: `docs/evidence/coach/companion-poses.png` (10 poses × both guides × both framings; replaces
`companion-frames.png`), all six themes, Today states, narrow, large text and weather scenes.

Real app on the emulator (`emulator-5554`, debug, local API with live Open-Meteo, Halifax), `journey_companion_test`
passed twice. Recordings `docs/evidence/recordings/coach-*.mp4` from the second run:
- `today-leon`, `today-leona`: entrance, nod, words arriving with a glance, then 14 s at rest with blinks, looks and
  bubble glances; the tail stays on the lips through every head movement;
- `ask-leon`, `ask-leona`: the portrait opens Ask GoHard (same guide in its header), then Ask me does too, then back on
  Today;
- `scroll-return`: tabs, Home and relaunch: still there, no replay;
- `appearance`: Today still there after other screens; off → plain greeting, no Ask button; the guide on Train opens
  Ask; on → back, settled;
- `split-help`, `exercise-help`, `food-portion`, `hints-off`: contextual help, unchanged;
- `reduced`: still portrait with its bubble.

`coach-hide-today.mp4` was removed. The first two attempts failed before any coach step: the API had been started with
`-FoodFixtures`, which also answers city lookups from recordings, and Halifax isn't in them. The companion journey
needs the API without that flag.

Not measured: frame timing and battery (no physical device).

Emulator journeys on the finished code, one at a time, local API with recorded provider responses, network restored
before each run:
- Passed on the first run: journey_test (it had failed 3 of 6 times at Me › Sign out last round), journey_secondary,
  journey_offline, journey_device, journey_upgrade, journey_food.
- journey_plan passed **both phases**. Phase 2, in a new process, had never attached before, so it is now verified on
  the emulator.
- journey_coach hung at attach on its first try (the driver extension never became available), then passed.
- journey_coldstart: phase 1 passed, then phase 2 failed to attach ("Service has disappeared") before any step. Run
  alone after an adb restart, it hung at attach once more, then passed both phases.
- journey_more: twice the app printed "+2: All tests passed" and then the driver lost the VM service while collecting
  results (exit 1). Run alone after the adb restart, it passed cleanly.

Pattern: the attach and "Service has disappeared" failures came after more than an hour of runs and stopped after an
adb restart. No failure happened at an app step.

CI and IPA on `79fca3d`: **not run**. GitHub refused to start the jobs of `ci` run 68 and `ios-unsigned-ipa` run 22
(and, earlier, `ci` run 67 on `c447c44`) with "recent account payments have failed or your spending limit needs to be
increased", a billing block on the GitHub account, not a code result. They need re-running once billing is fixed.
The last successful IPA (run 21, `a613cf4`) predates this round. `main` untouched.
After the repository was made public (free Actions minutes), on `9fa0e60` (the round 3 code plus the ledger note):
`ci` run 69 (re-run) success, api and app jobs; unsigned IPA run 23 success (`GoHard-Dev-unsigned-ipa`, 12,371,122 bytes,
expires 30 Oct 2026). `main` untouched. A successful iOS build says nothing about iPhone smoothness or battery.

## 16 October 2026 (round 4) — eyes that can be seen, the coach on every tab, setup after sign-up, temperature on Today (branch `feature/coach-companion`, continued)

**Why the eyes looked static on the phone.** Not the scheduler, not repaint, not the layer order. With temporary
`COACH_DIAG` logging in a profile build on the emulator, the companion stayed active after the greeting
(`active=true`, tab and route current, foreground, on screen, Reduce Motion off), rest/wake cycles ran, and blinks were
painted to a full closure on top of the eyes. The pose sheet at 3× showed convincing closed eyes for both guides, so
the artwork was not the limit either. The cause was size and time:
- on Today the eye opening is **6.3 pt** tall (logged), and the gaze moved the iris at most 0.30 × its 3 pt radius ≈
  **0.9 pt**;
- a blink was fully closed for **30 ms**, 2–4 frames on a phone;
- after the first minute a blink came about every 14 s.
Earlier recordings showed blinks clearly because this emulator draws the app at a few frames per second (Choreographer
"Skipped 136 frames"; in debug, paints about 1 s apart) and the rig caps each step at 1/30 s, so every blink played
in slow motion. Those recordings overstated what a phone shows. The installed IPA and the phone's own motion settings
could not be checked from here: no device access.

What changed:
- **Eyes.** Blink 90 ms closing, 70 ms closed, 170 ms opening. A natural moment every 2–5 s for as long as the guide can
  be seen (no slowing after a minute): a blink 45 % (double now and then), a clear look to one side 35 %, a glance at
  the bubble 20 %, each look held 0.9–2.2 s. Gaze up to 55 % of the iris radius across and 22 % vertically (was
  30 % / 18 %), checked on the 3× pose sheet and a close-up for both guides: no exposed original iris, clipped cleanly
  at the corners. Reduce Motion: unchanged, still.
- **Help sheets showed no guide** (found on the emulator in this round; it affected workout and run help too): the
  companion measured itself once while the sheet was still below the screen and never again. It now looks again after
  each frame until it has started. Regression test added; it fails without the fix.
- **Coach on every tab.** Train's avatar asks about the section in view (primary plan / "Your progress" / "Your
  training"). Eat gained the avatar, opening built-in journal guidance with no Ask me, since the coach endpoint is
  training-only. Workout and run recording already had the compact app-bar avatar and help sheet.
- **Setup after creating an account** (docs/COACH.md › Setup): Choose your coach with live previews and the chosen
  guide's hello in its bubble, then Optional features. Progress is kept per account in the coach preferences, so a
  restart resumes and finishing or skipping ends it. Accounts that sign in never see it. Nothing asks for access
  unless the person turns on or uses the feature. Me › Phone permissions shows the platform's actual state.
- **Temperature.** "10°C · Overcast" on Today from the same fresh answer; °C/°F in Me › Units (a device setting); no
  API change, because both adapters already return `temperatureC` in °C.

Checks run (no full suite, no API tests: API unchanged):
- `flutter analyze lib test integration_test`: clean.
- Tests: weather_scene_test, coach_avatar_test, coach_companion_test, me_ui_test, eat_ui_test, today_ui_test,
  train_ui_test, weather_ui_test, widget_test, coach_ask_test, all passing after updating three expectations: the Units
  row now reads "Kilograms · °C", and Eat has the avatar image.

Real app on the emulator (`emulator-5554`, **profile** build, local API with live Open-Meteo, driven by adb; recordings
in `docs/evidence/recordings`, frames in `docs/evidence/coach`):
- `eyes-today-leon.mp4`: Leon after the greeting, blinks and looks continuing; `eyes-live-leon-frames.png` shows
  closures and side glances at device pixel size.
- `eyes-today-leona-temperature.mp4`: Leona on Today with "10°C · Overcast".
- `eyes-reduced-motion.mp4` and `eyes-reduced-frames.png`: identical still frames for 16 s.
- `setup-signup-choose.mp4`, `setup-leona-welcome.mp4`: sign-up lands on Choose your coach, both previews animate,
  Leona's hello. Then Continue, a force-stop and relaunch, which resumed at Optional features
  (`setup-features-resumed.png`).
- `setup-features-refusals-city.mp4`: reminders on → system prompt → Don't allow → stays off with an explanation;
  Weather → Automatic → GoHard's explanation → system prompt → Don't allow → "Location was not allowed. Choose a city";
  Halifax; Done → Today.
- Temperature: Open-Meteo returned 9.5 °C, code 3, for the same grid point. Shown as 10°C, then **49°F** after
  switching, which is converted from 9.5, not from the rounded 10 (that would be 50).
- `coach-train-plan-progress-eat.mp4`, `coach-help-sheets.mp4`: Ask GoHard "About: Your progress"; Eat help sheet;
  workout help sheet with the guide, the avatar clear of fields, timer and Complete set.
- Large text 1.5× at 720 × 1520: Today fits; Eat's date wraps to three lines beside the avatar (taller header, no
  overflow; accepted).

Emulator motion runs at about half speed (motion time advanced 7.1 s in 14.7 s of wall time). Not measured: phone
frame timing and battery. Still to check on a physical phone: the blink and gaze at real size and frame rate, iOS
permission prompts (and the "restricted" state, which geolocator reports as not allowed), and VoiceOver.

Known limit: Ask GoHard's suggested questions on Progress are still the plan ones; the context label is right.

## 16 October 2026 (Today panels) — the approved Today mockup: photographic panels (branch `feature/today-photo-panels`, from `feature/coach-companion` at `bbe4fd7`)

Presentation only: no API, contract, sync, stored-data, permission or AI-provider change. Layout and rules in
docs/DESIGN.md › Today panels.

| Change | Where |
|---|---|
| Order: Workout and Nutrition at the full width, then a compact Run tile (64 %) with History beside it; the scene shows around them. The single blurred surface and the rhythm thread are removed (`RhythmTimeline`, `GoColors.panelOpacity` deleted) | `features/today/today_screen.dart` (`TodayScreen`) |
| One panel family: `_PanelTheme` (pale accent tint, dark ink, deep accent button, same in Light and Dark; Blue and Pink have their own), `_PanelSurface` (opaque tint, soft shadow, thin edge, photograph on the trailing half fading into the tint by a `ShaderMask` gradient), `_Module` (badge, serif display line, secondary lines, button with a quiet link) | `today_screen.dart`; `goThemeOf` split out of `goTheme` in `core/theme.dart` (no change for other screens) |
| Workout: the real name in the serif; every state kept (due, in progress, saved for later, completed, partly completed, skipped, rest, paused, starts later, block review, draft, no plan); only due and in-progress have the photograph and Start/Resume; other workouts today, unresolved earlier workouts, Start a manual workout and saved-for-later sit under the lead in the same panel; an open manual or other-day workout has its own panel in front | `_TrainingSection`, `_OpenWorkout` |
| Nutrition: the calorie figure in the serif ("1,400 kcal"), the goal and its bar when set, protein on one line, unknown as a dash, partial as "known", the missing-values line; "No food logged today" (never 0 kcal); Log food filled, Journal quiet | `_NutritionCard`; `NutritionSummary` display figure in `nutrition/nutrition_surface.dart` (only Today uses it) |
| Run: compact tile with the photograph; real state, Distance/Time only from saved values; Start run / Continue run filled; History on the scene in the header's sky colours on a scrim | `_RunCard` |
| Sheets and dialogs opened from a panel (Details, Start/Resume, Log food, Start run, Undo skip) open from the context outside the panel theme, so they keep the app's look | `_AppContext`, `_appContext` |
| Journeys skip the coach setup a new account now gets (it blocked every journey that signs up since round 4) | `integration_test/support.dart` (`Journey.start`) |
| A device evidence journey for the panels (not in the default run) | `integration_test/journey_today_panels_test.dart` |

**Photographs.** The three bundled ones, unchanged (provenance note added to `app/assets/PROVENANCE.md`). They show the
mockup's subjects but are not its pictures, which are wet/rainy variants not supplied as files. No asset was added.

**Visible differences from the approved image.**
- Photographs: see above (dry gym floor and dusk riverside path instead of wet ones).
- Heights: the due workout panel is 260 at 390 × 844 against about 183 in the mockup, because the 52 px button and
  the plan-week line ("Week 3 · 50 min planned") are kept; in progress with the ring it is 320.
- The scene is the live weather (Halifax partly cloudy / overcast during the capture), not the mockup's rain.
- History has a soft scrim backing so it reads over a light sky as well as a dark one.
- Nutrition shows the goal line and bars, and the missing-values line, when they apply (the mockup shows the simplest
  state).

**Checks run** (proportionate; no full suite; no API tests, API unchanged):
- `flutter analyze` (lib, test, integration_test): clean.
- `today_ui_test`, `widget_test`, `train_plan_ui_test`, `theme_test`, `weather_contrast_test`, `motion_test`,
  `today_states_test`, `coach_companion_test`, `coach_avatar_test`, `weather_ui_test`, `weather_motion_test`,
  `me_ui_test`: all passing. Updated expectations that described the old arrangement (one surface and blur, one
  filled button on Today, outlined Start run, 84/72 px crops, the old height targets, the serif rule now allowing
  Today's panel lines, the sections' dark theme in Dark mode); removed the surface contrast test and the timeline half
  of a motion test with the code they covered. New regression test: Details opens its sheet in the app's Dark look
  (fails without the fix, passes with it).
- Renders: `flutter test test/render_test.dart --dart-define=GOHARD_RENDER=true` (Today states, six themes, every
  weather scene, 320 px at 2×). Before/after pairs at the same fixture and viewport in `docs/evidence/today-panels/`.
- Device (`emulator-5554`, Pixel 7 image, 1080 × 2400, debug build, local API, live Open-Meteo for Halifax):
  `scripts\test-android.ps1 -Only journey_today_panels_test` passed. Captures `docs/evidence/screenshots/today-panels-*`
  (no plan, due, due with food, in progress, open run, Green/Blue/Pink × Light/Dark); the journey checks Start workout
  → workout → Resume on Today → the same workout; Log food → food form → real values; Journal → Eat; Start run → run
  → Continue run → finish → Start run; History → Run history. Recording `docs/evidence/recordings/today-panels.mp4`:
  scrolling, Ask me → Ask GoHard, Details sheet, Journal, History, the guide and the sky at rest.
- Emulator housekeeping: the data partition was full (install failed). Old recordings on `/sdcard` were copied off
  first, then removed; this project's earlier profile install `com.gohard.rebuild` was uninstalled (test data only;
  the original `com.example.go_hard_app` untouched); the emulator was rebooted.

**Pending, physical phone:** the panels and their photographs on a real screen, scroll smoothness over the moving
sky, VoiceOver/TalkBack by ear. Large text was checked in renders (320 px at 2×), not on the device this time.

## 16 October 2026 (app-wide) — the Today photo-panel language across the app (branch `feature/appwide-design`, from `feature/today-photo-panels` at `72779c9`)

Built from `GoHard_Appwide_UI_Handoff` (its `CLAUDE_PROMPT.md` and five reference boards, kept beside the code and not
used as images). Presentation only: no API, contract, model, stored-data, sync, permission or AI-provider change; no new
dependencies or assets. Rules and the shared pieces in docs/DESIGN.md › App-wide panels.

How it was done: the shared tokens and components first (`db5efee`: `GoColors.accentDeep` / `onAccentDeep` / `tint` /
`panelOf`, `PanelTheme` with `appContext`, `PanelSurface`, `PanelPhoto`, `PhotoPanel`, `QuietLink`, deep filled
buttons, tinted `Segmented` and `ChoiceCard`; Today moved onto them unchanged in look). Then three screen groups in
parallel with strict file ownership (Train and workout; Eat, food and run; Me, account, setup and Ask GoHard), then one
integration pass (tests, renders, device, docs).

| Area | Change |
|---|---|
| Train / Plan | Pale plan panel with the dumbbells (`train-pass`); chosen week in the tint; this week's rows in one card with icon-and-word states and today's row outlined and labelled "Today" |
| Train / Workouts, Progress | Open workouts as panels with Resume and Details; start rows quiet; Progress summary panel from recorded data only (`train-progress-panel`), recent workouts, "Exercise history" |
| Workout recording | Serif workout name; exercise panel (`workout-exercise-panel`) with the prescription; separate Target and Last recorded tiles from real data; sets, rest, notes, undo, Save for later, Finish unchanged |
| Plan builder | Numbered step marks; plan-in-progress and Guide me suggestion as pale panels; serif workout names. Workout cards stay ordinary cards (their menus must keep the app's look) |
| Eat | Summary panel with the bowl and Log food; goals ring and protein bar only when set; unknown "—", partial "known"; journal one card per meal, no photos |
| Add food, food form | Scan barcode under the search; Search / Recent / Favourites / My foods as a tinted track (scrolls when it does not fit); clean result rows; "Enter it yourself". Form: pale header without a photograph, Amount and Portion, a "You're logging" summary (energy, protein, "—" when unknown), Add your own portion |
| Run | "Your run": elapsed time in the serif on the runner panel; distance only once measured; Pause and Finish run; GPS start, typed distance, Remove run kept; no pace, map or signal indicator |
| Me, Appearance, goals | Profile row with initial; quiet rows unchanged. Appearance: small preview, accent swatches, Light / Dark / System segment, coach cards, switches, Motion & haptics (`appearance-motion`), Today background. Goals: optional-goals panel, no prefill |
| Sign-in, setup, Ask GoHard | Serif wordmark and heading, dumbbells panel, one show/hide password button (`auth-show-password`); "Step N of 2", tinted coach card, "Not now"; Ask GoHard answers in the tint with the guide's avatar, quiet user bubbles, pill suggestions, deep send |
| Journeys | `Journey.start` skips the coach setup a new account gets (kept from the Today panels branch); `journey_plan_test` reads the target from its tile; new evidence journey `journey_appwide_test` (not in the default run) |

**Checks run** (proportionate; no full suite; no API tests, API unchanged):
- `flutter analyze` (lib, test, integration_test): clean.
- Widget tests: today_ui, widget, train_ui, train_plan_ui, plan_builder_ui, plan_builder, today_states, eat_ui, food_ui,
  food_search, food, me_ui, coach_ask, coach_avatar, coach_companion, weather_ui, motion, reminders_gps, theme: all
  passing. `theme_test` gains contrast checks for the deep button's label and its edge in Dark, ink on the chosen
  tint, and secondary and link text on a photo panel (all six looks and increased contrast). The serif rule is now
  "titles and key figures; never in a control, row, field or the navigation" on every tab and Appearance. Expectations
  updated where they encoded the old layout (Mode as a segment, food rows opened by the row, outlined vs filled
  Resume/Start run, the target tiles, meal cards, the image count on Eat); none weakened.
- Renders (`render_test`, GOHARD_RENDER): six looks for Today, Workouts, Plan, Progress, Eat, Me, Appearance, Add food,
  results, the food form, scanner, goals; whole pages, 12- and 16-week plans, large text at 320 px. Recording, builder
  and Ask GoHard need the real database and are captured on the device instead. Before/after pairs at the same
  fixtures and viewports in `docs/evidence/appwide/`.
- Device (`emulator-5554`, Pixel 7 image, 1080 × 2400, debug build, local API): `journey_appwide_test` passed:
  sign-in, registration, Choose your coach, optional features, goals, the builder's steps, Today, workout start, a set
  recorded, rest, Train's three views, food search and the portion form (choosing logs nothing), a run started and
  finished, Me, Appearance, Ask GoHard, then Train/Eat in Blue Light, Pink Dark and Green Light. 28 captures in
  `docs/evidence/screenshots/appwide-*`; recording `docs/evidence/recordings/appwide.mp4` (69 s: tabs, Ask GoHard,
  the plan, food search with the keyboard, the coach and the sky at rest). `journey_plan_test` (two phases: offline activation, the set recorded before the process ended recovered,
  move, edit, my own rotation) passed after two harness fixes: the recorded-set row now sits below the exercise panel
  in a list built as it scrolls, so journeys scroll to it before waiting (`j.reveal`; the same in the cold-start, more,
  offline and captures journeys, assertions unchanged); one attempt lost the emulator ("device offline") after phase 1
  and was retried once. Those other journeys were not rerun.

**Not verified:** a physical iPhone or Android phone (smoothness, brightness comfort, battery), VoiceOver/TalkBack by
ear, System mode following the phone's setting on a device (rendered and tested in widget tests), the keyboard over
every form (seen on food search and set entry).

## 17 October 2026 — daily goals from Today, optional water, Customize tracking, visual corrections (branch `feature/nutrition-goals-water`, from `feature/appwide-design` at `5b24cb8`)

| Change | Where |
|---|---|
| Water entries on the account: table `WaterEntries` (migration `AddWaterTracking`, additive), `water.create/update/delete` commands, `GET /water-entries?date=`, `waterEntries` in the snapshot, `waterGoalMl` on the profile (kept when left out), capability `water.entries` | `api/src/GoHard.Api` (`Persistence/Entities.cs`, `GoHardDb.cs`, `Application/JournalServices.cs` `WaterService`, `Contracts.cs`, `AuthService.cs`, `Endpoints.cs`), `api/tests/.../WaterTests.cs` |
| Water on the phone: record kind `water`, `WaterRepository` through the outbox, `waterProvider` per day, US fl oz / mL display unit (Me › Units), per-account display choices (`TrackingPrefsStore`, off by default), capability-gated | `app/lib/features/nutrition/water.dart`, `data/models.dart`, `data/sync.dart`, `app/providers.dart`, `main.dart`, `features/me/me_screen.dart`, `sync_review_screen.dart` |
| Goals from Today and Eat: one `GoalsEditor` for Me's page and the new sheet; "Set daily goals" / "Edit goals" and Customize tracking under both nutrition summaries; the water line and sheet; the Customize tracking sheet | `app/lib/features/nutrition/nutrition_tools.dart`, `today/today_screen.dart`, `nutrition/eat_screen.dart`, `me/me_screen.dart`, `me/account_repository.dart` (`setGoals(withWater, waterGoalMl)`, `validateWaterGoal`) |
| Eat's summary: the same compact composition as Today's (full-height bowl), its own extra lines below; carbs and fat follow Customize tracking | `nutrition/nutrition_surface.dart` |
| Meal icons sunrise / sun / moon / cookie; Train's navigation icon lies flat | `nutrition/eat_screen.dart`, `shell/home_shell.dart` |
| A two-phase device journey (not in the default run) | `integration_test/journey_water_test.dart`, `scripts/test-android.ps1` (phases and network switching) |

**Decisions.** Display choices (water / carbs / fat) are kept per account on this phone, like the coach preferences:
they are presentation, and a second phone starts with water off until it is turned on there (the entries and the goal
are on the account and appear as soon as it is). Water is offered only when the server declares `water.entries`, so an
older server can never be sent a command it would refuse. The water goal travels only from a form that shows it, so
Today's goals sheet without water never clears it. On Eat the calorie ring became a bar, as on Today, so both screens
draw goals the same way; Eat keeps its "what is left or over" words. An unknown total with a goal keeps Today's
existing rule (a dash, the words, a bar at 0).

**Checks run** (proportionate):
- `flutter analyze` (lib, test, integration_test): clean. `dotnet build api -c Release`: clean (the Debug build was
  locked by the running dev API at the time; it built after that process was restarted).
- API: `dotnet test api -c Release --filter WaterTests|FoodDataTests|WorkoutAndFoodTests|FoundationTests`: 30 passed,
  including two new water tests (idempotent retry, payload mismatch, duplicate id, ranges, update/delete revisions,
  another account 404 and no snapshot leak, erasure with the account; goal set / kept when omitted / cleared / range).
- App, new: `water_test` (real Drift file and the fake authority: offline add through restart, a lost response retried
  byte-identically with one entry on the server, the logged day kept after a late sync; correction and removal by
  revision; another account sees nothing; pulled entries grouped by day, a new day at zero; fl oz conversion and exact
  totals) and `water_ui_test` (off until turned on, hide and show keep the day's water and goal on Today and Eat; goals
  from Today in a Dark sheet, empty fields, saved through the one profile path; quick additions in fl oz, Undo, invalid
  amount refused).
- App, existing: today_ui, eat_ui, food_ui, me_ui, widget, theme, data_layer: passing after updating expectations tied
  to the old Eat ring and the new heights (Today's nutrition panel is taller by its goals line).
- Renders: all states and six looks; a large-text defect found and fixed (the goals link broke letter by letter at 2×
  text on 320 px).
- Device (`emulator-5554`, Pixel 7 image, debug build, local API migrated with `AddWaterTracking`):
  `journey_water_test` passed both phases. Phase 1: goals set from Today's sheet (empty fields, keyboard open) and read
  back on Eat and Me; water turned on; 250 + 330 mL logged, the 330 corrected to 300 and then removed; a 2 L goal set
  from the water sheet; offline, 500 mL saved on the phone. Phase 2, a new process back online: 750 mL read back, the
  queue drained ("Everything is saved to your account"), a pull from the account showed exactly two entries (no
  duplicate), the keyboard over the water sheet, hide and show kept the total. Captures
  `docs/evidence/screenshots/water-0*.png`; recording `docs/evidence/recordings/goals-water.mp4` (from the short
  `journey_water_demo_test`). Before/after renders in `docs/evidence/goals-water/`.
- Found on the device and fixed, each with a regression test in `water_ui_test`: the "Correct this amount" dialog
  used its text field after disposing it (it closed with an exception); the water line showed "0 mL" while the day's
  entries were still being read after a restart (it now shows nothing until they are known).
- Harness, not the app: two attempts hung before the test attached (adb restarts and a cold emulator boot cleared
  it), one lost the emulator after phase 1; the journey now waits for the goals link to be enabled (it is disabled for
  a few seconds after sign-up until the account's profile arrives) and closes sheets by popping their route.

**Not verified:** a physical phone; VoiceOver/TalkBack by ear; the hosted API, which gets the migration only when
`main` is deployed (until then the capability is absent there and water stays hidden; goals work as before). The
installed IPA talks to the hosted API, so water will not appear in it until that deployment.

## 17 October 2026 (later) — display choices on the account, the coach on Train and Eat, meal hierarchy, screen inventory (branch `feature/coach-tabs-tracking-sync`, from `feature/nutrition-goals-water` at `3948f07`)

| Change | Where |
|---|---|
| Water / Carbs / Fat visibility on the account: `ShowWater`, `ShowCarbs`, `ShowFat` (nullable) on `Users`, migration `AddTrackingDisplay` (additive), in `ProfileDto` and `profile.update` (left out or null = kept), capability `profile.tracking-display` | `api/src/GoHard.Api` (`Persistence/Entities.cs`, `Application/Contracts.cs`, `AuthService.cs`, `JournalServices.cs`, `Endpoints/Endpoints.cs`), `WaterTests.Tracking_display_*` |
| On the phone: account value per field, else this phone's own choice, else defaults; changes at once and through the outbox; a local choice sent once when the account has none; unknown capability = not sent | `features/nutrition/water.dart` (`rawNutritionDisplayProvider`, `setNutritionDisplay`, `displayMigrationProvider`), `data/models.dart`, `me/account_repository.dart` (`setDisplay`), `nutrition_tools.dart`, `shell/home_shell.dart` |
| The coach speaks on Train and Eat: Today's bust and mouth-attached bubble (`TabCoach` over `CoachSpeech`), once per tab per session; Create my plan / Continue my plan / Review my plan in the bubble; words per section; no second launcher; Show coach on Train and Eat in Appearance | `coach/coach_bubble.dart` (`CoachSay.primary`, `TabCoach`, `tabsGreetedProvider`), `coach_prefs.dart` (`onTabs`), `plans/train_screen.dart`, `nutrition/eat_screen.dart`, `me/me_screen.dart` |
| Meal groups: heading (icon, name, quieter subtotal), foods, small "+ Add food" footer read as "Add food to lunch"; no "Nothing logged" | `nutrition/eat_screen.dart` (`_AddFood`) |
| Docs | `COACH.md` › Train and Eat, `FOOD_DATA.md` › What is shown follows the account, `DESIGN.md` › Eat and › Screen inventory |

**Found and fixed during verification.** (1) With the coach under Train's title, 2× text at 320 px pushed Workouts /
Plan / Progress off the first screen: the coach now sits under the sections (`train_ui_test` 320 px case). (2) On the
device, scrolling Eat's coach out of the lazy list and back made it peek in again: the entrance is now remembered per
tab for the session (regression test in `coach_companion_test`, fails without the fix). (3) Device captures showed
the Eat bubble repeating the summary's "Set daily goals" and mentioning goals that were not set: the bubble is words
only now.

**Checks run** (proportionate; no full suite):
- `flutter analyze` (app, test, integration_test): clean. `dotnet test -c Release --filter WaterTests|FoundationTests`:
  12 passed (new: unset until chosen, explicit false kept, omitted fields kept by an older client, hiding keeps the
  water goal, stale revision is a conflict).
- `tracking_sync_test` (new, 5; two phones with real Drift files and one fake account): two phones converge both
  ways; a fresh phone sends no defaults; offline change survives restart and syncs; arriving account data does not
  discard a pending edit; stale revision → conflict, edit kept; a pre-capability choice is uploaded exactly once and
  an existing account choice wins; goals updates omit and keep the choice; another account is isolated. Mutation
  checks: disabling the upload and reversing the precedence each fail it.
- Widget tests: eat_ui, train_ui, train_plan_ui, plan_builder_ui, coach_companion (22, new: Train/Eat bubble, single
  Create my plan opening the builder, no replay on a section change, food help from the bust, no AI request; builder
  draft → Continue my plan without discarding; Appearance off keeps Create my plan, Log food, goals and the small
  avatar, Today untouched; Reduce Motion settled; scroll-back no replay), coach_avatar, coach_ask, me_ui, food_ui,
  widget, theme, today_ui, water_ui (coach mentions water once shown), water, food, data_layer: 308 passing.
  Expectations updated where they described the removed launcher, the one-time Train spot, "Nothing logged" and the
  "Add food to …" row text; the add action is now checked by its semantics label, size, meal and day.
- Renders: full `render_test` (103, six looks, large text 320 px). Before/after at the same fixture and viewport:
  `docs/evidence/coach-tabs/before|after/`.
- Device (`emulator-5554`, Pixel 7 image, debug build, local API migrated with `AddTrackingDisplay`):
  `journey_coach_tabs_test` (new, not default) passed: coach on Train and Eat, Create my plan → builder, Eat's footer
  opens Log food for Lunch, an egg logged under Lunch, water on and carbs off, then read from the account as a second
  phone would: `showWater=true showCarbs=false showFat=true`; Pink Dark captures. Captures
  `docs/evidence/screenshots/coach-tabs-0*.png`, recording `docs/evidence/recordings/coach-train-eat.mp4` (60 s).
  Earlier attempts failed in the harness (a second surface conversion; the journey's own scrolling), fixed in the
  journey. `journey_plan_test` (default run) passed both phases after one retry (the first lost the emulator before
  attaching: "Service has disappeared").
- `journey_companion_test` was updated for the new keys but not rerun (long recording journey).

**Not verified:** a physical phone; VoiceOver/TalkBack by ear; the hosted API, which lacks `profile.tracking-display`
until `main` is deployed (it already declares `water.entries`).

### Same branch, follow-up: the water goal bar, a suggested starting water goal, goals only in Eat

| Change | Where |
|---|---|
| Water drawn like the nutrition goals: "750 / 2,000 mL", a 6 px bar and the real share (full bar above the goal, "120%"); no bar or percentage without a goal; the chosen unit throughout (`VolumeUnit.format` no longer switches to litres; `number`, `progress`) | `nutrition/water.dart`, `nutrition_tools.dart` (`WaterRow`, `WaterGoalBar`, water sheet) |
| Eat's goals form offers "Suggested starting goal: 2,000 mL daily." while no water goal is saved: Use fills the field only, info dialog (needs vary, other drinks count, only logged water is counted), blank keeps no goal, a saved goal is never replaced | `nutrition_tools.dart` (`GoalsEditor`) |
| Goals set and edited only in Eat: Today's goals link and the water sheet's goal shortcut removed; Today keeps totals, progress, logging and Customize tracking | `today_screen.dart` (`NutritionTools(goals: false)`), `nutrition_tools.dart` |

Storage, sync and validation unchanged (the same `setGoals` path and ranges).

**Checks run:** `flutter analyze` clean; water_ui (new: above-goal bar and words, no bar or % without a goal; Today
and its water sheet without goal shortcuts while logging and removal stay; the suggestion offered, info, skip saves no
goal, Use then edit saves only what Save goals sends; an existing goal kept and no suggestion; fl oz suggestion), water
(formatting and progress text), today_ui, eat_ui, me_ui, food_ui, widget, coach_companion, tracking_sync, theme, food:
188 passing. Device: `journey_coach_tabs_test` extended (goals sheet with the suggestion, Use + Save, 500 mL, the bar on
Eat and Today, no goals link on Today) passed after one retry (the first attempt failed to attach: "Service has
disappeared"); captures `coach-tabs-09/10/11`; recording `coach-train-eat.mp4` refreshed. `journey_water_test` and
`journey_water_demo_test` (not default) were updated to set goals in Eat but not rerun.


## 17 October 2026 (Run / Walk) — the approved Focus Dial: durable routes, background recording, route sync (branch `feature/run-walk`, from `origin/main` at `f47ab98`)

Started after the nutrition/coach work was merged to `main` (PR #6, CI green). Design and contract: `docs/RUN_WALK.md`.

| Change | Where |
|---|---|
| One metric pipeline over the stored entries: acceptance (accuracy, order, impossible jumps with outlier recovery), 3-fix smoothing, accuracy-scaled anchor + Doppler-speed gate against drift, gaps and segments, active / moving / elapsed, pace, splits with a labelled partial, pace and elevation profiles, gain/loss with hysteresis and coverage (unknown ≠ 0), auto-pause rules | `app/lib/features/activity/track_math.dart` |
| Durable route: Drift v3 `track_entries` (every fix and event, ordered `seq`, owner-scoped), additive migration | `data/db.dart`, `features/activity/track_store.dart` |
| One recorder for the device, outside any screen: Start/Pause/Resume/Finish/Save/Discard, ordered writes with visible failure and retry, checkpoints, Interrupted after process death, legacy open runs adopted with their time and distance, auto-pause | `features/activity/recorder.dart` |
| Location: one geolocator stream; Android location foreground service with notification; iOS background updates with indicator; truthful permission states incl. approximate; timer-only fallback | `location_source.dart`, Android manifest (`FOREGROUND_SERVICE(_LOCATION)`, `WAKE_LOCK`; no background location), iOS `Info.plist` (`UIBackgroundModes location`, temporary precise purpose), `Podfile` |
| Map: Google Maps when a key is configured (channel `gohard/maps`), otherwise a drawn route; Follow / Free / Fit route, zoom buttons, gestures claimed by the map | `route_map.dart`, `MainActivity.kt`, `AppDelegate.swift`, `build.gradle.kts`, xcconfigs |
| Screens from the approved board: Ready, Recording (Stats dial / Map), Save review, Saved (Overview / Splits / Charts, edit, delete, GPX), History (All/Run/Walk, week/month totals, lazy rows, thumbnails); Today tile "Run / Walk" (Start / Resume, real type); Train entries; Me › Units km/mi | `run_walk_screens.dart`, `activity_detail.dart`, `activity_history.dart`, `gpx.dart`, `today_screen.dart`, `train_screen.dart`, `me_screen.dart`, `core/units.dart`, `core/device_prefs.dart` |
| Sync: activity type/title/notes/metrics, `run.update`, route chunks (500 entries, idempotent by content), `route.complete`, paged reads; commands a server cannot take yet stay queued (`mayDispatch`); acknowledged chunks drop their payload copy; delete withdraws queued uploads | `activity_repository.dart`, `data/sync.dart`, `app/providers.dart` |
| API: `Run` + `ActivityType`, `Title`, `Notes`, `MetricsJson`, `RouteState`, `RouteChunkCount`; `RouteChunks` table; `PUT /runs/{id}`, `PUT /runs/{id}/route/chunks/{i}`, `POST /runs/{id}/route/complete`, `GET /runs/{id}/route`; capabilities `runs.activity-type`, `runs.routes`; migration `AddRunRoutes` (additive) | `Entities.cs`, `GoHardDb.cs`, `Contracts.cs`, `JournalServices.cs`, `Endpoints.cs` |
| CI: optional Maps key secrets, never printed | `ci.yml`, `ios-unsigned-ipa.yml`, `ios-dev-ipa.yml` |
| Removed: screen-owned GPS (`run_tracking.dart`, `RunScreen`, `RunHistoryScreen`) | |

**Found and fixed during verification.** (1) GPS fixtures showed white-noise jitter inflating distance 45 % and
10 minutes standing adding 300 m: smoothing, a 1.5 × accuracy threshold and the Doppler-speed gate (speed stored only
with its accuracy, since Android reports 0.0 for "none"). (2) Saving queued several commands inside one transaction
and each started a dispatch inside it ("transaction used after being closed"): `submit(dispatch: false)` and one
dispatch after commit (found by `run_walk_recorder_test`). (3) The "Route not recorded" panel overflowed at a fixed
height. (4) On the emulator the map opened on the whole world until zoomed: the first position now frames it at
street level. (5) `DevicePrefs` gained three fields; the stored value stays readable from the two-field form.

**Checks run.**
- `flutter analyze`: clean. Full `flutter test` once (sync, database and Today are shared): all passed after updating
  3 motion tests for the stored preference format; new `track_math_test` (16, SYNTHETIC GPS fixtures), 
  `run_walk_recorder_test` (7, real Drift file + fake account), `run_walk_ui_test` (5). Today/Train/widget tests
  updated for "Run / Walk", Start/Resume and the recorder.
- API: `dotnet test -c Release`: 189 passed, including new `RunRouteTests` (2: idempotent chunk, mismatch conflict,
  invalid ranges, partial upload then complete, paged reads, snapshot without points, ownership, delete and account
  erasure remove chunks, older-client run shape, edits). `verify-api.ps1` against the local API: all passed, including
  the new Run / Walk check.
- Device (`emulator-5554`, Pixel 7 image, Android 16 / API 36, debug build, local API, **simulated GPS** through
  Android's test location provider, old Maps key in the local gitignored `secrets.properties`):
  `journey_runwalk_test` (new, two phases, not default) **passed**: Ready with GPS ready; Walk recorded; Stats and Map
  views, Zoom in kept while fixes arrived, Recenter, Pause added nothing over 8 s; with another app in front and with
  the screen off distance kept growing (foreground service; notification "GoHard is recording your walk" captured);
  force-stop while recording; new process: "Walk interrupted", Resume, Finish, Save **offline**, Saved / Splits /
  Charts / History; online: the account holds one walk titled "Morning walk" with route state complete, 189 entries
  in order with one `interrupt` (210.2 m); then a short run. Captures `docs/evidence/screenshots/runwalk-01…19`,
  recording `docs/evidence/recordings/runwalk-flow.mp4`, notification check `docs/evidence/runwalk-notification.txt`.
  Earlier attempts failed on a too-strict pause tolerance (fixes in flight), the account email in phase 2, a record
  matcher, a screenshot call, and four times on emulator storage (`INSTALL_FAILED_INSUFFICIENT_STORAGE`: the 6 GB data
  partition; the runner now builds the grant APK for the device ABI only, and the emulator was rebooted before runs).
- `journey_coldstart_test` (default run; real process end) passed: an open run left recording is "Run interrupted" in the new
  process, then finished and saved. `journey_device_test` (default run) passed after two fixes to the journey itself: it
  never skipped the coach setup added on 16 Oct, and its in-process `main()` restart left the first app instance
  recording (not a real restart; replaced by leave-and-resume, real restarts being the two journeys above).

**Not verified:** a physical phone (outdoor GPS accuracy, real lock-screen and app-switch behaviour, battery, Doze),
iOS anything beyond CI compilation (background location, Maps SDK, permission prompts), the hosted API (needs `main`
deployed), Google Cloud key restrictions and billing (no console access), `journey_today_panels_test` and
`journey_appwide_test` (updated, not rerun), TalkBack/VoiceOver by ear.

## 18 October 2026 — steps, intervals, voice and alerts, personal bests, saved-foods guidance (branch `feature/steps-intervals-audio-records`, from `feature/run-walk` = `main` at `ff65c88`)

From `GoHard_Steps_Intervals_Audio_Records_Coach_Claude_Prompt.md`. Design and contracts: docs/RUN_WALK.md › Steps,
› Intervals, › Voice and alerts, › Personal bests; docs/COACH.md › Saved foods, › Run / Walk.

**Discrepancy reported, decided by the user.** The prompt's item 5 assumed existing "saved meals" and "recipes". None
exist on any branch, worktree or handoff (searched 18 Oct 2026): only saved foods (Favourites, My foods). The user chose
guidance to the existing saved foods; nothing was rebuilt or invented.

| Change | Where |
|---|---|
| Steps: native adapter (Android `TYPE_STEP_COUNTER` + Health Connect `StepsRecord` aggregate, steps read only; iOS `CMPedometer` live + history), recording tally over recorded time only (batches split at pause boundaries ≤ 10 s, counter resets, partial vs measured vs not counted vs unknown), opt-in per account in Customize tracking with an optional goal, Today row with source and time, nothing daily stored or synced | `steps.dart`, `move_prefs.dart`, `move_widgets.dart`, `recorder.dart`, `track_math.dart` (`recordingShare`), `MainActivity.kt`, `AppDelegate.swift`, manifest, `build.gradle.kts` (minSdk 26, `connect-client` 1.1.0), `Info.plist` |
| Intervals: plan + editable preset (NHS Couch to 5K week 1), setup sheet with to-scale preview and total, saved setup, phase from the recorder's active clock (pure), Skip phase, Intervals finished → Continue freely / Finish and review, auto-pause off during intervals (preference kept), timeline in details | `intervals.dart`, `move_widgets.dart`, `recorder.dart`, `run_walk_screens.dart`, `activity_detail.dart` |
| One announcer: structured cues with keys (no repeats), priority, coalescing, stale drop, cancel on pause/finish/discard/account change, no replay after restart (first look primes), coach line in the page, native TTS (`flutter_tts` 4.2.5, MIT) with ducking, installed-voice choice + preview, vibration (Android also locked), countdown ticks; iOS background `audio` for speech only | `announcer.dart`, `move_widgets.dart` (`CoachLine`, voice sheet), `run_walk_screens.dart`, `Info.plist` |
| Personal bests: fastest continuous stretch by elapsed time inside one segment (`metrics.efforts`), longest GPS distance, Run and Walk separate, typed/corrected/legacy excluded, projected (edits/deletes/type changes at once, no double awards), celebrated once from the save path only when there was something to beat; History row → list, Train › Progress, badge on details | `records.dart`, `recorder.dart`, `activity_history.dart`, `activity_detail.dart`, `train_screen.dart` |
| Saved foods on Eat: once-per-stage hint (only while Eat is really in view), shortcut to Add food on Favourites / My foods for the day shown (nothing logged), help explains the two lists | `eat_screen.dart`, `log_food_screen.dart` (`scope`) |
| Robustness found on the way | `recorder.dart` `_drain` no longer touches a disposed recorder (seen once at the end of a device journey) |

No API change: `metrics` is an opaque object (≤ 4,000 characters; skips capped at 100) and edits merge into it, so
older apps keep the new fields and the hosted server needs no migration or capability. Route entries were deliberately
left unchanged (an older app would fail on an unknown entry type).

**Found and fixed during verification.** (1) The announcer read a provider while being disposed (recorder tests).
(2) Steps: a long stretch across Pause marked every paused walk "partial"; now only when more than 10 steps are left
out (a calibration constant, marked). (3) The coach's interval button on Ready and the long plan summary pushed Start
off a 390 × 844 screen; the coach now says words only. (4) Large text at 320 px broke the phase name and Pause/Finish
letter by letter; Skip phase moves under the phase and the buttons stack. (5) A merged phase + distance message cut
"0.5 km" to "0" (split on the first dot), found on the emulator; fixed and unit-tested. (6) Eat's saved-foods hint was
used up while Eat was built off screen behind Today (tabs stay built); it is now chosen only while Eat is the tab in
view (regression check in `move_ui_test`). (7) The steps goal field's controller was created lazily in `dispose`.
(8) The daily-steps poll now lives with the row that shows it.

**Checks run.**
- `flutter analyze`: clean. Full `flutter test` once after the shared changes (recorder, Today, Eat, Train): 552
  passed, after 3 Run / Walk UI tests were adjusted for the longer Ready page and the new rows; then the affected suites
  again after each later fix. New: `move_logic_test` (20: intervals, steps, cues, records; SYNTHETIC readings and GPS),
  `run_walk_extras_test` (5: recorder on a real Drift file with a restart, steps across pause and a counter reset,
  phase kept, no replay, saved metrics; announcer priority, staleness, cancel, voice off), `move_ui_test` (5).
- Renders (`move_render_test`, gated): six themes of Ready with intervals, Recording (Stats and Map) with the phase bar,
  coach line and steps, the interval setup, details with intervals and bests, Today's steps row; 320 px at 2× text for
  Ready, Recording and Today: `docs/evidence/design/six-themes-{runwalk-ready-intervals,runwalk-recording-intervals,runwalk-recording-map,interval-setup,activity-intervals-best,today-steps}.png`, `state-large-text-320-*.png`.
- Android debug build with the Kotlin adapter and Health Connect: built.
- Device (`emulator-5554`, Pixel 7 image, Android 16 / API 36, debug build, local API; **SIMULATED GPS** through the
  test location provider at about 3.5 m/s, **SIMULATED steps** via `GOHARD_SIM_STEPS`, labelled on screen; the emulator
  has no step counter): `journey_move_test` (new, two phases, not default) **passed**. Phase 1: Customize tracking ›
  Steps on with a goal; Today's steps row with its source and time; a favourite marked from Add food (nothing logged);
  back on Eat the coach offered it once and Open Favourites opened Add food on Favourites, nothing logged; a short free
  run saved; interval setup cut to 2 × (15 s run, 15 s walk); Voice on, updates every 0.5 km; the walk prompt on screen,
  Pause froze the phase's time left, Skip phase → "Final round. Run for 15 seconds.", Intervals finished → Continue
  freely, "0.5 km completed. Active time … Avg. moving pace … /km."; left recording; force-stop **and an emulator
  reboot**. Phase 2: "Run interrupted", Resume, Finish, Save; "Your longest run so far, 0.50 km." once with the badge;
  History › Personal bests; Eat in the new process kept its usual words (hint not repeated) and its help opened
  Favourites. Captures `docs/evidence/screenshots/move-01…15`. The emulator's text-to-speech received the phrases but
  nobody listened: speech, ducking and vibration were **not** checked by ear or hand.
  Runner changes: this journey reads its phase from the phone (both phases one build, so phase 2 needs no reinstall:
  the emulator's 6 GB partition had no room for a second 197 MB copy) and the emulator restarts between the phases.
  The emulator's low-storage reserve was lowered (`settings put global sys_storage_threshold_percentage 2`,
  `sys_storage_threshold_max_bytes 157286400`): an emulator setting, not the app. Earlier attempts failed on: the
  `GOHARD_SIM_STEPS` argument splatting, a leftover test GPS provider, the same `log-food` key on Today and Eat, a
  sheet filled by the keyboard, the coach header scrolled out of the lazy list, "Service has disappeared" (three times,
  retried), storage (four times), the "0.5 km" merge bug (app, fixed) and the off-screen hint (app, fixed).

**Not verified:** a physical phone (step accuracy against counted steps, Health Connect with real data and its
permission screens, Core Motion prompts, speech heard by ear, ducking with music and restoring it, calls, Bluetooth
headphones, lock-screen speech and vibration, battery), iOS beyond CI compilation, TalkBack/VoiceOver by ear, the
hosted API with this build (no API change is needed). `flutter_tts` applies the Kotlin Gradle plugin: Flutter warns a
future release will refuse that until the plugin migrates.
- CI `ci` run 84 on `46c5503`: passed. Unsigned IPA `ios-unsigned-ipa` run 32 on `46c5503` (branch
  `feature/steps-intervals-audio-records`, build number 32, hosted API): passed; artifact `GoHard-Dev-unsigned-ipa`
  (`GoHard-Dev-unsigned-32.ipa`). It compiles the Core Motion bridge and `flutter_tts`; nothing ran on an iPhone.
  `main` and Railway are unchanged.

## 18 October 2026 (corrections) — Steps discovery, Run / Walk Ready order, shared icons (same branch, from `9d39cd4`)

From `GoHard_Steps_RunWalk_UX_Corrections/CLAUDE_PROMPT.md`, the selected board `references/approved-ready-option-1.png`.

| Change | Where |
|---|---|
| The supplied 12 SVG glyphs as assets, one `GoIcon` tinted from the theme (`flutter_svg` 2.3.0, MIT), used on Ready, the map buttons, Today's Start and Steps, Me › Steps; buttons and group rows take a glyph in the icon's place | `assets/icons`, `core/go_icon.dart`, `core/widgets.dart`, `route_map.dart` |
| Steps' one sheet (Count steps, access state and fix, goal, Show Steps on Today), opened from Today's tile, Me › Activity & tracking › Steps and Ready's row; removed from Nutrition's Customize tracking; existing choices kept (same store; `stepsHidden` added, display only) | `steps_ui.dart`, `move_prefs.dart`, `today_screen.dart`, `me_screen.dart`, `nutrition_tools.dart` |
| Today: Steps tile beside Run / Walk, shown before steps are on (Enable, no number or bar), every state distinct; History under the pair; the coach introduces Steps once from the account's second day | `today_screen.dart` |
| Ready in the approved order, Start in a bar of its own, every setting above it; "Your setup" rows with real states, Auto-pause's own sheet, the Steps row; compact one-line GPS; map controls as on the board; Expand map follows the same position | `run_walk_screens.dart`, `steps_ui.dart`, `route_map.dart` |
| Recording: the animated guide with the mouth bubble replaces the small static portrait in the coach line | `move_widgets.dart` |
| Voices: only offline voices offered or used (Android `network_required`); explained when none | `announcer.dart`, `move_widgets.dart` |

No backend, migration, entitlement or new health integration. Saved meals / recipes remain absent (reported 18 Oct; the
user chose guidance to Favourites and My foods); nothing here touches food.

**Found and fixed.** The two tiles in `IntrinsicHeight` (a panel's `LayoutBuilder` cannot report intrinsics): a plain
row. Setup rows broke words at 2× text on 320 px: the state goes under the label there. The coach-off layout constant
left the Steps row 13 px under Start (caught by the inset test). A brand-new account's first Today showed the Steps
invitation instead of the plan's greeting: now from the second day only.

**Checks run (focused, no full suite: the earlier full run passed and these changes are UI and wiring).**
- `flutter analyze`: clean. 13 affected suites together, 217 passed: `move_ui_test` (new: Ready's fit at 390 × 844
  with 47/34 px insets, coach on and off; setup summaries and auto-pause kept apart from intervals; 320 px at 2× text
  reached by scrolling without overflow; one sheet from Today and Me; no permission request by opening Today, a sheet
  or Me; Enable asks once; choices saved before the move kept; tile and Enable with the coach off; hiding the tile
  changes nothing else; network-only voices left out), `run_walk_ui_test`, `today_ui_test`, `me_ui_test` (three
  expectations updated for the new layout: History under the pair, a fourth filled button "Enable", Me rows scrolled
  into view before tapping), `water_ui`, `widget`, `coach_companion`, `eat_ui`, `food_ui`, `move_logic`,
  `run_walk_extras`, `theme`, `today_states`.
- Renders (Flutter widgets, not a phone; map drawn without a key): before/after at 390 × 844 with the notch insets,
  coach on and off, first use and steps on, Ready default/configured, 320 px at 2× text:
  `docs/evidence/ux-corrections/ux-{before,after}-*.png`; six themes: `docs/evidence/design/six-themes-*.png`.
- Device (`emulator-5554`, API 36, debug, local API; SIMULATED steps and GPS): `journey_ux_test` (new, not default)
  **passed**: Today's Steps tile → Enable → the simulated count with its source; Ready with every row and Start in view
  and above Start; intervals, voice and auto-pause set from their rows, summaries read back ("Run 1 min · Walk 90 s ·
  × 8", "On · every 1 km", "Not used with intervals"); Start, Pause, Resume of the same activity; Discard. Captures
  `docs/evidence/screenshots/ux-01…05`. In `ux-04` the map shows the whole region: the journey's scroll-into-view drag
  started on the map, which (as designed) leaves Follow; the first try failed only because the emulator had no network
  right after a reboot. The simulated step source allows at once, so the refusal path is covered by `move_ui_test` only.

**Unavoidable differences from the board.** No footprint photograph on the Steps tile (none supplied; the panel is
plain); the board's map is a satellite image (the app uses the Google map or, without a key, its drawn route); the
tiles are not forced to equal height.

**Not verified:** a physical phone (Ready's fit on other phone sizes and with system font sizes, VoiceOver/TalkBack,
an Android voice in airplane mode, Motion & Fitness and Health Connect prompts), iOS beyond CI compilation.
- CI: run 86 on `970743e` **failed** in `motion_test` (2 tests tapped Me rows that the new Activity & tracking group
  had pushed under the floating bar; not in the focused set). Fixed in the test only (`0c6c68b`); CI run 87 on
  `0c6c68b`: **passed** (full suite + API). Unsigned IPA `ios-unsigned-ipa` run 33 on `970743e`, build number 33,
  artifact `GoHard-Dev-unsigned-ipa` (`GoHard-Dev-unsigned-33.ipa`): passed; `0c6c68b` changes no app code, so this IPA
  is the app at the final commit. `main` and Railway unchanged.

## 18 October 2026 (Today, history, water) — matching tiles, history in Train and Eat, one-tap water (same branch, from `ab073c3`)

From `GoHard_Today_History_Water_Corrections/CLAUDE_PROMPT.md`; BEFORE = the supplied iPhone screenshot
`references/current-iphone-problems.jpeg` (IPA 33).

| Change | Where |
|---|---|
| Run / Walk and Steps: equal width and height side by side (`IntrinsicHeight`; `_Module` without its `LayoutBuilder`, `PanelSurface(fill)`: photo full height, action at the bottom), stacked at large text / narrow; Steps gets the supplied photograph (resized JPEG, provenance in DESIGN.md) with its icon kept; the goal line and bar only with a goal, then source · time | `today_screen.dart`, `core/widgets.dart`, `assets/images/steps-footprints.jpg`, `pubspec` (already registered folder) |
| Today: no Run / Walk History link; Nutrition without the goals / sliders line | `today_screen.dart` |
| Train › Workouts: **Run / Walk history** beside Run / Walk (moved up from the bottom History card, not duplicated) | `train_screen.dart` |
| Eat: **History** under the date (calendar + days with entries; opens the day, Back to today); labelled **Customize tracking**; earlier days are not set against today's goals; a one-time coach line "Your past meals and water are in History." once earlier days exist | `nutrition_history.dart`, `eat_screen.dart`, `nutrition_tools.dart`, `providers.dart` (`waterEntriesProvider`) |
| Water: **+250 mL / +8 fl oz** in one tap with a 5 s Undo of that entry, **Other amount** sheet, the line opens details; quick add only on today | `nutrition_tools.dart` (`WaterRow`, `addWater`, `_OtherWater`), `water.dart` (`everyday`) |

No backend change: water's add/remove commands and their idempotency and revision rules are reused as they were.

**Found and fixed.** Eat's header with History beside the arrows overflowed 93 px at 2× text on 320 px: History moved
under the date. The calendar marked the phone's real date as today instead of the app's day (`currentDate`). An
earlier day showed today's water goal as its bar: past days' goals were never kept, so no goal comparison on them (food
and water). Undo bars used to stay until dismissed (a SnackBar with an action persists by default): 5 s, one at a time.

**Checks (focused).** `flutter analyze`: clean. Affected suites together (Today, water, water model, Eat, Train,
move, widget, food, tracking sync, motion, coach, Run / Walk UI, Me, Today states, theme): all passed after updating
expectations that described the old layout (Today's History link, Customize tracking on Today, the water plus opening
the sheet, tile heights now equal, tests tapping a shared `log-food` key, a header row that grew). New: one tap → one
entry → Undo removes that id → bar gone after 5 s; +8 fl oz stored as 236.588 mL; Other amount; History lists an earlier
day with its water, opens it dated, Other amount logs on that day, Back to today; tiles equal; the Steps image is the
supplied asset. Renders (widgets, not a phone): `docs/evidence/today-history-water/` (Today Blue Light and Pink Dark
at 390 × 844 and full height, 320 px at 2×, Eat today, History, an earlier day, Train). Device (`emulator-5554`, API 36,
debug, local API, SIMULATED steps): `journey_today_water_test` (new, not default) **passed**: water on in Eat; Today
+250 mL → 250 mL at once; Undo → 0 mL; another +250 (kept, captured with its Undo bar); Other amount 330 → 580 mL; the
Undo bar gone by itself; yesterday from Eat's arrow, Other amount 500 there; History lists yesterday "· 500 mL water",
opens it dated; Back to today; Train › Run / Walk history; Blue Light and Pink Dark. Captures
`docs/evidence/screenshots/thw-01…08`. Earlier attempts: three "Service has disappeared" attach failures and one
emulator without network after a reboot (emulator restarted), and three journey expectations (a total without a goal
reads "250 mL"; Undo tapped after a slow capture; the history page of a new account has no bests row).

**Known limit.** The 5 s Undo bar floats above the navigation bar and can briefly cover the lower edge of the Run /
Walk and Steps tiles (including Start) while it shows; it can be swiped away.

**Not verified:** a physical phone (photo crop on other phone sizes, VoiceOver/TalkBack, real Health Connect / Core
Motion counts), iOS beyond CI compilation. Recipes / multi-food saved meals remain out of scope (unchanged).
- CI: run 89 on `6477eab` failed at `flutter analyze` (an unused import left in `move_render_test`); fixed in the test
  only (`f5daa33`); CI run 90 on `f5daa33`: **passed**. Unsigned IPA run 34 on `6477eab`, build number 34, artifact
  `GoHard-Dev-unsigned-ipa`: passed; `f5daa33` changes no app code. `main` and Railway unchanged.

## 18 October 2026 (Today option 2) — photo-header Run / Walk and Steps tiles, inline water Undo (same branch, from `4b704fa`)

From `GoHard_Today_Option_2_Polish/CLAUDE_PROMPT.md`; target `references/approved-today-option-2.png`, BEFORE =
`references/current-iphone-before.jpeg` (IPA 34) and the earlier device captures (copied to
`docs/evidence/today-option-2/before-device-*`).

| Change | Where |
|---|---|
| Run / Walk and Steps as two separate photo-header tiles (`_HeaderTile`: short photograph strip with the label on its pale side, content, one action at the bottom), equal height side by side, stacked at > 1.3× text or < 350 px; `_Module(fill)`, `_Cells` and `PanelSurface(fill)` removed | `today_screen.dart`, `core/widgets.dart` |
| Run / Walk: check + "Walk/Run completed" / "today"; distance the main figure, time under it; no Distance/Time labels or second title; **Start new** (full width) opens Ready; open states keep **Resume**; empty keeps **Start** | `today_screen.dart` (`_TileState`, `_RunCardState`) |
| Steps: label in the header, footprints icon, count, goal and bar only with a goal, source and "Updated <time>" on their own lines (locale clock format, non-breaking); **Set a goal** / **Edit goal** open the shared Steps sheet | `today_screen.dart` (`_StepsCardState`) |
| Water Undo inline: for 5 s it takes Other amount's place ("Undo 250 mL"), removes exactly that entry, then Other amount returns; no SnackBar over the tiles; announced to screen readers | `nutrition_tools.dart` (`lastWaterProvider`, `WaterRow`, `addWater`) |

No backend change.

**Found and fixed.** In dark themes the Run / Walk figure and time were near-white on the pale tile (styled from the
page, not the tile): they now take the tile's `PanelTheme`. "Start new" and "Run completed" wrapped in a 174 px tile:
the button is full tile width and the paddings are 14–16 px. A full-width header strip can only crop the photograph
vertically, which put the label on the runner's shoe: the photograph now takes the strip's trailing 72 %.

**Checks (focused).** `flutter analyze`: clean. `water_ui`, `today_ui`, `move_ui`, `widget`, `coach_companion`,
`motion`, `eat_ui`: 112 passed, after updating expectations of the old layout (Distance/Time labels, "Run finished
today", Start after a finished run, the Undo bar, the source · time line, the photo's share of the tile). New checks:
inline Undo removes that entry, keeps the line's height, no SnackBar, goes away after 5 s; Start new opens Ready;
"Updated" is in the phone's clock format and cannot wrap before AM/PM; Set a goal opens the Steps sheet and sets no
goal; Edit goal with a goal; the header photo is the bundled footprints asset; the strip stays at 2× text. Renders
(widgets, not a phone): `docs/evidence/today-option-2/` and `docs/evidence/design/six-themes-today-steps.png`,
`state-large-text-320-today-steps.png`. Device journeys updated for the new wording ("Run completed", "Start new").
Device (`emulator-5554`, API 36, debug, local API, SIMULATED steps): `journey_today_water_test`, updated for the inline
Undo and Set a goal, **passed** (one earlier attempt passed its tests but lost the driver while copying captures:
"Service has disappeared"). Today's header tiles in Blue Light and Pink Dark; Set a goal opens the Steps sheet and
leaves no goal; +250 mL → Undo 250 mL in the water line → 0 mL; another drink kept with Undo shown (Start not covered or
moved), Other amount back after 5 s; Other amount 330 → 580 mL; Eat History; Train › Run / Walk history. After:
`docs/evidence/screenshots/thw-02, 03, 08`; before: `docs/evidence/today-option-2/before-device-thw-02, 03, 08`.

**Not verified:** a physical phone (photo crops on other sizes, VoiceOver/TalkBack wording, real Health Connect / Core
Motion counts), iOS beyond CI compilation.
- CI run 92 on `59904a6`: **passed**. Unsigned IPA run 35 on `59904a6`, build number 35, artifact
  `GoHard-Dev-unsigned-ipa`: passed. `main` and Railway unchanged.

## 19 Oct 2026 — Unexpected "Your sign-in expired" sign-outs (`fix/auth-sign-out`, from `main` c586864)

Lifetimes: access 30 min, refresh 60 days, single-use rotation (repository defaults in appsettings.json; the hosted
service is configured only with `GOHARD_Auth__SigningKey`, per RELEASE_AND_ROLLBACK.md; Railway itself was not read).
The notice is shown in one place only: `Api._refresh` when `POST /auth/refresh` answers 401 and the session epoch still
matches, i.e. when the phone presents a refresh token the server no longer accepts (already used, expired, or revoked).

- **Confirmed defect 1 (reproduced, fixed):** request A sent with an expired access token; request B gets 401, refreshes
  R1 → R2 (R1 revoked) and finishes; A's 401 arrives after that, `_refreshing` is clear, so A refreshed again with the
  revoked R1 it had captured, got 401, and signed out the valid session (rotation keeps the epoch). Happens whenever two
  authenticated requests overlap after the 30-minute access token expired: resume (sync, pull, weather, coach) and the
  45-second poll while the app is open. `session_refresh_test` reproduced it on the unchanged code (signed out) and
  passes with the fix: a 401 refreshes only if nobody rotated since it was sent, otherwise it retries with the current
  token; a delayed 401 for a previous account refreshes nothing; a refresh 401 signs out only if it rejected the refresh
  token the session still holds.
- **Confirmed defect 2 (reproduced as code behaviour, fixed):** if saving the rotated pair failed, the request threw
  and the revoked token stayed on disk, to be restored at the next start (→ the notice). The iOS keychain items were
  "when unlocked" (flutter_secure_storage default) while GoHard syncs in the background during a locked-screen run.
  Now the pair stays in memory and is saved on the next foreground, and keychain items are "after first unlock"
  (the plugin reads items saved under the old setting and moves them on the next write).
- **Not fixed, remaining risk:** a refresh the server accepts whose response never reaches the phone (iOS suspends the
  app mid-request, connection drops) leaves the phone with the revoked token; the next refresh is rejected by design
  (FoundationTests: a replayed refresh token is 401). Closing it needs a server decision: a short reuse grace window for
  a just-rotated token. Not implemented.
- Checks: `session_refresh_test` 7 (incident, silent refresh, shared refresh, delayed 401 across accounts, offline/503/
  500/429 keep the session, genuine revocation still signs out keeping the phone's data, unsaved rotation recovered
  after restart); `data_layer_test`, `coach_ask_test`, `me_ui_test`, `widget_test`, `tracking_sync_test`: 69 passed.
  No API code changed. Not observed on a real iPhone.
- CI run 100 on `69dd1c5`: **passed**. Unsigned IPA run 38 on `69dd1c5`, artifact `GoHard-Dev-unsigned-ipa`: **passed**.
  `main`, Railway and Cloudflare unchanged; `feature/owner-exercise-videos` untouched.

## 19 Oct 2026 — Lost refresh responses (`fix/auth-sign-out`, approved narrowly bounded recovery)

- **Reproduced:** `RefreshRecoveryTests.a_lost_refresh_response…` on the unchanged API: refresh R1 accepted (R1 → R2), the
  answer discarded, the retry with R1 → 401. On the phone (`session_refresh_test`, strict server): a lost answer is an
  ordinary offline failure, R1 kept, nothing decided; the next request refreshes with R1 → 401 → "Your sign-in expired".
  The real client retries on its next authenticated request: a sync retry (5–120 s back-off), the 45-second poll while
  open, or the next resume.
- **Recovery (server only, migration `AddRefreshTokenReplacement`: nullable `RefreshTokens.ReplacedById`):** the
  replacement is derived (HMAC under a key from the signing key), so the server returns the SAME replacement to the
  immediate predecessor within `Auth:RefreshRecoverySeconds` (default 300) from the rotation while it is unused; retries
  never extend it; rotation is atomic (conditional update in a transaction). See docs/ARCHITECTURE.md › Refresh recovery.
- Tests: `RefreshRecoveryTests` 7 (lost response + repeated retries, 8 concurrent refreshes → one chain, window counted
  from the rotation and not extended, older token rejected, logout/expiry/deleted account final, account isolation,
  window 0 off) and `FoundationTests` (rotation check restated) 16 passed; `session_refresh_test` 9 passed (both lost-
  response variants plus the existing delayed-401 and secure-storage cases). No client code changed: IPA 38 is
  compatible (it already retries with the previous token).
- Deploy needs: the migration (the existing pre-deploy `migrate` applies it); optional `GOHARD_Auth__RefreshRecoverySeconds`.
  Rotations made before the migration are not recoverable. Not deployed; `main`, Railway, Cloudflare unchanged.
- CI run 102 on `13d1443`: **passed** (api, app). Server-only change: no new IPA; IPA 38 (`69dd1c5`) stays the app build.

## 19 Oct 2026 — One workout panel in Train › Workouts (`feature/workout-workspace`, from `GoHard_Workout_Workspace`)

- **Built:** preview, recording and result are three states of one panel in Train › Workouts, chosen by
  `ShellState.workout` (plan + occasion before Start, workout ID after). Today › Details opens the preview directly
  (nothing created) or the open workout as it is; Start/Resume (Today, preview, occurrence sheet, Train, the
  foreground dialog) and manual starts all end in the panel by ID, one at a time, and an occurrence with an open
  workout resumes it rather than starting another. The recorder (`WorkoutRecorder`, from `WorkoutScreen`) keeps every
  action and adds Last time · date (Set / Last time / Today), Use last values (fills only, asks before replacing
  typed values, never records), All sessions (read-only, newest first, real outcomes) and "Record set". Workouts
  gains "Scheduled today" from Today's projection. Design: docs/DESIGN.md › Workout panel.
- **Last time:** `exerciseHistory` in `progress.dart` (the existing `previousPerformance` policy generalised: identity
  + occurrence ordinal, counted training only, before the anchor, newest by start time, sets in recorded order, all
  of them). Preview anchors at now; recording at the session's start.
- **State:** drafts are written draft-only (`WorkoutRepository.saveDraft`) so a park/resume made elsewhere is never
  undone; the recorder adopts runtime changes from `runtimesProvider`. No API, migration or dependency change.
- **Tests:** `workout_panel_test` (history policy incl. same-day sessions, repeated and custom exercises, no identity;
  Last time's loading/unreadable/none/timed/bodyweight; a real local database through the shell: Details creates no
  workout or command, rapid Start makes one, Use last values asks/fills/records nothing, Record set stores kilograms
  from a pounds entry, history, tab switch, leaving and reopening keep the typed entry and rest deadline, Today's
  Resume keeps the same ID). Updated: `today_ui_test` (Details → preview, sheet via More options),
  `train_plan_ui_test` (target vs last time). Affected suites: today_ui, train_ui, train_plan_ui, projection: passed.
- Renders (`render_test`, GOHARD_RENDER): `state-workout-*` (preview blue light, pink dark; recording green light,
  blue dark with a typed entry; history sheet; result) and `state-large-text-workout-*-320` (2× text; the table stacks).
- Journeys whose workout steps used the old back gesture now switch tabs instead (appwide, captures, coach, coldstart,
  plan, today_panels, journey_test); only `journey_workout_panel_test` was run natively for this change.
- **Native (Android emulator Pixel_7, local API, new account):** `test-android.ps1 -Only journey_workout_panel_test`,
  two phases, **passed**. Phase 1: Details → preview with no workout; a manual session of the plan's first exercise
  through the same panel (result, Done); Details → last time 40 kg × 10, 42.5 kg × 8; Start; Use last values asked
  before replacing 45 and filled 40 × 10 with nothing recorded; Record set; All sessions and About above the panel and
  back; a typed 50 kept across Today ↔ Train, All workouts (one open workout) and Today's Resume. Phase 2 (new process,
  same install): Resume → the same workout with its one set and the typed 50; Finish → "Finished partially".
  Captures `docs/evidence/screenshots/wp-01…05`, recording `docs/evidence/recordings/wp-recording.mp4` (Start →
  compare/copy → record → history → leave/return). Not checked on an iPhone.
- CI run 105 on `21202e5`: **passed** (api, app). Unsigned IPA run 39 on `21202e5`, artifact `GoHard-Dev-unsigned-ipa`:
  **passed**. `main`, Railway and Cloudflare unchanged by this feature; owner-video branch untouched.

## 19 Oct 2026 — Progress: weekly goals, exercise trends, weekly recap (`feature/training-progress`)

Built on `feature/workout-workspace` (`717f3f7`, not merged to `main`). Handoff `GoHard_Progress_Claude_Handoff`. Rules:
docs/PROGRESS.md; design: docs/DESIGN.md › Progress.
- **API:** `WeeklyGoal` (key owner + Monday), `PUT /weekly-goals/{monday}` (revision-checked, 1–21 or null, omitted
  fields kept, Monday only, not ahead of the server's week), snapshot `weeklyGoals`, capability `goals.weekly`,
  migration `AddWeeklyGoals` (one new table, purely additive; erased with the account by cascade).
- **App:** `features/progress/` (weekly projection, trend index, goal repository, Progress view, goal sheet, trend
  pages, recap), `Kinds.weeklyGoal`, ack/snapshot mapping, conflict review (keep mine / use the account's), dispatch
  gate. The gate now also re-asks for capabilities when a command is held only because they are unknown (found by
  the journey: after an offline start, a held goal stayed queued after reconnecting; the same applied to Walk/route
  commands). Train's coach line on Progress is a fact from the weekly projection; the old Exercise history list is
  replaced by Strength trends.
- **Tests:** `progress_test` (10), `goal_sync_test` (3, real Drift file + fake authority), `progress_ui_test` (6, incl.
  320 px 2×, three looks, no coach request); updated `coach_companion_test` (new Progress line); `train_ui_test`,
  `coach_companion_test`, `food_test`, `data_layer_test`, `me_ui_test`, `projection_test`: passed. CI run 107 found
  `run_walk_recorder_test` racing the new capability re-check (its server switch landed while that check was in flight);
  the test now waits for that answer first. API
  `WeeklyGoalTests` + capabilities test: passed (Testcontainers PostgreSQL). Migration also applied to a disposable
  local database (`migrate seed-catalog`: Ready, 9 migrations), dropped afterwards; `gohard_rebuild_dev` untouched.
  Render: `six themes: train-progress` (fixture).
- **Native (Android emulator Pixel_7, branch API on a disposable database, new account):** `test-android.ps1 -Only
  journey_progress_test`, two phases, **passed**. SEEDED through the API (titles say "Seeded"): last week's goals 3/2,
  two bench sessions (88.5, 93 kg × 8), an older one (85), a walk (3.10 km). Recorded in the app: a bench session
  95 × 8. Progress 1 of 3 / 0 of 2 (inherited); trend Top set load · 8 reps with every session, a row opened the real
  session; recap 2 of 3, 1 of 2, highlight 88.5 → 93; offline goal change to 4/1 shown as pending. Phase 2 (new
  process, still offline): 1 of 4 pending; back online: account holds this week 4/1 (revision 1) and last week 3/2
  unchanged; the recap still says 2 of 3. Captures `docs/evidence/screenshots/progress-01…05`, recording
  `docs/evidence/recordings/progress-flow.mp4`. The first two runs failed on a test bug (an API read while offline)
  and on the capability gate above; the recap's figures were drawn in page colours on the pale panel (fixed, with a
  regression check) and the journey was run again.
- **Not verified:** a physical phone; the hosted API (goals need `main` deployed with the migration; until then the app
  shows goals as unavailable there).
- CI run 107 on `b059564`: app job failed (`run_walk_recorder_test`, above); CI run 108 on `57154fb`: **passed** (api,
  app). Unsigned IPA run 40 on `57154fb`, artifact `GoHard-Dev-unsigned-ipa`: **passed**. `main`, Railway, Cloudflare
  and the owner-video branch unchanged. The local owner-video API container was paused for the journey and restarted.

## Fix: exercise switching in the workout recorder (19 Oct 2026, `fix/workout-exercise-switch`)

- **Report (iPhone, IPA 40):** with Triceps pushdown at 3 of 3 sets, Next exercise and the All movements rows did nothing.
- **Cause (reproduced, traced):** both taps ran `_flushDraft()` (unawaited `saveDraft`: read the stored runtime, then write
  it back with the draft) and then saved the new selection. The draft save read before the selection was written and
  wrote after it, putting the previous exercise back; the panel adopted that stored runtime. Trace: save with the new
  ID, then an adopt of a stored runtime holding the old ID, with nothing after it. Introduced with the workout panel
  (21202e5). `journey_test` did not catch it: after Next it waits for the text "Bench press", which All movements always shows.
- **Fix:** runtime writes in `WorkoutRepository` run in turn (a read-then-write can no longer land over a newer write);
  one `_select` path for Next, the movement rows and an added movement folds the draft into the same write as the
  selection; adopting a stored runtime keeps the panel's own selection; the selected panel is brought into view when
  its top is off screen (no animation with reduced motion). An untouched suggestion is no longer stored as a typed
  draft. On the last movement the target line says so; there is no Next there.
- **Tests:** new `workout_panel_test` case through the real buttons and rows: Next and direct selection after the
  target, a typed draft on another exercise kept, back to the first with its 3 sets, rapid taps, last movement, the
  panel revealed on a 390×844 screen scrolled to the end; same workout, 3 sets, rest deadline and clock unchanged.
  It failed on the unfixed code ("Overhead press is the selected exercise"), and the reveal check failed with the
  reveal removed (panel at y = -706). `workout_panel_test`, `train_plan_ui_test`, `data_layer_test`,
  `today_states_test`, `render_test`: 56 passed. `flutter analyze`: no issues.
- **Native (Pixel_7, branch API on a disposable database, dropped afterwards):** `test-android.ps1 -Only
  journey_switch_test` (not default) **passed**: a manual workout of Triceps pushdown, Lat pulldown, Skull crusher
  (own exercise), Barbell row; three sets 45 kg × 12/10/10 and a typed 45 × 8; Next → Lat pulldown; row → Skull crusher;
  row → Triceps pushdown with its 3 sets and the 45 × 8 draft. Same workout ID, clock anchors identical before and after
  (manual exercises have no rest; the rest deadline is covered by the widget test). Captures `sw-01…04`. The first
  run failed on a test assumption (a manual workout shows no target line). The media API container was stopped for
  the run and restarted.
- **Not verified:** a physical iPhone.
- CI run 111 on `18588e7`: **passed** (api, app). Unsigned IPA run 41 on `fix/workout-exercise-switch` (`18588e7`),
  artifact `GoHard-Dev-unsigned-ipa`: **passed**. `main`, Railway and the owner-video branch unchanged.
- Verified on the user's iPhone with IPA 41 (user report, 19 Oct 2026). Follow-up: `journey_test` now checks that Bench
  press is in the selected movement's panel after Next (it used to accept the All movements row); `flutter analyze`
  clean, `workout_panel_test` passed. That journey was not rerun on the emulator (test-only change; user did not ask).

## 20 Oct 2026 — Body progress (`feature/body-progress`, from `main` e33ec42)

- **Base:** `main` e33ec42 contains the accepted exercise-switch fix 18588e7 (IPA 41), checked with `git merge-base
  --is-ancestor`. Policies: docs/BODY_PROGRESS.md.
- **Built:** Me › Body progress (replaces Body measurements; quiet link in Train › Progress): overview with latest
  weight, day-weighted 7-day average, weight over time, latest per metric, all entries; Log / Edit entry with optional
  waist, chest, left/right upper arm, left/right thigh, existing body fat and note, kg/lb and cm/in; Compare dates;
  How to measure (CDC NHANES 2017 manual, cited). API: additive columns + `RecordedAtUtc`, weight precision
  numeric(6,2)→(9,4) (lossless widening), `PUT /body-metrics/{id}` (`metric.update`, omit = keep, null = clear),
  capability `body-metrics.measurements`, migration `AddBodyMeasurements`. Old `BodyMetricsScreen` /
  `ActivityRepository` removed; every existing record is read unchanged.
- **Tests:** API `BodyMetricTests` + existing `Runs_and_body_metrics…` (2 passed, testcontainers PostgreSQL with all
  migrations). App `body_progress_test` (10), `body_progress_ui_test` (5), `me_ui_test` updated; full app suite
  `flutter test`: 612 passed; `flutter analyze`: no issues. Renders `body_render_test` (six themes of overview, log,
  compare, legacy state; 320 px at 2× text) in docs/evidence/body-progress — fixture renders, not captures. The 320 px
  test found the unit toggles overflowing (fixed: they stack at large text).
- **Native (Pixel_7, branch API on a disposable database `gohard_body_journey`, migrated then dropped):**
  `test-android.ps1 -Only journey_body_test` (not default) **passed** both phases on the second run. Phase 1: two
  SEEDED legacy weight entries (old shape, same day, no saved time) shown as "Average of 2 entries"; today's check-in in
  lb/in (198 lb, waist 35,5 in, left upper arm 16.25 in); a measurement-only waist entry for yesterday; Compare dates;
  body units → cm in Me › Units; today's waist corrected to 89.5 cm; Wi-Fi and data off (simulated outage), one more
  check-in saved on the phone. Phase 2 (new process): still pending; back online the account holds 5 entries, the
  offline one once, the corrected one at revision 2; deleting the offline entry moved the 7-day average 197.8 → 198.0 lb.
  Captures `body-01…05`, recording `docs/evidence/recordings/body-flow.mp4`. The first run failed on the journey
  itself (it looked for the waist row below the fold); fixed by scrolling to it. The owner-video API container was
  stopped for the run and restarted.
- **Not verified:** a physical iPhone (keyboard Done, VoiceOver, scrolling); the hosted API (not deployed: until
  `main` with the migration is deployed there, circumferences and corrections wait in the outbox and the app says so).
- CI run 115 on `71a3e29`: **passed** (api, app). Unsigned IPA run 42 on `feature/body-progress` (`71a3e29`), artifact
  `GoHard-Dev-unsigned-ipa`: **passed**. `main`, Railway, Cloudflare and the video branches unchanged.

## 20 Oct 2026 — Nutrition trends (`feature/nutrition-trends`, from `main` 14f6285)

- **Base:** `main` 14f6285 (Body progress, workout workspace, exercise-switch fix). Policies: docs/FOOD_DATA.md ›
  History & trends; design: docs/DESIGN.md › Eat.
- **Built:** Eat's History became **History & trends**: Week (Mon–Sun) / Month (calendar month), previous / next and a
  date picker (no wholly future period), Calories / Protein / Carbs / Fat / Water by the account's settings, known
  total, coverage and a daily average over the days with a known value of that metric, one bar per day with not
  logged / unknown / partial / recorded-zero marks, the chosen day with View day, every day of the period, and the
  previous calendar and day list behind **Calendar**. One pure projection (`intake_history.dart`) feeds all of it.
  Returning from a day keeps period, metric and day (account-scoped). **No server change:** the snapshot already
  carries all food and water history; no API, migration, dependency or permission.
- **Tests:** `nutrition_trends_test` (11: the handoff's week 10,710 kcal / 5 days / 2,142 average, unknown-only out
  and known zero in the denominator, per-nutrient coverage, water-only / food-only days, pending / review / deleted,
  correction and deletion through the grouped provider, Mon–Sun across years, 28/29/30/31-day months, so far and
  midnight), `nutrition_trends_ui_test` (4: week → chart → View day → return keeps the view, month to date, Protein,
  optional metrics follow settings, water error leaves food, fl oz, Calendar, 320 px at 2× text), `water_ui_test`
  updated (History's calendar is now behind Calendar), `eat_ui_test`, `food_ui_test`, `coach_companion_test`;
  `flutter analyze`: no issues. The 320 px test found the legend overflowing (fixed). Renders
  `nutrition_trends_render_test` (gated; six themes of week, month, an unknown day and protein; 320 px at 2× text) in
  docs/evidence/nutrition-trends — fixture renders, not captures. They found the coach bubble covering the title and
  weekday labels touching at large text (fixed: the coach goes under the title, weekdays shorten to one letter).
- **Native (Pixel_7, branch API on port 5136 with a disposable database `gohard_trends_journey`, migrated then
  dropped; the owner-video container on 5131 was left running):** `test-android.ps1 -Only journey_trends_test
  -ApiBase http://10.0.2.2:5136` (not default) **passed** both phases. Phase 1: last week SEEDED through the API
  ("Seeded …" entries: Monday complete, Tuesday not logged, Wednesday partial, Thursday unknown only, Friday water
  only, Saturday a recorded zero, Sunday complete): 2,530 kcal over 4 of 7 days, average 633 kcal; each day's words
  checked; Wednesday's journal opened; History & trends reopened on the same week and day; Month, Protein, Water;
  no food or water command was queued by viewing. Offline, Wednesday's pasta removed in that day's journal: 1,670 kcal,
  3 of 7 days. Phase 2 (new process): still 1,670 kcal; back online the removal reached the account and the totals
  stayed the same. Captures `trends-01…05`, recording `docs/evidence/recordings/trends-flow.mp4`. Runs before the
  passing one: two failed on the journey's own expectations (a wrong expected figure; a panel below the fold not yet
  built), one on "Service has disappeared", one attach timeout, and one on a timing-sensitive command count (made
  precise); one passing run had wrong capture steps and was rerun.
- **Not verified:** a physical iPhone (chart feel, VoiceOver, keyboard). Observed then: Eat's water line on an
  earlier day with no water read "0 mL" (fixed in `c5ddc93`, below).
- CI run 118 on `011c0c4`: **passed** (api, app). Unsigned IPA run 44 on `feature/nutrition-trends` (`011c0c4`), artifact
  `GoHard-Dev-unsigned-ipa`: **passed**. `main`, Railway, Cloudflare and the video branches unchanged.
- **Water wording fix (`c5ddc93`):** an earlier day with no water entries now reads "No water logged" in Eat's water
  row and its water sheet, not "0 mL" (no goal bar; label "Water, no water logged"). Today keeps its goal progress
  ("0 / 2,000 mL"); while entries are loading, or cannot be read, no amount is shown, as before. Test: `water_ui_test`
  "an earlier day without water says…". `scripts\test.ps1` passed (analysis clean, 629 tests); no emulator journey
  (wording only). CI run 120 on `c5ddc93`: **passed**. Unsigned IPA run 45 on `feature/nutrition-trends`
  (`c5ddc93`), artifact `GoHard-Dev-unsigned-ipa`: **passed**. **Not verified:** a physical iPhone. `main` and
  Railway unchanged.

## 20 Oct 2026 — Workout progression (`feature/workout-progression`, from `main` 4871cc2)

- **Base:** `main` 4871cc2 (exercise-switch fix, body progress, nutrition trends). Rules, storage and compatibility:
  docs/PROGRESSION.md; design: docs/DESIGN.md › Next targets. The approved three-screen mockup was not on this machine;
  the work follows its written description (workspace panel, Next time after Finish, review sheet).
- **Built:** deterministic, offline next-target rules (`progression.dart`: the two newest comparable sessions of the
  same plan workout, same exercise identity and occurrence, all planned sets at the target with reps at the top of the
  range, one user-chosen increment, 5% product guard, reason codes; never further back, never down, never sets/reps).
  Accepted targets are the plan definition's existing `targetLoadKg`, saved with the existing revision-checked
  `plan.revise` (`PlanRepository.setNextTarget`; same values queue nothing; an open builder edit is kept). UI: a
  *Next target* line under *Target in this workout* in the recorder, a *Next time* section after Finish and in the next
  preview (one pale card, rows for the rest, the selected Leon/Leona inline), the review sheet with Restore, the
  increment sheet, *How progression works*. **Server change:** `ExerciseIncrements` table (migration
  `AddExerciseIncrements`, additive), `PUT /exercise-increments/{key}`, snapshot list, capability
  `exercises.load-increment`; the phone holds increment commands from a server without it.
- **Tests:** `progression_test` (8), `progression_sync_test` (3, real Drift file: offline confirmation through
  restart, one command per confirmation and byte-identical retries, the next matching start freezes the accepted target,
  open and finished workouts and other workouts unchanged, plan revision conflict kept for review, increments per
  account / second phone / conflict / older-server gate), `progression_ui_test` (2: preview + Keep current save
  nothing and hide the same suggestion; a double tap saves once; selected exercise ID from the runtime, typed entry and
  workout survive; only Record set records; 320 px at 2× text), `train_plan_ui_test` (label updated). One full
  `flutter test` run: 641 passed, 1 failed (that label, then fixed and rerun green); the progression files were rerun
  after the last code change: 13 passed. `flutter analyze`: no issues. API: `ExerciseIncrementTests` added; full suite
  **199 passed**. `verify-api.ps1` against the branch API: every check passed, including the new increment check.
- **Renders** (fixtures, not captures; `progression_render_test`, gated): six themes of Next time, review, increment
  and help, and 320 px at 2× text, in docs/evidence/progression. They found the review filling before the profile
  and increments had loaded (kg and the current target instead of lb and the suggestion) and cut-off rep labels at
  large text (fixed: the form follows the records until the person types; fields stack with large text).
- **Native (Pixel_7, branch API on free port 5137 with a disposable database `gohard_prog_journey`, migrated then
  dropped; the owner-video container on 5131 was left running):** `test-android.ps1 -Only journey_progression_test
  -ApiBase http://10.0.2.2:5137` (not default) **passed** both phases, twice; the second run is on the committed code.
  Phase 1: a SEEDED plan ("Seeded upper plan", Upper body A, bench press 80 kg 3 × 6–8) and two complete sessions made
  through the app's own repositories; the preview offered *Choose your weight increment* (no load invented); 2.5 kg
  chosen; 80 → 82.5 kg reviewed and kept as it is (plan unchanged, suggestion hidden); the workout started, 85 typed,
  the next target accepted from the recorder with Wi-Fi and data off; same workout, Bench press still the selected
  panel, 85 still typed, no set; today's target 80 kg, next 82.5 kg; three sets recorded and finished offline. Phase 2
  (new process): 82.5 kg still on the phone; online, it reached the account; the three finished workouts keep 80 kg;
  the next matching session started with 82.5 kg. Real captures `prog-01…08` in docs/evidence/screenshots (the green
  boxes are the emulator's TalkBack focus).
- **Not verified:** a physical iPhone (feel, VoiceOver, keyboard over the review sheet). **Hosted:** increments need
  this migration deployed (Railway deploys `main`); until then they wait on the phone, targets sync already.
- CI run 123 on `b44efb0`: **passed**. Unsigned IPA run 46 on `feature/workout-progression` (`b44efb0`), artifact
  `GoHard-Dev-unsigned-ipa`: **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39496397224). `main`,
  Railway, Cloudflare and the exercise-video branches unchanged; not merged.

## 21 Oct 2026 — French and Arabic (`feature/localization-fr-ar`)

- Base: `feature/workout-progression` at `225c7b3` (code `b44efb0`), **unmerged**, used as a reported dependency because
  its progression panel is part of the surface; `main` (`4871cc2`) is its ancestor. Spec: GoHard_French_Arabic_Claude_Prompt.md.
- What: English, Canadian French and Modern Standard Arabic (RTL) app-wide — docs/LOCALIZATION.md (inventory in
  docs/LOCALIZATION_INVENTORY.md). 2,424 messages; device-only language choice (sign-in, setup, Me › Language);
  locale-aware formats; numeric input accepting French commas and Arabic digits; bundled Arabic fonts; translated
  exercise names, common foods, plan templates and coach guide; offline-voice speech in the app language; localized
  reminders and permission purpose strings; Ask GoHard reply language (additive optional API field).
- Checks: `check-l10n.mjs` OK (new, in CI); `flutter analyze` no issues; `flutter test` **691 passed**; API **200
  passed**. Renders (fixtures) in docs/evidence/localization/{fr,ar}; they found and fixed Arabic-Indic digits in
  dates, Arabic phase times shown in the wrong order, the run dial overflowing at 2× text, and long French one-word
  titles and tab names breaking or being cut. French renders had first come out in English (a test harness mapping,
  fixed and re-rendered).
- Native: `journey_language_test` partly verified (docs/LOCALIZATION.md › Verification): every step through the
  mid-workout switch to Arabic passed with the draft kept; reruns of the fixed test failed in the test driver
  ("Service has disappeared") four times, so the rest is covered by widget tests only. Captures and recording in
  docs/evidence/localization/native.
- **Not reviewed by a fluent French or Arabic speaker.** Not verified on a physical phone. Hosted API: deploy needed only
  for French/Arabic AI replies. Not merged; Railway, Cloudflare and exercise-video work untouched.
- CI run 125 on `d02b475`: attempt 1 failed one test (`coach_companion_test` › "no replay…", the CI-only flake seen on
  19 Oct; it passes locally in both full runs), attempt 2 **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39606994744). Unsigned IPA run 47 on
  `feature/localization-fr-ar` (`d02b475`), artifact `GoHard-Dev-unsigned-ipa`: **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39607063020).

## 21 Oct 2026 — Original GoHard branding (`feature/original-branding`)

- Base: `main` at `f4a1eb5`. Spec: GoHard_Original_Branding_Claude_Handoff (step 1 only: branding; no auth, signing,
  backend or deploy changes). Bundle/application IDs, display names, signing, Maps config and account storage untouched.
- What: the original GH/lightning badge (GoHardAPP `357a8b3`, unchanged masters in `design/brand/`) as the iOS and
  Android app icons (adaptive icon keeps the whole badge inside every mask), on the iOS and Android launch screens
  (warm-light/dark page colours, following the phone's appearance), and as a 44 dp badge beside the wordmark on
  sign-in / create account. The header GH mark is the same shape, now cropped to the glyph. docs/BRANDING.md has the
  derivations and `scripts/build-brand-assets.ps1` regenerates everything; `crypto` 3.0.7 pinned as a dev dependency.
- Checks: `flutter analyze` no issues; `brand_test` (5) plus `widget`, `localization`, `l10n_shell`, `today_ui`,
  `weather_contrast`, `session_refresh`, `theme` — 112 passed. Renders (fixtures) of sign-in, create account and the
  update notice in en/fr/ar, light/dark, 320 px at 2× text; Today header in six themes and over weather.
- Native (Android emulator, debug build installed as an update over the existing install): app drawer icon, cold launch
  (Android 12+ splash) in OS light and dark, sign-in, registration, French → Arabic switch, OS dark switch, Today header
  in OS light and dark. A disposable local account (brand-check-1021@example.test) was created for the header and then
  deleted through the API. TalkBack on the emulator was switched off for the scripted taps and restored. Evidence in
  docs/evidence/branding/{renders,device}/{before,after}.
- **Not verified:** iPhone (icon and launch screen are compiled only). Not merged.
- CI run 127 on `c5c5e7d`: **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39669382810). Unsigned
  IPA run 48 on `feature/original-branding` (`c5c5e7d`), artifact `GoHard-Dev-unsigned-ipa`: **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39669435464).

## 21 Oct 2026 — Authentication email: reset, verification, password change (`feature/auth-recovery-verification`)

- Base: `main` at `2ff9a9d`. Spec: GoHard_Authentication_Claude_Prompt.md. Code commit `4cce829`. Guide:
  docs/AUTHENTICATION_EMAIL.md. Already present and kept: registration, sign-in, hashing, rotating refresh with the
  recovery window, logout, password-confirmed erasure. Added: forgot/reset by emailed code, email verification and
  resend, signed-in password change. Resend is the one provider adapter; a capture transport exists for
  Development/Testing only. Migration `AddAccountEmail` (additive). Password policy for new passwords raised from 8
  to 15 characters (NIST SP 800-63B rev. 4, OWASP); existing passwords keep working.
- API: `AccountEmailTests` 14 passed (disclosure, purpose/account binding, expiry, attempts, cooldown and resend abuse,
  concurrent single use, restart persistence, reset token is not a session, old credentials and refresh recovery
  defeated, stamp race, wrong current password changes nothing, verification state and older clients, erasure,
  provider failure and ambiguous retry with one idempotency key, expired mail not sent, log redaction, capture refused
  in Production, limits). Full suite (Release) 214 passed.
- App: `flutter analyze` no issues; `account_security_test` 11 passed (forms and navigation, pasted/Arabic digits with
  leading zeros, errors vs no connection, unconfirmed reset, unavailable sender, older server, offline change,
  fr/ar at 320 px with 2× text, no credential in the outbox, same account keeps its pending work); `me_ui_test`,
  `brand_test`, `widget_test`, `check-l10n` (2,479 messages) passed.
- Native (Android emulator, capture API on a disposable database, disposable accounts): `journey_auth_test` was run
  ten times. Verified on the device: registration, Setup offering verification, the captured 8-digit code entered in
  the code field, the server marking the address verified, the offer disappearing (runs 7 and 8; two accounts
  verified in the database). The runs found and fixed two real problems (the capture route's code pattern, and the
  Setup offer requiring a confirmed capability where the app treats unknown as supported) and two journey-script
  mistakes. **Not verified on a device**: Me showing *Verified*, the signed-in password change, old-password
  rejection, sign-in with the new password keeping the open workout, and the forgot-password flow. Those runs were
  stopped by the emulator itself (INSUFFICIENT_STORAGE after each install, and driver attach failures "Service has
  disappeared" / "GetHealth … Collected" / attach hangs); the same steps are covered by the widget and data tests
  above. Disposable database dropped; no account remains.
- **Not done:** real email (no provider, DNS or Railway configuration exists; owner steps in the guide § 4 and § 8),
  iPhone. Not merged, not deployed; Railway, Resend and Cloudflare untouched.
- CI run 130 on `4cce829`: **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39697196717).
  Unsigned IPA run 49 on `feature/auth-recovery-verification` (`4cce829`), artifact `GoHard-Dev-unsigned-ipa`:
  **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39697208591).

## 23 Oct 2026 — Required email verification, Eat History & trends panel, one home for past workouts

- Base: `main` at `6c0cc79`. Spec: GoHard_Verification_Eat_Train_Claude_Prompt.md. Branch `feature/verification-navigation`.
  Guide: docs/AUTHENTICATION_EMAIL.md › 10 (boundary, migration `AddVerificationGrace`, rollout order). Contract and
  default `minimumClientContract` now 2 (older apps show *Update GoHard*). Registration without a sender is refused (503).
- API: `VerificationPolicyTests` 4 passed: a waiting account's token on every mapped signed-in route (over 40) gets 403
  `EMAIL_VERIFICATION_REQUIRED` except exactly the six identity routes; verification opens the data; a correctly signed
  token carrying the eligibility claim itself is still refused; refresh, sign-in, password change (15-character rule
  kept) and reset do not bypass it; legacy grace set by the real migration on unverified accounts only, unchanged by
  sign-in, refresh, resend and a new process, expired after 14 days, never marking anyone verified; a new account after
  the rollout has none. `AccountEmailTests` updated (forged profile fields refused, no account without a sender).
  Full suite (Debug, local) 218 passed. The shared test account fixture verifies through the real confirm route.
- App: `flutter analyze` no issues; `check-l10n` 2,491 messages; full `flutter test` passed after one contract-number
  fix in `food_ui_test` (713 + that file's 40). New: `verification_gate_test` (a 403 pauses the outbox untouched,
  survives a restart and lost answers, verifying sends the change once with its operation id, no downgrade offline;
  a new account's gate is stored before its session starts, per account), gate and sign-up widget tests, Eat panel
  placement/semantics/no-entries test, Train three-item preview + history action + empty case, Progress without the
  duplicates.
- Renders (Flutter widgets, fixture data): docs/evidence/verification-navigation/{before,after,after-fr,after-ar}:
  Eat, Train › Workouts (and empty), Progress in light/dark, 320 px at 2× text; the gate and Today's grace notice.
  "Before" made from `main` with the same render file. Reviewed by eye; found and fixed: the gate's brand under the
  title (moved above), and the panel link (also the existing recap link) exposing no tap action to screen readers.
- Native (Pixel_7 emulator, capture API on a disposable database, dropped afterwards): `journey_verify_nav_test`
  **passed**: registration lands on the code step with no frame of the app, the API refuses that account's snapshot
  (403), the captured code verifies, setup once, Today, snapshot 200, Eat panel → History & trends, Train › Workouts
  empty state → Workout history, Progress without them; account deleted. Captures docs/evidence/screenshots/vn-*.
  **Not verified on the device:** the restart of a waiting account. Three two-phase attempts failed on the emulator's
  reinstall (`INSTALL_FAILED_INSUFFICIENT_STORAGE`, 491 MB free); stopped there. Restart persistence is covered by
  `verification_gate_test` (real Drift file, restart).
- Not done here: merge, deploy, Railway/Resend/Cloudflare changes, real email, iPhone.
- CI run 133 on `42f3647` (code): **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39992757093).
  Unsigned IPA run 50 on `42f3647` **failed before building**: its pre-check required the app's contract (2) to equal
  the hosted API's (1, not deployed). `c4ff4a3` changes only that check to the app's own rule (the API's
  `minimumClientContract`, 1, must not exceed the app's contract); app and API code are identical to `42f3647`.
  CI run 134 on `c4ff4a3`: **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39994700269). Unsigned
  IPA run 51 on `c4ff4a3`, artifact `GoHard-Dev-unsigned-ipa`: **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/39994700234). Against the hosted API as it is now (contract 1)
  this IPA shows no verification step (that server declares none); verification needs the deploy first.
- 23 Oct 2026, owner approved: `main` fast-forwarded to `5ea68e7` and pushed. CI run 136 on `main`: **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40002550143). Railway (devoted-caring) deployed it:
  `/health/ready` Ready with 13 migrations (incl. `AddVerificationGrace`: the legacy 14-day grace starts at this
  deploy), `/capabilities` contract 2 / minimum 2 with `account.email`; an unauthenticated snapshot still 401. No hosted
  account was created (that would send real email to an invented address). **Pending (owner):** the iPhone checklist
  with an address you choose (docs/AUTHENTICATION_EMAIL.md › 8), using IPA run 51; older installs now show Update GoHard.

## 23 Oct 2026 — Saved meals and recipes (`feature/saved-meals-recipes`)

- Base: `main` at `3a36aa7`. Spec: GoHard_Saved_Meals_Recipes_Claude_Prompt.md. Guide: docs/FOOD_DATA.md › Saved meals and
  recipes (model, logging, coverage rule, compatibility, deployment order); hints in docs/COACH.md. Favourites and My
  foods unchanged. Additive migration `AddSavedMeals` (table `SavedMeals`), capability `food.saved-meals`, routes
  `PUT /saved-meals/{id}`, `POST /saved-meals/{id}/delete`, `POST /food-entries/batch`; recipe-portion snapshots
  may be up to 48,000 characters (ordinary ones stay 16,000). Client contract unchanged (2).
- API: `SavedMealTests` (14, real PostgreSQL): owned/revisioned/tombstoned definitions, other accounts get 404, erasure
  cascades, 9 invalid bodies refused, 30-component and size bounds, atomic batch (one invalid or reused ID records
  none; a replay returns the first answer byte for byte; order kept), recipe snapshot bound, template edit/delete leaves
  the logged entry byte-identical, capability declared. `VerificationPolicyTests` cover the new routes automatically
  (403 for a waiting account). Full suite once: 231 of 232; the failure was real (batch entries 100 ns apart collapse
  to the same microsecond in PostgreSQL, so their order was arbitrary), fixed to 1 µs steps, `SavedMealTests` then
  passed three runs in a row.
- App: `flutter analyze` no issues; `check-l10n` 2,591 messages (100 new, en/fr/ar). `saved_meals_test` (13: scaling
  without drift, unit conversion, yield/fractions/prepared weight, partial vs complete vs zero through a portion and a
  day, Save as meal copies, limits; on the real Drift database: save/update/save-as-new/drafts log nothing, atomic
  local write, invalid component writes nothing, rapid taps and a lost answer give one operation and the same bytes,
  offline + restart keep the past day and reconcile without duplicates, unsupported/unknown server receives none of the
  commands, account isolation, template edit/delete leaves history intact, a changed portion uses its own snapshot,
  revision conflict held, our own echoed save is not a conflict). `saved_meals_ui_test` (6: Eat → library → review →
  1½× → Log once despite a double tap, back on Eat, template untouched; Update saved meal / Save as new explicit and
  logging nothing, leaving logs nothing; recipe portion with a French decimal comma, servings → grams through the
  weighed batch, "known" calories; editor validation; Arabic RTL and French at 320 px, 1.6× text, keyboard open, main
  action above it, remove button's spoken name). Affected suites run once together (food, food UI, Eat UI, trends,
  data layer, projection, l10n Eat, coach companion, localization): 169 passed.
- Renders (Flutter widgets, FIXTURE meals): docs/evidence/saved-meals (library light/dark and Recipes tab, meal editor,
  recipe editor, meal review at 1½×, recipe review, 320 px at 2× text, 320 px with the keyboard, Eat's entry) and
  docs/evidence/localization/{fr,ar}/saved-meals. Reviewed by eye; found and fixed: multiplier chip keys depended on
  the language ("1,5"), the missing-values note repeated in both recipe panels. Not fixed: English food names logged
  before stay English in Arabic (stored words never change, as elsewhere).
- Native (Pixel_7 emulator, branch API on 127.0.0.1:5136 with captured mail, disposable database dropped afterwards):
  `journey_meals_test` **passed** on the second run (first run: the journey tapped the catalog row of a food that,
  once logged, is listed under Your foods; fixed in the journey). Made a 2-food meal from common foods (no provider),
  logged it at 1½× once, Update saved meal at 2×, Save as new, a 4-serving recipe and 1.5 servings of it, then with
  Wi-Fi and data really off logged the variation ("sync pending"), back online: the account's own snapshot held 5
  entries (nothing twice), 3 definitions, the updated one at revision 2, the portion "1.5 servings"; account deleted.
  Captures docs/evidence/screenshots/sm-01…08. **Not verified on the device:** a restart while offline (one process:
  the emulator cannot take a phase-2 reinstall); covered by `saved_meals_test` on the real database.
- Not done here: merge, deploy, Railway/Resend/Cloudflare, an iPhone, a fluent review of the new fr/ar strings.
- CI run 139 on `f2c1904` (code): **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40017471403). Unsigned
  IPA run 52 on `f2c1904` (branch `feature/saved-meals-recipes`), artifact `GoHard-Dev-unsigned-ipa`: **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40019230261). Against the hosted API as it is now (no
  `food.saved-meals`) this IPA keeps saved meals and meal logs on the phone and says so; they need the deploy first.
- 23 Oct 2026, owner approved: `main` fast-forwarded from `3a36aa7` to `13dcc7b` and pushed (app/API code identical to
  `f2c1904`, so IPA 52 stands; no new build). CI run 141 on `main`: **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40034345006). Railway (devoted-caring) deployment of `13dcc7b`:
  **success** (22:34 UTC). Hosted: `/health/ready` Ready with 14 migrations (`AddSavedMeals` applied), `/capabilities`
  contract 2 / minimum 2 and declares `food.saved-meals` (and `account.email`); `PUT /saved-meals/{id}` and the snapshot
  answer 401 without a session. **Not run on the hosted API:** the data checks (template saves no entry, meal logged
  once per component, retry without duplicates, template edit/delete leaves history, another account cannot read
  definitions). They need verified accounts, and hosted registration sends a real verification email; by the
  owner's decision no account was created and verification was not weakened. These behaviours are verified locally
  (`SavedMealTests` on PostgreSQL, `saved_meals_test`, `journey_meals_test`) and are left to the owner's iPhone test.

## 25 Oct 2026 — Eating out (`feature/eating-out`, from `main` 2397b0d)

Brief: `GoHard_Eating_Out_Claude_Prompt.md`. Details: docs/EATING_OUT.md; per-item sources and values:
docs/RESTAURANT_SOURCES.md.

- Catalog `2026-10-25.1`: Subway Canada 31 items (Nutrition Data Tables PDF printed "October 2026", read through a
  page-to-PDF fetch, SHA-256 recorded, text extracted with `scripts/pdf-text.mjs`; 11 footlongs derived by the table's
  own doubling rule) and Pizza Pizza Canada 20 items (pizzapizza.ca nutrition pages, "as of November 1st, 2023", some rows
  "Updated March 12, 2026"; read twice with differently worded page-to-text requests, identical numbers). Every row
  passes the build's checks (unique match, Atwater, sat fat ≤ fat, fibre ≤ carbs). **Not imported:** McDonald's Canada
  (HTTP 403 for every automated request to the calculator and product pages) and Tim Hortons Canada (page built in the
  browser; its data service is not a documented public source and reading it was refused by this session's access
  rules). Both are listed honestly empty. Excluded on purpose: Subway drinks/soups/regional items, Pizza Pizza drinks and
  dips (unlabelled columns), medium+ pizzas (no stated slice size), small-pizza saturated fat (lost decimal → unknown).
- API: `dotnet test --filter CoachTests` on disposable PostgreSQL: **28 passed** (23 existing Ask GoHard + 5 new
  Eating out, provider STUBBED in both Anthropic and Groq shapes). Build: 0 warnings.
- App: `flutter analyze` no issues; `node scripts/check-l10n.mjs` OK (2,706 messages; 115 new, fr-CA and ar);
  `eating_out_test` 17 + `eating_out_ui_test` 7 passed (AI client STUBBED); affected suites once together (food search,
  food, food UI, saved meals ×2, Eat UI, coach companion, coach ask, l10n Eat/coach, localization, coach guide, data
  layer): **201 passed**.
- Renders (Flutter widgets, fixture drafts, stubbed answer): docs/evidence/eating-out (chains, suggestions, comparison,
  order; light and dark; 320 px at 2× text; 320 px at 1.6× with the keyboard) and docs/evidence/localization/{fr,ar}/
  eating-out. Reviewed by eye; found and fixed: Send could sit under the keyboard at 320 px (moved into the field), the
  French Undo label overflowed the targets header and Material chips cut labels at large text (wrapping header and
  chips), English official names/portions/build notes scrambled inside Arabic sentences (isolated with `ltr()`), the
  coach bust missing from renders (texture now preloaded in the render test).
- Native (Pixel_7 emulator, branch API on 127.0.0.1:5136 with captured mail and `Coach:GroqBaseUrl` pointed at
  `scripts/coach-stub.mjs` — a STUB, so this proves the app/API path, not live AI; disposable database dropped
  afterwards): `journey_eatout_test` **passed** on the 4th run (run 1: the journey re-logged in on every poll and hit the
  auth rate limit; run 2: the journey expected 3 entries, but the chicken kept in the draft after Save as meal correctly
  made the offline order 2 items — expectation fixed; run 3: INSUFFICIENT_STORAGE on install, emulator rebooted).
  Chose Subway, sent a request, interpreted chips shown, suggestion kept Potato Rings, used it, comparison shown,
  logged once (2 entries), saved another order as a meal and reopened it (no entry), then with Wi-Fi and data really
  off: asking said it couldn't be sent and kept the question, the order was logged on the phone, back online the
  account held 4 restaurant entries with one catalog version and 1 saved meal; account deleted. Captures
  docs/evidence/screenshots/eo-01…10 (the device capture of the suggestion is clipped at the bottom; the card is shown in
  the widget renders). **Not verified on the device:** a restart (one process; covered by `eating_out_test`).
- **Live AI:** no Groq key on this machine; no live request made. Hosted (key configured) after an approved deploy.
- Not done here: merge, deploy, an iPhone, a fluent review of the new fr/ar strings.
- CI run 143 on `1663d25`: **failed**, one API test: the "no injected value reaches the phone" check searched the whole
  body and the random request ID happened to contain "590" (test flaw, not a feature fault). Fixed in `fc7eddc` (distinct
  injected values, only the intent searched). CI run 144 on `fc7eddc` (tested code commit): **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40256329141). Unsigned IPA run 53 on `fc7eddc` (branch
  `feature/eating-out`), artifact `GoHard-Dev-unsigned-ipa`: **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40257479054). Against the hosted API as it is now (no
  `restaurants.*` capabilities) this IPA browses the bundled catalog, builds, suggests and logs; asking in words says it is
  not available until the API is deployed. `main` and Railway unchanged, awaiting the owner's approval.

### 25 Oct 2026 (follow-up) — McDonald's and Tim Hortons added (catalog 2026-10-25.2)

- Owner authorized read-only access to the official McDonald's and Tim Hortons Canada sites, their linked nutrition
  documents and the public services those pages use. From this session McDonald's still answered every plain request
  with its edge's "Access Denied" (HTTP 403): `/ca/en-ca/about-our-food/nutrition-calculator.html` (ref
  `#18.b059c817.1792983967.63bfb82`), `/dnaapp/itemList?country=CA&language=en&showLiveData=true` (ref `…63bfc44`),
  `/ca/en-ca/product/big-mac.html` (ref `…63bfd9c`); no browser tool exists in this session, and nothing tried to get
  around the edge. A second local session (babti-7b) working on the same branch captured the calculator's data
  service in Chrome (135 items, displayed values) and the official Tim Hortons PDF ("as of July 2026", SHA-256
  recorded), then stopped and handed the catalog over. Its Tim Hortons spec entry was overwritten by this session by
  mistake (concurrent edit) and rebuilt here from its committed PDF rows.
- Tim Hortons source: the PDF (dated official document). The public content service (`prod_th_ca`) was read once as a
  cross-check: identical values wherever both list an item. 33 Tim Hortons items, 27 McDonald's items (Mini fries added
  as its own stated record); all pass the build's checks; two PDF defects left out (Snow Ball Timbit, Bacon & Cheese
  Omelette Bites). McDonald's values were not re-read by this session (blocked); they passed every build check.
- Tests (affected only): `eating_out_test` 18, `eating_out_ui_test` 7, `food_search_test` passed (43 together);
  `CoachTests` incl. Eating out 28 passed; `flutter analyze` clean; catalog `--check` up to date.
- Live AI: not run. No environment here holds a Groq key AND the Eating out endpoint (hosted has the key but not the
  endpoint until deployed; no hosted accounts by the owner's rule). Pending for the approved deployment.
- CI run 146 on `a100461` (tested code + catalog 2026-10-25.2): **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40263214913). Unsigned IPA run 54 on `a100461`, artifact
  `GoHard-Dev-unsigned-ipa`: **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40318077683).
  `main` and Railway unchanged.
- 26 Oct 2026, owner approved: size guard added (`8458563`: a size the request names is never replaced; API test
  `A_size_that_is_not_listed_is_never_replaced_by_another_size`; coach + Eating out API tests 29 passed; branch CI 148
  passed). `main` fast-forwarded 2397b0d → 8458563 and pushed; CI 149 on `main` passed; Railway devoted-caring deployed
  8458563 (success 12:19 UTC); hosted Ready with 14 migrations, declares `restaurants.catalog`, `restaurants.interpret`,
  `coach.ask`; new routes 401 without a session. IPA 54 reused (app unchanged). **Pending:** live AI and hosted data
  checks on the owner's iPhone (no hosted accounts by the owner's rule).

## 27 Oct 2026 — Eating out discovery (`feature/eating-out-discovery`, from `main` 71a80e9)

- UI only (docs/EATING_OUT.md › Finding it, docs/COACH.md › Eating out): the small Eating out button in the nutrition
  summary is replaced by a full-width panel (`PanelLink` with a new optional detail line and action) between the
  summary and History & trends, naming the catalog's chains; the coach introduces it once (`eat.out`, last in the Eat
  hint chain, with **Find an order**). The hint chooser now also waits for the keyboard to be down. No API, catalog,
  capability, AI, auth, logging or sync change. New strings in en/fr/ar (`eatOutPanelBody`, `eatOutPanelAction`,
  `eatHintEatingOut`, `eatHintEatingOutAction`); `eatOutEntrySaid` removed.
- Tests (affected only): `flutter analyze` clean; `check-l10n` OK (2709 messages); `eating_out_ui_test` +2 (panel
  placement, removed summary entry, chain line, one screen-reader node, opens for the picked day; introduction only on
  Eat in view, not with the keyboard up, once, Find an order opens it for the day; hints off / coach off: none, panel
  stays; no AI request, nothing logged); `water_ui_test` and `nutrition_trends_ui_test` adjusted (the taller page puts
  the header coach / History below the fold); with `eat_ui`, `move_ui`, `saved_meals_ui`, `coach_companion`,
  `coach_avatar`, `l10n_eat`, `localization`, `food_ui`, `render`: 148 passed.
- Renders: `render_test` states now read the bundled catalog from its file (it did not load reliably in the harness).
  `state-full-eat-*` and `state-large-text-eat-goals-320` regenerated in en/fr/ar; before/after set in
  `docs/evidence/eating-out-discovery/`. **Pre-existing, not changed here:** the French 320 px / 2× Eat render fails on
  `main` too — the meal group's "+ Ajouter un aliment" / "Enregistrer comme repas" row overflows (eat_screen.dart
  meal-group footer Row).
- Native: `journey_eatout_entry_test` (new, one process, not default) on Pixel_7 against the branch API on
  127.0.0.1:5136 with a disposable DB (dropped afterwards): **passed** on the second run (the first failed only on its
  own last check — a header key out of the lazy list — after the real checks had passed). Captures
  `docs/evidence/screenshots/eod-*`.
- Tested app commit `ab8bee0`. CI run 152: attempt 1 failed only on `coach_companion_test` "no replay" (Today's
  idle-blink timing, the known CI flake; 759 passed), attempt 2 **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40540012687). Unsigned IPA run 55 on `ab8bee0`, artifact
  `GoHard-Dev-unsigned-ipa`: **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40540109863).
  Not merged; `main`, Railway, secrets and restaurant data unchanged.

### 27 Oct 2026 (follow-up) — meal footer stacking and the Eat hint sequence

- Meal footer (`_MealFooter` in eat_screen.dart): Add food and Save as meal stay side by side when both labels fit
  (measured with the real styles and text scale); otherwise Save as meal goes under Add food. Fixes the French 320 px /
  2× overflow that was also on `main`. The Eating out panel is unchanged.
- Hint sequence: for an account with nothing logged or saved, the hint chooser never left its first step, so no later
  introduction (Eating out included) could ever be chosen. Now the first such visit keeps "Log a meal…" and is
  remembered per account (`eat.first`); the next visit to Eat (another tab shown in between, or a later launch)
  introduces Eating out once, under the same rules (in view, route current, keyboard down, Coaching hints).
- Tests (affected only): `eat_ui_test` +1 (footer side by side in English; stacked, full-width Add food, 48 px targets,
  on screen, no overflow in French and Arabic at 320 px / 2×); `eating_out_ui_test` +1 (first visit stays about logging
  and does not switch mid-visit; keyboard up: not chosen; next visit: introduced, Find an order opens it for the day, no
  AI request, nothing logged; after a restart: not again; hints off: never, panel stays); `water_ui_test` marks
  `eat.out` seen (it visits Eat repeatedly and checks the usual words). `flutter analyze` clean, `check-l10n` OK; with
  `move_ui`, `saved_meals_ui`, `nutrition_trends_ui`, `coach_companion`, `coach_avatar`, `l10n_eat`, `localization`,
  `food_ui`, `render`, `today_ui` all passing (`coach_companion` "no replay" failed once under parallel load and passed
  alone — the known timing flake).
- Renders: new state `large-text-eat-meals-320` (en/fr/ar) shows the stacked footers; Eat states regenerated; the
  French `large-text-eat-goals-320` render now passes.
- Tested app commit `1b7b3bc`: CI run 154 **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40549038131);
  unsigned IPA run 56, artifact `GoHard-Dev-unsigned-ipa`, **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40549060769). No emulator run for this follow-up (not
  asked). Not merged; `main` and deployment untouched.
- 27 Oct 2026, owner approved: `main` fast-forwarded 71a80e9 → df6062c and pushed; CI 156 on `main` passed; Railway
  devoted-caring deployed (success 22:07 UTC; diplomatic-intuition failed, unused); hosted Ready, 14 migrations (no API
  change). IPA 56 reused (app code identical to `1b7b3bc`).

## 28 Oct 2026 — Help with today and food (`feature/daily-nutrition-coach`, from `main` 65fa9b8)

Brief: `GoHard_Daily_Nutrition_Coach_Claude_Prompt.md`. Design and contract: docs/COACH.md › Help with today;
docs/FOOD_DATA.md › Suggested portions.

- What works: Today's guide (portrait and Ask me) and Eat's Ask me (bubble and journal help) open a conversation about
  that day. Built-in requests (Help me with today, What have I recorded today?, Help me reach my protein goal, What could
  I have from my saved meals?, Make that a smaller portion) are answered on the phone with no AI. Typed words go to
  `POST /coach/daily`, whose model only returns a checked intent naming this account's own saved meals, recipes and saved
  foods by short reference; every number is worked out on the phone with MealMath / FoodScaling / NutrientCoverage. Cards
  open the existing review (`MealReviewScreen` at the suggested multiplier/amount, or the food's amount form) and only
  its own Log records, through the existing paths. Stale replies are detected (`dayRevision`) and recalculated without AI.
  Shared allowance with Ask GoHard and Eating out; capability `coach.daily`; no migration; client contract stays 2.
- Changed on purpose: Today's guide now opens Help with today instead of Ask GoHard (Ask GoHard stays on Train; a training
  question offers Ask about training). Eat's coach now has Ask me. `coach_companion_test` updated accordingly.
- Not included (brief's later ideas): plan adaptation, new trend analysis, durable preference memory, photos, voice,
  notifications, autonomous logging. Water and steps are not part of the briefing (the brief allowed them; left out to
  keep it small).
- Tests: API `CoachTests` 33 passed (4 new `DailyCoachTests`, **stubbed provider**, Anthropic and Groq shapes). App
  `day_coach_test` 20, `day_coach_ui_test` 10 (**scripted client**, real local DB for the conversation),
  `coach_companion_test` updated; full app suite 792 passed on the feature commit; `flutter analyze` clean; `check-l10n`
  OK (en/fr/ar).
- Native `journey_daily_test` (new, one process, not default) on Pixel_7 against the branch API on 127.0.0.1:5136, a
  disposable DB (`gohard_daily_journey`, dropped afterwards), captured mail, and the provider pointed at
  `scripts/coach-stub.mjs` — a **stub with a fixed rule, not a model**: **passed** (2:55). Covered: briefing and goal
  question with no AI request; Edit goals opening Eat's goal sheet; a saved meal made; a typed request naming it; a typed
  "smaller" (0.75×); Review → back (account: no entries); Review → Log meal (account: 2 entries at exactly 0.75× of each
  saved amount; saved meal still revision 1); a typed request the provider fails (HTTP 500) → honest problem with Retry,
  then a built-in request still answering ("Foods in the journal: 2"); nothing logged twice; account deleted. Captures
  `docs/evidence/screenshots/dc-01…08`. The captures showed two defects, fixed in the follow-up commit: an empty answer
  bubble for a card-only reply, and the failure text reusing Ask GoHard's words (now its own `dcProblem*`).
- Restart with an unsaved draft: not covered natively (a one-process journey; phase-2 reinstalls fail on Pixel_7 for
  storage). Covered at database level: `day_coach_ui_test` "the conversation survives closing the screen" (real local DB),
  and the existing review/draft persistence tests (`saved_meals_test`).
- Live AI: no Groq key on this machine; **no live request was made**. Pending owner approval to deploy, then iPhone.
- CI run 158 on `457541e` **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40600762565).
- Follow-up (from the journey and render captures): no empty answer bubble for a card-only reply; failure states use this
  feature's own words (`dcProblem*`: limit / busy / couldn't be sent / interrupted / unavailable — never "offline");
  suggested requests are outlined rounded buttons whose words wrap (Material chips clipped them in French at 320 px /
  1.6×). Renders (`day_coach_ui_test` › renders, `GOHARD_RENDER`, settled guide): `docs/evidence/daily-coach/` and
  `docs/evidence/localization/{fr,ar}/daily-coach/` — empty and goal + smaller portion in light and dark, large text at
  320 px, typed request with the unavailable fallback. Affected suites after the follow-up: 132 passed; analyze clean.
  The native journey ran on `457541e` (before these presentation-only changes; its keys and flow are unchanged).
- Tested app commit `dea4e00`: CI run 159 **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40609988642);
  unsigned IPA run 57, artifact `GoHard-Dev-unsigned-ipa`, **passed**
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40611505805). Not merged; `main`, Railway, Cloudflare,
  secrets, signing and the deferred video branches untouched. Live AI not verified (no key here; needs the deploy).
- 29 Oct 2026, owner approved merge and deploy: `main` fast-forwarded 65fa9b8 → b0c0da6 (no newer work on `main` to
  preserve) and pushed. CI run 161 on `main` **passed** (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40921678030).
  Railway devoted-caring deployed (success 17:29:56 UTC; diplomatic-intuition failed, unused). Hosted
  `/health/ready` 200 "Ready — 14 migration(s) applied" (no migration in this release); `/capabilities` contract 2 /
  minimum 2 and declares `coach.daily` beside `coach.ask` and `restaurants.interpret`, so the existing Groq settings are
  in use — no secret or variable was changed. Unauthenticated `POST /api/v1/coach/daily` → 401. No hosted account was
  created and no email sent. IPA 57 reused (app code identical to `dea4e00`). **Live AI and hosted logging: unverified**,
  pending the owner's iPhone check.

## 29 Oct 2026 — Meal habits, saved-meal amounts and Reminders (`feature/meal-habits-reminders`, from `main` 12d7ce5)

Design and rules: docs/MEAL_HABITS_REMINDERS.md. Code a19aef7.

- What existed: saved-meal review with per-food edits, add/remove, multipliers, recipe servings/weighed grams, Update
  saved meal (confirmed), Save as new; typed coach requests resolving to the review; workout reminders with one
  replace-everything scheduler.
- Added: local meal-habit detection (28-day window, 3 distinct days, last within 14, stable identities, latest amounts)
  with Eat's Review usual meal / Choose something else / Not today, opt-in (Me › Meal suggestions or the coach's one-time
  offer); review actions renamed Log this time / Update saved meal / Save as a variation with an explanatory note;
  `portion.ingredient` on `POST /coach/daily` (additive, no capability/migration) resolved on the phone; Me › Reminders
  (workout switch moved there) with local, per-account meal/medication/supplement reminders, 7-day horizon within 60
  notifications, meal suppression once logged, Taken/Snooze/Skip per occurrence, private lock-screen wording, suggested
  meal time only from same-day logging times; Eat link to Reminders.
- Tests: app `meal_habits_reminders_test` 16, `meal_habits_reminders_ui_test` 3 (ar/fr, 320 px, 1.6× text), updated Me /
  language / saved-meal tests; full app suite **812 passed**; `flutter analyze` clean; `check-l10n` OK (2,893 messages).
  API `DailyCoachTests` 7 passed locally (**stubbed provider**). CI 40933069001 passed on attempt 2: attempt 1 failed only
  `AccountEmailTests.Provider_trouble…`, whose "no 8-digit code in logs" regex matched digits inside a random GUID
  (unrelated, pre-existing flake). Unsigned IPA run 58 (a19aef7) passed.
- Native `journey_habits_test` (new, one process, not default): **not run**. Branch API on 127.0.0.1:5136 with a
  disposable DB (`gohard_habits_journey`, dropped) was up; the Pixel_7 install failed twice with
  INSUFFICIENT_STORAGE (~560 MB free after reboot and cache trim). Stopped there as instructed.
- **Unverified:** real iOS/Android notification delivery, lock-screen discretion, notification buttons, background meal
  suppression, real Groq interpretation of ingredient requests, VoiceOver. Not merged, not deployed.

## 30 Oct 2026 — Eat companion and meaningful reminders (`feature/eat-companion`, from unmerged `feature/meal-habits-reminders` d613430)

Design: docs/EAT_COMPANION.md. **Depends on `feature/meal-habits-reminders`** (not merged): this branch contains it.

- Reminder wording: the generic "GoHard reminder — Open GoHard to see it" was the hidden-details text, on by default
  for supplements too. Now every notification states its purpose ("Time to log breakfast.", the supplement's name,
  "Time for your medication." / "Time for your supplement." when hidden); hidden details never show name, dose or
  instructions; default hidden for medication only.
- Eat's bubble: a deterministic briefing from the day's records, goals, time and meal reminders replaces the fixed
  sentence; earlier days are told looking back; one action (What could I eat?), Set goals without goals, Ask me kept;
  the same words in a compact panel without the coach. In-app heads-ups (over, near before 17:00 within
  max(150 kcal, 10 %), protein reached), once per day per account, switchable in Me › Meal suggestions; none as
  notifications. Fixed during testing: a heads-up already said could be picked again before the account's choices had
  loaded.
- What could I eat?: built-in (usual meal, saved items, Eating out, Choose something else, Saved meals) with no AI;
  new ideas via `POST /coach/daily` kind `ideas` (capability `coach.ideas`, request `features`), words only, matched
  on the phone to bundled everyday foods, the person's foods, foods seen on the phone, then at most 3 account food
  searches; values only from records; unmatched foods shown without totals with Find food; review through the existing
  review and atomic meal log.
- Tests: app `eat_companion_test` 9, `eat_companion_ui_test` 7, `day_coach_ui_test` +4 (15 total), updated
  `coach_companion_test`, `eating_out_ui_test`, `move_ui_test`, `water_ui_test`, `meal_habits_reminders_test`; full app
  suite once: 828 passed, 4 failed on the old Eat wording, those files fixed and rerun (35 passed); `flutter analyze`
  clean; `check-l10n` OK (2,936 messages). API `DailyCoachTests` 8 passed (**stubbed provider**).
- Native `journey_eat_companion_test` (new, one process, not default) on Pixel_7 against the branch API on 127.0.0.1:5136
  (disposable DB `gohard_ec_journey`, dropped) with the provider pointed at `scripts/coach-stub.mjs` (**a stub, not a
  model**). Run 1 found a real bug: on a fresh start the bundled food catalog had not been read yet when ideas were
  matched, so nothing matched (fixed: the catalog and seen foods are loaded on demand). Run 2: briefing, What could I
  eat?, the stub's ideas (one matched to bundled foods, one "needs a food match"), review with an amount changed and
  left (account: nothing), Log once (account: 2 entries at the original amounts) all **passed**; it stopped on the
  journey's own back step (the conversation has a close button). Run 3: INSTALL_FAILED_INSUFFICIENT_STORAGE. Run 4
  (after a reboot): the same steps passed again; only the last check (the briefing after logging) timed out because
  Eat's header had scrolled out of its lazy list (journey fixed to scroll back, not rerun). Stopped there.
- **Unverified:** real Groq ideas, real USDA matches for ideas, iPhone notification wording on the lock screen,
  VoiceOver. Hosted ideas need this API deployed. Not merged, not deployed.
- Final code ae3abd2: CI 41076832635 passed (99ee83d before the device fix: CI 41074210093 passed); unsigned IPA run 59 (ae3abd2) passed.

### 30 Oct 2026 (follow-up, before merge) — confirmation instead of silent matching

- Preparation: a proposed preparation now filters records and the name decides among them; when no record states it,
  the same name is only offered as a choice (the old fallback to the name without its preparation is gone). Equally good
  records are a choice of up to 3 (the old "first of a tie"). Found while testing: "raw egg" tied with raw egg whites.
- Amounts: a unit the record lacks, or several sizes of the same thing (slices), now asks **Choose amount** (the usual
  amount form); the automatic standard-portion substitution is removed. Totals and Review only once all is confirmed.
- Focused tests only: `eat_companion_test` 11, `day_coach_ui_test` 15 (idea → choose amount → review → back logs
  nothing → Log once). `flutter analyze` clean, `check-l10n` OK.
- Code b52a8ed: CI 41083395123 passed on attempt 2 (attempt 1: the known AccountEmailTests 8-digit-in-GUID flake; no API change in this commit); unsigned IPA run 60 (b52a8ed) passed.
- Emulator journey (one attempt, after a reboot, coach stub): briefing, What could I eat?, a matched idea asking for the toast amount, Choose amount, review with a changed amount and back (nothing logged), Log once (2 entries) passed. The final check, the briefing after logging, timed out again: back on Eat the coach bubble was not in the widget tree at all (neither its words nor its button). Not established whether that is the device-journey animation quirk or a real display issue: **unverified**, on the iPhone checklist.

### 30 Oct 2026 (follow-up 2) — preparation amounts; the coach after returning to Eat

- A record chosen with another preparation than the idea proposed (dry oats for cooked oats) no longer keeps the
  proposed amount: the card explains the difference and asks for a fresh amount; no totals before it.
- "The coach disappears after logging an idea": investigated. Not a visibility, scroll or navigation fault: the coach was
  there, but after logging, Eat's one-time "save it as a meal" introduction took the bubble instead of the briefing. That
  introduction is rich text with no buttons, and the journey's screen dump skipped rich text (and stopped at 34
  items), so the bubble looked absent. Widget probes: returning from a pushed screen, and scrolling the header out of
  the lazy list and back, both keep the coach. Fixed: when the day's food changed while Eat was not on screen, the visit
  back shows the updated briefing and introductions wait for a later tab visit (coach off: the panel). Journey dump now
  includes rich text.
- Focused tests: `eat_companion_test` 11, `eat_companion_ui_test` 9 (+2: back from logging, scrolled to the top, coach
  on and off), `day_coach_ui_test` 15, `move_ui_test` / `eating_out_ui_test` / `coach_companion_test` 46 (introduction
  order). `flutter analyze` clean, `check-l10n` OK.
- Code 31b0e2a: CI 41095951147 passed (first attempt); unsigned IPA run 61 (31b0e2a) passed.
- Native `journey_eat_companion_test` (one attempt after a fresh boot, branch API on 127.0.0.1:5136, disposable DB dropped, coach stub — **not a model**): **passed, every step**, including the last: back on Eat after logging the idea, the coach says "Lunch is logged. Want ideas for your next meal?" with What could I eat?, Ask me and Set goals. Captures `docs/evidence/screenshots/ec-01…05`.

### 30 Oct 2026 (fix) — Eat blank grey on iPhone for accounts with reminders

- Cause (reproduced, not assumed): `_EatScreenState._briefing` (added in 99ee83d, so IPA 59, 60 and 61) iterated
  `ref.watch(remindersProvider).value ?? const []`. In a for-in, the untyped `const []` made each element `dynamic`, and
  `Reminder` is an extension type, so `r.enabled` was a dynamic call on the raw map: NoSuchMethodError
  ("Class '_Map<String, dynamic>' has no instance getter 'enabled'") thrown while building EatScreen, which a release
  build shows as a grey box filling the tab. Only accounts with at least one reminder of their own (enabled or paused),
  which is why fresh test accounts never showed it. No stored data was involved or changed.
- Fix (9cf808b): the list is typed (`const <Reminder>[]`, also in the reminder-offer check). Defence: the coach's optional
  message (briefing, suggestions, introductions, the coach-off panel) is worked out in one guarded step; a failure is
  reported through FlutterError.reportError (still visible in logs and tests) and a notice with Retry takes the coach's
  place, while the day's summary, Log food and the meals render as usual.
- Evidence: `test/eat_existing_account_test.dart` (existing-account data with reminders, 12 combinations of goals, coach
  on or off and stored preferences, plus 2 isolation tests) fails with the old line put back and passes with the fix.
  Affected Eat tests (7 files, 76) pass; `flutter analyze` clean; `check-l10n` OK. The `avoid_dynamic_calls` lint would have
  caught it; enabling it repo-wide needs about 50 test/journey JSON accesses typed first (not done here).

### 30 Oct 2026 — merged and deployed (owner approved)

- Owner confirmed on iPhone: IPA 62 fixes Eat (the grey page). Approved merging `feature/eat-companion` with its
  `feature/meal-habits-reminders` dependency. `main` fast-forwarded 12d7ce5 → 57ea806; CI 41125465960 passed on `main`;
  Railway devoted-caring success; hosted health 200, contract 2, declares `coach.daily` and `coach.ideas`; unauthenticated
  `POST /coach/daily` → 401. IPA 62 reused. Release notes: docs/RELEASE_AND_ROLLBACK.md.
- Still unverified: live Groq (ingredient changes, ideas), hosted food matching, phone notifications, VoiceOver.

## 30 Oct 2026 — Shared nutrition assessment, goal colours, weekly report (`feature/nutrition-assessment-report`, from `main` 19e2cf2)

Design: docs/EAT_COMPANION.md › Shared assessment, goal colours and the weekly report.

- One pure assessment (`nutrition_assessment.dart`) now feeds Eat's briefing, What could I eat? and its ranking, the
  Today/Eat goal bars, Eat's left/over lines, the coach's goal lines and the weekly report. Display-resolution policy:
  compare at whole kcal / tenths of a gram, 80 % on the exact value, percent rounded down below the goal and up above it.
- Bars: calories green (<80 %) / yellow (80 %–target) / green (reached) / red (above); protein yellow / yellow / green,
  never red. Words beside the amount (Today keeps its height), read out with amount, goal and percentage; "Known intake"
  when values are missing; neutral without a goal. New theme tokens `goal*` / `goal*Text`, contrast checked in all themes.
- What could I eat? assesses first: no goals, remaining, calories reached with protein left (asks before any option),
  protein reached, every goal reached (asks first; continuing always works and says the calories add), incomplete
  values. Ranking follows the goals that still apply; "nothing fits" is said, never relaxed.
- Briefing: "reached" state with no food pushed; the usual-meal suggestion is not put forward once every goal is reached;
  **earlier days are now compared only with a goal recorded for that day** (before: today's goal).
- Goal history: the account keeps only current goals. New local, additive `nutrition_goal_day` records the goals in
  effect each day the app is open (`changed` when one goal replaced another that day). History starts on this phone
  now; nothing is backfilled. No API change, no migration, no capability.
- Weekly report (History & trends top bar): Monday–Sunday, "Week so far", no future weeks, averages with denominators
  (known-value and complete-day), unlogged/partial/unknown/zero days, goal comparison only on recorded days, ≤3
  observations, ≤2 next steps, day rows opening the journal. Local only, no AI.
- Found and fixed by tests: the History app-bar label overflowed in French/Arabic at 320 px with 2× text (icon with
  tooltip there now); the near heads-up could contradict a green bar for small goals; "0 kcal left" at display resolution.
- Tests: `nutrition_assessment_test` (21), `nutrition_report_ui_test` (7), `theme_test` (goal tokens); updated
  `eat_companion_test`, `nutrition_trends_ui_test`. Full app suite once: **878 passed**; `flutter analyze` clean;
  `check-l10n` OK (3,004 messages). No API tests run (no server change).
- Code 71f0b48: CI 41162680886 passed; unsigned IPA run 63 (71f0b48) passed (artifact GoHard-Dev-unsigned-ipa).
- Native `journey_nutrition_report_test` (new, one process, not default; branch API on 127.0.0.1:5136, disposable DB
  `gohard_nr_journey` dropped, coach stub — not a model): **not run** — two attempts (cold boot, then reboot + trim-caches,
  491 MB free) both failed to install with INSTALL_FAILED_INSUFFICIENT_STORAGE. Stopped there.
- **Unverified:** emulator and iPhone behaviour, VoiceOver/TalkBack reading of the bars, real Groq ideas ranking.
  Not merged, not deployed (nothing to deploy server-side).

### 31 Oct 2026 — merged (owner approved)

- Owner confirmed IPA 63 on iPhone and approved. `main` fast-forwarded 19e2cf2 → 05a998d; CI 41166239621 passed on `main`; Railway devoted-caring redeployed (success, 14 migrations, no API change). IPA 63 reused. Release notes: docs/RELEASE_AND_ROLLBACK.md.
- Still unverified: real Groq idea ranking, VoiceOver/TalkBack on the bars, the emulator journey.

## 31 Oct 2026 — GoHard Free and GoHard Plus preview (`feature/plus-preview`, from `main` 7398a39)

Design and exact matrix: docs/PLUS_PREVIEW.md. A preview only: no StoreKit, payment SDK, checkout, Apple product or
price; no Subscribe / trial / Restore action. Unmerged work and the deferred video work were not touched.

- API (0c15f63 + c5d6f01): `EntitlementService` (sources: owner preview override → Plus, else Free), `AiAllowance`,
  `GET /entitlement`, owner-only `PUT /preview/entitlement` and `POST /preview/allowance/reset` (404 for anyone else),
  creation limits in `plan.draft` / `plan.create` / `plan.continue` (`PLAN_LIMIT`) and new saved meals (`MEAL_LIMIT`),
  one monthly allowance checked and recorded in `CoachService.GuardedAsync` (`429 COACH_LIMIT reason=monthly`),
  migration `AddEntitlements` (additive: `PreviewOverrides`, `AiUsage`), capability `account.entitlement`.
- App (c5d6f01): `features/plus/` (model, controller, cache 72 h from receipt per account, Plus page, limit and feature
  sheets, allowance line), Me › GoHard Plus, gates in the plan builder, Continue this plan, saved-meal save, See all /
  All range, next-target suggestions; allowance message in Ask GoHard, Help with today, Eating out. +47 strings en/fr/ar.
- Tests run: API `PlusPreviewTests` (7) + 4 allowance tests: passed; full API suite once: 251/254 — 2 existing
  `Bad_proposals…` cases exceeded the new Free month (test given a higher allowance, then passed) and the known
  `AccountEmailTests.Provider_trouble…` flake (passed on rerun). App: `plus_test` (14) passed; full app suite once:
  891 passed, 1 failed (`theme_test` serif check: Me grew one row, the lazily built title left the surface; test
  surface raised, file rerun 35/35); `progression_ui_test`, `me_ui_test` adjusted (Plus override; taller surface).
  `flutter analyze` clean, `check-l10n` OK (3,051 messages).
- CI 41181024131 (c5d6f01) passed. Unsigned IPA run 64 (41181963066, c5d6f01) passed (artifact GoHard-Dev-unsigned-ipa).
- **Not run:** the emulator flow (Free → limit → owner Plus → Free), so no device evidence. Not verified on iPhone,
  VoiceOver, hosted. Hosted needs the deploy (migration) and `GOHARD_Plus__PreviewOwnerUserId` set by the owner.
  Not merged, not deployed.
