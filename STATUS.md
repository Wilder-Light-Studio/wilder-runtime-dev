# Project Status

Quick context recovery — read this first when returning after a break.

## Purpose

Cosmos is a general way to build things in a logical manner suited to a
Neurodivergent (ND), ADHD mind: one kind of entity, uniform Concepts, visible wires,
no hidden behaviour, and a history of what happened. It's for building anything. The
first use is a set of personal music tools: a MIDI editor, a synth, and possibly a
DAW. The first planned non-music build is a port of the user's rhyming dictionary
app.

The goals that drive every decision:

- **Logical, ND-friendly building:** explicit over implicit, little to remember,
  everything inspectable by a person or an AI.
- **Integration:** solutions are built by composing Concepts into systems of Things.
- **Hardware feel (for the music tools):** low, consistent latency, with the OS kept
  off the hot path.

**Project boundary:** Cosmos and the audio projects (the real-time kernel and the
instruments) are kept in separate projects. Cosmos stays a general runtime. The audio
projects use it through its public surface, such as Things, bridges and IPC, and
nothing audio-specific lives in this repo.

**Audio/UI notes waiting for their own project** (move them when it exists):
- [ui-vision.md](docs/enhancements/ui-vision.md): calm, spacious, fast UI with
  accessibility built in, including high contrast, screen readers and keyboard-only
  use.
- [audio-nl-ring-buffer.md](docs/enhancements/audio-nl-ring-buffer.md): sketch of the
  real-time audio boundary.
- [audio-references.md](docs/enhancements/audio-references.md): inspiration sites for
  building synths, starting with Vital.

## Current Focus

| Phase | Status | Summary |
|-------|--------|---------|
| **MVP re-scope** | 🔄 Active | Requirements, spec and matrix drafted; Phase 1 gate mostly done. Next: review, then Phase 2 |
| **Phase XF** | ⏸ Paused | Cosmos Encryption Spectrum — waiting on the MVP re-scope |
| **Phase XE** | ⏸ Paused | Humane Offline Licensing — likely deferred for single-user use |

**Version:** `0.9.10` · **Dev line:** `0.9.9.9` · **Preview tag:** `v0.9.9.9-wip`

## Current State (2026-11-01)

### Architecture direction

- **Two layers:**
  - **Real-time audio kernel (not built yet):** small, never allocates/locks/waits,
    sample-accurate MIDI timing, runs a precompiled flat audio graph.
  - **Cosmos layer (mostly built):** Things, waves, capability graph, persistence,
    undo, console.
- **Patches compile into the kernel:** Things plus wires are compiled into the
  kernel's graph and swapped in at a block boundary. This follows the prefilter's
  pattern: generated ahead of time, then activated before use.
- **Kernel portability:** plain Nim, with OS calls behind a thin adapter (WASAPI/ASIO
  on Windows for now).
- **Possible later target:** a stripped OS appliance. Leaning toward stripped Linux
  with PREEMPT_RT (prior art: Elk Audio OS, Bela). FreeBSD is the alternative.
- **Appliance hardware:** a mini PC as the instrument module, such as a NUC (now made
  by ASUS) or an AMD-based mini PC. Measure timing with `cyclictest` before
  committing to a model.

### Test health

Snapshot from 2026-11-05 (Nim 2.0.8, Windows). Per-file results and every
requirement's status are in
[MVP-COMPLIANCE-MATRIX.md](docs/implementation/MVP-COMPLIANCE-MATRIX.md).

- **`nimble test` passes:** it finds all 50 test files itself and runs each with a
  90-second limit. 46 pass. 4 are known failures, listed with reasons in
  `tests/KNOWN_FAILURES.txt`, and all four are fixed by Phase 2.
- **Fixed on 2026-11-05:** five compile errors; two real bugs they had hidden (the
  bundle loader looked in the wrong folder, and status invariants were checked then
  ignored); a test expecting the old "config required" rule; the missing ND
  checklist, now at `docs/implementation/ND_DOCS_CHECKLIST.md`.
- **Not yet checked:** a run from a fresh clone, and `nimble compliance`, which
  still looks for `.github` files that don't exist.

### Known issues

- **CLI routing regression:** the 2026-04-13 daemon commit (`f71f93a`) stopped routing
  to `startapp`, `capabilities`, `concept`, `scan`, `ipc`, `notify` and `--help`.
  Their handlers still exist in `cosmos_main.nim`, but nothing calls them.
- **`cosmos stop` doesn't stop the daemon:** the daemon loop is `while true`, and the
  IPC server has no stop path.
- **Missing build and CI files:** `scripts/build/*.ps1` and the `.github` CI workflows
  exist nowhere, neither on disk nor in history. `buildRuntime` now calls `nim`
  directly and `.gitignore` anchors `/build/`. `cleanExe`, the release tasks and
  `check_requirements.ps1` still point at the missing files.
- **The daemon's IPC side isn't connected to the runtime:** it keeps its own `things`
  list and `tick` counter, `start` ignores flags and config, and console sessions
  don't stay attached. See MVP-SPECIFICATION §3–§5.
- **Version numbers disagree** across the nimble file and README (0.1.0), the
  changelog (0.9.6 / 0.9.9.9) and this file (0.9.10).
- **Home-made encryption:** `encrypted_record.nim` uses a custom XOR/SHA-256 cipher
  with a deterministic nonce. Replace it with a vetted library before relying on any
  privacy guarantee.
- **Audio design note:** `docs/enhancements/audio-nl-ring-buffer.md` allocates on the
  audio thread (`seq.add`), targets Linux-only APIs, and has no measurements yet.

## Next Tasks

1. **Close the MVP doc gaps:**
   - **Requirements:** done except naming. Settled on 2026-11-05: waves are global
     and wires are local; one manifest shape (WHO as id, VERSION, ten
     interrogatives, SENSES, IMPLEMENTATION or PARTS/WIRES); operators act through
     the Cosmos interface; "module" wording; header date.
   - **Naming:** settled on 2026-11-05 and written into MVP-ONT-9, using standard
     terms. The history is a table with one row per frame:
     - the key is the frame, in Cosmos time (virtual, never clock time);
     - the value is that frame's changes;
     - an occurrence is a whole row, what happened and when.

     Retired: wink, smile, morphos, blip, tick and "record" (as the history's
     name). Saved data is a "persisted entry".
   - **Spec:** add the how for MVP-ONT-7 to ONT-11 (Concepts and the Cosmos as
     Things, folding in modules/bundles/specialists, wires, global waves and
     senses, the frame-to-changes history, scope enforcement, removing
     `overrideDeltas`, WHY from the Concept).
   - **Phases:** place that work, and revisit constraint C1.
2. **Confirm:** full AI parity (CLI and MCP) and the foreground daemon.
3. **Write the phased plan** from spec §9.
4. **Finish Phase 1:** run the gate from a fresh clone; make `nimble compliance` stop
   depending on the missing `.github` files.
5. **Audio project:** decide whether to use an existing engine (Faust or the
   SuperCollider server) instead of writing a kernel from scratch (suggested
   2026-11-05). Then run LatencyMon and a WASAPI-exclusive sine test at the smallest
   stable buffer. Those numbers become the latency targets.

## Quick Commands

```
nimble verify          # Full gate: compliance + all tests
nimble test            # Run every test file, each with a 90 s limit
nimble checkFast       # Same, minus tests that use sockets or processes
nimble compliance      # Requirements compliance check only
nimble buildRuntime    # Build release binary to bin/
```

## Session Log

<!-- Append one line per session: date + what you did + what's next -->

- 2026-04-09: Added ND-friendly repo administration infrastructure (STATUS, CHEATSHEET, script help, VS Code tasks).
- 2026-11-01: Evaluated project state and ran the full test suite; set purpose (personal music tools, hardware-feel kernel). Next: MVP requirements → spec → phased plan.
- 2026-11-05: Settled the three MVP decisions; wrote MVP-SPECIFICATION (plausibility constraints, daemon, IPC, AI access) and MVP-COMPLIANCE-MATRIX (79 requirement rows). Ontology decided: everything that exists is a Thing, the Cosmos is the self-existent root, wires are Things, waves/occurrences/record are properties of the Cosmos, time advances in ticks with one morphos per tick. Phase 1: `nimble test` now discovers and time-limits every test; 46 pass, 4 known failures. Next: review, finish Phase 1, then Phase 2.
- 2026-11-05 (later): Archived 36 superseded, deferred or contradicted files to `archive/` (tracked, original paths kept); stopped tracking 22 build leftovers; rewrote the implementation doc index; fixed links. Recorded: Thing WHY comes from its Concept and can be overridden; a wire is a standing perception; no inheritance through containment.
- 2026-11-05 (evening): Completed MVP requirements: waves global, wires local; one manifest shape; operator scope. Settled time and history naming on standard terms (history = one row per frame, frame -> changes; occurrence = a row); retired wink, smile, morphos, blip and tick. Next: the spec's how for the ontology, then the phased plan.
- 2026-11-05 (night): A wire is a constrained wave with a set origin and destination, a property of the Cosmos and not a Thing (restores the original "waves over wires" rule). Updated MVP-ONT-8, MVP-INT-7, spec §4B.3 and the matrix. Wires are checked at load (destination must handle what the origin sends; a mismatch skips the Concept with a warning). A wire connects one Thing's output to the input of one or more Things. A wire names what it carries in the MVP-INT-1 form: `Thing` (whole output) or `Thing.provide` (one PROVIDES, like an output jack). Next: the spec's how for the ontology.
