# Setup, upgrade, compatibility and rollback

Internal QA preparation only. Nothing here deploys, publishes to a store, or touches the original GoHard databases.

## Server schema

| Migration | Contents |
|---|---|
| `20261011011030_Initial` | users, refresh tokens, operations, training contexts, plans, occasions, workouts, exercises, sets, food entries, exercise catalog |
| `20261011011041_AddActivitiesAndProposals` | runs, body metrics, proposals (additive only) |
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

## Secrets

`infrastructure/.env.local` (database password) and `api/src/GoHard.Api/appsettings.Local.json` (connection string,
JWT signing key) are generated by `setup.ps1`, git-ignored and never printed. For any shared environment supply
`GOHARD_ConnectionStrings__Default` and `GOHARD_Auth__SigningKey` as environment variables instead. The app contains
no secrets; the API address is the only build-time setting.
