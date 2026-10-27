# Guide, quick help and Ask GoHard

Added 15 Oct 2026 on `feature/coach-today`. Three separate things, never presented as one another:

| Feature | Implementation | Shown as | Needs AI |
|---|---|---|---|
| **Guide me** | Rules + curated templates (`suggestTemplate`, `plan-templates.json`) from availability, equipment, experience | Guided setup | No |
| **Quick guide** | Reviewed bundled text (`coach-guide.json`): splits, exercises, terms | "Quick guide · built in" | No, works offline |
| **Ask GoHard** | Server-side model call grounded in the current draft and the reviewed text | "AI training assistant" | Yes |

Plan creation, schedules, exercise IDs, starting weights and recorded results never depend on a model. A model
request is made only when the person presses Send or a suggested question. Opening help, changing a field, reading
a definition or a hint appearing sends nothing.

## Reviewed content: `coach-guide.json`

Canonical file: `api/src/GoHard.Api/Data/coach-guide.json` (the API grounds answers in it). The app bundles a
byte-identical copy at `app/assets/data/coach-guide.json`; `coach_guide_test` fails if they differ.

```jsonc
{
  "version": 1,
  "sources": [ { "id": "acsm-2009", "title": "…", "publisher": "…", "url": "https://…" } ],   // only real, checked sources
  "splits": [ { "templateId": "upper-lower", "name": "Upper / Lower", "summary": "…", "organisation": "…",
                "days": "4 days a week, or a rotation over 2–3", "benefits": ["…"], "limitations": ["…"], "sources": ["acsm-2009"] } ],
  "exercises": [ { "catalogKey": "bench-press", "muscles": ["Chest", "Front of shoulders", "Triceps"], "equipment": "Barbell and bench",
                   "role": "main" | "accessory", "cues": ["…"], "benefits": ["…"], "limitations": ["…"],
                   "alternatives": ["dumbbell-bench-press", "push-up"], "sources": [] } ],
  "terms": [ { "id": "sets-reps", "term": "3 × 8–12", "text": "…" } ]
}
```

Every `catalogKey` / `alternatives` key exists in `exercise-catalog.json`; every `templateId` in `plan-templates.json`;
every source ID in `sources`. A custom exercise (`custom:<id>`) has no entry: the app says "Added by you" and claims
no verified technique information.

## `POST /api/v1/coach/ask` (authenticated; reads only; not a command, never queued)

```jsonc
// request
{ "requestId": "<uuid>",                 // same ID while in flight or within 2 min → the same answer, one model call
  "question": "…",                       // 1–600 chars after trim
  "history": [ { "role": "user" | "assistant", "text": "…" } ],   // ≤ 6 earlier turns, each ≤ 1500 chars
  "context": {
    "label": "Upper / Lower", "focus": "plan" | "split" | "workout" | "exercise",
    "templateId": "upper-lower" | null, "workoutId": "<uuid>" | null, "occurrenceKey": "e1" | null, "catalogKey": "bench-press" | null,
    "draft": { "title": "…", "durationWeeks": 8 | null, "timeBudgetMinutes": 45 | null,
               "schedule": /* PlanSchedule */, "workouts": [ /* WorkoutDefinition */ ] } | null,   // PlanRules shape limits
    "draftRevision": "<opaque>" | null } }

// 200
{ "requestId": "…", "kind": "ai", "answer": "…",          // plain text, ≤ 1200 chars
  "sources": ["acsm-2009"],                                 // only IDs present in coach-guide.json
  "proposal": null | {
     "summary": "Replace Bench press with Dumbbell bench press in Upper A",
     "scope": "draft",
     "operations": [                                         // 1–8, applied in order
       { "op": "replaceExercise", "workoutId": "…", "occurrenceKey": "e1", "catalogKey": "dumbbell-bench-press" },
       { "op": "setPrescription", "workoutId": "…", "occurrenceKey": "e1", "targetSets": 3, "targetRepsMin": 8, "targetRepsMax": 12,
         "targetDurationSeconds": null, "restSeconds": 90 },
       { "op": "addExercise", "workoutId": "…", "catalogKey": "…", "targetSets": 3, "targetRepsMin": 8, "targetRepsMax": 12,
         "targetDurationSeconds": null, "restSeconds": 60 },
       { "op": "removeExercise", "workoutId": "…", "occurrenceKey": "e3" } ] },
  "draftRevision": "<echoed>" }

// errors: { "code": … }
// 400 COACH_INVALID      malformed request
// 429 COACH_LIMIT        per-account limit (concurrency 1, daily cap) — "You've asked a lot today"
// 503 COACH_UNAVAILABLE  not configured, bad provider key (401/403), model unknown/unavailable (404 or a model error
//                        code), other provider 4xx, 5xx after its one retry, timeout, cut-off/refused/off-schema reply.
//                        Never called "Offline".
// 503 COACH_BUSY         the provider is rate limited (429) or overloaded (498/503/529) after at most one retry:
//                        { "code": "COACH_BUSY", "retryAfterSeconds": 30 | null }  — "Ask GoHard is busy right now.
//                        Try again in a moment." Question and Retry kept. Not COACH_LIMIT (that is the person's own limit).
```

Optional request field `"language"` (21 Oct 2026, docs/LOCALIZATION.md › Coach): `"fr-CA"` or `"ar"` adds one trusted
instruction to reply (and summarize a proposal) in Canadian French or Modern Standard Arabic; `"en"`, a missing field or
any other value leaves the request exactly as before. The question is never translated.

### Provider and configuration

Section `Coach`; environment variables use the `GOHARD_` prefix and `__` for `:` (Program.cs:
`AddEnvironmentVariables("GOHARD_")`). Groq is the provider for this project:

| Setting | Env var | Default |
|---|---|---|
| `Coach:Provider` | `GOHARD_Coach__Provider` | `Anthropic` (case-insensitive; `Anthropic` \| `Groq`; anything else = off) |
| `Coach:GroqApiKey` | `GOHARD_Coach__GroqApiKey` | — |
| `Coach:AnthropicApiKey` | `GOHARD_Coach__AnthropicApiKey` | — |
| `Coach:Model` | `GOHARD_Coach__Model` | Groq `openai/gpt-oss-120b`, Anthropic `claude-haiku-5-5` |
| `Coach:GroqBaseUrl` | `GOHARD_Coach__GroqBaseUrl` | `https://api.groq.com/openai/v1` |
| `Coach:Effort` | `GOHARD_Coach__Effort` | `low` (Groq `reasoning_effort`, Anthropic effort) |
| `Coach:MaxTokens` / `TimeoutSeconds` / `DailyLimit` | `GOHARD_Coach__…` | 4000 / 20 / 40 |

Hosted: `GOHARD_Coach__Provider=Groq`, `GOHARD_Coach__GroqApiKey=<secret>`, `GOHARD_Coach__Model=openai/gpt-oss-120b`.
Locally: `api/src/GoHard.Api/appsettings.Local.json` (git-ignored, lowest precedence):
`{ "Coach": { "Provider": "Groq", "GroqApiKey": "…", "Model": "openai/gpt-oss-120b" } }`.

`coach.ask` is declared only when the **chosen** provider's own key is set and the guide loads. `Provider=Groq`
without a Groq key is off, even with an Anthropic key: there is never a fallback to another provider or model, and
the model id is sent verbatim (an unavailable model is COACH_UNAVAILABLE, never substituted).

Groq request (`POST {GroqBaseUrl}/chat/completions`, `Authorization: Bearer <key>`): one `system` message (the
instructions and `<reviewed_references>`, joined by a blank line) and one `user` message (the labelled
`<context>`, `<draft>`, `<earlier_conversation>`, `<question>` blocks); `response_format: {type: "json_schema",
json_schema: {name: "coach_reply", strict: true, schema}}`; `max_completion_tokens`; `reasoning_effort: "low"`;
`include_reasoning: false`. No `stream`, no `tools`. The reply is `choices[0].message.content`; `finish_reason`
other than `stop`, a `refusal`, empty content, non-JSON or anything off the schema is a failure. The schema (shared
with Anthropic) lists every property as required, sets `additionalProperties: false` on every object, makes values
nullable with `anyOf [..., {"type":"null"}]` and has no numeric or length keywords (the server checks limits).

Groq docs relied on, read 15 Oct 2026: [OpenAI compatibility](https://console.groq.com/docs/openai) (base URL;
`logprobs`, `logit_bias`, `top_logprobs`, `messages[].name` are 400s), [API reference](https://console.groq.com/docs/api-reference)
(Bearer auth; `max_completion_tokens`, `max_tokens` deprecated; `reasoning_effort` low/medium/high for gpt-oss;
`include_reasoning` and `reasoning_format` mutually exclusive), [Structured outputs](https://console.groq.com/docs/structured-outputs)
(strict mode on `openai/gpt-oss-120b`; all properties required, `additionalProperties: false`, nullable via type
union or `anyOf` with null; streaming and tool use not supported with structured outputs),
[Reasoning](https://console.groq.com/docs/reasoning) (gpt-oss: no `reasoning_format`, use `include_reasoning`),
[Rate limits](https://console.groq.com/docs/rate-limits) (429 with `retry-after` in seconds),
[Errors](https://console.groq.com/docs/errors) (401/403/404/429/498/5xx; body `{"error":{"message","type"}}`),
[Models](https://console.groq.com/docs/models) (`openai/gpt-oss-120b` production, 65,536 max completion tokens).

Retries and limits: at most **one** retry, only for 429/498/503/529/5xx, only when the wait (the provider's
`retry-after`; 0.5 s for a 5xx without one; a 429 without one is not retried) is ≤ 5 s and fits inside the 20 s
budget. Auth, model and other 4xx failures and unreadable replies are never retried. The app retries only when the
person presses Retry (same `requestId`). The daily cap counts a question once the provider has been reached (any
HTTP answer, or the timeout while it worked) — not one refused before that, one whose connection failed, or one the
client abandoned. A failure is never remembered under its `requestId`, so Retry asks again. Logs carry the HTTP
status and the provider's error type/code only, never its message, the request or a key.

Server rules: credentials only in server configuration; capability `coach.ask` is declared only when configured. System instructions, the reviewed references and the person's text are kept in
separate, labelled parts of the request; the question, history, custom names and notes are untrusted. The model has
no tools beyond returning one optional proposal, fetches nothing and cannot name a source outside the list. A
proposal is dropped (the answer is kept) unless every operation names a workout and `occurrenceKey` in the sent
draft, a catalog key that exists or a `custom:<id>` the caller owns, and values inside `PlanRules` limits. No weight
is ever proposed. A provider failure never affects readiness, sync or any other endpoint.

Phone rules: the proposal is re-validated against the **current** draft before Preview and again before Apply. If the
draft changed since the question (`draftRevision` differs) the card says it was made for an earlier version and
offers "Check against my current draft", which re-validates and rebuilds the preview; newer edits are never
overwritten. Preview and dismiss change nothing. Apply goes through `PlanDraft` editor operations into the builder's
draft (saved like any edit, not activated) and offers Undo, which restores only what the apply changed and only if
those exercises were not edited afterwards.

## Leon and Leona

`CoachGuide.leon` (default) / `CoachGuide.leona`: an appearance preference on this phone (same store as Motion &
haptics), never inferred from the profile, identical capabilities. Fur and clothing keep their colours in every
theme; the accent only colours controls and selected indicators. Coaching hints: on by default, each shown at most
once per flow until "Show coaching hints again"; "Coaching hints" off removes unsolicited hints, never manual help.
No hint while recording sets, running, reviewing conflicts or reviewing a destructive change.

### Companion: the coach who speaks through bubbles

One recognisable guide (Leon or Leona) who speaks through an attached speech bubble of native text, greets the user on
Today and offers relevant help at appropriate moments. Bubbles only: no voice, microphone or lip-sync.

**Today.** The guide leans in from the right screen edge (head and upper shoulders, mirrored to look in, faded over
the shoulders; portrait 92 × 114 at ≥ 380 px, 80 × 100 below, 68 × 84 below 340 px). Right beside it, its bubble says
the greeting, one factual line from Today's own projection and Ask me, e.g. "Good morning, Bob! / Workout C is planned
today. Ask me ›" (`today_greeting.dart`: "<workout> is planned today.", "Your workout is ready to resume.", "A planned
rest day today.", "Today's workout is skipped/done/saved.", "Your plan is paused today.", after a finish this session
"Your workout is saved. Nice work.", or "Need a hand with today?" when there is nothing definite). The whole bubble is
the Ask me button; Ask GoHard opens about "Your training". The date and "Today" stay above, separate.

It stays: there is no close button, no "hide for today" and no timeout. It is part of the header (it scrolls away with
it and is never over a section, a form or the navigation) for as long as Me › Appearance › Show coach on Today is on;
that switch is the only way to remove it. Builds before 16 Oct 2026 stored a "hidden for today": it is no longer read
or written and is not turned into the Appearance setting, so an account that tapped × earlier sees the guide again
after upgrading. Narrow phones get the smaller portrait and large text a taller bubble; the guide never disappears for
size. With Show coach on Today off, the plain greeting with its time-of-day icon is shown, and there is no Ask button
in its place: Ask GoHard is the guide on Train (below). Worked out on the phone; opening Today never calls the AI; it
works offline. Trade-off (accepted for comfortable spacing): with the guide the header is about 285 px at 390 × 844
with a notch; the workout section and its action are whole on the first screen, nutrition a short scroll away.

**The bubble comes from the mouth** (`CoachSpeech` in `coach_bubble.dart`). The bubble is a raised rounded rectangle;
its tail is drawn separately, every frame, from the bubble's edge to the guide's lips: `RigArt.mouth` and `RigArt.front`
(the muzzle's edge at the mouth's height) are landmarks of the painting, mapped to the screen through the same
`RigGeometry` the renderer uses, as the head is posed now, so the tail follows a tilt or a nod and stops 4 px short of
the lips. Layout uses the settled mouth: the bubble's first line is level with it, and the portrait's empty side
(beyond the muzzle) tucks under the bubble, leaving only that small gap. The same composition holds for both guides,
any text length (the bubble grows downwards) and any width. No screen coordinates are hard-coded.

**Ask GoHard is the guide.** Every way into the conversation shows the selected guide, labelled by what it does
("Ask GoHard: open the conversation with Leon", a button with a tap action):

| Entry point | What the user sees |
|---|---|
| Today | the guide's portrait (`coach-avatar-launcher`) and Ask me in its bubble (`coach-say-ask`) |
| Train header | the guide's avatar (`coach-ask-launcher`), there whether or not Today shows the guide |
| bubbles and help sheets with Ask me | Ask me; the speaker's portrait opens the same conversation |
| Why this suggestion, About this exercise | "Ask GoHard" / "Ask about this exercise" with the guide's avatar |
| the conversation | the guide (moving, attentive while a question waits) in its header; each answer is headed by the guide's avatar and name, then "AI-generated" |

There is no generic AI icon and no text-only Ask button; Today has no second Ask beside the title. Opening the
conversation or showing a bubble sends nothing: only Send asks, and the existing Groq limits and proposal safeguards
apply unchanged.

**Elsewhere** (`coach_bubble.dart`): `CoachSay` (one or two short sentences, "Ask me" and at most one existing guide
action), `CoachSpeaker` (`CoachSpeech` inline: the whole 62 × 72 portrait on the left facing its bubble, × in the
bubble's corner, announced once, never takes focus; introduced, it peeks in and greets and its words arrive as it
settles), `CoachSpot` (where a context speaks, in the page's own flow: it pushes content down, covers nothing, scrolls
away) and `CoachHelpEntry` (the guide's avatar in a 48 px button: the one consistent way to ask for help). One bubble is
open at a time (`coachHelpProvider`). Where it speaks:

| Context id | Where | Appears by itself | Says | Actions |
|---|---|---|---|---|
| `train.noPlan` | Train › Plan with no plan or draft | once | Want a starting point? I can explain the splits or help you build your own. | Ask me, Guide me (Create plan) |
| `builder.preferences` | builder step 1 (help entry by the progress) | no | Pick the days you can train and your equipment… | Ask me (draft) |
| `builder.structure` | builder step 2 | once | Unsure which split fits your week? Let's compare your options. | Ask me (draft), Compare splits (template path) |
| `builder.workouts` | builder step 3 | no | Questions about sets, reps or a movement? The info button… | Ask me (draft) |
| `exercise.prescription` | the sets/reps/rest sheet | no | Questions about sets, reps or this movement? | Ask me, About this exercise |
| `food.search` | Add food (under the field, at the top of the results; gone while typing) | once | Search for a food, scan a barcode or enter your own… | none (built-in) |
| `food.portion` | the food form, under the amount and unit | once, only for a food with portions | You can count portions here. The weight is shown when a reliable conversion is available. | none |
| `me.goals` | Nutrition goals | once | These are your daily tracking targets. You can leave either one blank. | none |
| `me.appearance` | Me › Appearance (help entry in the app bar) | no | Choose Leon or Leona, whether I greet you on Today… | none |
| recording sets | workout screen app bar → sheet | never | Record each set when you finish it… | Ask me about the selected movement |
| a run | run screen app bar (open run) → sheet | never | Distance comes from your phone's GPS while this screen is open… | none |

Food, goals, appearance and runs have no Ask me: the coach server contract covers plans, splits, workouts and
exercises only, so nothing outside it is sent. During recording and a run, help is a sheet the user opens (the
same speaker inside), so nothing appears over a set field, the rest timer, the run controls or the keyboard; the
activity underneath keeps its input, timers and drafts, and Ask GoHard opens over the sheet and returns to it.

**Rendering — why not Rive.** No Rive editor is available to author or maintain a `.riv` rig here, and the art is a
painted raster, so a Rive file would be invented, not authored. Instead `coach_rig.dart` draws the approved bust
(`assets/coach/<guide>-bust.png`, 400 px, from `design/coach/assets/<guide>-avatar.png` by `build-coach-art.ps1`) as a
skinned mesh (`Canvas.drawVertices`, 18 × 18 grid over the texture): a head bone rotates and nods about the base of
the skull with its weight easing to zero across the neck (no seam, no cut-out parts), two brow bones lift, and
breathing scales the bust from its bottom row. Landmarks are fractions of the 1254 px source (`RigArt`), so the
texture size can change freely.

*Eyes.* The paintings have irises clearly inside their lash lines, so each eye (`RigIris`, measured on the originals)
has its opening as a polygon inside the lash line, the iris disc and the white's tone, sampled from its lid-shadowed top
to its lit bottom. Inside the opening (clipped to it) the original iris is toned to the white and the same painted
iris is drawn again from the texture, moved by the gaze (up to 55 % of its radius across, 22 % up or down) and turned
with the head; only the thin sliver it uncovers shows the new tone. Lashes, lids and the rest stay the painting:
nothing is stretched and no patch is painted over the face. Lids: the upper one sweeps down corner to corner over the
opening and its painted lash ring, feathered into the fur, its edge a dark lash line that comes to rest on the eye's
lower contour as a gentle curve; the lower one rises a little for the smile's squint. Both follow the opening as the
head moves.

`RigPortrait` is the only renderer entry point; a missing or unreadable texture shows the still round avatar, and the
greeting text never waits for it. Pose sheets of both guides in both framings (at the user, towards the bubble, away,
up, down, half and full blink, smile, head to the bubble, nod):
`flutter test test/coach_rig_render_test.dart --dart-define=GOHARD_RENDER=true` → `docs/evidence/coach/companion-poses.png`.

**Motion** (`coach_companion.dart`). Each pose value (slide, lean, tilt, nod, brow, smile, breath, gaze across and
up/down) is a damped spring, so any interruption — rapid taps, a guide switch, a theme change — continues from the
pose on screen; cues replace each other's schedule and never stack. Entrance ≈ 450 ms with a hair of settle (slide ω 14,
ζ 0.78); greeting: tilt towards the bubble and brows at 0.30 s, one nod 0.62–0.80 s, a blink at 1.05 s, the words
arrive with a glance at them, then back to the user with a small smile, settled at 1.55 s; gentle breathing, irregular
blinks and small looks until 7 s, then rest. At rest nothing ticks: a timer wakes it for one natural moment every 2–5 s for as long as it can be seen — a blink
(45 %, now and then a double one), a clear look to one side (35 %) or a glance at the bubble with a touch of head
(20 %), each look held 0.9–2.2 s and back to the user, often with a blink. Nothing bounces or
loops. Acknowledgement (being asked: the portrait or Ask me; a saved workout): eyes on the user, smile squint, one nod,
back after 1.1 s. Pending (Ask GoHard, only while a request is really in flight — `AskState.sending` — ending on answer,
error, Cancel or timeout): head the other way, brows up, leaning in, looking at the user, held without frames; released
with a brief smile. Blink: close 90 ms, closed 70 ms, open 170 ms.

*Why these values (16 Oct 2026, the eyes "never blink" on the phone).* The scheduler, repaint and lids were all working
(temporary logging on the emulator: blinks scheduled and painted to a full closure after the greeting, rest/wake cycles
active). What hid them was scale and time: on Today the eye opening is 6.3 pt tall, the old gaze moved the iris at most
0.9 pt, the old blink was fully closed for 30 ms (2–4 frames on a phone), and after the first minute a blink came about
every 14 s. Earlier emulator recordings looked fine because that emulator draws this app at a few frames a second and
the rig caps each step at 1/30 s, so every blink was played in slow motion. Recordings from the emulator still run at
about half speed for that reason; judge the timing on a phone. It moves only while its tab is selected (`TickerMode`),
its route is current, the app is in the foreground and the header is on screen; under Reduce Motion (the phone's or Me
› Motion) it is a still settled portrait looking at the user, with no blink and no eye movement. No speech, audio,
microphone or haptics.

**When the coach appears** (`coach_prefs.dart`, `CoachSpot`). Three kinds:

- *Today.* Always, while Show coach on Today is on. The entrance and greeting play at most once per local day per
  account on this phone (`greeted` = `owner|day`), marked when it starts, so tab switches, rebuilds, scrolling, syncs,
  theme changes, returning from the background and restarts never replay it; afterwards the guide is simply there,
  settled, beside its bubble. No entrance while a workout or run is open. Governed by Show coach on Today (not by
  Coaching hints).
- *Contextual introduction* (the table above). Once per account (`dismissed` holds `owner|context`; another account
  on the phone has its own), the first time the context is really in view: Coaching hints on, its route current and
  its tab selected (the shell builds every tab), the app in the foreground, no keyboard up (the view's own inset — a
  Scaffold strips it from the page) and the spot on screen (a spot built off screen or in a list's cache is not seen;
  scrolling it into view counts). Never daily, never twice; "Show coaching hints again" resets only this account.
  Typing pauses, scrolling and validation errors never open anything.
- *User-requested help.* The help entry opens (and closes) its context's bubble whatever the Coaching hints setting.

A finished workout with training in it is acknowledged once: `workoutSavedProvider` is set only by the finish's own
success path (memory only, cleared with a new sign-in), Today plays it when next in view and marks it played. Reduce
Motion (phone or app) shows the settled portrait and its bubble at once. There is no global overlay or floating
assistant: every bubble is laid out in its own page.

### Setup after creating an account

`features/setup/setup_screen.dart`. Only for an account created on this phone: `register` reports the new owner id
before the session starts, and the coach preferences record `setup[owner] = 'guide'`. `app.dart` shows the setup
instead of the shell while that entry exists, so a restart resumes at the same step; Continue moves it to
`'features'`, Skip setup or Done removes it for good. Accounts that sign in never get an entry.

1. **Choose your coach**: Leon and Leona as live companions (blinking, looking about; still under Reduce Motion) on the
   Appearance cards, applied at once. After a choice the chosen guide says hello through the attached bubble. "You can
   change this later in Me › Appearance." Continue or Skip setup.
2. **Optional features**: Weather on Today (opens the Today background setting: a city, or Automatic with its own
   explanation before the system prompt), Workout reminders (the same switch as Me; notifications are asked for only
   when it is turned on), and two lines saying barcode scanning and GPS runs ask for the camera or location when first
   used. Done lands on Today. Nothing on this page asks for access by itself.

Me › Phone permissions reads the platform's current answer each time it opens (and on returning from Settings):
location through geolocator, notifications through the plugin's own check; the camera has no check without starting
it, so the row says when it is asked. It never asks, offers Open phone Settings, and says that Units, Appearance and
Today background are app preferences in Me. Android reports a location refused once the same as never asked, so that
row says "Not asked yet, or not allowed".

### The coach on every tab

The same selected guide everywhere: Today (the companion and its bubble), Train and Eat (below), workout and run
recording (the avatar in the app bar opens help in a sheet; nothing pops over fields, timers or controls). Showing any
of them sends nothing.

#### Train and Eat (17 Oct 2026)

Today's bust and mouth-attached bubble (`TabCoach` in `coach_bubble.dart`, the same `CoachSpeech` / `CoachCompanion`
renderer and lifecycle) peek in from the right edge, compact (80 × 100 at 390 px, 70 × 88 below 380, 60 × 74 below
340). On Train it sits under Workouts / Plan / Progress, so the sections stay at the top with large text; on Eat under
the title. It is part of the page's flow: never over a control, a form or the keyboard (neither tab has a field). It
peeks in once while the tab is alive (the shell keeps tabs built), the first time the tab is in view (selected, its
route current, the app in the foreground, on screen); a new section or a rebuild changes only the words. Reduce Motion:
settled at once. No close button. There is no second, small launcher beside it: the bust is the help entry.

What it says is fixed words chosen from the real state (`train_screen.dart` `_coachSay`, `eat_screen.dart` `_say`):

| Where | Words | Action |
|---|---|---|
| Train › Plan, no plan | "Let's build your training plan. Choose a familiar split or make your own." | **Create my plan** (deep button in the bubble) → the existing Create plan page; the only one on the page. "Train without a plan" stays below as a quiet link |
| … a plan in progress in the builder | "Your plan in progress is saved on this phone. Pick up where you left off." | **Continue my plan** → the builder on that draft (nothing discarded) |
| … a saved draft plan | "Your plan is saved as a draft. Review it, then start it when you're ready." | **Review my plan** |
| Train › Plan, a plan | how to read and adjust the week (or that it is paused) | Ask me about the plan |
| Train › Workouts | an open workout to resume, or recording one's own (and where the planned one starts) | Ask me ("Your training") |
| Train › Progress | what is recorded, or that it appears once a workout is finished | Ask me ("Your progress") |
| Eat | "Log a meal, or set your daily goals." (with goals: "… and see how the day adds up against your goals"; with water shown: "Log a meal or some water…") | None: Log food and the goals link are right below it in the summary. No Ask me: Ask GoHard answers training questions only |

| Eat, saved-foods hint (18 Oct 2026; once each, Coaching hints govern it) | with food logged and nothing saved: "Eat the same foods often? Tap the star on a food's amount page and it waits under Favourites in Add food." · with favourites: "Your favourite foods are one tap away. Pick one, check the amount, then log it." (only My foods: "Foods you saved are in My foods. …") | **Open Favourites** / **Open My foods** (a guide action, not a primary button) → the existing Add food, on that list, for the day shown in Eat, the meal from the time of day (changeable there) |

#### Saved foods (18 Oct 2026)

Since 23 Oct 2026 saved meals and recipes exist (docs/FOOD_DATA.md › Saved meals and recipes); see the next section. Saved
foods are guided to as before: **Favourites** (any found food starred on its amount page) and **My foods** (foods the person wrote
or corrected), both lists in Add food. Eat's coach gives one saved-foods hint per stage (`eat.saved.new`, then
`eat.saved.shortcut`), chosen once for the screen's life and marked seen as it is shown; a first visit with nothing
logged keeps "Log a meal". Show coaching hints again brings them back; Coaching hints off hides them. The Eat help
(the bust, or the small avatar when the coach is off) explains the two lists and always offers Open Favourites. A
hint, the shortcut or the help never logs food: choosing a food opens its amount page, and only its own confirm logs
it; old journal entries are never rewritten. Food names and values are never read aloud.

#### Saved meals and recipes (23 Oct 2026)

Built-in words only, no AI request. On Eat, once the hints above have had their turn and food has been logged:
`eat.meals` "Eat this often? Save the meal and adjust the amounts next time." with the guide action Saved meals &
recipes (opens the library for the day shown). In the library, introduced once each when in view: `meals.library`
(what a saved meal is, and that amounts can be changed before logging) and `meals.recipes` ("A recipe divides a whole
batch into the servings you choose."), also behind the help entry in the app bar and in the recipe editor. After a save
a short toast says "Your meal is in Saved meals & recipes." A hint or shortcut never saves or logs.

#### Eating out (25 Oct 2026)

The same guide is the way to ask for help on Eating out (docs/EATING_OUT.md): `TabCoach` id `eatout`, fixed words,
leaning in (`attentive`) only while a request is really in flight; tapping it focuses the request field. Asking there
is NOT Ask GoHard: it is a narrow endpoint (`POST /restaurants/interpret`) whose model only turns words into checked
preferences naming real catalog items. It shares Ask GoHard's provider, timeout, retry rule and per-account limits
(`CoachService.GuardedAsync`: one request at a time and ONE daily allowance for both), and is declared
(`restaurants.interpret`) only where `coach.ask`'s provider rule holds. Ask GoHard itself still answers training only.

On Eat (27 Oct 2026), once the hints above have had their turn — or, for an account with nothing logged or saved, on
the visit after its first (that first visit keeps the usual words about logging and is remembered per account as
`eat.first`; a visit ends when another tab is shown): `eat.out` "Eating out today? I can help you choose an
order—or improve the one you want." with the guide action **Find an order** (opens Eating out for the day shown and the
meal of the time of day, like the panel). Built-in words, no AI request; chosen and marked seen only while Eat is the tab
in view, its route current and the keyboard down; Coaching hints and *Show coach on Train and Eat* govern it. It only
points to the permanent Eating out panel under the summary, which stays with the coach or hints off.

#### Run / Walk and Steps (18 Oct 2026; corrected the same day)

Ready: "Choose your setup. Start when ready." (or "Intervals are set. Start when you're ready."); words only, so the
setup and Start stay in view. While recording, the coach speaks through the **coach line** under the dial
(docs/RUN_WALK.md › Voice and alerts): Leon or Leona's animated bust with the bubble from the mouth (the same rig and
bubble as Today, compact), the words of the last announcement, a nod at each new one; in the page, never over the map
or the controls; the words alone when Show coach on Train and Eat is off.

Today introduces Steps once (`today.steps`, Coaching hints govern it): "Want to track your daily movement? Enable
steps here." with **Enable steps**, which opens the Steps sheet. Only while steps are off and their tile is shown, not
on the account's first day (that greeting is about the plan: an earlier day's greeting must be on record), decided the
first time Today is really in view; it reads no health data and asks the AI nothing. With the coach off, the tile's
own Enable is there. Spoken aloud only with Voice updates on, in a voice on the phone (no AI, no
network), Leon a little lower and Leona a little higher. After a save that sets a personal best, the Saved screen's
coach says it once ("Your longest walk so far, 4.00 km."), from the save itself, never from a sync or a restart.

No score, trend, readiness or form judgement is ever said. On Train the bust opens Ask GoHard about the section in view
(the plan's title, "Starting a plan", "Your progress", "Your training"); on Eat it opens the built-in journal help.
Water is mentioned only when it is shown (turned on, and the server declares `water.entries`).

Me › Appearance › **Show coach on Train and Eat** (default on, `CoachPrefs.onTabs`, key `tabs`) is separate from Show
coach on Today, whose meaning is unchanged. Off: Train shows the same Create / Continue / Review action as an ordinary
empty state, Eat keeps Log food and the goals link, and the guide's small avatar beside the title is the help entry.
The old one-time "Train without a plan" introduction (`train.noPlan`) is gone: the coach now says it every time, in
place of the long empty-state paragraph.

A help sheet's guide used to stay hidden: the companion checked once, on its first frame, whether it was on screen,
and a sheet is still below the screen then, with nothing scrolling to check again. It now looks again after each frame
until it has started (no frames are requested for that). `coach_companion_test` covers it.

### Groq rate limits in practice (live, 15 Oct 2026)

`openai/gpt-oss-120b` on this account's Groq plan allows 30 requests and 8K tokens a minute (console.groq.com/docs/
rate-limits; the account's own figures are on its Limits page). A request is kept near 2K prompt tokens (only the
asked-about exercise in full, named terms only, `max_completion_tokens` 1500; a test bounds the prompt) so several
questions fit in a minute. Beyond that Groq answers 429 with `retry-after`; the server retries once only when the wait
is ≤ 5 s, otherwise the app shows "Ask GoHard is busy right now" with the question kept and Retry. A higher Groq plan
raises the limits; nothing in the app needs to change.
