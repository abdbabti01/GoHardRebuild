# Design system — Calm Momentum

The app's look since 12 October 2026: clean sans type (Inter), pearl surfaces in light, graphite layers in dark, one
chosen accent, a photographic workout feature on Today and a training pass on Train. It replaces the earlier
"Evening Club" serif look. The brief and the two approved references are in `gohard-design-brief/`.

## Where things live

| What | File |
|---|---|
| Colour tokens, type, radii, targets, motion, `ThemeData` | `app/lib/core/theme.dart` |
| Accent + mode preference, saved on the device | `app/lib/core/appearance.dart` |
| Shared components (buttons, segmented control, pass, rail, rows, page) | `app/lib/core/widgets.dart` |
| Week tiles, day strip, state pills | `app/lib/features/plans/week_widgets.dart` |
| Completion, plan weeks, recorded-set progress (pure logic) | `app/lib/features/plans/plan_progress.dart` |
| Appearance page | `AppearanceScreen` in `app/lib/features/me/me_screen.dart` |

Screens read colours only through `context.c` (`GoColors`). No screen carries its own colour values, except white
text on the workout photograph and on the pass, which sit on fixed dark surfaces.

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
| Page | `#F6F6F4` | `#101114` |
| Raised surface | `#FFFFFF` | `#1C1F24` |
| Recessed fill (tracks, unselected segments) | `#ECECE8` | `#272B32` |
| Text / secondary text | `#121417` / `#555B63` | `#F3F4F6` / `#ADB3BC` |
| Separator / control boundary | `#E0E0DB` / `#6E747D` | `#2E3239` / `#8A919B` |
| Blue accent / selection tint | `#0062CC` / `#E7F0FC` | `#77B6FF` / `#172C47` |
| Green accent / selection tint | `#147644` / `#E2F2E9` | `#6BD39C` / `#143527` |
| Pink accent / selection tint | `#B32E70` / `#FBE9F1` | `#F58CB9` / `#3F1E33` |
| Text on a filled accent | `#FFFFFF` | `#101114` |
| Pass (top → bottom), blue | `#0A63CB` → `#073F8C` | `#15457F` → `#0C2748` |
| Success / warning / error | `#0C6B63` / `#7D5200` / `#B3261E` | `#5FD4C4` / `#F2C36B` / `#FFB4AB` |

Changes from the brief's starting values, each made because the measured contrast asked for it: light blue
`#0068D9` → `#0062CC` and light pink `#B83275` → `#B32E70` (accent-coloured text on the selection tint was under
4.5:1); success is teal so that "completed" never looks like the green accent. Status is always an icon and a word.

With the phone's Increased Contrast setting, secondary text, separators and control boundaries move toward the
primary text colour (`highContrastTheme`). Nothing in the app uses blur or translucent panels, so Reduce Transparency
has nothing to change. With Reduce Motion, pages appear without a slide and rails and segments change without easing.

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

## Deliberate differences from the references

| Reference | App | Why |
|---|---|---|
| Calories and protein against goals, with progress bars | the same, but only for a goal the person set; the rail stops at full while the words give the real total; "left" is stated only when every food that day has a value | no goal is suggested, and a remainder worked out from a partial sum would be invented |
| Photographs of each meal and exercise, a profile photo | none; an initial for the profile | no such images exist in the account, and none are licensed |
| A person in the workout photograph and on the pass | the existing dumbbell photograph; a plain pass | the only licensed photograph in the project; no synthetic anatomy to get wrong |
| Week tiles four across with small text, selected tile without its label | three across at phone width, every tile shows week, dates and state | the reference's labels were too small to read; three across fits "Sep 28 – Oct 4" on one line |
| System segment stays blue with Green selected | selected controls always use the chosen accent | a flaw in the reference |
| "Week history" and "Progress overview" as separate cards on Me | one card: completion, then the last three weeks | a card inside a card otherwise |
| Units, Appearance, History, Settings as four rows | Appearance has its own page; units is a two-way switch in place | one tap fewer for a two-value choice |
| Green check marks for completed days | teal check marks | completion must not depend on, or be confused with, the accent |
