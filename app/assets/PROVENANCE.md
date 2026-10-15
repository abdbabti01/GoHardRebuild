# Reference asset provenance

These files were copied unchanged from the verified GoHard native source checkpoint. The native screenshots contain explicitly synthetic widget fixtures, not a new implementation or signed-in device account. Fonts were parsed successfully with fontTools and retain their original OFL license/source files. The gym hero/GH raster mark retain the original asset notes. They are permitted visual/design references; the runtime application code must be written fresh.

Update, 12 October 2026: the Calm Momentum redesign sets all type in Inter, so the Source Serif 4 files and their
license file (`OFL.txt`) were removed from the app. Inter and `Inter-OFL.txt` remain. The gym photograph is now the
workout feature on Today; the GH mark is used on the sign-in screen. The list below is the original record.

Update, 13 October 2026 (Daily Rhythm): page titles are set in DM Serif Display Regular (SIL Open Font License 1.1),
downloaded unchanged from the official Google Fonts repository,
`https://github.com/google/fonts/raw/main/ofl/dmserifdisplay/DMSerifDisplay-Regular.ttf` (sha256 8cc3643535edf039aa5d95440a8542735e9197e4f4b8d9303e980fefbf5ab616), with its
licence as `DMSerifDisplay-OFL.txt`. Everything else stays in Inter.

Update, 14 October 2026 (weather scenes): no new asset files. The condition scenes (clear, cloudy, rain, snow, fog,
storm; day and night) are original native painting (`app/lib/features/weather/sky_painter.dart`) composited with the
existing `assets/scenes/scenic-dusk.webp`, which is unchanged. No third-party images were downloaded or used.

Update, 15 October 2026 (coach avatars): `assets/coach/` holds Leon and Leona, static raster artwork generated for
the GoHard Coach Handoff from the approved concept boards (no Rive/Lottie, rig or animation). The four originals, with the
handoff's `ASSETS.md` and `manifest.json` (sha256 of each), are kept unbundled in `design/coach/`. The runtime files are
derived by `scripts/build-coach-art.ps1` (alpha below 16 cleared, resized with high-quality bicubic, alpha kept):
`leon-avatar.png` and `leona-avatar.png` 192 × 192, `leon-full.png` and `leona-full.png` 202 × 420 (both cropped to the
same box). The concept boards themselves (their text, buttons and help strips) are reference only and are not shipped.
The two full-body files also carry a faint warm-white rim just outside the alpha edge (2 px, 25% opacity, softened),
added by the same script so the charcoal clothing keeps its outline on dark pages; the originals are unchanged.

[
  {
    "path": "reference/assets/fonts/FONT_SOURCES.md",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/FONT_SOURCES.md",
    "sha256": "2b7a03328c8bf04cf56c46204e523eeb84dedb296f2d3e2095cc2fa6d334fba1"
  },
  {
    "path": "reference/assets/fonts/Inter-Bold.ttf",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/Inter-Bold.ttf",
    "sha256": "adb91831676f3aa1aec7d47ea24ca7cb7765259db204e2d69bc2f868c614df3c"
  },
  {
    "path": "reference/assets/fonts/Inter-Medium.ttf",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/Inter-Medium.ttf",
    "sha256": "91ddbb9e2157215122051cf8b9bc4ef0d20ef8cd07cf00e31b4b5a751bf41876"
  },
  {
    "path": "reference/assets/fonts/Inter-OFL.txt",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/Inter-OFL.txt",
    "sha256": "5b9321a4298cfeb6b34354164a1c3afc3db114569984c502b9b35d988fd58c57"
  },
  {
    "path": "reference/assets/fonts/Inter-Regular.ttf",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/Inter-Regular.ttf",
    "sha256": "e405604c3319436bc81fdc818f6f2fe6be1cda3f193a6164358797c84a41d54a"
  },
  {
    "path": "reference/assets/fonts/Inter-SemiBold.ttf",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/Inter-SemiBold.ttf",
    "sha256": "901b34fbae6715ed00d93414b5cc9bc7fc0d6d27015c72ef88f439c0028b58af"
  },
  {
    "path": "reference/assets/fonts/OFL.txt",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/OFL.txt",
    "sha256": "c21d7293d87b6d7ab1d0229a2f55b77f33a7613a6a4e66f6693d68d7d8d09464"
  },
  {
    "path": "reference/assets/fonts/SourceSerif4-Medium.ttf",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/SourceSerif4-Medium.ttf",
    "sha256": "322e66494fdbc931b59b5701de5cd00c038a30608ae1114a1d05e231a99abe59"
  },
  {
    "path": "reference/assets/fonts/SourceSerif4-Regular.ttf",
    "source_checkpoint_path": "GoHardAPP/assets/fonts/SourceSerif4-Regular.ttf",
    "sha256": "e5a4ee6a3d87bb9024796be390c6771e2a0eb1883dae25effaf57ca01668e24b"
  },
  {
    "path": "reference/assets/images/EVENING_CLUB_ASSETS.md",
    "source_checkpoint_path": "GoHardAPP/assets/images/EVENING_CLUB_ASSETS.md",
    "sha256": "01cac8b2722cb16e8aa6931c53341876901f798ef8e1b5a154fb1cb5c17f7018"
  },
  {
    "path": "reference/assets/images/evening-gh-mark.png",
    "source_checkpoint_path": "GoHardAPP/assets/images/evening-gh-mark.png",
    "sha256": "0e442606c60cf29088e7e019b6568a724f7d635db74bc2e521bc29c861b64155"
  },
  {
    "path": "reference/assets/images/evening-gym-hero.jpg",
    "source_checkpoint_path": "GoHardAPP/assets/images/evening-gym-hero.jpg",
    "sha256": "49d96e0674904d1f518e3ba40e653893c95c267d38e48554fb1b0523ba5224d5"
  },
  {
    "path": "reference/screenshots/evening-shell-eat-dark.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-eat-dark.png",
    "sha256": "82ccc26006ccbf29a2967ecc36334a738edb0a32a8b53c7eb7734baa27e2f290"
  },
  {
    "path": "reference/screenshots/evening-shell-eat-light.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-eat-light.png",
    "sha256": "4e948ea6fac6ce6f05931ea015af0d19b643c3465a74e7c5dd39b1b6f3c4949a"
  },
  {
    "path": "reference/screenshots/evening-shell-me-dark.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-me-dark.png",
    "sha256": "cf80693e3fbe952c003178cdb6fa51eabd5c63b8c58a7143b7845e48e77265b8"
  },
  {
    "path": "reference/screenshots/evening-shell-me-light.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-me-light.png",
    "sha256": "faba068596b60ef1bc7873621005069e572131f2ee6b6d31b0a4e788e6f6a204"
  },
  {
    "path": "reference/screenshots/evening-shell-today-dark.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-today-dark.png",
    "sha256": "2f824ad6c3c2c386291e7c763de9a58d960fe2c281e2f625b0bfdc8a34d4927f"
  },
  {
    "path": "reference/screenshots/evening-shell-today-light.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-today-light.png",
    "sha256": "b3884a17e19c1d74b4b6c3db4648e288315bdd169e90ae8f44723dfc29eaf211"
  },
  {
    "path": "reference/screenshots/evening-shell-train-dark.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-train-dark.png",
    "sha256": "f61fed6893f463a584685aac7bede5155031fe46c51c39c699d6438b5353d978"
  },
  {
    "path": "reference/screenshots/evening-shell-train-light.png",
    "source_checkpoint_path": "GoHardAPP/test/screenshots/evening-shell-train-light.png",
    "sha256": "127a1459fd7ef866305c9eb4f41689b8452d1454fd59bdce00508382297a523b"
  }
]
