# Wilder Cosmos Runtime — MVP Requirements

**Status:** Draft for review (2026-11-01).
**Full requirements:** [REQUIREMENTS.md](REQUIREMENTS.md) is kept unchanged as the
long-term reference. This file is the subset that defines the MVP. When the two
disagree, this file governs MVP work.

---

## Goal

Cosmos is a general runtime that makes building small things easy for a
Neurodivergent (ND), ADHD brain. Other projects, such as the separate audio
projects, use Cosmos through its public surface and add nothing to this repo.

**The MVP is done when:**

- A new Thing can be scaffolded, started and inspected in three commands or fewer.
- Every requirement below is proven by a test that runs in the gate.
- The gate passes from a fresh clone on Windows.

## How to read this

- Each requirement has an ID (`MVP-…`) and a trace to its source section in
  REQUIREMENTS.md.
- **Must** means it's checked in the gate. There are no "should"s in this file.
- Anything not listed here is **deferred**, not deleted. Existing code for deferred
  features stays in place but isn't part of the MVP gate. See [Deferred](#deferred).

---

## 1. Ontology

*Source: Ontology Requirements, Interrogative Manifest, Cosmos Root, Scope Semantics.*

- **MVP-ONT-1** The runtime implements exactly five primitives: Thing/World,
  Occurrence, Wave, Perception and RECORD. Everything else is a pattern.
- **MVP-ONT-2** A Thing exists with only **WHO** (identity) and **WHY** (purpose).
  A missing WHO or WHY is a structured error. Missing optional interrogatives are not
  errors.
- **MVP-ONT-3** **WANTS** and **PROVIDES** are optional. When present, they're
  validated.
- **MVP-ONT-4** Occurrences are immutable. Waves are the only way Things communicate.
  A Thing perceives a Wave only when its own filter matches.
- **MVP-ONT-5** Cosmos is the single runtime-created root Thing, with no parent. User
  Things are always its descendants.
- **MVP-ONT-6** Scope is a dot-separated path rendered as `(cosmos.a.b)`. `cd` changes
  scope only and never mutates anything.

## 2. Lifecycle

*Source: Runtime Lifecycle Requirements, Host Observability.*

- **MVP-LIFE-1** Startup runs in a fixed order: config → envelope → reconcile →
  migrate → activate prefilter → load modules → create root → scheduler → capability
  registry → user Things → frame loop.
- **MVP-LIFE-2** Startup with zero user Things succeeds (empty boot). Missing world
  files never block startup.
- **MVP-LIFE-3** A malformed user Thing is skipped with a deterministic warning and
  doesn't block startup.
- **MVP-LIFE-4** No module runs before reconciliation passes. No input is accepted
  before the prefilter is active.
- **MVP-LIFE-5** A failed step halts startup with a structured error containing
  `haltedAt`, `reason` and `recoveryGuidance`. Guidance never includes file paths,
  secrets or payload contents.
- **MVP-LIFE-6** Shutdown flushes pending transactions, writes a final snapshot, stops
  the scheduler, unloads modules and closes persistence, in that order.
- **MVP-LIFE-7** Startup, reconciliation, migration, prefilter activation and shutdown
  emit structured host events with stable kinds. Logs never contain raw payloads,
  keys or secrets.

## 3. Persistence

*Source: Updated Storage and Persistence Requirements.*

- **MVP-PER-1** Three layers: primary state, an append-only transaction log, and
  signed snapshots, in the fixed `state/` layout.
- **MVP-PER-2** Every persisted record carries `schemaVersion`, `epoch`, `checksum`,
  `origin`, `txId` and `timestamp`. Checksums are verified on every read.
- **MVP-PER-3** State is rebuilt deterministically from any two layers, or from one
  layer plus the transaction log.
- **MVP-PER-4** File writes go to a temporary file, then an atomic replace. A crash
  never leaves a partial file.
- **MVP-PER-5** Irreconcilable divergence halts startup (see MVP-LIFE-5).
- **MVP-PER-6** Persistence keys are sanitized to `[a-zA-Z0-9_-]`, at most 128
  characters.

## 4. Validation

*Source: Validating Prefilter, Data Handling and Validation.*

- **MVP-VAL-1** All public procedures validate input at the boundary and fail fast.
- **MVP-VAL-2** The prefilter table is generated ahead of time from canonical sources,
  never copied by hand. It's activated before any input is accepted.
- **MVP-VAL-3** Only validated payloads reach Thing code or become domain Occurrences.
- **MVP-VAL-4** A prefilter failure produces a redacted, deterministic failure
  Occurrence. Invalid payload bytes are never shown.

## 5. Scheduler

*Source: Scheduler Requirements, Tempo Types.*

- **MVP-SCH-1** The same state plus the same Occurrences always produces the same
  frame result (replayable).
- **MVP-SCH-2** No Thing can use unbounded time in a frame. Things yield
  cooperatively.
- **MVP-SCH-3** A failing Thing is isolated from the others. A Thing that fails
  repeatedly is suspended with a structured error.
- **MVP-SCH-4** Each Thing declares one tempo type: Event, Periodic, Continuous,
  Manual or Sequence. It's validated at load.

## 6. Integration: Things composing Things

*Source: Phase X — DRY Wants/Provides and Capability Discovery.*

- **MVP-INT-1** A `PROVIDES` contract is declared exactly once, by the provider.
  Consumers reference it as `Thing.provide` or `Thing` and never repeat its signature.
- **MVP-INT-2** Startup builds one deterministic capability graph before any module
  runs.
- **MVP-INT-3** Missing providers, ambiguous providers and incompatible signatures
  produce structured diagnostics. A fatal issue halts startup.
- **MVP-INT-4** `cosmos capabilities` lists Things, provides, wants and resolution
  status with stable, line-oriented output.
- **MVP-INT-5** Boundary declarations are written in Nim. Other languages are
  deferred.

## 7. Configuration

*Source: Runtime Configuration Requirements (simplified).*

- **MVP-CFG-1** Config is optional. With no config, Cosmos starts on documented
  defaults.
- **MVP-CFG-2** Config is a JSON file. Override precedence, lowest to highest: file,
  then environment variables (`COSMOS_MODE`, `COSMOS_LOG_LEVEL`, `COSMOS_PORT`), then
  CLI flags.
- **MVP-CFG-3** Every value, whatever its source, passes the same validation. Invalid
  config is rejected at load time with a structured error.
- **MVP-CFG-4** Subsystems receive one loaded config record and never read config
  files themselves.

## 8. Daemon, CLI and IPC

*Source: Runtime Start Coordinator, Runtime Entrypoint CLI, Phase XC (updated for the
daemon model).*

- **MVP-CLI-1** `cosmos` with no command, `--help` and `-h` print help, exit 0, and
  start nothing.
- **MVP-CLI-2** `cosmos start` starts the daemon. It accepts `--mode
  <step|continuous|periodic>`, `--config <path>`, `--with <path>` (repeatable) and
  `--loglevel <info|warn|error|debug>`. Invalid values fail fast with usage text.
- **MVP-CLI-3** If a daemon is already running, `cosmos start` reports that and exits
  0 without starting another.
- **MVP-CLI-4** `cosmos stop` shuts the daemon down cleanly (MVP-LIFE-6) and releases
  its port.
- **MVP-CLI-5** The daemon commands `inspect`, `list`, `step`, `mode`, `add` and
  `remove` talk to the running daemon. With no daemon running, they say so clearly and
  exit non-zero, without hanging.
- **MVP-CLI-6** The existing subcommands `startapp`, `capabilities`, `concept`,
  `scan`, `ipc` and `notify` stay reachable from the CLI.
- **MVP-CLI-7** IPC is localhost-only, using JSON lines with versioned request and
  response envelopes. Request IDs are unique per invocation.
- **MVP-CLI-8** Unknown commands, unknown flags and missing values exit non-zero with
  usage text.

## 9. Console

*Source: Console Subsystem Requirements (reduced command set).*

- **MVP-CON-1** The three-layer layout (status bar, scope line, prompt line) is fixed
  in that order.
- **MVP-CON-2** MVP commands: `ls`, `cd`, `pwd`, `info`, `peek`, `state`, `world`,
  `watch`, `attach`, `detach`, `help`, `clear` and `exit`.
- **MVP-CON-3** `attach`, `help`, `clear` and `exit` work without an attached
  instance. Every other command gives a clear error when detached.
- **MVP-CON-4** `detach` cancels watches, clears session state and resets scope and
  prompt.
- **MVP-CON-5** `ls` output is one flat list, using the existing entry formats.
- **MVP-CON-6** `watch` returns to the layout on `Ctrl+C`.

## 10. Safety and stacking

*Source: Security & Input Validation, Security Requirements, and the design
principles.*

- **MVP-SAFE-1** **Degrade, never stall:** a missing file, a missing daemon or an
  unavailable port gives reduced function and a clear message, never a hang or a
  crash.
- **MVP-SAFE-2** Every failure can be recovered from the CLI alone. No step needs
  anything the failed component provides.
- **MVP-SAFE-3** CLI path arguments reject filesystem roots.
- **MVP-SAFE-4** `startapp` names are validated against
  `[a-zA-Z0-9_\- .]`, at most 64 characters, before any file is generated.
- **MVP-SAFE-5** There are no bare `except:` blocks.
- **MVP-SAFE-6** In the MVP, data is stored unencrypted (CLEAR). The runtime makes no
  privacy claim. Protecting data on disk is the operating system's job (for example,
  BitLocker).

## 11. Gate and developer experience

*Source: Testing Infrastructure, Compliance Gate, ND Documentation (simplified).*

- **MVP-GATE-1** Every test file under `tests/` runs in `nimble test`. None are left
  out.
- **MVP-GATE-2** The gate passes from a fresh clone. Tests never depend on ignored or
  untracked files.
- **MVP-GATE-3** No test can hang. Tests that start a daemon use a free port and stop
  it themselves.
- **MVP-GATE-4** A fast check (`nimble check-fast` or similar) runs the core suites in
  under one minute on the development machine.
- **MVP-GATE-5** A chapter or phase is marked complete only after its tests pass in
  the gate.
- **MVP-DX-1** `cosmos startapp` creates a working Thing scaffold that `cosmos start
  --with` loads with no edits.
- **MVP-DX-2** `STATUS.md` always shows the current state, the one active phase and
  the next tasks.
- **MVP-DX-3** Each phase's requirements fit on one page.
- **MVP-DX-4** "Neurodivergent (ND)" is spelled out on first use in every file.
  Modules keep the existing header comment convention.

## 12. Platform

*Source: Portability Requirements (narrowed).*

- **MVP-PLAT-1** The MVP targets Windows 11 with Nim 2.0.8.
- **MVP-PLAT-2** Platform-specific code stays behind the portability layer, so Linux
  can follow without restructuring.

---

## Deferred

These requirements stay in [REQUIREMENTS.md](REQUIREMENTS.md). Existing code for them
stays in place, but they're outside the MVP gate.

| Area (REQUIREMENTS.md section) | Why deferred |
|---|---|
| Encryption Spectrum (Phase XF) and Encrypted RECORD (Phase XD) | Single user, so there's no operator to protect against. Revisit with a vetted crypto library. |
| Humane Offline Licensing (Phase XE) | Not needed for personal use. |
| Installer, release matrix, promotion (Ch 19A, Phase X release) | One machine. Build from source. |
| Dynamic Semantic Scanner (Phase XB) | Not needed to build Things. The `scan` command stays reachable. |
| Protobuf transport and serializer switching | JSON only, so one less decision. |
| Cue schema validation workflow | JSON config with in-code validation is enough. |
| Multi-language provides (Python, Rust, Node, binaries) | Nim first. |
| Context inheritance, overrides and references (Phase XH, beyond scope and `cd`) | Decide once real Things need them. |
| World Ledger claims | Graph references are enough for navigation. |
| Delegation and specialists | Kept working, but not MVP-gated. |
| Memory categories and caps | Kept working, but not MVP-gated. |
| Console commands `specialists`, `delegations`, `claims`, `run`, `set`, `call` and `instances` | Not needed for the MVP workflow. |
| Multiple instances and federation | One instance. |
| Portability to BSD, macOS and Haiku, and 7–10-year-old toolchains | Windows first, then Linux. |
| Performance targets (startup under 2 s, frame rates) | Measure once the MVP is stable. |

## Open decisions

Settle these before the spec:

1. **Daemon port in tests:** use a configurable `--port` on `start` (precedent:
   `ipc serve --port`), or keep 7700 and have tests skip when it's taken.
2. **Fast check contents:** which suites count as "core" for MVP-GATE-4.
3. **Console in the daemon world:** keep `console_main` as a separate entrypoint, or
   fold it into `cosmos console`.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
