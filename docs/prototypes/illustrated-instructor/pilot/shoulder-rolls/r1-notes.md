# Shoulder rolls: pilot R1 notes

Date: 2026-11-02. The owner approved 40 credits in the project thread at 20:02 UTC.

## Credits

| | Credits |
|---|---:|
| Balance before | 1000 (Plus, workspace "Private") |
| Seedance 2.0 Mini, quote / charged | 8 / 8 |
| Kling 3.0 std, quote / charged | 12 / 12, refunded 12 (visible in transactions) |
| Seedance 2.0 Fast, quote / charged | 20 / 20 |
| **Total spent** | **28** |
| Balance after | 972 |

Uploading the reference cost 0 credits. Media ID: `ddacd00b-e416-42ee-a15a-59c4ab80d849`.

## Jobs

All three used the same prompt (shoulder-rolls in `pilot-requests.json`) and the same settings: 8 s, 1:1, no audio, count 1. The reference image was both `start_image` and `end_image`. They ran one at a time.

| Model | Job ID | Result |
|---|---|---|
| `seedance_2_0_mini` 720p | `3ebfeb66-b11b-455c-9017-3a159161deb7` | completed → `r1-mini.mp4` |
| `kling3_0` std, sound off | `185b9c6c-61c8-48e3-89a9-0131694fabad` | **failed** after about 6 s, no reason returned. Refunded. Not retried. |
| `seedance_2_0` fast 720p | `2b0eadec-1b65-4617-9e35-350c126252d7` | completed → `r1-seedance-fast.mp4` |

Both clips are 960×960, 24 fps, 193 frames, 8.04 s. That's larger than the "720p" label, but the cost didn't change.

## End frame support

All three models accept `end_image` (from `higgsfield model get`), and both completed jobs report `start_image` and `end_image` in their params. Kling also accepts it, but I can't tell whether the end frame caused its failure.

## Frames

- `r1-<model>-start|mid|end.png` are frames 0, 96 and 192.
- `r1-contact-sheet.png`: rows are Mini, Kling and Fast; columns are start, middle and end. The Kling row is a plain grey tile because the job failed. This ffmpeg build has no text filter, so the tiles carry no labels.
- Working views I also looked at, in the scratchpad: the whole figure at 2 fps, and the shoulders and head every 16 frames.

## Evaluation against the README checklist

SSIM measures how similar two frames are, from 0 to 1. I used it to compare frames within each clip and with the reference.

### Seedance 2.0 Mini (8 credits)

- **Does the right thing move?** Partly. Both shoulders clearly rise together around 1–2 s, stay up until about 4.5 s, then come back down. From the front, this reads as a **slow shrug**, up, hold, down. In the stills I can't see the backward phase that makes it a "roll". Arms and hands don't swing.
- **Whole body bounce:** none visible. Feet, chair and pelvis stay put. The head tilts slightly with the shoulders.
- **Identity and limbs:** same person, same clothes and chair throughout, no extra limbs. Not requested: she closes her eyes during the raised phase. It looks calm, not like an error.
- **Camera:** stable, no zoom or pan visible.
- **Loop:** start vs end SSIM 0.959. The end frame is close but not identical: posture and face differ slightly. A short crossfade would probably hide it. I need to watch it to be sure.
- **Artifacts:** none seen in the stills.

### Kling 3.0 std (12 credits, refunded)

The job failed, so there's nothing to evaluate.

### Seedance 2.0 Fast (20 credits)

- **Does the right thing move?** Very little. The shoulders rise slightly around 2 s and come back down. The range is so small that at app size it would probably read as an almost still image, which doesn't demonstrate the exercise.
- **Whole body bounce:** none. The head turns very slightly.
- **Identity, limbs and camera:** very faithful to the reference, stable.
- **Loop:** the best of the two. Start vs end SSIM 0.982, end vs reference 0.977. But that's mainly because it barely moves.
- **Artifacts:** none seen.

### Both clips

- Frames 0 and 1 are a little less alike (SSIM 0.992–0.994) than consecutive frames usually are. There may be a small jump at the start. I need to watch it.
- **What the stills can't show:** how smooth the motion is, whether there's flicker, whether the roll has a backward component in depth, and how the loop looks when played. I didn't watch the video in real time.

## Verdict

1. **Mini.** It's the only one whose shoulder movement is legible. It reads as a slow shrug more than a roll, with a slight head tilt and eyes closing. The cheapest model produced the most useful result.
2. **Fast.** Clean and loops well, but the motion is too small to demonstrate the exercise. Not good value at 2.5× the cost.
3. **Kling std.** Failed; no clip.

Neither clip fully passes the "roll" check. Mini is a reasonable base for "shrug and drop", and it's the right model to try another shoulder-roll take with. One option is a 3/4 or side view so the backward motion is visible. Doing that would be a new spending decision.
