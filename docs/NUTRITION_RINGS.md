# Nutrition rings and macro composition (19 Nov 2026, `feature/nutrition-rings`)

Brief: make Today's and Eat's nutrition summaries easier to read at a glance with circular progress for calories and
protein, and add a macro-composition donut in the existing macro breakdowns. A presentation change only: the shared
assessment (docs/EAT_COMPANION.md › Shared assessment), goals, goal history, food records and every calculation are
unchanged. No API, model, migration, capability, sync, AI or allowance change. No new dependency (Flutter's
`CustomPaint`; the ring is the existing `ProgressRing` in `core/widgets.dart`).

## Goal rings (`features/nutrition/nutrition_surface.dart` › `NutritionSummary`, `GoalRing`)

`GoalRing` draws one `NutrientAssessment` and works nothing out: no data, no goals, no network. `NutritionSummary`
gives it the same coverage and goals on both screens, so Today and Eat can never disagree.

| | Today (compact) | Eat (prominent) |
|---|---|---|
| Ring | 56 px, both | calories 84 px, protein 64 px |
| Figures beside it | name · "1,650 / 2,300 kcal · 72 %" · state in words | name · amount in the serif and unit · "of 2,300 kcal · 72 %" · state in words · "650 kcal left" (exact only) |
| Arrangement | one above the other beside the photo; side by side when the panel is wide enough (≥ 360 text-scaled px) | the same, ≥ 420 px |

- **Colours and words are the assessment's**: `goalFill` / `goalText` / `goalStatus`, no thresholds of their own. Below,
  approaching, reached and above for calories; protein above its goal stays green "Goal reached · N g above target".
- **Above the goal** the arc stops at one full circle; the real percentage (rounded up, "107 %") and the excess ("161
  kcal over target") are in words. Never a second lap.
- **No goal**: a neutral disc (the recessed fill, no arc) with the nutrient's icon, the amount and "No goal"; no
  percentage. On an earlier day: "No goal recorded for this day". Setting goals stays Eat's existing **Set daily goals**
  / **Edit goals** link (Today keeps goals in Eat, as before).
- **No entries** is words ("No food logged yet" / "Nothing is recorded for this day…"), never a ring at zero. **A
  recorded zero** is a ring at 0 % with "0 kcal", "0 %" and its state.
- **Missing values**: each nutrient on its own. Nothing known: a dash and "No value entered yet", no percentage. A
  partial sum: "Known intake" in the state (also "Target reached · Known intake", "No goal · Known intake"), the arc in
  the neutral ink (`goalFill(neutral)` is now the panel's secondary ink, 3:1 on the track; the old grey was 2.6:1), never
  an amount left. Missing fat or carbs never touch calories or protein.
- **Earlier days** are compared only with the goal recorded for that day (`Kinds.goalDay`, not `changed`); Eat's panel
  now uses the same `_goals` rule as its briefing. Before this change an earlier day showed no goal at all.
- **Icons** (decoration, fixed size, never squeezing a number): calories `local_fire_department_outlined`, protein
  `set_meal_outlined`. Text is never shrunk into the circle: with little room or large text the ring goes above its
  figures (when the figures would keep under ~100 text-scaled px beside it), and the ring gives up size first.
- **Motion**: the existing `ProgressRing` appears at its value and moves only when the value changes; never on a
  rebuild, tab switch or return; not at all under Reduce Motion (`motion_test`).
- **Screen readers**: one node per ring, e.g. "Calories 1,650 kilocalories, goal 2,300 kilocalories, 71%, Room
  remaining, 650 kilocalories remaining"; the arc, icon and separate figures are excluded.
- **Removed duplication**: Eat's old lines "1,650 of 2,300 kcal · 650 kcal left" under the photo (they repeated the
  bars) and the two bars. Keys kept: `{today|eat}-goal-{calories|protein}` (now the ring) and `…-status`; new
  `…-percent`, `eat-goal-…-left`.

## Macro composition (`features/nutrition/macro_composition.dart`)

Composition, not progress: kept apart from the rings, with its own colours and no goal states.

- **Where**: the two existing macro breakdowns, no new panel. Eat: the recorded composition replaces the Carbs / Fat
  row inside the nutrition panel (`eat-macros`) when Customize tracking shows both carbs and fat; with one of them
  hidden the old row stays. Help me set my targets › See macro breakdown: the **Estimated target split** (a
  hypothetical day at the edited targets; protein as typed, carbs and fat the rounded estimate, "about").
  Titles say which: **Recorded macro composition** vs **Estimated target split**.
- **Energy, not grams**: each share is grams × 4 / 4 / 9 kcal (general Atwater factors, the same convention as
  `macrosFor`) over their sum; whole percentages by largest remainder, so they add up to 100 (ties go protein →
  carbs → fat). The caption says what the percentages are of: "Percentages of the 1,062 kcal from protein, carbs and
  fat (4, 4 and 9 kcal per gram)."
- **Recorded calories stay authoritative.** Nothing is adjusted to make the donut add up. When the macro energy and the
  recorded calories (complete) differ by at least 10 kcal and 5 %, a line says the recorded total stays as logged and
  why they can differ (rounding on labels, fibre, alcohol).
- **Partial or missing**: no split at all. A plain track, the legend with the known grams ("40 g · known") or a dash,
  and "Some foods have no protein, carb or fat value, so no split is shown." Never the known part presented as 100 %.
- **Genuine zero** (every value known and all zero): a plain track and "No energy from protein, carbs or fat was
  recorded, so there is no split." No division.
- **Colours**: protein blue `#2A78D6`, carbs orange `#C94F1D`, fat teal `#13866A`, the same in every theme and language.
  Not the goal green / gold / red; checked as a set with the dataviz validator (colour-vision separation all pairs, light
  and dark) and in `theme_test` for 3:1 on every pale panel and every page. Segments are flat-ended with 2 px gaps.
  Each legend row has the swatch, the name, the grams and the percentage: colour is never needed. Nothing to tap.
- **Screen readers**: one node, e.g. "Recorded macro composition. Protein 120 grams, 29%. Carbs 180 grams, 44%. Fat 50
  grams, 27%. Percentages of the 1,650 kcal from protein, carbs and fat (4, 4 and 9 kcal per gram)."

## Localization

en / fr-CA / ar: 12 new strings (`nr…`), 13 strings of the old bar lines removed (3,268 messages). Units and numbers
follow the existing formatters (`formatGrouped`, `formatPercent`, `withUnit`); in Arabic the ring sits on the
reading side and figures follow it.

## Verification

- `nutrition_rings_ui_test` (19): calories at recorded zero, below, approaching, reached and above (arc capped at 1.0,
  "107%", "161 kcal over target", remainder only below); protein above stays green; no goal (no ring, no %); missing
  calories vs missing protein independently and a partial sum; Eat with no entries vs a recorded zero (and zero macro
  energy); recorded calories unchanged beside a composition that adds to more; missing fat leaves protein exact and the
  donut without a split; earlier days with a recorded goal, without one and with a changed goal (never today's);
  one semantics description per ring and per donut, none for the figures alone; fr-CA and ar at 320 px with 2× text;
  Arabic ring placement; Log food, Saved meals & recipes and Edit goals still open.
- `macro_composition_test` (4): energy not grams, sums to 100, missing/partial give no split, zero, recorded calories
  explained not changed.
- `theme_test`: neutral arc 3:1 on its track and macro colours 3:1 on every panel and page, all six themes plus
  increased contrast.
- Existing suites updated to the ring wording (`eat_ui_test`, `food_ui_test`, `today_ui_test`, `nutrition_report_ui_test`,
  `target_helper_ui_test`, `widget_test`, `meal_copy_ui_test`, `nutrition_trends_ui_test`, `journey_food_test`).
- Renders with real fonts (`nutrition_rings_render_test`, gated; the same file renders `main` as **before**):
  `docs/evidence/nutrition-rings/{before,after}/{en,fr,ar}`: Today and Eat in light and dark for below, approaching,
  reached, above, no goals and incomplete; Eat's macro composition; the estimated target split; Eat in all six themes;
  320 px with 2× text in English, French and Arabic. Test renders, not device captures.
