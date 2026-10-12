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
