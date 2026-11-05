# Scheduler And Rhythm

What this is. This page describes how time works: frames, rhythms and the scheduler.

## Rhythms

Each Thing declares one rhythm: when it acts. It's checked when the Thing loads
(MVP-SCH-4).

- Event
- Periodic
- Continuous
- Manual
- Sequence

"Rhythm" replaced the older name "tempo type". Tempo means speed, and the music tools
use it in that sense. The code still calls rhythms `TempoKind`, in
`src/cosmos/tempo/`, until a later rename.

## Scheduler Rules

- **Replayable:** the same state plus the same waves always gives the same frame
  result.
- **Bounded:** no Thing can use unlimited time in a frame. Things yield cooperatively.
- **Isolated:** a failing Thing doesn't affect the others. A Thing that keeps failing
  is suspended with a structured error.

## Frames

- A frame is complete when one round of changes to every Thing is complete.
- Cosmos time is counted in frames, never clock time. The code's frame counter is
  `epoch`.
- A wave sent during a frame is perceived in the next frame, so the order Things run
  in never changes what they perceive.
- Each frame becomes one row in the history: the frame, and its changes.

## How the Daemon Runs Frames

`cosmos start --mode` chooses how frames run:

- `step`: start paused. Each `cosmos step` runs exactly one frame.
- `continuous`: run frames back to back.
- `periodic`: run frames at the configured frame rate.

The `--mode` flag and frames driven by the daemon arrive in Phase 2. Frames are not
the audio clock: an audio kernel keeps its own sample clock, and a bridge maps
between the two.

A simple metaphor is a film reel: each frame is fixed once exposed, and playback order
matters.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
