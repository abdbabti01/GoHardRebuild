# Exercise demonstrator: athletic mannequin (concept Option A)

Leon stays the app's coach; this mannequin only demonstrates exercises. Appearance approved 20 Nov 2026 (`--head face`,
the default; the earlier faceless head is `--head egg`).

Source and licence: Blender Studio "Human Base Meshes" bundle v1.4.1, realistic male, CC0. Zip SHA-256
`811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`, kept at `C:\dev\tools\human-base-meshes`
(not in git). Rig: Rigify, which ships with Blender (GPL tool; the generated rig is ours). Everything else is generated.

```powershell
$B = 'C:\dev\tools\blender-4.5.16-windows-x64\blender.exe'; $W = 'C:\dev\GoHard-leon-prototype\mannequin'
& $B -b --factory-startup --python design\leon-3d\mannequin\build_mannequin.py -- `
  --base C:\dev\tools\human-base-meshes\human-base-meshes-bundle-v1.4.1\human_base_meshes_bundle.blend `
  --out $W\face_final --res 1080 --samples 192 --views face,3q --save $W\mannequin_face.blend
& $B -b --disable-autoexec $W\mannequin_face.blend --python design\leon-3d\mannequin\rig_test.py -- --out $W\rigtest
# squat pilot: keys + checks, then frames (3q ~1 h, side ~20 min on the CPU), then encoding
& $B -b --disable-autoexec $W\mannequin_face.blend --python design\leon-3d\mannequin\animate_squat.py -- `
  --out $W\squat --check 1 --save $W\mannequin_squat.blend
& $B -b --disable-autoexec $W\mannequin_squat.blend --python design\leon-3d\mannequin\animate_squat.py -- --out $W\squat --check 0 --render 3q --res 720 --samples 48
& $B -b --disable-autoexec $W\mannequin_squat.blend --python design\leon-3d\mannequin\animate_squat.py -- --out $W\squat --check 0 --render side --res 480 --samples 24
powershell -File design\leon-3d\mannequin\export_squat.ps1 -Squat $W\squat
```

The editable `.blend` files and frames stay in `C:\dev\GoHard-leon-prototype\mannequin` (production workspace, not git).

## Media record

| Media | Exercise ID | Version | Status |
|---|---|---|---|
| `mannequin_bodyweight-squat_3q_720.mp4` + `_poster.jpg` (720x720, 30 fps, H.264, muted, 11 s loop) | `bodyweight-squat` | mannequin v1 (20 Nov 2026) | Visual: awaiting owner review. **Technique review: pending** |
| `mannequin_bodyweight-squat_side_480_review.mp4` (movement review copy, labelled) | `bodyweight-squat` | mannequin v1 | Review only, not for the app |

Movement: three controlled reps, 0.5 s stand, then per rep 1.5 s down, 0.3 s hold, 1.2 s up, 0.5 s stand; feet a
little wider than hips, toes out 12 degrees, knees over toes, heels down, arms reaching forward. Checks printed by
`animate_squat.py`: foot sliding, heel lift, depth, rough balance, clothing pass-through, loop seam.

Pilot results (21 Nov 2026): foot sliding 0.36 mm, heel lift 0.2 mm, knee angle 82 degrees at the bottom, rough centre of
mass inside the feet on all 110 sampled frames, loop pose difference 0 and seam PSNR 49.2 dB. Clothing: no visible
pass-through; up to 3 mm at the inner-thigh hem and 7 mm in the front waistband fold at the bottom (hidden). Known
limits: the seat rounds out from behind at the bottom (not visible from the 3q camera). Review copies and contact sheets
are in `docs/evidence/leon-3d/mannequin/squat/`.
