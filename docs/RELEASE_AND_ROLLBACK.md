# Setup, upgrade, compatibility and rollback

Internal QA preparation only. Nothing here deploys, publishes to a store, or touches the original GoHard databases.

## Server schema

| Migration | Contents |
|---|---|
| `20261011011030_Initial` | users, refresh tokens, operations, training contexts, plans, occasions, workouts, exercises, sets, food entries, exercise catalog |
| `20261011011041_AddActivitiesAndProposals` | runs, body metrics, proposals (additive only) |
| `20261020200446_AddExerciseIncrements` | new table `ExerciseIncrements` (owner + exercise key, nullable `IncrementKg` numeric(9,5), revision), cascade-deleted with the account; additive only (docs/PROGRESSION.md) |
| `20261012172306_AddFoodDiscoveryAndGoals` | `Users.CalorieGoal`, `Users.ProteinGoalG` (nullable), `FoodEntries.SourceJson` (nullable jsonb), new table `SavedFoods` (additive only; no existing row is rewritten) |

- Apply: `dotnet run --project api\src\GoHard.Api -- migrate` (what `scripts\setup.ps1` does). It prints the readiness
  result and exits non-zero if the schema is not ready.
- Check without changing anything: `… -- readiness`.
- Seed reference data: `… -- seed-catalog` (idempotent upsert of the exercise catalog; never accounts or records).
- New migration: `dotnet ef migrations add <Name> -p api\src\GoHard.Api -o Persistence\Migrations` (run from `api\`).
  Keep migrations additive; add a test beside `Upgrade_from_initial_schema_preserves_existing_records_and_operations`.
- The API never migrates at startup. A pending, unknown or drifted schema makes it answer 503 until the explicit step
  is run. An `UnknownHistory` result (history contains migrations this build does not know) means a newer schema is
  deployed than the binary: deploy the matching build; do not edit history.

Verified: fresh database → all three migrations → Ready; second migration only → a user and a food entry written
as that schema stored them → upgrade → both intact, no goal and no source invented; Initial only → data → upgrade → data, unknown nutrients, entered
zeros and operation records intact; unknown history and missing tables reported without repair.

## Local (phone) schema

Drift `schemaVersion` 2. v1 → v2 adds `records.alternative_body` and `commands.ack`. Verified by building a v1 file
with raw SQLite, including a pending command, and opening it with the current app code: the command's operation ID
and outbound bytes, the record and its unknown nutrient are unchanged. Future changes must stay additive and extend
that test; never drop or rewrite `commands.payload` / `commands.outbound`.

## Compatibility

- Contract version 1 is the only version. `GET /api/v1/capabilities` (public) returns `contractVersion`,
  `minimumClientContract` and the capability list the server really supports (`food.search` only with a USDA key).
- **Enforced on the client.** On start and resume the app reads capabilities with a 6-second limit. A server minimum
  above the app's contract blocks the app over whatever was open, stops sync and keeps the outbox; the block is
  remembered across restarts and lifts when a check passes. No answer changes nothing. The server does not itself
  reject older clients yet.
- `minimumClientContract` is the setting `Compatibility:MinimumClientContract` (default 1). Raise it only for a change
  an older app cannot live with; added optional fields are not one.
- **Additive fields and older apps.** Goal fields left out of `PUT /me` are kept and only an explicit `null` clears
  them. `source` and `provenance` on food commands are optional. A field that is left out is also left out of the
  command's semantic hash, so a retry of a command sent before this release still matches its recorded answer.
  An app from before this release that edits a food logged from a provider turns its values into the user's own
  (`entered`) and drops the stored source, which is what such an edit is.
- **Newer app, older server.** The app hides Nutrition goals when the server does not declare
  `profile.nutrition-goals`, treats a missing `savedFoods` list as empty, and shows search or barcode as not set up.
- **Next targets** (docs/PROGRESSION.md) use the existing `targetLoadKg` and `plan.revise`: nothing new on the server.
  **Weight increments** need `AddExerciseIncrements` and the capability `exercises.load-increment`; against a server
  without it the phone keeps the command pending (never sent), and older apps never send one, so they cannot erase it.
- Operation records are kept indefinitely, so any retry of an old command is still answered with its original
  acknowledgement. Do not prune them without defining the supported offline-retry window first.

## Rollback

| Situation | Action |
|---|---|
| Bad API build, schema unchanged | redeploy the previous build; pending phone commands retry safely under their operation IDs |
| Bad API build after an additive migration | the previous build reports `UnknownHistory` and refuses to serve (by design). Either roll forward with a fix, or restore the database from the pre-migration backup. Do not hand-edit `__EFMigrationsHistory` |
| Bad app build | install the previous build over it. The local database is kept; a build older than the local schema must not be installed over a newer one (Drift cannot downgrade) — uninstalling instead would lose unsynced work, so sync first |
| Appearance or wording problem | cosmetic only; rolling it back does not affect stored commands or records |

Before any real migration: back up the database, record `… -- readiness` output, apply on a copy first.

## Build artifacts (internal QA)

- API: `scripts\test.ps1` publishes a Release build to `publish\api` (git-ignored).
- Android debug: `app\build\app\outputs\flutter-apk\app-debug.apk` (ID `com.gohard.rebuild.debug`, cleartext HTTP to
  the local API allowed).
- Android release: `flutter build apk --release --dart-define=GOHARD_API_BASE=<https origin>`. It is signed with the
  **debug key** (Flutter's template default) and so is for internal testing only; release builds do not allow
  cleartext HTTP, so they need an HTTPS API. A real signing key and store listing are separate work.
- iOS: built unsigned by `.github/workflows/ios-unsigned-ipa.yml` on macOS. The barcode scanner adds the
  `NSCameraUsageDescription` text in `ios/Runner/Info.plist`; Android adds the `CAMERA` permission, with the camera
  marked not required so a phone without one can still install.

## API verification and its throwaway accounts

`powershell -ExecutionPolicy Bypass -File .\scripts\verify-api.ps1 -BaseUrl <api> [-Coach]` checks a local or
hosted API end to end with an account it creates (`verify-<16 hex>@example.test`, display name `API Verify`) and
deletes. Feature checks and cleanup are reported separately; the last line before the verdict is always `Cleanup: …`.

- **Record.** Before registering, the email is printed and appended to `scripts\.verify-accounts.log` (git-ignored,
  this PC only); the account id is added when registration answers, the cleanup outcome at the end. One line per
  event: UTC time, base URL, email, id, outcome. No password, token or key is printed or written anywhere.
- **Cleanup always runs** (a `finally` block): after success, after a failing check, after an exception, and after
  Ctrl+C (PowerShell 5.1 runs `finally` on Ctrl+C). It deletes through `DELETE /api/v1/account` with the password,
  then requires `/me` and sign-in to answer 401. If the token is missing (registration answer lost) or expired, it
  signs in again with the stored credentials first. If registration never created an account, it reports "nothing to
  clean". It cannot run if the process is killed (Task Manager, closed window, power loss, a second Ctrl+C during
  cleanup): the log then names the account.
- **Exit code:** 0 all passed; 1 a check failed but the account was deleted; 2 cleanup failed and the account was left.
  On 2 the script prints the exact delete command.
- **Delete helper:** `.\scripts\delete-verify-account.ps1 -BaseUrl <api> -Email verify-…@example.test` signs in with
  the fixed verification password and deletes exactly that account (exact email only; patterns, wildcards and
  non-`verify-<hex>@example.test` addresses are refused), then checks `/me` and sign-in answer 401. The fixed password
  is acceptable only because each email carries 64 random bits and the account lives for one run.
- **Debug:** `-FailAfter <start of a check name>` throws right after that check to prove cleanup still runs.
- **Ask GoHard:** where `coach.ask` is declared, one contextual question with a small Upper/Lower draft (live model
  call, marked `[LIVE]`); `-Coach` runs five (follow-up with history, exercise explanation, a proposal-inviting
  question where "no proposal" is only INFO, and a workout that is not in the draft). Every answer must be `kind=ai`,
  non-empty, ≤ 1200 chars, cite only `coach-guide.json` source IDs, and any proposal may only name workouts and
  occurrence keys that were sent. `COACH_BUSY` (503) and `COACH_LIMIT` (429) are reported as `BUSY` and stop further
  coach calls without failing; the daily cap is 40 per account. Where `coach.ask` is absent the run says
  `NOT CONFIGURED` (not a failure) and `-Coach` only checks the request shape is accepted (503 `COACH_UNAVAILABLE`).

### Open task: one orphan verification account on the hosted testing API

A manual verification on 15 Oct 2026 left one **empty** account on `https://gohardrebuild-production.up.railway.app`.
Its email was never printed, so it cannot be found from outside: there is no admin or user-listing endpoint, the
only deletion route (`DELETE /api/v1/account`) needs that account's own sign-in, and this PC has no database or
Railway access. Guessing emails or mass deletion must not be attempted.

Known: email `verify-<8 hex>@example.test`, password `verify password 1`, display name `Verify` (the script uses
`API Verify`), created 15 Oct 2026 between about 16:30 and 16:40 UTC, no data written.

For an operator with database access (Railway → Postgres → Data/psql):

```sql
SELECT u."Id", u."Email", u."CreatedAtUtc"
FROM "Users" u
WHERE u."Email" ~ '^verify-[0-9a-f]{8}@example\.test$' AND u."DisplayName" = 'Verify'
  AND u."CreatedAtUtc" BETWEEN '2026-10-15 16:25' AND '2026-10-15 16:45'
  AND NOT EXISTS (SELECT 1 FROM "Operations" o WHERE o."UserId" = u."Id")
  AND NOT EXISTS (SELECT 1 FROM "FoodEntries" f WHERE f."UserId" = u."Id")
  AND NOT EXISTS (SELECT 1 FROM "Plans" p WHERE p."UserId" = u."Id")
  AND NOT EXISTS (SELECT 1 FROM "Workouts" w WHERE w."UserId" = u."Id");
```

Only if this returns **exactly one** row: either run `.\scripts\delete-verify-account.ps1 -BaseUrl <api> -Email <that
email>` (the normal deletion path; preferred), or in SQL `BEGIN; DELETE FROM "Users" WHERE "Id" = '<that id>';` —
check it reports `DELETE 1`, then `COMMIT;` (owned rows cascade). Zero or several rows: stop and change nothing.

## Secrets

`infrastructure/.env.local` (database password) and `api/src/GoHard.Api/appsettings.Local.json` (connection string,
JWT signing key) are generated by `setup.ps1`, git-ignored and never printed. For any shared environment supply
`GOHARD_ConnectionStrings__Default` and `GOHARD_Auth__SigningKey` as environment variables instead. The app contains
no secrets; the API address is the only build-time setting.

## Releases

### Eating out — deployed 26 Oct 2026 (`main` 8458563)

- **What:** Eating out (docs/EATING_OUT.md): verified Canadian menus for McDonald's (27 items, official calculator values
  captured in a browser), Tim Hortons (33, official Nutrition Information PDF "as of July 2026"), Subway (31, official
  table "October 2026") and Pizza Pizza (20, official pages "as of November 1st, 2023"); Help me choose / Improve my
  order with deterministic totals and ranking; natural-language preferences through the existing Groq coach provider
  (one call per Send, checked, never nutrition); logging through the atomic `food.batch`; Save as meal.
- **Deployment:** owner approved 26 Oct 2026. `main` fast-forwarded 2397b0d → 8458563 (no unrelated changes on main).
  CI run 149 on `main`: passed (https://github.com/abdbabti01/GoHardRebuild/actions/runs/40321444564; branch CI 148 on
  the same commit also passed). Railway **devoted-caring**: success at 12:19 UTC. Hosted `/health/ready`: Ready, 14
  migrations (none added by this feature). `/capabilities`: contract 2, minimum 2, declares `restaurants.catalog` and
  `restaurants.interpret` (and `coach.ask`, so the existing Groq settings were picked up unchanged; no secret was
  touched). `/restaurants/catalog` and `/restaurants/interpret` answer 401 without a session. Railway
  diplomatic-intuition reported failure (unused project, ignored as before).
- **App:** IPA 54 (built from a100461; app code and bundled catalog identical to 8458563) — artifact
  `GoHard-Dev-unsigned-ipa`, https://github.com/abdbabti01/GoHardRebuild/actions/runs/40318077683, available until
  9 Nov 2026. No rebuild.
- **Compatibility:** additive only. No migration, no contract change, no new configuration. Older apps never call the
  new routes. Rollback: redeploy 2397b0d; nothing stored on the server depends on Eating out (logged orders are ordinary
  food entries with their own snapshots).
- **Pending:** live AI on the iPhone (owner to confirm; no hosted test account was created and no live request was made
  from here). Hosted data checks for logging/saving from Eating out, same reason (verified locally: API tests on
  PostgreSQL, Drift tests, and the emulator journey with a stubbed provider).
- **Known gaps:** McDonald's Small and Large fries, McCafé drinks and combos are not in the catalog (a requested size
  that is not listed is reported as not found, never replaced); McDonald's values could not be re-read from the build
  machine (its edge refuses scripted requests) and rest on the browser capture; no customisations (no sauce, extra
  cheese, other milks) are calculated for any chain; French and Arabic strings await a fluent review.
