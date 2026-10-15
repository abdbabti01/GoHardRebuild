# Leon & Leona artwork

## Approved direction

Leon is the selected athletic lion. Leona is the requested matching female lioness. Both are approachable adult fitness guides, with warm tan/cream fur, charcoal training clothes and a calm, confident expression.

The source artwork was generated for this handoff from the approved concept boards. It is static raster artwork, not a Rive/Lottie file, 3D model, sprite sheet or animation rig.

## Use these files

| File | Purpose |
| --- | --- |
| `assets/leon-avatar.png` | Compact Leon head-and-shoulders avatar |
| `assets/leona-avatar.png` | Compact Leona head-and-shoulders avatar |
| `assets/leon-full.png` | Leon full-body help/empty-state illustration |
| `assets/leona-full.png` | Leona full-body help/empty-state illustration |
| `references/leon-approved-concept.png` | Selected concept board, visual reference only |
| `references/leona-approved-concept.png` | Approved female counterpart, visual reference only |

Use portrait assets for small UI and full-body assets only where space permits. Keep the entire head/ears/mane visible; give both avatars comparable optical scale. Render with normal aspect ratio and suitable transparent padding. Do not stretch, flatten, add a white rectangle or recolour fur with the accent.

Inspect real alpha edges and appearance on the app's light and dark surfaces. Use correctly sized runtime variants through the project's normal asset pipeline. Keep originals as design sources rather than decoding a large source image repeatedly in a list.

## Important boundaries

- Build all help text, close buttons, controls and chat UI in Flutter. The concept boards' text and demonstration controls are not app assets.
- Do not use a generated garment monogram as an official logo. Prefer the plain-clothes production artwork and the real existing GoHard logo separately.
- Do not invent extra mascot directions, change the faces or give the two guides different AI capabilities.
- Blue/Green/Pink remains an independent interface accent; either guide works with every accent and Light/Dark/System.
- Use short entrance/acknowledgement transforms only if appropriate. These PNG files do not provide blinking, talking, hand articulation or a walking cycle.
- Keep motion off when required by the app preference, OS Reduce Motion, inactive route or background lifecycle.
- The two guides are selectable by anyone; do not infer a selection from gender, name or profile information.

See the complete prompt for hint frequency, dismiss behaviour, allowed contexts, accessibility, AI identity and tests.

