# Design system — Daily Rhythm

The app's look since 14 October 2026: a quiet editorial design with a serif for main page titles (DM Serif Display)
and Inter for everything else, warm light surfaces and layered charcoal-plum dark ones, one chosen accent, a
continuous daily rhythm on Today, a rounded floating navigation bar, and an optional weather-aware scene at the top
of Today. Built from the brief and seven references in `C:\dev\GoHard_Daily_Rhythm_Weather` (one design family:
Today, Train › Plan, Eat, Me, Add food, the portion form, Appearance; shown in Pink + Dark). It follows "Calm
Momentum" (12–13 October 2026), whose structure it keeps. The references are concepts with sample data; where they
and real data, accessibility or truthfulness disagree, the app follows the latter, and the differences are listed at
the end. Weather behaviour, provider and limits: `docs/WEATHER.md`.

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

Daily Rhythm (13 October 2026, from `C:devGoHard_Daily_Rhythm_Weather`): warm foregrounds, restrained warm surfaces
in light, layered charcoal-plum in dark. Accent is for interactive selection and progress only.

| Role | Light | Dark |
|---|---|---|
| Page | `#F5F2EE` | `#16141A` |
| Raised surface (cards, sheets, dialogs, fields) | `#FCFBF9` | `#1F1C24` |
| Recessed fill (tracks, unselected segments, neutral icon tiles) | `#EAE5DF` | `#2C2832` |
| Floating bar (`raised`) | `#FFFEFC` | `#262329` |
| Text / secondary text | `#1C1A1F` / `#5B5560` | `#F6F1EC` / `#B9B0B9` |
| Separator / control boundary | `#E0DAD3` / `#7A737C` | `#37323D` / `#8F8692` |
| Increased contrast: secondary / separator / boundary | `#38333B` / `#746D76` / `#4E4851` | `#DDD6DC` / `#8F8692` / `#BDB4BE` |
| Blue accent / selection tint | `#0062CC` / `#E6EEF9` | `#7DB8FF` / `#1C2A40` |
| Green accent / selection tint | `#147644` / `#E2F0E7` | `#72D6A2` / `#17302A` |
| Pink accent / selection tint | `#B0306E` / `#F9E7EF` | `#F58CB9` / `#3D2033` |
| Text on a filled accent | `#FFFFFF` | page |
| Success / warning / error | `#0C6B63` / `#7D5200` / `#B3261E` | `#5FD4C4` / `#F2C36B` / `#FFB4AB` |
| Header scrim over a scene (`scrim`) | page at 66% | page at 66% |

The scrim holds 4.5:1 for primary text over any pixel, black to white, so a header over a scene never depends on the
picture (`TabHeader(onBackdrop: true)`).

**Type.** Inter for everything, plus one serif, DM Serif Display (OFL, `assets/fonts/`), for page titles only:
the four tabs, Add food, Appearance and secondary page titles, through `context.pageTitleStyle` /
`Heading(serif: true)` / `TabHeader` / `AppPage`. Figures stay in Inter with tabular digits. Page titles grow with
the text setting up to 1.3x so a word never breaks.

**Shell.** The navigation bar floats inset (12 px from the sides, above the home indicator), rounded, on `raised`
with a thin border and one soft low shadow. Secondary pages have back navigation and no bar.

**New components** (`core/widgets.dart`): `ProgressRing`, `IconTile(circle: true)`, `RhythmTimeline`,
`ChoiceCard`, `TabHeader(onBackdrop:)`, `Heading(serif:)`.

### Calm Momentum (previous values, kept for history)

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
| Add food | `features/nutrition/log_food_screen.dart` | Back, serif "Add food", a labelled Scan action; the meal (editable) with the date; a rounded search field; quiet Search / Recent / Favourites / My foods tabs; category chips; plain rows (name, preparation or brand, stated basis with calories, protein, a round plus labelled "Choose <food>"); "Search more foods" in the accent and "Can't find it? Create your own food". Nothing on this screen logs. Behaviour and data: `docs/FOOD_DATA.md`. |
| The food form | `features/nutrition/food_form.dart` | Serif food name with its preparation; Meal and date; a "Food details" row (key `food-source`) that opens the provider's full title, values per basis, credit and barcode in a sheet; Amount and Unit side by side, the unit's definition only when the source states it ("1 egg = 50 g"), the amount in full ("1 egg (50 g)"); "Nutrition for …" as a read-out table where a tap corrects a value ("Your value"), unknown is "—"; one Log food. |
| Scan a barcode | `features/nutrition/barcode_scan_screen.dart` | The camera in a rounded panel; the typed-barcode field always below it. |
| Nutrition goals, update notice | `features/me/me_screen.dart`, `app/app.dart` | Unchanged in behaviour. |

## Today

A bounded header (`_Header` in `features/today/today_screen.dart`): the scene from `TodayBackdrop` (dusk, the
weather scene, or the plain page, as chosen in Me › Appearance › Today background) behind the local date, the serif
"Today" and a greeting from the phone's local time with the first word of the profile's name. The header text sits
on TabHeader's own scrim; `test/weather_contrast_test.dart` measures it at 7:1 or more against the worst pixel of
every scene in all six looks. Weather changes only that scene: never the modules, states, accent or navigation.

Below it, on the page (never over photography), `RhythmTimeline` joins three sections of comparable weight:

| Section | What it shows |
|---|---|
| Workout | Name and state; "5 exercises · 18 planned sets"; recorded planned sets as a ring ("6 of 18 sets", "33% recorded": recorded, not completed); a manual workout as a count with no percentage; one filled Start or Resume and Details (the existing sheet). Text-first states (rest, paused, done, starts later, review, draft, no plan) carry no gym photo. |
| Run | One Start run / Continue run for the saved open run; Distance and Time only from saved values; History. |
| Nutrition | Calories and protein from the same coverage as Eat, bars only for goals that were set, unknown as a dash, a compact missing-values line that opens Eat; Log food and Journal. |

"Start a manual workout", workouts saved for later, Recorded today (only activity not already shown, by identity)
and the connection notice are kept. Heights at 390 × 844 with the real font: workout 238, run 164, nutrition 215 in
the fullest state (194 / 164 / 164 quiet); nutrition starts on the first screen.

## Train

A bounded header with the static `ScenicBackdrop` (never weather) behind the date and serif "Train". Workouts /
Plan / Progress kept in `shellProvider`.

- **Plan.** The pass: the plan's name in the serif, "Week X of Y" (calendar position), completed over eligible
  workouts with a rail (completion), a small photo only for an active started plan. "Choose a week" lists every week
  of any length, three across when it fits. A week's label comes from `weekStateOf`
  (`features/plans/week_widgets.dart`), first match wins: No workouts; Skipped; **Done only when every eligible
  workout has a recorded result**; Current; "X of Y"; Missed; Paused; Upcoming. Selection is the accent border;
  "Current" is a word. The selected week lists weekday and date, a round icon, name, "N exercises · M planned sets"
  and a state pill with an icon and a word.
- **Workouts.** Open workouts, start a manual workout or a run, recent workouts, and History (Workout history, Run
  history), always there. **Progress** keeps its real counts.
- Recording, detail, plan setup and review, pickers and the occasion sheet use the shared system; behaviour, keys,
  timers and rules are unchanged.

## Eat

A bounded `ScenicBackdrop` header with the date, the serif "Eat" and previous / next day. One card: the calorie
total, one ring with the real goal when set (full when over, the centre giving the true percentage), what is left or
over only for a complete total with a goal, Protein with its bar when that goal is set, Carbs and Fat as known
totals. One "Log food". "Today's meals" in the serif: one grouped card, each meal with its icon, subtotal and a plus
for that meal, and one row per logged food with its own name, saved portion wording and known values.

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
| Sample name, date and figures (Babti, 13 October, 1,480 kcal, a 78 kcal egg) | the profile's own name, the phone's date, the account's records, the source record's values (a USDA egg is 72 kcal) | references are concepts with sample data |
| The scene running up behind the status bar | the scene starts below the status bar | the shell keeps a top safe area for all four tabs; changing it is a separate layout change |
| A vivid scene behind the header text | the scene shows in the open band above the date and softly behind the text | the text keeps 7:1 over every weather scene in all six looks; Light mode shows scenes more softly than Dark |
| Separate photographs for each weather | colour-graded, hazed treatments of the one supplied dusk photograph | no art pack was supplied and none could be produced here; see `docs/WEATHER.md` |
| Food photo in the Eat overview | none | the total, the ring and a photo do not fit at 390 px; the photo is decoration only |
| "Account & privacy" row on Me | "Delete account" directly in the Account group | it is the only account action; a page holding one row would be a detour |
| "Metric", "Device settings" | "Kilograms" / "Pounds"; "Device" | the app's real choices, short enough for the row |
| "‹ Back" text link on the portion form | the platform back arrow | the shared app bar keeps one back control everywhere |
| "View schedule" link on Train | none | the schedule is already on the page |
| Green check marks for done weeks | teal checks with the word "Done" | completion must not be confused with the Green accent |
| Calorie and protein bars in different colours | both in the chosen accent | one accent per look |
| One line per meal ("Eggs and toast") | one row per logged food | entries are never merged into an invented meal name |
