# Exercise demonstrations

First built 18 October 2026 on `feature/exercise-demonstrations` (never merged); brought into the current app on
19 November 2026 on `feature/wger-demonstrations` (from `main` 27877fe), re-audited against the live wger API the same
day. One shared exercise sheet shows a real person doing the movement where a reviewed clip exists, reviewed pictures
where only those exist, and says plainly when there is neither. Row-by-row coverage:
[EXERCISE_DEMOS_COVERAGE.md](EXERCISE_DEMOS_COVERAGE.md).

## What came from where

- **Brought forward** from `feature/exercise-demonstrations` (4bd3f6a): the manifest model and validator
  (`exercise_media.dart`), the player and download store (`exercise_demo.dart`), the shared sheet entry
  (`showExerciseDetails`), the reviewed spec, build script and posters, and the tests. Its ledger commit and its old
  evidence (renders, emulator captures, a 15 MB recording of the October UI) were not.
- **Not brought forward**: `feature/owner-exercise-videos` (owner uploads, server conversion, R2 hosting, remote
  catalogue). Nothing here uploads, converts or hosts media. `fix/workout-exercise-switch` is unrelated and untouched.
- **Rebuilt for today's app**: main had since localized every sheet (en, fr-CA, ar), added localized exercise names and
  redesigned the recorder into Train › Workouts' panel. The demonstration UI was merged into those, all its words moved
  to the ARB catalogs (58 `demo…` strings), and the manifest gained French and Arabic variant and technique text.

## Coverage (50 built-in catalogue keys, re-checked 19 Nov 2026)

| | Count | Keys |
|---|---|---|
| Video | **5** | bench-press, incline-dumbbell-press, dumbbell-bench-press, overhead-triceps-extension (seated), dip (parallel bars) |
| Pictures (start and end) | **7** | barbell-curl, biceps-curl, hammer-curl, lateral-raise, seated-cable-row, walking-lunge (start and bottom), dumbbell-shoulder-press (seated) |
| Written guide only | **38** | everything else; each has its reason in the coverage table |

The same as 18 October. The re-audit, method and findings:

- **Catalogue**: the 50 keys in `api/src/GoHard.Api/Data/exercise-catalog.json` are unchanged since the first audit.
- **wger today** (API v2, read 19 Nov): 78 videos (the only clip that matters for a gap, 79, is a 19.7 MiB 10-bit HEVC
  face pull), 395 images (12 new: TRX/rings dip, push-up, face pull, Y raise and chest fly; a backpack row; and six
  from `yuhonas/free-exercise-db` for incline fly, incline curl and Tate press). None is the catalogue's exact variant,
  so coverage does not change. The free-exercise-db photos are CC0-tagged but that project's photos have no clear
  original owner: flagged, not used.
- **Every mapped asset re-verified**: the build script fetched each reviewed clip again, measured it and compared it with
  wger's metadata (author, licence, codec, size, dimensions, index position). All five clips are byte-identical to 18
  October (same SHA-256); all 14 images keep author Everkinetic, CC BY-SA 3.0, not AI-generated.
- **Looked at, not just matched by title**: the five clip posters and seven picture pairs were viewed again. One
  correction: the shoulder-press drawing is a plain bench with **no** back support, so its variant now says "seated on a
  bench" (the October text claimed a back support).
- **Unmapped H.264 clips checked**: 16 (incline barbell bench), 55–56 (overhead cable extension), 58–59 (one-arm cable
  extension), 60–63 (skull crushers), 75–77 (kickbacks): none is a catalogue movement or its exact variant.

### Why a clip that exists is still not used

Fifteen catalogue movements have a matching wger clip that is **blocked by format or hosting**: romanian-deadlift,
leg-press, seated-cable-row, walking-lunge, dumbbell-shoulder-press, lateral-raise, biceps-curl, barbell-curl,
hammer-curl, pull-up, calf-raise, hip-thrust, face-pull, rear-delt-fly (all 10-bit HEVC with Dolby Vision metadata,
index at the end, most over 20 MiB) and leg-curl (generic entry; three variants exist). 10-bit HEVC is not reliably
decodable on Android, and streaming a file whose index is at the end means fetching most of it first. CC BY-SA 4.0
**does** allow a converted copy (an adaptation, under the same licence, with credit and a note of the change), but the
copy needs somewhere to live: no hosting was created or paid for, and Railway is not a media proxy. The remaining 23
have no usable clip at wger and need another licensed source or commissioned footage. Nothing was invented, and no
AI-generated picture fills a gap.

### Rights, per asset

- **Clips**: all five by "Goulart", **CC BY-SA 4.0** (https://creativecommons.org/licenses/by-sa/4.0/), which allows
  commercial use, copying, downloading and adaptation with attribution, a licence link, an indication of changes and
  share-alike for adaptations. Played and saved **unchanged**. Each poster is one frame scaled to 640 px: an adaptation,
  credited in the sheet with its change note and the same licence.
- **Pictures**: Everkinetic illustrations via wger, **CC BY-SA 3.0** (same obligations). The two 400 px thumbnails are
  placed side by side on white: an adaptation, credited the same way.
- **Uploader identity**: Goulart uploaded 70+ clips to wger in the same gyms and style, and Everkinetic is the known
  open illustration set; no conflicting copyright notice was found on any mapped asset. A licence tag on an upload is
  still the uploader's claim: excluded elsewhere are images with another company's notice (HOIST), commercial-looking
  charts or stock photos, no author, AI-generated, and free-exercise-db.
- **People in the clips**: the performer and, in some clips, bystanders in a public gym are recognisable. A Creative
  Commons licence covers copyright only, not personality or privacy rights; wger's uploader terms are the only evidence
  of consent. Recorded as a residual risk, not cleared.
- **wger's AGPL** covers its software, not this media; each asset carries its own licence, author and AI flag.

### Compatibility, measured

All five clips: H.264 **High** profile, level 3.0 (640 × 352) or 4.0 (1920 × 1080), AAC audio track (muted in the app),
QuickTime (.mov) with the index first. iOS's AVFoundation and Android's Media3/ExoPlayer decode this natively; nothing
was converted. Measured from the files' `avcC` headers, not inferred from the extension. Clip 22 was decoded and played
on the Android emulator (see Verification); the other four were not played on a device in this round.

## Where to find it

- **Exercise picker** (Add a movement, Replace…, Add exercise): a row with a clip has a 56 × 40 poster thumbnail with a
  play mark and **Watch demo**; a row with pictures has the pictures' thumbnail and **View guide**; any other built-in
  row keeps its (i). The action is a compact icon over a short label; with large text it becomes the icon alone with its
  full spoken label. The thumbnail itself is decoration. The action opens the sheet over the picker; tapping the row
  still chooses it. Closing the sheet chooses nothing and leaves the search, filters, scroll position and list as they
  were. Your own exercises have neither thumbnail nor action.
- **Plan builder and this-workout-only editor**: the row's (i) becomes the play or pictures icon with the same label as
  the picker for its tooltip; the sets/reps editor has **Watch demo** / **View guide** / **How to do it** at the top. The
  sheet opens over the form, so typed sets, reps, rest, target weight and notes stay, unsaved.
- **Recording a workout** (Train › Workouts panel): a 56 × 40 thumbnail with a play mark beside the selected movement's
  name, only when it has media. The existing **About** link stays for the written guide. Last session, the optional aim,
  the entry fields and Record set are where they were; nothing plays until Play.

## The sheet

`showExerciseDetails(context, exercise: (catalogKey, name, isTimed), prescription?)` in `guide_sheets.dart`; the old
`showExerciseInfo(prescription)` wraps it. In order:

1. The exercise's name (the sheet title, localized) and **Shown: …** the exact variant the media shows.
2. The video, the pictures, or "No demonstration for this exercise yet. The written guide below still applies."
3. **How to do it**: Setup and Movement when written from an exercise-specific source, otherwise the guide's cues under
   Technique with "General cues, not yet checked against a technique source."
4. **Common mistakes**, where the source gives them.
5. The existing guide (muscles, equipment, role, benefits, limitations, alternatives), the prescription when there is
   one, the guide's sources, **Technique text sources**, then the **media credit** (attribution, change note, licence
   and link, source page, and "The licence covers reuse of this media only. It does not mean the technique was reviewed
   by a professional."), then Ask about this exercise (with Leon or Leona's small avatar) and Replace… when the caller
   gives them.

Pictures carry **Start** and **End** (walking lunge: **Bottom**) under their own picture only where the drawings show
those positions; the labels stay left to right in Arabic because the pictures are one image. The caption says "Pictures
only. No video for this exercise yet."

The October version introduced Leon/Leona with a coach bubble under the clip; it is removed: the avatar between the
video and the instructions was not unobtrusive. Leon/Leona stays on Ask about this exercise.

## Playback

- Poster (bundled, uncropped, at most ~40 % of the screen height) with a round **Play**. Nothing is fetched or decoded
  until Play. Never autoplays.
- Playing: Play/Pause, Replay, **0.5× / 1×**, Full screen; "Muted. It repeats until you pause it."
- Loading shows the dimmed poster and "Loading demonstration…". After 20 s, or on any player error: "Demonstration
  unavailable", a reason and **Retry**; the written guide stays.
- Paused when another page covers the sheet (Ask GoHard, Replace…) and when the app is hidden or paused; it resumes
  only on Play. Disposed when the sheet closes. Full screen shows the same player and session. Play/Pause acts on the
  player's state at the moment of the tap (a background pause since the last frame is respected).
- Audio: always muted (`setVolume(0)`) with `mixWithOthers`, so music and the app's spoken cues carry on.
  `video_player` 2.14.1 (Android Media3/ExoPlayer, iOS AVFoundation).

## Downloads and offline

- Only on **Download**, per clip (all five clips' licences allow copies). Stored in app support storage
  `exercise-demos/`, file name = SHA-256; fetched with a plain HTTPS GET (no GoHard headers or token), checked for
  **exact size and SHA-256** before it is kept. At most **100 MiB** in all and **20 MiB** per clip, least recently used
  out first, never the clip playing. **Remove download** deletes it.
- A downloaded clip plays from the file, also in airplane mode. The poster, the written guide and the full credit are
  bundled with the app, so they are there offline whether or not a clip was downloaded.
- Nothing is fetched by opening Today, Train, the builder or the picker; no bulk download; no video in the IPA (12
  posters, 0.37 MB, and the manifest).

## Protecting the workout and the plan

Opening, playing or closing a demonstration never records a set, selects another exercise, replaces typed weight, reps,
duration or notes, pauses or resets the workout clock or rest timer, saves a plan edit, or creates or changes a workout.
Media are looked up by the **stable catalogue key** of the movement actually selected (after a replacement, the new
one); a custom exercise (`custom:` key) never gets media, whatever its name. No sync command, API or database change.

## Languages and accessibility

- en, fr-CA and ar for every word: 58 `demo…` strings, and the manifest's `translations` for the 12 variants and the 4
  sourced Setup/Movement/Common mistakes texts (French and Arabic written by the developer; **not reviewed by a fluent
  speaker**). Authors' names, licence names and links stay as published.
- RTL: the sheet and picker mirror; the picture labels deliberately do not (see above). Large text: tested at 320 px
  with twice the text size in all three languages. Reduce Motion: nothing animates on its own. Screen readers: the
  picker action, the editor icon and the recorder thumbnail each say what they open ("Watch a demonstration of Bench
  press", "View the picture guide for Lateral raise"), with a working tap action; the clip is "Demonstration video,
  muted"; the pictures describe the variant and the positions.

## Technique text and review

Media credits and technique sources are separate: a media licence is not evidence that the technique is right.
Setup/Movement/Common mistakes for four keys (bench-press, incline-dumbbell-press, dumbbell-bench-press,
overhead-triceps-extension) are paraphrased from the ACE Exercise Library, checked 18 Oct 2026 (on 19 Nov two of the
four pages answered and two returned 503 to an automated request; not re-read). The other 46 keep the guide's general
cues. **No text, clip or picture has been reviewed by a qualified coach**, and the French and Arabic technique text has
not been reviewed by a fluent speaker.

## How it is built

- `scripts/exercise-demos.spec.json`: the reviewed choices (asset IDs, variant, rationale, positions, translations, gap
  reasons). `scripts/build-exercise-demos.mjs --cache <dir>` fetches only those IDs, measures each clip, checks licence,
  author, AI flag, codec, host, size and index position, and writes `app/assets/data/exercise-media.json` and the
  coverage table. It never searches or takes a first hit. Posters: `scripts/exercise-demo-posters.ps1`.
- `exercise_media.dart`: `ExerciseMediaCatalog.parse(text, lang:)` (an entry with an HTTP or unlisted host, over
  20 MiB, without an approved status, licence link, credit, bundled poster or valid SHA-256, a custom key, an unknown
  position or listed twice is left out); `forKey` is an exact-key lookup. `DemoStore`: the phone's downloads.
- `exercise_demo.dart`: `ExerciseDemoMedia` (the one player), `DemoThumb`, `demoActionLabel` / `demoActionFor` /
  `demoIcon` (one wording everywhere); `demoPlayerFactoryProvider` is the player boundary tests replace.

## Verification

- `test/exercise_demo_test.dart` (21): the manifest is whole; exact-key lookup only; 12 malformed entries refused;
  download checked, atomic, deduplicated; wrong bytes, too many bytes, no network and no space leave nothing; > 20 MiB
  refused before fetching; a changed file is not trusted; LRU within the limit, never the playing clip; a restart finds
  the download offline; the player boundary (nothing until Play, muted, loop, speed, replay, full screen shares the
  player, background and covering pause, closing disposes, reopening makes one session); failure → unavailable +
  Retry; a start that never completes fails after 20 s; Download → plays from the file → Remove; no media / pictures /
  custom; the picker previews without choosing and keeps the search; Watch demo / View guide / (i) labels and spoken
  labels; Start/End and Bottom left to right in English and Arabic; French and Arabic variant and Setup with the author,
  licence and links unchanged and the credit present with no network; Arabic dark at 320 px with 2× text (clip playing,
  pictures, none, picker); recording: the replaced movement's own clip from the thumbnail, typed weight, rest timer,
  workout clock, Pause and selection unchanged, no set recorded.
- `test/plan_builder_ui_test.dart`: Watch demo over the prescription form keeps sets, rest, target and notes and saves
  nothing; a row without media keeps "About"; Replace… from the sheet still replaces.
- Renders with real fonts (`test/demo_render_test.dart`, gated): `docs/evidence/exercise-demos/{en,fr,ar}` – picker,
  picker with pictures, recorder light and dark, sheet with a clip (light, dark, How to do it, credits), pictures,
  none, and 320 px at 2× text. Test renders: a clip shows its poster.
- Device: `integration_test/journey_demo_test.dart` (see the ledger for the run and its result).

## Internal preview (Exercise Animatic sample, 21 Nov 2026)

The owner liked Exercise Animatic's bodyweight-squat sample and asked to test that visual direction inside the app
(branch `feature/animatic-squat-preview`, from `feature/wger-demonstrations`). Custom mannequin production is paused,
and its work is kept on `feature/exercise-mannequin`.

- **Source**: free sample 02, "Bodyweight Squat", from https://www.exerciseanimatic.com/free-fitness-exercise-videos
  (a Google Drive download, `Bodyweight Squat.mp4`, 2,540,138 bytes, SHA-256 `e3d50302…a2d`, H.264 Main 1920 × 1080,
  30 fps, 5.7 s, no audio). It shows one repetition of an anatomical figure with the thigh muscles highlighted, in a
  three-quarter view. There is no watermark or credit text in the clip. The original is kept outside the repo at
  `C:\dev\third-party\exercise-animatic\sample-02`.
- **Terms**: the sample page states no licence for the free samples. The Terms of Service (§7) forbid reproducing,
  distributing or displaying the content without written permission, and the licence (§8) is granted "with eligible
  purchases". So the sample is treated as **internal testing only**. Building an IPA or any shared build with it needs
  **written permission from Exercise Animatic** to put the free sample in an app build given to testers, or a purchase
  (the product page lists an N-ECL licence for mobile apps). On 21 Nov 2026 the owner authorised one unsigned IPA
  with the sample for their own private iPhone test only (no public-distribution rights).
- **Switch**: `--dart-define=GOHARD_DEMO_PREVIEW=true`. It is off by default: CI, tag builds and every normal build never
  set it. `ios-unsigned-ipa.yml` has a manual `demo_preview` input (default off) for an owner-approved private build:
  a separate job reads the files from a named draft release, the build checks the clip against the manifest's SHA-256,
  and the IPA artifact is kept 1 day. Used once: run 82 (21 Nov 2026, e1a5dc6). Afterwards the draft release and both
  artifacts were deleted from GitHub; the IPA is kept only locally (`C:\dev\third-party\exercise-animatic\ipa-82`). With the switch on, the manifest's `previews` entries replace the media for their **exact** keys.
  The only entry is `bodyweight-squat`, so back, goblet and Bulgarian split squats and every other key are unchanged.
- **Local slot**: `app/assets/demos/preview/` (git-ignored except its `.gitignore`) holds `bodyweight-squat.mp4` and
  `bodyweight-squat.jpg` (the first frame scaled to 640 px wide). Builds made on a machine with those files bundle them,
  so remove them before making any build that will be shared. CI's checkout has an empty slot.
- **App**: the same picker action, recorder thumbnail, sheet and player. Tap-to-play with the poster, Play/Pause,
  Replay, 0.5×/1×, full screen and background pause all work as for the other clips. The clip plays from the app bundle
  and has no Download line. The sheet adds "Internal preview: … licence for distribution is not confirmed, and the
  technique has not been reviewed by a professional" (en, fr, ar). The credit section names Exercise Animatic, links the
  Terms of Service and says the licence is not confirmed. A preview build without the file says "This preview clip is
  not in this build" with Retry and keeps the written guide.
- **Offline**: not exercised as a separate check. The clip is in the build and is never stored by the app's download
  store, and the terms do not confirm that storing it is allowed.
- **Tests**: `test/exercise_demo_test.dart` › internal preview (5); the full suite passed (1,015). Device:
  `integration_test/journey_preview_test.dart` (`scripts\test-android.ps1 -Only journey_preview_test`). Its captures
  stay in `app\build\journey-shots` and never go to `docs\evidence`. Run it a second time with the slot emptied to check
  the missing-file path.
- **Device run, 21 Nov 2026 (Android emulator Pixel_7, not an iPhone)**: with the sample in the build it passed. Watch
  demo appeared only on Bodyweight squat. Nothing played before Play. The clip decoded at 1920 × 1080, muted, and its
  position advanced; it was shown 371 × 209 in the sheet (16:9, not stretched or cropped). 0.5× and full screen (same
  shape) worked. It paused on Home, stayed paused on return and resumed on Play. Afterwards the typed reps (10), the
  recorded set, the selected movement and the Pause label were unchanged, and the workout clock kept running (52 s with
  the demonstration open, 52 s more on the clock). An added movement with no target has no rest timer, so the device
  run did not show one; the widget test covers keeping the rest timer. With the slot emptied it also passed:
  "Demonstration unavailable", the preview's reason, Retry and the written guide, with the workout unchanged. The
  figure fills about a third of the frame's width, so it looks small in the sheet.
- **Coverage if bought**: [EXERCISE_ANIMATIC_COVERAGE.md](EXERCISE_ANIMATIC_COVERAGE.md).

## Not verified

Real iPhone decoding of the QuickTime clips and the full-screen page, music continuing on a real phone, VoiceOver and
TalkBack wording on a device, the four clips other than 22 on any device, smoothness on a low-end phone, a qualified
coach's review, and a fluent speaker's review of the French and Arabic technique text.
