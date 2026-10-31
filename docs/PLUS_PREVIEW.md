# GoHard Free and GoHard Plus (preview)

Added 31 Oct 2026 on `feature/plus-preview` (from `main` 7398a39). A **preview** of the subscription experience:
one typed entitlement model, usage allowances and honest upgrade screens. There are **no purchases**: no StoreKit, no
payment SDK, no checkout, no Apple products, no prices. The only way to be on Plus is the configured owner's
server-authorized preview switch.

## Entitlement matrix (as implemented)

| Area | Free | GoHard Plus (preview) |
|---|---|---|
| Workout logging, timers, previous sets, manual targets | ✓ | ✓ |
| Active training plan | one (unchanged scheduling rule) | one (unchanged: Plus is more *saved* plans, never two active schedules) |
| Saved plan definitions (plans not archived, any lifecycle) | up to **3** | no product limit (technical cap 200) |
| Food search, barcode, nutrition goals, water, coloured bars | ✓ | ✓ |
| Saved meals + recipes (combined, not deleted) | up to **10** | no product limit (technical cap 500) |
| Run / Walk, maps, steps, intervals, audio | ✓ | ✓ |
| History, Train › Workouts records, weekly reports, recap | ✓ | ✓ |
| Progress overview: weekly goals, counts, the two strength-trend previews, adherence, recap, personal bests | ✓ | ✓ |
| An exercise's trend page opened from the overview previews or the weekly recap highlight (4 weeks / 12 weeks, rep count, its sessions, "All N sessions and sets") | ✓ | ✓ |
| **Exercise-trend explorer**: Progress › Strength trends › See all (every recorded exercise) and the **All** range | — (explained on tap) | ✓ |
| **Next-target (progression) suggestions** (Next time card, "Review suggestion") | — (hidden; manual targets stay) | ✓ |
| Meal, medication and supplement reminders | ✓ | ✓ |
| Leon/Leona, briefings, navigation help, local habit suggestions, Quick guide | ✓ | ✓ |
| Sync, export of records, deletion, languages, accessibility, account security | ✓ | ✓ |
| Provider-backed AI (one shared allowance) | **15** successful requests / calendar month | **300** successful requests / calendar month |
| Daily abuse/cost guard (attempts that reached the provider) | 40 / UTC day (existing `Coach:DailyLimit`) | same |

Nothing else is Plus. Weekly meal planning, grocery lists, cross-domain reviews and new analytics do not exist and are
not listed as benefits. Tentative product notes only (never shown, never purchasable): CA$6.99/month, CA$49.99/year.

### Basic versus advanced trends (why this boundary)

`trends.dart` is one projection. Free keeps everything Progress shows by itself (the overview, the two most recent
exercises' previews and their full trend pages with 4- and 12-week ranges and their sessions). Plus adds exploring
beyond that: the searchable list of every recorded exercise and the whole-history (All) range. Workout records are
never behind Plus: every session stays reachable from Train › Workouts and from each trend row.

## What counts and what never does

**Charged (one successful provider-backed request):** Ask GoHard (`/coach/ask`), typed Help with today
(`/coach/daily`), new AI meal ideas (`/coach/daily` with `features: ["ideas"]`), natural-language Eating out
(`/restaurants/interpret`). All four go through `CoachService.GuardedAsync`, the one place the allowance is checked
and recorded.

**Never charged:** opening any screen, avatar motion and greetings, briefings and local suggestions, deterministic
calculations, filters, weekly reports, cached/viewed answers, food database search and barcode lookup, the restaurant
catalog, built-in (suggested) requests.

**Charging policy.**

* A request is charged only when it ends with a usable answer: an Ask GoHard answer, or a Help-with-today / Eating
  out interpretation whose kind is not `unsupported`.
* Not charged: invalid requests, refusals by the guards, provider unreachable, timeouts, provider errors, busy
  (rate limited), schema failures, empty answers, `unsupported` interpretations. These provider attempts are still
  recorded internally (`AiUsage` row `released`, `Reached = true`) and still count against the **daily guard**,
  so failures cannot create unbounded provider cost.

**Shared limits (every API instance, every restart).** One-at-a-time, the daily guard and the monthly allowance are
database state, not process state (`EntitlementService.ReserveAsync` / `FinalizeAsync`, via `AiAllowance`):

1. **Reserve** before the provider is called, in one transaction under a per-account advisory lock
   (`pg_advisory_xact_lock(hashtextextended('ai:' || userId))`, separate from the command lock): refused as busy if
   the account has a live reservation; as the daily guard if today's attempts (UTC day: rows that reached the
   provider, plus expired reservations whose cost is unknown) reached `Coach:DailyLimit`; as the month if this
   month's charged rows reached the allowance. Otherwise one `reserved` row is inserted with a lease. Refusals write
   nothing.
2. **Finalize once** when the request ends: `counted` for a usable answer, `released` for anything else; `Reached`
   records whether the provider answered. Only a row still `reserved` changes, so a second finalize is a no-op.
3. **Charged once per request.** A partial unique index `(UserId, Scope, RequestId) WHERE State = 'counted'` and a
   `NOT EXISTS` in the finalize make a second charge impossible; if two instances finalize the same request at the
   same moment the index refuses one and it becomes `released`. A retry of a request already charged is never
   refused for the month (it cannot cost the person anything more); it still needs a free slot and the daily guard.
4. **Crashes.** The lease is `Coach:TimeoutSeconds × 2 + 30 s` (70 s by default), longer than any live request
   (its time budget, one ≤ 5 s retry, the HTTP backstop). A reservation whose instance died is never finalized: once
   its lease ends it stops blocking and never counts for the month, so no allowance is lost; it does count as a
   daily attempt, because whether the provider was reached is unknown. A finalize that arrives after the lease (a
   stalled instance) still records the truth, and still cannot charge a request twice.
5. **Same instance.** Only the answer cache stays in memory: a retry of the same `requestId` within 2 minutes on the
   same instance shares the one call and answer. A retry that lands on another instance asks the provider again,
   within the same limits, and is not charged again.

**Open before a paid launch (late finalization).** A request finalized after its own lease ran out, while another
request of the same account was reserved in the gap, can take the month one past the limit. It needs an instance
stalled for over a minute, which is acceptable for a free preview but not for a paid quota. Fix options: refuse to
count a finalize that arrives after its lease unless the month still has room (check under the same advisory lock),
or extend the lease while the provider call is running. Listed again under "Before real Apple subscriptions".

**Period and reset.** Calendar month in **UTC**: it starts 00:00 UTC on the 1st and resets 00:00 UTC on the 1st of
the next month (in Toronto that is the evening of the last day). The server's clock decides; the phone's clock never
does. The app shows the reset date (`resetsAtUtc`) as a date in the reader's language. An owner reset starts a new
count from that moment until the month ends (earlier rows are kept, not deleted).

**Limit reached.** `429 {code: "COACH_LIMIT", reason: "monthly", allowance}` (older apps keep their existing "limit"
wording). The daily guard and one-at-a-time stay `COACH_LIMIT` without `reason`. The app says: "You've used your AI
allowance for this month. Your tracking, saved meals and built-in guidance still work." with the reset date nearby.

## Server

* `GET /api/v1/entitlement` (signed in, verified): `{tier, source, preview: true, purchasesAvailable: false,
  limits: {savedPlans, savedMeals}, features: [...], allowance: {used, limit, remaining, periodStartUtc,
  resetsAtUtc, dailyGuard}, canManagePreview, issuedAtUtc, validForSeconds}`. `limits` null = no product limit.
* Preview management, only for `Plus:PreviewOwnerUserId` (compared with the token's verified subject; everyone else
  gets 404 and nothing changes): `PUT /api/v1/preview/entitlement {tier: "free"|"plus"}` and
  `POST /api/v1/preview/allowance/reset`.
* `EntitlementService` resolves the tier from **sources**: today only the preview override (honoured only while the
  row's account *is* the configured owner); everything else is Free. A verified purchase becomes another source later;
  the preview table and endpoints can then be removed without touching the model.
* No profile, sync, command or capability field can grant Plus: the tier is never read from a request.
* Creation limits are enforced in `PlanService` (`plan.draft`, `plan.create`, `plan.continue` — every way a new plan
  definition is made, duplicates included) and `SavedMealService.PutAsync` for a new ID. Answers: rejected
  `PLAN_LIMIT` / `MEAL_LIMIT`. Edits, activation, starting, logging, deleting, archiving and sync are never limited.
* Capability `account.entitlement` (every new server). It says the endpoint exists; it is **not** an entitlement.
* Migration `AddEntitlements` (additive): `PreviewOverrides (UserId PK → Users cascade, Tier, AllowanceResetAtUtc,
  UpdatedAtUtc)` and `AiUsage (Id, UserId → Users cascade, Scope, RequestId, AtUtc, LeaseUntilUtc, State
  reserved|counted|released, Reached)`, indexes `(UserId, AtUtc)` and the partial unique one above.
* `compare` in the answer carries both tiers' figures (`savedPlans`, `savedMeals`, `monthlyAi`), so the comparison
  shows the server's configured values and the app hard-codes none of them.

Configuration (`Plus` section, all optional; these are testing values, not commercial quotas):

| Key | Default |
|---|---|
| `Plus:PreviewOwnerUserId` | empty (no account can switch) |
| `Plus:FreeMonthlyAi` / `Plus:PlusMonthlyAi` | 15 / 300 |
| `Plus:FreeSavedPlans` / `Plus:FreeSavedMeals` | 3 / 10 |
| `Plus:MaxSavedPlans` / `Plus:MaxSavedMeals` (technical, both tiers) | 200 / 500 |
| `Plus:CacheHours` (how long the app may use the last answer) | 72 |

## App

* `features/plus/entitlement.dart`: the typed `Entitlement` (from the server's answer), `EntitlementController`
  (kept alive by the app from sign-in; fetches then, on resume, on opening the Plus page and after AI answers or
  allowance refusals; caches the last valid answer as local record kind
  `entitlement`, id = owner, so caches are isolated per account).
* **Cache bound.** The last answer is used for `Plus:CacheHours` (72 h) from when the phone received it. A phone
  clock earlier than the receipt time, or later than the bound, makes it **unknown**; changing the clock can only
  shorten the cache, never extend it. Allowances are never counted on the phone.
* **Unknown** (loading, never fetched, expired, server unreachable): no paywall is ever shown for it. Existing
  content, logging, plans, saved meals and activities are untouched. Creating beyond the Free limits is not offered
  until the answer is known ("We couldn't confirm your GoHard Plus access right now"); Plus-only views say the same.
* Gates (all from the one model): plan builder Activate for a new or duplicated plan, Continue this plan, saved-meal
  and recipe Save / Save as new, Strength trends › See all, the All range, progression suggestions.
* Drafts survive: the plan builder's draft and the meal editor's draft are already local records; the limit sheet is
  a sheet over the page (View Plus pushes a page above it), so the page and its fields stay as they were.
* A server without `account.entitlement` (older deployment) limits nothing, so the app treats it as `legacy`: no
  limits, every existing feature available, no allowance shown.
* Never interrupted: the recorder, Run / Walk, timers and food review contain no gate; nothing is shown at launch.
* **Me › GoHard Plus**: "GoHard Plus preview", "Purchases aren't available yet.", Free vs Plus comparison (only the
  rows above), this month's AI allowance with its reset date, and for the owner only: the Free/Plus switch, Reset
  test allowance, and a "Preview override active" notice. No Subscribe, trial, Restore purchases or prices.

## Testing both tiers (preview activation)

Two separate switches; neither involves a payment:

| State of the hosted API | What every account gets | Owner preview controls |
|---|---|---|
| Before this deploy (no `account.entitlement`) | No limits at all: IPA 64 treats the server as older (no limits, no Plus-only views, no allowance shown) | none |
| **Deployed** (migration `AddEntitlements` applied, `account.entitlement` declared) | **Free, enforced at once for everyone**: 3 saved plans, 10 saved meals/recipes, 15 AI requests a month, the explorer and suggestions explained/hidden. Existing content over a limit stays usable | none: nobody can switch |
| Deployed **and** `GOHARD_Plus__PreviewOwnerUserId` set | Unchanged for every other account | Me › GoHard Plus › Preview controls on the owner's account only: Free / Plus, Reset test allowance |

Setting the owner ID (the owner does this; no password or token is shared with anyone):

1. Railway → project **devoted-caring** → the **Postgres** service → **Data** → table `Users` → the row with your email
   → copy its `Id` (a UUID).
2. Railway → the **GoHardRebuild** API service → **Variables** → New variable
   `GOHARD_Plus__PreviewOwnerUserId` = that UUID → Deploy. It is an identifier, not a secret; no other value changes.
3. On the iPhone: close and reopen GoHard, then Me › GoHard Plus. "Preview controls (owner only)" appears.

Lowering the limits for a quick test is configuration too (`GOHARD_Plus__FreeMonthlyAi=2`, …); none of it needs a
code change.

## Before real Apple subscriptions

* App Store Connect products and a subscription group; StoreKit 2 in the app (purchase, restore, manage, refund and
  revocation handling), shown only once they work.
* Server verification of transactions (App Store Server API / signed JWS) and App Store Server Notifications v2 as a
  new entitlement **source** in `EntitlementService.ResolveAsync`, with expiry, grace period and billing retry.
* Final quotas and prices (the CA$6.99/month, CA$49.99/year figures are tentative), localized price display from
  StoreKit, terms and privacy text, App Review notes, and a decision on whether the preview routes are removed.
* Resolve the late-finalization edge (Shared limits › Open before a paid launch).
