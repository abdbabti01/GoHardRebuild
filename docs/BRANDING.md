# Branding

The rebuild uses the original GoHard identity: the metallic white GH with a lightning bolt on a black rounded badge.
Nothing was redrawn. Every runtime image comes from one of two masters through `scripts/build-brand-assets.ps1`.

## Masters (`design/brand/`, never edited)

| File | What | Source | SHA-256 |
|---|---|---|---|
| `original-ios-app-icon-1024.png` | The original badge with its outer black padding. 1024 × 1024, opaque RGB | abdbabti01/GoHardAPP @ `357a8b3e643199e7d41de523ed32b87b6043c480`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` | `b902bbd79dd7d51fbe52d92b8779c61b39835ffd9704fdfbe79b61dffd6d2ce5` |
| `gh-mark-mono.png` | The rebuild's transparent one-colour GH mark, 1774 × 887 (the same shape as the original; compared in a widget render) | abdbabti01/GoHardRebuild @ `f4a1eb5`, `app/assets/images/evening-gh-mark.png` | `0e442606c60cf29088e7e019b6568a724f7d635db74bc2e521bc29c861b64155` |

GoHardAPP's `assets/logo.png` (SHA-256 `bb8cf8a5…68a9f`) decodes to exactly the same pixels as the iOS icon above
(decoded RGBA SHA-256 `4846ef96…77fe` for both), so only one copy is kept. Provenance was recorded in the handoff's
SOURCE_MANIFEST.json (GoHard_Original_Branding_Claude_Handoff, 21 Oct 2026).

## Exports

Regenerate everything with:

    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-brand-assets.ps1 [-Check <dir>]

`-Check` also writes the badge, launch image, icon and mark on the light and dark launch colours for a visual review
(not committed). Resizing is System.Drawing high-quality bicubic, as in `build-coach-art.ps1`; no extra dependency.

| Output | Derivation |
|---|---|
| iOS `AppIcon.appiconset` (every image its `Contents.json` lists) | The whole master, no crop. 1024 is a byte copy of the master; the others are downscales saved without an alpha channel. Debug, Profile and Release all use `AppIcon`. |
| Android `mipmap-*/ic_launcher.png` (48 dp) | The whole master, no crop. Only used below API 26 (minSdk is 26, so in practice never). |
| Android `mipmap-*/ic_launcher_foreground.png` + `mipmap-anydpi-v26/ic_launcher.xml` | Adaptive icon: the master at 72 of 108 dp (the visible viewport) on a transparent canvas, over `@color/ic_launcher_background` `#000000`. Every launcher mask shows the whole badge; nothing cuts the GH or the bolt. |
| `LaunchImage.imageset` (1×/2×/3×), Android `drawable-*/launch_badge.png`, `assets/images/gohard-badge.png` | The **badge**: a uniform crop of the master to the badge's outer frame (x 192, y 196, 640 × 612 px) with the area outside its own rounded corners (80 px radius, anti-aliased) made transparent. Inside the frame nothing changes. 112 pt/dp wide on launch screens; 192 px for the app. |
| `assets/images/evening-gh-mark.png` | The mono master cropped to its visible pixels (400, 67, 1104 × 768): a lossless crop, so a widget's height is the glyph's height. |

The outer black padding is kept on the app icons, as the original app shipped it. The adaptive Android icon therefore
shows the rounded badge inside the launcher's circle with black around it; the GH is smaller than in GoHardAPP's old
Android icon, which filled the circle. Enlarging it means cropping into the badge's frame (the circle would cut its
corners), so it was left whole.

## Where the brand appears

- **Home screen**: the app icons above. The launcher icon is the original black and metallic artwork in every accent.
- **Launch screens**
  - iOS `LaunchScreen.storyboard`: the badge, 112 × 107 pt, centred on `LaunchBackground` (`#F6F6F4`, dark `#101114`).
  - Android 12+ (`values-v31`, `values-night-v31`): the system splash shows the adaptive app icon on
    `windowSplashScreenBackground` = `@color/launch_background` (the same two colours).
  - Android 8–11 (`drawable(-v21)/launch_background.xml`): the badge centred on the same colour.
  - All of them follow the **phone's** light or dark setting, not the app's Appearance choice: the app's setting is not
    readable before Flutter starts. No animation, no added delay.
- **Sign-in and create account**: `BrandBadge` (44 dp) beside the existing serif "GoHard" wordmark, centred. The badge
  is excluded from semantics because the wordmark beside it already says "GoHard". The row follows the reading
  direction (badge on the right in Arabic); the artwork itself is never mirrored.
- **Tab headers and the full-screen notices** (update required, configuration problem): `GhMark`, the transparent
  mark tinted with the page's text colour, 19 dp high (the same glyph size as before the crop). Kept one-colour on
  purpose: it sits over light, dark and weather-backed headers, where the opaque badge would be a black tile.
- **Not branded**: Me (its build line is text only), the coach, photos and panels. The opaque badge is never tinted.

## Checks

- `test/brand_test.dart` (in CI): master checksum; every iOS catalog image at its pixel size, fully opaque, reading as
  the original (dark corners, bright GH) and not the Flutter default; 1024 equals the master; Android legacy and
  adaptive layers per density and their wiring; launch image sizes and transparency, storyboard size, Android launch
  drawables and v31 splash colours; sign-in lockup read once, directional in Arabic, not mirrored.
- Renders (`render_test.dart`, `--dart-define=GOHARD_RENDER=true`, filter `--plain-name "brand:"`, plus
  `GOHARD_RENDER_LANG=fr|ar`): sign-in, create account and update notice in light and dark, sign-in at 320 px and 2×
  text. Written to `docs/evidence/design/brand-*` and `docs/evidence/localization/{fr,ar}/design/brand-*`.
- Evidence: `docs/evidence/branding/` — `renders/before|after` (widget renders, fixture data) and `device/before|after`
  (Android emulator captures: app drawer, cold-launch screen and recording, sign-in, registration, Arabic, Today header
  in OS light and dark).

## Not verified

The iOS icon and launch screen are compiled into the unsigned IPA but not observed on an iPhone. iOS caches launch
screens; after installing over an older build, the new one may need a restart of the phone to appear.
