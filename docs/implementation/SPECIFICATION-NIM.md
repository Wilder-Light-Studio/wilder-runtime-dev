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
- **Bridges are membranes**: Bridges are Thing/World templates that become boundary translators when instantiated.
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
Binary naming is platform-scoped: `cosmos.exe` on Windows and `cosmos` on
non-Windows platforms.

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

# 19A. Binary Build, Installer, and Release Tooling Phase Specification

**REQ:** Project Phase: Binary Build, Installer, and Release Tooling

### 19A.1 Build Matrix and Artifact Contract

- CI must build release artifacts for:
  - `windows-amd64`
  - `linux-amd64`
  - `linux-arm64`
  - `darwin-amd64`
  - `darwin-arm64`
- Every build job must produce:
  - runtime binary payload containing canonical `cosmos.exe`
  - installer payload for the target platform
  - SHA-256 checksum file for each distributable artifact
  - machine-readable release manifest entry
- Build output identity must include version, git commit, target triple, and UTC build
  timestamp.

### 19A.2 Installer Modes and Filesystem Layout Contract

Installers must support two explicit modes:
- `user`: install under user-home paths.
- `system`: install under shared system paths.

Canonical runtime home tree (per install mode root) must include:

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

Mode-specific root mapping:
- Windows user mode: `%USERPROFILE%\\.wilder\\cosmos\\`
- Windows system mode: `%ProgramData%\\Wilder\\Cosmos\\`
- Linux/macOS user mode: `~/.wilder/cosmos/`
- Linux/macOS system mode: `/var/lib/wilder/cosmos/`

Installers must create required directories idempotently and preserve existing user data.

### 19A.3 Entrypoint Canonicalization Contract

- The canonical startup executable name is always `cosmos.exe` on every supported OS.
- Runtime invocation paths, wrappers, package launch scripts, and symlink targets must
  terminate at `cosmos.exe`.
- If a compatibility alias is provided (for example `cosmos`), it must be a thin
  delegator to `cosmos.exe` and must not bypass runtime bootstrap logic.
- Both `user` and `system` installs must expose `cosmos.exe` on-demand via explicit path
  and optional PATH integration.

### 19A.4 PATH Integration and Uninstall Contract

- Installers must offer opt-in PATH integration during install.
- PATH mutation must be scoped to user environment for `user` mode and machine
  environment for `system` mode.
- Uninstall must remove:
  - installed binaries and wrappers
  - PATH entries added by installer
  - installer-generated manifests and metadata
- Uninstall must not delete user-created project content under `projects/` or outside
  runtime home.
- After uninstall, no installer-owned files may remain in install targets.

### 19A.5 Application Scaffold Command Contract (`cosmos.exe startapp`)

`cosmos.exe startapp` must execute deterministic scaffold generation with interactive
prompts.

Required behavior:
1. Accept optional target path argument; default to current working directory.
2. Prompt for app name, runtime mode, transport, and initial module set.
3. Show defaults for every prompt and allow accept-by-enter.
4. Validate destination path writability before generation.
5. Generate scaffold atomically (temporary staging then rename/move).
6. Emit a completion summary containing generated paths and next commands.
7. Exit `0` on success; non-zero with structured error on validation or IO failure.

Generation must be location-agnostic: users may create projects in any writable path.

### 19A.6 Signing, Publishing, Versioning, and Channels Contract

- Release pipeline stages must execute in this order:
  1. build
  2. package
  3. sign
  4. verify-signature
  5. publish
- Signing must support:
  - Authenticode (Windows)
  - Developer ID or equivalent notarized signing for macOS distributions
  - detached signature files for Linux artifacts
- Publishing must produce channel-separated outputs at minimum for `stable` and
  `preview`.
- Versioning must be sourced from `.nimble` and enforce monotonic release progression
  per channel.
- Each published artifact must include checksum, signature data, and source provenance
  (commit, tag, build job id).

### 19A.7 Automation and Compliance Execution Contract

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
- CI compliance tests must fail if:
  - a required target in the build matrix is missing
  - `cosmos.exe` is absent from any package
  - installer mode behavior deviates from path contract
  - uninstall leaves installer-owned residue
  - manifest schema or required fields are missing

---

# 20. Archive Completeness Specification

- no external dependencies
- full offline build/test capability

---

# 21. Runtime Configuration Specification

**REQ:** Runtime Configuration Requirements
**Source:** Cue schema → exported JSON/YAML → loaded at startup into Nim types.

### 21.1 Schema Fields

| Field      | Type   | Values                                      | Default       |
|------------|--------|---------------------------------------------|---------------|
| `mode`     | string | `"debug"` \| `"production"`                 | `"debug"`     |
| `transport`| string | `"json"` \| `"protobuf"`                    | `"json"`      |
| `logLevel` | string | `"trace"` \| `"debug"` \| `"info"` \| `"warn"` \| `"error"` | `"info"` |
| `endpoint` | string | non-empty hostname or address               | `"localhost"` |
| `port`     | int    | `1–65535`                                   | `7700`        |

### 21.2 Validation Rules
- `mode = "production"` must reject `logLevel ∈ {"trace", "debug"}`.
- `port` must be in range `[1, 65535]`.
- `endpoint` must be a non-empty string.
- All other invalid combinations must produce a structured error at config-load time.

### 21.3 Nim Config Type
The loaded config must map to a single Nim record passed to all subsystems:

```nim
type
  RuntimeMode    = enum rmDebug, rmProduction
  TransportKind  = enum tkJson, tkProtobuf
  LogLevel       = enum llTrace, llDebug, llInfo, llWarn, llError

  RuntimeConfig = object
    mode:      RuntimeMode
    transport: TransportKind
    logLevel:  LogLevel
    endpoint:  string
    port:      int
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
- Supported environment variable overrides include `COSMOS_MODE`, `COSMOS_LOG_LEVEL`, and `COSMOS_PORT`.
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
**Source:** docs/implementation/Chapter2/VALIDATION-MEMBRANE-REQUIREMENTS.md

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