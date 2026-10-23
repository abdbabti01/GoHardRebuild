# Food data: search, barcodes, reusable foods and goals

How the app finds foods, where the numbers come from, what has to be configured, and what is and is not covered.

## What the user gets

Eat → **Log food** (also from Today, and the + beside each meal) opens **Add food**, one place to find a food:

- **Search**: everyday foods bundled with the app (see "Common foods") and the user's own foods appear as you
  type, with no connection. **Search more foods** asks USDA for the same words; when the phone has nothing for
  what was typed (three letters or more), that is asked by itself after a 0.6 s pause. Category chips filter the
  common foods only, and say so: your own foods and USDA results have no category and are not shown under one.
- **Scan** (top right): the camera reads a product barcode, or the digits can be typed.
- **Recent**, **Favourites**, **My foods**: the user's own lists, narrowed by what is typed.
- **Can't find it? Create your own food**: the manual form, as before.
- The meal under the title starts as the meal the screen was opened for and can be changed; it carries into the form.

A row shows the name, what tells the food apart (preparation or brand), the amount its values are for ("1 egg
(50 g)", "100 g"), calories and protein; an unknown value is a dash. The row and its plus ("Choose Eggs") both open
the form. Every one of these opens the same form. It shows the food, its source and the values it has, takes an amount and a
unit, and logs only when **Log food** is pressed. Searching, scanning, previewing, marking a favourite and
"Save to My foods without logging" never write a journal entry.

## Sources

| Need | Source | Endpoint | Licence and credit |
|---|---|---|---|
| Barcode → packaged product | Open Food Facts | `GET /api/v3.6/product/{barcode}.json` | Data: Open Database License. Photos: CC BY-SA 3.0. Credited on the form and on the search screen. |
| Text search of basic and branded foods | USDA FoodData Central | `GET /fdc/v1/foods/search` | Public domain (CC0). USDA asks to be credited; it is, under the results and on the form. |

Checked against the providers' documentation and live responses on 12 October 2026:

- Open Food Facts v3.6 is the current API version and has **no full-text search**, so it is used for barcodes only.
  Its text search service (Search-a-licious) is a separate, newer service and is not used.
- In v3.6 the values are under `nutrition.aggregated_set`, not the older `nutriments` object. Each value says whether
  it was stated per 100 g, per 100 ml or per serving, and whether it comes from the label or is an **estimate from
  the ingredient list**. Estimates are not treated as label values: they stay unknown.
- USDA energy is nutrient 1008 (kcal). Foundation foods often carry Atwater energy (2047, 2048) instead, and some
  carry none of the four values in search results; those stay unknown.

**Coverage, honestly:** USDA is in English and describes foods sold or eaten in the United States. Open Food Facts
is volunteer-built; it is strongest for European and North American products and patchy elsewhere, and a product's
name is shown in the language it was entered in. Neither is complete for Canada or for any other country. Product
data can be wrong or out of date; the form says where each value came from and lets the user correct it.

## Rules the numbers follow

- A missing value is unknown and is shown blank or as a dash. A zero is a stated zero. Neither becomes the other.
- Values are for one basis: per 100 g, per 100 ml, or per serving. Only units that make sense are offered:
  grams for a per-100 g food, millilitres for a per-100 ml food, a named serving only when its weight (or volume) is
  stated. A gram is never treated as a millilitre, and a serving without a stated weight can only be counted.
- **Units are counted the way the source names them** (`FoodScaling` in `features/nutrition/food_item.dart`). A
  portion stated as one of something ("1 egg", "1 slice", "1 cup, cooked") is a counting unit: "2 eggs",
  "½ slice", "2 cups, cooked". A size word stays as it is ("2 large"). A serving the source only weighed is
  "1 serving (15 g)". A portion of several things ("2 biscuits (25 g)") is counted as that portion. Fractions are
  allowed. A new entry starts at one of the first countable unit, otherwise 100 g or 100 ml; a common food starts
  at the portion its catalog entry names, which is always one the record itself states.
- **Changing the unit keeps the amount.** Every unit of a food is defined against the food's one basis, so any
  two convert exactly: one 30 g serving becomes 30 g, 45 g becomes 1.5 servings. The form keeps the amount
  unrounded and rounds only what it shows, so 100 g said in 158 g cups reads "0.63" and is still 100 g when said
  in grams again (`FoodScaling.exact`). A unit with no such definition is not offered at all, so "1 serving" can never turn into "1 g".
- **No weight is ever taken from a food's name.** Where the source gives no usable portion, the user can add
  their own ("1 slice = 30 g", or on a per-serving food "1 slice = 0.125 × 1 pizza") with **Add your own
  portion**. It is stored on the food as a serving marked `definedBy: user`, used for that food only, and no
  amount is pre-filled.
- The form shows the amount in full, with its weight where known ("2 eggs (88 g)"), under the fields and in the
  heading of the values. That text is what the journal keeps as the meal's amount.
- Values stated on a different basis than the rest of the product are left unknown instead of being mixed in.
- Energy given only in kilojoules is converted at 4.184 kJ per kcal.
- Barcodes are text. Leading zeros are kept, and codes follow Open Food Facts' documented normalization (8 digits
  for short codes, otherwise 13), so a UPC-A and its EAN-13 form are one product.

## Common foods

`app/assets/data/common-foods.json` is a small, versioned catalog of everyday foods bundled with the app, so
"egg", "rice" or "poulet" find a recognizable food at once, offline and straight after a restart. There is no
table, endpoint or contract change behind it.

- **Each entry is one real USDA FoodData Central record**, exactly as this API normalizes it in
  `GET /api/v1/foods/search`: `source: usda`, `sourceId` the FDC ID, and the record's own values, basis and
  portions. Nothing in an item was typed by hand. The file states its `version` and `provenance` (source,
  retrieval date, method).
- Around the item, GoHard adds only what finds and labels it: a stable `id`, the everyday `name` ("Eggs"), a
  `qualifier` saying which preparation the record is ("Whole · raw", "Baked or roasted · skinless"), one of eight
  `category` values, English and French `aliases`, and `portion`: which of the record's own portions a new entry
  starts from ("1 egg"), or null for 100 g. These are labels, not USDA data, and are not copied into a meal.
- **Identity is the record.** A common food, the same record returned by a wider search, and a favourite or a
  logged meal made from it all share `usda:<fdcId>` and are listed once, under the everyday name. Foods are never
  merged because their names are alike: the user's own "Eggs" stays a separate food with its own values.
- A meal logged from a common food stores the provider's record untouched as its snapshot, under the everyday
  name. The form shows the provider's full title and "Source: USDA FoodData Central".
- **Rebuilding it:** `node scripts/build-common-foods.mjs --cache <dir outside the repo>` reads
  `scripts/common-foods.spec.json` (everyday name → query → the FDC ID chosen by review), asks the testing API
  for anything not in the cache through one disposable account that it deletes afterwards (at most 20 lookups a
  minute), and refuses a portion the record does not state. `--candidates` lists what the API returned for an
  entry so a record can be chosen. Raise `VERSION` in the script when the foods change.
- Every original name, its replacement record (FDC ID, preparation, starting portion) and the old and new values
  side by side: `docs/COMMON_FOODS_COMPARISON.md`. 74 foods cover 75 of the 76 original names (string cheese is the
  part-skim mozzarella record).
- Left out on purpose: "Protein bar" (USDA has only specific branded bars, no generic one) and "String cheese"
  (it is the part-skim mozzarella record, which is found by that name too). Records without count portions
  (mostly SR Legacy) start at 100 g; none was given an invented portion.

**Relevance** (`features/nutrition/food_search.dart`, one rule for common foods, the user's foods and USDA's
answer): case, spacing, accents and ligatures are ignored and simple plurals folded; every word typed has to be
found; an exact name or alias comes before a name that starts with the words, then whole words among name,
aliases, preparation and brand, then beginnings of words, then parts of words. USDA's answer is re-ordered by the
same rule (plain "Rice, …" before "Snacks, rice cakes"), never thinned.

**What the search screen says when the wider search gives nothing** is one of six different things: the database
answered with nothing; it could not be reached (this phone's connection or the server, the app cannot tell which);
it took too long; too many requests for now; not answering; not set up on this server. A failure never removes the
foods found on the phone and is never worded as "no foods" or "offline". An answer to an earlier question, or to
one since cleared or re-scoped, is dropped when it arrives; an answer already given is reused while the screen is
open.

## What is stored when food is logged

The journal entry keeps its own copy of the food as it was, the amount and unit, the values for that amount, and
per nutrient whether the value is the source's (`imported`), the user's (`entered`) or `unknown`. A later change at
the provider, a refreshed cache or an edit to a saved food never changes a meal already logged. Editing a logged
meal is the user's own action and goes through the normal revision check.

A portion the user defines travels inside every copy of the food: the meal's own snapshot, the favourite or My
food kept for it (updated when the portion is defined), and, through those, the same food found again by search or
barcode. It syncs as part of those records; the server stores the food as given and needed no change. A meal
logged earlier keeps its own snapshot, quantity, unit and wording: units are read from each snapshot, and the two
added fields (`definedBy`, `ofServing`) are optional, so records from before them read exactly as they did.

A value the user corrects stays theirs when the amount changes. "Save to My foods" keeps a corrected food as the
user's own copy, with a note of what it was based on; the provider's record is not changed for anyone.

## Where the code is

| Part | File |
|---|---|
| Normalized food, lookup result, barcode rule | `api/src/GoHard.Api/Application/FoodDiscovery/FoodItem.cs` |
| Open Food Facts adapter | `…/FoodDiscovery/OpenFoodFactsProvider.cs` |
| USDA adapter | `…/FoodDiscovery/UsdaProvider.cs` |
| Cache, shared in-flight calls, request budgets, retry | `…/FoodDiscovery/FoodDiscoveryService.cs` |
| Endpoints `GET /api/v1/foods/search?q=`, `GET /api/v1/foods/barcode/{code}`, `PUT /api/v1/saved-foods/{id}` | `api/src/GoHard.Api/Endpoints/Endpoints.cs` |
| Units and scaling on the phone | `app/lib/features/nutrition/food_item.dart` |
| Lookup with offline cache, local suggestions | `app/lib/features/nutrition/food_discovery.dart` |
| Common-food catalog, relevance, row facts | `app/lib/features/nutrition/food_search.dart`, `app/assets/data/common-foods.json` |
| Catalog build (reproducible, cached) | `scripts/build-common-foods.mjs`, `scripts/common-foods.spec.json` |
| Journal and saved foods (through the existing outbox) | `app/lib/features/nutrition/food_repository.dart` |
| Search screen, scanner, shared form | `log_food_screen.dart`, `barcode_scan_screen.dart`, `food_form.dart` |

The phone never talks to a provider. It asks the GoHard API, which holds the USDA key.

## Limits and budgets

Both providers count requests per calling address, and every user of the API shares the server's one address.

| | Provider's limit | This server's budget | Also |
|---|---|---|---|
| Open Food Facts product reads | 15 a minute | 10 a minute (`FoodData:OpenFoodFactsPerMinute`) | identified by User-Agent, as they require |
| USDA | 1,000 an hour | 800 an hour (`FoodData:UsdaPerHour`); one search costs two requests | key in the `X-Api-Key` header, never in a URL |
| Per signed-in person | | 30 lookups a minute (`FoodData:PerUserPerMinute`) | |

- Answers are remembered in the API's memory: found foods and searches for 24 hours, "not found" for 1 hour.
  Failures are not remembered. Identical requests in flight share one provider call.
- After a provider answers "too many requests", nothing more is sent to it for 5 minutes.
- Each call waits at most 8 seconds and is retried once.
- The phone keeps up to 300 foods it has seen, per account, and answers a barcode looked up in the last 7 days from
  there. The wider search is never run per keystroke: it runs on a tap, or once after a 0.6 s pause when the
  phone has no match, and an answer is reused while the search screen stays open.

Known ceiling: the cache and the budgets live in one API process. A restart empties the cache, and a second API
instance would need a shared cache before the budgets hold. At 10 barcode lookups a minute for all users, a busy
moment shows "the product database is busy" and offers manual entry. Open Food Facts asks high-volume apps to use
their data downloads instead; that is the path if usage grows.

## Configuration

| Setting | Where | Needed for |
|---|---|---|
| `GOHARD_FoodData__UsdaApiKey` | environment variable on the API host (Railway → service → Variables), or `FoodData:UsdaApiKey` in `api/src/GoHard.Api/appsettings.Local.json` locally | text search |

1. Get a free key at <https://fdc.nal.usda.gov/api-key-signup> (it arrives by email).
2. Set it as above and restart the API.
3. `GET /api/v1/capabilities` then lists `food.search`, and `scripts\verify-api.ps1 -BaseUrl <api>` checks a real search.

Without a key the API still does everything else. Search answers "not set up on this server", `food.search` is not
declared, and the app says so on the search screen and offers barcode and manual entry. `DEMO_KEY` is refused as a
configured key on purpose: it allows 30 requests an hour and is for trying the API by hand. The key is never sent to
the phone, logged, or committed. Barcode lookup needs no key.

## Nutrition goals

Me → **Nutrition goals**: optional daily calories (500 to 10,000) and protein (10 to 500 g), whole numbers, blank
for none. Nothing is suggested or pre-filled. They are two fields on the profile and travel in the existing
`profile.update` command:

- a goal field left out of the request is kept (so an app from before goals cannot erase them);
- an explicit `null` clears it;
- a number sets it.

Today and Eat draw the same `NutritionSurface`. A rail appears only for a goal that is set. It stops at full while
the words give the real total. "Left" is stated only when every food that day has a value; otherwise the line
says "known so far".

## Water

Optional, declared by the capability `water.entries`. Water is only what the person logs on purpose; it is never
counted or estimated from foods or drinks in the food journal.

- `WaterEntryDto`: `{ id, dayKey: "YYYY-MM-DD", volumeMl, revision, isDeleted }`. `volumeMl` is canonical millilitres,
  above 0 and at most 5,000 per entry, up to 3 decimals (stored as numeric(9,3)). `dayKey` is a calendar date, stored
  as sent and never zone-converted. Display units are the app's business.
- `POST /api/v1/water-entries` `{ operationId, entryId, dayKey, volumeMl }` (command `water.create`; an existing id is
  a `DUPLICATE_ID` conflict), `PUT /api/v1/water-entries/{id}` `{ operationId, expectedRevision, dayKey, volumeMl }`
  (`water.update`), `POST /api/v1/water-entries/{id}/delete` `{ operationId, expectedRevision }` (`water.delete`, soft
  delete). Same idempotency, revision and `ENTRY_DELETED` rules as food entries; another account's entry is a 404.
- `GET /api/v1/water-entries?date=YYYY-MM-DD` lists that day's live entries; the sync snapshot carries every entry,
  deleted ones included, as the optional `waterEntries`.
- Goal: `waterGoalMl` on the profile, 100 to 10,000 mL, null = no goal, never defaulted or saved by the app (Eat's
  goals form offers 2,000 mL as a general starting point while none is saved; only Save goals stores it). Same three cases as the
  nutrition goals in `profile.update`: left out = kept, `null` = cleared, a number = set.

On the phone (`features/nutrition/water.dart`, `nutrition_tools.dart`):

- Entries are the record kind `water`, written by `WaterRepository` through the same outbox as food: saved on the
  phone first, one operation per change, byte-identical retries, the day pinned when the sheet opened.
- Display unit: Me › Units › Water, millilitres (mL, L) or US fluid ounces (1 fl oz = 29.5735295625 mL), set on this
  phone like °C/°F. Quick additions are 100 / 250 / 500 mL or 4 / 8 / 16 fl oz. An amount is converted to mL once
  (three decimals) when it is entered; totals are exact sums of the stored mL and are rounded only when shown.
- Water is off until turned on in Customize tracking, with carbs and fat shown or hidden; hiding changes nothing
  stored (entries, goals and logged values stay). It is offered only where the server declares `water.entries`, so
  nothing is queued that an older server could never accept.

### One tap for a drink, and History (18 Oct 2026, GoHard_Today_History_Water_Corrections)

- **Quick add.** On Today and on today's Eat, under the water line: **+250 mL** (or **+8 fl oz** in fluid ounces,
  `VolumeUnit.everyday`). One tap logs exactly that amount on today, at once, through `WaterRepository.add` (one entry,
  its own id, local first; a retry reuses its operation). The amount on the button is the amount stored: 8 fl oz is
  236.588 mL, converted once by `toMl`. A second tap is a second drink. A convenience, not a recommendation; no goal is
  set or changed.
- **Undo** (`addWater` in `nutrition_tools.dart`): a bar for 5 seconds, one at a time, that removes exactly the entry
  just added (`WaterRepository.remove`, its revision dependency waits for the add when that has not been sent yet), never
  a numeric decrease. It does nothing once another account is signed in, and acts on the day the entry was logged on.
- **Other amount**: one field in the chosen unit and **Add water** (same validation: above zero, at most 5 L per entry),
  for the day shown. On an earlier day in Eat only Other amount is offered (the one-tap drink is for today).
- **Water details**: tapping the water line opens the day's entries with correction and removal (unchanged).
- **History** (Eat, under the date; since 20 Oct 2026 inside History & trends, below): a calendar to pick any day, and the days with food or
  water on this phone, newest first, each with its count of foods, its calories (known totals labelled "known",
  "calories unknown" when no food had a value) and its water. Choosing a day shows it in Eat, dated, with Back to today;
  Add food and Other amount keep that day. Read from the same local records as Eat (`foodJournalProvider`,
  `waterEntriesProvider`); no copy, no new model.
- **Goals on earlier days**: goals of past days were never stored, so an earlier day is not set against today's goals
  (no goal bars or percentages on it, food or water); only today is.
- Goals and **Customize tracking** are in Eat only (a labelled action); Today shows the water line and its actions.

### History & trends (20 Oct 2026, GoHard_Nutrition_Trends_Claude_Handoff)

Eat's **History & trends** (since 23 Oct 2026 a full-width panel under the day's summary, above the meals, key `eat-history`; it replaces the History screen) shows what was logged
per day, week and month. Code: `intake_history.dart` (the pure projection), `nutrition_history.dart` (the screen,
the bar chart and the calendar). No API change, migration, dependency or permission: it reads the same local records
as Eat (`foodJournalProvider`, `waterEntriesProvider`), grouped by day once per change of the records
(`foodDaysProvider`, `waterDaysProvider`). The full sync snapshot already carries every food and water entry of the
account (`/sync/snapshot`, no date limit), so nothing is fetched per day and no food provider is asked. Viewing changes
no preference and queues no command.

- **Periods.** Week is Monday to Sunday; Month is the calendar month (28–31 days). Both are worked out on day keys
  (calendar dates, never 24-hour steps, so DST and month ends are exact). It opens on the period of the day Eat shows.
  The current period is "This week so far" / "Month to date" with its date range; its future days are drawn empty with
  faded dates, never as not logged or zero; no wholly future period can be opened. Previous goes back to the period of the earliest
  entry (or a year). The period's label opens a date picker; **This week / This month** returns to the current one.
- **Metrics.** Calories and Protein always; Carbs and Fat when shown; Water when turned on (and kept by the server).
  A metric hidden after being chosen gives way to Calories without changing the period. kcal, g (one decimal) and the
  chosen water unit, converted once from the exact sum.
- **One day, one metric** (`intakeDay`): *Not logged* (no food that day: a water-only day is food not logged; no
  water entry for Water), *Unknown* (food logged, none with this value: "?" in the chart), *Partial* (a known sum, some
  foods without the value: lighter bar, outline and a star, and "known" in words), *Recorded* (every logged food has the
  value), and a *recorded zero* (explicit zeroes: a ring on the baseline). Each nutrient has its own coverage. Nothing
  is estimated, worked out from other nutrients, or recomputed from a food's current serving. Deleted entries are left
  out; pending ones count as they do in Eat and are labelled "sync pending" / "needs review".
- **Totals** (`IntakeSummary`): the period's total is the sum of known daily values (null, never zero, when there
  are none). The **daily average** divides it by the days with a known value of *that* metric: a recorded zero counts;
  unknown-only, unlogged and future days do not. When a partial day contributes, the panel says "Known … logged",
  "Daily average, known values" and how many days are partial. Coverage reads "5 of 7 days with calorie values" (elapsed
  days only, "so far" in the current period), and, when it differs, how many days had food logged and how many had no
  value for this metric. Water counts water days.
- **Choosing and opening a day.** Tap or slide across the chart (nearest elapsed day), or step with the day panel's
  arrows; the panel shows the date, value and coverage and **View day**. View day, a row of *Days in this period* (every
  elapsed day of the period, empty days included) or the **Calendar** (the calendar and every day with entries, as
  before) open that day in Eat, dated, with Back to today; Add food and water there keep that day. Opening History &
  trends again from that day keeps the period, metric and day (`trendsViewProvider`, cleared on account change).
- **Goals** are not drawn: earlier days' goals were never stored.
- Tests: `nutrition_trends_test` (states, denominators, periods), `nutrition_trends_ui_test`, `water_ui_test`;
  renders `nutrition_trends_render_test` (gated) in `docs/evidence/nutrition-trends`; Native `journey_trends_test`.

### What is shown follows the account (17 Oct 2026)

The three display choices are on the account where the server declares `profile.tracking-display` (migration
`AddTrackingDisplay`, additive: three nullable columns on `Users`).

- Profile: `showWater`, `showCarbs`, `showFat`, each `true`, `false` or `null` (never chosen on the account; nothing
  is invented for it). `profile.update` sends all three together when the choice changes; left out or `null` = kept,
  so an older app that renames the account or sets goals cannot erase them, and an explicit `false` is a choice. The
  same revision check and conflict review as any profile change (a stale offline edit becomes a conflict to keep or
  discard, never a silent overwrite).
- On the phone (`water.dart`): each field is the account's value when the profile has one (it also holds an edit
  made offline until it is sent, and the sync engine never replaces a record with a change waiting), else the choice
  made on this phone (`TrackingPrefsStore`, per account, kept as before), else the defaults (water off, carbs and fat
  on). A change applies at once, is kept on the phone and goes through the outbox.
- Migration: a choice made on this phone while the account could not keep it is sent once, when the account has
  none (`displayMigrationProvider`, kept alive by the shell). A fresh install has no choice of its own, so it shows the
  account's and sends nothing; an account that already has a choice keeps it.
- Unknown capabilities count as "no" here (unlike elsewhere): no server is sent fields it did not declare. The water
  unit (mL / fl oz) stays a phone setting, like °C/°F.
- Covered by `tracking_sync_test` (two phones with real Drift files and the fake account; offline through a restart;
  a stale revision; the one-time upload; omitted fields; another account) and `WaterTests.Tracking_display_*`.
- The water goal is edited in the same goals form as calories and protein, and only sent while that form shows it.

## Compatibility gate

On start and on resume the app asks `/capabilities` once, waiting at most 6 seconds. If the server's
`minimumClientContract` is higher than the app's contract, the app shows "Update GoHard to continue" over whatever
was open, stops sending and pulling, and keeps its outbox untouched. The block is remembered across restarts and
lifts only when a later check passes. No answer, or an unreadable one, changes nothing, so offline works as before.

`minimumClientContract` is 1 and is raised only by setting `Compatibility:MinimumClientContract` for a change an
older app cannot live with. Everything in this document is additive and did not raise it.

## Testing without the providers

- Automated tests use recorded responses in `api/tests/GoHard.Api.Tests/Fixtures/`. No test run reaches a provider.
- `scripts\start-api.ps1 -FoodFixtures` runs the local API against those recordings, for development and for the
  native journey `journey_food_test`.
- `scripts\verify-api.ps1 -BaseUrl <api>` is the separate live check: against a deployed API it performs a real
  barcode lookup, and a real search when a key is configured.
