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
