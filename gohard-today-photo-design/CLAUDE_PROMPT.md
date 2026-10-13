# GoHard Today: photo cards and clear workout details

Implement this approved design in the CURRENT GoHardRebuild Flutter app. Work in C:\dev\GoHardRebuild or the actual checkout available to this session. The last reported main checkpoint was e33a7fc; inspect current HEAD and treat current source as authoritative. This is a continuation of the existing app.

The user has approved the photo layout: one full-width workout card, then matching Run and Nutrition photo cards side by side. The workout card must make its exercises and progress easy to understand. You may improve spacing, hierarchy, components and responsive behavior as needed to produce a polished result. Complete implementation and verification without further check-ins for routine decisions.

## Read the actual project first

Read applicable repository instructions and the relevant design, food and testing documentation. Inspect Today, the existing workout details/recording flow, running state, the shared daily nutrition projection and the theme tokens. Preserve unrelated local work. Use an isolated feature branch based on the current project, and follow its established state-management and component patterns.

Reported existing files include today_screen.dart, nutrition_surface.dart and train_screen.dart under app/lib/features; discover their actual locations. Inspect working code before choosing a component structure. This is native Flutter work, using the existing account, sync, commands and navigation.

## Visual sources and assets

Open these files directly before coding:

- references/today-workout-refinement.png: primary reference for the workout header, exercise rows, recorded-set progress and single Resume action.
- references/selected-photo-layout.png: selected overall composition, especially the two companion photo cards.
- references/current-today.jpeg: the user's current phone screenshot, showing the mismatch this change fixes.
- assets/workout-hero.webp
- assets/run-cover.webp
- assets/nutrition-cover.webp

The references are concepts, not specifications for hard-coded sizes or sample data. The refinement uses illustrative Back exercises, prescriptions and 1-of-9 progress. Actual names, totals, states, dates and nutrition must come from the app. Its large photograph should become more compact in the real implementation so Today remains useful at a glance.

The three standalone photos are provided as bundled assets. They are generated editorial illustrations, not photographs belonging to the user, evidence of a completed workout, or a logged meal. Read ASSETS.md for provenance and crop guidance. Use the supplied originals rather than cropping photo pixels out of a UI mockup.

## Page composition

Keep the actual local date, Today heading and Today / Train / Eat / Me navigation. Use the current Inter typography and Calm Momentum theme system. Make all three sections share a deliberate family: consistent corner radius, spacing, title treatment, icon scale, button height and surface treatment. The workout remains the main action.

Use a full-width workout card followed by a two-column Run / Nutrition row when there is enough room for real content. Choose the layout from available width and text scaling. Stack the companion cards vertically when long labels, increased text size or a narrow phone would otherwise cause clipping or awkward wrapping.

Use content-driven heights and scrolling. Keep empty states compact. Aim to make the workout action and supporting cards easy to reach at common phone sizes. Do not shrink text, truncate important values or force populated nutrition to fit an empty-state mockup.

## Workout: name, exercises, progress, action

Use a compact photographic header, initially around 100–130 logical pixels where it works. It contains a clear Workout label, the actual workout name and a named state such as Due today or In progress. Keep sufficient image contrast behind text. Avoid a tall photograph that pushes useful information down the page.

Place exercise information on the neutral card body below the photograph:

- One concise summary from actual data: exercise count and planned set count when known.
- Up to three exercise rows in workout order, with readable names on the left.
- Planned sets and reps on the right only when the source contains them. For example, "3 × 8–12" is a prescription, not recorded performance.
- Support long names and unavailable targets gracefully.
- For additional exercises, show a quiet "See all N exercises" action opening the existing workout details. With one exercise, show one useful row.
- Use the existing details/recording route for row interaction where a real route exists. A row must not look clickable if it cannot do anything.
- Active or completed indicators must reflect actual state. Do not highlight the first exercise merely because it is first, or mark an exercise complete because one set was recorded.

Below the preview, show recorded-set progress when a reliable planned denominator exists: "X of Y sets recorded" and a restrained progress rail. This records sets, not exercise or workout completion. Clamp the fill safely while keeping displayed real counts. If the planned total is unknown, show "X sets recorded" without inventing a percentage or expected sets.

Use one clear Start workout / Resume workout action. Preserve existing completion, rest day, paused-plan and no-plan behavior. A manual workout must not falsely complete a scheduled workout. A selected plan duration remains labelled as planned, not presented as a calculated estimate.

Keep rest/no-plan states honest and compact; a training photograph must not imply a workout is due on a rest day. Existing safe Start workout / plan actions can remain.

## Run companion card

Place the running photo in a compact header and the Run title, state and action in the same shared card system.

- Show Start run when none is open.
- Show Continue run when a run is open, opening that exact saved session.
- Include actual distance/time only when available and meaningful.
- Keep the action available with no workout plan and on rest days.
- Keep one running entry point on Today.
- Reuse the established run flow, persistence and permission handling.

The cover is decorative. It is not a map, live route or claim that GPS is tracking in the background. This change does not add maps or background tracking.

## Nutrition companion card

Use a compact food-photo header with Nutrition and the same body/button styling. Use the existing daily nutrition projection shared with Eat; keep its calculation and logging rules intact.

For no entries, show "No food logged today" and Log food. The decorative bowl photo must not create a meal entry or imply the user ate it.

When entries exist, show clear calories and protein. If the user has set goals, retain compact, readable goal progress and actual totals. Missing nutrients remain unknown; partial totals remain qualified. Do not fabricate complete totals, remaining quantities or default goals. Goal rails fill to their limit but real over-goal values remain visible.

Food journal is a quiet navigation action, not another dominant button. Keep one obvious Log food action per card. Natural food portions, quantity conversions, saved definitions, offline drafts and historical snapshots must continue working unchanged.

If the content needs more space, grow or stack the companion cards. Do not hide real nutrition information merely to preserve the mockup's tile height.

## Photos and implementation quality

Copy the provided WebP files into the app's established asset directory and register them correctly. They must load without network access or external image-service keys. Use shared asset references and intentional BoxFit.cover / focal alignment. Preserve recognizable shoes, dumbbells and the bowl after cropping.

Use a lightweight reusable photo-header/card primitive only where it reduces duplication. Keep workout-specific logic, run state and nutrition presentation separate. Reuse existing buttons, surfaces, text styles and projections. Avoid a speculative generic dashboard framework or a parallel theme system.

These images are already encoded as WebP. Inspect decoded dimensions, package size and on-device memory behavior; use appropriate decode sizes where helpful. Ensure scrolling and theme changes do not repeatedly decode unnecessarily large photos. Provide a graceful neutral fallback if an asset cannot be loaded. Exclude decorative photos from screen-reader announcements.

Use semantic colors from the chosen theme. Blue, Green and Pink must all work with Light, Dark and System. Do not hard-code blue controls from the reference into Green/Pink. Avoid excessive brightness, glowing panels or translucent surfaces that weaken readability. Use restrained scrims on photos and verify the rendered contrast. Preserve theme persistence and unsaved workout/food state through appearance changes.

## Verification and final delivery

Add meaningful regression coverage for the affected behavior: the correct Start/Resume and Start/Continue actions, actual workout state, unknown planned totals, exercise previews, nutrition empty/partial/goal states, and responsive layout under long content and large text.

Inspect fresh rendered screens for all six accent/mode combinations. Also inspect narrow width around 320 logical pixels, common phone width, large text, one exercise, more than three exercises, due/in-progress/completed/rest/no-plan states, active/no run, and nutrition with goals and missing values. Verify screen-reader labels, touch targets, scrolling and safe areas.

Run analysis and applicable tests, then the repository-required final suite and native journeys before integration. Capture screenshots in a new per-run output directory, using the current screenshot-lock fix. Copy evidence into the tracked evidence directory only after a successful run. Do not use stale screenshots as proof.

Exercise existing navigation, recording, food logging and run continuation after a genuine process restart where the environment supports it. Distinguish a real cold start from invoking main() again in the same process. Do not claim physical-device or iPhone visual verification based on emulator tests or an iOS build.

Update DESIGN.md and the progress ledger with the final design, photo provenance, tested states and exact results. After required checks pass, follow the already approved commit, push, CI and merge process. Build the unsigned iOS IPA from the exact final main commit, using the existing workflow and testing API configuration.

Report changed behavior, test results, fresh screenshot paths, final commit, CI run and the new IPA artifact. Keep real-phone checks explicitly pending where they have not run. The expected scope is Flutter presentation and bundled assets; any unexpected requirement to alter the API or stored data must first be justified by inspecting the existing implementation.

