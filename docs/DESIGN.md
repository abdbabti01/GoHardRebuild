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

Mode used to be an account field. It is now a device setting. One rule carries the old value over: if this device has
no mode yet and the account says `light`, Light is adopted. The account's `dark` was the old default rather than a
choice, so it does not override following the phone. The account field is left as it is and is no longer written.

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

## Deliberate differences from the references

| Reference | App | Why |
|---|---|---|
| Calories and protein against goals, with progress bars | totals only | the app stores no nutrition goals; a target would be invented |
| Photographs of each meal and exercise, a profile photo | none; an initial for the profile | no such images exist in the account, and none are licensed |
| A person in the workout photograph and on the pass | the existing dumbbell photograph; a plain pass | the only licensed photograph in the project; no synthetic anatomy to get wrong |
| Week tiles four across with small text, selected tile without its label | three across at phone width, every tile shows week, dates and state | the reference's labels were too small to read; three across fits "Sep 28 – Oct 4" on one line |
| System segment stays blue with Green selected | selected controls always use the chosen accent | a flaw in the reference |
| "Week history" and "Progress overview" as separate cards on Me | one card: completion, then the last three weeks | a card inside a card otherwise |
| Units, Appearance, History, Settings as four rows | Appearance has its own page; units is a two-way switch in place | one tap fewer for a two-value choice |
| Green check marks for completed days | teal check marks | completion must not depend on, or be confused with, the accent |
