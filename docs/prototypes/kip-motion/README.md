# Kip motion references (2026-11-02)

Animation references made with Higgsfield to polish Kip's code-drawn rig. They are study material only: the app still draws and animates Kip in code.

## Credits

Approved budget: 52. Spent: **26** (balance 876 → 850). No retries were needed.

| Asset | Model | Settings | Credits |
|---|---|---|---:|
| pose-sheet-1.png (typing, looking up, waving, resting) | nano_banana_flash | 2k, 16:9, `kip_ref.png` reference | 2 |
| pose-sheet-2.png (stretch, side stretch, celebrate, poked) | nano_banana_flash | 2k, 16:9 | 2 |
| pose-sheet-3.png (wave keyframe breakdown) | nano_banana_flash | 2k, 16:9 | 2 |
| clip-wave.mp4 | seedance_2_0_mini | 5 s, 720p, 16:9, no audio, start image `kip_ref.png` | 5 |
| clip-stretch.mp4 | seedance_2_0_mini | same | 5 |
| clip-celebrate.mp4 | seedance_2_0_mini | same | 5 |
| clip-backtowork.mp4 | seedance_2_0_mini | same | 5 |

## What was applied to the rig

- Typing: longer arms that reach the keys; typing in bursts with pauses.
- Wave: shoulder slides toward the spine (`ShrimpPose.shoulderShift`) so the front arm waves out past the body on the far side, clear of the face.
- Stretch: upright body, both arms overhead.
- Celebrate: arms in a V, hops with hang time, body straightens in the air.
- Transitions: anticipation dip and squint, overshoot ease (`Geo.backOut`).
- Antennae trail the head and body (follow-through in `PoseBlender`).
- Tap Kip for a squishy wiggle with light haptics (`pokeable`).

Not taken from the references: the front-facing view in the clips (the rig is side-on by design).
