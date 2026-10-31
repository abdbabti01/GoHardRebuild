# Eat companion: briefing, meal ideas, heads-ups, meaningful reminders

Brief: "Improve GoHard's Eat coach into a useful, contextual nutrition companion, and fix vague reminder wording"
(30 Oct 2026). Built on `feature/meal-habits-reminders` (not merged when this started; this branch includes it).

One assistant, one set of numbers: Leon/Leona on Eat and Help with today (`features/coach/day_coach*.dart`), the
existing nutrition arithmetic (`NutrientCoverage`, `FoodScaling`, `MealMath`), the existing review and logging paths.
Nothing here is a second assistant or a second calculator.

## Reminder wording

**Cause of "GoHard reminder — Open GoHard to see it":** not missing data or a rendering fault. It was the text sent
when a reminder's **Hide details on the lock screen** is on, and the editor turned that on by default for supplements as
well as medication. The hidden text did not say what the reminder was for.

Now every notification states its purpose (`reminderNotices` in `features/me/reminders.dart`):

| Reminder | Details shown | Details hidden |
|---|---|---|
| Meal | "Time to log breakfast." · instructions, else "Tap to open Eat." | "Time to log breakfast." · "Tap to open Eat." |
| Medication | the person's name for it · instructions, else "Tap to confirm in GoHard." | "Time for your medication." · "Tap to confirm in GoHard." |
| Supplement | the person's name for it · same | "Time for your supplement." · same |

Hidden never shows the name, a dose or the instructions. New reminders hide details by default for medication only
(still a per-reminder switch). Taken / Snooze / Skip, account isolation and scheduling are unchanged; opening or
dismissing a notification still records nothing. There are no nutrition notifications.

## Briefing (`features/nutrition/eat_briefing.dart`, pure)

Eat's bubble says one thing about the day shown, worked out on the phone from that day's recorded food, the calorie and
protein goals the person set, the time, and the next meal (the next of the person's own meal reminders today, else the
time of day). It replaces the fixed "Log a meal and see how the day adds up against your goals." No AI is asked to
make it, to open Eat or to refresh the journal; the same records always give the same words.

Its action is **What could I eat?** (today only). When the day's food changed while Eat was not on screen (logged from an idea's review, Add food, another phone), the visit back shows the updated briefing; the one-time introductions (saved foods, history, saved meals, Eating out, meal suggestions) wait for a later visit to the tab. With the coach off, the panel shows the same updated words. Without goals it also offers **Set goals** (Eat's own goal sheet).
**Ask me** stays. With the coach hidden on Train and Eat, the same words and What could I eat? appear in one compact
pale panel under the day's summary (the usual meal takes that place when there is one). Log food and every meal's Add
food are unchanged.

### Completeness rules

- Calories and protein are judged separately (`NutrientCoverage`). A missing fat value changes neither; a missing
  calorie value never makes known protein unknown.
- A calorie total with any unknown value is "at least N kcal recorded": never an exact allowance or "left".
- Protein "left" is given only when every protein value is known; reaching the protein goal is said even with unknown
  values (the known part can only grow).
- "Left" is against what is recorded, never a claim about everything eaten. No meal is inferred from a missing log, and
  intake is never assumed to be spread evenly over the day.

### Order (first that applies)

1. An earlier day: looking back ("On Thursday, October 29 you recorded 2,300 kcal and 90 g protein. That is 300 kcal
   above your target."), or "Nothing was recorded on …". No heads-up, no "eat this now", no ideas.
2. Today, nothing logged: "Nothing logged yet today. Want ideas for lunch?"
3. A heads-up (below), if heads-ups are on and that one has not been said today.
4. A calorie goal and an incomplete calorie total: "Some foods today have no calorie value, so the total is incomplete:
   at least N kcal recorded."
5. Every goal reached: said plainly, no question asking to eat more (see Shared assessment below).
6. Goals: "You have N kcal and N g protein left. Want some options?" (or the parts that apply; "Protein goal reached.";
   above the target said plainly once its heads-up has been said; "Calorie target reached." at the target).
7. No goals: "Breakfast is logged. Want ideas for your next meal?"

### Heads-ups (in the app only)

Product thresholds, deterministic, not medical advice and not a prediction of anyone's needs (`BriefRules`):

| Heads-up | When |
|---|---|
| Above the calorie target | calorie goal set, every calorie value known, recorded total above it |
| Near the calorie target | as above, 0 < left ≤ max(150 kcal, 10 % of the goal), and before 17:00 local time |
| Protein goal reached | protein goal set, known protein ≥ goal |

Wording is neutral and offers a next step ("That's okay. If you're still hungry, I can suggest lighter options."). It
never suggests skipping meals, fasting, compensating with exercise or "earning" food, never changes a goal, and never
treats going over as a failure. Each heads-up is said **once per day per account** (`day|kind`, kept on this phone);
afterwards the same state is said plainly. The words on screen stay put while the state lasts and are re-worked after an
edit, a deletion, a goal change or the day changing. **Me › Meal suggestions › Show nutrition heads-ups** turns them off
(separate from reminders and from meal suggestions); heads-ups wait until that choice has loaded, so one already said is
never picked again during start-up.

## What could I eat?

**Built in, no AI** (Eat's action, or the conversation's chip): the usual meal (meal suggestions on), up to two of the
person's saved meals/recipes/foods by the existing suggestion rules, and the ways to **Eating out**, **Choose something
else** (Add food) and **Saved meals**. With a server that declares `coach.ideas`, ready requests follow: "Something quick
with more protein", "Something sweet", "No cooking", "A vegetarian meal" and (with a usual meal) "Something different from
my usual". Anything else can be typed ("something cheaper", "what could I order at McDonald's?").

### Ideas: who does what

| Step | Who | What |
|---|---|---|
| Read the request | server model (Groq, existing setup and shared allowance) | kind `ideas`, up to 3 ideas of 1–6 foods as **words**: an everyday English name, the name in the person's language, a preparation, an amount in g / ml / piece (+ noun) / serving; preferences from an allowlist |
| Check | server (`DailyCoachService.Ideas`) | lengths, units, amount ranges (g/ml 1–2,000; pieces/servings 0.25–20); a title or name with a figure (kcal, g, $, a link) is dropped; everything else treated as the person's data |
| Match foods | phone (`features/coach/meal_ideas.dart`) | each name to a real record: the bundled everyday foods (`common-foods.json`, USDA records), the person's own saved foods, foods already seen on this phone, then the account's food search (USDA via `/foods/search`), at most **3 searches per request**, unbranded results only, whole-word name matches only |
| Confirm preparation | phone | a proposed preparation filters the records (only records stating it count), then the name decides among them ("raw egg" is the egg, not raw egg whites). No record states it → the same name is offered as a choice with its preparation shown ("cooked oats" → "Oats (Dry · uncooked)"), never taken. Choosing it never reuses the proposed amount (it was for the other preparation): the card says so and asks for a fresh amount before any total. Several equally good records → a choice of up to 3 |
| Match amounts | phone | to exactly one of the record's own units (g, ml, a count unit by its noun, a single serving). A unit the record lacks, or one that fits several of its units (slice sizes) → **Choose amount**: the usual amount form in its selection mode; never a conversion and never a standard portion in its place |
| Values, limits, goals | phone | totals from the records only (`MealComponent` / `NutrientCoverage`); an explicit limit ("under 500 kcal", "at least 30 g protein") is met by a practical step of every amount (½–2×) or the nearest is shown with what it misses; how it sits with the day's goal when both are fully known |

The model never supplies a food record, a nutrient value, a serving conversion, a price, a preparation time or a
restaurant item. Restaurant requests stay kind `restaurant` and open the existing Eating out flow (its verified
Canadian menus and customization rules).

### Idea cards

Each card shows the foods with exact amounts, the matched record's preparation or title beside each, calories and
protein, and one of (an idea gets totals and Review only once every food is matched and confirmed):

- **Calculated from food records.** → **Review meal**
- **Confirm the foods below to see totals.** → per food, "Which rice?" with one button per record (name and
  preparation), or "How much toast?" with **Choose amount**. The answer is applied on the phone and the card recalculated;
  nothing is sent.
- **Needs a food match: Dragonfruit. No totals until it is found.** → **Find food** (Add food with that name in its
  search; nothing chosen for the person). Never estimated, never logged as verified.
- **Doesn't meet: …** (the misses) or "Some values are missing, so GoHard can't say whether it meets what you asked."

Preferences GoHard cannot check are said: no prices ("cheaper"), no preparation times ("quick", "no cooking"), no
dietary labels ("vegetarian"). "More protein" and "lighter" order the ideas by the calculated values. "Different from my
usual" leaves out ideas sharing a food identity with the usual meal. **Other ideas** asks again; **Choose something
else** is always there.

### Review and logging

**Review meal** opens the existing `MealReviewScreen` with the idea's foods for the selected day and meal: change any
amount, change or add or remove a food, ½×–2× or a custom multiplier; every value is recomputed from the records.
**Save as meal** keeps it as a saved meal (logs nothing). Only **Log this time** records food, through the existing
atomic meal log (`food.batch`: all entries or none, one operation ID, so a double tap or a retry logs once). Going back
logs nothing.

A reply is marked stale when the day's journal or goals change (`dayRevision`) and its Review is refused until it is
recalculated; matched records are snapshots, so an idea never changes under the person.

## Shared assessment, goal colours and the weekly report (30 Oct 2026, `feature/nutrition-assessment-report`)

Brief: "Improve GoHard's nutrition coaching, add a meaningful weekly nutrition report, and introduce clear colour states for
calorie and protein progress." Built on `main` 19e2cf2 (Eat companion merged).

### One assessment (`features/nutrition/nutrition_assessment.dart`, pure)

`DayAssessment.of(entries, calorieGoal, proteinGoal)` reads a day's calories and protein against the goals that applied.
Eat's briefing, What could I eat? (and its ranking), the bars on Today and Eat, Eat's "left/over" lines, the coach's goal
lines and the weekly report all read it; none of them compares a total with a goal on its own.

Per nutrient (`NutrientAssessment`), judged separately:

| State | When | Calories bar | Protein bar |
|---|---|---|---|
| `noGoal` | no goal set | neutral, no percentage | neutral, no percentage |
| `incomplete` | some values unknown and the known part below the goal | neutral, "Known intake" | neutral, "Known intake" |
| `below` | under 80 % | green, "Room remaining" | yellow, "Below target" |
| `near` | 80 % up to the goal | yellow, "Approaching target" | yellow, "Nearly there" |
| `reached` | at the goal (display resolution) | green, "Target reached" | green, "Goal reached" |
| `over` | above the goal (display resolution) | red, "N kcal over target" | green, "Goal reached · N g above target" |

- Unknown is not zero. Known values at or above a goal establish reached/over even with unknown values (the known part
  only grows); the label then keeps "· Known intake". An incomplete total below a goal never gives an amount left.
- A day with nothing logged is judged against what was logged (nothing), never as a claim about what was eaten.
- **Display-resolution policy.** An amount is compared with its goal as it is shown: whole kcal, tenths of a gram. 1,999.6
  and 2,000.4 kcal both show as 2,000 and are "reached" (never "0 kcal left" or "over"); 2,000.6 shows as 2,001 and is 1
  kcal over. The 80 % line is judged on the exact value (`known × 5 ≥ goal × 4`). The percentage shown is the exact share
  rounded down below the goal (79.99 % → 79 %), exactly 100 % when reached and rounded up above it (100.03 % → 101 %), so
  a percentage never contradicts its label.
- The bar fills to the goal at most; the real total, percentage and overage are in words ("2,450 / 2,300 kcal · 107 %",
  "150 kcal over target"). A green low calorie total means room against the chosen goal, not adequate intake.
- Situations for the coach (`DaySituation`): no goals · remaining · calories reached, protein left · protein reached,
  calories left · every goal reached (also when only one goal is set) · uncertain (a goal not reached and its values
  incomplete).
- Exercise calories are never added to what is left.

### Goal colours (`core/theme.dart`, `nutrition_surface.dart`)

Semantic tokens `goalGreen/goalYellow/goalRed` (bar fills) and `goalGreenText/goalYellowText/goalRedText` (words), chosen
from the page they sit on: the pale photo panels (every accent, Light and Dark) and Dark's own page. Fills hold 3:1 on
the bar's track and words 4.5:1 on the page in all six themes and with increased contrast (`theme_test`). A true yellow
cannot hold 3:1 on a pale panel, so the light "yellow" is a deep gold. The state is always also said in words, beside
the amount (not in a new row, so Today keeps its height), and read out with the amount, goal and percentage. Loading
shows no bar (Today: "Loading", Eat: the journal's loading line), never zero or a false success. These colours describe
progress against goals the person chose, never food quality, health or merit.

### What could I eat? assesses before suggesting (`features/coach/day_coach.dart` › `assess`, `eatChoices`)

For the selected day (today; an earlier day still gets no ideas), from the assessment:

| Situation | Said first | Then |
|---|---|---|
| No goals | "You haven't set daily targets. I can still help you choose a meal or snack." | Edit goals (Eat's sheet, optional) and the usual options |
| Remaining (values complete) | the exact amounts left | saved options within the calories left, most protein first while protein is still to reach; "These fit within …" or, when nothing does, "Nothing saved fits within … These are the nearest; each shows what it would add" (never relaxed silently) |
| Calories reached or exceeded, protein left | "You've reached your calorie target, with N g protein remaining. Would you like protein-focused options? They'll add to your calorie total." (unknown protein values: no exact remainder) | **no options yet**: Show protein-focused options · Find something to eat · See today's summary |
| Protein reached, calories left | "You've met your protein target and have N kcal remaining. What kind of food would you like?" | options within the calories left, no longer ranked by protein |
| Every goal reached | "You've reached your calorie and protein targets based on what you logged. If you're still hungry or want something else, I can help you choose." | **no options yet**: Find something to eat · See today's summary |
| Uncertain | each nutrient on its own ("…at least N kcal recorded", "N g protein remaining") | options without a calorie limit |

Going on (a phone-only `proceed` on the request; a server answer can never set it) gives the options with "Anything you
choose adds to your calorie total; each option shows how much." Protein-focused ranks by protein per kcal. Every card says
what it would make of each goal still known exactly ("Adds 240 kcal: 2,240 of 2,000 kcal logged after this.", protein
only while it is still a goal to reach). New AI ideas (typed requests) are answered whenever asked, ranked the same way
unless the person asked for "more protein" or "lighter"; when none fits within the calories left that is said. Reaching a
goal never blocks search, suggestions or logging. Matching, review, atomic logging and stale-reply protection are unchanged.

### No "done eating"

No button, flag or inferred state. GoHard says "You've reached your targets based on what you logged", never "you're
done". Once every goal is reached Eat's briefing says so plainly with no question asking to eat more, its action becomes
**Find something to eat** (still opens the same help), and the proactive usual-meal suggestion is not put forward. Any
new entry, edit, deletion or goal change re-works the words (they are a pure function of the records).

### Briefing changes (`eat_briefing.dart`)

Built on the assessment: a "reached" kind (above), "Calorie target reached." instead of "0 kcal left" at display
resolution, no "Want some options?" once the calorie target is reached, the near heads-up only while the bar is in its
"approaching" state (so a 500 kcal goal at 72 % is not "near"), the protein heads-up not used when protein was the only
goal (the reached briefing instead). **Earlier days** are compared only with the goal recorded for that day (below);
before this change they were compared with today's goal.

### Goal history (`Kinds.goalDay`, `goalHistorySyncProvider`)

The account stores only the current calorie and protein goals (profile), with no history. From this build, the phone
records the goals in effect each day it is open (`nutrition_goal_day`, id = day key, `{calorieGoal, proteinGoal, changed}`;
`changed` when one goal replaced another during that day; the first goals set on a day that had none are that day's goals). It is **local only and additive**: no server change, no migration, no
capability; it is per account (owner-scoped like every local record) and does not move to another phone. **History starts
when this phone first records it; earlier days are never filled in.** A day with no record, or with `changed`, is not
compared with any goal.

### Weekly report (Eat › History & trends › Weekly report; `intake_history.dart` › `WeeklyReport`, `nutrition_history.dart` › `WeeklyReportScreen`)

Entry: **Weekly report** at the top of History & trends (an icon with its name in the tooltip when text is large or the
phone narrow); Eat's History & trends link says "with a weekly report". No new Eat panel. Monday–Sunday weeks; earlier and
later weeks with the existing period bar; the current week is "Week so far"; never a future week. No AI and no network:
everything is worked out from local records, offline.

Shown: days with food logged of days elapsed; days with nothing logged (never zero); goal history availability; for
calories and protein, the known total, **"Average N a day, over the K days with known values"** (and "It may be
understated: days with some foods missing a value: P" when partial days are in it), **"Complete recorded days: N a day,
over C days"**, days without any value, days compared with the recorded goal (calories: above it on N; protein: reached
on N) and days that cannot be compared (unknown values below the goal); the week's chart for each (the trends chart);
up to three observations and up to two next steps; every elapsed day as a row that opens its journal in Eat.

Observations (only when supported): calorie values recorded on N of M days; protein values on N of M days (when it
differs); protein goal reached on N of M days with a recorded goal; recorded calories above the target on N of M days
with a recorded goal; protein spread between days more or steadier than last week (only with at least 4 complete
protein days in both weeks and a difference of at least 10 g and 1.5×). Next steps: days with foods missing a value;
days with nothing logged. Never: unlogged days as zero, improvement claims from sparse data, weight, muscle, deficiency
or habit inferences, or protein reached as proof of adequacy. "Complete" means every logged food has a value, not that
everything eaten was logged (said in the footnote).

No deeper AI explanation was added (optional in the brief; not needed for a factual report).

### Privacy and compatibility

No new provider, secret, service, endpoint, capability or migration; the daily-coach request is unchanged (`proceed`
never leaves the phone). Nothing nutritional is sent anywhere new; no notifications, no background work. Older servers
are unaffected. **Deployment:** none needed beyond the app build.

### Verification (this branch)

- `test/nutrition_assessment_test.dart` (21): calorie and protein states at 79.99/80/100 % and above, display-resolution
  edges (1,599.9, 1,999.4, 1,999.6, 2,000.4, 2,000.6 kcal; 139.94/139.96 g), percent and fill, protein never red,
  incomplete and genuine zero, every goal combination; What could I eat? for no goals, both remaining, nothing fits,
  calories reached (asks first, then protein per kcal with added calories), protein reached, every goal reached
  (continuing works), incomplete values, stale after an edit or goal change, `proceed` not settable by a server; briefing
  reached, "reached" at display resolution, near heads-up consistent with the bar, earlier days only against a recorded
  goal; weekly report averages and denominators, unlogged/partial/zero days, no history, recorded goals with changed and
  undeterminable days, the current week, spread only with enough data.
- `test/nutrition_report_ui_test.dart` (7): red calories and green protein with words, percentage and semantics on Eat and
  Today; "Known intake" with missing values; every goal reached → Find something to eat → asks first → continuing gives
  options; the report from History & trends with no goal history, no future week, a day opening in Eat; recorded goals
  compared and the previous week; French and Arabic at 320 px with 2× text (found and fixed: the History app-bar label
  overflowed; now an icon with a tooltip there).
- `theme_test`: goal tokens' contrast in all themes. Updated: `eat_companion_test` (reached briefings, no-goals reply),
  `nutrition_trends_ui_test` (link wording).

## Privacy and compatibility

- Sent to the model for an ideas request: exactly what Help with today already sent (the request words, the last six
  turns, the language, whether the day is today, the account's saved item names by reference) plus `features: ["ideas"]`
  and the line "New ideas: available". Not sent: the journal, totals, goals, body measurements, reminders, medication,
  email or location.
- Capability `coach.ideas` (new, declared with `coach.daily` when the coach is configured). The phone sends `features`
  only to a server that declares it; an older server never receives it, and the phone then keeps What could I eat? to
  the person's own items, Find food and Eating out. A server never returns ideas to a phone that did not ask (it answers
  `suggest`). No migration. **Deployment:** ideas appear only after the API with `coach.ideas` is deployed; no new
  secret, variable or provider.

## Verification

- `test/eat_companion_test.dart` (9): completeness (independent calories/protein, missing fat, no exact allowance),
  no-goal, empty, over/near/protein heads-ups and their thresholds, said once, turned off, earlier days, next meal from
  reminders; ideas matched to real records with their own units, preparation never swapped (cooked vs dry oats, raw egg vs egg
  whites), ties offered as a choice, unit mismatches and several sizes asking for an amount, no conversion, no branded
  substitute, search bound, model values ignored, limits met by steps, unmatched ideas without totals, unverifiable
  preferences said, "different" filtering, stored replies reading back the same, built-in What could I eat? with no AI.
- `test/eat_companion_ui_test.dart` (7): bubble wording and action, heads-up first time / said already / turned off,
  coach-off panel opening the ideas, French and Arabic at 320 px with 2× text.
- `test/day_coach_ui_test.dart` (+4): an idea from words to review, back logs nothing, Log once through the meal batch
  even with a second tap; an older server gets no `features`; French and Arabic ideas at 320 px with 1.6× text.
- `test/meal_habits_reminders_test.dart`: reminder wording with details on and off for meal, medication, supplement.
- Native `journey_eat_companion_test` (coach stub, not a model): briefing, What could I eat?, a matched and an unmatched
  idea, review with a changed amount and back (nothing logged), Log once (two entries) passed on Pixel_7; it found the
  cold-start catalog bug fixed here. On 31b0e2a it passed every step, including the updated briefing back on Eat after logging (captures ec-01…05).
- API `DailyCoachTests` (8): ideas kept as words only for a phone that asked, figures dropped, amounts out of range
  dropped, preferences allowlisted, an older phone gets `suggest`. **Stubbed provider: says nothing about real Groq.**
