# French and Arabic

GoHard runs in English, Canadian French (fr-CA) and Modern Standard Arabic (ar, right to left), across every
reachable screen. Branch `feature/localization-fr-ar` (from `feature/workout-progression`, 20–21 Oct 2026).

## Locale selection, fallback and device scope

- Choices: **System**, English, Français, العربية, each named in its own language (no flags). System is the default.
- Where: an unobtrusive language button on the signed-out screen and on both setup steps (`core/language_picker.dart`,
  `LanguageButton`), and Me › Preferences › **Language** (`me-language`).
- System resolves the phone's ordered list: any English → en, any French → fr-CA, any Arabic → ar; anything else →
  English (`resolveLocale`, `core/language.dart`). An explicit choice wins until System is chosen again. Under System a
  later phone-language change applies when the app resumes (`didChangeLocales`), including Android 13+ per-app
  language (`res/xml/locales_config.xml`) and iOS per-app language (Settings › GoHard › Language).
- Kept on this phone only, in the device-preferences store beside Motion, Haptics and Run / Walk choices
  (`DevicePrefsStore`, a sixth field; older values restore as System). Available before sign-in and after restart.
  Independent of the account, accent, mode, units and voice. No account field, migration or sync command.
- Switching is immediate: `appLocaleProvider` changes `MaterialApp.locale`, and every element is rebuilt in place once
  (`rebuildAllText`). The navigator, routes, tab, selected exercise, workout and run, clocks, rest deadline, journal
  day, plan-builder draft, search query and typed fields are the same objects before and after. No widget key is
  derived from displayed text. A change requests no permission, sends no command, contacts no food or weather
  provider and needs no connection.

## Architecture

- Flutter's SDK localization: `flutter_localizations` + `intl` 0.20.2 (the version flutter_localizations pins),
  `generate: true`, `l10n.yaml`. Generated, typed `AppLocalizations` live in `app/lib/l10n/` (committed) and are
  imported from the source tree — no synthetic `flutter_gen` package.
- ARB catalogs: `app_en.arb` is the complete source with a description and typed placeholders for every message;
  `app_fr.arb` (served as fr-CA; `app_fr_CA.arb` only declares the locale) and `app_ar.arb`. **2,424 messages.**
- Whole messages only; ICU plural/select. Arabic plurals give `=0`, `=1`, `=2`, `few`, `many`, `other` (checked at
  0, 1, 2, 3, 11, 100).
- Where to translate: widgets use `context.l10n`; services with a `ref` (spoken cues, notifications, reminders) read
  `ref.read(appL10nProvider)` at the moment a message is made; pure formatting helpers use `currentL10n`. Domain code
  returns typed codes (`SignOutReason`, `AuthError`, `RecIssue`, `FoodProblem`, `WaterProblem`, `InvalidSetReason`,
  `BodyFieldError`, `GoalInputError`, `SkipReason`, `ActivityMix`, …) translated at the presentation boundary.
  Command kinds, API routes, catalog keys, capability names, outcome enums, stored fields and error codes are never
  translated. An unknown server error shows the localized general message, never raw diagnostics.

### Adding or changing a message, adding a language

1. Edit `app/lib/l10n/app_en.arb` (message + `@key` description + placeholders), then the same key in `app_fr.arb`
   and `app_ar.arb`.
2. `cd app; flutter gen-l10n` (also run by `flutter pub get`).
3. `node scripts/check-l10n.mjs` — fails on a missing key, an unused or dropped placeholder, unbalanced ICU, a
   plural/select without `other`, an Arabic plural without all six forms, or a translation identical to English
   unless its description says it may match (international abbreviations, French cognates such as "Distance").
   It runs in CI and in `scripts/test.ps1`.

A new language: add `app_<code>.arb`, a value to `AppLanguage` and `resolveLocale`, the iOS `<code>.lproj/InfoPlist.strings`
(+ `CFBundleLocalizations`, project variant group), the Android `locales_config.xml` entry, the bundled content files
below, and a font if its script needs one.

## Formats, numbers and calendar

- One place for display: `core/format.dart` (dates through intl, durations, `localDecimal`, `formatGrouped`,
  `formatPercent`, `withUnit`, `ltr`) and `core/units.dart` (loads, distances, pace, speed, elevation, unit labels).
- Digits are Western (0–9) in all three languages, including Arabic dates (`useNativeDigits = false`), so timers,
  pace and values read the same everywhere. French uses the decimal comma and no-break-space grouping; values keep
  their unit on the same line (no-break space in fr/ar; English unchanged). The 12/24-hour preference is unchanged.
- Presentation only: kilograms, centimetres, millilitres, metres, UTC instants, day keys, enum values, hashes and
  payloads are unchanged, and no stored number is parsed from display text.
- **Numeric input** (`parseLocalNumber`, `parseNonNegative`, `parsePositiveInt`, `asciiDigits`): French "82,5",
  Arabic-Indic "٨٢٫٥" and Eastern Arabic-Indic "۸۲٫۵" are all 82.5. Grouping (space, no-break spaces, "٬", and
  "1,480" for whole numbers) is accepted only where grouping makes sense (calories, water, steps), never in a load,
  rep count or distance. Ambiguous input ("1,2,3", "1.480,5", "8 2", "-3") is rejected, never trimmed into another
  number. A partly typed "82," or "٨٢٫" is never recorded; drafts keep the raw text, so a French decimal typed before
  a switch to Arabic is still "82,5" afterwards and records 82.5 kg. Barcodes typed in Arabic digits become ASCII
  with leading zeros kept. Input formatters accept Arabic digits.
- The calendar is Gregorian, weeks are Monday–Sunday, and plan dates, period boundaries and goal history do not
  depend on the language. Material's own date picker uses the locale's first weekday (Saturday in Arabic) for its grid.
- Known zero, unknown ("—"), partial totals, no entries, loading and error stay distinct in every language.

## Arabic typography

- Latin text stays in Inter and DM Serif Display. Arabic letters fall back, per glyph, to bundled fonts (offline, OFL,
  provenance in `app/assets/PROVENANCE.md`): **IBM Plex Sans Arabic** Regular/Medium/SemiBold/Bold for UI text,
  and **Noto Naskh Arabic** (SemiBold at the titles' weight 400, Bold at 700) for serif page titles — the calm Naskh
  counterpart of the serif, not an imitation of it. Never an OS fallback, stretched text, reversed strings or images.
- In Arabic, `context.sansStyle`/`titleStyle`/`pageTitleStyle` drop letter spacing (joined script) and use more line
  height (1.55 / 1.4 / 1.45); page titles are drawn at 0.86× size because Naskh is larger at the same size.
- French labels are longer: layouts wrap first; a one-word title or tab name that cannot fit shrinks
  (`FittedBox`) rather than breaking mid-word or being cut.

## RTL and its exceptions

- Direction comes from MaterialApp; components use directional padding, alignment and positioning
  (`core/widgets.dart` and every feature area). Today is the leading tab, so it is rightmost in Arabic. Material's
  directional icons mirror once by themselves; GoGlyphs that mean back/forward mirror through `directionalGlyph`.
- **Not mirrored:** photographs (they sit on the trailing side and fade toward the words), avatar artwork, the GH
  mark, maps, routes and map controls, play/pause/stop glyphs, recordings.
- **Charts keep time left → right** (workout trends, consistency bars, nutrition History & trends, body measurements,
  run splits and charts): the plotted area is scoped LTR; labels and hit targets stay with their data; no array is
  reversed.
- Leon and Leona sit on the trailing side (left) in Arabic, drawn as painted (no horizontal flip). The bubble tail,
  mouth anchor and gaze are recomputed from the actual layout. Eyes, blinks, motion preferences and introduction
  state are unchanged; a language change replays nothing. Exception: the 48 px guide in Ask GoHard's header has no
  bubble and follows plain row order.
- Mixed content: Latin-ordered values inside Arabic lines are isolated (`ltr()`: emails, barcodes, signed values,
  rep ranges "8–12", set × rep amounts, clocks "1:30", voice names, technical values). A value with an Arabic unit
  ("40 ث") keeps Arabic order. Isolation is presentation only and never stored.

## Built-in content, catalog and user content

- **Exercise names** (`assets/data/exercise-names.l10n.json`, `core/catalog_names.dart`): French and Arabic names and
  aliases (incl. common English gym names) for all 50 catalog exercises, categories and equipment, keyed by catalog key.
  A name is shown translated only when the exercise has a catalog key and its stored name is still the catalog's own
  English name (an unchanged built-in label); custom, renamed and historical names are shown as stored. Search
  (`foldForSearch`: case, French accents, Arabic diacritics/tatweel/letter variants, Arabic digits) matches every
  language's name and aliases to the same exercise identity. Matching, progression eligibility, order, recorded sets
  and prescriptions are unchanged.
- **Plan templates**: `plan-templates.fr.json` / `.ar.json` are the same templates with only wording translated (a
  test checks shape, IDs and numbers). Plans made from them keep the wording they were made with (user data). Default
  names ("My plan", "Workout A") are created in the current language and are user content afterwards.
- **Coach guide**: `coach-guide.fr.json` / `.ar.json` — 524 strings per language, same structure, IDs, URLs and
  numbers (tested). Source citations stay in their original language; the review note still says the content awaits
  coach or clinician review. No claims added, no prescription changed.
- **Common foods** (`common-foods.l10n.json`): French and Arabic name, qualifier, start portion and aliases for all 74
  bundled foods, keyed by food id. Nutrient values, portion weights, source IDs and provenance are untouched. A French
  or Arabic search finds the same food id as the English name ("poulet", "دجاج" → chicken breast).
- **Never translated (user or provider content):** names, emails, notes, plan/workout titles, custom exercise and
  food names, logged entries (stored names, amounts and nutrition snapshots stay as logged), provider product names,
  brands and descriptions, provider and licence names, city names, TTS voice names, the step source text, GPX element
  names.

## Food providers

USDA and Open Food Facts are not multilingual catalogs here, and nothing translates queries. The bundled foods answer
French and Arabic names locally. When a non-English search finds nothing from the provider, the app says so plainly
and suggests the English name, the barcode or entering the food by hand — it never says the food does not exist.
No new provider, credential or extra lookup; switching language or opening cached results makes no request.

## Coach, AI and speech

- Deterministic greetings, hints, summaries, explanations, suggested questions and unavailability states are
  translated and stay offline.
- **Ask GoHard**: when a question is sent, the request carries an optional `language` (`en` | `fr-CA` | `ar`,
  `askLanguage`). The API (`CoachAskRequest.Language`) adds one trusted instruction for French (Canadian, "tu") or
  Arabic (MSA) replies; a missing, English or unknown value leaves the request byte-identical to before. The question
  is never translated; earlier messages keep their text. Same provider, limits and safety. Old clients and old
  servers are unaffected (unknown JSON fields are ignored). **Hosted deploy needed only for French/Arabic AI replies.**
- **Spoken cues** (intervals, distance, pace, records): made in the app language at the moment they are spoken, with an
  installed **offline** voice of that language only (fr-CA preferred for French). With none installed nothing is
  spoken — the cue still shows and vibration still works — and the voice sheet says so in the selected language.
  A language change mid-run restarts nothing and replays no cue or milestone.
- Reminders: title and Android channel name/description in the resolved language; a language change re-schedules
  future reminders with the same IDs, triggers and dates (no duplicates, nothing past replayed). The Android
  recording notification is localized when the recording starts.

## Native and permission dialogs

- iOS: `CFBundleLocalizations` en, fr, ar; `en/fr/ar.lproj/InfoPlist.strings` translate the purposes actually used
  (camera, location when in use, temporary precise location `RouteRecording`, motion). Android: `supportsRtl`,
  `locales_config.xml`; permission rationales are in-app (translated).
- The system owns its permission buttons, pickers and dialogs: they follow the **phone's** (or iOS/Android per-app)
  language, not the in-app choice. A purpose string follows the bundle localization iOS selects, which is the per-app
  or device language — choosing Français only inside GoHard does not change an iOS prompt.

## Verification (21 Oct 2026)

- `node scripts/check-l10n.mjs`: 2,424 messages OK. `flutter analyze`: no issues. `flutter test`: 691 passed
  (focused: `localization_test` resolution/persistence/numeric/format/search; `l10n_{shell,plans,workout,run,eat,me,coach,coach_guide}_test`).
  API: 200 passed (incl. the Ask language test).
- Renders (widget fixtures, not device captures): `docs/evidence/localization/{fr,ar}/` — the four tabs in six
  themes, Today/plan/workout/food/builder at 390 × 844 with phone insets and at 320 px with 2× text, the
  comparison/progression panel, nutrition History & trends (chart and calendar), body progress, Run / Walk.
- Native (Pixel_7 emulator, branch API on free port 5136 with a disposable database, dropped afterwards):
  `journey_language_test` (two phases, not default). **Partly verified.** The first run passed every step through the
  language switch: Français chosen on the signed-out screen, account created and setup skipped in French, Bench press
  found as "développé couché", "82,5" and 8 typed and not recorded, العربية chosen from Me mid-workout, back in Train:
  RTL, the Arabic tab names, the same exercise and "82,5" / 8 still in the fields, nothing recorded. It then stopped on
  a typing bug in the test itself (fixed). Four reruns of the fixed test failed in the test driver before any step
  ("Service has disappeared" / attach hang, also after an emulator reboot and an adb restart), so recording the set
  natively, Arabic-digit entry, the Arabic food alias and the restart phase are **not verified natively**; widget
  tests cover them (`l10n_workout_test`, `l10n_eat_test`, `l10n_me_test`, `localization_test`). Real captures and the
  recording of the switch: `docs/evidence/localization/native/` (`lang-01…06`, `lang-switch.mp4`; the green boxes
  are the emulator's TalkBack focus).
- **Review status:** all French and Arabic wording was written and self-reviewed by the AI implementation and its
  automated checks only. **No fluent human or professional linguist has reviewed it.** Items flagged for a reviewer:
  Arabic gym terms (دمبل, بار حديدي, العقلة…), Quebec terms (charnière de hanche, pareur, gaine-toi), Arabic gender
  forms in coaching cues, the Arabic Saturday-first calendar picker.

## Coverage by area

Every screen, sheet, dialog and notification by area, with its status: `docs/LOCALIZATION_INVENTORY.md`.

| Area | Messages | Notes |
|---|---|---|
| Core (language, formats, units, actions) | 39 | |
| Shell, Today, sign-in, setup, weather | 268 | weather condition from the cached code |
| Train › Workouts/Plan, plan builder, templates | 541 | + translated template files |
| Workout, progression, Progress, trends, recap | 422 | + exercise names file |
| Run / Walk, steps, speech, recording notification | 314 | |
| Eat, food, water, History & trends | 350 | + common-foods file |
| Me, body progress, sync review, reminders | 362 | |
| Coach, Ask GoHard, guide sheets | 128 | + coach-guide files |

Deliberately left in English: developer-only configuration detail (`AppConfig.problem`), the coach context label
sent to the API, weather diagnostics' technical values, and the user/provider content listed above.

## Physical-phone checklist (not yet done)

Sign-in language picker; System and explicit choices; Arabic navigation and bubble geometry; French and Arabic
keyboard entry; switching mid-workout without losing data or the timer; food and exercise aliases; charts and dates;
VoiceOver/TalkBack in both languages; installed offline speech; the real native permission prompts.
