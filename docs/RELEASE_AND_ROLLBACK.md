# Setup, upgrade, compatibility and rollback

Internal QA preparation only. Nothing here deploys, publishes to a store, or touches the original GoHard databases.

## Server schema

| Migration | Contents |
|---|---|
| `20261011011030_Initial` | users, refresh tokens, operations, training contexts, plans, occasions, workouts, exercises, sets, food entries, exercise catalog |
| `20261011011041_AddActivitiesAndProposals` | runs, body metrics, proposals (additive only) |
| `20261020200446_AddExerciseIncrements` | new table `ExerciseIncrements` (owner + exercise key, nullable `IncrementKg` numeric(9,5), revision), cascade-deleted with the account; additive only (docs/PROGRESSION.md) |
| `20261031122355_AddEntitlements` | new tables `PreviewOverrides` (owner preview tier, test-allowance reset) and `AiUsage` (one reservation per provider-backed AI request: `State` reserved/counted/released, `LeaseUntilUtc`, `Reached`; partial unique index on `(UserId, Scope, RequestId) WHERE State = 'counted'`), both cascade-deleted with the account; additive only (docs/PLUS_PREVIEW.md › Shared limits). Regenerated 31 Oct before any deploy (replaces the unreleased `20261031070038`). Rollback: the previous build ignores both tables |
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

### Food resolution: everyday defaults, per-food evidence, catalog v3 — deployed to testing 25 Nov 2026 (`main` 5fe71ec)

- **What:** Describe your meal now separates reading, retrieval, ranking and resolution (docs/FOOD_DATA.md › Food
  resolution). Typed food attributes in en/fr/ar (unknown ≠ false); only reviewed records are accepted without asking;
  a **reviewed general record** (USDA "not further specified") is used without a question when it shows everything said
  and names nothing that was not, shown as "Potato (general)" with "Uses a general nutrition estimate. Change the food or
  portion for a closer match." and a standard portion ("Standard size: 1 egg (50 g)"). Explicit words win (raw eggs, egg
  whites, boiled peeled potatoes). Questions only where a detail matters and no general record fits (cooked chicken
  thighs: the skin; raw or cooked for a weight). Each food's details come only from its own words: in "boiled potatoes and
  chicken" the chicken is not boiled; in "raw carrots and cooked chicken" it is cooked, never raw. Search always widens
  after the pause; Change food / Change amount / Remove on each item; "I'm not sure" estimates are disclosed. Catalog v3
  (131 foods) from the official FDC downloads.
- **API:** optional `evidence` per described food (kept only when the words appear in the question) and `more` on
  `/foods/search`. Additive; no migration, no new configuration, contract 2. Older apps ignore both; this app works with
  the older server shape too (tested). Charging unchanged.
- **Build:** app code e835c3a (CI 276); unsigned IPA run 89 from e835c3a (tag `ipa-food-mixed-e835c3a`, artifact
  GoHard-Dev-unsigned-ipa), supersedes IPA 88 and 86. 5fe71ec adds only the ledger, so **IPA 89 has the deployed app
  code**. No exercise-preview code, media or build options.
- **Merged and deployed:** authorized by the owner's request of 25 Nov 2026. `main` fast-forwarded ac324ff → 5fe71ec (main
  had no newer commits; nothing to resolve). CI 278 passed on the branch head and CI 279 on `main`. Railway devoted-caring
  deployment 8062420392 reported Success; hosted `/health/ready` Ready with 17 migrations (unchanged),
  `/api/v1/capabilities` contract 2 and advertises `coach.meal-log` and `food.search`; `/coach/daily` and `/foods/search`
  without a token 401. diplomatic-intuition not touched. No variable, secret, subscription or hosted account changed or
  created.
- **Verified:** API 270/270, app 1083/1083, analyze, l10n; mixed-meal tests in both response shapes; emulator journey of
  the defaults with the coach **stub**. **Not verified:** the hosted `evidence`/`more` fields (behind sign-in; no account
  created), live Groq reading of meal sentences (no key here: left for the owner's iPhone test), iPhone, VoiceOver.
- **Rollback:** revert the six commits ac324ff..5fe71ec on `main`; the API change is additive, no data or schema is
  affected. Entries logged with general records stay valid food entries.

### Food search relevance, Describe your meal and the Add food invitation — deployed to testing 25 Nov 2026 (`main` 1ebe45b)

- **What:** Food search ranks plain everyday foods before products (raw and cooked chicken breast first), respects
  preparation, cut and brand, says Brand/Generic, collapses repeats, corrects misspellings and puts French/Arabic staples
  in English for USDA; an exact match still offers **Search more foods and brands**. **Describe your meal**: Leon or
  Leona invites it at the top of Add food (the only entry; plain panel with the coach off); one AI request reads the
  sentence as words, the phone matches real food records and asks only what matters (raw or cooked only where cooking
  changes the weight, which food, how much), the existing meal review's **Log meal** logs it once. Typed follow-ups change
  the open draft. Foods past twelve are named and must be added with Add food or left out (docs/FOOD_DATA.md › Search
  relevance, Describe your meal). Catalog v2 (77 foods). New strings in en/fr/ar.
- **API:** `POST /coach/daily` kinds `ate`/`edit`, capability `coach.meal-log`, response fields `foods`, `edits`,
  `extra`; USDA page sizes 25/15. No migration, no new configuration, contract 2. Charging: one request per usable
  reading; questions, matching, search, review and logging never charged; unusable readings and retries not charged.
- **Build:** code 8c85823 (CI 264); replacement unsigned IPA run 86 from 8c85823 (tag `ipa-describe-invite-8c85823`,
  artifact GoHard-Dev-unsigned-ipa), supersedes IPA 85. 1ebe45b adds only the ledger, so IPA 86 has the deployed app
  code. No exercise-preview code, media or build options.
- **Merged and deployed:** authorized by the owner's request of 25 Nov 2026. `main` fast-forwarded 2211ad0 → 1ebe45b (main
  had no newer commits). CI 267 passed on `main`. Railway devoted-caring redeployed; hosted `/health/ready` Ready with
  17 migrations (unchanged), `/api/v1/capabilities` contract 2 and advertises `coach.meal-log`; `/coach/daily` without a
  token 401. diplomatic-intuition not touched. No variable, secret or hosted account changed or created.
- **Verified:** API 270/270, app 1055/1055, analyze, l10n; local end to end and emulator journey
  `journey_describe_meal_test` with the coach **stub**. **Not verified:** live Groq reading of meal sentences (no
  authenticated live test was possible without creating an account: left for the owner's iPhone test), live USDA brand
  coverage beyond spot checks, iPhone, VoiceOver.
- **Rollback:** revert 8c85823 and 53f74d7 (and their ledger commits); the API change is additive (an older app ignores
  `coach.meal-log`), no data or schema is affected.

### Eat: meals first and a compact top — deployed 24 Nov 2026 (`main` c524e4f)

- **What:** Eat's order is now summary › the day's meals › reminders › Eating out › History & trends (docs/FOOD_DATA.md
  › Eat page order). Eat's top is compact (docs/FOOD_DATA.md › Compact top): a smaller coach with a short briefing
  that leaves the figures to the rings, one action and Ask me; the summary without a photograph, the rings side by side
  with one line each; percentages and composition in a folded **Nutrition details**; Edit goals and Customize tracking
  in a **Nutrition settings** sheet; **Set daily goals** on the summary while none is set. Today is unchanged.
  17 new strings in en/fr/ar.
- **App only.** No API code, migration, capability, contract, sync, entitlement or AI-provider change. Opening Eat,
  details or settings sends no AI request and logs nothing.
- **Build:** code 43dcda5 (`feature/eat-meals-first`, CI 252, IPA 83) and ab3be2e (`feature/eat-compact-top`, CI 255);
  unsigned IPA run 84 from ab3be2e (tag `ipa-eat-compact-top-ab3be2e`). c524e4f adds only the ledger, so IPA 84 has
  the merged app code and is reused. No exercise-preview code or media.
- **Merged:** owner tested IPA 84 and approved 24 Nov 2026. `main` fast-forwarded 27877fe → c524e4f (main had no newer
  commits). CI 258 passed on `main`. Railway devoted-caring: success; hosted `/health/ready` Ready with 17
  migrations (unchanged), `/api/v1/capabilities` contract 2. No hosted account created.
- **Verified:** owner on iPhone (IPA 84); full app suite, analyze, l10n check; emulator journey
  `journey_eat_compact_test`. **Not verified:** VoiceOver and Reduce Motion on a device.
- **Rollback:** revert ab3be2e (compact top) and, if wanted, 43dcda5 (page order); app only, no data affected.

### Help me set my targets — merged 18 Nov 2026 (formula review pending)

- **What:** Eat › Edit goals › Help me set my targets: goal, a few details (latest weigh-in reused, metric or imperial),
  and editable starting calories and protein, saved through the goals form's own path; carbs and fat as estimates only
  (docs/NUTRITION_TARGETS.md). Offline and deterministic; nothing is sent to the AI.
- **Formula review: PENDING.** The calculation must be reviewed by a registered dietitian (or equivalent) before a
  public release; open questions in docs/NUTRITION_TARGETS.md.
- **App only.** No API code, migration, capability, contract or sync change. Railway redeploys `main` automatically;
  the server code it runs is unchanged.
- **Build:** code a0ba9ac (branch `feature/target-estimator`), CI 205 passed; unsigned IPA run 72 from a0ba9ac.
- **Merged:** owner instructed 18 Nov 2026; `main` fast-forwarded from 41fc375 (feature a0ba9ac plus these notes only).
- **Unverified until the owner confirms on iPhone:** goals, weigh-in, units, refusals, Cancel, coach off, French and
  Arabic at large text, offline.
- **Rollback:** revert the feature commit a0ba9ac (app only); calorie and protein goals already saved stay as set.

### Change email — deployed 14 Nov 2026 (`main` e072c6d)

- **What:** Me › Account › Change email: new address + current password, a code to the new address (resend, cancel);
  nothing changes until it is confirmed; then the same account (ID, data, Plus, pending offline changes) signs in and
  recovers with the new address, every device is signed out, and the old address gets a notice naming the support
  address (docs/AUTHENTICATION_EMAIL.md › 12).
- **One additive migration** (`AddEmailChange`: `AuthChallenges.NewEmail`, `MailMessages.ToEmail`) → 17 migrations.
  New capability `account.email-change`, declared only when `Email:SupportAddress` is set. Contract unchanged.
- **Configuration:** owner set `GOHARD_Email__SupportAddress=contact@lesdeserts.ca` in Railway (devoted-caring).
- **Build:** code e072c6d (branch `feature/change-email`), CI 200 passed (9e5826d: CI 199); unsigned IPA run 70 from
  9e5826d (app code unchanged since).
- **Deployed:** owner approved 14 Nov 2026. `main` fast-forwarded 5a0ee30 → e072c6d (the Eat branch stays separate).
  Railway devoted-caring: success. Hosted `/health/ready`: Ready, 17 migrations; after the owner's variable,
  `/capabilities` declares `account.email-change`; the four routes answer 401 without sign-in. No hosted account created,
  no email sent by these checks. IPA 70 reused.
- **Unverified until the owner confirms on iPhone:** real code delivery to the new address and the notice to the old one,
  sign-out of other devices, offline changes resuming after signing in with the new address.
- **Deploy order:** API first (done). IPA 70 against an older server would say the feature is not offered yet.
- **Rollback:** redeploy `main` 5a0ee30 (the extra columns are ignored by it); addresses already changed stay changed.
  To switch the feature off without a rollback, remove `GOHARD_Email__SupportAddress` (routes then answer 503).

### Saved plans, Suggested today, 8-character passwords, 4-digit verification codes — deployed 5 Nov 2026 (`main` 92dd85f)

- **What:** Save plan apart from activation and the Train › Plan library (docs/PLAN_LIBRARY_OVERLOAD.md); Free saved
  plans 3 → 1 and un-archiving limited like creating; Suggested today in the recorder (Plus); new passwords need 8
  characters (was 15); email verification sends 4-digit codes to apps that ask (IPA 68) and 8 digits otherwise, with
  per-address daily caps; password-reset codes stay 8 (docs/AUTHENTICATION_EMAIL.md › 11).
- **One additive migration** (`AddChallengeCodeDigits`: `AuthChallenges.CodeDigits`, default 8) → 16 migrations. No
  new capability, contract unchanged, no minimum-version change. Configuration defaults change in code:
  `Plus:FreeSavedPlans` 1, `Email:VerifyMaxAttemptsPerDay` 10, `Email:VerifyMaxSendsPerDay` 10. If Railway sets
  `GOHARD_Plus__FreeSavedPlans`, that value wins.
- **Build:** code 0bd50b8, CI 42105743824 passed, unsigned IPA run 68 (artifact GoHard-Dev-unsigned-ipa).
- **Deployed:** owner approved 5 Nov 2026. `main` fast-forwarded 5441d2a → 92dd85f (nothing newer on main). CI on `main`
  42114195492 passed. Railway devoted-caring: success (diplomatic-intuition failing as before; unused). Hosted
  `/health/ready`: Ready, 16 migrations applied; `/capabilities`: contract 2, minimum 2, `account.email` declared. No
  secret or variable changed, no hosted account created. IPA 68 reused (app code unchanged since 0bd50b8).
- **Unverified until the owner confirms on iPhone:** real delivery of a 4-digit verification email, iPhone one-time-code
  autofill, registration with an 8-character password on the hosted API. Password-reset codes stay 8 digits.
- **Deploy order:** any. Older builds still get and enter 8-digit codes; an 8-digit code issued before the deploy still
  works in IPA 68. Cross-device: a 4-digit code cannot be typed into an older build; resend from that build for 8 digits.
- **Effect on existing accounts:** Free accounts with more than one plan keep every plan usable; only creating another is
  explained. Existing passwords keep signing in.
- **Rollback:** redeploy `main` 5441d2a (the extra column is ignored by it). A 4-digit code sent by this build is
  refused by the older server: ask for a new code. Passwords of 8–14 characters set meanwhile keep signing in on the
  older server (it checks length only for new passwords).

### GoHard Free and Plus preview — deployed 31 Oct 2026 (`main` d31a29c)

- **What** (docs/PLUS_PREVIEW.md): one entitlement model, Free limits (3 saved plans, 10 saved meals/recipes, 15 AI
  requests a month), the shared AI limits in the database, Me › GoHard Plus, owner-only preview controls. **No
  payments**: no StoreKit, checkout, products or prices.
- **Effect of this deploy:** every hosted account is now Free with those limits enforced. Existing content over a limit
  stays usable; only creating more is explained. Nobody can switch tiers until `GOHARD_Plus__PreviewOwnerUserId` is set.
- **Verified on the hosted API** (no account created): `/health/ready` 200 "Ready, 15 migration(s) applied"
  (`AddEntitlements` included), `/capabilities` declares `account.entitlement` (contract 2, minimum 2),
  `/entitlement` and `/preview/entitlement` refuse a request without a token (401). Railway devoted-caring: success
  (diplomatic-intuition failing as before; unused).
- CI on `main` 41202879304: attempt 1 failed on the known `coach_companion_test` "no replay" flake, attempt 2
  passed; the same code passed on the branch (41202875156). App unchanged since IPA 64 (c5d6f01), which is reused.
- **Rollback:** redeploy 7398a39. The two new tables are ignored by the older build; with it, nothing is limited.
- **Pending:** the owner ID variable (owner), the owner's iPhone checks of Free, Plus, downgrade and allowances.

### Shared nutrition assessment, goal colours and the weekly report — merged 31 Oct 2026 (`main` 05a998d)

- **What** (docs/EAT_COMPANION.md › Shared assessment, goal colours and the weekly report): one assessment of the day's
  calories and protein against the goals, read by Eat's briefing, What could I eat? and its ranking, the Today/Eat goal
  bars and the weekly report; red/yellow/green goal bars with words (protein never red); the coach says where the day
  stands before offering food and asks first once a goal is reached (continuing always works); no food pushed once every
  goal is reached; earlier days compared only with a goal recorded for that day; local goal history (starts now, never
  backfilled); Eat › History & trends › Weekly report (local, no AI).
- **Deployment:** owner approved 31 Oct 2026 after confirming IPA 63 on the iPhone. `main` fast-forwarded 19e2cf2 →
  05a998d (no newer work on `main`). CI on `main`: passed (https://github.com/abdbabti01/GoHardRebuild/actions/runs/41166239621).
  Railway **devoted-caring** redeployed automatically: success; hosted `/health/ready` 200, 14 migrations (unchanged).
  diplomatic-intuition reported failure (unused project, ignored as before). No API change was needed.
- **App:** IPA 63 (run 41163916782, built from 71f0b48, the same app code as 05a998d, which adds only the ledger) —
  artifact `GoHard-Dev-unsigned-ipa`. No rebuild.
- **Compatibility:** app only. No migration, contract change, capability, secret or configuration. The goal history is a
  local record on each phone (`nutrition_goal_day`), not synced. Rollback: redeploy/reinstall from 19e2cf2; nothing on the
  server depends on this feature.
- **Confirmed by the owner on iPhone:** IPA 63 passed the owner's iPhone checks.
- **Pending (unverified):** real Groq behaviour for idea ranking after goals change; VoiceOver/TalkBack reading of the
  goal bars; the emulator journey `journey_nutrition_report_test` (never ran: emulator storage).

### Meal habits, reminders and the Eat companion — deployed 30 Oct 2026 (`main` 57ea806)

- **What:** two features merged together (the second was built on the first).
  - Meal habits, saved-meal amounts and Reminders (docs/MEAL_HABITS_REMINDERS.md): usual-meal suggestions worked out on
    the phone (opt-in), Log this time / Update saved meal / Save as a variation, one food of a saved meal changed for
    one time through the coach (`portion.ingredient`), Me › Reminders for workout, meal, medication and supplement
    reminders (local to the phone and account; Taken / Snooze / Skip).
  - Eat companion (docs/EAT_COMPANION.md): purpose-specific reminder wording (hidden details never show a name, dose
    or instructions); Eat's day briefing and in-app heads-ups (once a day, switchable); What could I eat? with new meal
    ideas proposed as words by the model and matched on the phone to real food records, with ambiguous records,
    other preparations and unit mismatches confirmed by the person; the coach's message isolated so it can never block
    the journal.
- **Deployment:** owner approved 30 Oct 2026 after confirming IPA 62 on the iPhone. `main` fast-forwarded 12d7ce5 →
  57ea806 (no newer work on `main`; other branches untouched). CI on `main`: passed
  (https://github.com/abdbabti01/GoHardRebuild/actions/runs/41125465960). Railway **devoted-caring**: success.
  Hosted `/health/ready`: 200. `/capabilities`: contract 2, minimum 2, declares `coach.daily` and the new `coach.ideas`
  (with `coach.ask`, `food.saved-meals`, `restaurants.*`): the existing Groq settings were picked up unchanged; no secret or
  variable was touched. `POST /coach/daily` without a session: 401. Railway diplomatic-intuition reported failure
  (unused project, ignored as before).
- **App:** IPA 62 (run 41116733213, built from 57ea806, the merged commit) — artifact `GoHard-Dev-unsigned-ipa`. No
  rebuild.
- **Compatibility:** additive. No migration, no contract change, no new configuration. `coach.ideas` is used only by a
  phone that sends `features: ["ideas"]`; older phones get the saved-item suggestions as before. Reminders, their answers,
  meal-suggestion choices and logging times stay on the phone (nothing new stored on the server). Rollback: redeploy
  12d7ce5; nothing stored on the server depends on these features.
- **Confirmed by the owner on iPhone:** Eat renders normally on IPA 62 (the blank grey page of IPA 59–61, caused by an
  untyped reminder list for accounts with reminders, is fixed).
- **Pending (unverified):** live Groq reading of ingredient changes and meal ideas; real food matching against the hosted
  USDA search; notifications on the phone (delivery, lock-screen wording, Taken / Snooze / Skip buttons, background meal
  suppression); VoiceOver. No hosted test account was created and no live coach request was made from here.

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
