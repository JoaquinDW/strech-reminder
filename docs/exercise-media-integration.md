# Exercise media integration

Implemented 2 November 2026. The human instructor demonstrates the movement while
Kip remains in the training header. Text, controls and mascot are native SwiftUI.
The clips are bundled resources, so playback works offline and spends no generation
credits. No additional Higgsfield jobs were submitted for this integration.

## Selected assets

Sources are preserved under `docs/prototypes/illustrated-instructor/pilot/`.

| App move | Selected source | Mirrored second side |
| --- | --- | --- |
| `shoulder-roll` | `shoulder-rolls/r1-mini.mp4` | No |
| `shrug` | `shrug/r2-mini.mp4` | No |
| `neck-tilt` | `neck-tilt/r1-mini.mp4` | Yes |
| `chest-opener` | `chest-opener/r1-mini.mp4` | No |
| `twist` | `twist/r1-mini.mp4` | Yes |
| `side-reach` | `side-reach/r2-mini.mp4` | Yes |

Runtime copies live in `Unshrimp/Resources/ExerciseVideos`. They are silent H.264,
720 × 720, 24 fps, about 8.04 seconds each, with a short final blend back to the
neutral first frame. Together they occupy 3,371,051 bytes (about 3.2 MiB). Eighteen
JPEG poses in the asset catalog provide loading/error posters and the Reduce Motion
guide. The app preserves aspect ratio and does not crop the instructor.

`nod`, `reach-up`, `cat-cow` and `march` remain in the placeholder catalog but cannot
enter automatic routines. Their issues are documented in `mini-batch-notes.md`:
unclear nod, clipped overhead fingers, missing arch, and no standing reference.
Selection means usable for this prototype, not professional approval. The accepted
shoulder-roll clip still has limited depth readability; chest opening and mirrored
anatomy also need review before release.

## Session behavior

- Three seconds to prepare before each move. Active movement time starts afterward.
- Bilateral moves split active time equally. A separate three-second transition
  shows the neutral mirrored pose before the second side begins.
- Pause preserves both time and the current video frame. Replay while paused plays
  one demonstration without consuming session time.
- Opening the end alert pauses the session. Keep going restores its prior running
  state. Backgrounding pauses until the user explicitly resumes.
- Videos loop only when visible, active, and moving. Leaving a step releases its
  player. A poster remains visible until AVPlayerLayer has a real frame.
- Reduce Motion uses Start pose / Movement / Return buttons rather than autoplay.
- Kip stays upper right, with stable per-move jokes shown briefly during movement.
  At accessibility text sizes, the comment moves into the scrollable content so it
  cannot squeeze the instructor or the fixed controls out of a compact screen.
- Two/three/five minutes mean 120/180/300 active seconds across four/six/eight steps.
  The five-minute routine labels repeated moves as another round. Preparation and
  side changes add time beyond those active seconds.

## Verification

Generated the project with XcodeGen and built with Xcode 26.6 for iOS Simulator.
The host selects Command Line Tools globally, so commands scope `DEVELOPER_DIR` to
`/Applications/Xcode.app/Contents/Developer` rather than changing the host setting.

- Nine session/resource unit tests: preparation, pauses, side transitions, skipping,
  repeated timer starts, exact durations, selected-only routines, six bundled clips,
  eighteen poses, and distinct companion comments.
- Full onboarding → home → guided break → reward → relaunch UI path.
- Playback/pause/replay, end-alert cancellation, background interruption, and all
  eight steps of a long routine, including repeated assets.
- Reduce Motion pose controls, compact iPhone SE layout at accessibility text size,
  and a timed bilateral side change.

Screenshots are under `docs/screenshots/video-integration*`. The UI launch flags are
compiled only in Debug and do not reset persistence. Exercise guidance continues to
be marked as prototype content pending professional review.
