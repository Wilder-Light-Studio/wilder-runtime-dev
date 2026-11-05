# Project Status

Quick context recovery — read this first when returning after a break.

## Purpose

Cosmos is the foundation for a set of personal music tools: a MIDI editor, a synth,
and possibly a DAW. The two goals that drive every decision:

- **Hardware feel:** low, consistent latency, with the OS kept off the hot path.
- **Integration:** solutions are built by composing Things and systems.

**Project boundary:** Cosmos and the audio projects (the real-time kernel and the
instruments) are kept in separate projects. Cosmos stays a general runtime. The audio
projects use it through its public surface, such as Things, Bridges and IPC, and
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
| **MVP re-scope** | 📅 Next | Revisit and factor MVP requirements, develop the spec, prepare a phased plan |
| **Phase XF** | ⏸ Paused | Cosmos Encryption Spectrum — waiting on the MVP re-scope |
| **Phase XE** | ⏸ Paused | Humane Offline Licensing — likely deferred for single-user use |

**Version:** `0.9.10` · **Dev line:** `0.9.9.9` · **Preview tag:** `v0.9.9.9-wip`

## Current State (2026-11-01)

### Architecture direction

- **Two layers:**
  - **Real-time audio kernel (not built yet):** small, never allocates/locks/waits,
    sample-accurate MIDI timing, runs a precompiled flat audio graph.
  - **Cosmos layer (mostly built):** Things, Waves, capability graph, persistence,
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

Snapshot from 2026-11-01 (Nim 2.0.8, Windows):

- **Overall:** 575 checks pass, 6 fail, and 5 files don't compile.
- **The gate is incomplete:** 22 test files are not wired into `nimble test`.
- **`nimble test` can't finish on a fresh clone:**
  - `doc_compliance_test` needs `.github/ND_DOCS_CHECKLIST.md`, but `.gitignore`
    excludes `.github`.
  - `coordinator_test` hangs: `start` runs the real daemon on fixed port 7700,
    which never exits.
- **Compile errors:**
  - `coordinator_ipc_test`: the `newIpcSession` signature changed.
  - `daemon_console_test`: `import threads` is invalid in Nim 2.
  - `bundle_loader_test` and `cli_parser_test`: they call names that are no longer
    declared.
- **Failures:** `cosmos_main_ipc_id_test` (2), `status_memory_test` (2),
  `console_status_test` (1).

### Known issues

- **CLI routing regression:** the 2026-04-13 daemon commit (`f71f93a`) stopped routing
  to `startapp`, `capabilities`, `concept`, `scan`, `ipc`, `notify` and `--help`.
  Their handlers still exist in `cosmos_main.nim`, but nothing calls them.
- **`cosmos stop` doesn't stop the daemon:** the daemon loop is `while true`, and the
  IPC server has no stop path.
- **Missing build and CI files:** `.gitignore` excludes `build/` and `.github`, so
  `scripts/build/*.ps1` (used by `nimble buildRuntime`) and the CI workflows are not
  in the repo.
- **Requirements stale against the daemon design:**
  - Reserved commands: `inspect`, `stop` and `list` are now real commands.
  - `console_main --config`: the requirements say it's required; the code makes it
    optional.
- **Plan contradictions:** `docs/implementation/PLAN.md` lists phases XA, XB, XC and
  XE twice with conflicting statuses, and `docs/PLAN.md` (the mirror) has drifted
  from it.
- **Version numbers disagree** across the nimble file and README (0.1.0), the
  changelog (0.9.6 / 0.9.9.9) and this file (0.9.10).
- **Home-made encryption:** `encrypted_record.nim` uses a custom XOR/SHA-256 cipher
  with a deterministic nonce. Replace it with a vetted library before relying on any
  privacy guarantee.
- **Audio design note:** `docs/enhancements/audio-nl-ring-buffer.md` allocates on the
  audio thread (`seq.add`), targets Linux-only APIs, and has no measurements yet.

## Next Tasks

1. **MVP requirements:** drafted in
   [MVP-REQUIREMENTS.md](docs/implementation/MVP-REQUIREMENTS.md). Review it and
   settle its three open decisions. Settled 2026-11-05: port from config, a no-I/O
   fast check, and `cosmos console` as the only console.
2. **Spec:** develop it from the MVP requirements, including kernel contracts and
   measurable latency targets.
3. **Phased plan:** small, verifiable phases. Make a trustworthy test gate an early
   phase.
4. **Fix the test gate** (diagnosed, not started): restore CLI routing, add a real
   daemon stop path, wire every test into `nimble test`, and make tests clone-safe.
5. **Measure this machine:** run LatencyMon, then a WASAPI-exclusive sine wave at the
   smallest stable buffer.

## Quick Commands

```
nimble verify          # Full gate: compliance + all tests
nimble test            # Run all tests
nimble compliance      # Requirements compliance check only
nimble buildRuntime    # Build release binary to bin/ (scripts/build is currently missing)
```

## Session Log

<!-- Append one line per session: date + what you did + what's next -->

- 2026-04-09: Added ND-friendly repo administration infrastructure (STATUS, CHEATSHEET, script help, VS Code tasks).
- 2026-11-01: Evaluated project state and ran the full test suite; set purpose (personal music tools, hardware-feel kernel). Next: MVP requirements → spec → phased plan.
