# Help me set my targets

First built on `feature/target-estimator` (17 Nov 2026, merged 18 Nov). Reviewed and reworked on
`feature/target-estimate-review` (19 Nov 2026, from `main` 67ca479). **Not reviewed by a registered dietitian (or
equivalent). That review is still pending and is required before public release** (see *Open review questions*).
Automated tests check arithmetic and behaviour against the published equations; they are not clinical validation.

Eat › Edit goals (the goals sheet) keeps direct editing and has a secondary, outlined **Help me set my targets**.
With no targets, Eat's nutrition summary offers **Set daily goals**, which opens the same sheet. Me › Nutrition goals
is unchanged except for its note.

Code: `app/lib/features/nutrition/target_estimate.dart` (pure calculator), `target_helper.dart` (three steps),
`nutrition_tools.dart` (the entry). Tests: `test/target_estimate_test.dart`, `test/target_helper_ui_test.dart`;
renders `test/target_render_test.dart` (gated, `docs/evidence/nutrition-targets/{en,fr,ar}`); native
`integration_test/journey_targets_test.dart` (not in the default run).

## Flow

1. **What's your goal?** Maintain weight / Lose weight / Gain muscle / Lose fat and build muscle. Choosing the last
   asks **What comes first?** with two choices and no default: *Keep my weight about steady* (maintenance) or *Put fat
   loss first* (the Lose weight deficit), each with its trade-off in one line.
2. **Tell us about yourself.** Age, height (cm, or ft + in), current weight (kg or lb), the sex the equations use (with
   why, and *Prefer not to answer? Set targets manually*), and **How active is your usual week?** (below). The latest
   Body progress weigh-in is used and shown with its date; *Use a different weight* takes a weight for this estimate
   only. Units start from Body progress's and can be switched here (typed values convert) without changing Body
   progress's choice. No answer is preselected.
3. **Your starting targets.** In order: Leon/Leona (or the same words as plain text when *Show coach on Train and Eat*
   is off) with this calculation's numbers; **Your goal** with **Change**; the approach in one sentence; editable
   **Daily calories** and **Daily protein**, each marked *Suggested estimate* or *Your edited target · suggested X*
   (with *Use suggestion*) and, when goals are saved, *Current goal X*; what is saved; the ledger **Estimated
   maintenance → Goal adjustment → Suggested calories** and **Protein: g per kg × weight**, with any floor or cap note
   and the rounding; then collapsed **Details used** (age, height, weight with its date or "entered for this estimate
   only", the sex input, activity; **Change details**), **See macro breakdown** (not saved), **How this was
   estimated** (method, sources, limits) and **Checking your starting point**. **Use these targets** is the primary
   action.

Back, Change, Change details, Cancel, the app-bar back and *Set targets manually* save nothing and keep the answers.
Each step opens at its top: the steps used to share one scroll view, so step 3 opened at step 2's scroll offset and
its title sat under the app bar (the partly hidden "Your starting targets"; reproduced in
`target_helper_ui_test` at 390 × 844, title at −833 px before the fix). Every step is now its own page.

**Edits are kept.** When the estimate is recalculated after Change / Change details, a field still holding the
previous suggestion follows the new one; a field the person edited keeps their number and says so.

## What persists

| | Saved? | Where |
|---|---|---|
| Daily calories, daily protein | Yes, on **Use these targets** only | `ProfileRepository.setGoals` → profile `calorieGoal` / `proteinGoal`, the existing outbox and `profile` command, same validation (500–10,000 kcal, 10–500 g, whole numbers) as the goals form |
| Water goal | Untouched (`withWater: false`) | — |
| Carbs, fat | **No.** There is no carb or fat goal in the model | shown only |
| Goal, priority, age, height, sex, activity, a typed weight | **No.** Page state only; never sent anywhere | — |
| Weigh-ins, Body progress units | Read only; nothing is created or changed | Body progress |

Targets never change by themselves. Past days keep the goals recorded for them (`GoalDay` history is untouched). No
model, migration, API, capability or sync change. No network call: nothing goes to Groq/Ask GoHard and no AI allowance
is used. Deterministic: the same answers always give the same numbers.

## Method (audited 19 Nov 2026)

### Energy: which equation, and why

**Chosen: NASEM 2023 adult total energy expenditure (TEE/EER) equations**, *Dietary Reference Intakes for Energy*
(National Academies, 2023, doi 10.17226/26818), adults 19 y and over, kcal/day = intercept + a·age + b·height(cm) +
c·weight(kg). Coefficients checked on 19 Nov 2026 against Health Canada's *Dietary reference intakes tables: Equations
to estimate energy requirement* (canada.ca), which reproduces them:

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

PAL bands (NASEM Table 7-1 footnote; Health Canada): inactive 1.0–<1.53, low active 1.53–<1.68, active
1.68–<1.85, very active 1.85–<2.50. The test reproduces NASEM's worked example (woman, 22 y, 165 cm, 63 kg, low
active = 2,275 kcal/day).

What the source says about scope: the equations are derived from doubly labelled water (DLW) measurements of
free-living people and estimate the intake that maintains weight "irrespective of body weight status" (NASEM ch. 7);
Health Canada lists no BMI restriction for adults beyond age ≥ 19, and separate equations for pregnancy and
lactation. NASEM gives a standard error of the predicted value of 342 kcal/day (men) and 241 kcal/day (women) and
says the equations "do not predict energy requirements for those seeking to lose or gain weight", and Health Canada
says body-weight change is the preferred indicator of energy adequacy. GoHard does not turn the SEPV into an on-screen
range (it describes a population, not this person); the result says it is an estimate and how to check it.

**Compared: Mifflin–St Jeor (1990)**, *Am J Clin Nutr* 51:241–247: RMR = 10·kg + 6.25·cm − 5·age + 5 (men) / −161
(women), from indirect calorimetry in 498 healthy adults aged 19–78, normal weight and obese. Frankenfield et al.
(*J Am Diet Assoc* 2005;105:775–789) found it predicted RMR within 10 % of measured for more non-obese and obese
adults than the other equations reviewed, with notable individual errors. It estimates **resting** expenditure only: a
daily total needs an activity multiplier (commonly 1.2–1.9) that is not part of the Mifflin paper and adds its own
error. NASEM's equations estimate the **total** daily expenditure directly from DLW and come with defined activity
categories, so they fit the question this screen answers. Not chosen: no averaging of methods, no RMR × multiplier,
no second activity factor on top of a PAL category. The choice was not made on which method gives lower numbers.
For the reference man (below), Mifflin RMR is 1,800 kcal; × 1.2 = 2,160, × 1.375 = 2,475, × 1.55 = 2,790 kcal,
against NASEM inactive 2,763: the Mifflin total depends almost entirely on which multiplier is picked, and no
multiplier is validated against these questions.

**Units.** 1 lb = 0.45359237 kg and 1 in = 2.54 cm, both exact. Switching units converts what was typed (one decimal).

### Activity: the whole usual week

One question, **How active is your usual week?**, with *"Think of an average day across your usual week: work,
getting around and workouts together. Workouts are already counted here, so don't add exercise calories on top."*
Each answer is one NASEM category; its example paraphrases NASEM Table 7-1, whose examples are "most appropriate for
individuals in occupations that require little physical exertion or movement, such as office work" and add activity
to activities of daily living (ADL: about 30 min walking and 90 min light-to-moderate household tasks):

| Answer (example on screen) | NASEM category | Table 7-1 basis |
|---|---|---|
| Mostly seated (desk or seated day with everyday walking and chores; includes a few workouts a week, such as 3 or 4 one-hour sessions) | Inactive | ADL only |
| Lightly active (plus about an extra hour of brisk walking or similar most days, at work or outside it) | Low active | ADL + 60–80 min walking at 3–4 mph |
| Active (about 2 extra hours most days, e.g. walking plus cycling or a sport, or work that moves you that much) | Active | ADL + 30–50 min walking, 45 min moderate cycling, 40 min doubles tennis |
| Very active (about 2 extra hours most days including hard effort, e.g. running, or heavy physical work) | Very active | ADL + 45 min cycling, ~25 min jogging, 60 min doubles tennis |

**GoHard's reading, not a validated mapping:** "3 or 4 one-hour workouts a week" under *Mostly seated*. Four hours a
week averages about 34 min a day; at roughly 3.5–6 METs (typical resistance-training intensities) that adds about
0.07–0.12 to a desk day's PAL of about 1.4, which stays under the 1.53 boundary. NASEM itself warns that the categories
do not correspond to physical-activity guidelines. Before this change the old wording ("an hour of walking or exercise
on most days" for Lightly active; "1½ to 2 hours … on most days" for Active) let a desk worker who trains four times a
week read themselves as Lightly active or Active; that is what made the reference man's maintenance 210–420 kcal
higher than the method implies (see *Before and after*).

### Goals: maintenance → adjustment → target

Maintenance is rounded to 10 kcal first; each adjustment is a whole number of kcal, so the three numbers on screen
add up exactly.

| Goal | Adjustment | Protein g/kg | Evidence | GoHard policy |
|---|---|---|---|---|
| Maintain weight | 0 | 1.4 | EER = intake for weight maintenance (NASEM) | 1.4 g/kg: low end of ISSN's 1.4–2.0 for exercising people (RDA 0.8) |
| Lose weight | −500 kcal | 1.6 | AHA/ACC/TOS 2013 obesity guideline (Jensen et al., *Circulation* 2014;129(25 Suppl 2):S102–S138): 500–750 kcal/day deficit, or 1,200–1,500 (women) / 1,500–1,800 (men) kcal/day. NASEM's own illustration of a loss intake, EER − 1.96 × SEPV, gives 472 (women) / 670 (men) kcal below | The low end, 500, for everyone; floor below |
| Gain muscle | +360 kcal | 1.6 | Slater et al., *Front Nutr* 2019;6:131: "start conservatively with an energy surplus within the range of ~1,500–2,000 kJ·day⁻¹" and monitor | 1,500 kJ (358.5 kcal) to the nearest 10 |
| Lose fat and build muscle — keep weight about steady | 0 | 2.0 | Barakat et al., *Strength Cond J* 2020;42(5):7–21: recomposition happens with resistance training and higher protein, trained and untrained | — |
| Lose fat and build muscle — fat loss first | −500 kcal | 2.0 | Murphy & Koehler, *Scand J Med Sci Sports* 2022;32(1):125–137: an energy deficit impairs resistance-training lean-mass gains (strength less so); their meta-regression put a ~500 kcal/day deficit at about the point where lean-mass gains disappear (mostly untrained participants; the threshold reading is disputed) | Same deficit and floor as Lose weight, with the trade-off said on screen, rather than inventing a smaller number |

The previous policy (recomposition always at maintenance, explained as "the same as Maintain weight") is replaced by
the explicit choice: neither priority promises fat loss or muscle gain, and nothing is inferred from BMI (no body-fat
level or training history is guessed).

**Floor (GoHard policy).** A deficit never starts below 1,200 kcal (women's equation) / 1,500 kcal (men's) — the
guideline's lowest prescriptions. If maintenance − 500 is below the floor, the target is the floor (*"Less than the
usual 500 kcal: GoHard's suggestions don't start below X a day."*); if maintenance is already at or below the floor,
there is no cut and a doctor or dietitian is suggested. The floor is a starting rule, not a statement that higher
intakes suit everyone; the wording says no more than that.

**Protein.** g/kg × the weight used (actual body weight: GoHard has no measured lean mass and does not invent an ideal
or adjusted weight), rounded to 5 g, capped at 35 % of the suggested calories (IOM 2005 AMDR upper limit for protein,
rounded down to 5 g so the cap is never passed). The cap is said under the protein line when it applies. Sources: Jäger
et al., ISSN position stand, *JISSN* 2017;14:20 (1.4–2.0 g/kg/day for most exercising people; more may help preserve
lean mass in a deficit); Morton et al., *Br J Sports Med* 2018;52:376–384 (fat-free-mass gains with resistance
training level off near 1.62 g/kg/day). At higher body weights per-kg amounts rest on less evidence (these studies were
mostly in leaner, exercising adults); *How this was estimated* says so for everyone rather than flagging anyone by BMI.
250 kg × 2.0 = 500 g, the goal editor's maximum.

**Carbs and fat (display only).** Fat 30 % of calories (inside the 20–35 % AMDR), rounded to 5 g; carbs the rest,
rounded to 5 g, so protein + fat + carbs land within 10 kcal of the calories. They follow the edited fields. If an
edited protein plus the fat share already passes the calories, carbs show 0 and a line says there is no room.
With high protein, carbs can fall below the 45 % AMDR floor; GoHard does not claim the AMDR for carbs.

**Rounding.** Calories to 10 kcal, protein to 5 g ("Rounded to the nearest 10 kcal and 5 g.").

### Who it is for (refusals)

Adults 19–100 years, 120–230 cm, 30–250 kg (input bounds, not health ranges). Under 19: no estimate (growth isn't
covered). Any deficit (Lose weight, or fat loss first) with BMI < 18.5: no estimate; the other goals still work.
Missing or non-numeric answers: field messages, no numbers. Every refusal offers *Set targets manually*. Pregnancy and
breastfeeding are stated as out of scope (not asked). No medication or medical-condition advice. No rate of weight
change is promised.

### Evidence vs GoHard policy, in one place

- **From the sources:** the TEE coefficients and PAL bands (NASEM 2023 / Health Canada); that EER is a maintenance
  estimate with individual error and body weight is the check; the 500–750 kcal deficit range and 1,200/1,500 kcal
  prescriptions (AHA/ACC/TOS 2013); the 1,500–2,000 kJ starting surplus (Slater 2019); protein 1.4–2.0 g/kg (ISSN 2017)
  and the ~1.6 g/kg plateau (Morton 2018); the AMDR shares (IOM 2005); the effect of a deficit on lean-mass gains
  (Murphy & Koehler 2022).
- **GoHard's choices:** NASEM rather than Mifflin × multiplier; the activity examples and the "3 or 4 workouts → Mostly
  seated" reading; one −500 kcal deficit for everyone; the floor as a starting rule; +360 kcal; 1.4 / 1.6 / 1.6 / 2.0
  g/kg by goal on actual weight; the 35 % cap; fat at 30 %; the recomposition priority reusing the loss deficit; the
  input bounds and the BMI < 18.5 refusal for deficits; rounding.

## Before and after (reference examples)

Assumptions: the formula's sex input as stated; height and weight typed as given; "desk job, trains four times a week
for about an hour" for the man. Calories / protein.

| Person | Activity | Maintain | Lose | Gain | Recomp, steady | Recomp, fat loss first |
|---|---|---|---|---|---|---|
| Man, 34 y, 170 cm, 199 lb (90.26 kg) | inactive (TEE 2,762.58) | 2,760 / 125 | 2,260 / 145 | 3,120 / 145 | 2,760 / 180 | 2,260 / 180 |
| | low active (2,972.81) | 2,970 / 125 | 2,470 / 145 | 3,330 / 145 | 2,970 / 180 | 2,470 / 180 |
| | active (3,181.11) | 3,180 / 125 | 2,680 / 145 | 3,540 / 145 | 3,180 / 180 | 2,680 / 180 |
| | very active (3,492.56) | 3,490 / 125 | 2,990 / 145 | 3,850 / 145 | 3,490 / 180 | 2,990 / 180 |
| Woman, 28 y, 5 ft 4 in (162.56 cm), 222 lb (100.70 kg) | inactive (2,497.63) | 2,500 / 140 | 2,000 / 160 | 2,860 / 160 | 2,500 / 200 | 2,000 / 175 (cap) |
| | low active (2,674.85) | 2,670 / 140 | 2,170 / 160 | 3,030 / 160 | 2,670 / 200 | 2,170 / 185 (cap) |
| | active (2,819.72) | 2,820 / 140 | 2,320 / 160 | 3,180 / 160 | 2,820 / 200 | 2,320 / 200 |
| | very active (3,054.73) | 3,050 / 140 | 2,550 / 160 | 3,410 / 160 | 3,050 / 200 | 2,550 / 200 |

Before (main a0ba9ac): within a category every value above was the same (checked for all 32 cells; the rounding change
moves other inputs by at most 10 kcal); recomposition had only "maintenance" (now *keep weight about steady*). What
changes for the man is the category the question leads to: under the old wording a desk worker training four times a
week could pick Lightly active or Active (Lose weight 2,470 or 2,680 kcal); the new wording places him in Mostly
seated (2,260 kcal), the category NASEM's definitions imply. For the woman nothing changes unless her week was
described the same way.

## Checking your starting point

A collapsed section on the result, with links to Body progress and History & trends: look at the weight trend over a
few weeks rather than any single weigh-in; a day with missing food entries is neither a zero nor a complete day, so
incomplete logs cannot show what someone really needs (GoHard does not calculate an "actual maintenance" from them);
scale weight alone cannot show fat or muscle change; GoHard never changes targets by itself. No adaptive engine,
dashboard or notification.

## Open review questions (for a qualified reviewer; pending)

1. Protein on actual body weight at higher body weights (e.g. 150 kg × 2.0 = 300 g before the cap): keep with the
   stated limitation, or use an adjusted/reference weight (which needs inputs GoHard does not have)?
2. The 1.4 g/kg Maintain value for people who do not exercise (RDA 0.8; within the AMDR).
3. One −500 kcal deficit for everyone vs a sex-specific or proportional deficit (NASEM's 1.96 × SEPV illustration:
   472 / 670 kcal); whether the 1,200 / 1,500 kcal starting floor is right for small, older or inactive people.
4. The activity examples and the "3 or 4 one-hour workouts → Mostly seated" reading against Table 7-1.
5. Recomposition "fat loss first" reusing the 500 kcal deficit given Murphy & Koehler's finding.
6. Upper age bound (100) and whether to state anything for older adults beyond the equations' own age term.
