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

Its action is **What could I eat?** (today only). Without goals it also offers **Set goals** (Eat's own goal sheet).
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
5. Goals: "You have N kcal and N g protein left. Want some options?" (or the parts that apply; "Protein goal reached.";
   above the target said plainly once its heads-up has been said).
6. No goals: "Breakfast is logged. Want ideas for your next meal?"

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
| Confirm preparation | phone | a proposed preparation filters the records (only records stating it count), then the name decides among them ("raw egg" is the egg, not raw egg whites). No record states it → the same name is offered as a choice with its preparation shown ("cooked oats" → "Oats (Dry · uncooked)"), never taken. Several equally good records → a choice of up to 3 |
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
  cold-start catalog bug fixed here. The last check (briefing after logging) was not rerun after a harness fix.
- API `DailyCoachTests` (8): ideas kept as words only for a phone that asked, figures dropped, amounts out of range
  dropped, preferences allowlisted, an older phone gets `suggest`. **Stubbed provider: says nothing about real Groq.**
