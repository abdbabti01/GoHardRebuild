# GoHard design handoff

This package contains a complete Claude Code implementation prompt and the two approved visual references. It does not contain application source code or secrets.

1. Extract the `gohard-design-brief` folder into the root of your CURRENT GoHardRebuild repository.
2. Open Claude Code in that repository. Use the current app, not the old GoHard project.
3. Paste this message:

> Read `gohard-design-brief/CLAUDE_PROMPT.md` and inspect both images in `gohard-design-brief/references/`. The app layout and Blue/Green/Pink with Light/Dark/System are approved. Implement the full redesign in this current project. You have discretion to improve the UI and UX while preserving my data, working features and existing deployment configuration. Pay particular attention to brightness, contrast, real-device smoothness and visual consistency. Use the tools and design capabilities available to you, verify the running app, and continue through implementation and testing rather than stopping at a plan. Follow the full prompt and report evidence, screenshots and any genuinely blocked checks.

## Contents

- CLAUDE_PROMPT.md — complete scope, design direction, theme behavior, readability and verification requirements.
- references/approved-app-layout.png — approved four-tab layout direction.
- references/approved-themes.png — appearance control and all six colour/mode previews.

The references contain illustrative account/training data and minor rendering inconsistencies. The prompt explicitly instructs Claude to correct those details and use actual application data. The prompt does not require Figma, a new backend, new paid tools or a new deployment.

