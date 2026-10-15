# Training plans: templates, your own workouts, fixed weekdays and rotating sequences

Added 16 Oct 2026 on `feature/train-plan-builder` (from `main` at `0364df0`). This is the design, the wire contract and
the rules for the plan builder. It extends the existing plan system (`Plan` + `Occasion` + `TrainingContext`,
local-first commands, reviewed activation); it does not replace it.

## Three things kept apart

| Concept | Where it lives | Changes when |
|---|---|---|
| **Starter template** (a familiar split with curated starting exercises) | `app/assets/data/plan-templates.json`, read-only, versioned | a new app build ships. Choosing one makes a personal copy; nothing ever points back at the template except `templateId` for display |
| **Workout definitions** (the user's own "Push", "Upper A", with exercises and prescriptions) | `Plan.workouts` (JSON on the plan) | the user edits the plan |
| **Occurrences** (dated or sequenced sessions of a definition) and **recorded sessions** | `Occasion` rows (with `workoutId`), and `Workout` rows with their frozen exercises and sets | the schedule is generated/changed; a workout is started, finished, skipped |

Three definitions (Push, Pull, Legs) on six weekdays are three `workouts` and six occurrences per week, each with its
own stable ID. Completing one never credits another.

## Schedule modes

**Fixed weekdays** (`schedule.mode = "fixed"`): `pattern` assigns a definition to each chosen weekday (one per weekday;
a definition may repeat). Occurrences are generated for the whole plan when it is created (finite: 1–52 weeks), exactly
like the existing block. Missed workouts stay on their date as Missed with Move / Skip / Start-now ("Continue").
Moving one occurrence (`plan.schedule` move) keeps its identity; changing the pattern (`plan.revise`) regenerates only
pending occurrences from an effective date. Fixed plans are always finite; "Continue this plan" repeats one.

**Rotating sequence** (`schedule.mode = "rotating"`): `cycle` is an ordered list of definitions (repeats allowed),
`trainingDays` optional weekdays (empty = any day). The cycle never restarts on Monday. The next workout is the
lowest sequence index that is neither credited nor skipped. It advances only by a credited finish or an explicit skip.
Opening, recording sets, saving for later, a no-data finish or a manual workout do not advance it. Rotating plans may be
finite (an end date) or **ongoing** (`durationWeeks = null`).

Rotating occurrences are **materialized when acted on**: the server creates occurrence *k* when a workout is started
for it or it is skipped. Until then the phone shows it as a projected ("virtual") occurrence. Both sides compute the
same ID for *k*, so a retry, a second device or a lost response cannot create a second one, and the unique index
`(PlanId, SequenceIndex)` enforces it.

Projected dates (rotating, phone only): from `max(today, startDate)` — or the day after the latest occurrence of this
plan already started, completed **or skipped** today or later — each next index takes the next training day (or the
next day when `trainingDays` is empty), skipping days the person chose to rest. A projected date is a plan, not a
record; it is never "missed". (Until 15 Oct 2026 a skip took no day, so skipping today's workout put the next one on
today — reported from an iPhone as "the next workout appears in its place". A skip now keeps its day; the next workout
can still be started now, explicitly.)

## Today (15 Oct 2026)

`resolveTraining` (`features/today/daily.dart`) says only what the primary plan says about today; open and recorded
workouts sit beside it (`DailySnapshot.inProgress`, `parked`, `recordedToday`) and never change it.

| Facts | Today |
|---|---|
| Occurrence(s) dated today | `PlannedToday`: each under its own name and real state — Due today, In progress, Saved for later, Skipped today, Completed, Partly completed. Several on one day are all kept; the first in progress/due leads, the rest are "Also today" rows |
| Today's occurrence skipped | Skipped today, with Undo skip while safe (`PlanRepository.canUnskip`; the account re-checks the revision, a conflict goes to the existing review). Fixed: "Next: Pull · Tuesday" on its real date. Rotation: "Next in your rotation: Pull" (· its day only when the plan has training days) and **Train this now** |
| Active plan, nothing dated today | `PlannedRest` "Planned rest day", next workout with its date; manual training, runs and food stay available; activity done that day is listed under Recorded today |
| Rotation with nothing dated today | Never inferred as rest from nothing being recorded: rest comes only from training days or a chosen rest day |
| Chosen rest (rotations, occurrence sheet "Rest today instead") | Local record kind `rest_day` (`{planId, dayKey}`), laid over the plan by `planListProvider` so Today, Train and the sheet agree. Skips, credits and advances nothing; survives sync and restart; "Train today" removes it. Not offered for fixed plans, which move or skip |
| Paused / before start / after the end / no primary plan | Plan paused / Starts … / Block ready to review / No active plan — never a rest day |
| A manual workout open | Its own compact "In progress" entry with Resume, above the plan's own state (the plan's Start becomes the quiet button). Finished: Recorded today. It never hides, completes, skips or advances anything |

A workout counts for an occurrence only through its `occasionId`; nothing is inferred from names, exercises or the
day. There is no reusable "manual workout definition" in the app: Manual workout starts a session directly.

## Deterministic occurrence IDs

`id = UUIDv5(namespace = planId, name)`, RFC 4122 (SHA-1 of the 16 namespace bytes in RFC order followed by the UTF-8
name; version 5; RFC variant).

| Mode | name |
|---|---|
| fixed | `"d:" + originalDate` (e.g. `d:2026-10-12`) |
| rotating | `"s:" + sequenceIndex` (e.g. `s:0`) |

Vectors are in `contracts/contract_fixture.json` › `planIds`. Legacy plans keep their random occasion IDs.

## Wire contract (contract version stays 1; every addition is optional)

New capabilities: `plans.builder`, `exercises.custom`. Fields marked † are omitted from JSON when null, so a command
recorded before them keeps its semantic hash.

```jsonc
// PrescriptionExercise — used by occasion.prescription and workouts[].exercises
{ "occurrenceKey": "e1",          // unique within its workout, stable across edits
  "catalogKey": "bench-press",    // catalog key | "custom:<uuid>" (owned custom exercise) | null (ad hoc name, no history link)
  "name": "Bench press", "isTimed": false,
  "targetSets": 3, "targetRepsMin": 8, "targetRepsMax": 12, "targetDurationSeconds": null, "restSeconds": 90,
  "targetLoadKg": 60.0,           // † optional target the user set. Never filled in by the app
  "notes": "Pause at the bottom" }// †

// WorkoutDefinition
{ "id": "<uuid>", "name": "Push", "notes": null, "exercises": [ /* PrescriptionExercise */ ] }

// PlanSchedule — all four fields always present
{ "mode": "fixed" | "rotating",
  "pattern": [ { "weekday": 1, "workoutId": "<uuid>" } ],   // fixed: 1..7 entries, distinct weekdays (ISO 1=Mon)
  "cycle": [ "<uuid>", "<uuid>" ],                           // rotating: 1..30 entries
  "trainingDays": [1, 3, 5],                                 // rotating: distinct, may be empty
  "cycleAnchor": 0 }                                         // rotating: index k at which cycle[0] applies

// PlanDto additions (null/false on legacy plans)
"workouts": [WorkoutDefinition] | null, "schedule": PlanSchedule | null, "isOngoing": false,
"timeBudgetMinutes": 45 | null, "templateId": "push-pull-legs" | null
// blockWeeks = durationWeeks, or 1 for an ongoing plan (older builds clamp by it); minRecoveryDays = 0 for new plans

// OccasionDto additions
"workoutId": "<uuid>" | null, "sequenceIndex": 3 | null, "isCustomised": false

// ExerciseSpec / ExerciseDto (workout exercises) additions: "targetLoadKg"†, "notes"†
```

### Commands (all through `CommandRunner`: idempotent, revision-checked, owner from the token)

| Kind | Route | Body | Notes |
|---|---|---|---|
| `plan.create` | `POST /plans` | `{operationId, planId, title, startDate, durationWeeks?, timeBudgetMinutes?, templateId?, workouts, schedule}` | Creates a **draft**. Fixed: generates every occurrence. Returns `PlanContextDto`. Existing ID → conflict `DUPLICATE_ID` |
| `plan.revise` | `PUT /plans/{id}` | `{operationId, expectedPlanRevision, effectiveDate, title, startDate, durationWeeks?, timeBudgetMinutes?, workouts, schedule}` | Future edits. See "Revising". Draft: everything may change. Active/paused: `startDate` and `mode` must stay (`START_LOCKED`, `MODE_LOCKED`). Closed: conflict `PLAN_NOT_ACTIVE` |
| `plan.occasion` | `PUT /plans/{id}/occasions/{occasionId}` | `{operationId, expectedPlanRevision, title, prescription}` | This occurrence only. Pending (eligible) materialized occasions only; sets `isCustomised` |
| `plan.schedule` (extended) | existing | `+ sequenceIndex`† | Skip of a not-yet-materialized rotating occurrence: `occasionId` = its ID, `sequenceIndex` = k, `to` = the day of the skip. Move is refused for rotating plans (`OCCASION_NOT_MOVABLE`). Unskip in a rotating plan only while no later index is materialized |
| `workout.start` (extended) | existing | `+ planId†, sequenceIndex†` | Planned start of a not-yet-materialized rotating occurrence. Server materializes it (date = `dayKey`) then starts as usual |
| `plan.activate` (extended) | existing | unchanged | New-style plans need every scheduled definition to have ≥ 1 exercise, else rejected `PLAN_NOT_USABLE` |
| `customexercise.put` | `PUT /custom-exercises/{id}` | `{operationId, expectedRevision (0 = create), name, category, equipment, isTimed, isArchived}` | Private to the owner. Someone else's ID is 404 and nothing changes |

Snapshot adds `customExercises: [{id, name, category, equipment, isTimed, isArchived, revision}]` (absent from an older
server). `catalogKey = "custom:<id>"` in a prescription must name the caller's own custom exercise
(`UNKNOWN_EXERCISE` otherwise, same code as an unknown catalog key); archived ones stay valid in existing plans.

### Validation (`PlanRules.Validate`, mirrored; error codes, in this order, first per group)

| Code | Rule |
|---|---|
| `TITLE_INVALID` | trimmed title 1–60 |
| `DURATION_INVALID` | `durationWeeks` null (ongoing, rotating only) or 1–52; fixed plans must be finite |
| `TIME_BUDGET_INVALID` | null or 10–240 minutes |
| `WORKOUTS_INVALID` | 1–20 definitions; distinct non-empty IDs; names trimmed 1–60; ≤ 30 exercises each; `occurrenceKey` non-empty and distinct within a workout; exercise name 1–120; `targetSets` null or 1–20; reps null or 1–100 with min ≤ max; `targetDurationSeconds` null or 1–3600; `restSeconds` null or 0–900; `targetLoadKg` null or 0–2000; notes ≤ 500 |
| `SCHEDULE_INVALID` | fixed: 1–7 pattern entries, distinct weekdays 1–7, every `workoutId` defined; rotating: 1–30 cycle entries all defined, `trainingDays` distinct 1–7, `cycleAnchor` ≥ 0 |

`PlanRules.Usable` (activation): every workout ID the schedule uses is defined and has at least one exercise. The builder
labels an unusable plan "Draft — add exercises to use it" and has no Activate button for it.

### Generating fixed occurrences (`PlanRules.FixedDates`, mirrored)

For week `w` in `0..durationWeeks-1` and each pattern entry ordered by its day offset from the start
(`(weekday − weekday(start) + 7) % 7`): `date = start + offset + 7w`, `weekNumber = w + 1`, `ordinal` = position
within that week (1-based), `workoutId` from the entry. Occurrence title and prescription are copied from the
definition (the occurrence's own snapshot, so later definition edits change only what the rules below say).

### Revising (`PlanRules.Revise`, mirrored on the phone so offline edits show the same result)

Input: existing occasions with eligibility (pending = not skipped, not credited, and no workout of any kind points at
it — so a finished no-data attempt keeps its occurrence and its link), the new definitions,
schedule, start, duration and the effective date `E`. Fixed mode:

1. `G` = generated occurrences (rule above) with `date ≥ E`, each with its deterministic ID.
2. For each `g` in `G`: if an occasion with that ID exists and is pending and not customised → take `g`'s workout,
   title, prescription, week and ordinal, **keep its scheduledDate** (a move survives). Exists but not pending, or
   customised → unchanged. Otherwise → added.
3. Pending, non-customised occasions with `originalDate ≥ E` and `scheduledDate ≥ E` whose ID is not in `G` → removed
   (the pattern no longer has them; one moved to before `E` is kept as it is). Legacy random-ID occasions fall in this group.
4. Pending, non-customised occasions with `originalDate < E` but `scheduledDate ≥ E` (moved forward past `E`) → content
   from their definition when it still exists; otherwise unchanged.
5. Everything else — recorded, skipped, open, before `E`, customised — keeps its content and dates. Completed
   workouts are separate rows with their own frozen exercises and are never touched by any plan command.
6. Ordinals (a display/sort key only) are renumbered within each week by `(originalDate, id)`, so kept and added
   occurrences never share one.

Rotating mode: definitions and schedule are replaced; materialized occasions are untouched; if the cycle changed the
phone sends `cycleAnchor` = its current next index, so the new cycle starts from its first workout.

A plan still in `draft` lifecycle is rebuilt in full (fixed: every occurrence regenerated from the new start; rotating:
none materialized). Every accepted revise increments the plan revision, which already turns open proposals into
"needs review".

## Compatibility decisions

- **Additive only.** New columns are nullable or default false; one new table (`CustomExercises`). No column is dropped
  or rewritten; legacy plans keep `SetupJson`, `BaselineId` and their occasions and stay startable, movable, pausable.
- **Older app builds** see new plans as ordinary plans: fixed ones fully (their occasions are real rows); rotating ones
  show only recorded sessions. The server refuses older commands that would rebuild a new-style plan from the old
  setup (`plan.draft.update` → `PLAN_NEEDS_NEWER_APP`), so an old build cannot erase definitions or schedules. The
  semantic hash of every older command is unchanged (new fields † are omitted when null).
- **`plan.draft` and baselines** stay on the server for older builds. The app no longer offers the old setup
  questionnaire; its fit-feedback screen is replaced by the template suggestion.
- **Exercise catalog update**: `api/src/GoHard.Api/Data/exercise-catalog.json` gains the movements the starters need;
  `seed-catalog` upserts by key, so it is idempotent and never deletes or renames a key in use.

## Phone-side model

- Local drafts: record kind `plan_builder` (`id = "new"` for a new plan, or the plan's ID while editing it). Saved on
  every change; never dispatched; survives restart and sign-out (owner-scoped). Saving a draft never creates a plan.
- Activate = `plan.create` (draft, writes the plan locally) then `plan.activate` (`after:` the plan), both queued, so a
  plan can be built and activated offline. If the create is refused the activation waits behind it and the sync review
  shows both versions; nothing is activated on the account.
- `plan_projection.dart` is the one projection used by Today, Train and the occurrence sheet: materialized occasions +
  locally started/credited rotating occurrences + projected virtual ones, with one status rule.

## Starter templates

Editable starting routines, not prescriptions. They contain no weights. Sets, rep ranges and rest follow the ACSM
position stand on resistance-training progression (2009): 2–4 sets; 6–10 reps for the main compound lifts with
about 2–3 minutes' rest; 8–15 reps for accessories with 60–90 seconds. A 2024 systematic review and meta-analysis
(PubMed 38595233) found no significant difference between split and full-body training in strength or hypertrophy
when weekly volume was matched, so the app suggests a structure by availability and never calls one split best.

**Where legs go in Push / Pull (including legs)**: Push days carry the knee-dominant leg work (squat, leg press,
split squat, leg extension); Pull days carry the hip-dominant work (Romanian deadlift, deadlift, hip thrust, leg
curl). Calves and core can sit on either.

Equipment variants are produced by a deterministic swap table in the template file (full gym → dumbbells →
bodyweight); a swap that would repeat an exercise already in that workout is dropped.

| Template | Sessions | Definitions |
|---|---|---|
| Full Body | 2 (A, B) or 3 (A, B, C) | Full body A/B/C |
| Upper / Lower | 4: Upper A, Lower A, Upper B, Lower B (2–3 days: rotating) | 4 |
| Push / Pull / Legs | 3, or 6 by repeating the three | 3 |
| Push / Pull (legs included) | 4: Push A, Pull A, Push B, Pull B (2: Push A, Pull A) | 4 |
| Upper / Lower + Push / Pull / Legs | 5 | 5 |
| Body-part split | 5: Chest, Back, Legs, Shoulders, Arms | 5 |
| Custom | any | the user's own names |

Suggestion by available days: 2–3 → Full Body; 4 → Upper / Lower; 5 → Upper / Lower + PPL; 6–7 → Push / Pull / Legs
twice. When the chosen day count differs from a template's sessions the builder proposes the rotating sequence over
those days instead of dropping a workout.
