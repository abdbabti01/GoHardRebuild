# Eating out

Added 25 Oct 2026 on `feature/eating-out` (brief: `GoHard_Eating_Out_Claude_Prompt.md`). Find a restaurant order that
fits targets the person chooses, improve an order they already want, and ask Leon or Leona in words — with every
number taken from the chains' own published Canadian nutrition information and calculated by GoHard, never by a model.

## What the person gets

- **Where:** Eat › **Eating out** (beside Log food and Saved meals & recipes, for the day shown and the meal of the time
  of day) and Add food › **Eating out** (for the day and the meal chosen there). Both carry the day and meal through to
  the review. History & trends and the meal groups are unchanged.
- **One page** (`eating_out_screen.dart`): choose a chain (each labelled *Canada*), then the coach and the request field,
  the visible targets, and two tabs: **Help me choose** (up to three suggestions) and **Your order** (the order being
  built, with steppers, the menu, totals and how it stands against the targets).
- **Targets** (all optional, nothing pre-filled, for this meal only — not the daily goals): maximum calories, minimum
  calories, minimum protein, items to keep (with a count), items to leave out, preferred and avoided kinds, and how
  fitting orders are sorted. Each is a removable chip; *Edit* opens the sheet. Without any target, Help me choose says so
  and invents none. Daily goals are not used here, so a remaining daily allowance is never treated as a meal size.
- **Suggestions:** exact items and counts, calories and protein first, carbs and fat after, "Fits your selected targets"
  (and which kept items it keeps) or "Misses: 120 kcal over your limit", and beside an order already started "Compared
  with your order: −100 kcal, +3 g protein". **Use this order** / **Use instead of my order** changes the draft only and
  offers **Undo**. Nothing fits: "Nothing fits all your targets", then the nearest ones, each with what it misses.
- **Your order:** add from the chain's menu (grouped by the source's own sections, filterable), change counts, remove.
  Totals are computed from the catalog; sodium only when every item states it. **Review and log** opens the ordinary
  saved-meal review (`MealReviewScreen`) with the day and meal confirmed there; **Log meal** there is the only action that
  writes the journal. **Save as meal** opens the ordinary saved-meal editor, prefilled; it logs nothing.
- **Customisations:** only listed items and sizes. A footlong is offered because Subway's table says how to compute it
  (double the 6-inch values). No sauce/extra cheese/bread swap is calculated: the page says so and offers **Log your own
  estimate instead** (the ordinary manual form; the values are the person's own, `entered`, never restaurant data).
- **Provenance on screen:** the page footer names the source, its publication date (or "not stated") and the date it was
  checked; the food details sheet of a logged item says "Subway Canada's published nutrition information · published
  2026-10 · checked 2026-10-25", the source's standard-build statement and any sodium/fibre/saturated fat it states.

No ordering, payment, delivery, prices or location search. No allergy, halal, vegetarian or medical claim is made.

## Catalog: chains and exact coverage (version 2026-10-25.2)

Full per-item table with values: `docs/RESTAURANT_SOURCES.md` (generated).

| Chain | Status | Source (official, Canadian) | Published | Checked | Items |
|---|---|---|---|---|---|
| McDonald's Canada | available | the official nutrition calculator (mcdonalds.com/ca/en-ca/about-our-food/nutrition-calculator.html); its displayed values as loaded from `mcdonalds.com/dnaapp/itemList?country=CA&language=en`, read in Chrome by owner-authorized read-only access (`scripts/restaurant-sources/mcdonalds-ca-2026-10-25.json`, 135 items captured) | not stated by the calculator (kept unknown) | 2026-10-25 | 27: Big Mac, Quarter Pounder with Cheese (+ Double), McDouble, Cheeseburger, Hamburger, McChicken, McCrispy, Grilled Chicken Sandwich, Chicken & Bacon McWrap (grilled), 6 and 10 McNuggets, Egg / Sausage 'N Egg / Bacon 'N Egg McMuffin, Hash Browns, Fries Medium and Mini (separate stated records), Apple Slices, Baked Apple Pie, and 8 drinks with stated sizes and volumes (Coca-Cola, Coke Zero, Diet Coke, Sprite, orange juice, 1% milk, Dasani) |
| Tim Hortons Canada | available | Nutrition Information PDF linked from timhortons.ca/nutrition-and-allergens (`cdn.sanity.io/files/czqk28jt/prod_th_ca/147e592c…pdf`), SHA-256 recorded; text extract committed | "as of July 2026" (file 10 Jul 2026) | 2026-10-25 | 33: brewed coffee black and Double Double (both as stated), latte, protein latte, steeped tea, hot chocolate, iced coffee, Original and Light Iced Capp (all medium), 3 English Muffin breakfast sandwiches, Protein Bagel BELT, 2 breakfast wraps, 2 Omelette Bites, Hash Brown, Yogurt Parfait, Turkey Bacon Club, Crispy Chicken Sandwich, Chicken Bacon Ranch Wrap, 3 Loaded Bowls, Grilled Cheese Melt, Chicken Noodle Soup (regular), Chili (regular, large), 2 donuts, a Timbit, Plain Bagel |
| Subway Canada | available | Nutrition Data Tables `CAN_Nutrition_ENG_9-16-26.pdf` (media.subway.com, linked from subway.com/en-ca/menunutrition/nutrition), SHA-256 recorded | printed "October 2026" (file 16 Sep 2026) | 2026-10-25 | 31: eleven 6-inch subs (+ their 11 footlongs, derived by the source's rule), 2 wraps, 2 salads (no dressing), 1 Power Bowl, 2 breakfast sandwiches, Potato Rings, Chocolate Chunk Cookie |
| Pizza Pizza Canada | available | pizzapizza.ca/about-us/nutrition/ (small-pizza, chicken-wings-bites pages) | "as of November 1st, 2023"; rows marked "Updated March 12, 2026" carry that date | 2026-10-25 | 20: 10 small pizzas by the slice (1/6 of a 10-inch pizza), 8 Walk-In slices, Classic Wings, Boneless Chicken Bites |

**How McDonald's and Tim Hortons were read (follow-up, 25 Oct 2026).** The owner authorized read-only access to both
official sites and their public nutrition services. McDonald's answers scripted requests (curl, WebFetch) with an
"Access Denied" page from its edge (HTTP 403, e.g. reference `#18.b059c817.1792983967.63bfc44` for
`/dnaapp/itemList?country=CA&language=en&showLiveData=true`), so its values were captured in a normal Chrome window
from the calculator's own data service; nothing tried to get around that edge. Tim Hortons publishes a dated PDF on its
nutrition page; it is the source. The public content service its site reads (dataset `prod_th_ca`) was read once as an
independent cross-check: wherever both list an item they agree (Turkey Bacon Club 550/27, Crispy Chicken Sandwich
660/23, Grilled Cheese Melt 560/28, Medium Latte 140/10). Two PDF rows fail the build's checks and are left out
(Snow Ball Timbit: saturated fat above fat; Bacon & Cheese Omelette Bites: energy does not fit the macros).

**Not covered:** McDonald's Small and Large fries (only Medium and Mini were captured — a size is never scaled from
another), McCafé drinks, combos/meals (order the parts); Tim Hortons other sizes than those listed, and any addition to
a drink beyond what the source states (a Double Double is offered because its values are stated).

**Deliberately excluded:** Subway drinks (not in the table), soups and regional items (marked regional/limited),
Fresh Fit duplicates; Pizza Pizza drinks and dips (their table columns are unlabelled in the page text), medium/large
pizzas (the page states no slice size for them), saturated fat of small pizzas (the page text loses its decimal point:
"35" for 3.5 — kept unknown, never 0 and never 35).

**Standard builds** (the source's words, kept with each item): Subway 6-inch subs — the table does not say which bread,
cheese, vegetables or sauce the standard build uses, so changes cannot be calculated; wraps "include wrap, Processed
Cheddar, mayonnaise, lettuce, tomato, onion and cucumber"; salads include the listed vegetables and no dressing;
breakfast sandwiches "include 6" Italian, scrambled egg patty and Canadian cheddar cheese". Pizza Pizza: a small slice is
"1/6 of the pizza (10 inch diameter)" and is not interchangeable with any other size or cut; a Walk-In slice is "Per
Slice" (no diameter stated); wings list their serving as "5" with no unit and are shown exactly so.

### Format and identity

`api/src/GoHard.Api/Data/restaurant-catalog.json` is canonical; the app bundles a byte-identical copy at
`app/assets/data/restaurant-catalog.json` (`eating_out_test` fails if they differ). Each item: stable `id`
(`<chain>:<item>`, independent of display name), official `name`, `size` (6-inch / Footlong), the source `section`,
`role` (main | side | dessert | drink), `kind`, variety `group`, `portion` ("1 sub (6-inch)", "1 slice (1/6 of a
10-inch small pizza)"), `grams` when stated, `nutrients` {calories, protein, carbs, fat} (null = unknown, 0 = stated 0),
`extra` {sodiumMg, fibreG, satFatG} only when stated, `build`, `source`, row `updated` date, `derived` ("footlong-double")
and `maxQuantity`. Chains carry `country: CA`, `status`, `sources` (title, URL, published, checked, note) and `builds`.

A restaurant item becomes an ordinary `FoodItem` with `source: restaurant`, `sourceId` = the item id (identity
`restaurant:<id>`, never USDA, Open Food Facts or the person's), basis per serving (its own portion, with its weight when
stated), and a `restaurant` block (chain, country, item, catalogVersion, source title/URL, published, checked, build,
derived, extra). That block travels in every copy: saved-meal components (`MealComponent.slim` keeps it), journal
snapshots, Recent foods.

### Update procedure

1. Read the official document. For a PDF: `node scripts/pdf-text.mjs <file.pdf> > scripts/restaurant-sources/<name>.txt`
   (the PDF itself is not committed; its SHA-256 goes in the spec). For an HTML table: a rows file
   `{columns, rows:[{section, name, values[], updated?}]}` with the source's own numbers.
2. Edit `scripts/restaurant-catalog.spec.json`: raise `version` (dated, so newer compares higher), set `checked`, list
   the items (section + row as printed, portion words "1 <noun> (detail)", role, kind, group, build).
3. `node scripts/build-restaurant-catalog.mjs` writes both catalog copies and `docs/RESTAURANT_SOURCES.md`. It refuses a
   row found zero or several times, energy that does not fit the macros (Atwater 4/4/9 within max(25 kcal, 12 %)),
   saturated fat above fat, fibre above carbs, missing calories/protein, a portion not "1 <noun>…", unknown builds or
   sources. `--check` fails when the committed outputs are stale.
4. Deploy the API (the catalog ships in `Data/`). Phones holding the older version pick up the new one the next time
   Eating out opens (below). Nothing fetches restaurant sites at run time.

## API

- `GET /api/v1/restaurants/catalog?have=<version>` (signed in, verified; the default `me` policy, so an expired session
  is 401 and a verification hold 403 as everywhere): the catalog JSON, or `{upToDate: true, version}` when `have` matches.
- `POST /api/v1/restaurants/interpret` (same policy; a read, never a command, never queued):

```jsonc
// request (≤ 64 KB)
{ "requestId": "<uuid>", "catalogVersion": "2026-10-25.1", "chainId": "subway-ca",
  "question": "…",                                   // 1–600 chars
  "language": "en" | "fr-CA" | "ar",
  "history": [ { "role": "user" | "assistant", "text": "…" } ],     // ≤ 6, each ≤ 1500
  "order": [ { "itemId": "subway-ca:tuna-6in", "quantity": 1 } ],   // ≤ 30, quantity 1–20
  "orderRevision": "<opaque>",
  "preferences": { "maxCalories", "minCalories", "minProtein", "keep": [ids], "exclude": [ids] } }

// 200
{ "requestId", "catalogVersion", "chainId", "orderRevision",
  "intent": { "kind": "constraints" | "clarify" | "unsupported", "mode": "choose" | "improve" | null,
              "chainId": null | "<another listed chain the person named>",
              "maxCalories": 100–4000 | null, "minCalories": 0–4000 | null, "minProtein": 1–300 | null,
              "keep": [ { "itemId", "quantity": 1–6 } ], "exclude": [ids], "prefer": [kinds], "avoid": [kinds],
              "priority": "protein" | "calories" | "closest" | null,
              "clarification": "…" | null, "unknownItems": ["names"], "problem": "contradiction" | null,
              "dropped": ["item" | "quantity" | "maxCalories" | …] } }
// 400 RESTAURANT_INVALID · 409 RESTAURANT_CATALOG_MISMATCH {catalogVersion} · 429 COACH_LIMIT
// 503 COACH_BUSY {retryAfterSeconds} · 503 COACH_UNAVAILABLE
```

Capabilities: `restaurants.catalog` when the catalog loads; `restaurants.interpret` only when the catalog loads AND
the configured coach provider is enabled (`coach.ask`'s rule). Manual Eating out needs neither on the phone (bundled
catalog); a server without `restaurants.interpret` gets no request (the field says asking is unavailable). No contract
change, no migration, no new configuration: client contract stays 2.

## AI boundary (what the model may and may not do)

Pipeline: the person presses **Send** → the API makes ONE model call (`RestaurantService`, through `CoachService`'s
provider abstraction, so the configured Groq model, timeout, one-retry rule and request IDs are reused) asking for the
strict schema `eating_out_preferences` → the server keeps only checked values → the phone resolves them against its
catalog and **deterministic code** builds, ranks and totals orders → the coach's words are fixed localized templates
("Here's what I understood…", what it misses). No second model call; no explanation call per change.

- **The model never supplies a value.** The menu sent to it lists id | name | portion | kind and no nutrition; the
  schema has no nutrition, price, ingredient or URL field; the server rebuilds the intent from known properties only
  (an added `calories` field is ignored), drops unknown item IDs, out-of-range numbers and quantities (named in
  `dropped`), and replaces a clarification that states a figure (kcal, g, mg, $, a link) with the app's own wording.
- **Sizes are exact, never substituted.** The catalog holds only sizes the source states (McDonald's fries: Medium
  and Mini, no Small or Large); nothing is scaled from another size. The model is told to report an unlisted size as
  not found, and the server enforces it: when the request names a size (small/mini/medium/large/regular, in English,
  French or Arabic) and a kept item's own stated size is none of them, that item is dropped (`dropped: size`) and named
  in `unknownItems` ("small World Famous Fries"), so the coach says it isn't on the menu. Every kept item is shown as a
  chip with its exact size before anything is used.
- **Ambiguity is said back:** budget (money vs calories), an unmatched or ambiguous item/size, a minimum above a maximum
  or an item both kept and excluded (`problem: contradiction`) give `clarify`, and the app changes nothing.
- **Untrusted text** (the question, history, item names) travels in separate labelled user blocks with `<`/`>` replaced,
  after trusted instructions and the menu; the model has no tools, fetches nothing and writes nothing.
- **What is sent:** only the chain, the order on screen, the targets, the words, the language and up to six earlier
  exchanges (stored as IDs and numbers). Never the email, journal, body data, location or goals.
- **Shared limits:** `CoachService.GuardedAsync` holds one request per account at a time and ONE daily allowance
  (`Coach:DailyLimit`) for Ask GoHard and Eating out together; the same requestId within its scope shares one call and
  answer; another account never gets it. Failures are not remembered, so Retry asks again.
- **On the phone** (`eating_out.dart`): no request on opening, chips, quantities or browsing. A reply is applied only if
  it answers the request on screen for the same account and the order revision (chain, order, targets and language)
  has not changed; otherwise "Your order or targets changed while I was reading that. Nothing was changed". Applying
  changes the targets only, with Undo. Offline, rate-limited, unconfigured, timed out or unreadable: the question and the
  draft stay, the page says what is true, and targets/menu/building/logging keep working. 409 → **Update menu**.

## Ranking rule (deterministic; `OrderPlanner` in `restaurants.dart`)

1. Candidates: kept items with their counts, plus at most one main (pizza slices 1–3, others one) unless a main is kept,
   plus optionally one side, a dessert only when desserts are preferred or kept, optionally one drink. Only items with
   stated calories and protein; never an excluded item or avoided kind; with preferred main kinds, the main is one of
   them (sides stay possible). So no stack of burgers unless the person builds one.
2. Hard targets: max calories, min calories, min protein. Meeting all = fits.
3. Fitting orders by the shown sort: *most protein* (default when a protein target is set), *fewest calories*, or
   *closest to your calorie limit* (default when only a calorie limit is set); ties: fewer items, then calories, then
   item IDs. The sort is always written on screen; fewest calories is a choice, never called healthiest, and nothing is
   ranked by protein per calorie.
4. Variety: one suggestion per added main group (a 6-inch and its footlong are one group), up to three.
5. None fits: the three nearest by the sum of each miss relative to its target, each labelled with its misses; kept and
   excluded items are never relaxed. Contradictions: nothing is built.

## Snapshots, offline, saved meals and logging

- **Draft** (`Kinds.eatOut` `draft`, local only, owner-scoped): chain, order lines (item IDs + counts), targets, last six
  exchanges; written after every change, read when the page opens, so leaving, a language change or a restart loses
  nothing. Changing chain starts a new draft (Undo restores the old one). A logged order clears its lines, keeps targets.
- **Catalog on the phone:** the newer of the bundled copy and the last one the server sent (`Kinds.eatOut` `catalog`),
  asked once per visit with `?have=` where `restaurants.catalog` is declared. A refresh never edits the draft: lines the
  new menu no longer lists are reported ("1 item is no longer on this menu") and Review/Save wait until they are removed.
- **Logging** reuses `FoodRepository.logMeal` (`food.batch`): one ordinary entry per item, each with its own frozen
  snapshot `{item, quantity, unit}` and `imported` provenance, no total entry, one operation ID per review (double taps
  and lost answers replay), one local transaction, all-or-nothing on the server, held until `food.saved-meals` is
  declared. A later catalog version, AI answer or template change never touches a logged entry: the snapshot keeps its
  own catalogVersion and values.
- **Save as meal** = the ordinary saved-meal editor with restaurant components; Update saved meal / Save as new stay
  the explicit actions they were. Coverage rules are the app's one path (`NutrientCoverage`): a sum with any unknown is
  "known", never complete — in Eat, Today, History & trends and the goal line.

## Leon and Leona

The selected guide's animated bust with the mouth-attached bubble (`TabCoach`, id `eatout`: its entrance plays once per
session, never per selection; Reduce Motion settles it at once). It introduces Eating out ("Eating out? Tell me where
you're going and what you want to keep."), then speaks fixed words about the chosen chain, the order, the reading in
progress (leaning in, `attentive`, only while a request is really in flight) and what was understood. Tapping it
focuses the request field and sends nothing. With *Show coach on Train and Eat* off, its small avatar beside the same
words is the help entry, so explicit help never disappears with the hints. It never promises results, shames, or calls
exceeding a target a failure; it says "fits your selected targets" with the numbers.

## Verification (25 Oct 2026)

- API (`RestaurantTests`, in `CoachTests`, real host + disposable PostgreSQL, **stubbed provider**, both Anthropic and
  Groq shapes): checked intent, injected nutrition/price/URL fields ignored, invented IDs dropped, prompt has the menu
  without nutrition and the words in their own block, ranges, contradictions, unsafe clarifications, injection, bad
  replies, shared daily allowance with Ask GoHard and one call per requestId, catalog served without a key, 409 on a
  stale version, invalid requests never reach the provider. Existing Ask GoHard tests unchanged and passing.
- App (`eating_out_test`): catalog integrity (byte-identical copies, sources, IDs, portions, Atwater, footlong = 2×,
  unknown vs zero), exact totals and slice maths, ranking (hard targets, kept/excluded, variety, bounds, sorting, nearest
  with misses, contradictions, determinism), reading the interpretation, request contents; on the real Drift database
  with the fake account: Save as meal logs nothing and keeps provenance, Log writes each item once with frozen snapshots
  through taps and a lost answer, offline log + draft survive a restart and reach the account once.
- App (`eating_out_ui_test`, **stub client**): Eat entry, chains and blocked chains, targets, menu, no AI request without
  Send, interpreted chips, Undo, Use this order, Review and log once with one entry per item, Save as meal opens the
  editor and logs nothing, stale reply not applied, failure keeps the question, Retry reuses the request ID, mismatch,
  clarification, Arabic RTL and French at 320 px / 1.6× text with the keyboard (Send above it), coach off + Reduce
  Motion. Renders (`GOHARD_RENDER`): `docs/evidence/eating-out/` and `docs/evidence/localization/{fr,ar}/eating-out/`.
- Native journey `journey_eatout_test` (not default; branch API on a disposable DB with captured mail and the coach
  provider pointed at `scripts/coach-stub.mjs` — a **stub**, so it proves the app/API path, not live AI): **passed** —
  chain, request, interpreted chips, suggestion keeping the kept item, comparison, log once, Save as meal and reopen,
  genuinely offline (honest failure, offline log reaching the account once). Captures `docs/evidence/screenshots/eo-*`;
  run details in `docs/PROGRESS_LEDGER.md`.
- **Live AI:** no Groq key exists on this machine; no live request was made. The hosted API (key configured) will make
  real calls after deployment — check on the iPhone.

## iPhone checklist (after the owner approves and deploys)

1. Eat › Eating out opens with today and the current meal; Add food › Eating out keeps the meal chosen there.
2. All four chains show their menus; try "McDonald's, about 600 calories, more protein, keep the mini fries" and a
   Tim Hortons breakfast with a medium Double Double.
3. Ask: "Subway for lunch, around 600 calories, more protein, keep the potato rings" (live Groq): targets appear as
   chips, suggestions keep Potato Rings, the numbers match `docs/RESTAURANT_SOURCES.md`.
4. Ask something ambiguous ("something cheap"): a question back, nothing changed. French and Arabic requests work.
5. Use a suggestion, change a count, Undo; Review and log; Eat shows one entry per item; the entry's details name the
   source and dates.
6. Save as meal; reopen it in Saved meals & recipes; log it from there.
7. Airplane mode: asking says it couldn't be sent; building and logging still work; the order reaches the account later.
8. Several questions quickly: the shared daily/busy messages are calm and keep the question.
