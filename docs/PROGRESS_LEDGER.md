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
