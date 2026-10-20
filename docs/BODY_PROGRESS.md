# Body progress: weight, measurements, comparisons

Added 20 Oct 2026 from `GoHard_Body_Progress_Claude_Handoff` (branch `feature/body-progress`, from `main` e33ec42,
which contains the accepted exercise-switch fix 18588e7). It extends the existing body-metric history; no record,
ID, weight, body-fat value or note is changed by it.

Three connected views, all computed on the phone from the account's own check-ins:

1. **Body progress** (Me › Body progress; a quiet link in Train › Progress): latest weight with its real date, the
   7-day average with its recorded-day count, weight over time (4 weeks / 12 weeks / All), Log and Compare dates, the
   latest value of every other metric with its own date, and All measurements.
2. **Log measurements / Edit entry**: date, weight and units, side-specific circumferences, body fat and a note.
3. **Compare dates**: two saved check-ins side by side.

Code: `app/lib/features/body/` (`body_metrics.dart` pure projections, units and form rules; `body_repository.dart`;
`body_prefs.dart`; `body_screens.dart`). The chart is the exercise-trend painter, generalised (`PointChart`).
API: `ActivityService.AddMetricAsync` / `UpdateMetricAsync`, `PUT /body-metrics/{id}` (`metric.update`), migration
`AddBodyMeasurements`, capability `body-metrics.measurements`.

## What a check-in holds

Every field is optional; null means not recorded, never zero. At least one number is required (a note alone is not
a measurement).

| Field | Stored as | Bound (input bound, not a health range) |
|---|---|---|
| Weight | `weightKg`, numeric(9,4) | above 0, at most 700 kg |
| Body fat (existing, user-entered) | `bodyFatPercent`, numeric(5,2) | 0 to 100 % |
| Waist, chest | `waistCm`, `chestCm`, numeric(8,4) | above 0, at most 500 cm |
| Left / right upper arm | `leftUpperArmCm`, `rightUpperArmCm` | same |
| Left / right thigh | `leftThighCm`, `rightThighCm` | same |
| Note (existing) | `note` | at most 200 characters |
| First-saved time | `recordedAtUtc` (nullable, immutable) | set once by the phone on a new check-in |

Left and right are separate fields everywhere: never one "arms" value, never copied from one side to the other. The
app (`BodyField.accepts`) and the API (`ActivityService.Valid`) apply the same rules. Dates after today are refused
(the API refuses a day after the latest calendar day on Earth, UTC+14).

## Units

Weight is stored in kilograms, circumferences in centimetres, body fat in percent; units exist only at input and
display. 1 in = 2.54 cm exactly; 1 lb = 0.45359237 kg (`kgPerLb`). Values are rounded to 4 decimals once, at
conversion (`round4`, and the API rounds the same way), so a quarter inch (0.635 cm) and pound entries survive
round trips. Display shows up to two decimals, at least one ("198.0 lb", "16.25 in").

- A field filled from a stored value (or converted between units) remembers the exact canonical value it stands for
  (`FieldAnchor`). While its text is untouched it saves that exact value, so "198.0" never overwrites 89.81128 kg.
- Switching a form's units converts every field's current value; a field holding text that is not a number blocks
  the switch with a message, so nothing is discarded to convert.
- Decimal comma or dot. Blank is missing; typed text that is not a number is an error, and a refused save keeps every
  character typed.
- Body units (kg/lb, cm/in) are chosen in the form or in Me › Units › Body progress. They never change the lifting
  unit. Until chosen, weight follows the lifting unit and length follows weight (lb → in, kg → cm).
- Units and which fields the form shows (Choose measurements) are **kept per account on this phone**, like the
  nutrition display choice (`BodyPrefsStore`, key `gohard.rebuild.body`). They are never uploaded, so another phone
  keeps its own choice. Measurements themselves always sync.

## 7-day average

Today (the app's day key) and the six calendar days before it. For each day with non-deleted weight readings, that
day's mean in kilograms; then the mean of those daily means, each recorded day weighing the same. Missing days are
left out, not zero-filled; several weigh-ins in a day do not give it more weight. The count of contributing days is
shown ("4 recorded days of 7"). No weight in the window: "Not available", never 0. Converted once for display.
Check-ins awaiting conflict review are left out of averages, charts and comparisons (they stay in history, labelled).

## Chronology and legacy entries

The server model had no trustworthy measurement time, and IDs are random. So:

- Existing records keep their IDs and values; nothing is backfilled or merged. Their `recordedAtUtc` stays null.
- New check-ins carry `recordedAtUtc`, set once when first saved on the phone and never changed by an edit or a date
  change. A backdated check-in keeps its chosen day.
- Order within a day is known only when every check-in that day has a first-saved time (ties fall back to ID only for
  equal times). Otherwise the day shows "one of N entries, order not known".
- Latest value of a metric: the latest day that holds that metric (a later waist-only check-in is not the latest
  weight). Several entries that day in a known order: the latest. In an unknown order: that day's mean, labelled
  "Average of N entries on Oct 12".

## Charts

Every reading in the range is a point at its calendar day; when a day has several, the line joins daily means and
the chart says so ("Points: each entry · line: daily average"). Ranges are 28 or 84 calendar days including today
(the same `TrendRange` as exercise trends), or all; nothing after today, nothing forecast, no zeroes. One day of data
says a change needs two. The range change is shown neutrally ("−3.6 lb"). A tap on a point opens that check-in (or
a list of that day's entries). The chart has a spoken summary; the entry list is the full non-visual alternative.

## Comparison

From and To are saved check-ins; only days with an entry can be chosen, and a day with several lists each entry.
Default: the newest two distinct days, choosing the latest entry on a day with a known order. A day whose entries
have an unknown order gets no default: the page asks the person to choose. Fewer than two days: an explanation and
Log. Each record's real values are shown; To minus From only where that exact metric exists in both; otherwise
"—" and "Not recorded". Body fat changes are percentage points ("pts"). An edited, deleted or now-under-review entry
refreshes the comparison or falls back to the default with a note. Comparing changes nothing.

## Sync

The existing BodyMetric pipeline and outbox, no parallel history.

- **Create** (`metric.create`): one ID per form, so repeated taps make one check-in and one command; local record and
  command in one transaction; retries reuse the same bytes, and the server replays a lost response.
- **Correct** (`metric.update`, `PUT /body-metrics/{id}`): revision-checked, same ID and first-saved time. Each field:
  left out = kept, null = cleared, value = set (`Optional<T>` on the API). The form sends only fields whose value
  changed, so hidden fields, body fat, notes and the other side are untouched. An edit leaving no measurement is
  refused (app and API); Delete entry is the way to remove one. Never delete-and-create.
- **Delete** (`metric.delete`): unchanged, with the existing destructive confirmation.
- Conflicts go to Me › Sync status as before; "Keep the version on this phone" sends one correction with every value.
- **Older servers**: `metric.update`, and any create carrying circumferences or `recordedAtUtc`, wait in the outbox
  until the server declares `body-metrics.measurements` (unknown waits too). When the server is known not to have it,
  a weight/body-fat/note check-in is sent in the old shape, circumferences are refused with an explanation and the
  draft is kept, and corrections are refused with the input kept. Nothing is sent to a server that would drop it.
- An older client's create (weight, body fat, note) still works; it cannot clear new fields because it never sends
  corrections.
- Erased with the account (rows cascade); in the snapshot; owner-isolated; local records stay owner-scoped like every
  other record. Body data is never sent to Ask GoHard or telemetry; viewing makes no network call.

## Coach and help

Leon/Leona speaks through the existing `CoachSpot` / `CoachHelpEntry` (introduced once, Coaching hints respected),
with "How to measure" as its guide action. How to measure is fixed text; its landmarks (waist at the top of the hip
bone, at the end of a normal breath out; upper arm at the shoulder-tip–elbow midpoint, arm relaxed; tape snug without
compressing) come from the CDC NHANES Anthropometry Procedures Manual (January 2017, §3.4.6–3.4.8), cited on the page.
Chest and thigh have no landmark in that manual, and the page says so instead of inventing one.

## Differences from the board

- Pushed detail pages use the app's AppBar back arrow and no bottom bar (the existing secondary-page pattern), so the
  keyboard never sits under a tab bar.
- The log form shows both arms and both thighs by default (the board shows left only); body fat and a note come from
  Choose measurements.
- The compare default is the newest two days even when they share few metrics, per the written rule.
- The coach on Compare is the help entry and an on-request bubble, not an always-on portrait.
