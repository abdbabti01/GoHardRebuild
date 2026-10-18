# Design system — Daily Rhythm

The app's look since 14 October 2026: a quiet editorial design with a serif for main page titles (DM Serif Display)
and Inter for everything else, warm light surfaces and layered charcoal-plum dark ones, one chosen accent, a
continuous daily rhythm on Today, a rounded floating navigation bar, and an optional weather-aware scene behind the whole
of Today (15 October 2026: full-screen weather; the other tabs sit on calm page colours). Built from the brief and seven references in `C:\dev\GoHard_Daily_Rhythm_Weather` (one design family:
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
| Today's panels (`_panelColors` in `today_screen.dart`): tint / badge / button / ink | Green `#D4ECDD` / `#BADFC8` / `#143B2C` / `#0E1C17`; Blue `#D8E4F1` / `#BDD0E6` / `#173554` / `#0E1724`; Pink `#F2DCE6` / `#E6C3D3` / `#4F1E37` / `#20111A` | the same (pale panels in both modes) |
| Calm wash at the top of Train and Eat (`wash`) | halfway between page and recessed fill, fading into the page | the same |

The scrim holds 4.5:1 for primary text over any pixel, black to white, so a header over a scene never depends on the
picture (`TabHeader(onBackdrop: true)`).

**Type.** Inter for everything, plus one serif, DM Serif Display (OFL, `assets/fonts/`), for page titles and for the photo panels' titles and key figures (see App-wide panels):
the four tabs, Add food, Appearance and secondary page titles, through `context.pageTitleStyle` /
`Heading(serif: true)` / `TabHeader` / `AppPage`. Figures stay in Inter with tabular digits. Page titles grow with
the text setting up to 1.3x so a word never breaks.

**Shell.** The navigation bar floats inset (12 px from the sides, above the home indicator), rounded, on `raised`
with a thin border and one soft low shadow. Secondary pages have back navigation and no bar.

**New components** (`core/widgets.dart`): `ProgressRing`, `IconTile(circle: true)`,
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
primary text colour (`highContrastTheme`). Today's panels are opaque (no blur), so nothing depends on Reduce Transparency; with increased contrast their
secondary text moves toward their ink. With Reduce Motion, pages appear without a slide and rails and segments change without easing.

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

**Full-screen weather (15 October 2026).** The scene from `TodayBackdrop` (the weather, dusk, or the plain page, as
chosen in Me › Appearance › Today background) fills the whole of Today: from the top edge, behind the status bar, down
behind the floating navigation bar (the shell's `extendBody`). It is fixed to the screen while the page scrolls over
it, covers the screen as a crop of the one landscape (never stretched or repeated: on a portrait phone the middle of
the photograph, ridge a little above the centre, lake below) and carries one even veil, no fade into a solid body.
Every tab starts its title at `TabHeader.topInset`; a fixed `StatusBarVeil` in `features/shell/home_shell.dart`
keeps the status-bar icons readable and follows the sky on Today. Every list ends with the bar's height
(`MediaQuery.paddingOf(context).bottom`) plus 28, so the bar never covers the last control. Calories are shown in whole
kilocalories everywhere (`formatKcal`), display only.

The header (`_Header` in `features/today/today_screen.dart`): the local date, the serif "Today", a greeting from the
phone's local time with the first word of the profile's name, and the sky line. It sits on TabHeader's own scrim in
the sky's look (light lines over a dark sky, dark over a light one); `test/weather_contrast_test.dart` measures it at
6:1 or more against the worst pixel of every scene in all six looks. Weather changes only the scene and the header's
light or dark lines: never the sections, states, accent, appearance preference or navigation.

### Today panels (16 October 2026, from the approved Today mockup)

Below the header, in this order: **Workout** and **Nutrition** at the full width, then a compact **Run** tile (64% of
the width) with **History** beside it, the scene showing around all of them. The single blurred surface and the rhythm
thread are gone. Each panel (`_PanelSurface` for the surface, `_Module` for the content, `_PanelTheme` for the colours,
all in `features/today/today_screen.dart`) is:

- a pale, desaturated tint of the chosen accent with dark ink text, the same in Light and Dark, opaque, with a soft
  shadow and a thin edge to lift it off the scene, radius 18, 16 px from the screen edges;
- a photograph filling its trailing half at full height and fading into the tint toward the words (a `ShaderMask`
  gradient, so it adapts to any panel size); the words keep to the part the photograph has faded out of (at most about
  a third of the way into the fade, where it is under 20% opaque), and the button row may reach a little further;
- a state badge (the existing `StatusPill`), the display line in the serif (the workout's real name at 36, the calorie
  figure at 44, "Run" at 30), secondary lines in Inter, then one filled button in the accent's deep shade with a quiet
  link beside it ("Details ›", "Journal ›").

Only Today uses the panel palette (`_panelColors`); `goThemeOf` in `core/theme.dart` builds a theme from it, and every
other screen keeps `GoColors.of`. History sits on the scene in the header's sky colours on a `scrim` backing, so it
reads over any weather.

| Panel | What it shows |
|---|---|
| Workout | The badge (Due today, In progress, Saved for later, Completed, Skipped, Planned rest day, Plan paused, Starts …, Block ready to review, plan ready to review) and the real name; counts and the plan week, or the recorded-sets ring while in progress; Start or Resume (outlined when another workout is open in front, or when saved for later) and Details. Rest, done, skipped, paused, starts later, review, draft and no plan have no photograph and no Start. Under the lead, in the same panel: other workouts today, unresolved earlier workouts, Start a manual workout, workouts saved for later. A manual or other-day open workout has its own panel in front, without a photograph. |
| Nutrition | "No food logged today" in the serif (never "0 kcal") with the goal when one is set; or the calorie figure ("1,400 kcal"), "/ 2,200 kcal" and its bar when a calorie goal is set, protein on one line with its bar when a protein goal is set, unknown as a dash, partial sums marked "known"; the missing-values line opening Eat; Log food and Journal. The bowl is decoration, there on an empty day too. |
| Run | The badge (In progress, Paused, Finished today), "Run", "No run today" / "Started …", Distance and Time only from saved values; Start run or Continue run. |

Recorded today and the connection notice are panels too, without a photograph. With large text (over 1.3×) the
photographs give their room to the words, the button and link wrap, and History goes under the Run tile; on a phone
narrower than 350 px the Run tile takes the full width with History under it. Heights at 390 × 844 with the real
font, fullest state: workout 320, nutrition 309, run 261; quiet (due, nothing logged, no run): 260 / 214 / 176. The
mockup's due panel is about 183: the 52 px button and the plan-week line are kept on purpose.

**Photographs.** The three bundled ones (`workout-hero.webp`, `nutrition-cover.webp`, `run-cover.webp`, provenance in
`app/assets/PROVENANCE.md`), unchanged. They show the same subjects as the mockup (hex dumbbells by a bench, a chicken
and quinoa bowl, a runner's shoes on a riverside path) but are not the mockup's pictures, which are wet, rainy
variants; those were not supplied as files, so they are not used. Each is decoded for the box it is drawn in.

### Today option 2: photo-header tiles (18 October 2026, from `GoHard_Today_Option_2_Polish`)

The approved `references/approved-today-option-2.png` (a mockup; its numbers and weather are illustrative). Run / Walk
and Steps are two separate tiles (`_HeaderTile` in `today_screen.dart`), equal width and height side by side, stacked
at large text (> 1.3×) or below 350 px:

- A short photographic header (78 px, 88 at large text). The photograph takes the strip's trailing 72 % and blends into
  the tile's pale tint, so the label (an overline: RUN / WALK, STEPS) sits on the pale side, once, with no second title.
  The runner photograph (`run-cover.webp`) is aligned to its shoe; Steps uses the bundled
  `assets/images/steps-footprints.jpg`, aligned to the tread impressions. Below it: the content, then one action at the
  bottom; the tile's text takes its colours from the tile (`PanelTheme`), so it reads in dark themes too.
- Run / Walk, completed today: a small check and "Walk completed" / "Run completed" with "today" quieter under it; the
  distance as the main figure (when recorded), the time under it; no Distance / Time labels; **Start new** (full tile
  width) opens Ready. Open: the state (in progress, paused, interrupted, not saved yet; "Started <date>" when begun on
  another day) and **Resume** the same activity. Nothing yet: "No run or walk today", **Start**. No History on Today.
- Steps: the footprints icon, the count, "of N" and its bar only with a goal, then the source and "Updated <time>" on
  their own lines (the phone's clock format, non-breaking, so AM/PM never wraps alone). **Set a goal** without a goal,
  **Edit goal** with one; both open the shared Steps sheet and set nothing. Off, loading, not allowed, unavailable,
  failed: as before. Opening Today asks the phone for nothing.
- Water: **+250 mL / +8 fl oz** and **Other amount** as before. Undo is now inline: for 5 s after a drink it takes Other
  amount's place in the water line ("Undo 250 mL"), so nothing covers or moves Start or the tiles; screen readers hear
  "Added 250 mL of water. Undo available."
- Renders: `docs/evidence/today-option-2/` (Blue Light at 390 × 844 and full height, Blue Dark, Pink Dark without a goal,
  Green Light with Steps off, 320 px at 2×) and `docs/evidence/design/six-themes-today-steps.png`; device before/after:
  `docs/evidence/today-option-2/before-device-*` and `docs/evidence/screenshots/thw-02, 03, 08`.

### Matching tiles, history in Train and Eat, one-tap water (18 October 2026, from `GoHard_Today_History_Water_Corrections`)

Superseded on the same day by Today option 2 above (the photo-header tiles and the inline Undo).

- Run / Walk and Steps side by side are the same width and the same height (the taller one's content sets it, through
  `IntrinsicHeight`; `PanelSurface(fill:)` runs the photograph the full height and puts the action at the bottom),
  stacked at large text or below 350 px. Steps has its own photograph, `assets/images/steps-footprints.jpg` (from the
  handoff's `assets/steps-footprints.png`: a generated photograph supplied with the handoff, per its ASSETS.md; resized to
  960 × 640, JPEG 82), through the same `PanelPhoto` fade into the theme's tint. In a paired tile the words may use 85 %
  of the width over the photograph's faded side.
- Today has no Run / Walk History link: the tile's one action is Start / Resume. **Run / Walk history** is in Train ›
  Workouts, beside Run / Walk. Nutrition history is **History** in Eat, under the date.
- The Nutrition panel on Today: the words, Log food, Journal, and (when water is tracked) the water line with **+250 mL**
  and **Other amount**; no goals link and no sliders icon (both in Eat, Customize tracking now labelled).
- Renders: `docs/evidence/today-history-water/`; device captures `docs/evidence/screenshots/thw-01…08`.

### Steps beside Run / Walk, and Ready's order (18 October 2026, from `GoHard_Steps_RunWalk_UX_Corrections`)

Today: Workout, Nutrition, then **Run / Walk and Steps side by side** (stacked at large text or below 350 px; Run / Walk history moved to Train on 18 Oct, below), Run /
Walk History under them. Steps is shown before it is turned on ("Track your steps", Enable) so it can be found; it is
not in Nutrition's Customize tracking any more. Ready follows the approved "option 1" board: every setting above Start,
Start last in its own bar. The Run / Walk and Steps controls use the supplied SVG glyphs through `GoIcon`, tinted by
the theme; the rest of the app keeps its Material icons. Details: docs/RUN_WALK.md › Ready, › Steps › Where it is.
Before/after renders at 390 × 844 with the notch insets: `docs/evidence/ux-corrections/ux-{before,after}-*.png`.

## App-wide panels (16 October 2026, from `GoHard_Appwide_UI_Handoff`)

The Today photo panels are the language of the whole app. The boards (`GoHard_Appwide_UI_Handoff/references/`) are
visual references with illustrative data; nothing from them is hard-coded.

**Shared pieces** (`core/theme.dart`, `core/widgets.dart`; one set, used everywhere):

| Piece | What it is |
|---|---|
| `GoColors.accentDeep` / `onAccentDeep` | The filled button in every screen: the accent's deep shade with a light label, both modes. In Dark it carries a thin accent edge (≥ 3:1 on the page) so its shape reads on charcoal |
| `GoColors.tint` | The pale accent tint: photo panels, the chosen segment, the chosen choice card, the chosen week |
| `GoColors.panelOf(c)` | The panel palette (tint, dark ink, deep button, Light status colours), the same in Light and Dark |
| `PanelTheme` + `appContext(context)` | Puts content in the panel palette; sheets, dialogs and pickers opened from inside a panel open from `appContext` and keep the app's look (regression test in `today_ui_test`) |
| `PanelSurface`, `PanelPhoto` | The opaque tint with soft depth and a thin edge; a bundled photo on the trailing half fading into the tint (`ShaderMask`), decoded for its box |
| `PhotoPanel` | One summary per screen: words on the faded side (serif title or figure, quiet lines), then a deep button and a `QuietLink` |
| `Segmented`, `ChoiceCard` | Chosen = pale tint with the panel ink (a chosen segment no longer fills with the full accent) |

**Where it is used.** Today (unchanged composition). Train: the plan (`train-pass`), Progress (`train-progress-panel`),
open workouts on Workouts (`train-resume-<id>`), the recording screen's exercise panel (`workout-exercise-panel`) with
separate Target and Last recorded tiles, the workout detail figures, the builder's "plan in progress" and Guide me
suggestion. Eat: the day's summary with the bowl and Log food. Food form: the food's header, without a photograph.
Run: the elapsed time with the runner photo. Me › Nutrition goals: the optional-goals explainer. Appearance: a small
preview (dusk scene with the chosen guide). Sign-in: the dumbbells panel. Lists, sets, settings and the journal stay
quiet `GroupCard` rows. The serif is for page titles, panel titles and key figures, never in a control, row, field or the
navigation (`theme_test`).

**Photographs.** Only the bundled ones: `workout-hero.webp` (plan, progress, workouts, exercise, sign-in),
`nutrition-cover.webp` (Eat, goals), `run-cover.webp` (run), `scenic-dusk.webp` and the guides' busts (Appearance).
There is no photograph per food or per exercise: food rows and the food header have none, and every exercise panel
uses the same dumbbells. No asset was added.

**Deliberate differences from the boards.**
- No average pace on the run: the recorded time includes stretches GPS did not measure, so a pace from time and
  distance would be invented. No "GPS active" indicator beyond the tracking state the app really has.
- No food thumbnails, egg or barbell photographs; no Help row on Me (no destination exists).
- The builder's workout cards stay ordinary cards (their move buttons and menus open popups that must keep the app's
  look); the board's pale cards with photos are not used there.
- Me's profile row reads "Edit profile" (what it opens), not "Account settings".
- Sign-in uses one show/hide button in the password field, not both an eye and a checkbox (the brief asks for one
  control); its tagline is our own words.
- The plan week selector wraps all weeks (any length), rather than the board's fixed two rows of four.

### Goals, water and Customize tracking (17 October 2026)

- **Daily goals from Today and Eat** (Today's link removed later the same day; see "Goals belong to Eat"). The Nutrition summary on both ends with one quiet line: "Set daily goals" while
  no goal is set (also on a day with nothing logged), "Edit goals" once one is, and a labelled tune icon,
  "Customize tracking". Goals open a compact sheet in the app's own look (`showGoalsSheet`, opened from `appContext`)
  with the same `GoalsEditor` Me › Nutrition goals uses: one form, one validation, one save path
  (`ProfileRepository.setGoals`), fields empty unless a goal is saved, nothing suggested. The sheet says the goals
  repeat every day. Today, Eat and Me all read the one profile, so a save shows everywhere at once.
- **Water** (off until turned on; data in docs/FOOD_DATA.md › Water). A compact line under the figures: a droplet,
  "Water 750 / 2,000 mL" and, when a goal is saved, the same 6 px bar and real share ("38%", also "120%") as the
  calorie and protein goals (the bar full at the goal, the words keep the real amount); without a goal only the
  amount, no bar or percentage. Always the chosen unit (mL or fl oz), never switching to litres. An add button. It
  opens the water sheet: the day's total in the serif with "/ goal" and the bar, three quick amounts in the chosen
  unit, another amount, Add, Undo in the message bar, and the day's entries, each tappable to correct and with a
  remove button. No goal shortcut in the sheet.
- **Goals belong to Eat (17 Oct 2026, later).** Today shows the totals and progress toward saved goals and keeps Log
  food, the water sheet and Customize tracking, but no "Set daily goals" / "Edit goals". Eat's summary keeps the goals
  link to the shared form (calories, protein, water). With water shown and no water goal saved, the form offers
  "Suggested starting goal: 2,000 mL daily." (in fl oz when chosen) with one line ("A general starting point; your
  needs may differ. Only water you log is counted."), "Use 2,000 mL" (fills the field; nothing is saved until Save
  goals) and an info button explaining that needs vary, other drinks and food contribute, and only logged water is
  counted. It disappears once the field has a value, and never appears over a saved goal. No calorie or protein goal
  is suggested; nothing is worked out by AI or from the weather.
- **Customize tracking.** A short sheet of switches: Water, Carbs, Fat. Calories and protein always stay. Hiding is
  presentation only; it is kept per account on this phone, like the coach preferences. Water is offered only where
  the server declares `water.entries`.
- **Eat's summary** is now the same compact composition as Today's Nutrition panel (calories in the serif and
  protein, each with its goal bar, the deep Log food beside the full-height bowl), with Eat's own extra lines under
  it: what is left or over, carbs and fat (when shown), the missing-values note, water, then the goals line. The
  separate calorie ring is gone: one bar per goal, as on Today.
- **Meal icons**: one outlined Material family on the same tile: Breakfast `wb_twilight` (sunrise), Lunch
  `light_mode` (sun), Dinner `dark_mode` (moon), Snack `cookie` (Material Icons has no apple fruit; `Icons.apple` is
  the brand logo).
- **Train's icon** in the navigation bar lies flat (the Material dumbbell rotated 45°), as in the boards.

## Train

The calm wash (`QuietBackground`, `GoColors.wash` fading into the page) behind the date and serif "Train"; no
scene, no weather. Workouts /
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

### Plan builder and built plans (16 Oct 2026; rules and contract in `docs/TRAINING_PLANS.md`)

- **Create plan** (`features/plans/builder/`): two `GroupRow` choices, "Start from a template" and "Build my own"; a
  plan in progress offers Continue / Start over. Then four steps on `AppPage` with an overline "Step N of 4 · Name",
  a thin `ProgressRail` and Back / Next in the bottom slot (never under the floating bar or the keyboard): Availability
  (frequency chips, weekday chips, equipment, optional planned time, experience behind a disclosure), Structure
  (templates as concise rows with the suggestion and its one-line reason, a readable preview of names and sequence;
  name, Fixed weekdays / Rotating sequence with one sentence each, day assignment or cycle with Move up / Move down,
  start and length), Workouts (each workout's exercises as "3 × 8–12 · 90 s rest", optional "Target 60 kg" on its own
  line with a flag icon, notes; every reorder has buttons, no drag), Review (real dated rows with rest days, or the
  cycle with projected dates; the plan it replaces, named; Activate plan / Save draft, or Save changes from an
  effective date when editing). No photographs in the builder.
- **Plan tab**: the pass shows the plan name; under it "split · mode" and "Planned time N min" (chosen, never
  calculated). Fixed plans keep the week grid. Rotating plans show a cycle strip (the next step has a border and the
  word "Next"), "Cycle N", a "Coming up" week strip and the next steps as rows; progress is "N sessions completed this
  week" and "step p of L", never a percentage. Manage holds Edit plan, Pause, Duplicate, Review/finish and Create a
  different plan; a saved plan's page holds Archive.
- **Workout screen**: "Target 60 kg" (the plan's) and "Last time 57.5 kg × 8" (the record) are two separate lines;
  the target never fills the entry.

### Today's training states, guide and coach (15 Oct 2026; `docs/TRAINING_PLANS.md` › Today, `docs/COACH.md`)

- **Today's Workout module** says what the plan says about today and nothing else: the occurrence's own name with
  Due today / In progress / Saved for later / Skipped today / Completed / Partly completed as a word and an icon; a
  "Next:" line on its real date, or "Next in your rotation:"; "Planned rest day" only when the plan has nothing dated
  today. Only a due or in-progress workout has the training photograph. Other occurrences on the same day are compact
  "Also today" rows. An open manual workout is its own compact entry above it (Manual workout · In progress · Resume
  workout, the one filled button); the plan's Start then becomes the outlined button. Skipped today offers Undo skip
  as the quiet link while it is safe, and a rotation offers "Train this now" (outlined) for its next workout.
- **Create plan** offers two `ChoiceCard`s, Guide me and I know what I want, into the same four-step builder. Guide
  me's Structure step shows one suggestion card (real split name, the week on the person's own days, a one-line reason
  tied to their answers) with Use this starting plan, Compare splits and Why this suggestion?, and at most two
  alternatives. Quick-guide sheets are labelled "Quick guide · built in" and never look like a chat answer.
- **Exercise info** is an "About <name>" icon button on each exercise row, opening a sheet (muscles, equipment, role,
  cues, benefits, limitations, alternatives, the prescription in `3 × 8–12` notation). Since 18 Oct 2026 it is the one
  exercise sheet with the demonstration (`docs/EXERCISE_DEMOS.md`), reached from the picker, the builder and the workout.

### Exercise demonstrations (18 October 2026, from `GoHard_Exercise_Demonstrations`)

- The media area sits under muscles and equipment: a bounded box (16:9 of the clip's own shape, at most ~40 % of the
  screen, never cropped: `BoxFit.contain` on black for clips, on white for illustrations) in the theme's field radius
  with the divider edge. Its one control before Play is a round 64 px Play on a dark scrim.
- Controls under it are the app's own: Material rounded icons (play, pause, replay, fullscreen) at 48 px targets and the
  `Segmented` control for 0.5× / 1×; captions in Inter. No emoji, no icon pack, no gestures needed.
- "How to do it" is a 19 px title (`titleStyle`, Inter) with Setup / Movement / Common mistakes as the usual section
  labels and bullets. Credits and sources are captions at the end, the media credit apart from the text's sources.
- Picker rows with a clip get a 56 × 40 static thumbnail (the poster, decoded at its size) and a quiet "Demo" text
  button; other built-in rows an (i). In the workout the action is a text button in the exercise panel's action row,
  under the name, below the panel's words and never competing with Complete set.
- Full screen is a black page with the same controls on a surface panel; it leaves orientation and system bars alone.
- Light/Dark/accents need no new tokens: everything uses `c.sunken`, `c.divider`, `c.text`, `c.secondary` and the
  existing buttons; the panel action takes the panel's dark ink (`PanelTheme`).
- **Leon and Leona**: the compact avatar sits in a 48 px `CoachHelpButton` beside the builder's progress bar (Structure:
  "Ask GoHard about this split", with the one-time "Need help choosing a split?" hint; Workouts: "…about this workout").
  The full figure appears only in Ask GoHard's empty state, at 120 px, when the text is not enlarged and the screen is
  at least 640 px tall. The art is never tinted: the accent colours only the controls and the selected ring around it.
  The avatars appear nowhere on Today, workouts, runs or review screens, and there is no coach tab.
- **Ask GoHard** is a pushed page: heading, a quiet "AI training assistant" label, the compact avatar, "About: <split,
  workout or exercise>", suggested questions as wrapping chips, the conversation, and the composer with Send above
  the keyboard. AI answers carry an "AI-generated" label; answers asked against an earlier draft say so. A suggested
  change is a card with Preview change; the preview sheet lists every before → after, the scope pill "Draft only", and
  Apply to draft / Keep current.
- **Motion**: only the hint's 200 ms fade-and-scale entrance (`Motion.quick`, instant under Reduced motion or the
  phone's Reduce Motion). The pictures are static PNGs: nothing blinks, talks, walks, waves or "thinks", and no
  haptic fires for a hint.

### Owner exercise videos (19 October 2026, docs/OWNER_EXERCISE_VIDEOS.md)

- Me gains a "GoHard owner" group with **Manage exercise videos** only for the account the server names; nobody else
  sees a trace of it. The exercise sheet's owner-only **Manage demonstration** is a quiet text button after the credits.
- The manager is an ordinary AppPage: serif title, a caption saying publishing reaches everyone, the coach's one-time
  line (CoachSpot, hint policy), one filled **Upload video**, a search field and ListRows whose subtitle is the status in
  words (No owner video / Draft / Processing / Ready to preview / Published / Failed, plus "bundled demonstration shown").
- An exercise's page separates **What everyone sees now** (a Panel: the published owner video with Unpublish, or the
  bundled credit, or none) from the **Owner video / Replacement** being prepared. Upload shows real bytes sent on the
  app's ProgressRail with Cancel; Processing is a small indeterminate spinner with words (no invented percentage); Ready
  shows the processed clip in the existing player (no Download for a private preview) and one filled **Publish**, which
  asks before it reaches everyone. Errors are StatusLines in plain words with Try again.
- Details are ordinary TextFields, a switch for someone else's footage (licence, links) and a checkbox for the rights;
  Material rounded icons only. No new tokens: Light/Dark/accents and large text use the existing components.

## Eat

The calm wash behind the date, the serif "Eat" and previous / next day; no scene, no weather. One card: the calorie
total, one ring with the real goal when set (full when over, the centre giving the true percentage), what is left or
over only for a complete total with a goal, Protein with its bar when that goal is set, Carbs and Fat as known
totals. One "Log food". "Today's meals" in the serif: one grouped card, each meal with its icon, subtotal and a plus
for that meal, and one row per logged food with its own name, saved portion wording and known values.

**Meal hierarchy (17 Oct 2026).** Each meal group reads parent → foods → action:
- Heading: the outlined meal icon (sunrise / sun / moon / cookie) on its tile, the meal's name at 18 px bold, and the
  subtotal as a quieter second item (14.5 px, secondary colour, "known" when partial, "Calories unknown" when none is
  known). An empty meal shows no subtotal and no "Nothing logged" line.
- Foods: unchanged rows (name, saved portion, known macros, kcal or a dash, opens the entry).
- "+ Add food": a footer, 15 px medium in the accent with a small plus, no tile, 48 px tall across the card; read out
  as "Add food to lunch". Opens Log food for that meal and the day shown; nothing is logged until saved.
The coach speaks under the title (docs/COACH.md › Train and Eat); with Show coach on Train and Eat off, the small
avatar beside the date arrows opens the journal help instead.

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

Appearance (15 Oct 2026) adds **Coach avatar**: two equal cards, "Leon, lion" (default) and "Leona, lioness", selected
by a check, the accent border and a tint (never colour alone), never chosen from the profile; a **Coaching hints**
switch; and **Show coaching hints again**. All three are kept on this phone with Motion & haptics and change nothing
else (no route, draft, conversation or other appearance setting).

Refined 15 Oct 2026 (later): the two coach cards are their own compact cards with **64 px** pictures above "Leon /
Lion" and "Leona / Lioness" (56 px beside the name, stacked, above 1.5× text), check badge + accent border + tint +
bolder name when selected, read as one-of-two selected buttons. The full figures carry a soft warm off-white rim
(2 px at the 420 px asset, 25 % opacity, behind the art) baked by `scripts/build-coach-art.ps1`, so the charcoal
clothing separates from dark surfaces; invisible on light ones; fur, faces and clothing keep their exact colours.

## Deliberate differences from the references

| Reference | App | Why |
|---|---|---|
| Sample name, date and figures (Babti, 13 October, 1,480 kcal, a 78 kcal egg) | the profile's own name, the phone's date, the account's records, the source record's values (a USDA egg is 72 kcal) | references are concepts with sample data |
| The scene running up behind the status bar | the same on Today, the only tab with a scene; a page-coloured veil (66%) over the status-bar inset keeps its icons readable (≥ 11:1 measured over every scene) and dims that strip slightly | the status bar must stay legible over bright and dark scenes alike |
| A vivid scene behind the header text | the scene shows clearly above and around the text and softly behind it | the date, title and greeting keep ≥ 9:1 over every scene in all six looks (measured with the header scrim) |
| Separate photographs for each weather | painted skies behind the one supplied photograph's silhouettes: same lake, hills and trees, six weathers × day/night, static | no art pack exists; see `docs/WEATHER.md` |
| Food photo in the Eat overview | none | the total, the ring and a photo do not fit at 390 px; the photo is decoration only |
| "Account & privacy" row on Me | "Delete account" directly in the Account group | it is the only account action; a page holding one row would be a detour |
| "Metric", "Device settings" | "Kilograms" / "Pounds"; "Device" | the app's real choices, short enough for the row |
| "‹ Back" text link on the portion form | the platform back arrow | the shared app bar keeps one back control everywhere |
| "View schedule" link on Train | none | the schedule is already on the page |
| Green check marks for done weeks | teal checks with the word "Done" | completion must not be confused with the Green accent |
| Calorie and protein bars in different colours | both in the chosen accent | one accent per look |
| One line per meal ("Eggs and toast") | one row per logged food | entries are never merged into an invented meal name |

## Screen inventory against the approved boards (17 Oct 2026)

Compared with `GoHard_Appwide_UI_Handoff/references/00`–`04` using the current Flutter renders (`render_test`, all six
looks, 320 px at 2× text; `docs/evidence/design`) and device captures (`docs/evidence/screenshots/coach-tabs-*`,
`appwide-*`). "Matches" means the approved direction (pale tinted photo panels with dark ink, serif titles and key
figures, sans controls, deep accent buttons, Light/Dark foundations, independent accents), not pixel identity.

| Screen | Status | Note |
|---|---|---|
| Today (panels, weather, temperature, greeting coach) | Matches | unchanged in this pass |
| Train › Workouts, Plan, Progress | **Corrected** | the speaking coach under the sections replaces the circular launcher; no-plan empty paragraph and its one-time spot replaced by the coach's invitation with Create my plan in the bubble (before/after: `docs/evidence/coach-tabs/before|after/new-account-*`, `full-plan-light`, `workouts-light`, `progress-light`) |
| Plan builder (Create plan, four steps, compare sheets) | Matches | entered directly from Create my plan; Continue my plan reopens a saved draft |
| Workout recording, workout detail, history | Matches | help stays a sheet from the app-bar avatar (fields, timer and keyboard stay clear) |
| Eat | **Corrected** | speaking coach under the title; meal groups as heading → foods → small "+ Add food" (`coach-tabs/…/full-eat-*`, `new-account-eat`, `large-text-eat-goals-320`; device `coach-tabs-04/05/08`) |
| Add food (search, Recent / Favourites / My foods, scanner, Enter it yourself) | Matches, one deliberate difference | rows without food photographs (below) |
| Food form / portions | Matches | |
| Customize tracking sheet | **Corrected** | says when the choices follow the account |
| Run, run history | Deliberately differs | no "GPS active" line and no pace unless measured (below) |
| Me, Units, Edit profile, Delete account | Matches | no coach on Me: Me is about the person (the board shows one) |
| Appearance | **Corrected** | adds Show coach on Train and Eat beside Show coach on Today |
| Nutrition goals (page and sheet) | Matches | |
| Sign-in, registration, Choose your coach, optional features | Matches | |
| Ask GoHard | Matches | |
| Conflict review, dialogs, loading / empty / error states | Matches | renders `state-dialog-*`; sync review unchanged |

Deliberate differences found in this pass (in addition to the table above it):

| Board | App | Why |
|---|---|---|
| Food thumbnails in search results | clean rows without photographs | no licensed per-food image set; a wrong or generic photo would misrepresent the food |
| A small coach with a bubble at the top of Add food, workout recording, nutrition goals and Create plan | a help entry (the avatar) that opens the bubble in the page or a sheet; introductions once | a permanent bubble there would sit over fields, timers and the keyboard |
| Coach beside the "Train" title | under Workouts / Plan / Progress | at large text the bubble grows; the sections must stay at the top |
| Collapsible meals with chevrons, "Nothing logged" | every meal open; empty meals show only the heading and "+ Add food" | nothing is hidden behind a tap; no repeated explanation |
| "GPS active · Tracking your run", pace | distance and time from saved or measured values only | no fake signal state or estimate |
| Coach on Me | none | Me is the person's settings, not another coached page |

Still pending, with the blocker:
- A physical phone (look, brightness comfort, scroll smoothness, coach frame rate, VoiceOver/TalkBack by ear): no device
  attached to this machine; everything above is renders and the Android emulator.
- System mode following the phone's setting on a device: covered in widget tests only.
- The hosted testing API (checked 17 Oct 2026): it declares `water.entries` but not `profile.tracking-display`, so a
  hosted account keeps its display choice on each phone until this branch reaches `main` and Railway deploys it
  (migration `AddTrackingDisplay` runs in the pre-deploy step). The app sends nothing new to it meanwhile.
