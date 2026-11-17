# Help me set my targets

Branch `feature/target-estimator` (from `main` 41fc375), 17 Nov 2026. **Not released: the calculation below needs a
review by a registered dietitian (or equivalent) before public release** (see *Open review questions*).

Eat › Edit goals (the goals sheet) keeps direct editing and gains a secondary, outlined **Help me set my targets**.
With no targets, Eat's nutrition summary already offers **Set daily goals**, which opens the same sheet. No new tab,
no onboarding step, no second place to manage goals. Me › Nutrition goals is unchanged except for its note.

Code: `app/lib/features/nutrition/target_estimate.dart` (pure calculator), `target_helper.dart` (three steps),
`nutrition_tools.dart` (the entry). Tests: `test/target_estimate_test.dart`, `test/target_helper_ui_test.dart`.

## Flow

1. **What's your goal?** Maintain weight / Lose weight / Gain muscle / Lose fat and build muscle, one line each.
2. **Tell us about yourself.** Age (whole years), height (cm, or ft + in), current weight (kg or lb), the sex the
   formula uses (with why, and *Prefer not to answer? Set targets manually*), and one activity question whose four
   choices describe daily life *and* workouts together, so exercise is never counted twice. The latest weigh-in from
   Body progress is used and shown with its date (an unknown-order day shows its average, as Body progress does);
   *Use a different weight* takes a weight for this estimate only. Units start from Body progress's and can be
   switched here (typed values convert) without changing Body progress's choice.
3. **Your starting targets.** Calories and protein first, as *Current X → suggested Y* when a goal is saved, each in an
   editable field. A sentence says why the numbers are what they are. Carbs and fat sit under *See macro breakdown*,
   follow the edited fields, and are labelled *Estimates only … not tracked*. Leon/Leona (or plain text when *Show
   coach on Train and Eat* is off) explains the method in fixed words; the numbers come from the calculator only.

Back keeps the answers; Cancel, the app-bar back or *Set targets manually* (every step) save nothing.

## What persists

| | Saved? | Where |
|---|---|---|
| Daily calories, daily protein | Yes, on **Use these targets** only | `ProfileRepository.setGoals` → profile `calorieGoal` / `proteinGoal`, the existing outbox and `profile` command, same validation (500–10,000 kcal, 10–500 g, whole numbers) as the goals form |
| Water goal | Untouched (`withWater: false`) | — |
| Carbs, fat | **No.** There is no carb or fat goal in the model | shown only |
| Goal, age, height, sex, activity, a typed weight | **No.** Page state only; never sent anywhere | — |
| Weigh-ins | Read only; nothing is created or changed | Body progress |

Targets never change by themselves when weight changes: the estimate is made once, when step 2's Continue is pressed.
Past days keep the goals recorded for them (`GoalDay` history is untouched). No model, migration, API, capability or
sync change. No network call: nothing goes to Groq/Ask GoHard and no AI allowance is used.

## Method

**Energy (maintenance).** National Academies of Sciences, Engineering, and Medicine, *Dietary Reference Intakes for
Energy* (2023), adult (19 y +) total energy expenditure equations, kcal/day = intercept + a·age + b·height(cm) +
c·weight(kg), by sex and physical activity level (PAL) category:

| | Intercept | Age | Height | Weight |
|---|---|---|---|---|
| Men, inactive | 753.07 | −10.83 | 6.50 | 14.10 |
| Men, low active | 581.47 | −10.83 | 8.30 | 14.94 |
| Men, active | 1,004.82 | −10.83 | 6.52 | 15.91 |
| Men, very active | −517.88 | −10.83 | 15.61 | 19.11 |
| Women, inactive | 584.90 | −7.01 | 5.72 | 11.71 |
| Women, low active | 575.77 | −7.01 | 6.60 | 12.14 |
| Women, active | 710.25 | −7.01 | 6.54 | 12.34 |
| Women, very active | 511.83 | −7.01 | 9.07 | 12.56 |

PAL categories: inactive 1.0–<1.53, low active 1.53–<1.68, active 1.68–<1.85, very active 1.85–<2.5. The activity
choices paraphrase NASEM Table 7-1 (inactive = daily living only; low active ≈ + 60–80 min walking; active ≈ + ~2 h
moderate activity; very active ≈ + ~2 h including vigorous). The test reproduces NASEM's worked example (woman, 22 y,
165 cm, 63 kg, low active = 2,275 kcal/day) and Health Canada's coefficients.

Why this method: it is the current US/Canadian reference, derived from doubly labelled water, and since 2023 its
population explicitly includes people with overweight and obesity. Its PAL categories cover all activity, so no
separate exercise multiplier can double count.

**Goal adjustments.**

| Goal | Calories | Protein (g/kg body weight) |
|---|---|---|
| Maintain weight | maintenance | 1.4 |
| Lose weight | maintenance − 500, never below 1,200 (women) / 1,500 (men); if maintenance is already at or below that, maintenance | 1.6 |
| Gain muscle | maintenance + 1,500 kJ (≈ 359 kcal) | 1.6 |
| Lose fat and build muscle | maintenance (same as Maintain; explained on screen) | 2.0 |

Protein is capped at 35 % of calories (rounded down) and the cap is shown. Fat is 30 % of calories; carbs are the rest
(never below 0). Rounding: calories to 10 kcal, grams to 5 g.

- 2013 AHA/ACC/TOS Guideline for the Management of Overweight and Obesity in Adults (Jensen et al., *Circulation*
  2014;129(25 Suppl 2):S102–S138): 500–750 kcal/day deficit, or 1,200–1,500 kcal/day women / 1,500–1,800 men. The
  lower deficit and the lowest prescriptions are used as the floor.
- Slater et al., "Is an Energy Surplus Required to Maximize Skeletal Muscle Hypertrophy Associated With Resistance
  Training", *Front. Nutr.* 2019;6:131: "start conservatively with an energy surplus within the range of
  ~1,500–2,000 kJ·day⁻¹" and monitor; the size needed is unknown. The low end is used.
- Jäger et al., ISSN Position Stand: protein and exercise, *JISSN* 2017;14:20: 1.4–2.0 g/kg/day for most exercising
  people (higher intakes may help preserve lean mass during energy restriction).
- Morton et al., *Br J Sports Med* 2018;52:376–384: gains in fat-free mass with resistance training level off near
  1.62 g/kg/day.
- Barakat et al., "Body Recomposition: Can Trained Individuals Build Muscle and Lose Fat at the Same Time?",
  *Strength Cond J* 2020;42(5):7–21: recomposition relies on resistance training and higher protein; calories are not
  pushed below maintenance here, so it does not overlap with Lose weight.
- IOM, *DRIs for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids* (2002/2005),
  AMDR: protein 10–35 %, fat 20–35 %, carbohydrate 45–65 % of energy.

## Scope and refusals

Adults 19–100 years, 120–230 cm, 30–250 kg (input bounds, not health ranges; 250 kg keeps the top protein inside the
goal editor's 500 g). Under 19: no estimate (growth isn't covered). Lose weight with BMI < 18.5: no estimate.
Missing or non-numeric answers: field messages, no numbers. Every refusal offers *Set targets manually*. Pregnancy
and breastfeeding are stated as out of scope (not asked). No rate of weight change is promised; the result says it is
a starting point to adjust after watching weight for a few weeks.

Limits stated by the sources: an individual's real need can differ considerably from the EER (NASEM; monitor body
weight); the right gain surplus is unknown (Slater); protein research is mostly in exercising people.

## Open review questions (before public release)

1. Protein per kg of *actual* weight for people with obesity (e.g. 140 kg × 2.0 = 280 g). The 35 % cap rarely binds;
   a reference-weight basis may be preferable.
2. The 1.4 g/kg Maintain value for people who do not exercise (RDA is 0.8; still inside the AMDR).
3. Whether the floor should also apply in other cases, and the wording of the activity examples against Table 7-1.
4. The body recomposition choice of maintenance calories versus a small deficit.
