# Leon: 3D character and exercise animation pilot — brief

**Client:** GoHard, a fitness app for iPhone and Android. **Stage:** request for quotes. Nothing is commissioned until we agree
in writing.

## The project

Leon is GoHard's guide character, an athletic and friendly anthropomorphic lion. He exists only as 2D images: there is no
turnaround, model or rig. We want a **reusable 3D Leon** that can demonstrate many exercises over time, starting with **one
bodyweight squat**. Leona, his lioness counterpart, may follow later on the same skeleton; she is not part of this quote.

## Attached references

| File | Use |
|---|---|
| `leon-full.png` | Full body. Ignore the background glow. He wears joggers here; the exercise version wears shorts (below). |
| `leon-avatar.png` | Face and expression. |
| `leon-approved-concept.png` | A second face and body view. Ignore the text, the app banner and the "G/H" shirt mark. |
| `storyboard.png` | Squat timing and camera, drawn with a stick mannequin. It is not the look, and its angles are placeholders. |

**Where these images came from.** The embedded Content Credentials show they were generated with ChatGPT (OpenAI `gpt-image`) on 15 October 2026.
- We have not yet confirmed which account made them, the prompts used, or whether any reference image went into them.
- Please treat them as visual references only.
- The 3D design should be your own original work: do not base it on other existing characters.

## Character requirements

- **Keep Leon recognisable:**
  - Face: amber-brown eyes, heavy dark brows, a dark-brown nose, a cream muzzle and chin.
  - Fur: a large dark-brown mane, tan fur, rounded ears, a tail with a dark tuft.
  - Manner: calm and confident, athletic but not exaggerated.
- **The movement must be easy to read.** Shoulders, elbows, hips, knees and ankles stay visible.
  - A plain charcoal fitted T-shirt with sleeves ending above the elbow, with no logo or mark.
  - **Charcoal fitted athletic shorts ending above the knee.**
  - White trainers with flat soles and a visible heel and ankle.
- **Mane** sits behind the shoulder line. **Tail** hangs behind, away from the camera, and never crosses a leg or the floor.
- The stylised head stays. Limb lengths and joint positions are human-plausible.
- A neutral, attentive expression while exercising.
- **Background:** a plain cool light grey with soft contact shadows. The frame must still read clearly when converted to greyscale.

## Milestones (please price each separately)

1. **Character design for approval.** These are design references, not a modelling blueprint. We approve them before modelling starts.
   - Front, side and back views in the exercise clothing, at the same scale and aligned on height lines (head, shoulder,
     elbow, wrist, hip, knee, ankle, sole), in a neutral A-pose.
   - One three-quarter view.
   - A face sheet: front and side.
   - Colour swatches.
   - A note of what you reinterpreted from the 2D art.
2. **Reusable model, textures and rig.**
   - Fur or fur shading that stays stable in video.
   - IK/FK legs with heel, ball and toe pivots and foot locking. IK/FK arms that can lock the hands to the floor or a bar.
   - Knee and elbow poles. Twist bones. Fingers, tail chain, ears, jaw and eyelids.
   - The rig must handle **future upper- and lower-body exercises**:
     - deep squat and lunge flexion with the trunk leaning forward;
     - arms overhead with the shoulder blades moving;
     - push-up and plank floor contact;
     - switchable grip sockets for dumbbells, a barbell or a cable handle.
   - Correctives at knees, hip crease, glutes, shoulders and elbows. No intersections.
   - A turnaround render for our approval.
3. **Bodyweight squat animation.** About three controlled repetitions, starting and ending in the same standing pose, so it loops cleanly.
   - **First, a plain movement preview:** untextured or flat-shaded, in the clip's camera plus a side view. Our qualified
     reviewer checks the technique on it before final lighting and rendering.
   - Expect one technique revision. Depth, stance, arm position and tempo are confirmed by that review, so please key them to be easy to adjust.
   - In each rep, the hips go back first, then down, with hips and knees bending together. Heels stay flat and the feet stay fixed, with the knees over the second toe. A short pause at the bottom.
     Hips and chest rise together.
   - Hand-keyed or properly licensed motion only. **No generative video or AI motion.**
   - No foot sliding, floating, joint pops, jitter or intersections.
4. **Final export and source delivery.**
   - **Clip:** H.264 MP4, High profile level ≤ 4.0, yuv420p, **720 × 720, constant 30 fps**, about 12 s.
     - **No audio track**, faststart, metadata stripped.
     - First and last frames identical.
     - Size: we aim for about 2.5 MB. If movement or fur quality visibly suffers at that size, tell us the size you need
       rather than degrading the clip.
   - **Camera:** locked three-quarter front (about 35° off the front), Leon facing screen right, 50 mm-equivalent lens, the whole
     body in frame with a margin.
   - **Poster:** frame 1 as a 720 × 720 JPEG. A 1440 × 1440 PNG master sequence.
   - **Source files:** the editable model, rig, textures, groom, animation and scene files (Blender preferred, otherwise your
     native files plus FBX or glTF).
     - Document every software version, add-on, plugin and render engine they need.

## We also need from you

- **Rights:** commercial use in the GoHard app and its promotion, perpetual and worldwide. This includes changing the model and
  having **another artist create future exercise animations** with it. Tell us whether you assign copyright or grant a licence, and any limits.
- **Third-party assets:** list any base mesh, rig tool, texture, HDRI, brush or motion library you would use, with each one's licence and
  restrictions.
- **A separate estimate for each additional exercise** using the same model and rig.
- **Your revision policy** (rounds included per milestone, and the cost of extra rounds), your **delivery schedule**, and **examples of
  similar character animation**.

## Approvals

These are four separate approvals:

1. GoHard approves **Leon's appearance**.
2. GoHard approves **animation quality**.
3. A **qualified professional** approves the **exercise technique**.
4. Our developer confirms **playback in the app**.

Please price and plan with all four in mind.
