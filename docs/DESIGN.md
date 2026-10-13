# Design system — Calm Momentum

The app's look since 12 October 2026: clean sans type (Inter), pearl surfaces in light, graphite layers in dark, one
chosen accent, a photographic workout feature on Today and a training pass on Train. It replaces the earlier
"Evening Club" serif look. The brief and the two approved references are in `gohard-design-brief/`.

## Where things live

| What | File |
|---|---|
| Colour tokens, type, radii, targets, motion, `ThemeData` | `app/lib/core/theme.dart` |
| Accent + mode preference, saved on the device | `app/lib/core/appearance.dart` |
| Shared components (buttons, Pressable, tab header, icon tile, group card and rows, sheet, segmented control, pass, rail, page) | `app/lib/core/widgets.dart` |
| Motion and haptics preference, the `Haptics` helper | `app/lib/core/device_prefs.dart` |
| Week tiles, day strip, state pills | `app/lib/features/plans/week_widgets.dart` |
| Completion, plan weeks, recorded-set progress (pure logic) | `app/lib/features/plans/plan_progress.dart` |
| Appearance page | `AppearanceScreen` in `app/lib/features/me/me_screen.dart` |

Screens read colours only through `context.c` (`GoColors`). No screen carries its own colour values, except white
text on the workout photograph, which sits on a fixed dark scrim.

## Appearance

Two independent choices in **Me → Appearance**: accent (Blue, Green, Pink) and mode (Light, Dark, System). They apply
at once with a 200 ms cross-fade and no movement, and are saved in the platform's secure store next to the session,
so they are read before the first frame. A fresh install is Blue + System.

Mode used to be an account field (Dark, Light or Match this phone). It is now a device setting, and an existing
install keeps the look it had: the first launch of this version over an install that is already signed in copies the
account's value across, once (Light stays Light, Dark stays Dark, Match this phone becomes System). After that, and
for anything chosen on the device, the device setting stands. A fresh install starts on System and records that at
once, so signing in later is not mistaken for an upgrade. On that single upgrade launch the app can open following
the phone for a moment before the saved profile is read. The account field is left as it is and is no longer written.

## Tokens

| Role | Light | Dark |
|---|---|---|
| Page | `#F3F3EF` | `#131417` |
| Raised surface (cards, sheets, dialogs, fields) | `#FCFCFA` | `#1D2025` |
| Recessed fill (tracks, unselected segments, neutral icon tiles) | `#E8E8E3` | `#2A2E35` |
| Text / secondary text | `#14161A` / `#555B63` | `#F2F3F5` / `#ADB3BC` |
| Separator and card border / control boundary | `#DCDCD6` / `#6E747D` | `#33373E` / `#8A919B` |
| Blue accent / selection tint | `#0062CC` / `#E6EFFB` | `#77B6FF` / `#172C47` |
| Green accent / selection tint | `#147644` / `#E1F1E8` | `#6BD39C` / `#143527` |
| Pink accent / selection tint | `#B32E70` / `#FAE8F0` | `#F58CB9` / `#3F1E33` |
| Text on a filled accent | `#FFFFFF` | `#131417` |
| Success / warning / error | `#0C6B63` / `#7D5200` / `#B3261E` | `#5FD4C4` / `#F2C36B` / `#FFB4AB` |

Refined on 13 October 2026 for the four-tab redesign: the light page is pearl and the raised surface is an off-white
one step above it, so a card reads as raised before its thin border is noticed and no page is pure white; the dark
page is charcoal rather than near-black, with the same step up to cards and recessed fills. The training pass no
longer has its own gradient colours: it is an ordinary card. Radii are 12 (fields, choices), 14 (buttons, tiles),
18 (cards, dialogs) and 22 (the top of a sheet). Buttons are rounded rectangles; the pill is kept for status labels.
A destructive action is filled with the error colour and labelled in the page colour.

Changes from the brief's starting values, each made because the measured contrast asked for it: light blue
`#0068D9` → `#0062CC` and light pink `#B83275` → `#B32E70` (accent-coloured text on the selection tint was under
4.5:1); success is teal so that "completed" never looks like the green accent. Status is always an icon and a word.

With the phone's Increased Contrast setting, secondary text, separators and control boundaries move toward the
primary text colour (`highContrastTheme`). Nothing in the app uses blur or translucent panels, so Reduce Transparency
has nothing to change. With Reduce Motion, pages appear without a slide and rails and segments change without easing.

## Motion and haptics

One place for timing, `Motion` in `theme.dart`, always read through `context.motion(...)`:

| What | Timing |
|---|---|
| Press feedback (`Pressable`, the buttons): scale to 0.98 and back | 100 ms |
| Selection, tab cross-fade, look change, a sheet leaving | 200 ms |
| A sheet arriving (`showGoSheet`) | 280 ms, ease-out |
| A progress rail moving to a new real value | 360 ms, ease-out |

Nothing loops, bounces or slides a whole page. A rail appears at its value and moves only when the value changes;
a rebuild or a tab coming back replays nothing. The tabs stay built in an `IndexedStack`; the cross-fade only
changes the opacity of the tab being shown.

**Me › Motion & haptics** holds two device preferences, saved in the platform secure store beside the appearance
(`gohard.rebuild.device-prefs`) and read before the first frame. They are not part of the account. Motion is Device
or Reduced: Reduced is presented to the whole app as the phone's own Reduce Motion (`DevicePrefsScope` sets
`MediaQuery.disableAnimations` above the navigator), so there is one code path and changing it rebuilds no route.
Haptics is Device or Off: every haptic goes through `Haptics.selection()` / `Haptics.confirm()`, which do nothing
when it is Off. Haptics are for something the person just did, never for sync or typing.

## What is measured, and how

`app/test/theme_test.dart` fails the build if any of these drop below their line, for all six combinations and their
increased-contrast variants:

- text, secondary text and the three status colours on page, surface, recessed fill and selection tint: 4.5:1;
- accent-coloured text on page, surface and selection tint; labels on filled accent controls; text on the pass: 4.5:1;
- control boundaries, selected segments against their track, progress fills against their tracks: 3:1;
- white text over the photograph assuming the brightest possible pixel behind it (the overlay is at least 82% black
  under all text): 4.5:1.

The same file runs Flutter's rendered-pixel text-contrast check, the 48 px (Android) and 44 pt (iOS) tap-target
checks and the labelled-control check on Today, Train › Plan, Eat and Me in all six themes.

## Renders for review

```
cd app
flutter test test/render_test.dart --dart-define=GOHARD_RENDER=true
```

writes PNGs to `docs/evidence/design/`: every main screen in all six themes side by side (`six-themes-*.png`), whole
pages, large text at 320 px, 12- and 16-week plans, a new account. They use the fixture in `app/test/ui_support.dart`
(illustrative data, like the reference), the real fonts and the real photograph. They are renders of the widgets,
not captures from a phone. Captures from the Android emulator, made by the native journeys with a real account on the
local API, are in `docs/evidence/screenshots/`.

## Food: search, scanner, preview and goals

Added on 12 October 2026 with the existing components only (`AppPage`, `ListRow`, `Panel`, `StatusLine`,
`SecondaryButton`, `ProgressRail`, the themed text fields and dropdowns). No new colour, radius or type size.

| Screen | File | Notes |
|---|---|---|
| Log food (search, scan, saved, recent, manual) | `features/nutrition/log_food_screen.dart` | Local matches as you type; online search is a separate button, because the food database is shared and counted per request. One list style for every origin. |
| Scan a barcode | `features/nutrition/barcode_scan_screen.dart` | The camera sits in a rounded panel inside the normal page, with a plain white frame and a torch button only where the phone has one; the typed-barcode field is always below it. It never takes over the screen like a scanner SDK page. |
| The food form | `features/nutrition/food_form.dart` | The same form for every entry path. A source card (name, brand, values per basis, credit) sits above the fields. Amount and unit side by side, stacked at large text or under 350 px. A corrected value is marked "Your value". |
| Nutrition goals | `features/me/me_screen.dart` | Two optional fields that start empty. |
| Update notice | `app/app.dart` | Drawn over the open screen, so nothing underneath is lost. |

Checked by `test/food_ui_test.dart`: contrast, tap-target size and labels on search, results, a preview with unknown
values, and the scanner's fallback, in all six themes; no overflow on search, preview, scanner and goals at twice
the text size on a 320 px phone. Renders of each in all six themes are in `docs/evidence/design/`
(`six-themes-log-food`, `-food-results`, `-food-preview`, `-scan`, `-goals`). In those renders the camera is a flat
grey panel, because a widget render has no camera; the emulator capture `screenshots/97-scanner.png` shows the real
camera view with its frame.

Found and fixed while checking these: the Meal dropdown overflowed by 59 px at twice the text size on a 320 px phone
(it now uses the full width), and a long text-and-icon button did not wrap (it is now plain text).

## Today: what it holds and what it leaves to the other tabs

Redesigned on 13 October 2026 from the brief in `gohard-today-photo-design/` (three references and three
photographs). Today is three cards of one family: the same 20 px radius, border, surface, title weight, 36 px icon
tile and 52 px button. The workout card is full width and holds the page's only filled button; Run and Nutrition
are companion cards with outlined buttons.

| Part | What it shows | Where the rest lives |
|---|---|---|
| Workout card (`_WorkoutCard` in `features/today/today_screen.dart`) | A photograph about 124 px high carrying "WORKOUT", the workout's real name and a filled state label (Due today, In progress, Done for today). Below it, on the card's own surface: one summary line (exercise count, planned sets when known, the plan's session length as "50 min planned"), up to three movements in workout order with their prescription on the right when the plan has one ("4 × 6–8"), per-movement recorded counts while in progress, "X of Y sets recorded" with a rail, and one Start or Resume button. | "See all N exercises" (or "Workout details" with three or fewer) opens the existing workout sheet or record. The week's calendar: Train › Plan. |
| Rest day, paused plan, plan not started, block to review, draft, no plan (`_PlainCard`) | The same card with no photograph, so a picture of training never sits above "Rest today". "Start a manual workout" stays as a text link under it. | Train › Plan. |
| Run card (`_RunCard`) | Photograph, "Run", one line of real state ("No run today", "Today: 31 min · 5.20 km", "In progress", "In progress · 0.42 km so far" once a distance has been measured) and one button: "Start run", or "Continue run" for the saved open run, whatever day it began. It is Today's only way into a run. | "Run history" is a quiet link in the side-by-side layout. Train › Workouts has the same start. |
| Nutrition card (`_NutritionCard`, values by `NutritionSummary`) | Photograph, "Nutrition", "No food logged today" or the number of foods, then calories and protein from the same coverage Eat reads, a goal rail only for a goal that was set, one line when values are missing, a quiet "Food journal" link and one "Log food" button. | Carbs, fat, the per-food list and the longer explanation: Eat. |
| Recorded today | Workouts finished today in their own words ("Manual workout · Recorded · 1 set"). A single finished run is said on the Run card; runs are listed here only when there are several. Absent when there is nothing to list. | Histories: Train and Me. Body measurements: Me. |
| Account not reached | One line, "Can't sync right now", with the number of changes still only on this phone; a tap opens the explanation and "Try again". Me's sync row uses the same words (`cantSyncLabel` in `app/providers.dart`). Neither says "Offline": the app knows an attempt failed, not whether the phone or the server was the cause. | Changes that need a decision keep their notice above the navigation bar. |

**Layout.** Run and Nutrition sit side by side while both are short: nothing logged today, text size up to 115%,
and a screen at least 350 px wide. Their buttons then share a baseline. Logged food brings values and goal rails
that need the full width, so the two cards stack, and the Run card becomes one row (title and state on the left,
button on the right). Large text or a narrow phone also stacks them. Nothing is truncated or shrunk to keep a
layout: heights follow content and the page scrolls.

**What the rows do and do not claim.** A movement row is plain text, not a button: there is no page for a single
movement, so nothing pretends to be tappable. No row is highlighted for being first, and none is marked complete;
"2 of 4 sets recorded" is a count. With no planned total (a manual workout) the card says "3 sets recorded" with
no percentage and no "of".

**Photographs.** `assets/images/workout-hero.webp`, `run-cover.webp` and `nutrition-cover.webp` (1536 × 1024,
about 0.69 MB together) are the files supplied with the brief, unchanged. Per its `ASSETS.md` they are generated
editorial illustrations made for this design on 13 October 2026: not stock photographs, not the user's workout,
route or meal. They replace `evening-gym-hero.jpg`, which is removed. They are bundled, so they load with no
network, and are excluded from screen-reader output. Each is cropped with `BoxFit.cover` and a focal alignment that
keeps the dumbbells, the near shoe and the bowl in view; a file that fails to load leaves a plain recessed panel.
Each is decoded once at the phone's width (`cacheWidth`), the same size in every layout, so scrolling, stacking and
theme changes reuse the decoded image.

**Contrast.** Only the workout photograph carries text. A left-to-right scrim keeps at least 82% black under the
62% of the width the words may use (the same floor `theme_test.dart` checks), and lets the photograph show on the
right. With large text the words take the full width and the scrim covers the whole header. The state label is a
filled accent pill, so Blue, Green and Pink each keep their own colour; nothing on the card is hard-coded blue.

The minutes on a due workout are the session length chosen in plan setup (`setup.minutesPerSession`), so they read
"50 min planned", never "about 50 min": nothing is estimated from the exercises.


## Me

Redesigned on 13 October 2026 from `me-reference.png`. Me is identity, personal information, preferences and the
account, as grouped rows (`GroupCard` / `GroupRow`): the profile's own name with its initial and Edit profile;
Personal (Body measurements, Nutrition goals); Preferences (Appearance, Units, Motion & haptics, Workout reminders);
Account (Sync status, Delete account); Sign out, with the signed-in email. Every row opens something real.

The training overview, week history, open workouts and the Workout history, Progress and Run history rows that used
to be here are gone from Me: they are in Train (Workouts lists recent workouts and Run history; Progress ends with
Workout history; Plan has the pass and weeks). Units is a row that opens a sheet rather than a switch in place.

Sync status says one word and one sentence from the real state: "Needs review" when a change needs a decision,
"Not synced" with "Can't sync right now" when the last attempt to reach the account failed (plus the number
waiting), "Waiting" while changes are only on this phone, and "Saved" only when none of those is true. Nutrition
goals shows the goals that were set, and "None set" otherwise; no number ever stands in for a goal.

## Deliberate differences from the references

| Reference | App | Why |
|---|---|---|
| Calories and protein against goals, with progress bars | the same, but only for a goal the person set; the rail stops at full while the words give the real total; "left" is stated only when every food that day has a value | no goal is suggested, and a remainder worked out from a partial sum would be invented |
| Photographs of each meal and exercise, a profile photo | none; an initial for the profile | no such images exist in the account, and none are licensed |
| A person in the workout photograph and on the pass | the supplied dumbbell illustration; a plain pass | the photographs supplied with the Today brief show no face; no synthetic anatomy to get wrong |
| Week tiles four across with small text, selected tile without its label | three across at phone width, every tile shows week, dates and state | the reference's labels were too small to read; three across fits "Sep 28 – Oct 4" on one line |
| System segment stays blue with Green selected | selected controls always use the chosen accent | a flaw in the reference |
| "Account & privacy" row on Me | "Delete account" directly in the Account group | it is the only account action there is; a page holding one row would be a detour |
| "Metric" for Units, "Device settings" for Motion & haptics | "Kilograms" / "Pounds"; "Device", or what was changed | the app's real choices, short enough to stay on the row's line |
| "YOUR PROFILE" in capitals, the mark above the title | "Your profile" in the same quiet line every tab uses, the mark at the top trailing edge | one header for all four tabs |
| A deep-coloured gradient pass | the pass is a plain card | no glossy gradients or heavy shadows |
| Green check marks for completed days | teal check marks | completion must not depend on, or be confused with, the accent |
