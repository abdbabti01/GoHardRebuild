# Design system — Calm Momentum

The app's look: clean sans type (Inter), pearl surfaces in light, charcoal layers in dark and one chosen accent.
Introduced on 12 October 2026 and refined across all four tabs, forms and sheets on 13 October 2026 from the brief
and five references in `C:\dev\GoHard_UI_Food_Search` (one design family: Today, Train, Eat, Me, Add food). The
references are concepts with sample data; where they and real data, accessibility or truthfulness disagree, the
app follows the latter, and the differences are listed at the end.

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

Screens read colours only through `context.c` (`GoColors`). No screen carries its own colour values, and no text sits on a photograph.

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
- white text over a photograph (a helper check kept from the earlier design; no screen puts text on a photograph now).

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

## Add food, scanner, the food form and goals

| Screen | File | Notes |
|---|---|---|
| Add food | `features/nutrition/log_food_screen.dart` | Back, "Add food", a labelled Scan action; an editable meal with the date; the search field; quiet Search / Recent / Favourites / My foods scopes; All and category chips in Search; plain rows with thin separators (name, preparation or brand, the stated basis with calories, protein, a plus labelled "Choose <food>"); "Search more foods" and "Can't find it? Create your own food". Choosing a row opens the form; nothing on this screen logs. Behaviour and data: `docs/FOOD_DATA.md`. |
| Scan a barcode | `features/nutrition/barcode_scan_screen.dart` | The camera sits in a rounded panel inside the normal page; the typed-barcode field is always below it. |
| The food form | `features/nutrition/food_form.dart` | The same form for every entry path. A source card (the provider's full title, values per basis, credit) sits above the fields. Amount and unit side by side, stacked at large text or under 350 px. |
| Nutrition goals | `features/me/me_screen.dart` | Two optional fields that start empty. |
| Update notice | `app/app.dart` | Drawn over the open screen, so nothing underneath is lost. |

Checked by `test/food_ui_test.dart` and `test/food_search_test.dart`: contrast, tap-target size and labels in all six
themes; no overflow at twice the text size on a 320 px phone with the keyboard up; the query, scope, category, meal
and scroll position kept through the keyboard, a theme change and a round trip to the form.

## Today

Three modules of one shape (`_Module` in `features/today/today_screen.dart`): an icon tile, a small-caps label with
the state as an icon and a word, the content, a small photograph crop at the trailing edge, then one button and one
quiet link. Above them: the local date, "Today", the mark, and a greeting from the phone's local time and the first
word of the profile's own name (no name, no name shown).

| Module | What it shows | Where the rest lives |
|---|---|---|
| Workout | The workout's real name and state, "5 exercises · 18 planned sets". In progress on a plan: "6 of 18 sets recorded", a percentage and a rail (recorded, not completed). A manual workout: "N sets recorded", no percentage. One filled Start or Resume, and Details. | Details opens the existing sheet or record. Exercise order and prescriptions: that sheet, the recording screen and Train. The week: Train › Plan. |
| Rest, paused, done, starts later, block review, draft, no plan | The same module, text first, with no photograph. "Start a manual workout" and workouts saved for later stay below it. | Train › Plan. |
| Run | "Start run", or "Continue run" for the saved open run whatever day it began. Distance and Time appear only from saved values. No target, percentage or route. | History opens run history. An open run is never also listed under Recorded today. |
| Nutrition | Calories and protein from the same coverage Eat reads; a rail only for a goal that was set; unknown is a dash, a partial sum is marked "known"; one line when values are missing, which opens Eat. One Log food. | Carbs, fat, what is left, and the foods: Eat. |
| Recorded today | Finished workouts, and runs when there are several. Absent when there is nothing to list. | Histories: Train. Body measurements: Me. |
| Account not reached | One line, "Can't sync right now", with the number of changes waiting; a tap gives the explanation and "Try again". | Changes needing a decision keep their notice above the navigation bar. |

Heights at 390 px and normal text, measured in `test/today_ui_test.dart` with the real font: workout 197, run 150,
nutrition 176 in the fullest state (178 / 144 / 144 with a due workout and nothing logged). They are results, not
fixed heights: content and text size can grow them and the page scrolls. The photographs
(`assets/images/workout-hero.webp`, `run-cover.webp`, `nutrition-cover.webp`, generated illustrations supplied with
the earlier Today brief) are decoration: excluded from screen readers, decoded at the size of the crop (88 px
square times the pixel ratio), 64 px under 350 px width, and left out above 130% text.

## Train

Workouts / Plan / Progress under one header; the chosen section is kept in `shellProvider` through tab, theme and
accent changes.

- **Plan.** A flat pass (`_TrainPass`): the plan's real name, "Week X of Y" (calendar position), completed over
  eligible workouts with a rail (completion). "Choose a week" lists every week of any plan length, three across,
  two at 320 px, one per row at large text. A week's label comes from `weekStateOf` in
  `features/plans/week_widgets.dart`, first match wins: No workouts; Skipped; **Done only when every eligible
  workout has a recorded result**; Current; "X of Y" when something is recorded; Missed; Paused; Upcoming. A week
  whose dates have passed is never Done for that reason. Selection is the accent border and tint; "Current" is a
  word. The selected week lists weekday and date, name, "5 exercises · 18 planned sets" and a state pill with an
  icon and a word (Planned, Due, In progress, Completed, Partial, Skipped, Missed, Paused).
- **Workouts.** Open workouts, start a manual workout, start a run, the five most recent, and a History card
  (Workout history, Run history) that is always there.
- **Progress.** The same three questions and real counts as before; Workout history also in the empty state.
- The occasion sheet uses `showGoSheet`; recording, detail, plan setup and review screens use the shared cards,
  rows and tabular figures. Their actions, keys, timers and rules are unchanged.

## Eat

The local date with previous and next day; one card with the calorie total, one rail and the goal when set,
then Protein, Carbs and Fat with the protein rail when that goal is set. What is left or over is said only for a
complete total with a goal; a partial sum is "known". One "Log food" button. Each meal is a group: name, its
calorie subtotal, a plus that opens Add food for that meal, and one row per logged food with its own name, the
portion as it was stored, its known values and any sync mark. No photograph.

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
| A state pill beside WORKOUT / RUN on Today | the state as an icon and a word on the label's line | a pill beside the label wraps at 360–390 px next to the photograph |
| Separate colours for the calorie and protein bars | both use the chosen accent | one accent per look; no extra colours to keep accessible in six themes |
| A calorie ring on Eat, and a meal photograph | one bar; no photograph | one progress graphic per value; the photograph crowded the totals |
| One line per meal ("Eggs and toast") on Eat | one row per logged food | entries are never merged into an invented meal name |
| "View schedule" link on Train | none | the schedule is already on the page |
| A deep-coloured gradient pass | the pass is a plain card | no glossy gradients or heavy shadows |
| Green check marks for completed days | teal check marks | completion must not depend on, or be confused with, the accent |
