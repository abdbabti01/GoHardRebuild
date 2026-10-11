# Architecture record

Fresh rebuild, October 2026. Sources of truth: `CLAUDE_REBUILD_PROMPT.md`, `REBUILD_BRIEF.md`,
`REBUILD_TASK_MAP.md` and the referenced product/visual specifications in the handoff folder.

## Pinned toolchain

| Piece | Version |
|---|---|
| .NET SDK / target | 10.0.401 (`api/global.json`, roll-forward latestFeature) / `net10.0` |
| EF Core Relational / Npgsql provider / JwtBearer | 10.0.12 / 10.0.3 / 10.0.12 |
| PostgreSQL | 17.6 (dev container and test containers) |
| Tests | xUnit 2.9.3, Testcontainers.PostgreSql 4.16.0, Mvc.Testing 10.0.12 |
| Flutter / Dart | 3.47.6 / 3.13.5 |
| flutter_riverpod, dio, drift, drift_flutter, flutter_secure_storage | 3.4.3, 5.11.1, 2.35.2, 0.3.1, 11.2.0 (`app/pubspec.lock` committed) |

The first Android build also installed NDK r28c and Build-Tools 36 into the existing Android SDK (additive).

## API (`api/src/GoHard.Api`) — one modular application

```
Domain/        pure rules: ScheduleRules, WorkoutResultRules, SemanticHash        (no EF, no HTTP)
Persistence/   entities, GoHardDb, Migrations/, read-only SchemaReadiness, CatalogSeeder
Application/   CommandRunner, AuthService, PlanService, WorkoutService, ProposalService,
               FoodService / ActivityService / AccountService, Contracts.cs (wire DTOs)
Endpoints/     route table only: every mutating route goes through CommandRunner
Data/          baselines.json (curated plan), exercise-catalog.json (reference data)
Program.cs     composition, auth, readiness gate, explicit `migrate` / `seed-catalog` / `readiness` commands
```

**Every command** (`CommandRunner`): begin transaction → per-account advisory lock → look up a terminal operation
**before** looking at revisions → compare the semantic hash (`OPERATION_PAYLOAD_MISMATCH` on a changed payload) →
run → record the acknowledgement atomically. Accepted, conflict and rejected are all terminal; a foreign or missing
resource is a plain 404 and records nothing. Acknowledgement shape: `{operationId, status, revision, data, code}`
with HTTP 200 / 409 / 422.

**Ownership** always comes from the validated token (`sub`), never from a client-supplied ID. A token stops working
the moment its account is deleted (security-stamp check on every request). Passwords use ASP.NET Core Identity's
`PasswordHasher`; refresh tokens are stored hashed and rotate on use.

**Readiness**: `SchemaReadinessService` reads migration history and table names only and reports
`Ready / PendingMigration / UnknownHistory / SchemaDrift / Unreachable`. Not ready ⇒ `/health/ready` and all `/api`
return 503. There is no startup migration, history stamping, date rewrite, repair or background reaper.

## App (`app/lib`) — widgets → providers → repositories → local store / API

```
core/       config (no default API), clock + BusinessDateService, units, format, theme tokens, shared widgets
data/       db.dart (Drift), models.dart (typed views over wire JSON), session.dart (tokens, epoch, transport),
            sync.dart (SyncEngine: durable commands, dispatch, merge, conflict resolution)
app/        providers.dart (composition root + shared projections), app.dart (lifecycle, theme mode)
features/   auth, shell, today, plans, workout, nutrition, me, activity
```

Widgets never touch Dio or Drift. Repositories (`PlanRepository`, `WorkoutRepository`, `FoodRepository`,
`ProfileRepository`, `ActivityRepository`, `AuthRepository`) are the only writers.

### Local store

Two Drift tables. `records` holds one row per owned thing in wire shape (`body`) with sync metadata
(`revision` acknowledged by the account, `localRevision`, `syncState`, `serverBody`, `alternativeBody`), keyed by
`(ownerId, kind, id)`. `commands` is the outbox. IDs are client-generated UUIDs, so a record has one identity on the
phone and on the server and nothing needs remapping after sync.

### Sync rules (the integrity core)

1. `SyncEngine.submit` writes the local change **and** its command in one transaction, before any network use.
2. A command's `payload` is immutable. References such as "the acknowledged revision of this set" are resolved
   **once**, stored as `outbound`, and re-sent byte-for-byte on every retry under the same operation ID.
3. Commands dispatch in dependency order (workout → sets → finish; context → plan edits). A dependency in conflict or
   rejected blocks its dependents until the user decides.
4. An acknowledgement replaces a record's body only when no newer local edit is waiting; otherwise it only advances
   the revision ("older ack keeps newer local change").
5. A conflict keeps the local version, stores the account's version beside it and waits. Choices: *use the account's
   version* (local kept as `alternativeBody`), *keep mine* (one replacement command, new operation ID; account's
   version kept as the alternative), or for a refused planned start *keep as a manual workout*. No choice ever adds a
   set, finishes a workout or silently drops the other version.
6. Every write is keyed by the owner captured at the start; `Session.epoch` changes on sign-in/out and any response
   arriving under an older epoch is dropped. Sign-out removes credentials only; that owner's records and queue stay
   on the phone, invisible to other accounts, and resume on their next sign-in.

### Dates, time and units (contract version 1)

| Suffix / name | Meaning |
|---|---|
| `dayKey`, `…Date`, `startDate`, `pausedOn` | calendar `YYYY-MM-DD`, never zone-converted (PostgreSQL `date`) |
| `…AtUtc` | UTC instant (PostgreSQL `timestamptz`, microsecond precision) |
| `…Seconds` (`activeDurationSeconds`, `restSeconds`, `durationSeconds`) | seconds. There is no minute-based field anywhere |
| `loadKg`, `weightKg` | kilograms. Pounds exist only at the input/display boundary (`core/units.dart`) |
| `weekdays` | ISO numbers, 1 = Monday … 7 = Sunday |
| nutrients | `null` = unknown, `0` = entered zero; per-nutrient `provenance`: `entered` / `unknown` / `imported` |

Workout time and rest are computed from persisted UTC anchors (`WorkoutRuntime`), never counted by a ticker, so
backgrounding, restart, midnight and DST cannot change them. A form or workout pins its `dayKey` when it opens.

## Domain decisions

- Planned occasion, actual workout and result are separate. One `TrainingContext` row per account holds the primary
  plan; lifecycle is draft / active / paused / closed; archive is a visibility flag only.
- Workout → plan/occasion foreign keys are `SET NULL`; nothing about a plan cascades into performed history.
- The exercises sent when a workout starts are its frozen prescription. Anything added later is forced to
  "not prescribed". The server computes the outcome (`full` / `partial` / `no_data` / `manual_recorded`) from sets.
- One occasion is credited by exactly one workout. No-data never credits; manual never links.
- Unsupported plan setup returns fit feedback and creates nothing.
- Proposals (schedule move, movement substitution) are stored with their base plan revision and an evidence hash;
  editing recorded history flips open proposals to `needs_review`; a declined unchanged proposal is not offered again.

## Deliberate simplifications (marked `ponytail:` in code)

- One advisory lock per account serializes that owner's commands (`CommandRunner`). Upgrade: per-aggregate row locks.
- Full-snapshot pull (`SyncEngine.pull`, `GET /sync/snapshot`). Upgrade: a `since` cursor once histories are large.

## Deviations from the brief, and their impact

| Deviation | Reason / impact |
|---|---|
| Semantic hash is computed on the server only; the client stores exact outbound bytes instead of hashing | Avoids cross-language number-canonicalisation risk. Both suites still read the same fixture file |
| One shared fixture file instead of two byte-identical copies | Byte equality by construction |
| Local store is a typed document table rather than one table per entity | One place for revision/owner/conflict metadata; far less schema to migrate |
| Plan-draft creation and proposal create/accept/decline need the account (not queued offline) | The account builds/validates them. Answers are retained locally and retries reuse the same IDs |
| Setup happens after sign-in, so there is no pre-auth setup flow token | Nothing to claim across authentication |
| No AI provider is implemented, only the `IPlanAssistant` boundary with a no-op default | Core app never depends on AI. Capability stays off |
| Reminders (OS notifications), GPS run tracking, social, health sync and music are not implemented | Shown as unavailable or absent; see `core/config.dart` `Capabilities` |
| The client does not yet read `/capabilities` to enforce a minimum contract | Only one contract version exists. Required before a second one ships |
