# Claude implementation prompt — GoHard design upgrade

You are acting as a senior mobile product designer and a senior Flutter engineer. Implement the approved GoHard redesign in my CURRENT GoHardRebuild project. Work through the implementation and verification; do not stop after an audit, a plan, a few recoloured screens, or a static prototype.

## Authority and scope

I approve the attached visual direction and authorize you to improve anything necessary within the app's UI, UX, shared components, navigation presentation, assets, accessibility, motion and supporting presentation logic. Exercise senior design judgment. You may change layouts, hierarchy, spacing, copy, component structure and implementation details when they improve the result. Explain meaningful deviations from the references in the final report.

Work in the current repository. Repository context: https://github.com/abdbabti01/GoHardRebuild.git. A previously reported Windows location was C:\dev\GoHardRebuild; discover the actual working root rather than assuming paths. Inspect this project's current code and documentation. Do not depend on, migrate from, or inspect the old GoHard project to reconstruct missing requirements. This handoff supplies the design direction.

Keep the Flutter app and its existing .NET API integration. Preserve authentication, user data, workout/nutrition persistence, resume behavior and current test/deployment configuration. Make narrowly scoped data/adapter or API fixes only when needed for a correct interface, with appropriate regression coverage. Keep the existing testing API configuration, signing setup and app identity. Never solve a visual task by replacing working services with mock data.

Read repository instructions and existing tests first. Preserve unrelated uncommitted work. Use a suitable isolated branch or checkout if necessary. Commit your changes when checks pass and the working tree allows it, and report the commit. Publishing or changing live services is outside this design task.

## Read these visual references first

- references/approved-app-layout.png: approved four-tab design.
- references/approved-themes.png: appearance selector and six colour/mode combinations.

The chosen direction is Calm Momentum, refined toward Apple TV's cinematic content presentation and Apple Wallet's tactile progress-card treatment. It uses clean native sans typography, rich meaningful workout imagery, light pearl surfaces, precise spacing and a layered training progress pass.

These images are generated design proposals, not pixel-perfect specifications, source assets, current account data, or proof of accessibility. Correct their flaws. In particular, the appearance reference leaves the System segment blue while Green is selected; make selected controls use the chosen accent consistently. Week tiles must have explicit readable week labels and dates, including the selected week. Never reproduce tiny labels or cramped reference spacing.

Rebuild the interface as native Flutter widgets. Do not flatten screenshots into UI backgrounds or extract screenshots as production photographs.

## Product structure and information

Preserve the four primary tabs: Today, Train, Eat, Me. Within Train preserve Workouts, Plan, Progress and the current user's selected subtab. Refresh every existing reachable screen, sheet, form, dialog, loading state and error state through the same design system, not only the four top-level pages. Preserve existing supported functionality. Improve confusing flows and redundant steps where evidence supports it.

Today:
- Make the current date, relevant workout and its state immediately clear.
- A cinematic workout feature shows workout name, exercise/set count, an estimate only when available, explicitly recorded-set progress and a prominent Start or Resume action appropriate to state.
- Show this week's real workout completion and a compact nutrition overview.
- Handle no plan, rest day, no workout, in-progress workout, completed workout and unavailable data with intentional layouts and useful next actions.
- Distinguish exercise prescriptions from recorded work. Do not count prefilled targets as performed sets.

Train:
- Give Workouts / Plan / Progress proper readable segmented navigation.
- Plan includes a personal training progress pass: plan name, completed-workout count / eligible planned total and a labelled progress rail. Calendar position such as Week 3 of 8 is a separate value.
- Make the block's weeks easy to inspect. Start from the approved eight-week grid, but reflow it or use accessible scrolling and an All weeks view when a real plan or large text requires it.
- Show week number, correct date range, selection and state. The selected week opens its dated schedule with named Completed, In progress, Planned, Rest or other existing supported states.
- Weeks of arbitrary length/count must work. Do not hardcode an eight-week product limit.
- Progress and history reflect recorded activity; elapsed time, rest days and skipped/unperformed sessions are not workout completion.

Eat:
- Calories and available nutrition goals are clear and legible, with labelled values and progress.
- Log food is an obvious action. Logged meals have clean grouping, useful details and totals derived from actual entries.
- Keep planned food separate from consumed food. Represent unknown nutrients as unknown rather than zero.
- Preserve search, editing, deletion, units and existing supported meal/nutrition workflows.

Me:
- Profile, real training overview, history, units, appearance and existing settings belong here.
- Use actual account information. Do not invent training history, dates, streaks, achievements, readiness or health statistics.

The numbers in the references are fixtures: 6/18 recorded sets, 2/3 weekly workouts, 8/24 block workouts, 1,400/2,200 kcal and 95/150 g protein. They are not my current data. Production values must come from the current app state and API. Fixture dates are October 11, 2026; production dates use the user's actual local timezone and plan start date. Test date/week boundaries rather than copying the picture's week into production.

## Appearance: three accents, three mode choices

Implement Me → Appearance with two independent controls:
1. Accent: Blue, Green, Pink.
2. Mode: Light, Dark, System.

All three accents work in light and dark, yielding six rendered combinations. System follows OS appearance changes without losing the chosen accent. Apply changes immediately, with a restrained transition, throughout every screen and overlay. Persist both preferences across app restarts using the project's appropriate local settings mechanism. Default fresh installs to Blue + System; do not overwrite an existing explicit supported preference unnecessarily.

Make a reusable semantic theme system using the project's existing architecture and compatible Flutter APIs: surfaces, foregrounds, accent/on-accent, muted content, dividers, selection, semantic status, input states, icon states and progress. Use ThemeData/ColorScheme and a theme extension or equivalent where suitable; avoid hardcoded per-screen colour patches.

Suggested starting tokens, not immutable values:

| Role | Light | Dark |
| --- | --- | --- |
| Page | #F6F6F4 | #101114 |
| Raised surface | #FFFFFF | #1C1F24 |
| Primary text | #121417 | #F3F4F6 |
| Secondary text | #555B63 | #ADB3BC |
| Blue accent | #0068D9 | #77B6FF |
| Green accent | #147644 | #6BD39C |
| Pink accent | #B83275 | #F58CB9 |
| Text on filled accent | #FFFFFF | #101114 |

Refine these tokens based on actual rendered contrast and visual balance. Dark-card backgrounds should be deeper accent shades; do not use the bright dark-mode control colour across huge surfaces. Keep semantic success, warning and error distinct from the selected decorative accent. Pair status colours with text/symbols.

## Brightness, readability and accessibility are priorities

Interpret brightness as visual comfort and readable luminance at different device brightness settings. Do not programmatically change the phone's brightness or introduce a brightness slider.

Light mode should feel calm rather than dazzling: pearl backgrounds, thoughtful whitespace, bounded saturation and subtle surfaces. Dark mode needs purpose-designed graphite layers, restrained highlights and readable muted text; do not simply invert light mode or make everything pure black. Avoid large luminous neon surfaces, halos and abrupt white flashes during startup, transitions, sheets or theme switching. Restore saved appearance early and align launch surfaces, native system bars and modal barriers as far as the platform permits.

Measure actual foreground/background pairs. Target at least 4.5:1 for ordinary readable text; use the applicable 3:1 exception only for genuinely qualifying large text. Essential control boundaries and graphics need appropriate non-text contrast, generally 3:1 against adjacent colours. Validate selected, unselected, pressed, focused, disabled and error states, as applicable; inspect real photo overlays and gradients rather than relying on seed-token calculations.

Use a minimum 48-logical-pixel touch target where practical across platforms. Support large text without disabling text scaling, clipping important labels or making weekly views unusable. Provide screen-reader names, states and meaningful progress announcements. Selection and completion must remain understandable in grayscale. Respect Reduce Motion and available reduced-transparency/increased-contrast signals, with readable solid-surface fallbacks.

Where a physical device is available, inspect comfort/readability at low, medium and high user-set brightness in normal and dim surroundings. Screenshots can support layout review but cannot verify display-brightness comfort; record that check as pending when hardware is unavailable.

## Make it look deliberately designed

Use current Apple design principles as inspiration, not copied branding or a generic template. Research current primary documentation and relevant real product references if useful. Use available design skills, asset tools, documentation tools, screenshots, emulators and other appropriate capabilities. Choose tools because they help, not to satisfy a tool-use checklist.

Create a coherent type scale, spacing rhythm, icon family, corner-radius hierarchy and elevation system. Prefer native-feeling sans typography and properly licensed assets. Use spacing, alignment and simple separators before adding more containers. Avoid card-inside-card layouts, gradients everywhere, random glass, oversized empty headers, vague motivational slogans, filler badges and unrelated metrics.

The fitness pass is an elegant landscape training component, not a payment card: no card number, chip, balance, currency or bank logo. Subtle layered edges and controlled depth are enough. Workout imagery must have purpose, natural anatomy and appropriate crops, with readable overlays and excellent fallbacks. Prefer suitable existing or licensed editorial photography; if generation is useful, scrutinize the result and reject obvious synthetic details. Do not download random images whose usage rights are unclear.

Extend the same design care to workout recording, food entry, keyboard behavior, confirmations and recovery flows. Keep frequent actions obvious and state changes understandable. Every visible actionable control must perform its intended operation.

## Motion and performance

Use smooth, restrained, interruptible interactions: native-feeling page transitions, interactive back navigation where appropriate, well-behaved sheets, week selection, pressed feedback and progress changes driven by real state. Respect platform conventions and safe areas.

Starting motion ranges can be around160–240 ms for small changes and250–350 ms for larger presentations, adjusted by judgment and native defaults. Avoid arbitrary delays, elaborate choreography and fake progress animations. Reduce Motion should remove unnecessary spatial movement. Use haptics sparingly.

Optimize image decode sizes and caching, lazy lists and rebuild scope. Limit expensive blur and unnecessary layers. Theme switching must not reset tab selection, form drafts, workout timers or in-progress sessions. Profile actual interactions; an animation existing in code is not evidence that the app is smooth.

My target phone is an iPhone 13. I use Windows and do not own a Mac, so preserve the current GitHub Actions iOS build/signing path. Use available Android/emulator and CI checks without treating them as proof of physical-iPhone performance. Run profile-mode physical-device measurements when possible; otherwise finish independent work and document the remaining device step exactly.

## Implementation and verification workflow

1. Inspect the current repo, supported flows, state management, theme code, assets, SDK versions, tests and build workflows. Run a relevant baseline. Capture actual before screenshots when the app can run.
2. Write a concise implementation plan and design-token proposal, then proceed without asking me to approve routine design or coding decisions.
3. Build shared themes and appearance persistence, then complete a representative Today/Plan vertical slice in light and dark. Run it and refine from screenshots before spreading components throughout the app.
4. Finish all reachable UI with the coherent design system. Keep existing data contracts and functional behavior working, fixing genuine UX/presentation defects along the way.
5. Verify all six accent/mode combinations, OS mode changes and persistence after restart. Cover small/large text, keyboard/safe areas, long content and empty/loading/error/offline states supported by the app.
6. Add meaningful widget/integration coverage for theme selection, persisted mode/accent, OS appearance behavior, accessible important controls and key progress-state logic. Keep or update existing functional regression tests. Do not write snapshot tests merely to mirror every implementation detail.
7. Run formatting, Flutter analysis, relevant tests and Android build with the installed compatible toolchain. Use current iOS CI/build capability where available. Run API checks if API code changed.
8. Exercise sign-in, plan navigation, start/resume/record/finish workout, log/edit food, units and profile/settings. Verify changing themes during a workout or draft does not lose state or duplicate saves.
9. Capture actual after screenshots of Today, Train/Plan, Eat, Me and Appearance, with a useful comparison of all six themes. Inspect the output, fix inconsistencies, overflow and unreadable elements, and rerun affected checks. Keep legitimate test fixtures separate from runtime account data.
10. Profile scrolling, navigation, week changes and sheets in an appropriate build when hardware permits. Report measured evidence and pending hardware checks honestly.
11. Finish with a concise report: changes, meaningful reference deviations, screenshots, exact commands/results, commit, known issues and exact Windows/iPhone testing steps based on this repo.

A blocked browser or missing iOS account should not stop unrelated implementation and verification. Describe the precise blocker; use another appropriate testing surface where possible. Never call native visual QA or device performance verified unless it actually ran.

Completion means the new UI is implemented in the working app, the six themes are consistent, brightness/readability have been assessed as far as the environment permits, meaningful regressions pass, and remaining external checks are explicit. Do not claim a subjective "senior designer" score or say "100% production ready" without evidence.

## Primary guidance to consult as needed

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Apple TV app direction: https://www.apple.com/apple-tv-app/
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter platform adaptations: https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations
- Flutter performance profiling: https://docs.flutter.dev/perf/ui-performance
- Text contrast: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- Non-text contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html

Start now: inspect the current project and both references, identify the highest-impact changes, then implement and verify the redesign end to end.

