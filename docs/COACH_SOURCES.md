# Quick guide: claim-to-source audit

Audit of `coach-guide.json` (7 splits, 50 exercises, 10 terms) on **15 Oct 2026** by the developer, on branch
`agent/guide-audit`. See `docs/COACH.md` for the schema.

## Two different things

| | Status |
|---|---|
| **Source verification**: does each recommendation match what the cited source says, with its conditions? | Done 15 Oct 2026 by the developer, against the sources below. |
| **Professional review**: is the content sound and safe as coaching? | **Not done.** No qualified coach or clinician has reviewed it. `reviewNote` says so. |

Source-checking does not make the content individual advice, injury advice or a guarantee of results.

## Sources opened

| ID | Source | What was read |
|---|---|---|
| `acsm-2009` | ACSM position stand, *Progression models in resistance training for healthy adults*, MSSE 2009;41(3):687–708, PMID 19204579 | Abstract (NCBI E-utilities) and **full text** (22-page PDF copy of the published article, sfu.ca course mirror; the journals.lww.com page itself did not load). |
| `acsm-2026` | ACSM position stand, *Resistance Training Prescription for Muscle Function, Hypertrophy, and Physical Performance in Healthy Adults: An Overview of Reviews*, MSSE 2026;58(4):851–872, Currier et al., PMID 41843416, PMC12965823 | **Full text**, open access (PMC XML via E-utilities). It states that it updates the 2009 stand. |
| `ramos-campo-2024` | Ramos-Campo et al., *Efficacy of split versus full-body resistance training…*, JSCR 2024;38(7):1330–1340, PMID 38595233 | **Abstract only**; full text is paywalled (JSCR). |
| `schoenfeld-2016-rest` | Schoenfeld et al., *Longer interset rest periods enhance muscle strength and hypertrophy in resistance-trained men*, JSCR 2016;30(7):1805–1812, PMID 26605807 | Abstract only. |
| `schoenfeld-2019-frequency` | Schoenfeld, Grgic, Krieger, *How many times per week should a muscle be trained…*, J Sports Sci 2019;37(11):1286–1295, PMID 30558493 | Abstract only. |
| (not cited) | Schoenfeld, Ogborn, Krieger, *Effects of resistance training frequency on measures of muscle hypertrophy*, Sports Med 2016, PMID 27102172 | Abstract read. Not cited: its "twice a week beats once" conclusion is superseded by the larger 2019 meta-analysis above (no significant difference when volume is equated). |
| (could not open) | NSCA *Basics of Strength and Conditioning* manual (nsca.com) | Blocked (HTTP 403 / Cloudflare). No NSCA technique text was read, so none is cited. ExRx and unofficial "NSCA manual" mirror PDFs were rejected as not authoritative. |

## Terms

| Claim | Source (section / finding) | Status |
|---|---|---|
| **Rest** | 2009: strength, "at least 2–3 min … for core exercises using heavier loads"; "1–2 min" for assistance exercises (Rest Periods, strength; Table). Hypertrophy: "1- to 2-min rest periods … in novice and intermediate training". Endurance: 1–2 min for 15–20+ reps, < 1 min for 10–15 reps. 2026: strength not affected by short (< 1 min) vs long (> 1 min) rest; insufficient data for hypertrophy. Schoenfeld 2016: 3 min > 1 min for strength and some muscle size in 21 trained men. | **Corrected.** Old: "The ACSM position stand suggests at least 2–3 minutes for heavier multi-joint lifts and 1–2 minutes for lighter accessory exercises" (no goal condition; written from memory). New: the 2009 figures with their goal/experience conditions, plus the 2026 finding and the 2016 trained-men study. |
| **Progression** | 2009 (Progression, strength): "2–10% (lower percent for small muscle mass exercises, higher percent increase for large muscle mass exercises) increase in load … when the individual can perform the current workload for one to two repetitions over the desired number on two consecutive training sessions". 2026: progression "not necessary to achieve beneficial outcomes"; overload "likely a requirement only for those seeking continued longer term progress". | **Corrected.** Old: "increasing the load by about 2–10% once you can do one or two reps more than your target in two sessions in a row" (number right; conditions missing). New: adds "when training at a set rep target", small vs large muscle, and the 2026 note. |
| **3 × 8–12** (sets & reps) | 2009: novices 8–12 RM, 1–3 sets per exercise. 2026: "healthy adults are advised to complete at least two sets per exercise". | **Corrected** (was a definition citing ACSM without saying what ACSM recommends; now states both, with "beginners" condition). |
| **Rep range** | 2009: novice loading 8–12 RM. 2026: training to failure did not enhance strength, hypertrophy or power; "near-failure" or 2–3 reps in reserve can give sufficient effort. | **Verified**; failure note added. |
| **Split** | Ramos-Campo 2024 abstract: 14 studies, 392 healthy adults; no significant difference in strength or hypertrophy "when volume is equated"; choose by preference. | **Verified**; conditions (study size, healthy adults, equal volume) added; "neither is better in general" stated. |
| **Compound and accessory** | 2009: "multiple-joint exercises before single-joint exercises". 2026: strength enhanced when exercises are done at the beginning of the session; hypertrophy not affected by order. | **Verified**; goal condition added (order matters for strength, not muscle size). |
| **Weekly volume** | 2026: hypertrophy enhanced by "≥10 sets/muscle group/wk", diminishing returns. Schoenfeld 2019: frequency no significant effect on hypertrophy when volume equated. Ramos-Campo 2024 as above. | **Corrected** (was only "Comparisons between routines are fairest when weekly volume is the same."; now states the findings with their conditions). |
| **3 × 40 s**, **Rotating sequence**, **Fixed weekdays** | App behaviour / notation, no source needed. | Verified against app behaviour; no source cited. |

## Splits

| Claim | Source | Status |
|---|---|---|
| No split is best; benefits/limitations are structural (sessions, days, how often an area comes round) | Ramos-Campo 2024; Schoenfeld 2019; 2009 notes total-body, upper/lower and muscle-group splits are all used, with similar strength gains between upper/lower and total-body | **Verified.** No split claims superior results. |
| Organisation and days of each split | `plan-templates.json` | **Verified**, except Push / Pull: **Corrected** "Squats, leg press and split squats sit on push days" → "…split squats and leg extensions…" (Push A has leg extension). |
| Custom: "Balancing the muscle groups across the week is up to you." | 2026 primary recommendation: RT "at least twice weekly, with all major muscle groups being engaged" | **Corrected**: adds that recommendation; source `acsm-2009` → `acsm-2026`. |
| "Once a week" for body-part split and three-day Push / Pull / Legs | Stated as fact of the schedule only. Schoenfeld 2016 (twice > once) vs 2019 (no difference volume-equated) conflict; the guide claims neither. | **Verified** (no evidence claim made). |

## Exercises (50)

Cues, muscle lists, equipment and roles are **general, widely taught descriptions**. They were **not** checked against a
technique source (NSCA material could not be opened) and cite no source (`sources: []`); `reviewNote` says so. They
were read for anything specific, unsafe or overstated:

| Exercise | Old | New | Status |
|---|---|---|---|
| dumbbell-bench-press | "No rack or spotter needed to fail safely: the dumbbells can be lowered to the sides." | "Needs no rack." | **Corrected** (safety claim removed) |
| incline-dumbbell-press | "Each arm works on its own, so both sides do equal work." | "Each arm moves its own dumbbell." | **Corrected** (unsupported "equal work") |
| dumbbell-bench-press, dumbbell-shoulder-press | "Each arm works on its own." | "Each arm moves its own dumbbell." | **Corrected** (wording) |
| overhead-press | "Heavy loads are harder to manage than in the bench press." | "Usually done with less weight than the bench press." | **Corrected** |
| deadlift | "Demanding, so it usually gets the longest rest." | "Demanding; many people rest longer between sets of it." | **Corrected** (no prescription implied) |
| romanian-deadlift | "…going lower by rounding the back defeats the purpose." | "…the cue is to stop before your back rounds." | **Corrected** |
| leg-press | "…with little balance or back demand." | "…little balance demand and your back supported." | **Corrected** |
| goblet-squat | "A simple way to learn the squat…" | "A common way to practise the squat…" | **Corrected** |
| bulgarian-split-squat | "Trains one leg at a time with light weights." | "…so it is demanding even with light weights." | **Corrected** (unclear) |
| hammer-curl | "Works the forearms more than a regular curl." | "The palms-facing grip also works the forearm muscles." | **Corrected** (comparative claim removed) |
| dead-bug | "…it works only when done slowly." | "…it is meant to be done slowly and with control." | **Corrected** |
| Alternatives / substitutions | Every key exists in `exercise-catalog.json` (test). 2026: equipment type (free weights vs machines) did not consistently affect outcomes, which is consistent with machine/free-weight swaps. | **Verified** keys; suitability for a person is not claimed. |
| All other exercise text | General descriptions | **Uncertain** (not source-checked; awaiting professional review). |

Custom exercises (`custom:<id>`) are unchanged: no entry, "Added by you", no claims.

## Exercise-specific technique text (18 Oct 2026, docs/EXERCISE_DEMOS.md)

The demonstration sheet's **How to do it** for four exercises (Setup, Movement, Common mistakes) is written by the
developer from one exercise-specific page each, read on 18 Oct 2026, paraphrased (not copied). It is stored in
`app/assets/data/exercise-media.json` (`technique`, `techniqueSources`), not in `coach-guide.json`, and the sheet names
the source beside it. **Source-checked, not reviewed by a qualified coach.**

| Key | Source | What it supports | Note |
|---|---|---|---|
| bench-press | ACE Exercise Library, Chest Press (barbell), https://www.acefitness.org/resources/everyone/exercise-library/5/chest-press/ | Grip slightly wider than shoulders; feet and hips pressed down; lower to the chest with elbows out; stop with elbows just below the bench; press straight up | The page lists no common mistakes, so none are shown |
| incline-dumbbell-press | ACE, Incline Chest Press, …/exercise-library/25/incline-chest-press/ | Bench 45–60°; shoulders down and back; contact points; press over the eyes; lower to the upper chest, slightly wide, elbows under wrists; no bouncing, no low-back arch, neutral wrists | The existing general cue says "a low incline"; the sourced Setup states the source's 45–60° instead of silently changing the cue |
| dumbbell-bench-press | ACE, Chest Press (dumbbells), …/exercise-library/19/chest-press/ | Flat bench, feet on the floor; shoulders down and back; press to eye level; lower to mid-chest; no bouncing, arching or bent wrists | |
| overhead-triceps-extension | ACE, Triceps Extension, …/exercise-library/74/triceps-extension/ | Both hands on one dumbbell; brace; upper arms still; lower behind the head to about 90° or until the upper arms move; avoid the head | ACE stands in a split stance; the clip is seated, which the text says |

The other 46 exercises' cues are shown under "How to do it" as "General cues, not yet checked against a technique
source". wger's community exercise descriptions were read but not used as technique sources (uneven, one machine
translated).

## Still uncertain

- 46 of the 50 exercises' cues, and all muscle lists: general descriptions only; need a qualified coach's review or an authoritative technique source (e.g. NSCA, when accessible). The four above are source-checked but not professionally reviewed.
- Ramos-Campo 2024 and both Schoenfeld papers: checked from abstracts only (full text paywalled).
- 2009 rest/2–10% figures are older guidance; the 2026 stand does not restate them, so the guide presents them as "2009 suggested", next to the 2026 findings.
- `docs/TRAINING_PLANS.md` (not owned by this audit) still describes rest times from memory; worth aligning.
