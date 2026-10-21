# French and Arabic: surface inventory

The per-area inventory behind docs/LOCALIZATION.md › Coverage (21 Oct 2026). Status: Translated / User content /
Provider content / Not reachable.

## Shell / Today / auth / setup / weather — localization inventory

| Surface | Files | Status | Notes |
|---|---|---|---|
| Shared components (buttons busy label, progress rail/ring values, TabHeader, ChoiceCard, ListRow, GroupRow, PanelSurface/PhotoPanel, QuietLink, PassCard, confirm(), GhMark) | lib/core/widgets.dart | Translated | `busyWorking`, `percentValue`, `actionCancel` default for confirm(), PassCard overline + ICU select sentence. RTL audited (see below). |
| Appearance / compatibility / glyph stores | lib/core/appearance.dart, compatibility.dart, go_icon.dart | Not reachable | No user-facing text. |
| Configuration error detail | lib/core/config.dart → app.dart `_ConfigProblem` | Translated (heading/body); detail left English | `AppConfig.problem` is a developer message naming the dart-define; only shown in a misconfigured dev build. |
| Update required notice | lib/app/app.dart `UpdateRequiredScreen` | Translated | Pending changes via ICU plural. |
| Can't sync label, detail, waiting count | lib/app/providers.dart | Translated | `cantSyncLabel`, `cantSyncDetail` are getters on `currentL10n`, `waitingToSync` an ICU plural; Today uses whole messages. |
| Sign-out notice | lib/data/session.dart, auth_screen.dart | Translated | Typed `SignOutReason { expired, accountDeleted }`. |
| Sign in / create account | lib/features/auth/auth_screen.dart | Translated | Errors shown via `AuthFailure.text(l)`, so they follow a language change. Email/password/name are user content. LanguageButton added at the bottom. |
| Setup: choose coach, optional features | lib/features/setup/setup_screen.dart | Translated | Coach name via `guide.displayName(l)`. First name is user content. LanguageButton on both steps. |
| Navigation bar + review banner | lib/features/shell/home_shell.dart | Translated | Keys from fixed ids; banner ICU plural. |
| Today header, greeting, coach bubble lines | today_screen.dart, today_greeting.dart | Translated | Greeting = whole message per time of day with name placeholder. `CoachContext(label: 'Your training')` stays English: it is sent as `contextLabel` in the Ask payload. |
| Today sky line | today_screen.dart, weather_model.dart | Translated | Condition from cached WMO code (English keeps provider description); temperature `weatherTemperatureC/F`. |
| Today connection status | today_screen.dart | Translated | Whole messages with ICU plural for waiting changes. |
| Today workout panel (all plan states, open/parked workouts, missed) | today_screen.dart | Translated | Plan/workout titles are user/plan content. Outcome via `outcomeLabel(l, …)`; plan state badge also via `OccasionStatus.label` (now `currentL10n`). |
| Today Run / Walk tile | today_screen.dart | Translated | ICU select on walk/run; distances via units. |
| Today Steps tile | today_screen.dart | Translated | `DailyValue.source` / `DailyUnavailable.why` come from activity/steps (activity area). |
| Today nutrition panel | today_screen.dart | Translated | `NutritionSummary`, `NutritionMissingNote`, `WaterRow`, goals text from nutrition area. |
| Recorded today | today_screen.dart | Translated | Run titles are user content; `activityTitle` fallback from activity area. |
| Today background setting, city search, consent dialog, basis rows | lib/features/weather/today_background_screen.dart | Translated | Scene ids, issue ids, provider description, WMO code, time zone, MET Norway/Open-Meteo names: technical/provider content, unchanged. City names: provider content. |
| Appearance row summary | weather_service.dart `todayBackgroundSummaryProvider` | Translated | Watches `appL10nProvider`; no fetch on language change. |
| Weather scenes / painters | backdrop.dart, scene_art.dart, sky_painter.dart | Not reachable | No text; artwork not mirrored. |

## Plan area: localization inventory

Keys: `l10n_parts/plan.json` (prefixes `train…`, `plan…`, `builder…`). Templates: `assets/data/plan-templates.{fr,ar}.json`.

| Surface | Files | Status | Notes |
|---|---|---|---|
| Train header, Workouts / Plan / Progress sections, Ask GoHard context labels | features/plans/train_screen.dart | Translated | Progress section content is features/progress (other area). |
| Train coach lines (plan, workouts) and plan-start empty states | train_screen.dart | Translated | |
| Workouts: scheduled today, open workout panels, manual / Run-Walk rows, recent, history | train_screen.dart | Translated | Workout titles are user content. |
| Plan: primary plan pass, notes, paused line, proposals row, manage card, saved/past plans, archived count | train_screen.dart | Translated | Plan titles, proposal explanations (account text) left as written. |
| Fixed plan weeks: week grid, week header, rail, day strip, occasion rows | train_screen.dart, week_widgets.dart | Translated | Occasion state words come from `OccasionStatus.label` (features/today/daily.dart, today area). |
| Rotation: cycle strip, coming up, recent sessions, rotation notes | train_screen.dart | Translated | |
| Occurrence sheet: where/when, prescription lines, target load, all actions, move/skip dialogs, rest-day toast | plan_actions.dart | Translated | Exercise names via exerciseNamesProvider. Native date picker is Material-localized. |
| Pause dialog, decision toasts and refusals | plan_actions.dart | Translated | Refusal codes → `planErrorText`. |
| Plan review (draft), change-schedule sheet, start/replace dialogs | plan_screens.dart | Translated | |
| Resume review, block review, close/stop dialogs, continue goal | plan_screens.dart | Translated | |
| Plan detail, archived plans | plan_screens.dart | Translated | Lifecycle word via `planLifecycle` select. |
| Replace a movement (substitution) | plan_screens.dart | Translated | Exercise names via exerciseNamesProvider. |
| Proposal review | plan_screens.dart | Translated | `p.explanation` and the raw `fromCatalogKey` are account content. |
| Rule / schedule error codes | plan_l10n.dart (from plan_rules.dart, schedule_rules.dart) | Translated | `ScheduleRefused.message` uses the resolved language for callers outside this area. |
| Split / schedule / setup / prescription / provenance / date-range helpers | plan_progress.dart | Translated | Shared helpers keep their signatures and use `currentL10n`. |
| Template suggestion reason, split evidence note, default names ("My plan", "Workout A", "(copy)") | plan_draft.dart, plan_l10n.dart, builder_steps.dart | Translated | Default names become user content once created. |
| Create plan (Guide me / I know what I want, plan in progress) | builder/plan_builder_screen.dart | Translated | |
| Builder steps indicator, progress, bottom bar, coach help, activate / save / discard dialogs and snackbars | builder/plan_builder_screen.dart | Translated | |
| Step 1 Availability | builder/builder_steps.dart | Translated | |
| Step 2 Structure: Guide me suggestion, templates, workout names, fixed days, cycle, schedule, start and length, custom length sheet | builder/builder_steps.dart | Translated | Guide reasons/fit lines from features/coach/guide.dart (coach area). |
| Step 3 Workouts: exercise list editor, prescription sheet, name sheet, copy-from sheet, menus, tooltips | builder/workout_editor.dart | Translated | Numeric fields accept Arabic-Indic digits. |
| Step 4 Review | builder/review_step.dart | Translated | |
| This workout only (occurrence editor) | builder/workout_editor.dart | Translated | |
| Starter templates (names, summaries, details, workout names) | assets/data/plan-templates.{fr,ar}.json | Translated | Names match coach-guide.{fr,ar}.json. Exercise names stay the catalog English (shown via exercise-names catalog). |
| Plan titles, workout names, notes, custom exercise names, recorded workout titles | — | User content | Never translated. |
| Proposal explanations, account error codes shown in fallback | — | Provider content | Fallback shows the code in `planErrUnknown`. |

## Workout / progress / exercise names — localization inventory

Keys: `app/l10n_parts/workout.json` (prefixes `workout…`, `progress…`). Exercise names, categories and equipment:
`app/assets/data/exercise-names.l10n.json` (50 catalog keys, display and search only).

| Surface | Files | Status | Notes |
|---|---|---|---|
| Workout panel: header, clock, pause/resume, parked/paused/review status, planned-sets rail | features/workout/workout_screen.dart | Translated | Clock digits unchanged (`clockText`); semantics translated. |
| Current exercise panel: position, name, prescription, swap note, About, target tile | workout_screen.dart, data/models.dart (`targetText`) | Translated | Built-in names via `exerciseNamesProvider`; custom/renamed names stored wording. Rep range wrapped in `ltr()`. |
| Entry fields (load / reps / time), Use last values, Record set, targets reached | workout_screen.dart | Translated | Loads parsed with `typedLoad` → `parseNonNegative`; a trailing "," "." "٫" is refused; drafts keep raw text. Unit suffix `LoadUnit.label`. |
| Rest timer (+30 s, Skip, Dismiss, from previous movement) | workout_screen.dart | Translated | Rest deadline untouched by language. |
| Recorded sets list, edit set dialog, snackbars (saved, removed, undo, failures) | workout_screen.dart | Translated | Edit dialog now refuses a malformed load instead of saving bodyweight. |
| All movements list, menu (add/replace/remove/park/remove workout), finish dialog | workout_screen.dart | Translated | ICU plurals for sets/movements. |
| Last time / comparison table (normal and large text), history sheet | workout_screen.dart | Translated | `Table` and directional padding follow RTL. |
| Validation messages from the repository | workout_repository.dart → `InvalidSetReason` | Translated | Typed code, words in `invalidSetText`. |
| Outcome labels (Finished, partial, no data, manual, in progress) | result_rules.dart (`outcomeLabel`) | Translated | Stored outcome codes unchanged; `WorkoutResultRules.label` kept as a resolved-locale shim for other areas. |
| Planned workout preview (state, counts, Start, options, rows, status lines) | workout_panel.dart | Translated | `rxSentence` belongs to the coach area. |
| Workout result / detail / history list / rows | workout_detail_screen.dart | Translated | `provenanceOf` (plans area) not mine. |
| Start/resume conflict dialog, start failure | workout_flow.dart | Translated | |
| Exercise picker: search, filters, rows, create custom; custom exercise form | workout_flow.dart | Translated | Search matches fr/ar/en names, aliases, translated categories/equipment (folded). Filter keys stay English ids. |
| Manual workout setup | workout_flow.dart | Translated | Blank name stores the localized default ("Workout" in English as before). |
| Next time section, suggestion card, next target line, keep/kept toasts | next_target.dart | Translated | "current → proposed" wrapped in `ltr()`. |
| Progression explanations (all decisions/reasons) | next_target.dart (`explainProgression`) | Translated | Domain already returns `ProgressionDecision`/`ProgressionReason` codes. |
| Next target review sheet, restore, errors | next_target.dart | Translated | Load parsed with `typedLoad`; `ScheduleRefused.message` comes from plans area. |
| Weight increment sheet | next_target.dart | Translated | Chip keys are ASCII numbers, not displayed text. |
| How progression works help | next_target.dart | Translated | Sources, years and percentages unchanged. |
| Train › Progress overview (week panel, goals rows, trends previews, adherence, consistency bars, recap link, history row) | features/progress/progress_view.dart | Translated | Consistency bars forced LTR (oldest left); numeric day/month order per locale. |
| Coach line on Train › Progress | progress_view.dart (`progressCoachLine`) | Translated | Signature compatible; optional `l`. |
| Weekly goals sheet | progress_view.dart, goal_repository.dart (`GoalInputError`) | Translated | Arabic digits allowed in the formatter, parsed with `parsePositiveInt`. |
| Exercise trends list, trend screen, all sessions, chart | trend_screens.dart, trends.dart (`TrendRange.label`) | Translated | Chart keeps time left→right; label text painters use ambient direction; hit targets unchanged. |
| Trend values, metric labels, signed changes | progress_view.dart | Translated | Signed values in `ltr()`. |
| Weekly recap (panel, semantics, goals, highlight, coach line, sessions) | recap_screen.dart, weekly.dart (`ActivityMix`) | Translated | `activityWord` replaced by typed `ActivityMix`. |
| Workout titles, plan titles, plan workout names, notes, custom/renamed exercise names, typed search text | — | User content | Shown as stored. |
| Run / Walk titles in recap rows (`activityTitle`) | features/activity | Not mine | Run area. |
| Category/equipment values stored on custom exercises | workout_flow.dart | Translated (display) | Stored English ids unchanged. |

## Run / Walk localization inventory (area `run`; keys `run…`, `steps…`)

| Surface | Files | Status | Notes |
|---|---|---|---|
| Ready: title, coach bubble, help sheet, History button, back tooltip | run_walk_screens.dart | Translated | Back uses MaterialLocalizations; back/chevron GoGlyphs mirrored in RTL (`directionalGlyph`). |
| Ready: GPS card (all access states, signal quality, accuracy), simulated-GPS line | run_walk_screens.dart | Translated | Accuracy "±5 m" via `ltr` + `withUnit`. |
| Ready: setup group (Intervals, Voice and alerts, Auto-pause values), Start button, start errors, "Start without GPS?" dialog | run_walk_screens.dart | Translated | |
| Auto-pause sheet | run_walk_screens.dart | Translated | |
| Ready map / expanded map labels | run_walk_screens.dart, route_map.dart | Translated | Map, route and its overlay controls are not mirrored. |
| Map controls (recenter/following, fit, zoom, expand, no-tiles caption, default semantics) | route_map.dart | Translated | |
| Recording: status pills, dial, figures, compact stats, GPS chip, notes, controls, voice toggle, help label | run_walk_screens.dart | Translated | Play/pause/stop glyphs not mirrored; GPS chip stays top-left over the map (zoom buttons are top-right). |
| Recording problems (not saving, GPS stopped) | recorder.dart → run_walk_screens.dart | Translated | Typed `RecIssue`, worded at the screen. |
| Interval setup sheet, plan summary, phase strip, interval bar, intervals-done panel | move_widgets.dart, intervals.dart | Translated | Phase names via `phaseName(l, kind)`; `IntervalPhase.label` kept (current language). |
| Voice and alerts sheet (updates, voice choice, no-offline-voice explanation, preview, vibration, countdown) | move_widgets.dart | Translated | Only voices of the app language are listed (`voicesFor`). Voice names/locales are device content. |
| Spoken / shown cues (phases, countdown end, distance and time updates, records) | announcer.dart, intervals.dart, records.dart, recorder.dart | Translated | Built at speaking time with `ref.read(appL10nProvider)`; keys language-independent. |
| Voice preview line | announcer.dart | Translated | Coach name via `guide.displayName(l)`. |
| Speech voice/engine language | announcer.dart | Translated | Only an installed offline voice of en / fr / ar; none → silent, words on screen, vibration kept. |
| Android recording notification (title, text, channel) | location_source.dart | Translated | Resolved language when the recording starts (`currentL10n`). |
| Save review (title, figures, fields, helpers, errors, discard dialog) | run_walk_screens.dart | Translated | Distance parsed with `parseNonNegative`. |
| Default activity title ("Morning run") | run_walk_screens.dart | Translated | Becomes the stored title (user content) once saved. |
| Activity detail (header, menu, figures, overview rows, sync states, intervals timeline, splits, charts, edit sheet, delete dialog, toasts, no-route panel, full map) | activity_detail.dart | Translated | Charts in scoped LTR Directionality; labels stay at their data. |
| GPX export | gpx.dart, activity_detail.dart | Translated | Track `<name>` is the displayed activity name; elements/values per GPX 1.1. File name keeps ASCII-only filter. |
| History (title, filters, open activity row, totals, empty state, rows) | activity_history.dart | Translated | |
| Personal bests (card, link row, page, pills, footnote) | move_widgets.dart, records.dart, activity_detail.dart | Translated | Categories via `benchmarkLabel(l, b)` from ids. |
| Steps sheet, Ready steps row, fixes | steps_ui.dart | Translated | Goal parsed with `parsePositiveInt(grouping: true)`. |
| Activity steps values, daily unavailable reasons, daily source names | steps.dart | Translated | "Health Connect" is a product name. |
| Activity titles, notes typed by the person | — | User content | Never translated. |
| Installed TTS voice names | move_widgets.dart | Provider content | Shown as the phone reports them, in an LTR isolate. |
| `activityNoun` (English noun) | run_walk_screens.dart | Not reachable | Kept for test fixtures only. |

## Eat area: localization inventory

Keys: `l10n_parts/eat.json` (350 keys, prefixes `eat`, `food`, `meal`, `water`, `trends`, `barcode`). Catalog words:
`assets/data/common-foods.l10n.json` (French and Arabic for all 74 foods).

| Surface | Files | Status | Notes |
|---|---|---|---|
| Eat tab: header, day arrows, History & trends / Back to today, coach lines and hints, help sheet | nutrition/eat_screen.dart | Translated | Coach name (`guide.label`) is passed through as is |
| Eat: meal groups, entry rows, Add food footer, journal loading/error, footnote | eat_screen.dart | Translated | Meal ids stay `Breakfast/Lunch/Dinner/Snack`, shown via `mealLabel` (fr-CA Déjeuner/Dîner/Souper/Collations) |
| Logged entry name, amount description, values | eat_screen.dart, food_form.dart | User content | Shown as stored; a language change never rewrites them |
| Day nutrition panel: Totals / Known totals / No food logged / no nutrition, goals progress, carbs/fat, partial note, sync pending | nutrition_surface.dart | Translated | Unknown stays "—"; partial sums say "known"; no entries is not zero |
| Today's NutritionSummary and missing-values note | nutrition_surface.dart | Translated | Used by Today |
| Goals editor and sheet, water goal suggestion and its About dialog | nutrition_tools.dart | Translated | Range errors from `setGoals` come from me/account_repository (me area) |
| Water line, quick add, Undo, Other amount sheet, Water sheet, correct dialog, announcements, errors | nutrition_tools.dart, water.dart | Translated | `WaterProblem` code replaces English exception text |
| Customize tracking sheet, NutritionTools links, goalsSummary | nutrition_tools.dart | Translated | goalsSummary is used by Me |
| Add food: title, search, scan, tabs, categories, groups, empty states, wider-search states, non-English guidance, manual entry, credits | log_food_screen.dart | Translated | Provider/licence names (USDA FoodData Central, Open Food Facts, Open Database License) kept |
| Food rows (title, tag, qualifier, basis, kcal/protein) | food_search.dart (`rowFacts`), log_food_screen.dart | Translated | Catalog foods shown by localized name/qualifier/start portion |
| Provider food names, brands, descriptions, serving labels ("1 cup, cooked") | food_item.dart, food_form.dart | Provider content | Not translated; English plural rules for provider serving nouns kept |
| Common-food names, qualifiers, start portions, aliases | assets/data/common-foods.l10n.json, food_search.dart | Translated | Values, weights, sourceId, provenance untouched |
| Common-food categories | food_search.dart (`foodCategoryLabel`) | Translated | Mapped from stored category id |
| Food form: header, credit line, amount/portion, Add your own portion dialog, nutrient fields, missing-values line, buttons, remove confirm, Food details sheet | food_form.dart | Translated | `FoodProblem` code replaces English `InvalidFood` text |
| User-defined portion names | food_form.dart | User content | Dialog now accepts letters of any language |
| Barcode scanner: title, instructions, camera states, torch, typed entry and error | barcode_scan_screen.dart | Translated | Typed field accepts ٠-٩ ۰-۹, normalised with `asciiDigits`, shown LTR |
| Barcode lookup messages | log_food_screen.dart | Translated | Code wrapped in `ltr()` |
| History & trends: period bar, metric chips, totals panel, chart legend, chart labels, day panel, day list, help | nutrition_history.dart, intake_history.dart | Translated | Arabic plurals for foods/days |
| Calendar and days-with-entries list | nutrition_history.dart | Translated | Material CalendarDatePicker (localized by MaterialLocalizations) |
| Domain exceptions (`InvalidFood`, `InvalidWater`, `LookupFailure`) | food_repository.dart, water.dart, food_discovery.dart | Translated | Typed codes; screens translate |
| FoodDiscovery / FoodRepository network and storage | food_discovery.dart, food_repository.dart | Not reachable | No user-facing text |

## Me area: localization inventory

| Surface | Files | Status | Notes |
|---|---|---|---|
| Me tab (identity, groups, rows, sync status, build line) | lib/features/me/me_screen.dart | Translated | The display name and email are user content (email wrapped in `ltr`). The build line has the commit, contract and server isolated LTR. The reminder time shows the stored HH:mm digits, as it did before. |
| Me › Language row | me_screen.dart (+ core/language_picker.dart) | Translated | Key `me-language`, in Preferences after Motion & haptics. Uses `languageValue` and `showLanguagePicker`. |
| Units sheet (load, body, temperature, water, Run / Walk) | me_screen.dart | Translated | `°F`/`°C` symbols are kept as they are. |
| Appearance (preview, accent, mode, coach cards, coach switches, hints reset) | me_screen.dart | Translated | Accent names come from `accentLabel(l, a)` and modes from `modeLabel(l, m)`. Guide names come from `CoachGuide.displayName/animalName` (coach area). The Today background value comes from the weather area's provider. |
| Motion & haptics page | me_screen.dart | Translated | Uses core `motionDevice/motionReduced/hapticsDevice/hapticsOff`. |
| Edit profile, Nutrition goals page, Delete account | me_screen.dart, account_repository.dart | Translated | The goals form itself (`GoalsEditor`) and `goalsSummary` belong to the eat area. |
| Account/auth errors (`AuthFailure`) | account_repository.dart | Translated | Server codes map to an `AuthError`. Unknown codes use `errorGeneric`, so no raw status is shown. `AuthFailure(String)` still exists for callers in other areas. |
| Account-deleted sign-out notice | account_repository.dart | Translated | Now `SignOutReason.accountDeleted`. The sign-in screen words it (auth area). |
| Phone permissions page | permissions_screen.dart | Translated | |
| Workout reminder notification + Android channel | reminders.dart | Translated | The body is the planned workout title (plan/user content, unchanged). Changing language reschedules with the same IDs. |
| Sync review (titles, reasons, version descriptions, buttons, dialogs, snackbars) | sync_review_screen.dart | Translated | Food names, amounts, workout and plan titles and display names are user/provider content. The stored meal, outcome, lifecycle and appearance ids are translated with ICU select (raw id as fallback). Unknown error codes are shown as the stable code. `setText` and `VolumeUnit.format` come from other areas. |
| Sync engine retry/conflict messages | lib/data/sync.dart | Not reachable | `lastError` already stores only codes (`HTTP_xxx`, server codes, transport type names). Nothing in it is English shown to users, so it is unchanged. |
| Body progress overview, weight panel, chart section, latest list | lib/features/body/body_screens.dart | Translated | The chart is wrapped in LTR Directionality so time runs left to right. |
| Metric page, history, day list | body_screens.dart | Translated | Notes are user content (quoted per language). |
| Log / edit check-in form, choose-fields sheet, discard and delete dialogs | body_screens.dart, body_metrics.dart, body_repository.dart | Translated | Typed codes: `BodyFieldError`, `BodyInputProblem`. Input goes through `parseNonNegative`, and the formatter allows Arabic digits and `٫`. |
| Compare dates | body_screens.dart | Translated | Side labels are anatomical (the person's own left and right). |
| How to measure | body_screens.dart | Translated | The NHANES citation titles stay in English as published. |
| Body field names, units, change values | body_metrics.dart | Translated | `bodyFieldLabel(l, f)`, `LengthUnit.label` (localized; `.name` is stored), `BodyUnits.value/change` (localized decimal, `withUnit`, signed values in `ltr`). |

## Coach area — localization inventory

| Surface | Files | Status | Notes |
|---|---|---|---|
| Ask GoHard screen: header, "About", intro, suggested questions, composer, Send/Close/Clear, clear confirmation | features/coach/ask_screen.dart | Translated | Suggested questions are sent as the question in the chosen language |
| Ask GoHard waiting / problem states (limit, busy, unreached, invalid, interrupted, unavailable), Retry, Edit question | ask_screen.dart | Translated | Never says "offline" |
| Ask GoHard questions the person typed | ask_screen.dart, coach_client.dart | User content | Sent and kept as typed, never translated |
| Ask GoHard answers and proposal summaries | ask_screen.dart | Provider content (AI) | New answers come in the requested language; stored messages keep their original words |
| AI-generated label, stale-draft line, More/Less, sources heading | ask_screen.dart | Translated | Source title · publisher come from the (translated) guide |
| Suggested change card + preview sheet (Draft only, apply/keep, recheck, changed rows, weight notes) | ask_screen.dart | Translated | Exercise names via exerciseNamesProvider (unchanged catalog names only); workout names are draft content |
| Left-out operations (not applicable) | coach_proposal.dart → ask_screen.dart | Translated | Typed `ProposalSkip` / `SkipReason`, worded in the screen |
| Undo refused | coach_proposal.dart → ask_screen.dart | Translated | `undoProposal` returns the exercise; sentence stored as shown (older stored English sentences stay as they were) |
| Quick guide button / sheet (built-in reviewed content) | ask_screen.dart | Translated | Content from coach-guide.<fr|ar>.json, English fallback |
| Why this suggestion / Compare splits / About exercise sheets | features/coach/guide_sheets.dart | Translated | Category/equipment/alternatives via catalog names; source URLs unchanged |
| Guide me reason, fit line, week line, prescription sentence | features/coach/guide.dart, guide_sheets.dart (`rxSentence`) | Translated | Through `currentL10n`; `suggestTemplate().reason` (plan_draft.dart) is the plan agent's and is embedded as given |
| Reviewed guide text (splits, exercises, terms, review note) | assets/data/coach-guide*.json (loaded in guide.dart, ask_screen.dart) | Translated | Files by the guide translator; API grounds answers in the English original |
| Coach bubble: Ask me ›, Ask me, Close, avatar/launcher labels | features/coach/coach_bubble.dart | Translated | Close defaults to actionClose |
| What the coach says (CoachSay text) | callers (today, train, eat, builder, setup, run…) | Not in this area | Passed in by other screens |
| Coach names Leon / Leona, lion / lioness | features/coach/coach_avatar.dart (`displayName`, `animalName`) | Translated | ليون / ليونا in Arabic; stored IDs `leon`/`leona`; `label`/`animal` stay English for callers not yet migrated |
| Companion rig, eyes, motion | coach_rig.dart, coach_companion.dart | Not text | RTL: guide on the left, art as painted, tail/mouth/gaze from real layout |
| Coach prefs (seen/greeted keys) | coach_prefs.dart | Not text | Language-independent; a language change replays nothing |
