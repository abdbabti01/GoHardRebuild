# Exercise demonstrator: faceless athletic mannequin (concept Option A)

Leon stays the app's coach; this mannequin only demonstrates exercises. Visual checkpoint only: no animation yet.

Source and licence: Blender Studio "Human Base Meshes" bundle v1.4.1, realistic male, CC0. Zip SHA-256
`811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`, kept at `C:\dev\tools\human-base-meshes`
(not in git). Rig: Rigify, which ships with Blender (GPL tool; the generated rig is ours). Everything else is generated.

```powershell
& C:\dev\tools\blender-4.5.16-windows-x64\blender.exe -b --factory-startup --python design\leon-3d\mannequin\build_mannequin.py -- `
  --base C:\dev\tools\human-base-meshes\human-base-meshes-bundle-v1.4.1\human_base_meshes_bundle.blend `
  --out C:\dev\GoHard-leon-prototype\mannequin\final --res 1080 --samples 192 --views front,side,3q `
  --save C:\dev\GoHard-leon-prototype\mannequin\mannequin.blend
& C:\dev\tools\blender-4.5.16-windows-x64\blender.exe -b --disable-autoexec C:\dev\GoHard-leon-prototype\mannequin\mannequin.blend `
  --python design\leon-3d\mannequin\rig_test.py -- --out C:\dev\GoHard-leon-prototype\mannequin\rigtest
```

The editable `.blend` stays in `C:\dev\GoHard-leon-prototype\mannequin` (production workspace, not git).
Renders: `docs/evidence/leon-3d/mannequin/`.
