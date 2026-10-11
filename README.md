# GoHard — fresh rebuild (Evening Club)

A new Flutter app, .NET 10 API and dedicated PostgreSQL development database, built from scratch from the
GoHard product and Evening Club design references. It shares no code, database, container or app identity
with the original GoHard projects, which are untouched.

**Today / Train / Eat / Me.** Train has Workouts / Plan / Progress and keeps its selected section.

| Folder | What it is |
|---|---|
| `app/` | Flutter app: Riverpod state, Dio transport, Drift/SQLite local store and command queue, secure credential storage |
| `api/` | ASP.NET Core (.NET 10) API, EF Core + Npgsql, PostgreSQL only; `src/GoHard.Api`, `tests/GoHard.Api.Tests` |
| `contracts/` | One wire/rules fixture read by BOTH the .NET and Dart test suites |
| `infrastructure/` | Docker Compose for the dedicated development database |
| `scripts/` | Windows PowerShell setup, start, test and Android scripts |
| `docs/` | Architecture, task matrix, progress ledger with evidence, release/rollback notes, native screenshots |

## Prerequisites (Windows)

- .NET 10 SDK (installed side by side; `api/global.json` pins 10.0.401 with feature roll-forward)
- Docker Desktop, running
- Flutter stable (built with 3.47.6 / Dart 3.13.5) and the Android SDK with an emulator (AVD) or a device

The scripts check these and tell you what is missing. They never print passwords or keys.

## Run it

From `C:\dev\GoHardRebuild` in PowerShell:

```powershell
# 1. One-time (repeatable) setup: dedicated container + database, explicit migrations, exercise catalog
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1

# 2. Start the API (leave this window open)        -> http://127.0.0.1:5131/health/ready
powershell -ExecutionPolicy Bypass -File .\scripts\start-api.ps1

# 3. In a second window: launch the app on an Android emulator (starts one if needed)
powershell -ExecutionPolicy Bypass -File .\scripts\run-android.ps1
```

Then create an account in the app. Nothing is pre-filled: a new account has no plan, workouts or food.

Physical phone on the same Wi-Fi: `.\scripts\start-api.ps1 -Lan` and
`.\scripts\run-android.ps1 -ApiBase http://<this-pc-ip>:5131`.

## Test it

```powershell
# Everything automated: API build + 58 tests on disposable PostgreSQL + release publish,
# then Flutter codegen + analyze + 57 unit / real-Drift / widget tests. Works while the API is running.
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1

# Native Android journey on an emulator/device against the running local API; saves real screenshots
powershell -ExecutionPolicy Bypass -File .\scripts\test-android.ps1
```

`test.ps1 -SkipApp` / `-SkipApi` run one side. API tests need Docker: without it they **fail**, they do not skip.

## What setup creates (and only this)

| Resource | Name |
|---|---|
| Container | `gohard-rebuild-postgres` (postgres:17.6) |
| Volume | `gohard_rebuild_pgdata` |
| Database / user | `gohard_rebuild_dev` / `gohard_rebuild` on `127.0.0.1:5435` |
| Local secrets (git-ignored) | `infrastructure/.env.local`, `api/src/GoHard.Api/appsettings.Local.json` |
| API port | `5131` |
| Android app ID | `com.gohard.rebuild` (debug: `com.gohard.rebuild.debug`, label "GoHard Dev") |

Setup refuses to migrate anything whose connection string is not that database and port.
To remove the development database completely: `docker compose -f infrastructure\docker-compose.yml --env-file infrastructure\.env.local down -v`.

## Important behaviours

- **Migrations are explicit.** `setup.ps1` runs `GoHard.Api migrate` and `seed-catalog`. Normal API start only *reads*
  schema readiness; if the schema is not ready every `/api` call returns 503 and nothing is repaired or stamped.
- **No default server in the app.** The API address comes from `--dart-define=GOHARD_API_BASE=...`; without it the
  app shows a configuration error instead of contacting some other server.
- **Local first.** Every change is saved on the phone with its command in one transaction, then synced with a
  stable operation ID. Sign-out keeps your data; account deletion is a separate password-confirmed erasure.

## Where to read next

- `docs/ARCHITECTURE.md` — structure, contracts, units, sync rules, deviations
- `docs/TASK_MATRIX.md` — all 33 A/B/W/N/R tasks mapped to modules, tests and honest status
- `docs/PROGRESS_LEDGER.md` — exact commands, results, evidence and open items
- `docs/RELEASE_AND_ROLLBACK.md` — migrations, upgrade, compatibility and rollback notes

Production deployment, store publishing and importing data from the original GoHard are **not** part of this work.
