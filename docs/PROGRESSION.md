# Workout progression: next targets from recorded sessions

Added 20 Oct 2026 on `feature/workout-progression` (from `main` at `4871cc2`). It links what was recorded to an
optional target for the next session of the same plan workout. It is an addition to the workout workspace, the
result and the preview; it does not replace recording, and it never records a set.

Three things stay apart everywhere:

| Word | Meaning | Where it comes from |
|---|---|---|
| **Target** | what you intend to lift | the plan (frozen into a workout when it starts) |
| **Last time** | what you recorded before | earlier finished workouts |
| **Today** | sets actually recorded in this workout | this workout's sets only |

## Technical note (written before implementation, kept as built)

**Where an accepted target lives.** The plan already carries an optional `targetLoadKg` on each exercise of a workout
definition (`Plan.workouts[].exercises[]`, `PrescriptionExercise`), keyed by plan, definition ID and the exercise's
stable `occurrenceKey`. That is exactly the scope asked for (account → plan → workout definition → exercise
occurrence). It survives renaming and reordering, and the builder's *Replace exercise* removes it and gives the new
exercise a new `occurrenceKey`, so a target and its evidence can never move to a different movement. Accepting a
target writes that field (and sets/reps only when the user edited them) through the existing revision-checked
`plan.revise` command, built from `PlanDraft.fromPlan` with the effective date today
(`PlanRepository.setNextTarget`). No new target model, table or setting.

Consequences, all from rules that already exist (docs/TRAINING_PLANS.md › Revising):

* Fixed plans: pending, non-customised occurrences dated today or later are regenerated from the definition, so the
  next one carries the new target. Recorded, skipped, open, earlier (missed) and individually edited occurrences keep
  theirs. A plan edit open in the builder is kept (not discarded); it is told the plan changed when it is saved.
* Rotating plans: projected occurrences are built from the definition; the cycle anchor is unchanged, so nothing
  advances and nothing is credited.
* A started workout keeps the exercises frozen into it at Start; historical workouts and their sets are never touched
  by any plan command.
* Preview, Today, Train and Start all read `planOccasions`, and `startPlanned` freezes `occasion.prescription`. The
  server stores what the start sends (`WorkoutService.StartAsync` validates ranges only; it does not recompute the
  prescription), so the preview and the started workout agree on both sides.
* Restore previous target is another `plan.revise`. It is offered only while the definition still holds the accepted
  value (`TARGET_CHANGED_SINCE` otherwise), and the account's plan-revision check sends an edit made on another phone
  meanwhile to the existing sync review (titled "Plan change"); nothing is overwritten.
* Saving the same values again (a double tap, reopening and confirming) queues nothing: `setNextTarget` returns null.

**Equipment increments** are per account and per exercise identity (catalogue key or `custom:<id>`): the same
movement usually uses the same plates or stack wherever it appears. They are not a plan field and not settings JSON:
a typed record `ExerciseIncrement` (`UserId`, `ExerciseKey`, `IncrementKg` numeric(9,5) or null = cleared,
`Revision`), command `exerciseincrement.put` (`PUT /exercise-increments/{key}`, `{operationId, expectedRevision,
incrementKg}`; 0 creates; above 0, at most 50 kg, at most 5 decimals; unknown or someone else's exercise →
`UNKNOWN_EXERCISE`), snapshot list `exerciseIncrements`, additive migration `AddExerciseIncrements` (one new table,
cascade-deleted with the account), capability `exercises.load-increment`. On the phone: record kind
`exercise_increment`, the outbox, and the sync review's "Weight increment" entry with Keep mine. No increment is ever
preselected.

**Dismissals and accepted history** are a local-only record kind `progression` (id `planId|workoutId|occurrenceKey`):
`dismissed` holds the fingerprint of the evidence a suggestion was kept-as-is against; `previous`/`accepted` hold the
target an accepted one replaced, for Restore. A corrected set changes the fingerprint, so a recomputed suggestion can
come back; the same facts never do. These are not synced: on another phone a declined suggestion can be shown once
more, and Restore is offered only on the phone that accepted (edit is always available).

## Suggestion rules (`features/workout/progression.dart`)

A pure function with structured results and reason codes, on the phone, from local records. No request, no AI,
works offline. These are **GoHard product rules, not a clinically validated algorithm**.

| Decision | When | Shown as |
|---|---|---|
| `unsupported` | timed, bodyweight (catalogue/own equipment) or assisted (key or name), or no stable identity | manual targets only |
| `setBaseline` | no positive load target, or no set count and rep range | Set a target (load field empty; *Use last recorded load* fills it on request) |
| `moreSessions` | fewer than two comparable sessions on the current prescription, or the newest is on another one | explanation only |
| `keepCurrent` | two sessions on the current prescription, and not both qualify | explanation only |
| `configureIncrement` | both qualify, no increment saved | Choose your weight increment |
| `incrementTooLarge` | both qualify, increment > 5% of the target (product guard, not a safety threshold) | review manually |
| `increase` | both qualify: proposed = target + one increment (rounded to the gram) | Next time card, Review next target |

**Comparable sessions**: finished workouts that count as training (full or partial; not deleted, open, no-data or
manual), started from the same plan and the same workout definition (via the occasion's `workoutId`), newest first.
**Only the newest two are judged**: an older success is never reached past a newer session that did not qualify.

A session qualifies when its exercise with the same `occurrenceKey` and identity exists, is prescribed and not a swap,
its frozen prescription has the same load, set count and rep range as the plan's current one, the workout is not
partial, exactly the planned number of sets is recorded (fewer: incomplete; more: ambiguous, since warm-ups are not
marked), every set has a known load equal to the target (a missing load is unknown, never zero) and reps at or above
the top of the range. Sets awaiting conflict review and deleted sets are left out.

Never: estimating a one-repetition maximum, inferring effort, form, pain or recovery from reps, lowering a weight,
adding sets, changing reps, replacing exercises, rewriting the split.

The approved mockup's previous session (10/9/8) would not qualify under this rule; the tests and fixtures use
complete sessions instead of weakening the rule (`progression_test`, "a more recent session that missed the top…").

**Units**: kilograms are canonical. A target typed in pounds is converted once (`loadInputToKg`, then rounded to the
gram, the account's precision for sets); an increment is converted once and kept to 5 decimals, so 190 lb + 5 lb
shows exactly 195 lb. Changing the unit never changes the stored target or increment.

## Where it appears

* **Recording** (selected exercise panel): *Target in this workout* (the frozen one), then *Next target · 195 lb* with
  Review / Review suggestion, or *No next weight target* with *Set a target*. Shown only while the exercise is still in
  the plan workout it was started from. Opening it is a sheet over the recorder: the selected exercise, typed entry,
  recorded sets, workout ID, rest and clock stay as they were (tested). *Use last values* and Record set are unchanged.
* **After Finish**: the workout is saved first, by the existing finish flow; the result then shows a compact
  **Next time** section for the suggestions this workout produced: one pale panel card (exercise, current and proposed
  target, sets and range, a factual sentence, *Review next target* / *Keep current target*), and one row per further
  exercise. The coach (the selected Leon/Leona, inline `CoachSpot`, introduced once per account, respecting hints,
  Reduce Motion, keyboard and visibility) says the fact and offers *How progression works*.
* **Later**: the same section in the preview of that plan workout's next occurrence (not on an occurrence edited on
  its own), and *Review target* / *Set a target* in each expanded exercise row.
* **Review next target** (sheet): workout and plan, current target, the reason, the actual sessions, the suggested load
  in the person's unit, editable weight / sets / rep range (plan validation ranges), the increment, the scope
  ("Applies from the next time you start Push, until you change it…"), *Use 195 lb from next session* and *Keep
  current target*. After saving: the accepted state with *Edit next target* and *Restore previous target*.
* **Choose your weight increment** (sheet): kg 0.5 / 1 / 1.25 / 2 / 2.5 / 5 or lb 1 / 2.5 / 5 / 10, or another value;
  none chosen until tapped. It explains that GoHard keeps a load exactly as recorded (the app has no per-dumbbell or
  total-load convention of its own), so the step follows the person's own convention: per hand if they record dumbbells
  per hand, the total bar change for a barbell. On a server without the capability it says the value is kept on this
  phone until the server is updated.
* **How progression works** (sheet): the rules above, their limits, and the sources below.

## Sources

| Source | What GoHard takes from it |
|---|---|
| ACSM position stand 2026, Currier et al., *Resistance Training Prescription for Muscle Function, Hypertrophy, and Physical Performance in Healthy Adults: An Overview of Reviews*, MSSE 2026;58(4):851–872, https://doi.org/10.1249/MSS.0000000000003897 (PMID 41843416, PMC12965823; full text read 20 Oct 2026) | Conclusions: "Healthy adults should perform progressive RT". Discussion: "progression is not necessary to achieve beneficial outcomes, and overload, or more accurately, increasing the stimulus in some manner, is likely a requirement only for those seeking continued longer term progress." Used for the help's framing only |
| ACSM position stand 2009, *Progression models in resistance training for healthy adults*, MSSE 2009;41(3):687–708 (audited in docs/COACH_SOURCES.md) | "2–10% … increase in load … when the individual can perform the current workload for one to two repetitions over the desired number on two consecutive training sessions" |
| **GoHard's own rules** | the top of the range (not 1–2 reps over it) in the newest two sessions, one user-confirmed increment, the 5% guard, no automatic decrease. Neither paper tests or validates this algorithm |

## Compatibility

* **Targets** need nothing new from the server: `targetLoadKg` and `plan.revise` exist on the hosted API, and older
  app builds already read and keep the field. An older build's plan edit sends the definition as it holds it, which
  includes the field.
* **Increments** need `AddExerciseIncrements` and `exercises.load-increment` on the server. Against an older server the
  phone never sends one (`ProgressionRepository.serverTakes`, like weekly goals): it waits in the outbox with the
  existing pending wording. Older clients never send the command, so they cannot erase an increment; the snapshot list
  is absent from an older server and ignored by an older client. Erased with the account (FK cascade).
* **Hosted**: the hosted testing API needs a deploy of this branch's migration (Railway deploys `main`) before
  increments sync for hosted accounts. Until then, targets sync and increments stay pending on the phone.
* `verify-api.ps1` checks increments when the server declares the capability (saved, retried once, stale refused,
  cleared) and says SKIP otherwise.

## Tests

`progression_test` (8, rules), `progression_sync_test` (3, real Drift file + fake account: offline restart, one
command per confirmation, next start freezes the accepted target, started and recorded workouts unchanged, other
workouts untouched, revision conflict kept for review, increments isolated per account, conflict review, older-server
gate), `progression_ui_test` (2: preview + Keep current saves nothing and hides the same suggestion; a double tap
saves once; entry, selection and workout survive; only Record set records; 320 px at 2× text), API
`ExerciseIncrementTests` (1), native `journey_progression_test` (not in the default run; two phases).
