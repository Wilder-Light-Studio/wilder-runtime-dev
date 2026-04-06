# WILDER COSMOS RUNTIME — SPECIFICATION (v0.1.1)

*A clean, canonical, implementation‑level specification aligned with REQUIREMENTS v0.1.1.*

---

# 1. Core Architectural Principles (Implementation Interpretation)

The runtime must implement the following principles mechanically:

- **Thing = World = Scope**: Thing is identity aspect, World is interior aspect, Scope is visibility region from inside a Thing boundary.
- **Waves are the only communication physics**: Waves are ambient, undirected, and non-coercive truth in the medium.
- **Perception determines understanding**: Things only understand Waves through local filters.
- **Waves over wires**: wires are optional designer-level containment patterns over Wave propagation.
- **Channels are optional tuning**: channel tags on Waves and channel filters on Perceptions do not change physics.
- **Occurrence is the only mechanism of change**: Waves are externalized Occurrences; RECORDS are internalized Occurrences.
- **Bridges are validation firewalls**: Bridges are Thing/World templates that become boundary translators when instantiated.
- **No new primitives**: only Thing/World, Occurrence, Wave, Perception, and RECORD are primitive.
- **Voluntary reversible entry/exit**: no irreversible bindings; participation is opt-in and reversible.
- **Small -> Step -> Repeat -> Federate -> Integrate**: all runtime components must support incremental growth and deterministic testing.

---

# 2. Persistence Model (Three‑Layer Storage)

The runtime must implement a three‑layer persistence system:

### 2.1 Storage Layers
- **Primary Layer** — authoritative state (JSON or CBOR)
- **Secondary Layer** — append‑only transaction log (txlog)
- **Tertiary Layer** — periodic signed snapshots

### 2.2 Envelope Metadata
Every persisted record must include:

- `schemaVersion: int` — Version number for schema evolution.
- `epoch: int` — Frame-order counter for sequencing and replay.
- `checksum: SHA256` — Checksum for data integrity verification.
- `origin: string` — Source identifier for the record.
- `txId: string` — Transaction identifier used for replay idempotence.
- `timestamp: string` — ISO 8601 commit timestamp.

### 2.3 File Layout Contract
The file-backed bridge must use this layout under its configured base path:

```text
state/
  runtime.json
  modules/<name>.json
  txlog/<epoch>.txlog
  snapshots/<epoch>_snapshot.json
```

Rules:
- Primary-layer records are JSON envelopes stored as one file per runtime or module key.
- Txlog files are newline-delimited JSON records; one committed transaction appends one line.
- Snapshot files are full-copy envelopes plus signature metadata.
- File writes must use `.tmp` staging and atomic replace semantics.

### 2.4 Reconciliation Rules
The runtime must:

- Deterministically rebuild state from any two layers.
- Rebuild from one layer + transaction log.
- Halt startup on irreconcilable divergence.
- Log all reconciliation decisions.

Winning-layer rules:
- If primary and snapshot are both absent, startup proceeds as a fresh state.
- If primary and snapshot share an epoch, their checksums must agree or startup halts with `ReconcileError`.
- If primary and snapshot disagree on epoch, the higher valid epoch wins before txlog replay.
- Txlog replay must process entries in epoch order and skip entries already reflected in the winning full copy.
- Any checksum mismatch, replay gap, or signature failure during replay halts reconciliation.

### 2.5 Snapshot and Restore Contract
- `snapshotAll` writes `state/snapshots/<epoch>_snapshot.json` as a signed full-copy snapshot.
- `restoreSnapshot` validates checksum and signature metadata before replacing primary-layer state.
- Primary-layer replacement during restore must be atomic.
- Corrupt snapshot data must raise `PersistenceError`.

### 2.6 Streaming APIs
Blobs > 64 KB must use streaming read/write.

### Serialization Envelope
- Implement `envelopeWrap` to serialize data with metadata.
- Implement `envelopeUnwrap` to deserialize and validate metadata.

---

# 3. Console Subsystem Specification

The Console is the truth-surface and control panel for a single running Cosmos instance.
It is a runtime navigator, debugger, and introspection surface — not a REPL, not a
language interpreter.

### 3.1 Instance Binding
- Each Console session is bound to exactly one Cosmos instance at a time.
- No cross-instance queries. No information leakage between instances.
- Multiple tabs or windows may each attach to different instances.

### 3.2 Three-Layer Layout
Rendered in fixed vertical order:

1. **Status Bar** — frame, thing count, tempo, scheduler, active/inactive
2. **Scope Line** — `(COSMOS:CHILD1)`
3. **Prompt Line** — `/path/inside/thing>`

This order is an invariant.

### 3.3 `ls` Output Rules
- One entry per line, flat list, no headers, no sections, no indentation.
- Things: `[ThingScope]/`
- Directories: `Name/`
- Virtual directories: `*Name/`
- Files: `Name`

### 3.4 Attach/Detach Protocol
- identity verification
- permission negotiation
- capability negotiation
- layout initialization
- cache clearing on detach
- reattach is a fresh binding; no state inherited from previous session

### 3.5 Command Dispatch
Commands must be grouped into:

- Navigation (`ls`, `cd`, `pwd`)
- Introspection (`info`, `peek`, `watch`, `state`, `specialists`, `delegations`, `world`, `claims`)
- Execution (`run`, `set`, `call`)
- Instance Management (`attach`, `detach`, `instances`)
- Ergonomics (`help`, `clear`, `exit`)

Preconditions:
- `attach`, `instances`, `help`, `clear`, `exit`: available without an attached instance.
- All other commands require an attached instance.

### 3.6 `watch` Full-Screen Mode
- `watch` takes over the full terminal screen; the three-layer layout suspends.
- `Ctrl+C` or configurable timeout returns the Console to the three-layer layout.

### 3.7 Delegation Introspection
The Console must expose:

- `specialists` — list all specialists
- `delegations` — list active or recent delegation Occurrences

### 3.8 World Ledger Introspection
The Console must expose:

- `world` — structural references
- `claims` — relational assertions

### 3.9 CLI Entrypoint
- The repository must provide `src/console_main.nim` as a thin orchestration entrypoint.
- Supported flags:
  - `--config <path>` — required.
  - `--mode <dev|debug|prod>` — optional override.
  - `--attach <identity>` — optional auto-attach target.
  - `--watch <path>` — optional watch target started after attach.
  - `--log-level <trace|debug|info|warn|error>` — optional log level override.
  - `--port <N>` — optional port override (1–65535).
  - `--help`/`-h` — print full help text and exit 0.
- Missing `--config` must print usage and exit non-zero.
- `--help`/`-h` is sovereign: exits 0 and bypasses all validation, including missing required flags.
- `--log-level` must be validated against `trace|debug|info|warn|error`; invalid values exit non-zero.
- `--port` must be validated as an integer in range 1–65535; invalid values exit non-zero.
- Help text must include a minimal example and a full example.
- CLI overrides must not inject defaults: only explicitly provided flags apply to `RuntimeConfigOverrides`.
- `--attach` binds identity and permissions to the current console session only.
- `detach` clears attachment state and returns the three-layer layout to its neutral rendering.
- `watch` must emit snapshot lines on observed data changes and must stop cleanly on `detach`.

---

# 4. Ontology Specification

The runtime must implement exactly five primitives:

- Thing/World
- Occurrence
- Wave
- Perception
- RECORD

### 4.1 Thing / World / Scope
Thing and World are one primitive seen in different aspects:

- Thing: identity aspect
- World: interior aspect
- Scope: region visible from inside a Thing boundary

Changing scope is changing worlds; changing worlds is changing things.

Minimal existence contract for a Thing/World:

- WHO (identity)
- WHY (purpose)

These are the only required fields for a Thing/World to exist.

Optional world-defined interrogative lenses over the Concept manifest:

- WHAT (capabilities and structure)
- WHERE (location and containment)
- WHEN (tempo)
- HOW (mechanics)

The relational contract is optional but recommended for richer semantics:

- NEEDS
- WANTS
- PROVIDES

All interrogatives are descriptive lenses over one Thing/World interiority; they are not separate entities.

### 4.2 Occurrence
Occurrence is immutable internal truth inside a Thing/World:

- `id: string`
- `source: string`
- `epoch: int`
- `payload: JsonNode`

Occurrences are the canonical interior change truth.

### 4.3 Wave
Wave is externalized Occurrence in the medium:

- ambient
- undirected
- non-coercive
- carries type, payload, and optional channel tags

Waves are the metaphysical substrate for all communication.

### 4.4 Perception
Perception is local awareness:

- produced when local filters match ambient Waves
- passive and local
- stored in bounded perception memory

### 4.5 RECORD
RECORD is the atomic temporal unit of internal change:

- RECORDS are internalized Occurrences.
- No internal mutation may bypass RECORD semantics.

### 4.6 Patterns (Non-Primitives)
The following are patterns inside Worlds, not primitives:

- Concept
- Schema and RECORD types
- Wire and Channel
- Bridge
- Specialist, Delegation, System, Constellation

---

# 5. Runtime Lifecycle Specification

### 5.1 Startup Sequence
1. Load configuration
2. Initialize persistence backend
3. Load runtime envelope
4. Reconcile layers
5. Run migrations
6. Activate validating prefilter
7. Load modules (deterministic order)
8. Initialize scheduler, tempo, world graph
9. Begin frame loop

### 5.2 Shutdown Sequence
1. Flush transactions
2. Write snapshots
3. Stop scheduler/tempo
4. Unload modules
5. Close backend

### 5.3 Invariants
- no partial startup
- no silent failure
- no module execution before reconciliation
- no ingress before validating prefilter activation

### 5.4 Lifecycle State Machine

```text
NotStarted -> ConfigLoaded -> PersistenceReady -> EnvelopeLoaded -> Reconciled ->
Migrated -> PrefilterActive -> ModulesLoaded -> FramesRunning -> Running ->
ShuttingDown -> Stopped
```

Rules:
- Steps execute strictly in index order with no skipping.
- Any failure freezes the lifecycle at the failed step and halts immediately.
- `stepLoadModules` requires `reconciliationPassed == true`.
- `stepOpenIngress` requires `prefilterActivated == true`.

### 5.5 Structured Startup Errors

```nim
type
  StartupError = object
    haltedAt: string
    reason: string
    recoveryGuidance: string
```

Rules:
- `haltedAt` names the lifecycle step that failed.
- `recoveryGuidance` is mandatory for startup, reconciliation, and migration halts.
- Guidance strings must be actionable and must not expose raw payloads, secrets, or runtime file paths.

---

# 5A. Host Observability Specification

### 5A.1 Event Types

```nim
type
  HostEventKind = enum
    evStartupStep,
    evReconcilePass,
    evReconcileHalt,
    evMigrate,
    evPrefilterActivated,
    evShutdown

  HostEvent = object
    kind: HostEventKind
    step: string
    epochSeconds: int64
    message: string
```

### 5A.2 Logging Rules
- The host logger must expose `logEvent(kind: HostEventKind, msg: string)` or equivalent behavior.
- At least one `evStartupStep` event must be emitted per lifecycle step reached during startup.
- Reconciliation must emit either `evReconcilePass` or `evReconcileHalt` and include layer-count context.
- Migration emits `evMigrate`; successful prefilter activation emits `evPrefilterActivated`; shutdown emits `evShutdown`.
- Log messages must not contain raw payloads, keys, or secrets; use digests, byte lengths, and step names.
- In production mode, effective host logging severity must not be lower than info.

---

# 5B. Runtime Start Coordinator Specification

The runtime start coordinator is the primary startup entrypoint process.
The canonical startup executable is always `cosmos.exe`; compatibility aliases such as
`cosmos` may exist, but they must delegate to `cosmos.exe` without bypassing runtime
bootstrap logic.

### 5B.1 Boundaries
- The coordinator owns startup orchestration and lifecycle handoff.
- `src/console_main.nim` remains a thin console attachment/watch orchestration
  surface and is not the startup owner.
- Console command dispatch, rendering, and attach semantics remain in the
  Console subsystem.

### 5B.2 Supported Flags and Switches
- `--config <path>` (required)
- `--mode <dev|debug|prod>` (optional)
- `--console <auto|attach|detach>` (optional, default `detach`)
- `--watch <path>` (optional)
- `--daemonize` (optional)
- `--log-level <trace|debug|info|warn|error>` (optional)
- `--port <N>` (optional, 1–65535)
- `--help`/`-h` (optional)

Rules:
- Missing `--config` must print usage and exit non-zero.
- `--help`/`-h` is sovereign: exits 0 and bypasses all validation, including missing required flags.
- `--watch <path>` without an explicit `--console` flag resolves console mode contextually:
  - if `--daemonize` is set: effective console mode is `detach`.
  - if `--daemonize` is not set: effective console mode is `attach`.
- `--daemonize` combined with explicit `--console attach` is an invalid combination; fail fast with non-zero exit.
- `--port` must be validated as an integer in range 1–65535; invalid values exit immediately with non-zero.
- `--log-level` must be validated against `trace|debug|info|warn|error`; invalid values exit immediately with non-zero.
- CLI overrides must not inject defaults: only explicitly provided flags apply to `RuntimeConfigOverrides`.
- All other invalid combinations fail fast with usage output and non-zero exit.

### 5B.3 Startup Flow Contract
1. Parse and validate coordinator args.
2. Load config and apply override precedence.
3. Execute lifecycle startup sequence in Section 5.1 order.
4. Branch on console mode:
   - `detach`: runtime continues without launching console.
   - `auto`: launch console and attach to started runtime.
   - `attach`: wait for external console attach before reporting startup complete.
5. Emit startup events per Section 5A.

### 5B.4 Exit Contract
- Exit `0`: runtime startup reached active state.
- Exit non-zero: startup failed before active state.
- Failure payload must contain `haltedAt`, `reason`, and `recoveryGuidance`
  consistent with Section 5.5.

### 5B.5 Console Integration Contract
- Coordinator and console may run as separate processes.
- Console may detach and reattach without terminating coordinator-managed runtime.
- Watch startup is only valid in attached console mode (direct or implied).

### 5B.6 CLI Interface Contract

The coordinator must implement a deterministic CLI interface over launch options.

Required option model:

```nim
type
  CoordinatorConsoleMode = enum
    ccmAuto, ccmAttach, ccmDetach

  CoordinatorLaunchOptions = object
    configPath: string
    modeOverride: Option[string]      ## development|debug|production
    logLevel: Option[string]          ## trace|debug|info|warn|error
    port: Option[int]                 ## 1-65535
    consoleMode: CoordinatorConsoleMode
    consoleModeExplicit: bool         ## true if --console was explicitly provided
    watchTarget: Option[string]
    daemonize: bool
    wantHelp: bool

  CoordinatorStartupReport* = object
    consoleBranch*: string            ## "detach" | "auto" | "attach"
    configPath*: string
    modeResolved*: string
    exitCode*: int
```

Argument parsing rules:

- Parse left-to-right with explicit value ownership per flag.
- Unknown flags fail parsing immediately.
- Missing values for value-carrying flags fail parsing immediately.
- Mode aliases normalize as: `dev -> development`, `debug -> debug`,
  `prod -> production`.

Validation rules:

- If `wantHelp` is true, all other validation is bypassed; exits 0 with help text.
- `configPath` is required and non-empty.
- `daemonize` combined with explicit `consoleMode == ccmAttach` is invalid.
- `watchTarget` is valid only in attached console modes.
- If `watchTarget` is set and the effective `consoleMode == ccmDetach`, validation fails.
- `port` when present must be in range 1–65535.
- `logLevel` when present must be one of `trace|debug|info|warn|error`.
- Only explicitly provided flags populate `RuntimeConfigOverrides`; no defaults are injected.

### 5B.7 Coordinator Output Contract

- Invalid argument/validation input returns non-zero and prints usage output.
- Startup failure returns non-zero and includes structured fields aligned to
  `StartupError` semantics (`haltedAt`, `reason`, `recoveryGuidance`).
- Successful startup returns `0` and emits a `CoordinatorStartupReport` containing
  `consoleBranch` (`detach`, `auto`, or `attach`), `configPath`, `modeResolved`,
  and `exitCode = 0`.
- `--help`/`-h` exits `0` and prints help text with examples; no `CoordinatorStartupReport`
  is emitted.
- Help text must include a minimal example and a full example.

---

# 6. Interrogative Manifest Specification

Every Thing/World Concept must declare the minimal existence contract:

- WHO
- WHY

Optional world-defined interrogative lenses over the Concept manifest:

- WHAT
- WHERE
- WHEN
- HOW

Optional relational contract (recommended):

- NEEDS
- WANTS
- PROVIDES

### 6.1 Validation
- WHO and WHY are required and must be non-empty.
- WHAT, WHERE, WHEN, HOW, NEEDS, WANTS, and PROVIDES are optional.
- If optional fields are present, they must satisfy schema and type constraints.
- Missing optional fields must not fail validation.

### 6.2 Specialist Capability Declaration
Specialists must declare:

- `PROVIDES` — capabilities
- `NEEDS` — prerequisites
- `HOW` — optional mechanism details for specialization

---

# 7. Status Model Specification

### 7.1 Schema
Status must be declared as:

```nim
type
  StatusField = object
    name: string
    fieldType: string
    required: bool
    default: JsonNode
    invariant: Option[string]

  StatusSchema = object
    fields: seq[StatusField]
    schemaVersion: int
```

### 7.2 Invariant Checking
Performed:

- at load
- after mutation
- during reconciliation

### 7.3 Persistence
Status is persisted as part of Thing state.

---

# 8. Memory Model Specification

### 8.1 Categories
- **State memory** — persisted Status
- **Perception memory** — bounded FIFO
- **Temporal memory** — frame/epoch counters
- **Module memory** — soft cap (1 MB default)

### 8.2 Enforcement
- checked at mutation time
- violations produce structured errors

### 8.3 Introspection
Console `state` must expose memory usage.

---

# 9. Delegation Model Specification

### 9.1 Delegation Occurrence
Delegation is represented as:

```nim
type
  DelegationOccurrence = object
    id: string
    source: string
    targetCapability: string
    payload: JsonNode
    epoch: int
```

### 9.2 Result Occurrence
Returned as:

```nim
type
  DelegationResult = object
    id: string
    source: string         ## Responding specialist's Thing ID, or "runtime" on auto-failure.
    delegationId: string
    payload: JsonNode
    epoch: int
    success: bool
    error: Option[string]
```

### 9.3 Matching Rules
A specialist is selected when:

- its Concept's `PROVIDES` matches `targetCapability`
- its `NEEDS` are satisfied
- it is active in the world graph

### 9.4 Lifecycle Integration
Delegation Occurrences:

- enter the frame loop
- are perceived by specialists
- produce Result Occurrences

### 9.5 Invariants
- voluntary
- reversible
- pull‑based
- no shared memory
- no direct calls
- logged in txlog

---

# 10. World Ledger Specification

The World Ledger is a declarative, append-only pattern inside Thing/World interiority,
recording structural references and relational claims within Scope.

### 10.1 References
- Explicit, typed edges between Thing/World instances (e.g., parent/child, spatial adjacency).
- No implicit or inferred references.

### 10.2 Claims
- Relational assertions made by Thing/World instances about local topology.
- Declarative, signed by the asserting Thing/World, non-coercive.

### 10.3 Invariants
- Persisted within the three-layer persistence model.
- Validated at load time.
- Mutations flow through Occurrence -> Wave -> Perception -> RECORD semantics.
- No hidden edges. All structure must be declared.

### 10.4 Introspection
- Console `world` command: structural references.
- Console `claims` command: relational assertions.

---

# 11. World Graph Specification

### 11.1 Structure
The world graph is the topology view of Thing/World Scope:

- nodes = Thing/World instances
- edges = explicit references (from World Ledger pattern)

### 11.2 Invariants
- no implicit edges
- no inferred relationships
- all edges declared via ledger

### 11.3 Introspection
Console must expose:

- `world` — structural edges
- `claims` — relational assertions

---

# 12. Scheduler & Tempo Specification

### 12.1 Tempo Types
- Event
- Periodic
- Continuous
- Manual
- Sequence

### 12.2 Scheduler Invariants
- deterministic ordering
- bounded execution
- cooperative yielding

### 12.3 Frame Semantics
- each frame is an immutable snapshot
- all Occurrences in a frame share the same epoch
- replay must reconstruct identical world state

---

# 13. Module System Specification

- kernel vs loadable modules
- canonical module template
- static registration
- metadata: memory cap, resource budget

---

# 14. Taxonomy Specification

The planned source structure:

```
cosmos/core/
cosmos/runtime/
cosmos/concepts/
cosmos/thing/
cosmos/wave/
cosmos/tempo/
cosmos/inventory/
cosmos/patterns/
cosmos/utils/
runtime_modules/
modules/
examples/
```

---

# 14A. Testing Infrastructure Specification

The repository must provide two canonical testing artifacts:

- `tests/harness.nim`: a small, reusable test harness exposing `setupTest(name)`, `teardownTest()` and common helpers (temporary directory management, JSON load/write). Tests should import this harness for shared behavior.
- `templates/test_module.nim`: a canonical test module template used when creating new tests; it should demonstrate `unittest` usage, naming conventions, and recommended run commands.

Acceptance:

- Tests import the harness when they require shared setup.
- New test files follow the template and compile with `nim c -r` and `nimble test`.

---

# 15. Portability Specification

- Linux, BSD, macOS, Windows, Haiku
- portability layer for filesystem/time/process
- support for 7–10 year old toolchains

---

# 16. Performance Specification

- startup < 2 seconds
- deterministic memory usage
- efficient perception filtering

---

# 17. Security Specification

- read/write protection
- explicit mode validation
- no hidden channels

---

# 18. Documentation Specification

- Non-Deterministic (ND)-friendly comment style
- offline documentation
- minimal cognitive load
- **Acronym expansion (global rule):** every acronym or initialialism must
  be written out in full on its first appearance in every file, with the
  short form in parentheses immediately after. Format: `Full Name (ABBR)`.
  This applies to all source files, docs, comments, help text, templates,
  tests, plans, and walkthroughs — everywhere, without exception.
  Subsequent uses in the same file may use the short form alone.
- each chapter must include `MODULE-FLOWCHARTS.md`
- every runtime/cosmos module must appear in chapter flowchart references

### 18.1 Module Flowchart Contract

- Flowchart references must use `docs/implementation/ChapterX/MODULE-FLOWCHARTS.md`.
- Flowcharts must cover touched modules before chapter completion.
- Flowcharts must be updated in the same change set as requirement changes.

### 18.2 Public Documentation Information Architecture

- Newcomer-facing documentation must live under `docs/public/`.
- Required section roots:
  - `docs/public/getting-started/`
  - `docs/public/concepts/`
  - `docs/public/runtime/`
  - `docs/public/modules/`
  - `docs/public/glossary/`
- `docs/index.md` is the documentation landing page and must link both:
  - public guidance (`docs/public/`)
  - deep implementation materials (`docs/implementation/`)
- Every page in `docs/public/` must begin with `What this is.` followed by one
  sentence that states page purpose.
- Public docs must use short sections, direct language, and skimmable structure.
  Metaphors are allowed when they clarify mechanism, not when they add ambiguity.

### 18.3 Repository Documentation Organization Contract

- The repository taxonomy for documentation-facing organization is:
  - `src/runtime/`, `src/cosmos/`, `src/modules/`, `src/runtime_modules/`,
    `src/examples/`, `src/style_templates/`
  - `docs/public/`, `docs/implementation/`, `docs/assets/`, `docs/index.md`
  - `proto/`, `config/`, `scripts/`, `templates/`, `tests/`, `examples/`
- Reorganization operations must preserve artifacts by moving files.
- `docs/implementation/` content is immutable except for path/link correction.
- Link updates are mandatory when docs are moved or renamed; no orphan relative
  links are allowed in public or implementation docs.
- Public docs may summarize behavior but must not invent runtime behavior that
  is absent from implementation or governing spec.

---

# 19. Packaging Specification

- `.nimble` is source of truth
- releases must be self‑contained

---

# 19A. Phase X — Installer, Build, Release, and Concept System Specification

**REQ:** Project Phase: Phase X — Installer, Build, Release, and Concept System

### 19A.1 Build Matrix and Artifact Contract

- CI must build release artifacts for:
  - `windows-amd64`
  - `windows-arm64`
  - `linux-amd64`
  - `linux-arm64`
  - `darwin-amd64`
  - `darwin-arm64`
- Every build job must execute, in order: compile, test, package, sign, publish, and
  verify artifacts.
- Every build job must produce:
  - runtime binary payload containing canonical `cosmos.exe`
  - installer payload for the target platform
  - SHA-256 checksum file for each distributable artifact
  - machine-readable release manifest entry
  - concept payload containing the embedded effective Concept for packaged apps
- Build output identity must include version, channel, git commit, target triple, and
  UTC build timestamp.

### 19A.2 Installer Modes, OS Mapping, and Runtime Home Contract

Installers must support two explicit modes:
- `user`: install under user-home paths.
- `system`: install under shared system paths.

Mode-specific install roots:
- Windows user mode: `%USERPROFILE%\\.wilder\\cosmos\\`
- Windows system mode: `%ProgramData%\\Wilder\\Cosmos\\`
- Linux user mode: `~/.wilder/cosmos/`
- Linux system mode: `/var/lib/wilder/cosmos/`
- macOS user mode: `~/.wilder/cosmos/`
- macOS system mode: `/var/lib/wilder/cosmos/`

Canonical runtime home tree must include:

```text
.wilder/cosmos/
  config/
  logs/
  cache/
  messages/
  projects/
  registry/
  bin/
  temp/
```

Ownership rules:
- `config/` is user-editable and must never be removed if it contains user-created files
  outside installer-owned defaults.
- `registry/` is tool-owned and may contain installer manifests, concept indices,
  and version-registry state.
- `projects/` is optional convenience storage only; installers must not assume all user
  projects reside there.
- `bin/` contains user-local runtime tools in `user` mode and shared runtime tools in
  `system` mode.

Installers must create required directories idempotently and preserve existing user data.

### 19A.3 Canonical Entrypoint Resolution Contract

- The canonical startup executable name is always `cosmos.exe` on every supported OS.
- Runtime invocation paths, wrappers, package launch scripts, and symlink targets must
  terminate at `cosmos.exe`.
- If a compatibility alias is provided, it must be a thin delegator to `cosmos.exe` and
  must not bypass runtime bootstrap logic.
- All CLI commands must be dispatched by `cosmos.exe` even when the operator launches a
  compatibility alias.
- Packaged applications must invoke `cosmos.exe` as the runtime host and must not embed
  or bypass runtime bootstrap logic.

### 19A.4 PATH Integration, Uninstall, and Update Registry Contract

- Installers must offer opt-in PATH integration during install.
- PATH mutation must be scoped to user environment for `user` mode and machine
  environment for `system` mode.
- Uninstall must remove:
  - installed binaries and wrappers
  - PATH entries added by installer
  - installer-generated manifests and metadata
  - tool-owned version registry entries created for the removed install
- Uninstall must not delete user-created project content under `projects/` or outside
  runtime home.
- After uninstall, no installer-owned files may remain in install targets.
- Runtime update state must be stored under `registry/` and must include installed
  version, installed channel, and last-known update-check result.
- The runtime may perform an optional check-only auto-update query, but installation of
  updates remains installer-driven.

### 19A.5 Concept Derivation Engine Contract

- The build system must derive programmatic Concepts from code-defined contracts.
- Derived Concepts must normalize into a stable serialized structure independent of source
  file ordering.
- When both a derived programmatic Concept and a manual Concept exist for the same
  identity, the derived programmatic Concept is the effective Concept.
- Manual Concept files may be used only when no derived programmatic Concept exists for
  the same identity.
- The build must fail if a manual Concept is selected as effective and does not validate.
- The build must emit deterministic concept metadata sufficient to embed the effective
  Concept in packaged applications.

### 19A.6 Concept ABI and Registry Format Contract

- The Concept ABI must be stable across supported platforms and versioned explicitly.
- Every serialized effective Concept must include at minimum:
  - `abiVersion`
  - `conceptId`
  - `sourceKind` (`programmatic` or `manual`)
  - `schemaVersion`
  - `checksumSha256`
  - `manifest`
  - `sections`
  - `derivedFrom`
- The runtime registry must store one record per concept identity under
  `~/.wilder/cosmos/registry/`.
- Registry records must include effective-source metadata and enough information to list,
  inspect, validate, and export Concepts without recomputing unrelated identities.

### 19A.7 Runtime Concept Loading Contract

- Runtime startup must resolve runtime home before concept loading begins.
- Runtime concept loading order must be:
  1. load embedded programmatic Concepts for packaged apps
  2. load registry-backed programmatic Concepts
  3. fall back to validated manual Concept files when no programmatic Concept exists
- Runtime must register the effective Concept for each identity in the registry.
- If both programmatic and manual Concepts exist, runtime may emit a warning but must keep
  the programmatic Concept as effective.

### 19A.8 CLI Command Contract

`cosmos.exe startapp` must execute deterministic scaffold generation with interactive
prompts.

Required `startapp` behavior:
1. Accept optional target path argument; default to current working directory.
2. Prompt for app name, runtime mode, transport, and initial template selection.
3. Show defaults for every prompt and allow accept-by-enter.
4. Validate destination path writability before generation.
5. Generate scaffold atomically using temporary staging then rename/move.
6. Generate `cosmos.toml`, `src/`, a build manifest, and optional templates.
7. Emit a completion summary containing generated paths and next commands.
8. Exit `0` on success; non-zero with structured error on validation or IO failure.

Required concept commands:
- `cosmos concept show` returns the effective Concept for the requested identity or app.
- `cosmos concept validate` validates a manual Concept file or the effective registered
  Concept and returns machine-readable pass/fail status.
- `cosmos concept export` emits the stable ABI serialization for the effective Concept.
- `cosmos concept registry list` returns deterministic ordered entries.
- `cosmos concept registry inspect <conceptId>` returns one registry record.

### 19A.9 Signing, Publishing, Versioning, and Channels Contract

- Signing must support:
  - Authenticode for Windows artifacts
  - Developer ID or equivalent notarized signing for macOS distributions
  - detached signature files for Linux artifacts
- Publishing must produce channel-separated outputs for `stable`, `beta`, and `nightly`.
- Versioning must be sourced from `.nimble`, expressed as semantic versioning, and enforce
  monotonic release progression per channel.
- Each published artifact must include checksum, signature data, source provenance,
  and channel metadata.

### 19A.10 Automation and Compliance Execution Contract

- Release workflows must emit `release-manifest.json` with one entry per artifact.
- Manifest fields must include at minimum:
  - `artifactName`
  - `version`
  - `channel`
  - `target`
  - `checksumSha256`
  - `signatureType`
  - `sourceCommit`
  - `buildId`
  - `publishedAtUtc`
  - `conceptAbiVersion`
  - `effectiveConceptId`
- CI compliance tests must fail if:
  - a required target in the build matrix is missing
  - `cosmos.exe` is absent from any package
  - installer mode behavior deviates from path contract
  - uninstall leaves installer-owned residue
  - concept registry records omit required ABI metadata
  - manifest schema or required fields are missing

---

# 20. Archive Completeness Specification

- no external dependencies
- full offline build/test capability

---

# 19B. Phase XA — DRY Wants/Provides and Capability Discovery Specification

**REQ:** Project Phase: Phase XA — DRY Wants/Provides and Capability Discovery

### 19B.1 Capability Identity and Declaration Contract

- Canonical capability key format is `<ThingName>.<provideName>`.
- Provider-side declaration is authoritative for signature shape.
- Consumer-side wants must not redefine provider signature as canonical truth.
- Want references must support:
  - exact capability reference: `<ThingName>.<provideName>`
  - whole-Thing reference: `<ThingName>`

### 19B.2 Capability Graph Data Contract

Runtime must construct an in-memory capability graph with deterministic ordering.

Required nodes and edges:
- Thing node
- provide node (owned by one Thing)
- want node (owned by one Thing)
- binding edge from provide node to implementation module binding
- resolution edge from want node to provide node when resolved

Required fields per provide node:
- `thingName`
- `provideName`
- `signature`
- `moduleBinding`

Required fields per want node:
- `consumerThing`
- `reference`
- `expectedSignature` (optional)

### 19B.3 Resolution Algorithm Contract

Resolution must execute before ingress opens.

Algorithm steps (deterministic):
1. Normalize and sort all provider declarations by `(thingName, provideName, signature)`.
2. Index providers by Thing and by full capability key.
3. Normalize wants in declaration order, then process deterministically.
4. For exact capability wants:
   - if provider Thing is missing: `missing-provider-thing`
   - if provide is missing on existing Thing: `missing-provide`
   - if more than one provider candidate exists for same key: `provider-conflict`
   - if expected signature exists and differs from provider signature:
     `signature-mismatch`
   - otherwise resolve to single provider.
5. For whole-Thing wants:
   - if Thing missing: `missing-provider-thing`
   - otherwise resolve to all provides for that Thing in deterministic order.
6. Emit unresolved errors and halt startup when any fatal issue exists.

Fatal issues:
- `missing-provider-thing`
- `missing-provide`
- `provider-conflict`
- `signature-mismatch`

Non-fatal issue:
- `orphaned-provide` (for visibility and cleanup guidance)

### 19B.4 Startup Gate Contract

- Capability resolution must run after configuration load and before ingress open.
- Runtime startup must halt on any fatal capability issue.
- Halt output must include deterministic issue kind, reference, and guidance text.

### 19B.5 Module Binding Contract

- Implementation bindings are validated against canonical declared provides.
- Undeclared implementation exports are rejected.
- Declared provides without bindings are rejected.
- Multiple implementation bindings targeting one declared provide are rejected.

### 19B.6 CLI Contract

`cosmos capabilities`:
- returns deterministic capability view for Things/provides/wants.
- includes resolution status and unresolved issue classes.
- must be parseable by tooling and readable by operators.

`cosmos concept resolve`:
- returns explicit mapping from one want reference to resolved provider(s).
- on unresolved mapping returns structured failure including issue class.

### 19B.7 Testability Contract

Minimum required test classes:
- provider uniqueness conflict detection
- missing provider Thing detection
- missing provide detection
- signature mismatch detection
- whole-Thing deterministic expansion
- deterministic output across repeated runs

---

# 19C. Phase XB — Dynamic Semantic Scanner and Relationship Extraction Specification

**REQ:** Project Phase: Phase XB — Dynamic Semantic Scanner and Relationship Extraction

### 19C.1 Scanner API Contract

Scanner API must expose deterministic pure-introspection operations:

- `scanPath(root: string): seq[Thing]`
- `scanThingsJson(root: string): JsonNode`
- `findCapabilityConflicts(things: seq[Thing]): seq[string]`

API failure behavior:
- invalid root path: structured error
- unreadable file: diagnostic record, continue scan

### 19C.2 Scanning Pipeline Contract

Pipeline stages (deterministic):
1. discover candidate files in lexicographic order
2. parse file structure (imports, declarations, annotations, comments)
3. infer relationship sets
4. emit Thing objects with relationship metadata
5. run cross-Thing conflict detection

Scanner candidate set for this phase:
- `.nim` source files under the target root

### 19C.3 Inference Engine Contract

Inference rules:
- `import` statements -> `needs`
- `@provides("...")` or detected declarations -> `provides`
- `@wants("...")` -> `wants`
- duplicate provide keys -> `conflicts`
- import edge `A imports B` -> `A after B`, `B before A`

All inferred lists must be sorted and deduplicated.

### 19C.4 Thing Output Schema Contract

Each scanner-emitted Thing must include metadata keys:
- `scannerVersion`
- `sourcePath`
- `needs`
- `wants`
- `provides`
- `conflicts`
- `before`
- `after`

Thing identity contract:
- `thing.id` must be stable for identical `sourcePath`.
- `thing.id` format for this phase: `scan:<normalized-relative-path>`.

### 19C.5 VFS and Translator Integration Contract

- Scanner metadata must be serializable through existing Thing JSON serialization.
- Scanner JSON output must be consumable by VFS exposure and translator tooling as
  read-only derived state.

### 19C.6 Safety and Determinism Contract

- Scanner must not execute scanned files.
- Scanner must not write to scanned files.
- Scanning the same tree twice without changes must yield byte-equivalent JSON output.

### 19C.7 CLI Contract

`cosmos scan [path] [--json]`:
- scans target path (default current directory)
- outputs deterministic summary or JSON payload

`cosmos capability conflicts [path]`:
- scans target path
- returns deterministic conflict list

### 19C.8 Testability Contract

Minimum required tests:
- import -> needs inference
- declaration/annotation -> provides inference
- duplicate provides -> conflict detection
- deterministic repeated scan output
- CLI command behavior and argument validation

---

# 19D. Phase XC — Runtime Messaging Strategy Specification

**REQ:** Project Phase: Phase XC — Coordinator IPC and Console Notification Stream

### 19D.1 Coordinator IPC Transport Contract

- Transport endpoint must resolve to localhost TCP URI form:
  - `tcp://127.0.0.1:<port>`
- Runtime transport for this phase is newline-delimited JSON frames over TCP localhost
  (JSON-lines request/response/event exchange).
- Endpoint validation must reject non-localhost hostnames for this phase.
- Port validation must enforce `[1, 65535]`.

### 19D.2 IPC Message Schema Contract

Request envelope:
- `{ "id": string, "method": string, "params": object }`

Response envelope:
- success: `{ "id": string, "result": object }`
- failure: `{ "id": string, "error": { "code": string, "message": string } }`

Event envelope:
- `{ "event": string, "payload": object }`

All envelopes for this phase include a protocol marker:
- `"version": "ipc-v1"`

### 19D.3 IPC Command Method Contract

Required methods:
- `pause`
- `resume`
- `step`
- `snapshot`
- `inspect`

Additional coordinator methods for this phase:
- `subscribe`
- `unsubscribe`

Method semantics:
- `pause`: runtime enters paused state and emits `runtime.paused` event.
- `resume`: runtime exits paused state and emits `runtime.resumed` event.
- `step`: runtime tick increments and emits `runtime.step` event.
- `snapshot`: snapshot revision increments and emits `runtime.snapshot` event.
- `inspect`: returns deterministic state payload with pause, tempo, health,
  Things, and reconciliation fields.

### 19D.4 Subscription and Push Event Contract

- Session maintains deterministic subscription set for event keys.
- Event is queued for push when event key is subscribed or wildcard `*` is subscribed.
- Duplicate subscriptions do not produce duplicate push events.

### 19D.5 Console Notification Stream Contract

- Notification format is line-oriented:
  - `[time] [level] [component] message`
- `level` is normalized to uppercase.
- Notification formatting must not embed IPC request/response envelopes.

### 19D.6 Failure and Safety Contract

- Invalid request structure returns structured `invalid_request` failure.
- Unknown method returns structured `method_not_found` failure.
- Method failures must not mutate unrelated session state.
- Repeated identical valid requests over identical prior state yield deterministic
  payload structure.

### 19D.7 CLI Contract

`cosmos ipc request --method <name> [--id <id>] [--params-json <json>] [--subscribe <event>]... [--tcp] [--host <host>] [--port <N>]`:
- validates request schema
- routes to coordinator IPC handler (in-memory by default)
- when `--tcp` is present, sends request to localhost TCP endpoint and returns returned
  response/event frames
- emits deterministic JSON response line
- emits queued event lines when subscriptions match

`cosmos ipc endpoint [--host <host>] [--port <N>]`:
- emits validated localhost endpoint URI

`cosmos ipc serve [--host <host>] [--port <N>] [--max-requests <N>]`:
- hosts TCP JSON-lines coordinator IPC endpoint on localhost
- serves deterministic request/response/event frames against one bounded session
- supports finite serving window when `--max-requests` is provided

`cosmos notify format --time <iso> --level <level> --component <component> --message <text>`:
- emits one formatted notification line

### 19D.8 Coordinator and CLI Integration Points

- Coordinator IPC request state and schema dispatch live in `src/runtime/coordinator_ipc.nim`.
- Runtime coordinator CLI integration lives in `src/cosmos_main.nim` under `ipc` and `notify`
  command branches.
- IPC transport and console notification stream must remain independent surfaces:
  - IPC channel is machine-oriented (`request`/`response`/`event` JSON envelopes)
  - notification channel is operator-oriented (`[time] [level] [component] message`)
- No coordinator CLI path may require console output parsing to execute IPC methods.

### 19D.9 GUI Migration Notes

- GUI tools should treat IPC as newline-delimited JSON envelopes over localhost TCP.
- GUI clients must ignore unknown keys for forward compatibility and gate behavior on
  `version`.
- GUI clients should consume response frame first, then zero-or-more event frames.
- GUI tools should not parse notification lines as IPC data; notification stream is
  intentionally human-readable and lossy by design.

### 19D.10 Testability Contract

Minimum required tests:
- request schema validation failures
- required method behavior (`pause`, `resume`, `step`, `snapshot`, `inspect`)
- deterministic endpoint URI and localhost guard
- TCP JSON-lines frame validation and deterministic envelope parsing
- subscription push behavior for wildcard and direct event keys
- notification formatting contract and level normalization
- coordinator CLI coverage for `ipc request`, `ipc endpoint`, `ipc serve`, `notify format`

---

# 19E. Phase XD — Encrypted Triumvirate RECORD Specification

**REQ:** Project Phase: Phase XD — Encrypted Triumvirate RECORD

### 19E.1 Encrypted RECORD Entry Contract

Entry object fields:
- `entryType: string`
- `authorId: string`
- `sequence: int`
- `previousHash: string`
- `encryptedPayload: string` (hex)
- `encryptedPayloadHash: string` (SHA256 over encrypted payload bytes)

### 19E.2 Deterministic Encryption Contract

- Encryption inputs are deterministic tuple:
  - payload JSON string
  - key material
  - sequence
  - entry type
  - author id
  - previous hash
- Encryption algorithm for this phase uses deterministic keystream expansion from SHA256
  counters over nonce material derived from the tuple above.
- Equal inputs must yield equal ciphertext and equal ciphertext hash.

### 19E.3 Decryption Contract

- Decryption uses the same keystream derivation tuple as encryption.
- Decrypted payload must parse as JSON object or fail with structured error.

### 19E.4 Metadata-Only Reconciliation Contract

- Chain validation input is ordered seq of encrypted entries.
- Validation checks:
  - sequence must be strictly increasing by one
  - first entry sequence must be `1`
  - entry `n.previousHash` must equal entry `n-1.encryptedPayloadHash`
  - each `encryptedPayloadHash` must equal recomputed SHA256(encryptedPayload)
- Validation must not decrypt payloads.

### 19E.5 Triumvirate Comparison Contract

- Reconciliation compares only metadata tuples:
  - `(sequence, entryType, encryptedPayloadHash, previousHash)`
- Any mismatch in metadata tuple across copies is structural divergence.

### 19E.6 Testability Contract

Minimum required tests:
- deterministic ciphertext stability for identical inputs
- ciphertext divergence for payload or metadata change
- encrypt/decrypt round-trip with JSON payload
- metadata-only chain pass/fail cases
- non-decrypting reconciliation behavior over malformed encrypted payload text

---

# 19F. Phase XE — Humane Offline Licensing Specification

**REQ:** Project Phase: Phase XE — Humane Offline Licensing

**Source:** License generation, validation, and runtime integration behavior.

### 19F.1 Installer and First-Run Flow Contract

Installer and first-run behavior must:
- remain fully functional without any network dependency;
- present Wilder License agreement as an explicit local step before local license generation;
- provide clear paid and complimentary local licensing options without coercion;
- treat optional transparency email as a separate opt-in action;
- never block runtime startup when a legitimate local licensing path is selected.

### 19F.2 Local License Generation Contract

License generation must:
- operate fully offline (zero network activity);
- accept deterministic local inputs: runtime version, local identity fingerprint, license mode (`paid` or `complimentary`), and generation timestamp;
- produce a stable, human-readable local file at `~/.wilder/cosmos/config/license.txt` (or OS-equivalent path);
- include verification fields signed by deterministic local signing rules;
- generate identical output for identical input fields.

### 19F.3 Local License File Structure Contract

The local license file must include at least:
- `schemaVersion`
- `runtimeVersion`
- `licenseMode` (`paid` or `complimentary`)
- `generatedAt` (ISO 8601)
- `identityFingerprint`
- `agreementRef` (Wilder License reference id)
- `signature`

Validation must check structural completeness, signature correctness, and version compatibility using only local data.

### 19F.4 Optional One-Time Transparency Email Contract

Transparency email behavior must:
- be optional, one-time, user-initiated, and editable before send;
- never run automatically in background logic;
- have zero effect on license validity, startup eligibility, or runtime behavior when declined;
- expose template content to the user before invocation;
- treat send failures as non-fatal with no licensing side effects.

### 19F.5 Licensing Deactivation Contract

Deactivation behavior must enforce:
- when a valid local license is present for a given runtime version, enforcement checks for that version deactivate;
- no periodic renewal checks, remote revalidation, or background license polling;
- optional `cosmos license deactivate` remains local-only and administrative.

### 19F.6 Three-Year Liberation Timer Contract

Liberation behavior must enforce:
- each runtime version carries a built-in three-year liberation timer from release date metadata;
- once timer expiry is reached, licensing enforcement for that version permanently deactivates;
- liberation transition is deterministic and local-only;
- no network calls are attempted before, during, or after liberation transition;
- liberation metadata is recorded for release/compliance traceability.

### 19F.7 Deterministic Errors and Runtime Integration Contract

Runtime integration must:
- evaluate licensing state deterministically at startup (before optional user-facing notices);
- return structured local-only states such as `licensed`, `unlicensed`, `liberated`, and `invalid_local_license`;
- keep concept registration and capability discovery independent of licensing state;
- never emit sensitive identity details in logs.

### 19F.8 CLI Contract

CLI must provide:
- `cosmos license generate` for deterministic offline local license creation;
- `cosmos license show` for local artifact inspection;
- `cosmos license validate` for local deterministic validation;
- `cosmos license deactivate` for local administrative deactivation;
- deterministic exit codes and structured error messages for invalid local files.

### 19F.9 Testability Contract

Minimum required tests:
- deterministic offline local license generation for identical inputs;
- valid paid and complimentary license generation and validation;
- invalid or tampered local license detection;
- no-network guarantees for generation, validation, deactivation, and liberation paths;
- optional transparency email decline and send-failure no-op behavior;
- valid local license deactivates enforcement checks for matching version;
- liberation timer expiry permanently deactivates licensing enforcement for the version.

---

# 19G. Phase XF — Cosmos Encryption Spectrum Specification

**REQ:** Project Phase: Phase XF — Cosmos Encryption Spectrum

**Source:** Encryption-mode selection, key custody, metadata exposure, and migration
behavior layered over the existing encrypted RECORD and persistence model.

### 19G.1 Mode Selector and Scope Contract

- Runtime configuration must expose `encryptionMode` with canonical values
  `clear`, `standard`, `private`, and `complete`.
- Exactly one encryption mode is active for a runtime instance at a time.
- The selected mode applies uniformly to:
  - RECORD payloads,
  - prompts and outputs,
  - eidela state,
  - persisted runtime state containing user data,
  - exports and backup artifacts.
- Phase XD encrypted RECORD structure, hashing, and reconciliation rules remain binding
  for every mode that stores encrypted RECORD payloads.

### 19G.2 CLEAR Contract

- `clear` disables Cosmos-managed content encryption and key-derivation flows.
- RECORD payloads and other protected user-data classes may persist as plaintext.
- No ciphertext wrapper, recovery envelope, or synthetic key material is required.
- User-facing surfaces must label the mode as non-private or equivalent language.

### 19G.3 STANDARD Contract

- `standard` encrypts user-authored content client-side before operator-controlled
  persistence, replication, or sync.
- Operator-visible metadata is limited to fields needed for routing, timestamps, size,
  deterministic reconciliation, and bounded diagnostics.
- Recovery or escrow is optional and valid only with explicit user opt-in.

### 19G.4 PRIVATE Contract

- `private` encrypts all user content and eidela state client-side.
- Primary content keys remain under user or device custody.
- Metadata exposure must be strictly less than or equal to `standard` and limited to
  the minimum needed for deterministic runtime operation.
- Recovery is permitted only through explicit user-provisioned artifacts.

### 19G.5 COMPLETE Contract

- `complete` enforces end-to-end encryption across content-bearing runtime surfaces.
- User content, eidela state, and runtime state containing user data must be encrypted
  before they cross the user-controlled device boundary.
- Operator-controlled services may observe ciphertext and the minimum transport or
  reconciliation metadata only.
- Operator escrow, hidden recovery channels, or plaintext inspection exceptions are
  forbidden.

### 19G.6 Key Handling and Recovery Contract

- `clear` uses no content-encryption key material.
- `standard` may use device-local keys and optional user-approved recovery wrapping.
- `private` requires user-controlled or device-controlled key custody for primary
  content keys.
- `complete` requires user-controlled key custody and must never upload plaintext keys
  to operator-controlled services.
- Missing required key material must cause deterministic startup or activation failure.

### 19G.7 Metadata and Diagnostics Contract

- `clear` permits plaintext content and metadata visibility.
- `standard` allows structural metadata visibility but forbids operator plaintext access
  to protected content.
- `private` must minimize metadata beyond `standard` while preserving deterministic
  routing and reconciliation.
- `complete` must not emit plaintext-derived diagnostic fields, previews, or support
  traces to operator-controlled surfaces.

### 19G.8 Migration and Failure Contract

- Mode changes are explicit migrations, not implicit runtime fallbacks.
- Moving to a more private mode requires re-encryption or state rewriting to complete
  before activation.
- Moving to a less private mode requires explicit user-visible confirmation and must not
  occur silently.
- `complete` activation must fail fast when end-to-end key material is unavailable.
- Recovery combinations that contradict the selected mode's trust boundary must be
  rejected deterministically.

### 19G.9 Testability Contract

Minimum required tests:
- deterministic parsing and validation of `encryptionMode`;
- `clear` bypass behavior for Cosmos encryption layers;
- no-plaintext-access coverage for `standard`, `private`, and `complete`;
- metadata exposure assertions per mode;
- migration and downgrade guardrail coverage;
- missing-key and invalid-recovery failure coverage.

---

# 21. Runtime Configuration Specification

**REQ:** Runtime Configuration Requirements
**Source:** Cue schema → exported JSON/YAML → loaded at startup into Nim types.

### 21.1 Schema Fields

| Field      | Type   | Values                                      | Default       |
|------------|--------|---------------------------------------------|---------------|
| `mode`     | string | `"debug"` \| `"production"`                 | `"debug"`     |
| `encryptionMode` | string | `"clear"` \| `"standard"` \| `"private"` \| `"complete"` | `"standard"` |
| `transport`| string | `"json"` \| `"protobuf"`                    | `"json"`      |
| `logLevel` | string | `"trace"` \| `"debug"` \| `"info"` \| `"warn"` \| `"error"` | `"info"` |
| `endpoint` | string | non-empty hostname or address               | `"localhost"` |
| `port`     | int    | `1–65535`                                   | `7700`        |

### 21.2 Validation Rules
- `mode = "production"` must reject `logLevel ∈ {"trace", "debug"}`.
- `encryptionMode` must be one of `clear|standard|private|complete`.
- `clear` must bypass Cosmos-managed content-encryption paths without synthetic key
  requirements.
- `private` and `complete` must reject activation when required key material is absent.
- `complete` must reject operator-escrow or operator-recovery settings if they are
  present in the effective config.
- `port` must be in range `[1, 65535]`.
- `endpoint` must be a non-empty string.
- All other invalid combinations must produce a structured error at config-load time.

### 21.3 Nim Config Type
The loaded config must map to a single Nim record passed to all subsystems:

```nim
type
  RuntimeMode    = enum rmDebug, rmProduction
  EncryptionMode = enum emClear, emStandard, emPrivate, emComplete
  TransportKind  = enum tkJson, tkProtobuf
  LogLevel       = enum llTrace, llDebug, llInfo, llWarn, llError

  RuntimeConfig = object
    mode:           RuntimeMode
    encryptionMode: EncryptionMode
    transport:      TransportKind
    logLevel:       LogLevel
    endpoint:       string
    port:           int
```

### 21.4 Loading Contract
- Config is loaded once during startup step 1 (see §5.1).
- No subsystem may read raw config after startup.
- A missing config file must halt startup with a structured error.

### 21.5 Validation Workflow
- Source of truth is `config/runtime.cue`.
- Exported config must be validated against the Cue schema before runtime load.
- The repository must provide a validation script that exits non-zero on schema violation.

### 21.6 Override Precedence
- `loadConfig` must support override inputs from environment and CLI.
- Precedence order is: config file < environment variables < CLI flags.
- Supported environment variable overrides include `COSMOS_MODE`,
  `COSMOS_ENCRYPTION_MODE`, `COSMOS_LOG_LEVEL`, and `COSMOS_PORT`.
- All override values are validated using the same rules as file-provided values.
- Overrides are additive replacements only; they do not permit missing required fields after validation.

---

# 22. Messaging System Specification

**REQ:** Wave Serialization Requirements
**Schema format:** Protobuf (`.proto` file at `proto/messaging.proto`) and JSON as encoding patterns.

### 22.1 WaveEnvelope Fields

| Field       | Protobuf type | Notes                              |
|-------------|---------------|------------------------------------|
| `id`        | `string`      | unique wave identifier             |
| `type`      | `string`      | wave type discriminator            |
| `version`   | `int32`       | payload schema version             |
| `timestamp` | `int64`       | unix milliseconds                  |
| `channels`  | `repeated string` | optional designer-level channel tags |
| `payload`   | `oneof`       | typed payload; see §22.2           |

### 22.2 Payload Types
At minimum the following concrete payload types must be defined:

- `Ping` — heartbeat / connectivity check (`message_id: string`).
- `ConfigUpdate` — signals a config reload request (`new_mode: string`, `new_log_level: string`).

Additional payload types are additive and must not renumber existing fields.

### 22.3 Forward Compatibility Rules
- Removed fields must be marked `reserved`.
- Field numbers must never be reused or renumbered.
- All evolution is additive.

### 22.4 Communication Physics Boundary
- Envelope schemas are encoding patterns over Waves and must not redefine communication physics.
- No envelope field may imply target ownership or directional delivery semantics.
- Wires and channels remain optional designer-level constraints compiled to Perception masks,
  validation rules, and topology hints.

### 22.5 Debug Introspection
- In `mode = "debug"`, every `WaveEnvelope` must be introspectable before local handling.
- The Console `watch` command must be able to tail the live Wave stream.
- In `mode = "production"`, envelope logging must not occur unless `logLevel <= info`.

---

# 23. Serialization Transport Specification

**REQ:** Serialization Transport Requirements

### 23.1 Serializer Abstraction (Nim)

```nim
type
  SerializerKind = enum skJson, skProtobuf

  Serializer = ref object of RootObj
    kind: SerializerKind

proc encode*(s: Serializer, msg: WaveEnvelope): seq[byte]
proc decode*(s: Serializer, data: seq[byte]): WaveEnvelope
```

### 23.2 Selection Rules
- Active serializer is chosen once at startup from `RuntimeConfig.transport`.
- `tkJson` → JSON serializer.
- `tkProtobuf` → Protobuf serializer.
- The serializer is injected; subsystems must not construct their own.

### 23.3 JSON Serializer
- Uses standard Nim `json` module.
- Must produce stable, deterministic output (key order determined by field declaration).
- Must round-trip all `WaveEnvelope` and payload types without loss.
- Used for: filesystem bridge, debug mode, and fallback when Protobuf is unavailable.

### 23.4 Protobuf Serializer
- Schema defined in `proto/messaging.proto`.
- Must round-trip all `WaveEnvelope` and payload types.
- Used for: production mode (`transport = "protobuf"`).

### 23.5 Fallback Policy
- If Protobuf is configured but unavailable at startup, the runtime must halt with a
  structured error. Silent fallback to JSON in production is not permitted.
- JSON is always the filesystem bridge format regardless of `transport`.

### 23.6 Module Layout

```
config/
  runtime.cue           # Cue schema
proto/
  messaging.proto       # Protobuf schema
src/runtime/
  config.nim            # config loading, validation, RuntimeConfig type
  serialization.nim     # envelopeWrap/envelopeUnwrap + Serializer abstraction
  messaging.nim         # Wave envelope handling, debug introspection
tests/
  config_test.nim       # config loading, validation tests
  serialization_test.nim # JSON and Protobuf round-trip tests
  messaging_test.nim    # Wave envelope handling and introspection tests
```

---

# 24. Data Handling and Validation Specification

**REQ:** Data Handling and Validation Best Practices
**Source:** REQUIREMENTS § Data Handling and Validation Best Practices

### 24.1 Input Validation Strategy

All **public procedures** must validate inputs at the boundary:
- Type correctness: leverage Nim's static type system.
- Structure validity: ensure records and collections conform to expected shape.
- Value bounds: numeric ranges, string non-emptiness, collection size limits.
- Preconditions: verify runtime state is correct (e.g., instance attached, module loaded).

Validation must be **fail-fast**: reject invalid inputs immediately without downstream
processing of bad data.

### 24.2 Validation Implementation Rules

- Use **short-circuit evaluation**: stop immediately on first validation failure.
- Prefer **compile-time validation** (static types, generics, constraints) over runtime
  validation where possible.
- Cache validation results for repeated checks on the same data.
- Centralize reusable validation logic in helper procedures to avoid duplication.
- For hot-path operations (frame-loop critical), avoid expensive validation (e.g.,
  recursive traversal) unless justified. Document performance expectations.

### 24.3 Safe Data Handling

- Prefer **immutable data structures** (Nim `const`, `let`) for read-only data.
- Use **value types** (records, tuples) instead of reference types (objects, refs)
  to prevent unintended aliasing.
- Avoid **mutable shared state** between modules and instances; make mutations
  explicit and guarded by transaction boundaries.
- **Normalize data** before storage or transmission: strip whitespace, convert case,
  resolve symbolic references to canonical identifiers.
- **Validate invariants** after every mutation to ensure consistency.
- Use **scope management** (Nim `defer`, finalizers) to ensure resources are released
  even in the presence of errors.

### 24.4 Checksum Validation (Persisted Records)

Every **persisted record** must include a SHA256 checksum for integrity verification:

- Validate checksums **at load time** (startup, reconciliation, disk reads).
- Validate checksums **after every mutation** (recalculate and update persisted record).
- Validate checksums **during serialization round-trips** (after JSON/Protobuf deserialization).
- **Halt operations** on checksum validation failure with a structured error; never
  silently corrupt or skip data.

### 24.5 Type Safety

- Use **distinct types** to distinguish semantically different data (e.g., `EpochCounter`
  vs. `SchemaVersion`).
- Avoid `Any`, `object`, or `ref object` without strong justification; use concrete
  typed records.
- Use **dependent types** (generics, constraints) to encode invariants in the type
  (e.g., `NonEmptyString`, `ValidEpoch`).

### 24.6 Error Handling and Recovery

Validation failures must:
- Raise an exception with a **descriptive, actionable error message** including the
  invalid value (or summary) and the rule violated.
- **Sanitize error messages**: do not expose sensitive data (credentials, keys, personal info).
- Provide **recovery paths** for correctable errors (e.g., schema migration on version mismatch).
- **Halt unrecoverable operations** with a structured error and manual recovery suggestion.

### 24.7 Logging and Auditing

All **validation failures** must be logged with context:
- Input value (or hash/summary if sensitive).
- Validation rule violated.
- Stack trace (debug mode only).
- Timestamp and operation context (which proc failed).

Logging rules:
- **Never log sensitive data** (credentials, keys, personal info) even in debug mode;
  log hashes or metadata instead.
- In **production mode** (`mode = "production"`), suppress verbose debug logs; retain
  only error and warning logs.

### 24.8 Alignment with Confidentiality and Opacity

Input validation and safe data handling must support the **Confidentiality and Opacity**
principle:
- Ensure invalid or corrupted data cannot leak information across instance boundaries
  or to unauthorized observers.
- Make validation **deterministic**: given the same input, validation produces the
  same result always.

### 24.9 Validating Prefilter Runtime Specification

**REQ:** Validating Prefilter Requirements
**Source:** docs/implementation/Chapter2/VALIDATION-FIREWALL-REQUIREMENTS.md

The validating prefilter is a runtime boundary gate. It must execute before both
dispatch and Occurrence recording. No bypass path is permitted.

### 24.10 Validating Prefilter Data Structures

#### 24.10.1 Signature Key

The runtime must represent each callable contract using a stable key:

```nim
type
  SignatureDigest128 = array[16, byte]

  ValidationSignatureKey = object
    namespaceId: string          ## Module or logical namespace.
    symbolId: string             ## Proc/function exported symbol.
    arity: uint8                 ## Declared argument count.
    contractVersion: uint16      ## Increment when contract changes.
    canonicalTypeVector: seq[string]
    canonicalDigest: SignatureDigest128
```

Canonical digest derivation:

1. Build canonical preimage string:
   `namespaceId|symbolId|arity|contractVersion|type1,type2,...`.
2. Normalize all tokens to NFC UTF-8, lower-case for identifiers only.
3. Compute SHA-256.
4. Use the first 16 bytes as `canonicalDigest`.

Stability guarantees:

- Same namespace/symbol/arity/type vector/contract version -> same digest.
- Build path, compiler flags, and object addresses must not influence digest.
- Contract-changing edits must increment `contractVersion` or change type vector.
- Digest collisions must fail table generation.

#### 24.10.2 Validation Record

Each signature key maps to one validation record:

```nim
type
  ExtraFieldPolicy = enum
    efRejectUnknown
    efIgnoreUnknown
    efAllowUnknown

  OrderingPolicy = enum
    opNotRelevant
    opStableSequence

  FieldRule = object
    path: string                 ## Dot-path, example: payload.user.id
    typeId: string               ## Canonical type token.
    required: bool
    nullable: bool
    minItems: Option[uint32]
    maxItems: Option[uint32]

  ArgumentRule = object
    position: uint8
    typeId: string
    required: bool
    fields: seq[FieldRule]
    orderingPolicy: OrderingPolicy
    extraFieldPolicy: ExtraFieldPolicy

  ValidationRecord = object
    keyDigest: SignatureDigest128
    argCount: uint8
    args: seq[ArgumentRule]
    schemaDigest: SignatureDigest128
    invariants: seq[string]      ## Structural only, never behavioral.
    masks: seq[ValidationMask]   ## One per argument, precomputed at build time.
```

Structural invariants:

- `argCount == args.len`.
- `ArgumentRule.position` values are contiguous from `0 ..< argCount`.
- `FieldRule.path` values must be unique per argument.
- All `required=true` fields must have explicit `typeId`.

Binary layout (for optional persisted cache artifact):

- Header (fixed, little-endian):
  - magic[4] = `PREF`
  - formatVersion u16
  - recordCount u32
  - stringTableOffset u32
  - recordsOffset u32
- Record entry (fixed):
  - keyDigest[16]
  - schemaDigest[16]
  - argCount u8
  - argsOffset u32
  - invariantsOffset u32
- Variable sections use length-prefixed arrays (u32 length + payload).

Implementers may store only the in-memory form. If persisted, this layout is
required for deterministic cross-platform loading.

#### 24.10.3 Validation Index/Table

In-memory mapping:

```nim
type
  ValidationIndex = object
    byKey: Table[SignatureDigest128, ValidationRecord]
    generationId: string         ## Build or regeneration identifier.
```

Requirements:

- Lookup is `byKey[digest]` in O(1) expected time.
- Index is immutable after activation in runtime hot path.
- Index must be fully available before first dispatch.

Persistence/regeneration strategy:

- Preferred: compile-time generated Nim module containing const records.
- Optional: load binary cache then verify `schemaDigest` and `generationId`.
- If cache is missing or invalid, regenerate from canonical sources at startup
  before accepting ingress traffic.

#### 24.10.4 Validation and Payload Masks

The prefilter uses a mask-based comparison model for hot-path structural
validation. Two complementary masks encode structural expectations (build time)
and structural observations (runtime) in the same fixed-width bit layout.

##### Validation Mask (Build-Time Artifact)

```nim
type
  ValidationMask = object
    ## Fixed-width bitmask precomputed from a ValidationRecord at build time.
    ## Encodes all structural expectations for one signature key.
    requiredPresence: seq[byte]  ## Bit per field position: 1 = required.
    typeConstraints: seq[byte]   ## Bit regions encoding expected type class.
    orderingBit: bool            ## True if sequence ordering is meaningful.
    cardinalityBits: seq[byte]   ## Set bits where min/max item bounds apply.
    width: uint16                ## Total mask width in bits. Fixed at build time.
```

Generation rules:

- Derived deterministically from the `ArgumentRule` and `FieldRule` sequences in
  the owning `ValidationRecord`.
- One bit per declared field position in `requiredPresence`; bit is set when
  `FieldRule.required == true`.
- Type-constraint bit regions use a predefined type-class enumeration. Bit layout
  is fixed per signature at build time.
- `orderingBit` is set when `ArgumentRule.orderingPolicy == opStableSequence`.
- `cardinalityBits` are set for fields declaring `minItems` or `maxItems`.
- Mask width is fixed at build time and must not grow at runtime.
- No heuristic or inferred bits are permitted.

##### Payload Mask (Runtime Artifact)

```nim
type
  PayloadMask = object
    ## Fixed-width bitmask computed at runtime from an inbound payload.
    ## Uses the same bit layout as the corresponding ValidationMask.
    fieldPresence: seq[byte]     ## Bit per field position: 1 = present.
    typeObserved: seq[byte]      ## Bit regions encoding observed type class.
    orderingBit: bool            ## True if payload ordering is intact.
    cardinalityBits: seq[byte]   ## Set bits reflecting observed sizes.
    width: uint16                ## Must equal ValidationMask.width.
```

Runtime rules:

- Computed per inbound message using the same bit layout as the corresponding
  `ValidationMask`.
- Must not allocate. Use pre-allocated scratch buffers or stack-resident arrays.
- Must not depend on dynamic schema parsing.
- `width` must equal the corresponding `ValidationMask.width`.

##### Boolean Conjunction Comparison

Structural validation for each argument is expressed as:

```
pass = (validationMask AND payloadMask) == validationMask
```

Interpretation:

- Every bit that is set in the validation mask must also be set in the payload
  mask. If so, the payload satisfies all required-presence, type-constraint,
  ordering, and cardinality expectations.
- The comparison must be constant-time with respect to mask width. Implementations
  must not branch on individual bit positions.
- Bits set in `payloadMask` but not in `validationMask` represent extra fields:
  these are evaluated by the per-argument `ExtraFieldPolicy`, not by the mask
  comparison itself.
- If the conjunction check fails, the prefilter reports the first failing mask
  region to determine `ValidationFailureKind`.

### 24.11 Lifecycle

#### 24.11.1 Compile/Build-Time Generation

Source-of-truth inputs:

- callable signature declarations,
- canonical structural schemas,
- explicit contract versions.

Build algorithm:

1. Discover all dispatchable signatures and bound schema definitions.
2. Normalize type vectors and structural field paths.
3. Compute `ValidationSignatureKey.canonicalDigest`.
4. Build `ValidationRecord` for each signature.
5. Derive `ValidationMask` for each argument within each record: set
   required-presence bits, type-constraint bits, ordering bit, and cardinality
   bits from the corresponding `ArgumentRule` / `FieldRule` sequences.
6. Store masks in `ValidationRecord.masks`.
7. Verify uniqueness and structural invariants.
8. Emit generated artifact(s):
   - `prefilter_table_generated.nim` (required path),
   - optional binary cache using `PREF` layout.
9. Wire generated artifact into runtime startup automatically.

No manual copying is allowed between schema definitions and prefilter logic.

#### 24.11.2 Runtime Startup and Activation

Startup algorithm:

1. Load generated table artifact.
2. Verify generation metadata and record invariants.
3. Build immutable `ValidationIndex.byKey` map.
4. Atomically swap index into active runtime state.
5. Enable ingress and dispatch only after prefilter activation succeeds.

Failure to activate the prefilter must halt startup with a structured error.

#### 24.11.3 Runtime Ingress Flow

Ingress algorithm for each inbound message:

1. Resolve target callable identity (`namespaceId`, `symbolId`).
2. Read declared arity and input contract version.
3. Build canonical key preimage and compute digest.
4. Lookup `ValidationRecord` by digest in O(1) expected time.
5. If key is missing, produce prefilter-failure Occurrence and stop.
6. Validate argument count against `ValidationRecord.argCount`.
7. For each argument, compute a `PayloadMask` from the inbound payload using
   the bit layout defined by the corresponding `ValidationMask`.
8. Perform mask conjunction: `(validationMask AND payloadMask) == validationMask`.
   - If the conjunction holds for all arguments, structural validation passes.
   - If the conjunction fails, identify the first failing mask region to
     determine `ValidationFailureKind`.
9. Evaluate extra-field policy for bits set in `payloadMask` but not in
   `validationMask` (fields present but not declared).
10. On any failure (steps 5-9), emit failure Occurrence and stop.
11. On success, mark message `Validated` and continue.

No dynamic schema parsing is permitted in steps 4-11. Mask comparison in step 8
must be constant-time with respect to mask width.

#### 24.11.4 Dispatch and Recording Guarantees

Dispatch gate:

- Only messages in `Validated` state may enter proc/function invocation.
- Unvalidated or failed messages are never passed to user code.

Occurrence admission gate:

- Only structurally validated payloads may be persisted as normal domain
  Occurrences.
- Prefilter failures are persisted only as failure Occurrences.

### 24.12 Validating Prefilter Error and Failure Occurrence Semantics

Validation failure must be represented as a dedicated Occurrence type:

```nim
type
  ValidationFailureKind = enum
    vfUnknownSignature
    vfArgumentCountMismatch
    vfTypeMismatch
    vfMissingRequiredField
    vfUnknownFieldRejected
    vfOrderingViolation
    vfCardinalityViolation

  ValidationFailureOccurrence = object
    id: string
    source: string              ## runtime prefilter component id
    epoch: int
    targetKey: SignatureDigest128
    failureKind: ValidationFailureKind
    rulePath: Option[string]
    diagnosticsCode: string
    payloadDigest: SignatureDigest128
    payloadByteLen: uint32
```

Inclusion rules:

- Include only metadata, rule identifiers, and digests.
- Include offending path (`rulePath`) when safe and deterministic.

Exclusion rules:

- Do not include raw invalid payload bytes.
- Do not include secret-bearing field values.
- Do not include reconstructed payload fragments in user-visible errors.

Operator observability:

- Failure Occurrences are visible to runtime operators and audit tooling.
- They are not dispatch targets for user procs/functions by default.
- Optional operator handlers may consume them only through explicit runtime
  introspection channels.

### 24.13 Validating Prefilter No-Copying and Regeneration Contract

Rules:

- Prefilter records must be generated from canonical signatures and schemas.
- Hand-maintained duplicate prefilter tables are forbidden.
- Runtime behavior must not depend on manually copied schema snippets.

Drift prevention:

- Generated artifact must include source digest list.
- Startup must verify source digest compatibility.
- Mismatch must trigger regeneration (pre-ingress) or startup failure.

Regeneration modes:

- Build mode: generate artifacts as part of normal build pipeline.
- Startup mode: regenerate once when artifacts are absent or stale.

Both modes must produce byte-equivalent records from equivalent source inputs.

### 24.14 Validating Prefilter Performance and Constraints

Performance requirements:

- Key lookup: O(1) expected per inbound message.
- Structural validation: mask conjunction — constant-time with respect to mask
  width per argument, O(n) over `n` arguments.
- Payload mask computation: O(f) where `f` = number of payload fields observed;
  no allocation permitted.
- No dynamic schema parsing on hot path.

Constraints:

- No reflection-based guessing of schema.
- No heuristic validation.
- No auto-correction or silent mutation.
- No fallback path that dispatches unvalidated data.
- No runtime mask-width extension.

Textual lifecycle diagrams:

- Build flow:
  - discover signatures + schemas -> normalize -> hash -> derive validation
    masks -> emit table -> link.
- Startup flow:
  - load generated table -> verify digests -> activate immutable index -> open
    ingress.
- Ingress flow:
  - resolve signature -> lookup record -> compute payload mask -> mask AND
    comparison -> success: dispatch and admit Occurrence; failure: emit
    ValidationFailureOccurrence.

Non-goals:

- Intent classification or abuse scoring.
- Runtime anomaly prediction.
- Implicit business-rule enforcement beyond declared structure.

---

# Licensed under the Wilder Foundation License 1.0. See LICENSE for details.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*