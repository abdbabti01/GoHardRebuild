# Repeat and copy meals; the workout exercise panel

Added 18 Nov 2026 on `feature/meal-copy-workout-panel` (from `main` 009bae6). Written before implementation and kept
as built. App only: no API, migration, capability, contract or sync change.

## 1. Repeat yesterday's meal, copy any meal

Built on what exists: the journal (`FoodEntry` snapshots), `FoodRepository.logMeal` (one `food.batch` command, one
operation ID, written locally with its command in one transaction), the amount form in selection mode
(`FoodFormScreen(pick: true)`), recipe portions from their frozen batch (`MealMath.portion`), and Eat's meal groups.

**Same as yesterday?** An empty meal group on the day shown in Eat offers a compact line when the same meal on the
calendar day before *that* day (not the phone's yesterday) has food: "Same as yesterday?" (or "Same as Mon, Nov 16?"
when the day shown is not today), the foods' names in their logged order, **Review & log** and **Other days**.
Deleted entries never count; water is a separate record kind and is never a food entry. Only that one meal on that
one day is the source: nothing is combined across days. No source → the ordinary empty group.

**One entry point per meal group.** Where the group shows Same as yesterday, the usual-meal suggestion
(docs/MEAL_HABITS_REMINDERS.md) is not also offered for that meal; **Other days** lists that meal on the last 14
days that have it (each one day's meal, never a mix), with Saved meals & recipes and Add food beside them.

**Copy meal** sits in a meal group's footer with Save as meal (the existing quiet secondary action). It opens the
same review.

**The review** (`MealCopyScreen`) always shows *Copy to* — date and meal — at the top, editable; changing them
records nothing. Defaults: Same as yesterday → the day and meal shown; Copy meal from an earlier day → today, same
meal; from today → today, the meal of the time of day. Dates follow the existing rule (up to tomorrow). Then:

* same date and meal as the source: a warning that this adds the same foods again (allowed: people do eat twice);
* destination already has food: "These are added; nothing there is replaced";
* the foods in source order, each changeable (amount form, or a portion of the frozen batch for a recipe), removable,
  and Add food (selection mode); known/unknown totals as everywhere else;
* **Log this time** is the only action that records anything. Back records nothing.

After logging, a snackbar names the destination and offers **View**, which shows that day in Eat.

**Exact copies.** A copied draft carries the entry's own snapshot and provenance (`FoodDraft.kept`) and is written
as logged: name, amount words, exact values (unknown stays null, entered stays entered), food identity, basis,
portions, attribution, quantity and unit, a recipe's whole frozen batch, yield, weight and partial sums. Nothing is
looked up again. Changing one food's amount drops `kept` for that food only and goes through the ordinary scaling
from its own snapshot (a recipe portion: from its frozen batch, never the recipe as it is now). An entry typed by
hand has no food to scale: the review says so and offers Keep, Remove or **Choose a food instead** (explicit; never
a silent substitute). Each copy gets fresh entry IDs; the source entries are never written.

**Once, and again on purpose.** One operation ID per review: double taps and lost-response retries log it once
(`FoodRepository._once`); a later review is a new operation and logs again. Offline, the batch survives restarts in
the outbox and is sent once. Copying is logging: no saved meal is created or changed, and the saved-meal limit is
never consulted.

## 2. The workout exercise panel

Same recorder (`WorkoutRecorder`), same runtime, repository, drafts, serialized selection, rest and progression
rules. Only the arrangement of the selected exercise changes, top to bottom:

1. **Header** (photo panel, unchanged style): "Exercise 2 of 6", the name, one plan line "3 sets · 8–12 reps ·
   90 s rest" with the target frozen into this workout ("· target 45 lb"), About.
2. **Last session · date** — one panel with Set | Last session | Recorded today (set by set, every previous set
   with its own load; extra rows show "—" for last session, never a copy of another set), the row being entered
   marked "Entering". Stacked per set at large text. All sessions. **Today's aim** sits inside the same panel when
   the existing rules (Plus) give one: Use 47.5 lb / Keep this aim / Keep my targets / Edit future targets / Why?.
   No comparable session: "First session on record: nothing to compare yet." in the same place.
3. **Set 2 of 3** (or "Extra set 4"): the matching last-session set beside it with Use last values, weight and reps
   (or time), **Record set**, and the rest timer as one compact row directly under it while it runs; Next exercise.
4. **Recorded sets** (edit through the existing dialog), then **Next target** (future plan target, quiet), All
   movements, Finish, Save for later.

Removed duplication: the separate "Target in this workout" tile (now in the plan line) and the separate Suggested
today card (now inside the history panel). Free: history, manual targets and recording unchanged; the quiet Plus line
stays inside the panel; nothing opens by itself.

What each aim action changes (fills this set's weight only; Edit future targets changes the plan from the next
session) is said in **Why?**, so the panel stays short. With large text the weight and reps fields stack.

Fit, measured with the app's real fonts at 390 px (`progression_ui_test`): header to Record set is 647 px without an
aim (fits between a 390 × 844 phone's status bar and tab bar) and 834 px with an aim and its four actions (one short
scroll). Not built: a live preview of typed values in the comparison (the entering row is labelled instead).

## Verification (18 Nov 2026)

* `meal_copy_test` (7), `meal_copy_ui_test` (3), one new `progression_ui_test` case; affected suites re-run file by
  file (23 files: Eat, meals, habits, water, trends, eating out, food, Today, workout panel, progression, plans, theme,
  l10n, widget) all passed.
* Renders (Flutter widgets with FIXTURE data, not phone captures): `docs/evidence/meal-copy-workout-panel/{before,after}`
  — Eat and the recorder at 390 × 844 in light and dark from `main` 009bae6 and from this branch with the same file
  (`meal_copy_workout_render_test`); after only: the copy review light/dark and at 320 px with 2× text, the recorder at
  320 px with 2× text.
* **Not run:** the emulator journey `integration_test/journey_copy_panel_test.dart` (written and analyzed): the local
  development database's migration history is unknown to the rebuild, so `setup.ps1` refuses to migrate it and the API
  answers 503. Repairing it would mean dropping that local database, which was not done.
* **Not verified on a device:** everything above on an iPhone, VoiceOver.
