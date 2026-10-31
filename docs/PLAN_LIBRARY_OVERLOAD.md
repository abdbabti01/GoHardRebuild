# Saved plans, activation, and "Suggested today"

Added 31 Oct 2026 on `feature/plan-library-overload` (from `main` 5441d2a). Written before implementation and kept
as built. It extends the plan builder (docs/TRAINING_PLANS.md), progression (docs/PROGRESSION.md) and the Plus
preview (docs/PLUS_PREVIEW.md); it adds no new plan model, table, command or migration.

Out of scope: sharing plans, recipients, several people's profiles, coaching clients, payments.

## 1. Draft, saved plan, active plan

| Word in the app | What it is | Stored as |
|---|---|---|
| **Unfinished plan** (draft) | the builder's work in progress | local record `plan_builder` (`new`), never sent, not a plan |
| **Saved plan** | a complete plan, never activated, ready to use | a plan on the account with `lifecycle = "draft"` |
| **Active plan** | the one that gives the personal schedule | `TrainingContext.primaryPlanId` + `lifecycle = "active"` |
| Paused / finished | a plan that *was* active | `lifecycle = "paused"` / `"closed"` |

The distinction is derived from existing state: the server already creates every new plan in `draft` lifecycle
(`plan.create`), and only `plan.activate` turns it active. A saved plan has never been active, so it is never shown
as paused. Only words change: the app said "Draft" for that lifecycle; it now says "Saved · not active".

Only the primary plan feeds Today, Train's schedule, adherence and the rotation (`dailySnapshotProvider`,
`primaryPlanProvider`). A saved plan's own occurrences (fixed plans get dated ones at creation) are never shown on
Today, never missed and never credited, because no workout can be started from a plan that is not active
(`canStartOccasion`, server `PLAN_NOT_ACTIVE`).

## 2. The builder's Review step (new plan or duplicate)

* **Save and activate** (primary): the existing `plan.create` then `plan.activate`, both queued (works offline). With
  another plan active, the existing confirmation explains it is paused, not deleted. Cancel leaves everything as it
  was, the unfinished plan included.
* **Save plan**: `plan.create` only. The current plan, its schedule, rotation and adherence are untouched (no command
  touches the context). The unfinished plan is cleared once the plan is saved on the phone. Train › Plan shows it
  under Saved plans.
* **Save draft**: unchanged (kept on the phone, nothing created).
* Edit keeps **Save changes**.

Save and activation are separate commands with separate operation IDs. If the save is accepted and the activation is
refused (another device activated something meanwhile), the plan stays saved; the sync review explains it and the
plan's page offers **Activate** again: the same plan ID, a new activation command, never a second plan.

### Activating a saved plan (Train › Plan › a saved plan)

The existing review page (`PlanReviewScreen`), now with Edit, Duplicate and Archive beside Activate. Activation rules
are unchanged (reviewed start and dates, one active plan, replacing asks and pauses the other, open workouts stay
open). New guard: a **fixed** plan whose start date has passed is not activated as it is (its first dates would be
missed at once); the page says so and offers Edit to choose a new start. A rotation projects from today, so its
start date never blocks.

## 3. Free and Plus: saved plans

| | Free | Plus (preview) |
|---|---|---|
| Saved plan definitions | **1** (`Plus:FreeSavedPlans`, default changed 3 → 1) | technical cap only (`Plus:MaxSavedPlans`, 200) |

**Counted**: every plan on the account that is not archived, any lifecycle (saved, active, paused, finished) — the
rule the server already applies (`EntitlementService.PlanRefusalAsync`). **Not counted**: the builder's unfinished
plan, archived plans.

**Limited** (the only operations that add a counted definition): Save plan / Save and activate for a new plan or a
duplicate (`plan.create`), Continue this plan (`plan.continue`), older builds' `plan.draft`, and — new — **moving a
plan out of the archive** (`plan.archive` with `isArchived: false`), which would otherwise be a way round the limit.
**Never limited**: editing, activating or switching between existing plans, pausing, resuming, starting and recording
workouts, archiving, reading history. Plans over the limit after this change stay readable, editable and usable;
nothing is hidden, archived or deleted.

At the limit, the attempted save shows the existing limit sheet (now worded for one plan) with View Plus and Back;
the unfinished plan stays as it is. Unknown entitlement: creating is allowed only while the account has no counted
plan (`Entitlement.minimumPlans` 3 → 1); otherwise the existing "couldn't confirm" sheet.

**Offline / two phones**: the phone may queue a save while it believes there is room; the server decides. A refused
`plan.create` (`PLAN_LIMIT`) appears in the sync review, explained in words, with **Keep as unfinished plan**: the
plan's content goes back into the builder as the unfinished plan (if none is open there), the refused command and an
activation waiting behind it are withdrawn, and the account's state is read again. Nothing waits forever and no work
is lost. Remove from phone stays available.

## 4. Train › Plan

Order: the active plan (unchanged), then **Saved plans** (lifecycle `draft`, not archived; each row: name, schedule
kind and workouts, "not active"), the **unfinished plan** row when there is one, and **Create plan**; then **Paused and
finished** (paused, closed); then Archived. A row opens the plan's page; Activate is an explicit button there, never a
side effect of opening or editing.

## 5. Suggested today (in the recorder)

Four things stay apart in the selected exercise:

1. **Plan** — the prescription frozen into this workout (`3 × 8–12`, target weight if any).
2. **Last session** — the existing Last time table (actual sets).
3. **Suggested today** — optional, Plus, new; a small panel below Last time.
4. **Today** — the sets recorded in this workout (the existing Today column and list).

### Rules (`ProgressionRules.today`, pure, local, no AI)

Comparable sessions are exactly those of the existing next-target rules: finished workouts that count as training,
from the same plan and the same plan workout (occasion → `workoutId`), the same exercise occurrence
(`occurrenceKey`) and identity, as planned (not a swap). Compared against the prescription **frozen in this
workout**.

1. **Unsupported** (no suggestion, plan guidance only): timed, bodyweight, assisted, no identity, an added or
   replacement exercise, or no set count and rep range.
2. **Weight**: the existing two-session rule unchanged (docs/PROGRESSION.md). `increase` → "Try 195 lb today and
   aim for your planned 8–12 reps" (the reps are not raised at the same time). `configureIncrement` → no weight is
   invented; the panel offers the existing increment editor. `incrementTooLarge` → no weight suggestion.
3. **Reps**, only when the weight rule does not apply, from the **newest** comparable session alone (an older one is
   never reached past it). It qualifies when its frozen set count, rep range and target weight are the ones in this
   workout; the workout was not partial; exactly the planned number of sets was recorded (fewer: missed; more:
   ambiguous); every set has a known, positive and identical weight, equal to this workout's target weight when there
   is one; every set's reps are within the range; and the total is below the top of the range on every set. Then:
   "Keep 45 lb and aim for one more rep across your sets (27 → 28 in total)". It never sets reps per set.
4. Anything else (no history, inconsistent or changed): no personalised suggestion. The plan and Last time stay.

Never: estimating a maximum, inferring effort, technique, pain, fatigue or readiness, lowering anything, treating an
assisted load as progress, deciding whether a dumbbell weight is per hand.

### Actions

* **Use suggestion** fills this set's entry only (session only): weight → the load field; reps → the load field with
  the kept weight (reps stay the person's to enter, the aim stays visible). Typed values are replaced only after the
  existing confirmation. It records nothing, starts no rest, writes no command and changes no target; the selected
  exercise, other drafts, recorded sets, rest and clock are untouched. A second tap with the same values does nothing.
* **Keep my targets** hides the suggestion for this exercise for the rest of this workout (stored in the workout's
  local runtime, so it survives a restart). Nothing else changes.
* **Edit** opens the existing next-target review (plan from the next session, revision-checked `plan.revise`) — the
  only way a suggestion can change the plan. The frozen targets of this workout never change.
* **Why this suggestion?** — the rule in words and the sessions it used, with GoHard's limits ("GoHard only sees what
  you recorded"). The selected Leon/Leona speaks only through the existing help sheet; nothing new floats over the
  recorder.

Recording fewer or more reps, other weights, extra sets or a replaced exercise is never blocked, warned about or
counted against anything. After Finish, the existing **Next time** card is unchanged and is computed from the same
rules, so it never contradicts what was suggested (using a heavier weight today makes the plan's two-session rule
start again at the new weight).

### Free and Plus

Previous sessions, plan ranges, manual targets and recording stay Free. Suggested today is Plus (feature
`progression.suggestions`, already used by Next time). Free sees one quiet line ("Suggested today is part of GoHard
Plus · Learn more") on supported exercises with history; unknown entitlement shows nothing; nothing ever opens on its
own. A downgrade changes nothing recorded or already accepted.

## Data and deployment

* No migration, no new capability, no new table or command. Client-only: runtime key `suggestions`
  (`{exerciseId: "kept" | "used"}`) inside the existing local `workout_runtime` record.
* Server: `Plus:FreeSavedPlans` default 1; `plan.archive` refuses un-archiving past the limit (`PLAN_LIMIT`).
  Takes effect on the hosted API only after a deploy of `main`; if Railway has `GOHARD_Plus__FreeSavedPlans` set,
  that value wins.
* Older app builds: they keep working; at the new limit their Activate shows their existing limit wording.
