# Leon squat prototype — technique review pending

A Blender prototype of GoHard's Leon doing a bodyweight squat, built on 19 Nov 2026 for the owner's review. It is a
**prototype**: the full-body design is a proposed interpretation of the 2D artwork, not approved brand artwork, and the
movement has **not** been reviewed by a qualified professional. The geometry checks below test the model and the
animation, not exercise technique.

## What is here

| File | What it is |
|---|---|
| `build_leon.py` | Builds everything from scratch: model, materials, rig, squat animation, studio, cameras, and the geometry checks |
| `render_leon.py` | Renders stills or an animation PNG sequence from the `.blend` |
| `export_leon.ps1` | Runs build and render, encodes the MP4s and poster, labels the review copies, verifies the files with ffprobe |
| `leon_squat_prototype.blend` | The editable project (no external files; everything is generated or packed) |
| `docs/evidence/leon-3d/` | The exported clips, poster, stills and the check report |

Rebuild everything (about 10 minutes on the development laptop):

```powershell
powershell -File design\leon-3d\export_leon.ps1 -Out C:\dev\GoHard-leon-prototype
```

Tools: Blender 4.5.16 LTS and ffmpeg 9.0.2 (gyan.dev essentials build), both portable under `C:\dev\tools`; pass
`-Blender` / `-Ffmpeg` to use other copies. Edits made by hand in the `.blend` are lost if you rebuild from the script,
so either change `build_leon.py` or keep the edited `.blend` as the new source.

## How it is built

- **Model:** metaballs converted to meshes, one piece each for the torso, legs, arms, hands, head, muzzle and mane base;
  eyes, nose, brows and ears are separate small parts; mane locks, mouth line and tail are generated tubes. Proportions
  follow `design/coach/assets/leon-full.png`, the face follows `leon-avatar.png` and the concept board.
- **Clothing:** the shirt and shorts are drawn on the body from two per-vertex fields (shirt and shorts hems), so the
  clothes can never pass through the body. Charcoal T-shirt with sleeves ending above the elbow, charcoal shorts above
  the knee, white trainers with a light-blue heel patch, as in the brief.
- **Rig (`Leon rig`):** root; hips, spine, chest, neck, head; tail; shoulders, upper arms, forearms, hands; thighs,
  shins, feet. Legs use IK to fixed `foot_ik` targets with `knee_pole` targets in front of each foot, so the feet cannot
  slide; feet copy their target's rotation so they stay flat. Arms are FK. Knees and elbows are weighted over a short
  blend; hands, head parts, shoes and tail move rigidly with their bone.
- **Animation:** 366 frames at 30 fps (12.2 s): 0.8 s standing, then three repetitions of 1.8 s down, 0.3 s at the
  bottom, 1.4 s up, 0.3 s standing. Frame 367 equals frame 1, so the loop has no jump. Hips move back before the knees
  travel far, the trunk leans forward, the arms rise forward as a counterbalance, the tail lifts. Starting angles come
  from the pilot storyboard and are placeholders: depth, stance, trunk angle, arm position and tempo are for the
  qualified reviewer to set (`BOTTOM` and `TIMING` at the top of `build_leon.py`).
- **Studio:** plain light-grey background, floor fading into it, soft key, fill and rim lights. Cameras: `Cam 3q`
  (three-quarter front, 35°, 50 mm, the main clip), `Cam side`, `Cam front`, `Cam face` (close-up for likeness checks).

## Geometry checks (`checks.json`)

Run by `build_leon.py` on every frame for the rig and on every sixth frame (plus the first bottom) for the meshes:
feet position and rotation, sole height, knee direction, elbow direction, centre of mass against the soles, part
overlaps (hands, forearms, legs, tail, mane), tail height, pelvis speed and acceleration, and the loop seam.
These are drawing checks; they are not evidence of correct technique.

## Results (19 Nov 2026)

| Export | Measured with ffprobe |
|---|---|
| `leon_bodyweight-squat_3q_720.mp4` (main clip, clean) | H.264 High, level 4.0, yuv420p, 720 × 720, 30 fps, 12.20 s, no audio stream, faststart, 1.11 MB |
| `leon_bodyweight-squat_side_720_review.mp4` (labelled) | same format, 0.86 MB |
| `leon_bodyweight-squat_3q_720.jpg` | poster: frame 1 of the main clip, 720 × 720 |

- All files decode without errors (`ffmpeg -f null`). Rendered frames 1 and 366 are identical (PSNR infinite); in the
  encoded clip the last and first frames differ only by compression (PSNR 47.4 dB).
- Checks: feet move at most 0.1 mm and never turn; soles never go below the floor; no knee bends behind the hip–ankle
  line; no elbow bends backwards; centre of mass at least 6.3 cm inside the heel edge and 19.6 cm inside the toe edge;
  no overlaps between hands, forearms, legs, tail and mane; tail at least 0.43 m above the floor; pelvis drops 0.36 m,
  peak speed 0.50 m/s, peak acceleration 1.8 m/s² (smooth eases, no jumps); loop seam vertex gap 0.
- Committed copies: `docs/evidence/leon-3d/` (main clip, side review clip, poster, labelled stills, `checks.json`).
  The full output with PNG frame sequences and the labelled three-quarter copy: `C:\dev\GoHard-leon-prototype`.

## Visual compromises (for the owner's review)

- The mane is chunky tapered locks with a streak texture, not flowing groomed hair; it is kept behind the shoulder line,
  so it is narrower than in the artwork.
- No fur, whiskers or fabric folds; surfaces are smooth.
- Hands are simple, with fingers together; the shoulder is a ball-and-socket style joint under the sleeve.
- The body proportions follow the artwork loosely; the head is large and the legs are slightly short, as in the art.
- Arms are raised forward at the bottom (a counterbalance that keeps the hips visible); ACE's setup has the hands by
  the sides. The reviewer decides.
