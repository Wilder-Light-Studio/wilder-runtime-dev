# UI Vision — Calm Instruments

> **Home:** this note belongs to the audio/UI project. It lives here, beside
> `audio-nl-ring-buffer.md`, until that project exists, then both move there.
> Nothing in it is a Cosmos runtime requirement.

## The feeling

A minimal, calm instrument, not a commercial airliner cockpit (today's DAWs).
Beautiful, spacious and quiet to use. Fast enough that the interface disappears.

**A workshop, not a mission control center.** Mission control is many screens all
demanding attention. A workshop is a place you make things, at your own pace.

| In a workshop… | …so in the UI |
|---|---|
| One workbench holds the piece you're making | One focal canvas holds the current instrument or phrase |
| Tools hang on the wall, within reach, out of the way | Controls sit at the edges and come forward when reached for |
| Rarely used tools live in a drawer | Rare actions live in a quiet panel or the command palette |
| You pick things up, turn them over, set them down | Things are objects you open, inspect and put back, not forms |
| Your work stays where you left it | Return to exactly the state you left: layout, selection, history |
| Things you've made sit on shelves | Finished Things are visible and reusable, not buried in files |
| Light falls softly through a window | The gradient field is ambient light, not decoration |
| It sounds like the work itself | Sound cues are quiet, material and meaningful |

Nothing in the workshop demands attention. You choose what to pick up next.

## Influences

| Source | What we take |
|---|---|
| **OmmWriter** | Atmosphere as part of the tool: soft full-screen gradient backgrounds with the work floating in the middle. Gentle sound feedback. Controls that fade while you work. One thing on screen. |
| **Zed** | Speed as clarity: GPU-rendered every frame, input that feels instant, no spinners. Clean type. Keyboard-first, with a command palette. |
| **iA Writer, Things 3** | Calm software done right: restraint and spacing over decoration. |
| **Teenage Engineering** (OP-1, OP-Z) | Playful, spacious, confident restraint in a music tool. |
| **Ableton Note** | A stripped-down, touch-first take on a DAW. |
| **Flash** | The display list (a tree of visual objects, which maps onto Things and scopes), timeline and tweens, and one clear visual clock. |
| **Rive** | State machines for controls: hover, drag and active states designed visually, then driven from code. |

## Principles

1. **Show only what's in use.** The constant case is a near-empty canvas with one
   focal point. Occasional controls appear on approach. Rare ones live in a quiet
   panel. This is the zone principle applied to the screen.
2. **Space is structure.** Use an 8-point grid with generous margins. Group by
   distance, not by boxes and dividers.
3. **Few colours.** A deep gradient field, one accent colour for "active," and one
   colour for warnings.
4. **Speed is calm.** Input-to-pixel response stays under one frame. Nothing ever
   blocks the interface thread, so the UI degrades and never stalls.
5. **Motion is slow and eased.** Transitions take 200–300 ms with ease-out. Nothing
   blinks or bounces, and nothing flashes more than 3 times per second.
6. **Sound is feedback.** State changes may give soft audio cues, always paired with a
   visual cue.
7. **Accessibility wins over aesthetics,** then we make the accessible version
   beautiful. Calm must never mean faint.

## Rendering

- **Stack:** pixie (Nim vector graphics) + boxy (GPU) + windy (windows and input).
  Rive's C++ runtime can be added later for designed, animated controls. Skia is the
  fallback if text quality falls short.
- **Gradients:** linear, radial and angular. Always dither them (a faint noise layer
  in the shader) to prevent banding on dark, soft gradients.
- **Crisp text:**
  - The app is per-monitor DPI-aware (set in its Windows manifest).
  - Text renders at physical pixel size and snaps to whole pixels.
- **Type:** one family, two weights, tabular numbers for values. Candidates: Inter,
  Atkinson Hyperlegible (designed for low-vision readers), IBM Plex Sans.

## Accessibility (designed in from the start)

Wherever possible, use the operating system's own settings rather than adding our own
(stare decisis): the user has already set them, and they work across every app.

**Vision**

- **High contrast:** follow Windows contrast themes. Detect them and use the system
  colours. In high-contrast mode, gradients flatten to solid colours and every control
  gets a clear border.
- **Contrast:** text is at least 4.5:1 everywhere, including over gradients. Darken
  the gradient behind text rather than fading the text.
- **Size:** follow Windows display scaling and the "Make text bigger" setting. Layouts
  reflow; they don't clip.
- **Colour is never the only signal.** Every state also has a shape, position or
  label, so the UI is colour-blind-safe.
- **Screen readers:** custom-drawn interfaces are invisible to screen readers by
  default. We expose the control tree through Windows UI Automation, so Narrator and
  NVDA can read and operate everything. This is significant work and is planned from
  the first screen, not added later.

**Motor**

- **Everything works from the keyboard.** The focus order is logical, and the focus
  ring is soft but always visible.
- **No chords or held keys** are required for any action (the motion principle).
- **Large targets** you can hit without precision.
- **No time limits,** and no actions that need fast double-clicks.

**Hearing**

- Every audio cue has a visual equivalent. Meters and indicators show what's heard.

**Motion and seizures**

- Follow Windows' "Show animations" setting. When it's off, transitions become instant
  or simple fades.
- No flashing above 3 times per second.

**Cognition and focus (ADHD)**

- Everything can be undone. History is visible.
- State is visible rather than remembered: no hidden modes.
- Controls stay in the same place. Only one thing asks for attention at a time.
- Errors say what happened and what to do next, in plain words.

## Test it

- Check contrast ratios automatically on every theme, including high contrast.
- Run each screen with Narrator, keyboard only, at 200% scaling, and with animations
  off.
- "Feels right" is judged by daily use over a living-with period, not by a single
  review.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
