# Brief: Leon, full-body 3D character and one squat animation (pilot)

**Client:** GoHard, a fitness app for iPhone and Android. **Status:** request for a quote; nothing is commissioned until agreed
in writing.

## What we need

Leon is GoHard's guide character: an athletic, friendly anthropomorphic lion. Today he exists only as 2D renders, with
no model, turnaround or rig. We want:

1. **A full-body 3D Leon**, modelled, groomed or fur-shaded, textured and rigged, faithful to the attached artwork.
2. **One animation:** a bodyweight squat, three repetitions, rendered as a short muted looping clip.

Later we may add Leona (his lioness counterpart) on the **same skeleton**, and more exercises. Please build with that in mind,
but quote only the work above.

## Attachments

- `leon-full.png`: the full-body reference (ignore the background glow).
- `leon-avatar.png`: the face reference.
- `storyboard.svg`: squat timing and camera, drawn with a stick mannequin. It is a reference, not the target look.

## Character

- Keep him recognisable:
  - Face: amber-brown eyes, heavy dark brows, dark-brown nose, cream muzzle and chin.
  - Large dark-brown mane, tan fur, rounded ears, tail with a dark tuft.
  - Calm, confident expression; athletic but not exaggerated.
- He demonstrates exercises, so the **shoulders, hips, knees, ankles and feet must stay readable**:
  - Clothing: a plain charcoal fitted T-shirt with no logo or monogram, charcoal training shorts above the knee (or fitted tights),
    and white trainers with flat soles and a visible heel. This differs from the joggers in the artwork; please confirm
    with us before modelling.
  - Mane: sits behind the shoulder line.
  - Tail: hangs behind, away from the camera, and never crosses a leg.
- Human-plausible limb lengths and joint positions; the stylised head stays.
- A neutral, attentive face while exercising (no talking or celebrating).

## Rig

- Humanoid skeleton with conventional bone names; tail chain; ears, jaw and eyelids.
- IK legs with heel, ball and toe pivots and foot locking, plus knee pole targets. IK/FK arms.
- Clean deformation at deep knee and hip flexion with the trunk leaning forward (correctives at knees, hip crease, glutes,
  shoulders). No intersections of mane, arms, thighs, belly, clothing or tail.
- Built so a second character (Leona) can share the skeleton and retarget the animation.

## Animation: bodyweight squat

- Start standing still, then do three controlled reps and end in the exact starting pose, so the loop has no jump.
  About 12 s in total (the storyboard has the timing).
- In each rep:
  - The hips go back first, then down, with hips and knees bending together.
  - Feet stay flat and fixed; the knees travel over the second toe.
  - Pause briefly at the bottom.
  - On the way up, hips and chest rise together.
- **Depth, stance, arm position and tempo will be confirmed by our technique reviewer.** Please key them so they are easy to adjust,
  and expect one revision round for technique.
- Hand-keyed or properly licensed motion only. **No generative or AI video and no AI motion.**
- No foot sliding, floating, joint pops, jitter or intersections. Fur and mane stay stable: no flicker or crawling strands.

## Camera, lighting, background

- A locked camera, three-quarter front (about 35° off the front), with Leon facing screen right.
  - Use a 50 mm-equivalent lens at hip-to-chest height, tilted down 5–10°.
  - The whole body (ears to shoes, hands and tail tuft) stays in frame with at least 5% margin in every pose. No camera moves.
- Soft key light from front-left above, a fill, and a gentle warm rim.
- A plain light-neutral background and floor (about `#E9EBE8`) with soft contact shadows. No props, text, logos or watermarks.
- Little or no motion blur.

## Deliverables

- `leon.blend` (mesh, materials, groom, rig) and `bodyweight-squat.blend` (action, camera, lights), with FBX or glTF exports.
- A master PNG sequence at 1440 × 1440, 30 fps.
- The delivery clip: H.264 MP4, High profile level ≤ 4.0, yuv420p, **720 × 720, 30 fps constant**, **no audio track**, faststart,
  metadata stripped, **≤ 2.5 MB**.
- A poster: frame 1 as a 720 × 720 JPEG.
- A turnaround render of Leon (front, three-quarter, side, back) in the exercise clothing.
- A list of any third-party assets used (base mesh, rig tools, textures, HDRIs), with each one's URL and licence. Each licence
  must allow commercial use in an app and modification.

## Rights

- GoHard receives the copyright, or an exclusive, perpetual, worldwide licence, in the model, rig, textures, groom, scene files and renders,
  including the source files, for use in the app and its marketing.
- The work must not be shared or reused elsewhere without permission.

## Review stages

1. The clothing and silhouette sketch, or a turnaround.
2. The untextured blocking animation.
3. The final render.

GoHard approves the likeness and look. A qualified coach separately approves the movement.

Please quote the price and timeline for each stage. Also state which software you use and whether you can deliver Blender files.
