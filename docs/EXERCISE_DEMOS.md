# Exercise demonstrations

Added 18 October 2026 on `feature/exercise-demonstrations`, from `GoHard_Exercise_Demonstrations`. One shared exercise
sheet shows a real person doing the movement where a reviewed clip exists, a reviewed illustration where only that
exists, and plainly says so where nothing does. Row by row coverage: [EXERCISE_DEMOS_COVERAGE.md](EXERCISE_DEMOS_COVERAGE.md). Since 19 Oct 2026 the owner can publish videos over this
library from the phone: [OWNER_EXERCISE_VIDEOS.md](OWNER_EXERCISE_VIDEOS.md).

## Coverage (50 built-in catalogue keys)

| | Count | Keys |
|---|---|---|
| Video (real person, streamed or downloaded) | **5** | bench-press, incline-dumbbell-press, dumbbell-bench-press, overhead-triceps-extension (seated), dip (parallel bars) |
| Still only (start and finish illustration) | **7** | barbell-curl, biceps-curl, hammer-curl, lateral-raise, seated-cable-row, walking-lunge, dumbbell-shoulder-press (seated) |
| Written guide only | **38** | everything else; each has its reason in the coverage table |

Technique text written from an exercise-specific source (Setup, Movement, Common mistakes): **4** keys (bench-press,
incline-dumbbell-press, dumbbell-bench-press, overhead-triceps-extension), from the ACE Exercise Library, checked 18 Oct
2026. The other 46 keep the existing general cues, labelled "General cues, not yet checked against a technique source".
**No text or clip has been reviewed by a qualified coach.** Code review and model review are not that.

Clip bytes in the manifest: 35.07 MiB in all (largest 11.29 MiB). Bundled with the app: 12 posters, 0.37 MB, and the
manifest; no video is bundled.

## Where to find it

- **Exercise picker** (Add a movement, Replace…, Add exercise): a row with a clip has a small static thumbnail and a
  **Demo** button; another built-in row has an **About** (i) button; your own exercises have neither. Demo and About open
  the sheet over the picker; tapping the row still chooses it. Closing the sheet chooses nothing and leaves the search,
  filters, scroll position and list as they were.
- **Plan builder and this-workout-only editor**: the row's (i) becomes a play-circle button for an exercise with a clip
  ("Demonstration and guide for …"); the sets/reps editor has **Watch demonstration** (or **How to do it**) at the top.
  The sheet opens over the form, so typed sets, reps, rest, target weight and notes stay, unsaved. Ask and Replace… keep
  their own buttons in the sheet.
- **Recording a workout**: **Watch demo** (or **How to do it**) in the exercise panel under the movement's name, never in
  the menu. It shows the movement actually selected (after a replacement, the new one, by its own catalogue key).

## The sheet

`showExerciseDetails(context, exercise: (catalogKey, name, isTimed), prescription?)` in `guide_sheets.dart`; the old
`showExerciseInfo(prescription)` is now its wrapper. The picker passes identity only (no invented sets/reps); the editor
and the workout pass the real prescription. Order: Quick guide label, muscles, equipment, the demonstration, the
coach's one line (see below), **How to do it**, In this routine, Good to know, Limitations, Alternatives, Prescription
(only when there is one), the guide's sources, **Technique text sources**, **Demonstration video credit** (or
Illustration credit), then Ask about this exercise and Replace… when the caller gives them.

The media area (`exercise_demo.dart`):

- Poster (bundled, uncropped, at most ~40 % of the screen height) with a round **Play**. Nothing is fetched or decoded
  until Play.
- Playing: Play/Pause, Replay, **0.5× / 1×** (the app's segmented control), Full screen; "Muted. It repeats until you
  pause it." The clip is muted and loops until paused.
- Loading shows the dimmed poster and "Loading demonstration…". After 20 s, or on any player error: "Demonstration
  unavailable", a reason and **Retry**; the written guide is unaffected.
- Download line: "Streams when you press Play · 1.4 MB" with **Download**; "Downloading"; "Downloaded on this phone ·
  1.4 MB" with **Remove download**; a failure says why ("could not be reached", "no longer at its source", "not the
  reviewed demonstration", "not enough free space") with **Try again**. Nothing claims the download is in the account.
- A still: the illustration on white with "Illustration: start and finish positions. No video for this exercise yet."
- No media: "No demonstration for this exercise yet. The written guide below still applies." (no fake poster).
- A custom exercise: the existing "Added by you" line, no media and no technique claims, whatever its name.

Full screen pushes a black page with the **same** player (same session and position) and the same controls on a surface
panel; it does not touch orientation or system bars, so there is nothing to restore.

## The coach

Leon/Leona says "Want to see this movement? Press Play on the demonstration." once, through the existing `CoachSpot`
(id `exercise.demo`, introduce): Coaching hints on, the account has not seen it, no other bubble open, the sheet the
current route. It sits in the sheet's flow, below the media, never over a field or control. Opening the sheet and
pressing Play call no AI; **Ask about this exercise** is the existing avatar-led path with the exact catalogue key.
Coach off and Reduce Motion are unchanged (the media starts only on Play either way).

## Sources and rights

- **Provider**: wger (https://wger.de), official public API v2, read 18 Oct 2026: `/video/` (78 clips), `/exerciseimage/`
  (383 images), `/license/`, `/exercise-translation/` (English names). wger's AGPL covers its software; each clip and
  image carries its own licence, author and is-AI flag, which is what was used.
- **Clips**: all five by "Goulart", **CC BY-SA 4.0** (https://creativecommons.org/licenses/by-sa/4.0/), H.264 in
  QuickTime/MP4 with the index first, played and saved **unchanged** (no transcoding, cropping or trimming). Each poster is
  one frame of its clip, scaled to 640 px (an adaptation, credited in the sheet as "Changes").
- **Stills**: Everkinetic illustrations, **CC BY-SA 3.0**, via wger. Poster = the provider's two 400 px thumbnails side
  by side on white.
- **Excluded on rights**: images carrying another company's copyright notice (HOIST), images that look like commercial
  muscle charts or stock photos uploaded under a CC tag, images with no author, and anything marked AI-generated. A CC
  tag on an upload is not taken as proof the uploader could grant it.
- **Technique text**: ACE Exercise Library pages for chest press (barbell, #5), incline chest press (#25), chest press
  with dumbbells (#19) and triceps extension (#74), paraphrased, not copied, checked 18 Oct 2026 and listed in the sheet
  under "Technique text sources", apart from the media credit. ACE's triceps extension is standing in a split stance;
  the clip is seated, which the Setup text says.
- Share-alike: the posters are adaptations of CC BY-SA material and stay under the same licences, credited in the sheet.

The reviewed choices are data (`scripts/exercise-demos.spec.json`); `scripts/build-exercise-demos.mjs --cache <dir>`
fetches only those IDs, measures each clip (bytes, SHA-256, index position), checks licence/author/codec/host/size and
writes `app/assets/data/exercise-media.json` and the coverage table. It never searches or takes a first hit, and a CI
run does not need it (the manifest is committed). Posters: `scripts/exercise-demo-posters.ps1` (Windows, WinRT +
System.Drawing); a re-run reproduced all 12 byte for byte.

## How it is built

- `exercise_media.dart`: `ExerciseMediaCatalog.parse` (typed manifest; an entry with an HTTP or unlisted host, over
  20 MiB, without an approved status, licence link, credit, bundled poster or valid SHA-256, a custom key, or listed twice
  is left out and logged); `forKey` is an exact-key lookup, null for `custom:` keys. `DemoStore`: the phone's downloads.
- `exercise_demo.dart`: `ExerciseDemoMedia` (the one player); `demoPlayerFactoryProvider` is the player boundary.
- Media metadata is separate from plans and workouts: viewing or downloading adds no sync command and changes no record.
  No API or database change.

### Playback lifecycle

One `VideoPlayerController` per sheet, created on Play only (none while scrolling the picker). Paused when another
route covers the sheet (Ask GoHard, Replace…) — not by its own full screen — and when the app is hidden/paused; it
resumes only on Play. Disposed when the sheet closes, on Retry and on Remove download; a callback from an old session
cannot reach the sheet. `video_player` 2.14.1 (Flutter's maintained plugin; Android ExoPlayer/Media3, iOS AVFoundation).

### Audio

Always muted (`setVolume(0)`) with `VideoPlayerOptions(mixWithOthers: true)`. Read in the plugin source: on Android it
then takes no audio focus, so music and the app's TTS continue; on iOS it only *adds* `.mixWithOthers` to the current
audio session category and keeps the options flutter_tts set (`duckOthers`, `interruptSpokenAudioAndMixWithOthers`).
Speech, rest alerts and background recording are not reconfigured.

### Downloads and offline

- Only on **Download**. Stored in app support storage `exercise-demos/` (not the OS cache), file name = SHA-256.
- Fetched with a plain Dio GET (no GoHard headers or token, 15 s connect / 30 s receive, ≤ 3 redirects, HTTPS only),
  into `<sha>.part`, stopped past the reviewed size, then checked for **exact size and SHA-256** and only then renamed
  into place. Any failure deletes the partial file. Two requests for one clip share one download.
- At most **100 MiB** in all, **20 MiB** per clip; least recently used out first, never a clip that is playing.
- A downloaded clip plays from its complete local file, also after a restart in airplane mode. A copy whose file
  disappeared or changed size is forgotten and deleted, not trusted. Streaming without Download is never called
  downloaded. Remove download stops a player using that file first.
- Nothing is fetched by opening Today, Train, the builder or the picker; no bulk download; no new permission.

## Gaps that need a decision

The 20 MiB cap and decodability left these out although wger has a matching clip (all 10-bit HEVC with Dolby Vision
metadata, index at the end): romanian-deadlift, leg-press, seated-cable-row, walking-lunge, dumbbell-shoulder-press,
lateral-raise, biceps-curl, barbell-curl, hammer-curl, pull-up, calf-raise, hip-thrust, face-pull, rear-delt-fly; and
leg-curl (generic entry; lying, seated and standing variants exist). Covering them needs **a transcoded H.264 copy
(CC BY-SA allows it with credit and a change note) and somewhere to host it**: a decision on hosting (none was created or
paid for here; Railway is not used as a media proxy). The remaining ~23 have no usable clip at wger; they need another
licensed source or commissioned footage. No content was invented for them.

## Tests and evidence

- `test/exercise_demo_test.dart` (17): the bundled manifest is whole; exact-key lookup, no custom/name/near match;
  12 malformed or unapproved entries refused; download checked and atomic, deduplicated (3 requests, 1 fetch), wrong
  bytes / too many bytes / network / no space leave nothing and can be retried; > 20 MiB refused before fetching; a
  changed file is not trusted; LRU within the limit, never the playing clip; a new store (restart) finds the download
  with fetching forbidden; the player boundary: nothing until Play, muted + loop + speed + play, 0.5×, replay, full
  screen shares the player, background pauses, a covering page pauses, closing disposes, reopening makes one new
  session; failure → unavailable + Retry; a start that never completes fails after 20 s; Download → plays from the file →
  Remove; no media / still / custom fallbacks; picker Demo chooses nothing and keeps the search, the row still chooses;
  320 px at 2× text (sheet with clip/still/none, picker); recording: the replaced movement's own clip, typed weight,
  rest timer and running clock unchanged, no set recorded.
- `test/plan_builder_ui_test.dart`: Watch demonstration over the prescription form keeps sets, rest, target and notes,
  saves nothing; the existing exercise information, contrast and 320 px tests pass with the new sheet.
- These tests use local fixtures and a fake player: they cannot show that a phone decodes a clip, how smoothly it plays,
  or whether the movement is taught well.
- Device: `journey_demo_test` on emulator-5554 (API 36, debug, local API), both phases **passed** on 18 Oct 2026 with
  the real wger clip 22 (not a sample video): picker Demo chose nothing and kept the search; no-demonstration fallback;
  builder Watch demonstration kept typed sets and notes; recording with the rest timer running, Watch demo on bench
  press streamed and played, 0.5×, full screen and back on the same playback, paused by Home and stayed paused,
  downloaded (the file on the phone is named by the reviewed SHA-256); typed 62.5 kg × 8, the rest timer, Pause and
  "1 of 13 planned sets recorded" unchanged. Phase 2 after force-stop with Wi-Fi and data OFF: the workout's typed values
  came back, the downloaded clip played from the phone, the never-downloaded dip clip said "Demonstration unavailable"
  with Retry and the guide. Captures `docs/evidence/screenshots/demo-01…12.png`, recording
  `docs/evidence/recordings/demo-recording.mp4`; renders `docs/evidence/design/demo-*.png` (Blue Light, Pink Dark, 320 px
  at 2× text). The green rectangles in the device captures are TalkBack's focus outline (TalkBack is on in that emulator),
  not part of the app. Emulator decoding uses the software codec; it says nothing about a real phone's smoothness.

## Not verified

Real iPhone decoding of the QuickTime clips, music actually continuing on a real phone, VoiceOver/TalkBack wording of
the controls, full-speed smoothness on a low-end phone, battery use, and any qualified coach's review of the clips or the
text.
