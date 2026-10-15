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

## `POST /api/coach/ask` (authenticated; reads only; not a command, never queued)

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
// 503 COACH_UNAVAILABLE  not configured, provider error, timeout. Never called "Offline".
```

Server rules: credentials only in server configuration (`GOHARD_Coach__AnthropicApiKey`); capability `coach.ask`
is declared only when configured. System instructions, the reviewed references and the person's text are kept in
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
