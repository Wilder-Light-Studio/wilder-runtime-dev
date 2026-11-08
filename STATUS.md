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

**Possible future projects:**
- [home-assistant-graph.md](docs/enhancements/home-assistant-graph.md): a graph-based
  wrapper for Home Assistant devices and automations.

## Current Focus

| Phase | Status | Summary |
|-------|--------|---------|
| **MVP re-scope** | 🔄 Active | MVP docs drafted; Phase 1 done (gate passes from a fresh clone). Phase 2's design questions answered. Next: the Phase 2 steps in the plan, then building Phase 2 |
| **Phase XF** | ⏸ Paused | Cosmos Encryption Spectrum — waiting on the MVP re-scope |
| **Phase XE** | ⏸ Paused | Humane Offline Licensing — likely deferred for single-user use |

**Version:** `0.9.10` · **Dev line:** `0.9.9.9` · **Preview tag:** `v0.9.9.9-wip`

## Current State (updated 2026-11-08)

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

Snapshot from 2026-11-05, results reconfirmed 2026-11-08 (Nim 2.0.8, Windows). Per-file results and every
requirement's status are in
[MVP-COMPLIANCE-MATRIX.md](docs/implementation/MVP-COMPLIANCE-MATRIX.md).

- **`nimble test` passes:** it finds all 52 test files itself and runs each with a
  90-second limit. 48 pass. 4 are known failures, listed with reasons in
  `tests/KNOWN_FAILURES.txt`, and all four are fixed by Phase 2.
- **The gate runs in parallel:** files are built and run up to one per processor at a
  time, with daemon tests taking turns. The full gate takes 96 s (was about 210 s;
  90 s of it is `coordinator_test` waiting out its limit until Phase 2), and
  `nimble checkFast` takes 22 s (was about 210 s). `-Jobs 1` runs one at a time.
- **Fixed on 2026-11-05:** five compile errors; two real bugs they had hidden (the
  bundle loader looked in the wrong folder, and status invariants were checked then
  ignored); a test expecting the old "config required" rule; the missing ND
  checklist, now at `docs/implementation/ND_DOCS_CHECKLIST.md`.
- **Fresh clone passes:** `nimble verify` (compliance, then every test) passed from a
  fresh clone on 2026-11-05. `nimble compliance` now checks the MVP docs and the
  header comment convention, and every MVP requirement has exactly one matrix row.
  It no longer reads `.github` or archived files. Seven files that had missed the
  header convention were brought into line (comments only).

### Known issues

- **CLI routing regression:** the 2026-04-13 daemon commit (`f71f93a`) stopped routing
  to `startapp`, `capabilities`, `concept`, `scan`, `ipc`, `notify` and `--help`.
  Their handlers still exist in `cosmos_main.nim`, but nothing calls them.
- **`cosmos stop` doesn't stop the daemon:** the daemon loop is `while true`, and the
  IPC server has no stop path.
- **Missing build and CI files:** `scripts/build/*.ps1` and the `.github` CI workflows
  exist nowhere, neither on disk nor in history. `buildRuntime` now calls `nim`
  directly and `.gitignore` anchors `/build/`, and `nimble compliance` no longer
  needs them. `cleanExe` and the release tasks still point at missing or archived
  scripts.
- **The daemon's IPC side isn't connected to the runtime:** it keeps its own `things`
  list and `tick` counter, `start` ignores flags and config, and console sessions
  don't stay attached. See MVP-SPECIFICATION §3–§5.
- **Most daemon methods return "method not found"** (found 2026-11-05):
  `handleRequest` in `coordinator_ipc.nim` lowercases the method name before looking
  it up, but the names it looks for have capitals. So `addThing`, `removeThing`,
  `listThings`, `addWatch`, `removeWatch`, `listWatch` and `setMode` can never match,
  and `ping` and `stop` aren't handled at all. Only `step`, `inspect`, `pause`,
  `resume`, `snapshot`, `attach` and `subscribe` work. Fixed by Phase 2.
- **The data firewall isn't connected** (found 2026-11-08): the prefilter's checker is
  built and tested, but nothing in the running program calls it. Its table holds one
  entry (`runtime.Ping`), no generator exists, and startup discards the table after
  checking it. The design is in MVP-SPECIFICATION §4D. Phase 2 connects commands, and
  Phase 3 connects Things and waves.
- **Version numbers disagree** across the nimble file (0.1.0), the changelog
  (0.9.6 / 0.9.9.9) and this file (0.9.10). The README no longer shows one.
- **Home-made encryption:** `encrypted_record.nim` uses a custom XOR/SHA-256 cipher
  with a deterministic nonce. Replace it with a vetted library before relying on any
  privacy guarantee.
- **Audio design note:** `docs/enhancements/audio-nl-ring-buffer.md` allocates on the
  audio thread (`seq.add`), targets Linux-only APIs, and has no measurements yet.

## Next Tasks

The MVP docs (requirements, spec, matrix) were drafted on 2026-11-05, and the
decisions known then were settled, including full AI parity (CLI and MCP) and the
foreground daemon. A close read on 2026-11-08 found 16 questions they didn't answer. The 8 that Phase 2
needs were decided the same day, and the 8 that Phase 3 needs are still open.
The session log has the details.

1. **Write the Phase 2 steps** in [MVP-PLAN.md](docs/implementation/MVP-PLAN.md).
2. **Start Phase 2:** daemon, CLI and AI access (spec §3–§6, §4A).
3. **Before Phase 3:** answer the 8 questions in
   [Still undecided](docs/implementation/MVP-PLAIN-LANGUAGE.md#still-undecided).
4. **Audio project:** decide whether to use an existing engine (Faust or the
   SuperCollider server) instead of writing a kernel from scratch (suggested
   2026-11-05). Then run LatencyMon and a WASAPI-exclusive sine test at the smallest
   stable buffer. Those numbers become the latency targets.

## Quick Commands

```
nimble verify          # Full gate: compliance + all tests
nimble test            # Run every test file, each with a 90 s limit
nimble checkFast       # Same, minus daemon tests (about 20 s)
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
- 2026-11-05 (late): Wrote spec §4C, the how for the ontology (tree with `cosmos.concepts`, WHY, waves, delivery in the next frame, history rows, scope by construction, no inheritance). Recorded exact-name senses and next-frame delivery in the requirements. Next: decide C1, then the phased plan.
- 2026-11-05 (late): Revised C1: Phases 1 to 3 are committed (Cosmos is for building anything, so Concepts, waves and wires can't wait on audio). Phase 4 waits until a project needs it. Next: confirm AI parity and the foreground daemon, then the phased plan.
- 2026-11-05 (late): Confirmed full AI parity (CLI and MCP in the MVP) and the foreground daemon. MVP docs complete. Next: finish Phase 1, then the phased plan.
- 2026-11-05 (late): Finished Phase 1. `nimble compliance` now checks the MVP docs (one matrix row per requirement) instead of `.github` and archived files; added missing header and Flow comments to seven files; `nimble verify` passed from a fresh clone (46 pass, 4 known). Next: the phased plan, then Phase 2.
- 2026-11-05 (late): Updated all docs to the MVP: rewrote the README, cheatsheet, docs index, getting-started guides, concept pages and glossary; added MVP status notes to the API and runtime pages; removed `.github` and archived-matrix references from the development guidelines; added a CHANGELOG entry. Renamed tempo to rhythm in the ontology (MVP-SCH-4; code rename later). Found that the daemon lowercases method names, so most CLI commands return "method not found". Measured the gate: about 3.5 min (111 s building, 90 s in coordinator_test). Next: decide on test fixes and speed-ups, then the phased plan.
- 2026-11-05 (late): Made the test gate parallel: builds and runs up to one file per processor, daemon tests (imports of net, osproc or cosmos_main) take turns, results print as they finish, `-Jobs 1` restores one at a time. Full gate 96 s (was about 210 s); `checkFast` 22 s (was about 210 s), so MVP-GATE-4 is now Passing. `cosmos_main` added to the fast-check rule. Next: fix the known failures as the start of Phase 2.
- 2026-11-08: Added a plain-language guide to the MVP requirements and spec; made the glossary the one word list. A close read found 15 open design questions, listed in the guide. Checked every current doc against the code and tests, and corrected what had gone stale. Decided the 8 questions Phase 2 needs: calls use one-time wires with ticket numbers and say when they're waiting; `cosmos history` and `cosmos logs`; every action gets a command; commands that need no daemon join the method table; `inspect` retired for `describe`. Started MVP-PLAN.md with a reference deployment (Linux and FreeBSD first; not built). Added the Home Assistant wrapper as a possible future project. Found the data firewall isn't connected, corrected the matrix (MVP-VAL-2 to 4) and wrote the design as spec §4D. Set the bullet-proof standard (MVP-VAL-6) after an audit found 14 defects. Added MVP-REASONING.md. Fixed all 14 prefilter defects with attack tests and a randomized test. Next: decide the console design, write the rest of the Phase 2 steps, then build Phase 2.
