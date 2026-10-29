# Meal habits, reusable meal amounts and reminders

Brief: meal-habit suggestions, clearer saved-meal quantities, and optional reminders (29 Oct 2026). Principle:
**GoHard learns and suggests; the person always chooses.** Nothing is logged, scheduled or changed by itself.

Built on what was already there: the journal (`FoodEntry` snapshots), saved meals and recipes
(`features/nutrition/saved_meals*.dart`, docs/FOOD_DATA.md › Saved meals and recipes), Help with today
(`features/coach/day_coach*.dart`, docs/COACH.md › Help with today), the workout reminder scheduler
(`features/me/reminders.dart`) and the coach bubble (`coach_bubble.dart`).

## What existed and what was added

| Area | Already there | Added |
|---|---|---|
| Saved meal review | Per-food amount edits, add/remove foods for this time, ½×–2× and custom multipliers, recipe servings and grams of a weighed batch, Update saved meal (confirmed), Save as new, Log | "Log this time" label, "Save as a variation" (own name dialog), a note saying what each action changes, Save as meal for a usual meal that is not saved, a starting list of foods (`initialParts`) |
| Coach | Typed requests → checked intent → review | One food of a saved meal at another amount this time (`ingredient`) |
| Reminders | Workout reminders (Me switch + time), one scheduler that replaces everything | Me › Reminders (one page), meal / medication / supplement reminders, confirmations, Eat link |
| Habits | — | Local detection, Eat suggestion, Me › Meal suggestions |

## Habits (`features/nutrition/meal_habits.dart`, pure)

Worked out on the phone from the account's own journal, deterministically; no AI and no server call.

- **Window:** the 28 days before today. Today never counts as evidence for itself.
- **Evidence:** one meal (Breakfast, Lunch, Dinner, Snack) on one day = one combination: every food logged at that meal
  that day. Several entries on one day are one day of evidence.
- **Identity:** each food needs a stable identity: its provider/catalog source and ID plus the kind of unit (grams,
  millilitres, a serving), or the recipe it came from. A hand-typed entry has none, and a day with one is not evidence.
  Names are never compared: two products called "Egg" are different foods.
- **Habit:** the same combination on at least **3 distinct days**, the last within **14 days**. Ties go to the most
  recent. An old habit therefore stops by itself; edits and deletions are seen at once (the journal is read as it is).
- **Amounts:** those of the most recent day of that combination, exactly as logged. Nothing is averaged and no unit is
  converted.
- **Never fabricated:** foods from different days are never combined. A saved meal that was never logged suggests nothing;
  a saved meal with exactly the same combination is the one reviewed (with its Update saved meal / Save as a variation).

### On Eat

Only when suggestions are **on**, only for **today** (an earlier day shown is never greeted as "now"), for the meal of the
time of day (before 11:00 Breakfast, before 16:00 Lunch, before 21:00 Dinner, else Snack, as elsewhere in Eat), and only
while that meal has nothing logged today and was not set aside today. Leon/Leona says "Your usual breakfast? Review it or
choose something else. Logged at breakfast on 4 recent days." with three choices:

- **Review usual meal** — the ordinary review; only its Log this time records food.
- **Choose something else** — Add food on that meal (search, favourites, saved meals all one tap away).
- **Not today** — no suggestion for that meal today.

With the coach hidden on Train and Eat, the same three choices appear in a compact pale panel under the day's summary.
Log food, Saved meals and every meal's Add food are unchanged.

### Choosing

Off until chosen. Me › Personal › **Meal suggestions** explains the feature and has the one switch; the coach asks once on
Eat (when the journal has at least 3 recent days) with **Turn on** / **Not now**. Turning it off removes nothing from the
journal or the saved meals. The choice and the Not today list are stored on this phone for this account
(`Kinds.habit`, local only).

## Saved meal amounts

The review (`MealReviewScreen`) keeps three separate actions:

- **Log this time** (main): logs the amounts shown as ordinary entries; the saved meal is not changed.
- **Update saved meal**: replaces the definition's amounts after a confirmation (and a second one if it changed on
  another phone).
- **Save as a variation**: a new saved meal with its own name; the original stays.

Logged entries are copies (snapshots), so editing or deleting a saved meal never changes anything already logged.

### "My chicken meal, but with 150 g of rice today"

`POST /coach/daily` may now return `portion.ingredient`: the food's name exactly as the person wrote it, only on a
portion of a saved meal (dropped otherwise, at most 60 characters, treated as data). The phone then:

1. matches it against that meal's own foods: every word must be a word of the food's name (case, accents, plurals
   ignored). Several matches → "Which food in My chicken meal?" with one button each; none → says so and offers the
   meal as saved.
2. applies the person's amount to that food only: grams only if the food has a weight, servings only if it has a
   serving, a factor of its own amount. Otherwise it says the unit does not fit; it never swaps units.
3. shows a card with the meal's values from the changed foods (MealMath / NutrientCoverage: unknown and partial stay
   labelled), and **Review** opens the ordinary review with that food changed. If the saved meal changed since, the
   review is not opened ("recalculate"). Only the review's Log this time records food.

Older servers do not send `ingredient`; the phone then reads the request as before (grams of a meal → "cannot measure
that in grams"). No capability or migration was needed: the field is additive.

## Reminders (`features/me/reminders.dart`, `reminders_screen.dart`)

**Me › Reminders** is the one destination: workout reminders (moved here from Me › Preferences, same profile fields),
and the person's own meal, medication and supplement reminders. Eat links to it ("Meal reminders" under the meals) and
the coach may offer a meal reminder once (below).

Each reminder: name, category, meal (meal reminders), time, weekdays, on/paused, optional instructions, and **Hide
details on the lock screen** (on by default for medication and supplements: the notification says only "GoHard
reminder" / "Open GoHard to see it", and Android marks it private). Nothing is enabled automatically; notification
permission is asked only when a reminder is saved on or switched on. A refusal keeps the reminder, says so, and the page
shows "Notifications are off…" with **Open phone settings**.

### Suggested meal times

The phone records, per meal and day, the minute the meal was **first logged on that day itself**
(`Kinds.logTime`, local). An entry logged for another day records nothing, so backdating is never evidence of an eating
time. A time is offered ("You often log breakfast around 9:00. Use that time?") only with at least **4 days** in the
window whose entries still exist, at least three quarters of them within **45 minutes** of the median; it is rounded to
the quarter hour. Otherwise the editor just asks for a time. **Choose my own time** is always there, a suggestion is only
for a new reminder, and nothing learnt ever changes an existing schedule.

Medication and supplement reminders: the person writes the name, time, days and any instructions. GoHard never
suggests a dose, a treatment or a schedule, never infers one from meals, and never adjusts one. No AI is involved.

### Storage and privacy

Reminders (`Kinds.reminder`) and answers (`Kinds.reminderLog`) are **local records on this phone for this account**,
like other local-only kinds: they survive restarts, are invisible to another account on the phone, and are never sent to
the account, to Groq or to any AI. They are deliberately not synced: delivery is per device anyway (no surprise
notifications on every signed-in phone), and medication details stay off the server. The cost: a new phone starts with
no reminders, and answers are not visible on another device. Workout reminders keep their existing account fields.

### Scheduling

One provider (`reminderSyncProvider`) works out the whole list and hands it to `DeviceReminderScheduler.replaceAll`,
which cancels everything GoHard scheduled and schedules exactly that list, one replacement at a time (a newer one
abandons an older one). It runs on start, on app resume, and whenever the plan, a reminder, an answer, today's journal,
the day or the language changes. So repeated taps, restarts, sign-in, edits and pauses can never duplicate
notifications. Signing out (or another account signing in) schedules nothing for the previous owner.

- **Horizon and limit:** the next **7 days** of each reminder, plus workouts, at most **60** notifications (iOS keeps 64
  per app). When the limit cuts later days, the latest whole days are left out and the page says "Scheduled through
  <date>"; opening GoHard schedules the following days. A phone not opened for a week stops reminding after that horizon.
- **Local time policy:** a time is a wall-clock time in the zone the phone is in when scheduling. After travel or a
  zone change it is re-timed on the next resume. On the day clocks go forward, a time in the skipped hour fires just after
  the change (02:30 → 03:30); when a time happens twice (clocks go back) it fires once, at the first.
  (`noticeTime`, tested with America/Toronto.)
- **Delivery:** Android uses inexact alarms (no exact-alarm permission), iOS schedules local notifications; the OS
  decides the exact moment and may deliver late or batch. Nothing calls a server or an AI when a reminder fires.
- **Meal suppression:** a meal reminder for today is removed as soon as that meal is in today's journal on this phone —
  offline entries included, and it comes back if the entries are deleted — whenever the app is running or next opened.
  **Limitation:** a meal logged on another device, or while GoHard has not run since, cannot cancel an already scheduled
  notification in the background; it will still appear.

### Confirming medication and supplements

Each occurrence has an identity (`reminderId|day|time`). The notification has **Taken**, **Snooze** and **Skip**
buttons; each opens GoHard (nothing is recorded in the background), records that answer for that occurrence and shows
Reminders. Tapping the notification itself opens the confirmation sheet for that occurrence; opening or dismissing it
records nothing. Me › Reminders › Today lists today's occurrences with their state.

- One record per occurrence: the same answer twice is one record; a later answer replaces an earlier one.
- **Snooze** (10 minutes) adds one extra notification for that occurrence only; the recurring schedule and tomorrow are
  unchanged.
- No answer is **Unconfirmed**, never "not taken".
- A notification of another account (signed out since) is ignored.
- iOS button titles are set when GoHard starts; after a language change they follow at the next start.

## Coach (Leon / Leona)

Fixed words chosen on the phone; no AI request because a screen opened or a reminder fired. On Eat (today only, in this
order, each once where marked): the usual meal; the offer to turn suggestions on (once); "You often log lunch around
12:30. Want a reminder to log it?" with **Add a reminder** (once, only when the times support it and that meal has no
reminder). The usual meal follows its own setting; the introductions follow Coaching hints; the coach's visibility and Reduce Motion apply as for every other bubble; the bubble sits under
Eat's title, never over a form or the keyboard. The coach never says something was eaten or taken. Phone notifications
are ordinary system notifications; the animated guide never appears in them.

## Verification

- Unit (`test/meal_habits_reminders_test.dart`, 16): habit eligibility (distinct days, today excluded, deletions, typed
  foods, look-alike names, unit kinds, unrelated foods never combined, fading), latest amounts, saved-meal match, usual
  log time and backdating, log-time recording on the real local database, the ingredient change (match, values,
  definition untouched, stale detection, ambiguity, unknown, unit mismatch, no amount), reminder planning (paused,
  weekdays, past times, horizon, meal suppression, answered/snoozed occurrences, stable IDs, private wording, budget),
  DST, answers idempotent / per account / surviving a restart and a pull / never sent.
- Widget (`test/meal_habits_reminders_ui_test.dart`, 3): Eat's three choices and reason, review logs nothing, no
  suggestion on an earlier day or when off; Reminders, the confirmation sheet and the editor at 320 px with 1.6× text in
  Arabic (RTL) and French, refusal explained, suggested time beside Choose my own time, no suggestion for an existing
  reminder.
- API: `DailyCoachTests` (ingredient kept as data, dropped on another kind or when too long).
- **Not verified:** real notification delivery on a phone (lock screen, buttons, background suppression), real Groq
  reading of ingredient requests, VoiceOver. See the iPhone checklist in the progress ledger.
