# Food data: search, barcodes, reusable foods and goals

How the app finds foods, where the numbers come from, what has to be configured, and what is and is not covered.

## What the user gets

Eat → **Log food** (also from Today, and the + beside each meal) opens **Add food**, one place to find a food:

- **Search**: everyday foods bundled with the app (see "Common foods") and the user's own foods appear as you
  type, with no connection. **Search more foods** asks USDA for the same words (corrected, in English); unless something on the
  phone is named exactly (three letters or more), that is asked by itself after a 0.6 s pause (since 24 Nov 2026; before,
  only when the phone had nothing). Category chips filter the
  common foods only, and say so: your own foods and USDA results have no category and are not shown under one.
- **Scan** (top right): the camera reads a product barcode, or the digits can be typed.
- **Recent**, **Favourites**, **My foods**: the user's own lists, narrowed by what is typed.
- **Can't find it? Create your own food**: the manual form, as before.
- **Describe your meal** (since 24 Nov 2026): a sentence about what was eaten, read by Leon or Leona into one meal to
  review (see *Describe your meal* below).
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
| Restaurant chain items (Eating out) | The chains' own published Canadian nutrition information, read into a reviewed catalog (`docs/EATING_OUT.md`, `docs/RESTAURANT_SOURCES.md`) | none at run time: bundled + `GET /api/v1/restaurants/catalog` | Factual values with attribution; source `restaurant`, credited with publication and check dates on the form. No logos or photos. |

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
  side by side: `docs/COMMON_FOODS_COMPARISON.md`. 74 foods cover 75 of the 76 original names (77 since catalog version 2, 24 Nov 2026: below) (string cheese is the
  part-skim mozzarella record).
- Left out on purpose: "Protein bar" (USDA has only specific branded bars, no generic one) and "String cheese"
  (it is the part-skim mozzarella record, which is found by that name too). Records without count portions
  (mostly SR Legacy) start at 100 g; none was given an invented portion.

**Relevance** (`features/nutrition/food_search.dart` › `relevance`, one rule for common foods, the user's foods, USDA's
answer and meal matching; revised 24 Nov 2026, see *Search relevance* below): case, spacing, accents and ligatures are
ignored and simple plurals folded; every word typed has to be found; then a tier (exact name or alias · a brand the search
names · every word whole · the last word still being typed · beginnings of words · parts of words) and, within a tier, how
much more specific the food is than what was asked.

**What the search screen says when the wider search gives nothing** is one of six different things: the database
answered with nothing; it could not be reached (this phone's connection or the server, the app cannot tell which);
it took too long; too many requests for now; not answering; not set up on this server. A failure never removes the
foods found on the phone and is never worded as "no foods" or "offline". An answer to an earlier question, or to
one since cleared or re-scoped, is dropped when it arrives; an answer already given is reused while the screen is
open.

### Search relevance (24 Nov 2026, `feature/food-search-describe-meal`)

**What was wrong.** Searching "chicken breast" showed one cooked breast from the phone, and USDA's own answer starts with
"Lunchmeat, chicken breast, sliced", rotisserie and breaded tenders; the plain raw breast is tenth and the plain roasted
ones past the first 15. The app then *promoted* titles that merely start with the words ("Chicken breast tenders,
breaded" above "Chicken, breast, boneless, skinless, raw"), the catalog had no raw breast, aliases such as "chicken" and
"grilled chicken" made the roasted breast the exact answer for any chicken, French or Arabic words were sent to the
English-only USDA as typed (it matched "de" and answered "Atole de avena"), and a misspelling ("chiken brest") found
nothing anywhere (USDA answers 0 hits). Checked against USDA's live answers on 24 Nov 2026.

**What it does now** (no AI anywhere in search; nothing here touches a food's values):

- **Specificity.** Within a tier, a food that says more than the search asked comes later: nothing for small words and
  plain descriptions (raw, cooked and every cooking method, boneless, skinless, meat only, lean, plain, fat level such as
  skim or 2 %), 3 for something added or a product made from the food (breaded, coated, sauce, glazed, deli, lunchmeat,
  nuggets, fast food, fried…), 2 for another word in the part of a provider title the search names or in its first part
  ("rice *noodles*", "*Yogurt*, Greek, nonfat milk"), 1 for anything else. "Skin not eaten", "without sauce", "no added
  fat", "from raw", "sans peau", "non cuit", "غير مطبوخ" are read as what they say. A word the search asks for costs
  nothing, so "breaded chicken breast" puts breaded first.
- **Preparation words mean the same in three languages** (`cuite` = cooked, `مشوي` = grilled) and "cooked" finds any way
  of cooking but never raw; sautéed and fried still count as more than plain "cooked".
- **Broader aliases are not exact.** An alias that is only part of another of the food's names ("chicken" beside
  "chicken breast", "دجاج" beside "صدر دجاج", "rice" beside "white rice") still finds it but never as the exact answer. The
  aliases "grilled chicken" / "poulet grillé" / "دجاج مشوي" were removed from the roasted breast.
- **Brands.** A branded product whose brand the search names ranks above everything else that matches; when no brand is
  named, a branded product counts as a little more specific, so plain foods come first and products follow (never
  hidden). Rows say **Generic** or **Brand: Tyson** (a capitalised product name reads as a sentence; the record keeps the
  source's name and ID).
- **Repeats.** The same product listed again under another ID (same name, brand, basis, values and portions) is shown
  once. Different preparations, values or portions are never merged.
- **Misspellings** are corrected to the nearest word the app knows (each catalog food's names, preparations and aliases
  in every language, and the translated staples): one edit for 4–6 letters, two from 7, never a word being typed, never a
  word with no close match. Said on screen: "Showing results for “chicken breast”."
- **French and Arabic for USDA.** A short list of everyday food words (`food_search.dart` › `_english`) puts the search in
  English for the wider database ("poitrine de poulet cuite" → "breast chicken cooked"); unknown words are kept and small
  words dropped; the screen says which words were sent. Results sharing no word at all with the search are not shown.
- **When the wider search runs by itself** (revised 26 Nov 2026: now always after the pause, see *Food resolution › Search*). After the 0.6 s pause, unless something on the phone is named *exactly*
  (an everyday food or the person's own): "chicken thigh" or a brand is worth asking for even when the phone has other
  chicken; "eggs" is not. **Search more foods and brands** stays under the results for every other case, so an exact
  everyday match ("chicken breast") never hides branded products: one tap asks once, and the products follow the plain
  foods, each marked Brand or Generic (25 Nov 2026). An answer to an earlier question is still dropped
  when it arrives, failures still never remove the foods found on the phone, and it is still never per keystroke.
- **Your foods** stay first only when one of them is at least as good a match as the best everyday food, and at most 8
  are listed before the others.
- **Page size.** The API now asks USDA for 25 generic and 15 branded records (was 15 and 10): plain records were just
  past the first page. Still two requests per search, cached 24 h, the same budgets.
- **Catalog version 2** (77 foods): the raw breast (FDC 2646170, Foundation), raw thigh (2646171) and roasted thigh
  (172388), each a real USDA record normalized by the API (`build-common-foods.mjs --reuse` keeps every existing record
  byte for byte and looks up only new ones; for a local API with captured mail it confirms the disposable account). Raw
  potato, beef, salmon and rice records were not added: USDA's public trial key ran out that day; they are found online.

Tests: `food_relevance_test` (USDA's real answer to "chicken breast" as the API normalized it,
`test/fixtures/usda_chicken_breast.json`; preparation, cut, skin, brand, repeats, misspellings, French and Arabic,
broader aliases, raw/cooked reading), `food_search_test` (updated), `meal_log_ui_test` › search on screen (no AI request,
no automatic wider search for an exact everyday food, a corrected search, a brand asked once, French sent in English).

### Describe your meal (24 Nov 2026, `feature/food-search-describe-meal`)

**Where** (revised 25 Nov 2026). At the top of Add food, above search, the selected guide (Leon or Leona) invites it in
the usual speech bubble, its portrait joined to the bubble: "What did you eat?" · "Tell me the foods and amounts. I'll
work out the nutrition for you to review before anything is logged." · **Describe my meal** · "Uses 1 AI request when you
send." It is the only way in on the page (the earlier link row and bottom-card row are gone). The guide's portrait is the
page's search help (a sheet), so one face is on the page. With Me › Appearance › Show coach on Train and Eat off, or at
very large text on a phone narrower than 360 px, the same invitation is a plain full-width panel (no portrait; search help
beside the title); at that size the longer sentence is said as "You review it before anything is logged." so search is about
one screen down rather than two (no text or target is made smaller). It scrolls with the page: the title, the day and meal and the invitation scroll away, and the search
field stays at the top once reached; typing a search scrolls the field to the top so results come straight under it
(scrolling back shows the invitation again, nothing is removed). Not shown while picking one food for a meal.
What it offers follows what can really happen: at the month's limit it says so with the reset date and offers no new
request (**Finish my meal** only when a meal is already being prepared); on a server without `coach.meal-log` it says
describing a meal isn't available yet; search, barcode and the lists stay below in every case. Opening Add food, showing
the invitation or opening the conversation never calls the AI or uses the allowance. **Describe my meal** opens the
existing coach conversation for that day (an earlier day too) and the meal chosen in Add food, the field focused with
the example "I ate 120 g of chicken and 100 g of potatoes." as its hint (never sent by itself). The same words typed in
Eat's coach conversation are read the same way. No new card on Eat, no other chatbot.

**Flow.** "I ate 120 g of chicken and 100 g of potatoes" → **one** request (`POST /coach/daily`, kind `ate`) reads the
foods as words → the phone matches each to a real record with the same matcher as meal ideas and search
(`meal_ideas.dart` › `FoodMatcher`: bundled foods, the person's foods, foods seen on this phone, then at most 6 food
searches, which are free) → one draft card asks only what it cannot know, with buttons → **Review meal** opens the usual
`MealReviewScreen` (day, meal, every amount, add/remove, totals) → **Log meal** is the only action that records, through
the existing atomic `food.batch` (one operation ID: a double tap or a retry logs once; offline it waits in the outbox and
is sent once). Leaving the review or the conversation logs nothing; every change in the review is kept on the draft.

**What is asked, never guessed** (each answered on the phone, no AI):
- *Weighed raw or cooked?* only where it matters: the amount is a weight or volume, no preparation was said (as a
  preparation or in the food's own words: "cooked rice", "riz cuit"), and a record says raw or cooked for a food whose
  weight cooking changes (meat, fish, grains, pasta, potatoes, legumes, oats). Never for foods eaten as they come: the
  bundled categories Vegetables, Fruits, Dairy, Fats & Oils, Snacks and Beverages, and bananas, eggs, egg whites and tofu
  (`CommonFoodCatalog.eatenAsIs`); toasted is not a cooking state, so bread is never asked; yogurt says neither. Answered
  once, never asked again. The weight said stays (it is what was weighed); a count ("2 eggs") is not asked.
- *Which chicken?* when several records are equally good (raw breast and raw thigh for "chicken"): up to 3 buttons and
  **Search for another**. "Chicken" is never taken as breast; oil, butter or sauce is never added.
- *How much potatoes?* when no amount was said or it fits none of the record's own units: the usual amount form. Kilograms,
  ounces, pounds and litres are converted exactly; nothing converts between weight and volume or raw and cooked, and no
  standard portion is put in its place. A record of another preparation than said clears the amount (the existing
  safeguard).
- *No food record found* → **Find food** (Add food in selection mode, with the word in the search); everything else stays.
  A food typed by hand there is marked "your own values".
- Every food can be removed; **Add food** adds one; **Discard** drops the draft. Totals: "Total" once every food has a
  record and an amount, otherwise "So far, without potatoes" (the confirmed ones only, named as such). Unknown values stay
  unknown and partial sums say "known", as everywhere (`NutrientCoverage`). A food with a missing value never blocks
  logging once its record and amount are confirmed.

**Follow-ups** while a draft is open ("make the potatoes 150 g", "remove the chicken", "add one tablespoon of olive oil"):
common changes are on the card and in the review, free. A typed one is one more request (kind `edit`) that carries only
the draft's references and words (`d1 | Chicken breast · 120 g`) — never values, the journal, goals or anything else.
The change is applied to a new copy of that draft (the old card says "Replaced"), and only if the draft is still exactly
the one that was sent: a change made meanwhile, a discarded or logged draft, or another account means nothing is changed
and the reply says so. A logged draft is closed for good ("Logged. Change it in Eat from now on."): no later message logs
it again or edits history.

**Day and meal.** "Yesterday" is the day before today; otherwise the day the conversation is about. The meal said, else
the one chosen in Add food, else the time of day's. Both are changed in the review.

**AI usage** (docs/PLUS_PREVIEW.md): under the field, before sending, "Uses 1 AI request · 14 remaining this month" from the
server's own count ("… can't be checked right now" while it is unknown; no count on a server without allowances). One
description is one charged request whatever the number of foods (see *More than twelve foods*);
a typed follow-up that changes something is one more; answering questions, matching, food searches, amounts, review and
logging are never charged. A reading with no usable food or change is `unsupported` and not charged. At the limit the
existing limit text and reset date show, and the line under the field reads "No AI requests left this month · they
come back on …"; the words and the draft stay, and the draft can still be reviewed and logged
(Log meal is never behind the allowance). Offline: "Understanding a new sentence needs a connection" with the words kept
for an explicit Try again (same request ID); nothing is sent later by itself.

**More than twelve foods** (25 Nov 2026). The model is told to list every food, never to stop early. The server reads the
first 12 into the draft and returns the next 12 by name (`intent.extra`, checked like any name); each is shown on the card
("pickles: past the first 12 foods…") with **Add with Add food** (the usual Add food, not selection, for the draft's day
and meal: logged on its own) or **Leave out**. The meal is not complete, has no Review and its sum says "So far, without
pickles", until each is added or left out. When the rest cannot all be named (more than 24, or a name that does not
check out) none is named: the reply says so and asks for the rest in a new message after logging, the card says the rest
is not in this meal, and only **Leave out the rest** makes it complete. Nothing is invented. An older app ignores `extra`
and still says some foods were left out.

**Compatibility.** Capability `coach.meal-log` (declared with `coach.daily`'s rule). Only to a server that declares it does
the phone send `features: ["log"]` and a draft; an older server gets neither, and Describe your meal says "isn't available
on this server yet" while search and logging work as before. No migration, no new configuration, client contract 2.

Code: API `DailyCoachService` (kinds `ate`/`edit`, `foods`/`edits` in the strict schema, `MealFood` checks), app
`meal_ideas.dart` (`FoodMatcher`, `resolveMeal`, `answerState`, `chooseRecord`, `applyMealEdits`, `draftWords`),
`day_coach.dart` (`mealCard`, `DayIntent.draft`), `day_coach_screen.dart` (draft operations and the card),
`MealReviewScreen` (`onChanged`, `logLabel`). Tests: API `MealLogTests`; app `meal_log_test` (matching, questions,
conversions, brands, totals, edits), `meal_log_ui_test` (the journey from Add food, follow-ups and late answers, allowance
and offline, usage line, older server, suggestions never logged, fr-CA/ar at 320 px and 1.6× text).

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
  there. The wider search is never run per keystroke: it runs on a tap, or once after a 0.6 s pause when nothing on
  the phone is named exactly, and an answer is reused while the search screen stays open.

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

### Food resolution (26 Nov 2026, `feature/food-resolution`)

**The bug it fixes** (IPA 86, reproduced locally with no model involved, `food_resolution_test` › the reported sentence):
"100 g of cooked chicken thighs and 130 g of cooked potatoes" became *Chicken thigh — roasted, meat only* and *Potato —
baked, with skin*, ready to review. The model's words were fine (`chicken thighs`, `potatoes`, `cooked`). Retrieval stopped
at the first source with a hit (the bundled catalog) and never looked further; "cooked" matched any cooking method; the
catalog held one cooked thigh and one potato; and a single "sure" match was taken as the answer. Roasted, meat only, baked
and peel eaten were never said. Searching "potato" showed one ordinary potato for the same reason (an exact local name
suppressed the wider search, and the catalog had one).

**Four parts, one set of food semantics** (`food_traits.dart`, `food_resolution.dart`, `meal_ideas.dart`):

- *Interpretation* — what was said. `readTraits` reads a text into typed attributes, the same way for what a person said
  and for a record's description: family (chicken, potato, rice…), cut or part (breast, thigh, ground, white), state
  (raw/dry or cooked), method, skin or peel, fat level (2 %, 90 % lean…), variety (white/brown, whole wheat, Greek), added
  fat, additions (breaded, sauce, flavoured, restaurant). Phrases before words, in English, Canadian French and Arabic
  ("skin not eaten", "sans peau", "بدون جلد", "non pelé", "مطبوخة"); "from raw", "from frozen" and "dry heat" are read as
  what they are (what it was made from, a way of cooking), never as the weight basis. An attribute not mentioned is
  absent: **unknown, never false**. `*` is a record saying a detail is not specified (USDA's "NS as to …", "NFS"). Said
  details come from the person's own words for the food (`evidence`, below), never from what the model added.
- *Retrieval* — `FoodMatcher.candidates`: the bundled catalog, the person's saved foods and foods seen on this phone, all
  at once (where a record comes from orders it, it never stops the look); then, only when none of them is compatible, the
  account's food search, at most 6 times per request, once per query, and remembered by `FoodDiscovery` for ten minutes, so
  answering a question never repeats a provider call. A search that does not answer is reported as such (`unavailable`).
- *Ranking* — unchanged `relevance` for manual search (tier, then specificity), with source as a factor only (see Search).
- *Resolution* — `resolveFood`, pure, with explicit outcomes: **resolved** (one record), **clarify** (a choice, or raw or
  cooked first), **none** (Find food); the caller adds **amount** (the record's units do not fit) and **unavailable** (the
  search did not answer). The reason and the unresolved details travel with the item to the card.

**Everyday defaults** (revised 26 Nov 2026, owner's clarification: sensible defaults, not a questionnaire). When the
details are not said and the catalog has a **reviewed general record** for the food (`attrs.generic`: USDA's own record
for it when details are not specified, e.g. "Potato, NFS", "Egg, whole, cooked, NS as to cooking method", "Chicken, NS as
to part and cooking method, NS as to skin eaten", "Rice, cooked, NFS", "Milk, NFS", "Yogurt, NFS", ground beef of
unspecified fat), that record is taken **without a question** when it shows everything said and names nothing that was
not. It is said to be general on the card ("2 eggs (100 g) · Eggs (general) (Whole · cooked, way not specified)",
"Uses a general nutrition estimate. Change the food or portion for a closer match.") and in the review and the journal
("Eggs (general)"); a standard portion is said ("Standard size: 1 egg (50 g)"); Change food and Change amount are on the
item. Explicit words win ("raw eggs", "egg whites", "fried eggs", "boiled peeled potatoes" take that record). A record is
never a default only because it is the only one: the default is the catalog's reviewed decision, not a score. A
question is asked only when no general record fits and the records differ in a detail that matters for the family (the
profiles below): cooked chicken thighs (no general thigh record — every thigh record states the skin, and the general
chicken record cannot show "thigh"), raw chicken, dry rice (white or brown), bread (white or whole wheat). Raw or cooked
is still asked for a weighed amount (it decides what the weight means). No general record is used for pasta (plain "pasta"
means regular pasta) or bread (none exists).

**Acceptance rules for a described meal** (what someone ate is never chosen for them):

1. A record that *contradicts* anything said is not a candidate (raw for cooked, skin eaten for skinless, another brand,
   another family: sweet potato for potato). A record with additions (breaded, sauce, flavoured, restaurant) only when said.
2. A record taken without asking must be **reviewed** (the catalog's own `attrs`), must **prove** everything said (a record
   that does not say it, or says it is not specified, cannot prove "roasted" or "no added fat"), and must **add nothing
   material that was not said**. One record found is not proof; a close name is not proof; a score is not proof.
3. What is material is a small, documented profile per family (`familyProfiles`): *asked* details (chicken: part, raw or
   cooked, skin; potato: raw or cooked, method, peel; rice/pasta: kind, dry or cooked; ground beef: part, fat level, raw or
   cooked; milk: fat level; yogurt: kind and fat; bread: kind; eggs: part; fish, oats, couscous, legumes: raw or cooked) and
   *defaultable* details, where USDA's "not specified" record is taken without asking (cooking fat everywhere — asking about
   oil for every food would be endless; the method of eggs, chicken, fish, grains). What the plain word means is a default
   (an egg is a whole egg, pasta is regular pasta). Any family without a profile only checks what was said. Raw or cooked
   is asked only for an amount weighed or measured; for whole items eaten, raw records are left out when cooked ones exist.
4. Several reviewed records with the same material details are one choice (equivalence by attributes); the first in the
   catalog's order stands for them. Values from different records are never combined.
5. Saved and seen foods and the food search's records are candidates beside the catalog, but never taken without asking.
   Choosing one is the person's confirmation. Nothing said becomes a personal default.

**What the person sees** (the Leon/Leona draft card, no new screen): for each item, at most one question at a time —
"Weighed raw or cooked?" first when it matters, then **"Which matches your potatoes?"** with real records, three at a time
and up to six with **More options** (the ones that take least for granted; options never invented, never a combination), "Not said: how it was cooked, skin or
peel", **Search for another**, **I'm not sure** and **Remove**. Each item is resolved on its own; answered ones stay. A ready
item says its amount and record and offers **Change food** (the picker starts from the same amount when it still means the
same thing — grams of food in the same state — and from the new record's own start otherwise; no yield or density is ever
applied), **Change amount** and **Remove**. After a choice the result is announced to a screen reader (the button is gone).

**I'm not sure** offers one reviewed record, said before it is used: "Use Chicken (Cooked · part, way and skin not specified) as an
estimate? Its own values are used as they are, and may differ from what you ate." — USDA's not-specified record when
there is one, else the reviewed record that takes least for granted. Accepted, it is named "Chicken (estimate)" through the
review and the logged entry (the entry's own name: no new field), with that record's real values. Without a reviewed
record nothing is offered: Search for another or Find food.

**Unresolved items never vanish**: the total says "So far, without potatoes"; Review and Log meal wait until every item
is resolved, removed or accepted as an estimate. Nothing is logged automatically.

**Suggestions are not descriptions.** Meal ideas keep their own policy: a preparation the idea proposes is part of the
suggestion, and among equally good reviewed records an idea takes the one that adds the fewest details (`_plainest`:
"eggs" → eggs cooked in a way not specified, never an NFS record when another is there). Ideas never write the journal.

**The model contract** (`POST /coach/daily`, kind `ate`, additive): each food also has `evidence`, the person's own words
for it copied from their message. The server keeps it only when it really is part of the message (case and spacing
aside, 120 characters at most), else it is null; the phone reads said details from the evidence only, so "chicken
breast" or "roasted" added by the model is not taken as said. Without evidence (an older server) the phone reads the label,
name and preparation, as before. One provider call per description, the same allowance, guard, reservations, charging and
request-ID rules; every question, choice, search, amount, estimate and calculation here is local and free.

**Compatibility** (checked against the response shape of the server deployed now, main 1ebe45b: `foods` without
`evidence`, search without `more`; `food_resolution_test` › retrieval and compatibility).
- *Works before deploying this API*: Describe your meal end to end (the deployed server already declares
  `coach.meal-log`), the same everyday defaults, questions, estimates, Change food/amount, review and logging, search with
  its wider answer, Looked up before, the catalog. All of that is on the phone.
- *Missing original words*: the deployed server sends no `evidence`, so the phone keeps the person's sentence
  (`withSentence`) and reads each food's details only from **that food's own part of it** (`foodPart`): the sentence is
  split at "and", commas, "+", "then", "et", "puis", "و", and a part belongs to a food when it names that food's family
  (or, for a food without a known family, holds every word of its label) and no other family. Nothing the model added is
  trusted: "breast" or "roasted" for "I ate 100 g of chicken" is not taken as said, and a word said for one food never
  counts for another ("boiled potatoes and chicken": the chicken is not boiled; "raw carrots and cooked chicken": the
  chicken is cooked, never raw). When no single part belongs to the food (two foods in one phrase, "potatoes with
  chicken"), nothing is taken as said for it: the reviewed general record is used if it fits, otherwise the usual
  concise question (raw or cooked for a weight, the cut, the skin).
- *Needs the new API*: per-food evidence from the model (the words it quotes must appear in the sentence; a quoted span
  that names two foods is narrowed the same way), the prompt asking for it, and `more` (without it the "more results" note
  is not shown). Older apps ignore both fields. Both shapes are tested (`food_resolution_test` › mixed foods).
- No capability, migration or configuration change. Drafts kept from IPA 86 still read; nothing logged changes.

**Catalog version 3** (131 foods, eight of them reviewed general records, `scripts/common-foods.spec.json`): every entry has reviewed `attrs`; 46 new records from
the official FoodData Central downloads (FNDDS 2024-10-31, Foundation 2026-10-29, SR Legacy 2018-04) instead of repeated
trial-key calls: a local stand-in (`scripts/usda-dataset-server.mjs`) answers the API's own search call from the files
(kept outside git), so each record is the GoHard API's own normalization (`UsdaProvider.Parse`), and
`build-common-foods.mjs --verify` checked all 77 earlier records against it: same records, names, bases, versions and
portions; differences only in rounding (the live search keeps one more decimal, ≤ 0.6 %), the order of FNDDS's additional
descriptions, and portion order. Earlier records stay byte for byte (`--reuse`). Coverage matrix:

| Family | Variants in the catalog |
|---|---|
| Potato | raw (with skin); boiled peeled; boiled skin eaten; baked skin eaten; baked peeled; roasted skin eaten; general: cooked; boiled, baked and roasted with peel not specified |
| Sweet potato | raw; baked; baked, no added fat; boiled; cooked, way not specified |
| Chicken | general: cooked, part, way and skin not specified |
| Chicken breast | raw skinless; raw with skin; cooked (way not specified) skin not eaten / skin eaten; baked or roasted, skinless |
| Chicken thigh | raw skinless; raw with skin; cooked skin not eaten; cooked skin eaten; roasted meat only |
| Chicken drumstick | raw with skin; cooked (way not specified) skin not eaten / skin eaten; baked, broiled or roasted skin not eaten / skin eaten (25 Nov 2026) |
| Chicken wing | raw with skin; cooked, way not specified; baked, broiled or roasted (25 Nov 2026) |
| Chicken leg (drumstick and thigh) | cooked, way not specified, skin not eaten / skin eaten (25 Nov 2026) |
| Chicken liver | raw; cooked, simmered (25 Nov 2026) |
| Rice | general: cooked, kind not specified; white and brown, each dry and cooked |
| Pasta | regular dry and cooked; whole wheat dry and cooked |
| Oats | dry; oatmeal cooked with water, no added fat; oatmeal cooked, way not specified |
| Ground beef | 90 %, 85 %, 80 % lean raw; 90 % broiled patty; 80 % pan-browned; cooked, fat level not specified |
| Fish | salmon raw and cooked; cod raw and cooked; tilapia raw and baked or broiled; tuna canned in water |
| Eggs | general: whole, cooked, way not specified; whole raw; boiled or poached; fried; whites |
| Milk | general: fat level not specified; whole, 2 %, 1 %, skim; almond (its own family) |
| Yogurt | general: kind not specified; Greek plain, milk not specified; plain low fat; plain whole milk; Greek nonfat; Greek whole milk |
| Bread | whole wheat; white |
| Legumes | black beans, chickpeas, lentils cooked from dried; lentils dry |
| Couscous | dry; cooked |

Genuine gaps, said rather than filled with a lookalike: turkey other than roasted breast,
beef cuts other than ground, pork other than tenderloin, shrimp raw, fried or mashed potatoes, sweet potato skin
variants (the records do not state it), rice kinds (basmati, jasmine), bread kinds (rye, sourdough, pita), flavoured
yogurts, scrambled eggs, legumes with "fat not specified" (FNDDS has none: the choice is no fat or fat added), oats cooked
with milk, and plant milks other than almond. They are found by the food search and confirmed by the person. Canadian
brands are only what USDA's branded data holds.

**Search** (Add food): the phone's foods are shown at once; the wider search is now asked after the 0.6 s pause **even when
a bundled food matches exactly** ("potato" shows the plain potatoes, then sweet potatoes, then products, and the wider
answer below). Once per question, remembered, stale answers dropped, failures still never remove what is shown, offline
search unchanged, nothing per keystroke. A wider answer that names the food better than anything on the phone is listed
first. Foods only met in earlier searches are listed as **Looked up before**, no longer under "Your foods". When a
page comes back full, the API says `more` and the screen says "More foods match than are shown: add a word to narrow the
search". The limit is GoHard's, not USDA's: FoodData Central's search pages (`pageSize` up to 200, `pageNumber` through the
whole result set, per its API specification), while GoHard's adapter asks only for the first 25 basic and 15 branded
results and does not page. Narrowing reaches the rest; paging is not added. Search and lookups use no AI allowance.

Tests: `food_resolution_test` (19: the reported sentence and its raw-or-cooked variant; explicit descriptions; "chicken"
and "potato"; one underspecified record; rice, pasta, ground beef, milk, yogurt, bread, sandwich, couscous; contradictions
and brands; negation, French, Arabic; evidence; saved records beside the catalog; one search per query, Try again;
estimates; follow-up amounts), `meal_log_test` (13, rewritten to these rules), `meal_log_ui_test` › food resolution on
the card (the reported sentence through Log meal with an estimate, one request; Change food keeping the amount;
unavailable), search tests updated for the catalog (`food_search_test`, `food_relevance_test`), API `MealLogTests`
(evidence kept and dropped) and `FoodDataTests` (`more`). Renders: docs/evidence/food-resolution/ (en light, fr-CA dark,
ar at 320 px with 2× text).

### Food identity (25 Nov 2026, `feature/food-identity`)

**What was wrong** (reproduced, `food_identity_test` › the reported screen). "Which matches your chicken drumsticks? Not said:
which part" offered giblets, liver, heart and gizzard. (1) Retrieval searched the model's `name` only, and the prompt keeps
it at the person's detail with the part in `noun` ("chicken", noun "drumstick"): USDA's first page for "chicken" is feet,
skin, back, tail, liver and dishes, no drumstick among 25 of 847 (recorded live). (2) Every record of the family was
relevant, a part its name did not state was no contradiction, and every searched record was offered whatever it cost.
(3) "Not said" listed details the person *had* said but a record could not show. (4) The catalog had no drumstick.

**Identity first** (one representation for words and records, `food_traits.dart`). Parts are read in English, Canadian
French and Arabic, singular and plural (drumstick/pilon/ساق·دبوس, wing/aile/جناح, whole leg, liver/foie/كبدة, heart,
gizzard, giblets, neck, back, feet, tail, chicken skin, whole bird); a record naming several parts is the one that is
another food first ("Chicken, skin (drumsticks and thighs)" is skin), then the whole bird, then the whole leg ("Chicken leg,
drumstick and thigh" is a leg). USDA's "NS as to cooking method" is cooked. A record whose name, before its first comma,
holds words this file does not know ("Orange chicken", "Chicken spread", "Soup, chicken") is another food made with it
(`productWords`; a leading category such as "Fish," is skipped). Then, before any ranking (`resolveFood`):
- a record must **show** the family and, for a known family, the part said: unknown is neither a match nor a
  contradiction, so a record that does not state "drumstick" (or says "NS as to part") is never taken nor offered;
- liver, heart, gizzard, giblets, neck, back, feet, tail and skin (`explicitParts`) only when that part was said, never
  for "chicken" or for another part; another food made with it only when its words were said;
- choices are the best rank only: what was said and the record shows first, then the fewest details taken for granted
  or left unknown, then reviewed, then source order; one per set of material details; three shown, up to six with More
  options. "Not said" is only what the person did not say (`unresolved`); a said detail a record cannot show is kept
  apart (`unshown`) and never called "not said";
- when no record of the food is there, a reviewed broader record may be offered as a **substitute**, said so ("Chicken
  (Cooked · part, way and skin not specified) is not a cooked chicken thighs record. Use it as a broader estimate?") and
  taken only on a tap; the ready item says "A broader record than what you said, used as an estimate." "I'm not sure"
  follows the same rule. A search that did not answer stays Try again, never a substitute or "nothing found".

**Retrieval** keeps the identity: the query is the name's identity words plus the family and part the person said
(`identityQuery`: "chicken drumstick" for the name "chicken" with "3 cooked chicken drumsticks", "3 pilons de poulet cuits"
or "3 سيقان دجاج مطبوخة"); preparation is left to the records. USDA's search, checked live 25 Nov 2026 (DEMO_KEY, 10 an hour):
plain keywords work and are combined by OR ("chicken drumstick" 867 hits, "chicken" 847); the first page for "chicken
drumstick" is all drumsticks (recorded in `api/tests/GoHard.Api.Tests/Fixtures/usda_search_chicken_drumstick.json` and
`usda_search_chicken.json`; the app fixtures are made from them by the API's own `UsdaProvider.Parse` and kept identical by a
test). USDA's front end also answered valid requests with an nginx 400 (`x-nginx-intercept: portal-foods-search`) that
succeeded moments before or after, and on every attempt at the required-word operator ("+chicken +drumstick"), at page 2
and at a plural; so the operators and paging USDA documents could not be verified live and are not used. A 400 is a failed
lookup (retried once, never remembered, never "no such food": `An_intercepted_400_is_a_failed_lookup_not_an_empty_answer`).
No second query or paging is added: the identity query finds the food on page 1, and the request budget (three searches
per request, each query once) is unchanged. No API change.

**Manual search** (Add food): a catalog food that is another part, or a part that is another food, is not listed for a food
named by its part ("chicken thigh" never lists the whole leg; "chicken" never lists liver); the wider answer lists the food
searched first and **Related foods** after (another part, organs, dishes made with it). Nothing is hidden; brands as before.

**Short, truthful labels**: a record found by the search is offered by what its own name establishes ("Drumstick · stewed ·
skin eaten", in each language) with its own name and source under it ("Chicken drumstick, stewed, skin eaten · USDA
2706014"); nothing it does not state is added and no preparation it states is hidden. Catalog records keep their reviewed
names and preparations. The record, its ID and its values are unchanged.

**Weighed with the bones** ("260 g cooked chicken drumsticks weighed with bones and skin; I did not eat the skin"; also
"bone-in", "on the bone", "avec les os", "بالعظم"): the record's values are for what is eaten, so 260 g is never used as
eaten. The item asks "Chicken drumstick · 260 g weighed with bones: how much was eaten?" with **Bones and skin left (g)**
(eaten = weighed − left, only for less than weighed) or **Enter weight eaten** (the amount form). The ready item keeps
"Weighed 260 g with bones · 80 g left". No bone share is assumed: USDA gives edible portions ("1 drumstick", 50 g without
skin), not a yield for this case, so none is offered. A sentence part that only adds details ("I did not eat the skin")
belongs to the food before it (`detailOnly`); two foods of one family keep their own parts ("chicken breast and chicken
thighs").

**Catalog** (143 foods, +12, same build path and provenance, `--reuse`: earlier records untouched): chicken drumstick
(FNDDS 2706000, 2706001, 2706002, 2706003; Foundation 2727566), wing (FNDDS 2706056, 2706057; Foundation 2727568), whole
leg (FNDDS 2705982, 2705983), liver (SR Legacy 171060, 171061), each with reviewed attrs, none marked general (USDA has no
drumstick record with the skin not specified, so the skin is the one question for "cooked drumsticks"). Audit of
neighbouring gaps with the same failure: organs, skin, giblets and whole birds of every family are now never offered unless
said, and dishes or products made with a food only when their words are said; turkey, beef and pork cuts other than those
listed remain search-only (above).

**Defaults kept**: "2 eggs" (general cooked egg, standard size), cooked potatoes (general), explicit raw/boiled/fried eggs
and peeled/skin-on potatoes, "chicken" (general cooked chicken). Questions still asked: raw or cooked for a weight; the skin
for drumsticks or thighs (no general record); which part for plain raw chicken; the size when a count fits several of the
record's portions.

AI: unchanged. One request per description, nothing per food, search or answer; choices, the bones answer, review and
logging are local and free. Tests: `food_identity_test` (20: the reported screen before and after; organs, other parts and
dishes mixed in; drumstick against thigh, leg, breast, wing and liver; a remote record absent from the catalog; roasted and
skinless; eggs and potatoes; mixed preparations and one family twice in both response shapes; bones in both shapes; French,
Arabic, singular, plural; offline, nothing suitable, the search budget), `meal_log_ui_test` › food identity on the card (7:
the reported sentence beside untouched eggs through Log meal, one request; search records' labels; the only food removed
then a new sentence; More options; the bones flow through Log meal; fr-CA and ar at 320 px with 1.6× text), API
`FoodProviderTests` (recorded live searches, the app fixtures, the 400). Renders: docs/evidence/food-identity/ (en light,
fr-CA dark, ar at 320 px with 2× text). Device (`integration_test/journey_food_identity_test.dart`, emulator Pixel_9 at
system font scale 1.6, local branch API on a disposable database, coach **stub**): bones flow logged as 180 g, 277.2 kcal,
allowance 0 → 1; drumstick choices; French and Arabic cards; docs/evidence/food-identity/device/. The stub copies a whole
phrase into `name`, which the server limits to 60 characters, so the device sentence is "260 g roasted skinless chicken
drumsticks on the bone" (a live model gives a short name).

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
  (no goal bars or percentages on it, food or water); only today is. Since 30 Oct 2026 the phone records each day's
  goals (docs/EAT_COMPANION.md › Goal history) and since 19 Nov 2026 Eat's rings compare an earlier day with that
  recorded goal only; a day without one says "No goal recorded for this day".
- Goals and **Customize tracking** are in Eat only (since 23 Nov 2026 in **Nutrition settings**, docs/FOOD_DATA.md › Compact top); Today shows the water line and its actions.

### History & trends (20 Oct 2026, GoHard_Nutrition_Trends_Claude_Handoff)

Since 30 Oct 2026 its top bar opens the **Weekly report** (calories and protein for one Monday–Sunday week, with goals compared only on days this phone recorded them): docs/EAT_COMPANION.md › Weekly report. The trends screen itself still compares nothing with a goal.

Eat's **History & trends** (since 23 Oct 2026 a full-width panel, key `eat-history`, at the end of the page since 23 Nov 2026; it replaces the History screen) shows what was logged
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

### Eat page order (23 Nov 2026, feature/eat-meals-first)

The day's meals come straight after its summary, so reviewing and logging them is the first thing below it. From the
top: date header › the coach's message, or with the coach off its compact panel (briefing or usual meal) in the same
place › nutrition summary (Log food, Saved meals & recipes, water, goals and tracking; compacted since, see Compact top) › *Today's meals* (an
earlier day: *Meals*) with Breakfast, Lunch, Dinner, Snack and each meal's own actions (Add food, Same as yesterday,
Copy meal, Save as meal) › the logged-food note and Meal reminders › **Eating out** › **History & trends**. The same
order holds for today and earlier days, empty and logged. It is one list in reading order, so screen readers traverse
it as shown; it ends with the floating bar's height. The panels, their keys and styling are unchanged; Add food keeps
its Eating out entry. Back from a logged Eating out order, Eat brings the meals' heading into view (the order may have
gone to another meal or day, so no single group is picked). Today's own layout is untouched.

At 390 × 844 with the render fixture (`render_test.dart` › eat layout, scroll offset 0) the Breakfast group starts
285 px higher in English (1472 → 1187), 305 in French, 297 in Arabic; on an earlier empty day 1074 → 789. With 2× text at
320 px it starts 822 px higher (3452 → 2630; French 4095 → 3070, Arabic 3537 → 2746). With a coach message and the
summary it is still below the fold at 844 (on an empty earlier day its heading peeks under the floating bar): the change
does not promise the first meal above the fold. Renders: after in `docs/evidence/design/eat-layout/` and
`docs/evidence/localization/{fr,ar}/design/eat-layout/`, before (main 27877fe, same test) in
`docs/evidence/eat-layout-before/{en,fr,ar}/`; the `*-scrolled-700` pair shows the same viewport at the same offset.

### Compact top (23 Nov 2026, feature/eat-compact-top)

Eat's top was made shorter by hierarchy and less repetition, not by smaller text or targets, so the meal journal comes
sooner. The page order is unchanged (Eat page order above).

- **Coach** (`TabCoach(compact: true)`, Eat only): a smaller portrait beside the bubble (62 × 78 at 380 px and up, 56 ×
  70 from 340, 50 × 62 narrower); the briefing in its compact wording (docs/EAT_COMPANION.md), the same state from the
  same assessment without the figures the rings show; one action (What could I eat?, Find something to eat once every
  goal is reached) as a strong accent text button, and Ask me (free text, Help with today). Without goals the bubble no
  longer repeats Set goals: the summary's own **Set daily goals** is right under it. Coach off: the compact panel in the
  coach's place, same wording. Opening Eat asks no AI.
- **Summary** (`NutritionSurface`, Eat only): no photograph. NUTRITION with how complete the figures are ("Totals",
  "Known totals", or "No food logged yet" with "Nothing is recorded for this day…" and the daily goal). Calories and
  protein side by side when two columns of 124 text-scaled px fit (360–430 px at normal text; stacked at 320 px and with
  large text): the ring beside the name, the amount, "of" the goal, then one line: what is left in the state's colour
  when it is exact, otherwise the state in words (reached, over by, "Known intake", no goal). The percentage moved into
  details. Assessment, colours, rounding, unknown-versus-zero and earlier-day goals are the shared ones, unchanged.
- **Actions**: Log food (the page's one filled button), then **Saved meals & recipes** beside it when its words fit in
  two lines there (measured, whole words), otherwise under it. Then water (when shown), and one row: **Nutrition details**
  (folded each visit; an expandable button: the recorded composition or carbs and fat, each goal's share, the longer
  notes about missing values) and **Nutrition settings** (a sheet: Edit goals / Set daily goals, the existing goals
  editor with Help me set my targets, and Customize tracking). **Set daily goals** is also on the summary while no goal
  is set. Opening details or settings logs nothing and asks nothing.
- **Today is unchanged**: it keeps its compact rings (share and state beside each), its photograph and layout; its
  renders before and after differ only in the guide portrait's time-dependent pose.

At 390 × 844 with a notched phone's insets (bar top 738, Arabic 736), the render fixture of `render_test.dart` › eat
compact (a returning account, introductions seen, scroll offset 0), the first meal's heading (Breakfast) moves from
864 to 609 on an empty day, with its Add food (644–692) fully above the bar; with food logged it moves from 1,155–1,283
to 680–711, the heading fully visible and Add food (801–880) still under the bar. French: empty 1,001 → 760, one food
1,290 → 822, neither above the bar (longer words wrap the coach's actions and the settings row). Arabic: empty 809 →
687 (heading visible, Add food not), one food 1,188 → 735 (not fully). 360 × 780: empty 908 → 645 (heading visible),
one food 1,360 → 764. 320 px at 2× text (whole page): 2,711 → 1,627 in English, 3,228 → 1,851 French, 2,923 → 1,696
Arabic. Nothing is promised above the fold for every language, state or text size. Renders: after in
`docs/evidence/design/eat-compact/` and `docs/evidence/localization/{fr,ar}/design/eat-compact/`, before (acf973f,
the same test) in `docs/evidence/eat-compact-before/{en,fr,ar}/`. On the Pixel_7 emulator (411 × 914, `journey_eat_compact_test`) the empty day showed Breakfast and its Add food above the bar; with one food logged, the heading only (`docs/evidence/eat-compact-device/`).

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

## Saved meals and recipes (23 Oct 2026, GoHard_Saved_Meals_Recipes_Claude_Prompt)

> 29 Oct 2026: the review's actions are now **Log this time**, **Update saved meal** and **Save as a variation**, with a
> note saying what each changes; usual-meal suggestions open the same review. See docs/MEAL_HABITS_REMINDERS.md.

Four things stay distinct, in storage and on screen:

| Thing | What it is | Where |
|---|---|---|
| Favourite / My food | one reusable food (unchanged) | `saved_food` records, Add food lists |
| Saved meal | several foods with default amounts (2 eggs + 60 g oats) | `saved_meal` record, `kind: meal` |
| Recipe | a whole batch of ingredients and the servings it makes, optionally its weighed finished weight | `saved_meal` record, `kind: recipe` |
| Logged food | what was eaten on a day | `food` records (the journal) |

A saved meal or recipe is a **template**. Browsing, creating, editing, previewing, duplicating or deleting one logs
nothing. Logging copies; it never links history to the template.

**Where.** Eat: "Saved meals & recipes" beside Log food in the day's panel (History & trends stays as it was); each
meal group with food has a quiet **Save as meal** beside + Add food (copies those entries' snapshots and amounts into
a new editor; logs nothing again). When both labels do not fit on one line (French, large text, narrow phones; since
27 Oct 2026) Save as meal goes under Add food, its label in line with Add food's; both keep 48 px targets. Add food: a "Saved meals & recipes" row in its bottom card, which keeps the day and
the meal chosen there. The library has Meals / Recipes, New meal / New recipe, search (from 4 items), honest empty
states, rows with the count and a truthful energy line ("370 kcal", "400 kcal known"), and a menu with Edit, Duplicate
and Delete (delete is confirmed; history stays).

**Editor** (`MealEditorScreen`): name; foods added through Add food in its **selection mode** (`LogFoodScreen(pick:
true)` → `FoodFormScreen(pick: true)`, "Use this amount"; no meal or date is asked and nothing is written to the
journal); each food's amount and unit changed in that same amount form (same units and conversions, so 1 serving never
becomes 1 g); remove; for a recipe the servings the batch makes and an optional finished weight; totals (meal, or
batch and one serving). Save is the main action; Save as new on an existing one; Discard changes (confirmed) on a
changed one. Every change is kept at once as this account's `meal_draft` (local only), so back, a language change or
a restart loses nothing; unsaved new ones are listed in the library. A value corrected in the amount form is kept by
rebasing it onto the food's basis and crediting the food as the person's own (as My foods does). Each component keeps
its food snapshot (identity, basis, values, portions, source; the photograph and long description are dropped to keep
definitions bounded), `quantity` and `unit` id, and the amount in words as it was said.

**Review before logging** (`MealReviewScreen`) works on a copy taken when it opened, so an edit from another phone
never changes what is on screen. Meal: ½×, 1×, 1½×, 2× or Other… (above 0, at most 20), always from the saved amounts
(no drift); any food changed, removed or added for this time only. Recipe: servings, or grams of the finished batch
when it was weighed (switching converts through the person's own servings and weight; without a weight grams are not
offered, and the raw ingredients' weight is never used); the batch's ingredients can be changed for this portion only.
The day and meal can be changed; that records nothing. **Log meal / Log portion** is the only action that records food.
**Update saved meal** (confirmed: "the amounts shown become the saved amounts, as one meal") and **Save as new** (asks a
name) change templates only. For a recipe, **Edit recipe** opens the full batch definition; a portion never guesses how
a batch should change. Cancelling or leaving records nothing.

**Logging.** A saved meal becomes one ordinary entry per food (its own snapshot `{item, quantity, unit}`, values
rounded to two decimals like every entry), no total entry. The entries and ONE command `food.batch` (`POST
/food-entries/batch`) are written in one local transaction; the server records all of them in the command's
transaction or none (any invalid entry, a reused ID or more than 30 refuses the whole meal). The review owns one
operation ID, so rapid taps and retries after a lost answer replay the same operation; the outbox keeps the exact bytes.
The other entries carry `parentId` = the first, so a refused meal is reviewed and removed as one. A recipe portion is
ONE entry named after the recipe whose `source` is `{recipe: <the whole batch, with its id and revision as
provenance>, portion: {quantity, unit: serving|g}, partial?}`, sent as `food.recipe.create`/`.update` (same
endpoints). Its ingredients are never logged as separate entries. Changing a logged portion opens it on its own
snapshot: new amounts are worked out from that frozen batch, never from the recipe as it is now. Editing or deleting a
template, a provider change or a custom-food change touch no logged entry. Recipes are not nested: a recipe portion in
a saved meal is a frozen food of its own.

**Coverage rules.** One path for every screen: `NutrientCoverage` (`calculate` for entries, `ofParts` for a meal's
foods or a batch's ingredients; `NutrientTotal.times` for a share or a multiplier). Per nutrient: a stated zero is a
known zero; no value is unknown; a known sum with some parts missing is shown "… known" and is never complete; complete
only when every part is known. For a recipe portion with a partial nutrient, `macros` holds **null** (unknown) and
`source.partial` holds the known part. Compatibility rule: an older app ignores `partial` and therefore sees
"unknown", never a partial sum as a total; this app adds the known part to the day's known total and keeps the day
incomplete (Today, Eat, the meal subtotal, the entry row, History & trends, and the goal line, which states no
remainder while incomplete).

**Sync and compatibility.** `saved_meal` records: owned, revisioned, tombstoned (`PUT /saved-meals/{id}`, `POST
/saved-meals/{id}/delete`, snapshot `savedMeals`), conflicts held for review like saved foods. An editor or a review
compares the definition's content (canonicalised, so the account's jsonb echo of our own save is not a change) with
what it started from and asks before saving over a change made on another phone; a deleted one can only be saved as
new. Capability **`food.saved-meals`** covers definitions, `food.batch` and recipe portions: until the server
declares it (unknown waits too) those commands stay pending and nothing unsupported is sent; ordinary entries still go.
If the server has said it lacks it, the screens say so and Save/Log are disabled while drafts stay on the phone. A known
compatible account works offline. Client contract stays 2 (only additive fields). Bounds, on both sides: 30
components, names ≤ 120, quantities > 0 and ≤ 100,000, yield > 0 and ≤ 1,000, prepared weight > 0 and ≤ 100,000 g,
definition and recipe-portion snapshot ≤ 48,000 characters (ordinary snapshots stay ≤ 16,000). Account erasure
cascades `SavedMeals`; drafts are local and owner-scoped.

**Deployment order.** The API migration `AddSavedMeals` (additive: one table) and the capability must be deployed
(push to `main` → Railway pre-deploy migrates) before the IPA's saved meals reach the hosted account. Until then the
hosted API does not declare `food.saved-meals`, so an IPA keeps those changes on the phone and says so.

Code: app `features/nutrition/saved_meals.dart` (model, `MealMath`, repository), `saved_meals_screens.dart`,
`food_repository.dart` (`logMeal`, recipe drafts), `nutrient_coverage.dart`, `data/sync.dart`; API
`SavedMealService`, `FoodService.CreateManyAsync`, `Endpoints.cs`. Tests: `test/saved_meals_test.dart`,
`test/saved_meals_ui_test.dart` (renders with `GOHARD_RENDER`), API `SavedMealTests`, native
`journey_meals_test`.

### Save once, log any amount (13 Nov 2026, feature/eat-reusable-amounts)

- **Create food** (Add food › Create food, formerly "Enter it yourself") asks what the values are for: **1 serving**
  (as before: the free "How much?" words, the values for exactly that), **100 g** or **100 ml**. Per 100 g/ml it is a
  food of its own (`source: user`, that basis): the values are typed for the basis, **Amount for this log** is a number of
  g/ml, and the preview and the entry are `FoodScaling.scale` of that basis. Saving it twice updates the same My food.
- A food of the person's own shows "Saved nutrition per …: … The amount for this log never changes it." Its button reads
  **Update saved food** once it is in My foods. `SavedFoodRepository.saveMine` keeps a nutrient's exact basis value when
  the value on screen is only that basis rescaled (rebasing a rounded 0.05 g at 0.5 g gave 10 g per 100 g instead of 9);
  a value the person corrected is rebased as before.
- The amount field is **Amount for this log** (food form, recipe portion, a meal's food in the review) and **Saved
  amount** in the meal/recipe editor. Logging is **Log this time** for food, meal and recipe. In the meal review a food
  changed on its own reads "90 g · Saved amount: 60 g" (not under a whole-meal multiplier, whose chip already says it).
- Library: **Create meal / Create recipe**, each with its description and example under the button; Add food's Create
  food row has its own. With no weighed batch the recipe review explains weighing the cooked batch and adding it with
  Edit recipe; the raw ingredients' weight is never used.
- A recipe portion saved into a meal (Save as meal from a logged portion) becomes a food made from its frozen batch: per
  100 g of the weighed batch (plus one serving's weight when the yield is known) or per serving, at the amount it was
  logged in, so its amount changes on its own like any food. A nutrient some ingredient lacks is unknown there (its
  partial sum is not carried). Before, it became a fixed "1 × 170 g" serving with no grams. No API or contract change:
  components already accept any food snapshot.
- Known, unchanged: amount words such as "60 g" are stored with a Latin g, which an Arabic paragraph shows as "g 60".
- Tests: `food_ui_test` › create food, log any amount; `saved_meals_ui_test` (one meal food changed alone; 170 g and
  242 g of one recipe; no weight; 320 px 2× text in ar/fr-CA; render `create-food-320-large`); `saved_meals_test`
  (recipe portion in a meal; `saveMine` keeps the basis).

### Suggested portions from the coach (28 Oct 2026)

Leon or Leona can suggest a portion of a saved meal, recipe or saved food (docs/COACH.md › Help with today). The values
are this section's arithmetic, unchanged: `MealBody.totals` × a multiplier, `MealMath.share` for a recipe (grams only for
a weighed batch), `FoodScaling` units for a food; unknown stays unknown, a zero stays zero, nothing is rounded before it
is shown. Practical steps only (½, ¾, 1, 1¼, 1½, 2 × the usual portion; grams in 5 g steps). **Review portion** opens
`MealReviewScreen` (new optional `initialFactor` / `initialAmount` / `initialMeasure`) or the food's amount form at that
portion; only their own Log records, through `logMeal` / recipe snapshot / `save` as above. A suggestion never edits a
saved definition or an earlier entry.

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
