# Wilder Cosmos Runtime — MVP Requirements

**Status:** Draft for review (started 2026-11-01, updated 2026-11-05).
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
- An AI client can discover, inspect and operate every Thing through the same surface
  people use (see [AI access](#13-ai-access)).

## How to read this

- Each requirement has an ID (`MVP-…`) and a trace to its source section in
  REQUIREMENTS.md.
- **Must** means it's checked in the gate. There are no "should"s in this file.
- Anything not listed here is **deferred**, not deleted. Existing code for deferred
  features stays in place but isn't part of the MVP gate. See [Deferred](#deferred).

---

## 1. Ontology

*Source: SPECIFICATION §4 (§4.1 Thing / World / Scope, §4.1A Cosmos Root Contract);
REQUIREMENTS Ontology, Interrogative Manifest, Scope Semantics and Scheduler. MVP-ONT-7
to MVP-ONT-11 were decided on 2026-11-05. Where a rule changes the old docs, it's
marked **Departs**.*

**Naming.** Cosmos, Thing, Concept and World are capitalized: they're what exists.
Everything else is lowercase. That covers the properties of the Cosmos (wave, wire,
perception, occurrence, history, frame, change) and Things made from Concepts (module,
bundle, bridge). The interrogatives stay uppercase: WHO, WHY, WANTS, PROVIDES.

- **MVP-ONT-1** **One kind of entity.** What exists is a Thing. A Thing's interior is
  its World ("Thing and World are one primitive", SPECIFICATION §4.1). Waves,
  perception, occurrences and the history are properties of the Cosmos (MVP-ONT-8).
  Everything else is a pattern made from these. **Departs** from "five primitives":
  only the Thing is an entity.
- **MVP-ONT-2** A Concept exists with only **WHO** (identity) and **WHY** (purpose).
  A Thing has its own WHO. Its WHY comes from its Concept unless the Thing states its
  own, which then overrides it. A missing WHO, or a WHY missing from both a Thing and
  its Concept, is a structured error. Missing optional interrogatives are not errors.
- **MVP-ONT-3** **WANTS** and **PROVIDES** are optional. When present, they're
  validated.
- **MVP-ONT-4** Occurrences are immutable. Waves are the only way Things communicate.
  A Thing perceives a wave only through a sense it declares or a wire connected to it
  (MVP-ONT-10).
- **MVP-ONT-5** The Cosmos is the single runtime-created root Thing, with no parent
  (SPECIFICATION §4.1A). All other Things are its descendants.
- **MVP-ONT-6** Every Thing has a scope path: dot-separated, following containment,
  rendered as `(cosmos.a.b)`. `cd` changes the console's current scope only and never
  changes anything (REQUIREMENTS Scope Semantics).
- **MVP-ONT-7** **Everything that exists is a Thing.**
  - The Cosmos (the runtime, instantiated) is the self-existent root Thing. It
    contains all other Things and is made from nothing.
  - Concepts are Things that serve as templates, like blueprints. Every other Thing is
    an instance of a Concept. Concepts live together at `cosmos.concepts`, apart from
    the Things made from them.
  - Modules, bundles and bridges are Things too, not separate kinds of unit.
  - **Departs** from the separate module, bundle and specialist types
    (REQUIREMENTS Module Contract; Delegation and Specialization). Folding that code
    in is later work.
- **MVP-ONT-8** **Waves, wires, perception, occurrences and the history are properties
  of the Cosmos, not Things.**
  - A wave is a message, and **waves are global.** A wave radiates from its source
    across the whole Cosmos, and every Thing with a matching sense perceives it. A
    sense matches a wave's kind by exact name, with no patterns. A falloff model may
    come later; the old projection radius
    (`Occurrence.projectionRadius`) is its hook.
  - **A wire is a constrained wave, with a set origin and destination.** It connects
    one Thing's output to the input of one or more other Things (MVP-INT-6). Waves on
    it go only to those destinations instead of radiating, and each destination
    perceives them because it's wired there.
  - **A wire names what it carries,** the same way consumers reference a provider
    (MVP-INT-1): `Thing` carries the whole output, and `Thing.provide` carries only
    that one PROVIDES. Like an output jack on a hardware module, each PROVIDES can be
    wired on its own. This keeps the original rule that wires are "designer-level
    containment over Wave propagation" (REQUIREMENTS Ontology). An intermediary
    between two Things is a Thing in the middle, with a wire on each side.
  - **A wire is checked before any wave travels on it.** Each destination must be
    able to handle what the wire carries. A mismatch is a structured error, like any
    incompatible signature (MVP-INT-3), and the Concept that declares the wire is
    skipped with a warning (MVP-LIFE-3).
  - Perception is a Thing noticing a wave through one of its senses, or receiving one
    along a wire.
  - An occurrence is what happened in one frame: a single historic event
    (immutable, MVP-ONT-4).
  - The history is the table of every occurrence in the Cosmos (MVP-ONT-9).
- **MVP-ONT-9** **Time advances in frames.**
  - A frame is complete when one round of changes to every Thing is complete. This is
    the scheduler's frame (REQUIREMENTS Scheduler).
  - **The history is the table of everything that happened in the Cosmos, with one
    row per frame.** Each row is an **occurrence**: what happened and when.
    - The key is the **frame**: when it happened, in Cosmos time. Cosmos time is
      virtual and counted in frames, never clock time. The code's frame counter is
      `epoch`.
    - The value is the frame's **changes**: everything that happened during that
      frame.
  - A wave sent during a frame is perceived in the next frame, so the order Things
    run in within a frame never changes what they perceive (MVP-SCH-1).
  - **Departs** from the code's per-event occurrences (`emitOccurrence`): those
    become changes within their frame's occurrence.
  - Frames are not the audio clock. The audio kernel keeps its own sample clock, and
    a bridge maps between the two.
  - These are standard terms on purpose; this is the event-log pattern. The earlier
    names wink, smile, morphos and blip (COSMOS_UNINTEGRATED_TERMS.md) are retired.
    The console's `blip` and `morphos` fields are renamed later.
- **MVP-ONT-10** **Scope is what a Thing can act on.**
  - A Thing's natural scope is itself and its interior: its parts and their
    descendants. Siblings and ancestors are outside it.
  - Anything else reaches a Thing only through its senses (waves it perceives) or
    through a wire a developer has connected explicitly. Perceiving a wave lets a
    Thing know about its source, not act on it.
  - Operators (people or AI using the CLI, console or MCP) act through the Cosmos's
    own interface (MVP-AI-7). The Cosmos's natural scope is everything, so operators
    can reach any Thing, and every change passes the same gates (MVP-AI-4).
  - A scope path is independent of location. The folder a Concept is stored in can be
    anywhere ("any writable filesystem location", REQUIREMENTS Runtime Home Tree). The
    location is described by WHERE, never inferred from the folder.
- **MVP-ONT-11** **Explicit over implicit, always. Nothing is inherited through
  containment.**
  - A Thing knows only what its Concept declares, what it senses and what is wired to
    it. There's no hidden behaviour.
  - Nothing flows from a parent Thing to the Things inside it.
  - Taking declarations from its own Concept is instantiation, not inheritance.
    Anything a Thing states for itself overrides its Concept explicitly (for example,
    WHY in MVP-ONT-2).
  - **Departs** from REQUIREMENTS Context Inheritance Rules and Override Rules, and
    SPECIFICATION §4.1C–§4.1D, which are **retired**, not deferred. A reference no
    longer "inherits target context" (Reference Rules).

## 2. Lifecycle

*Source: Runtime Lifecycle Requirements, Host Observability. Here "module" means a
Thing that extends the runtime (MVP-ONT-7).*

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
- **MVP-PER-2** Every persisted entry carries `schemaVersion`, `epoch`, `checksum`,
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
- **MVP-VAL-3** Only validated payloads reach Thing code or become changes in the history.
- **MVP-VAL-4** A prefilter failure is recorded in the history as a redacted,
  deterministic failure change. Invalid payload bytes are never shown.

## 5. Scheduler

*Source: Scheduler Requirements, Tempo Types.*

- **MVP-SCH-1** The same state plus the same waves always produces the same frame
  result (replayable).
- **MVP-SCH-2** No Thing can use unbounded time in a frame. Things yield
  cooperatively.
- **MVP-SCH-3** A failing Thing is isolated from the others. A Thing that fails
  repeatedly is suspended with a structured error.
- **MVP-SCH-4** Each Thing declares one tempo type: Event, Periodic, Continuous,
  Manual or Sequence. It's validated at load.

## 6. Integration: Concepts and Things composing

*Source: REQUIREMENTS Phase X — DRY Wants/Provides and Capability Discovery,
Multi-Module Provides (Nim and External Runtimes) and Concept System; SPECIFICATION
§19A.5–§19A.7. MVP-INT-5 to MVP-INT-7 were decided on 2026-11-05. Designing
Concepts, alone or in related groups (systems, subsystems, components), and
implementing them is the developer's main activity.*

- **MVP-INT-1** A `PROVIDES` contract is declared exactly once, by the provider.
  Consumers reference it as `Thing.provide` or `Thing` and never repeat its signature.
- **MVP-INT-2** Startup builds one deterministic capability graph before any module
  runs.
- **MVP-INT-3** Missing providers, ambiguous providers and incompatible signatures
  produce structured diagnostics. A fatal issue halts startup.
- **MVP-INT-4** `cosmos capabilities` lists Things, provides, wants and resolution
  status with stable, line-oriented output.
- **MVP-INT-5** **Concepts are uniform.**
  - Every Concept is declared the same way, in one manifest that doesn't depend on
    any language. This builds on the manual Concept file (REQUIREMENTS Concept
    System) and the existing `InterrogativeManifest`.
  - The manifest holds:
    - **WHO**, the identity, which also serves as the id;
    - a **VERSION**;
    - the other interrogatives: WHAT, WHY, WHERE, WHEN, HOW, REQUIRES, WANTS,
      PROVIDES and WITH;
    - **SENSES**, the kinds of wave the Thing perceives (MVP-ONT-8);
    - either an **IMPLEMENTATION**, or **PARTS** and **WIRES** for a composite
      (MVP-INT-7).
  - The bundle manifest folds in: `id` becomes WHO, `dependencies` becomes REQUIRES,
    `capabilities` becomes PROVIDES, and `entryPoints` becomes IMPLEMENTATION.
    **Departs** from the separate bundle manifest format (`bundle_loader.nim`).
  - Code may generate the manifest, but the manifest is the declaration.
  - **Departs** from "a programmatic Concept overrides a manual one" (SPECIFICATION
    §19A.5, §19A.7). There is one form. See Retired.
- **MVP-INT-6** **Implementations talk only through input, output and error.**
  - Waves arrive on input and leave on output, and errors go to error, one JSON
    message per line. There are no other channels: no sockets, shared files or shared
    memory.
  - Implementations in any language were already the goal: Nim, Python, Rust, Node or
    binaries (REQUIREMENTS Multi-Module Provides).
  - **Departs** from binding through an "ABI registration proc" or descriptor. The
    precedent is `wrapExternalProcessThing`, whose transport is stdin/stdout.
  - **In the MVP,** implementations are written in Nim, or in C where needed through
    Nim's C interop. A Nim implementation may run inside the Cosmos for speed, but it
    exchanges exactly the same messages.
  - **Later,** implementations in other languages will run as separate processes over
    the same contract (see Deferred).
- **MVP-INT-7** **Concepts compose.**
  - A Concept can be made of other Concepts: its parts and the wires between them.
    Instantiating it creates a Thing whose World holds one Thing per part
    (SPECIFICATION §4.1), connected by its wires (MVP-ONT-8). Parts and wires are new.
  - Only a Concept with no parts needs an implementation.
  - A composite Concept declares its own WANTS and PROVIDES and wires them to its
    parts. Other Things connect to it through that interface. Every connection is an
    explicit wire (MVP-ONT-11). Anyone can still inspect inside it (MVP-AI-2).

## 7. Configuration

*Source: Runtime Configuration Requirements (simplified).*

- **MVP-CFG-1** Config is optional. With no config, Cosmos starts on documented
  defaults.
- **MVP-CFG-2** Config is a JSON file. Override precedence, lowest to highest: file,
  then environment variables (`COSMOS_MODE`, `COSMOS_LOG_LEVEL`, `COSMOS_PORT`), then
  CLI flags.
- **MVP-CFG-3** Every value, whatever its source, passes the same validation. Invalid
  config is rejected at load time with a structured error.
- **MVP-CFG-4** Subsystems receive one loaded config object and never read config
  files themselves.

## 8. Daemon, CLI and IPC

*Source: Runtime Start Coordinator, Runtime Entrypoint CLI, Phase XC (updated for the
daemon model).*

- **MVP-CLI-1** `cosmos` with no command, `--help` and `-h` print help, exit 0, and
  start nothing.
- **MVP-CLI-2** `cosmos start` starts the daemon. It accepts `--mode
  <step|continuous|periodic>`, `--config <path>`, `--with <path>` (repeatable),
  `--loglevel <info|warn|error|debug>` and `--port <N>`. Invalid values fail fast with
  usage text.
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
- **MVP-CLI-9** The daemon listens on, and every client command connects to, the port
  from the loaded config (MVP-CFG-2: file, then `COSMOS_PORT`, then `--port`; default
  7700). No command hard-codes a port.

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
- **MVP-CON-7** `cosmos console` is the only console entry point. It attaches to the
  running daemon over IPC and accepts `--attach <identity>` and `--watch <path>`.
  `console_main` is removed once its tests have moved to `cosmos console`.

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
- **MVP-GATE-4** A fast check (`nimble check-fast` or similar) runs, in under one
  minute on the development machine, every test that opens no socket, starts no
  process and starts no daemon. Membership follows that rule, not a list, so new tests
  join automatically.
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

## 13. AI access

*Source: new direction (2026-11-05). AI is a first-class user of the runtime. There's
no earlier REQUIREMENTS.md section. Scope (full parity, MCP in the MVP) was confirmed on
2026-11-05.*

- **MVP-AI-1** **Parity:** every action available through the CLI or console is
  available as an IPC method with a structured JSON result. The CLI and console are
  clients of IPC, so there's no human-only path.
- **MVP-AI-2** Every Thing is discoverable and describes itself over IPC: identity,
  scope path, manifest (WHO, WHY and any optional interrogatives), WANTS and PROVIDES
  with signatures, tempo, status and children.
- **MVP-AI-3** The IPC surface describes itself. `runtime.methods` lists every method
  with its parameters, its result and whether it changes state, so a client needs no
  separate documentation.
- **MVP-AI-4** **Same gates:** AI requests pass the same validation as every other
  request. Every change is recorded in the history with its `origin` identity. There
  is no bypass and no AI-only path.
- **MVP-AI-5** A Thing's PROVIDES can be invoked over IPC (`runtime.call`), through the
  prefilter.
- **MVP-AI-7** **The Cosmos has an interface too.** The Cosmos root is a Thing like any
  other (MVP-ONT-5). Its PROVIDES are the runtime's own operations, such as `step`,
  `pause`, `addThing` and `stop`. `describe cosmos` lists them and `call cosmos …`
  invokes them, the same way as for any Thing.
- **MVP-AI-6** AI clients reach the runtime through ordinary interfaces: the CLI and
  Model Context Protocol (MCP). Both are thin clients of the same method table and add
  no logic of their own.
  - **CLI:** every method has a `cosmos` verb that prints the JSON response and exits
    with the §4.4 codes. It needs no terminal interaction.
  - **MCP:** `cosmos mcp` exposes every method as a tool over stdio, generated from
    `runtime.methods`.
  - **REST** is deferred. It would be one more thin client of the same table.

---

## Retired

These are removed from the design, not postponed.

| Area (REQUIREMENTS.md section) | Why retired |
|---|---|
| Context Inheritance Rules, Override Rules (SPECIFICATION §4.1C–§4.1D) | MVP-ONT-11: nothing is inherited. A Thing gets information only through its senses and explicit wires. |
| Programmatic Concept overriding a manual one (SPECIFICATION §19A.5, §19A.7) | MVP-INT-5: one manifest form for every Concept. |

## Deferred

These requirements stay in [REQUIREMENTS.md](REQUIREMENTS.md). Existing code for them
stays in place, but they're outside the MVP gate.

| Area (REQUIREMENTS.md section) | Why deferred |
|---|---|
| Encryption Spectrum (Phase XF) and Encrypted record (Phase XD) | Single user, so there's no operator to protect against. Revisit with a vetted crypto library. |
| Humane Offline Licensing (Phase XE) | Not needed for personal use. |
| Installer, release matrix, promotion (Ch 19A, Phase X release) | One machine. Build from source. |
| Dynamic Semantic Scanner (Phase XB) | Not needed to build Things. The `scan` command stays reachable. |
| Protobuf transport and serializer switching | JSON only, so one less decision. |
| Cue schema validation workflow | JSON config with in-code validation is enough. |
| Implementations in other languages (Python, Rust, Node, binaries), run as separate processes | The contract is fixed now (MVP-INT-6). The MVP uses Nim, and C where needed. |
| References (Phase XH) | Decide once real Things need them. A reference may turn out to be a wire. |
| World Ledger claims | Graph references are enough for navigation. |
| Delegation and specialists | Kept working, but not MVP-gated. |
| Memory categories and caps | Kept working, but not MVP-gated. |
| Console commands `specialists`, `delegations`, `claims`, `run`, `set`, `call` and `instances` | Not needed for the MVP workflow. |
| Multiple instances and federation | One instance. |
| Portability to BSD, macOS and Haiku, and 7–10-year-old toolchains | Windows first, then Linux. |
| Performance targets (startup under 2 s, frame rates) | Measure once the MVP is stable. |

## Decisions

Settled 2026-11-05.

1. **Daemon port comes from config** (MVP-CLI-9). `config.nim` already resolves `port`
   from file, `COSMOS_PORT` and overrides, with a default of 7700. The daemon and the
   client commands ignored it and hard-coded `IpcDefaultPort`. Tests set `COSMOS_PORT`
   to a free port. The rejected option, skipping tests when 7700 is busy, would let
   tests skip silently and couldn't run them in parallel.
2. **Fast check is a rule, not a list** (MVP-GATE-4). As of this decision, 48 of the
   50 test files qualify. The 2 that start the daemon or open sockets are
   `coordinator_test` and `daemon_console_test`.
3. **One console: `cosmos console`** (MVP-CON-7). It already talks to the daemon over
   IPC. `console_main` predates the daemon. Keeping both meant two ways in and two
   sets of flags, including the `--config` mismatch with REQUIREMENTS.md.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
