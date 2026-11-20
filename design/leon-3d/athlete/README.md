# Charcoal athlete — still built on a free BlendKit base

Built 20 Nov 2026 for appearance review. Stills only: no animation, no app work. The squat movement still needs a
qualified technique review.

## Base asset (not in git)

"Muscular Male Base Mesh with PBR Skin" by Dr toxic, BlendKit, free, **Royalty Free** licence
(commercial use and modification allowed, no attribution required; the model itself may not be resold or
redistributed, and in an app it must not be easily extractable). Downloaded through BlendKit's own download API
(asset base id `2d07e26a-cb11-456b-a493-264d3d2fb71f`, file from `assets.blendkit.com`) to
`C:\dev\tools\blendkit-assets\muscular-male\muscular_male_base_mesh.blend`
(SHA-256 `4DFE881CF43AFDFE48CE020E3A174D17C29FD16155F734F2C1705F686EEB965A`). Made in Blender 4.5.10.

Contents: one 21,797-vertex body, eyes, teeth, gums and tongue, an Auto-Rig Pro rig (350 bones, 68 deforming),
4K skin textures from a horror project. All 208 rig drivers are simple expressions, so the rig works in plain Blender
with Python auto-run off; Auto-Rig Pro is not needed to pose it.

## Rig tests (`pose_tests.py`)

```powershell
& C:\dev\tools\blender-4.5.16-windows-x64\blender.exe -b --factory-startup --disable-autoexec <asset.blend> `
  --python design\leon-3d\athlete\pose_tests.py -- --out <dir> --res 720 --engine CYCLES --samples 32 `
  --tests rest,squat,overhead,grip,rest2,squat2,overhead2,grip2
```

Results are in `docs/evidence/leon-3d/athlete/test_*.jpg`.

## Build the still (`build_athlete.py`)

```powershell
& C:\dev\tools\blender-4.5.16-windows-x64\blender.exe -b --factory-startup --disable-autoexec <asset.blend> `
  --python design\leon-3d\athlete\build_athlete.py -- --out C:\dev\GoHard-leon-prototype\athlete\final `
  --res 1080 --samples 640 --denoise 0 --views 3q --save C:\dev\GoHard-leon-prototype\athlete\athlete_still.blend
```

About three minutes on the CPU. Cycles runs on the CPU, and the denoiser is off, because this machine has almost no
free memory. Views: `3q`, `front`, `side`, `back`, `face`.

What it changes: subdivides the body once, flattens the belly and cuts abdominal lines, removes the face, ears, eyes
and mouth parts, adds a smooth faceless hood head with a blue visor (`#0062CC`), applies a charcoal-black satin
finish, and adds black shorts with a blue side stripe and black trainers with white soles and blue heel tabs.
The pose is a relaxed ready stance with loose fists. Clothing helpers come from `../v2/build_leon_v2.py`.
