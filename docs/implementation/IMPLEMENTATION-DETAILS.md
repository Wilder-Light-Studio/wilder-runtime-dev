# WILDER COSMOS RUNTIME — IMPLEMENTATION DETAILS

*Implementation-level reference for the Wilder Cosmos Runtime.*
*The canonical specification lives in `docs/implementation/SPECIFICATION.md`.*
*This document provides Nim types, API signatures, storage layouts, reconciliation*
*algorithms, and operational guidance that support the specification.*

---

## Public API (Nim Signatures)

Design for simplicity and safe defaults. API must be thoroughly documented and
ND-friendly (see `docs/implementation/COMMENT_STYLE.md`). All public APIs must include beginner
comments, similes, and memory notes.

Core types and functions:

```nim
type
  ModuleContext* = object
    name*: string
    state*: ref ModuleState
    host*: HostBindings

  HostBindings* = object
    sendMessage*: proc (toModule: string, payload: JsonNode): Future[JsonNode]
    getTime*: proc (): int
    storageRead*: proc (key: string): Option[seq[byte]]
    storageWrite*: proc (key: string, value: seq[byte]): bool
    # Streaming snapshot APIs (for blobs > 64KB):
    exportSnapshot*: proc (dest: Stream): bool
    importSnapshot*: proc (src: Stream): bool
    streamModuleBlob*: proc (moduleName: string, chunkSize: int, onChunk: proc (data: seq[byte])): bool
    writeModuleBlob*: proc (moduleName: string, chunkSize: int, onChunk: proc (): seq[byte]): bool

  ReconcileResult* = object
    success*: bool
    layersUsed*: seq[string]
    messages*: seq[string]

  ModuleState* = object
    name*: string
    version*: string
    data*: JsonNode
    lastUpdated*: int
    schemaVersion*: int
    memoryCap*: int
    resourceBudget*: Table[string, int]

  RuntimeState* = object
    modules*: Table[string, ModuleState]
    metadata*: Table[string, string]
    epoch*: int

proc registerModule*(name: string, init: proc (ctx: var ModuleContext), handle: proc (ctx: var ModuleContext, msg: JsonNode): JsonNode)
proc callModule*(sender: string, to: string, payload: JsonNode): JsonNode
proc getState*(ctx: ModuleContext, path: string): Option[JsonNode]
proc setState*(ctx: ModuleContext, path: string, value: JsonNode)

# Streaming read/write for large records (avoids large in-memory copies)
proc storageReadStream*(key: string, handler: proc (chunk: seq[byte])): bool
proc storageWriteStream*(key: string, writer: proc (write: proc (chunk: seq[byte]))): bool

# Backend reconciliation hooks
proc reconcileRecord*(key: string): ReconcileResult
```
## Input Validation and Type Safety

**All public procedures must validate inputs.** Use these patterns:

1. **Numeric bounds:** validate ranges at the start of the proc.
   ```nim
   proc config__setPort(port: int): bool =
     if port < 1 or port > 65535:
       raise newException(ValueError,
         "Port must be in range [1, 65535]")
     return true
   ```

2. **String non-emptiness:** check immediately.
   ```nim
   proc thing__setName(name: string): bool =
     if name.len == 0:
       raise newException(ValueError,
         "Name cannot be empty")
     return true
   ```

3. **Structure validation:** validate JSON/record shape before processing.
   ```nim
   proc message__dispatch(msg: JsonNode): bool =
     if "type" notin msg or "payload" notin msg:
       raise newException(ValueError,
         "Message missing required fields")
     return true
   ```

4. **Checksum validation:** validate persisted data on load.
   ```nim
   proc state__loadRecord(key: string): Option[JsonNode] =
     let data = readFromPersistence(key)
     if not validateChecksum(data, data.checksum):
       raise newException(ValueError,
         "Checksum mismatch for record: " & key)
     return some(data)
   ```

Use **reusable helper procedures** in `runtime/validation.nim` to avoid duplication.
For hot-path operations, document performance expectations and avoid expensive
validation (e.g., recursive traversal) unless justified.

### Validating Prefilter Runtime Gate

The validating prefilter is a mandatory boundary gate between ingress and both:

- proc/function dispatch, and
- normal domain Occurrence admission.

#### Core Prefilter Types

Implement or expose the following runtime types:

```nim
type
  SignatureDigest128* = array[16, byte]

  ValidationSignatureKey* = object
    namespaceId*: string
    symbolId*: string
    arity*: uint8
    contractVersion*: uint16
    canonicalTypeVector*: seq[string]
    canonicalDigest*: SignatureDigest128

  FieldRule* = object
    path*: string
    typeId*: string
    required*: bool
    nullable*: bool
    minItems*: Option[uint32]
    maxItems*: Option[uint32]

  ArgumentRule* = object
    position*: uint8
    typeId*: string
    required*: bool
    fields*: seq[FieldRule]

  ValidationMask* = object
    ## Precomputed at build time from ArgumentRule / FieldRule sequences.
    requiredPresence*: seq[byte]  ## Bit per field position: 1 = required.
    typeConstraints*: seq[byte]   ## Bit regions encoding expected type class.
    orderingBit*: bool            ## True if sequence ordering is meaningful.
    cardinalityBits*: seq[byte]   ## Set bits where min/max item bounds apply.
    width*: uint16                ## Total mask width in bits. Fixed at build time.

  PayloadMask* = object
    ## Computed at runtime from inbound payload; same bit layout as ValidationMask.
    fieldPresence*: seq[byte]
    typeObserved*: seq[byte]
    orderingBit*: bool
    cardinalityBits*: seq[byte]
    width*: uint16

  ValidationRecord* = object
    keyDigest*: SignatureDigest128
    argCount*: uint8
    args*: seq[ArgumentRule]
    schemaDigest*: SignatureDigest128
    masks*: seq[ValidationMask]   ## One per argument, precomputed at build time.

  ValidationIndex* = object
    byKey*: Table[SignatureDigest128, ValidationRecord]
    generationId*: string
```

Canonical digest generation must be deterministic and independent of build path,
object addresses, or compiler flags. Contract-changing edits must change either
`contractVersion` or the canonical type vector.

#### Mask-Based Structural Validation

Hot-path structural validation uses precomputed validation masks compared against
runtime payload masks via boolean conjunction.

- **Build time**: derive a `ValidationMask` for each argument in each
  `ValidationRecord`. Set required-presence, type-constraint, ordering, and
  cardinality bits from the corresponding rules. Store in `ValidationRecord.masks`.
- **Runtime**: compute a `PayloadMask` from the inbound payload for each argument.
  Payload mask computation must not allocate and must not parse schemas dynamically.
- **Comparison**: `(validationMask AND payloadMask) == validationMask`. If the
  conjunction holds, the payload satisfies all structural expectations. The
  comparison must be constant-time with respect to mask width.
- **Extra fields**: bits set in `payloadMask` but not in `validationMask` are
  evaluated by the per-argument `ExtraFieldPolicy`.
- **Failure diagnosis**: on conjunction failure, the first failing mask region
  determines `ValidationFailureKind`.

#### Generation and Activation

- Build-time source-of-truth inputs:
  - callable signatures,
  - canonical structural schemas,
  - contract versions.
- Generate `src/runtime/prefilter_table_generated.nim` automatically, including
  precomputed validation masks per record.
- Runtime startup must:
  1. load generated table,
  2. verify invariants, digests, and mask widths,
  3. build immutable O(1) lookup map,
  4. activate prefilter before ingress opens.

Startup must fail with a structured error if the prefilter table cannot be
validated and activated.

#### Ingress and Dispatch Contract

Per inbound message:

1. Resolve target signature identity.
2. Compute canonical signature digest.
3. Lookup `ValidationRecord` in O(1) expected time.
4. Validate argument count.
5. For each argument, compute `PayloadMask` from the inbound payload.
6. Perform mask conjunction: `(validationMask AND payloadMask) == validationMask`.
7. Evaluate extra-field policy for undeclared fields.
8. On any failure, short-circuit and emit validation-failure Occurrence.
9. On success, mark payload `Validated` and allow dispatch/admission.

Guarantees:

- no unvalidated payload reaches user code,
- no unvalidated payload becomes a normal domain Occurrence,
- mask comparison is constant-time with respect to mask width,
- payload mask computation does not allocate.

#### Failure Occurrence Rules

Validation failures must be persisted as explicit failure Occurrences containing:

- target signature digest,
- failure kind,
- violated rule path or rule identifier,
- payload digest and size metadata.

Failure occurrences must not include raw invalid payload bytes or secret-bearing
field values.

## Naming Conventions

- Module and public proc names should follow the `typeObject__verb()` pattern. Use a double underscore to separate the type/module from the action (for example: `counter__increment()`, `ledger__commit()`, `playground__dispatch()`).
- Use lowercase and clear, imperative verbs. Prefer explicit verbs over vague names like `handle` for exported procs.
- When an API signature expects a `handle` parameter (for example `registerModule(..., handle: proc ...)`), implement your exported proc using `typeObject__verb()` and pass it as the `handle` argument. Example:

```nim
proc counter__handleMessage(ctx: var ModuleContext, msg: JsonNode): JsonNode =
  # implementation

registerModule("counter", initCounter, counter__handleMessage)

## Formatting and Line Length

-- Source and example lines should be wrapped at 80 characters to improve
  readability in diffs and narrow terminals. Apply wrapping to Nim source, code
  examples in Markdown, and function signatures. Use automated tools where
  available and prefer breaking after logical separators when splitting long
  signatures.
```

API rules:
- All host interactions are explicit via `HostBindings`.
- **All public procs must validate inputs** at the boundary. Validation must be fail-fast
  and centralized in reusable helper procedures (see `runtime/validation.nim`).
- Mutations to persisted state must occur through `setState` to ensure transactionality
  and change tracking. After mutation, invariants must be re-validated.
- Module registration is static at startup; dynamic registration supported via
  well-documented hooks.
- Private procedures may assume correctness of inputs transferred from validated public procs;
  validation at private proc boundaries is optional.
- **Persisted records** must include SHA256 checksums and validate checksums at load time,
  after mutation, and during serialization round-trips.

---

## Core Modules

- `runtime/core.nim`
  - Bootstrapping, lifecycle, and host binding.
  - Responsibilities: initialize `RuntimeState`, load modules, dispatch messages/events.

- `runtime/persistence.nim`
  - Abstract `PersistenceBridge` interface with concrete implementations:
    - `FileBridge` (local JSON/CBOR)
    - `SqliteBridge` (optional)
    - `InMemoryBridge` (for tests)
  - Exposes: `loadState()`, `saveState()`, `beginTransaction()`, `commit()`, `rollback()`.

- `runtime/config.nim`
  - `RuntimeMode`, `TransportKind`, `LogLevel`, `RuntimeConfig` types.
  - `loadConfig(path: string): RuntimeConfig` — loads, validates, and returns config.
  - Called once at startup; result injected into all subsystems.

- `runtime/messaging.nim`
  - `MessageEnvelope` dispatch and routing.
  - Debug introspection: full envelope logging in `debug` mode.
  - Wires active `Serializer` (from config) to all outbound/inbound messages.

- `runtime/serialization.nim`
  - Versioned serialization envelopes.
  - Supports JSON (human readable), CBOR (compact), and Protobuf (production transport).
  - Utility functions: `serialize[T]`, `deserialize[T]`, `envelopeWrap`, `envelopeUnwrap`.
  - `SerializerKind`, `Serializer` abstraction, `encode*`, `decode*` for transport switching.

- `runtime/api.nim`
  - Public-facing runtime API signatures for modules.
  - Input validation at all public proc boundaries.
  - Type-safe distinct types for domain-specific values.

- `runtime/validation.nim`
  - Reusable validation helper procedures.
  - `validateNonEmpty(s: string): bool` — ensure non-empty string.
  - `validateRange(v: int, min: int, max: int): bool` — ensure numeric bounds.
  - `validateStructure(n: JsonNode, schema: string): bool` — validate JSON structure.
  - `validateChecksum(data: seq[byte], expected: string): bool` — verify SHA256 checksum.
  - All validation helpers are deterministic and report clear errors.

- `runtime/prefilter_table_generated.nim`
  - Build-generated prefilter table artifact.
  - Source of runtime prefilter contracts (no manual copying).
  - Loaded and verified before ingress/dispatch activation.

- `runtime/console.nim`
  - Console, attach/detach protocol, and tooling.

- `runtime/testing.nim`
  - Test harnesses, deterministic RNG, state snapshots.

---

## Persistence Implementation

### Three-Layer Redundancy (Detailed)

Storage layers:
- **Primary:** Configured persistence backend (FileBackend/Sqlite/cloud) — stores the
  current authoritative state as a complete, checksummed record.
- **Secondary:** Append-only transaction log (txlog) — stores an ordered sequence of
  state-changing operations. Not a full copy; its checksum covers the log integrity,
  not the record payload directly.
- **Tertiary:** Periodic signed snapshots stored separately (`snapshots/` or remote
  backup) — stores complete, checksummed point-in-time copies.

Persisted records include Thing Status (see Status Model) and are subject to Memory
bounds (see Memory Model). Status invariants must be re-validated after any
reconciliation or migration that modifies persisted state.

### Detailed Reconciliation Scenarios

**When two or more full-copy layers are available (primary + tertiary):**
1. If checksums agree, accept the agreed value.
2. If checksums differ but `schemaVersion` matches, prefer the highest epoch and log
   the decision.
3. If both `schemaVersion` and epoch differ, halt module load, surface an explicit error,
   and provide an automated repair plan.

**When only one full-copy layer is available plus the txlog:**
1. Validate the full-copy layer's checksum.
2. Validate txlog integrity (sequential checksums).
3. Replay the txlog from the last known-good epoch of the full copy to reconstruct
   current state.
4. If the txlog is incomplete or corrupt, halt module load and flag for operator review.

**When all three layers are available:**
1. Compare primary and tertiary checksums first (full-copy comparison).
2. If they agree, accept and verify the txlog is consistent (no gaps). Log any txlog
   divergence as a warning but do not block.
3. If they disagree, use the txlog to determine which full copy is more recent, prefer
   the one consistent with the txlog sequence, and log the decision.

Operational guarantees:
- Rebuild from any two layers must be possible; rebuild from a single layer must be
  possible when accompanied by a valid txlog and snapshot metadata.
- Snapshots and txlogs must be signed and checksummed; signatures verified before
  acceptance.
- Each layer must be independently checksummed and validated on access.
- Per-module in-memory soft cap: 1MB. Exceptions must be documented in module metadata.
- Streaming Application Programming Interfaces (APIs) must be used for blobs larger than 64 KB.
- All recovery and reconciliation operations must be logged and testable.

### ACID-Like Transaction Semantics

Single-instance semantics:
- `beginTransaction()` returns a transaction context.
- `commit()` persists all changes atomically (backend dependent).
- `rollback()` reverts in-memory changes for the transaction.

### Storage Layout (FileBackend)

On-disk layout:
- Top-level directory: `state/`
  - `runtime.json` (or `runtime.cbor`) — runtime envelope with version + state.
  - `modules/` — per-module data:
    - `{moduleName}.json` — primary layer (human-readable state).
    - `{moduleName}.meta` — reconciliation metadata (schemaVersion, epoch, checksum, origin).
  - `txlog/` — append-only transaction log (secondary layer) for recovery.
  - `snapshots/` — periodic signed snapshots (tertiary layer).

### Migration Strategy

- Each `ModuleState` has a `schemaVersion`.
- Migrations registered as `migrate_vN_to_vNplus1(modState: var ModuleState)` and
  executed on load if needed.

### Backup & Recovery

- Provide atomic snapshot export and import tools using streaming for large blobs.
- Validate snapshots and layers using checksums stored in metadata.
- Reconciliation API must be exposed for deterministic rebuild from available layers.

### Persistence Testing & Acceptance

- Unit and integration tests must simulate single-backend failure, bit-rot, and partial
  writes.
- Acceptance requires automated rebuild success when any one layer is removed or
  corrupted; reconciliation logs and repair instructions must be produced.

---

## Serialization Implementation

- Versioned envelope structure:
  - `envelope = { "format": "nim-runtime", "version": 1, "payloadType": "runtimeState", "payload": <bytes/base64 or nested JSON>, "checksum": "<sha256>" }`
- Supported formats:
  - Primary: JSON (for visibility)
  - Secondary: CBOR (for size and speed)
- Type mapping:
  - Nim primitives → JSON types (strings, numbers, booleans, arrays, objects)
  - Binary blobs → base64 within JSON envelope or raw bytes in CBOR
- Backward/forward compatibility:
  - Additive fields allowed.
  - Unknown fields preserved in `raw` maps where possible.
  - Mismatched schema triggers migration workflow or error, depending on the configured
    policy.
- Serialization must handle Status fields (see Status Model) and respect declared
  Memory bounds when deserializing (see Memory Model).

---

## Console Implementation

### Instance Binding

- Each Console session or tab is bound to exactly one Cosmos instance at a time.
- The Console process may attach and detach freely, but no session may observe more
  than one instance simultaneously.
- No cross-instance queries are permitted.
- The Console must never leak or infer information about other instances.
- Multiple tabs or windows may each attach to different instances simultaneously.

### Runtime Startup Banner

The runtime process itself (not the Console) prints a one-line status banner to stdout
on startup, before the Console prompt appears or any instance is attached. This is a
process-level diagnostic line. It is printed once and is not part of the Console's
three-layer rendering.

Minimum fields:
- Runtime version
- Runtime mode (Production, Development, Debug)
- Active modules count
- Persistence backend in use
- Reconciliation layer status (OK, Degraded, Rebuilding)
- Snapshot/txlog availability
- Last successful commit epoch

Example (single line):
```
[Cosmos Runtime v0.0.0] Mode=Development | Modules=4 | Backend=FileBackend | Reconcile=OK | Epoch=128 | Snapshots=Enabled
```

### Three-Layer Rendering (Detailed)

**Layer 1 — Status Bar** (top line)

Fields in order: frame number, thing count, tempo state, scheduler state, runtime
active/inactive flag. Additional global metrics may be appended as the system evolves.

When no instance is attached: `[no instance]`

Example:
```
F:1024  Things:42  Tempo:Running  Sched:Active  Active
```

**Layer 2 — Scope Line** (second line)

Format: `(NAMESPACE:CHILD)` — the Thing namespace the user is currently inside.
Initialized to the instance root Thing on attach. Reset to `(none)` on detach.

**Layer 3 — Prompt Line** (third line)

Format: `/path/dir/inside/the/thing>` — the filesystem-like path within the current
Thing. Initialized to `/` on attach. Reset to `>` (neutral) on detach.

### `ls` Output Rendering

- One entry per line, flat list, no headers, no sections, no indentation.
- Things: `[ThingScope]/`
- Directories: `Name/`
- Virtual directories: `*Name/`
- Files: `Name`

### Attach/Detach Protocol (Detailed Steps)

**Attach sequence** (`attach <instance>`):

1. Verify instance identity.
2. Negotiate permissions: read-only or read-write.
3. Negotiate capabilities: what the Console may introspect or mutate.
4. Bind to the instance.
5. Initialize layout: status bar starts streaming; scope → root Thing; prompt → `/`.

**Detach sequence** (`detach`):

1. Flush pending output.
2. Cancel all active `watch` streams.
3. Clear instance-bound caches.
4. Unbind from the instance.
5. Reset layout: scope → `(none)`; prompt → `>`; status bar → `[no instance]`.

### `watch` Full-Screen Mode

When `watch <bus|wave>` is active:

1. The three-layer layout suspends.
2. Stream output fills the terminal from the top.
3. On `Ctrl+C` (or configurable timeout): the stream cancels, the layout re-renders
   from the top, and normal command dispatch resumes.

### Console Command Reference (Full)

Navigation: `ls`, `cd`, `pwd`

Introspection: `info`, `peek <thing>`, `watch <bus|wave>`, `state`, `specialists`,
`delegations`, `world`, `claims`

Execution: `run <action>`, `set <field> <value>`, `call <method> [args]`

Instance Management: `attach <instance>`, `detach`, `instances`

Ergonomics: `help`, `clear`, `exit`

Preconditions:
- `attach`, `instances`, `help`, `clear`, `exit`: available without an attached instance.
- All other commands require an attached instance.

---

## Ontology Implementation

### Concept Fields

A Concept is persisted, versioned (`schemaVersion`), and validated at load time.

Minimal requirement:
- **Identity** — unique Concept id
- **WHY** — purpose or description

Declared sections:
- **Identity** — name, type, unique identifier.
- **Location** — spatial or logical placement rules.
- **Perception** — filters defining what Occurrences this Thing can perceive.
- **Emission** — what Occurrences this Thing can project.
- **Tempo** — cadence, tick rate, temporal behavior.
- **Status** — schema for the Thing's mutable interior.
- **Interrogative Manifest** — optional full contract surface.

### Occurrence Fields

```nim
type
  Occurrence* = object
    id*: string
    source*: string
    epoch*: int
    payload*: JsonNode
    projectionRadius*: float
```

### Perception Fields

```nim
type
  Perception* = object
    occurrenceId*: string
    thingId*: string
    epoch*: int
    filtered*: JsonNode
```

### Thing Fields and Lifecycle

```nim
type
  Thing* = object
    id*: string
    conceptId*: string
    status*: JsonNode
    perceptionLog*: seq[Perception]
    epoch*: int
    metadata*: Table[string, string]
```

Thing lifecycle:
1. **Instantiation:** Created from a Concept. Status initialized to Concept defaults.
   Perception filters activated. Registered in the world graph.
2. **Active:** Participates in the frame loop. Perceives, updates status, emits.
3. **Destruction:** Removed from the world graph. Final status snapshot persisted.
   Perception filters deactivated.

Minimal Thing validity requires only `id`.

---

## Interrogative Manifest (Nim Type)

```nim
type
  InterrogativeManifest* = object
    who*: string
    what*: string
    why*: string
    where*: string
    when*: string
    how*: string
    requires*: seq[string]
    wants*: seq[string]
    provides*: seq[string]
    with*: seq[string]
```

Behavior:

- A Concept may omit the manifest entirely.
- If a manifest is present, all ten interrogatives must be non-empty.
- Specialist validation applies when capability declarations are used and requires non-empty `PROVIDES` and `REQUIRES`.

---

## Delegation Implementation

### Delegation Occurrence (Nim Type)

```nim
type
  DelegationOccurrence* = object
    id*: string
    source*: string
    targetCapability*: string
    payload*: JsonNode
    epoch*: int

  DelegationResult* = object
    id*: string
    source*: string
    delegationId*: string
    payload*: JsonNode
    epoch*: int
    success*: bool
    error*: Option[string]
```

### Matching Algorithm

1. Scan active Things whose Concept's `PROVIDES` includes the `targetCapability`.
2. If exactly one specialist matches, deliver as a Perception.
3. If multiple match, select the one with the narrowest `PROVIDES` set (fewest
   capabilities). Ties broken lexicographically by Thing `id`. Decision logged.
4. If none match, emit a `DelegationResult` with `success = false`.

### Load-Time Validation

- Concepts without manifests are valid on identity plus WHY.
- A present manifest must be complete.
- Every Concept that declares `PROVIDES` must have non-empty `HOW` and `REQUIRES`.
- Capability strings in `PROVIDES` must be non-empty and unique within the Concept.
- Duplicate capability strings across Concepts are permitted but logged as a warning.

### Module Contract Authority

- Cosmos-native modules define contracts in code.
- Any native-module manifest is generated from code.
- External-process wrappers use handwritten manifests as the authoritative source.
- stdin/stdout wrappers are valid external Things and do not require rewrites into Cosmos-native code.

---

## World Ledger Implementation

The World Ledger stores structural references and relational claims between Things.
It is append-only and persisted within the three-layer persistence model.

### Reference Types

```nim
type
  LedgerReference* = object
    id*: string
    sourceThingId*: string
    targetThingId*: string
    edgeType*: string           ## e.g., "parent", "spatial", "logical"
    epoch*: int
    metadata*: Table[string, string]
```

### Claim Types

```nim
type
  LedgerClaim* = object
    id*: string
    assertingThingId*: string
    subject*: string            ## Thing ID or world-level identifier
    predicate*: string
    value*: JsonNode
    epoch*: int
    signature*: string          ## Signed by the asserting Thing
```

### Ledger Invariants
- All mutations flow through Occurrences (no direct writes).
- References and claims are validated at load time.
- The World Graph is derived from ledger references.

---

## Scheduler & Tempo Implementation

### Tempo Types

Each Thing's Concept declares one of these tempo types:

- **Event** — Thing participates only when a matching Occurrence is perceived.
- **Periodic** — Thing participates at a fixed interval (e.g., every N frames).
- **Continuous** — Thing participates every frame.
- **Manual** — Thing participates only when explicitly triggered via Console command.
- **Sequence** — Thing participates in a declared order of steps, advancing on each
  activation.

Tempo type is declared in the Concept's Tempo section and validated at load time.

### Scheduler Loop (Per Frame)

1. Advance epoch.
2. Collect pending Occurrences (ordered by epoch).
3. For each Occurrence, evaluate perception filters against active Things.
4. Deliver Perceptions to matching Things.
5. Allow Things to update status and emit new Occurrences (respecting tempo type).
6. Enforce bounded execution — no single Thing may consume unbounded time.
7. Things must yield control cooperatively; no preemption.

### Error Boundaries

- If a Thing fails during a frame, the error is logged, the Thing is flagged, and
  the frame continues for other Things.
- A Thing that fails repeatedly (configurable threshold) is suspended from the
  frame loop with a structured error surfaced.
- Scheduler errors (e.g., epoch overflow) halt the runtime with a structured error.

---

## Startup Implementation (Detailed Steps)

1. **Load configuration and persistence backend.**
   Read runtime config (file or environment). Initialize the configured
   `PersistenceBridge` (FileBridge, SqliteBridge, etc.).

2. **Load runtime envelope and metadata.**
   Read `state/runtime.json` (or `.cbor`). Verify envelope checksum and
   `schemaVersion`. If the envelope is missing, initialize a fresh `RuntimeState`.

3. **Reconcile persisted layers.**
   For each module key, run the reconciliation strategy. Reconciliation must validate
   Status invariants and respect Memory bounds. If reconciliation fails for any module,
   halt startup and surface the error.

4. **Run migrations.**
   For each module whose persisted `schemaVersion` differs from the registered migration
   chain, execute migrations in order (`migrate_vN_to_vNplus1`). Migrations are
   transactional: if a migration fails, rollback and halt.

5. **Load modules in deterministic order.**
   Modules are loaded in lexicographic order by registered name. Each module's `init`
   proc is called with a valid `ModuleContext`.

6. **Initialize scheduler, tempo, and world graph.**
   Activate the frame scheduler and tempo clock. Construct the initial world graph
   from loaded Thing state.

7. **Begin frame loop.**
   Enter the main frame loop. The runtime is now `Active`.

---

## Memory Enforcement (Detailed)

- Memory bounds are checked at mutation time (not polled).
- When a module exceeds its `memoryCap`, the runtime must:
  1. Log a structured warning with the module name, current usage, and cap.
  2. Reject the mutation that would exceed the cap.
  3. Allow the module to continue operating within its current allocation.
- Repeated violations (configurable threshold) escalate to a structured error.
- Memory usage per module and per Thing must be queryable via the Console's `state`
  command.
- The runtime startup banner should include total memory allocation.

---

## Runtime Configuration Implementation

### Config Schema (Cue)

Source: `config/runtime.cue`. Exported to JSON/YAML by `cue export` for consumption
by the Nim runtime. The Cue schema is the authoritative source; the Nim loader is
the consumer.

### Config Loading Contract
- `loadConfig(path: string): RuntimeConfig` reads the exported JSON file.
- All fields are validated immediately; an invalid config raises a structured error
  and halts startup.
- Sane defaults are applied for missing optional fields before validation.
- After `loadConfig()` returns, no subsystem reads the config file directly.

### Validation Rules (Nim)
- `mode = rmProduction` with `logLevel ∈ {llTrace, llDebug}` → structured error.
- `port` outside `[1, 65535]` → structured error.
- `endpoint` empty → structured error.

---

## Messaging System Implementation

### Proto Schema

Source: `proto/messaging.proto`. Defines `MessageEnvelope` and concrete payload
types. Field numbers are never reused; removed fields are reserved.

### Envelope Dispatch (Nim)
- `src/runtime/messaging.nim` receives a `MessageEnvelope` and dispatches by
  `type` field to the appropriate handler.
- In `debug` mode: the full envelope is logged before dispatch (JSON-rendered).
- In `production` mode: no logging overhead is incurred.
- The active `Serializer` (JSON or Protobuf) encodes/decodes all wire bytes.

### Forward Compatibility Rules
- New payload types are added as new `oneof` branches — never replacing existing ones.
- Existing field numbers are never changed or reused.
- Unknown payload types in `oneof` are logged as a warning and dropped gracefully.

---

## Serialization Transport Implementation

### Serializer Abstraction

```nim
type
  SerializerKind = enum skJson, skProtobuf

  Serializer = ref object of RootObj
    kind: SerializerKind

proc encode*(s: Serializer, msg: MessageEnvelope): seq[byte]
proc decode*(s: Serializer, data: seq[byte]): MessageEnvelope
```

### Serializer Factory
- Called once at startup after `loadConfig()`.
- `tkJson` → `JsonSerializer`.
- `tkProtobuf` → `ProtobufSerializer`.
- Result injected into all subsystems; no subsystem constructs its own serializer.

### JsonSerializer
- Uses Nim `json` module.
- Key order is deterministic (field declaration order).
- Round-trips all `MessageEnvelope` and payload fields without loss.
- Always used for filesystem bridge writes regardless of `transport` config.

### ProtobufSerializer
- Uses generated Nim bindings from `proto/messaging.proto`.
- Round-trips all `MessageEnvelope` and payload fields without loss.
- Only used when `transport = tkProtobuf`.

### Fallback Policy
- Silent JSON fallback in production is not permitted.
- If `ProtobufSerializer` fails to initialize, startup halts with a structured error.
- JSON is always the filesystem bridge format; this is not a fallback — it is mandatory.

---

## Build & Packaging

- Tooling: Nimble package with `wilder-cosmos-runtime` name.
- Supported Nim versions: specify a minimum (e.g., 1.6+) and test matrix in CI.
- Layout:
  - `src/` for Nim sources (`runtime/*.nim`).
  - `tests/` for unit/integration tests.
  - `nimble` file with dependencies.
- Packaging:
  - Produce a `nimble` package and an optionally compiled binary (`runtime.exe` /
    `runtime`) for target platforms.
  - Provide a Dockerfile for reproducible builds.
- CI:
  - Run `nimble test`, static checks, lints, and cross-version build matrix.
  - Include artifact publishing of `nimble` package and binaries.

---

## Testing & Verification

- Unit tests: Isolate core modules; use `InMemoryBackend`.
- Integration tests: Use `FileBackend` with ephemeral temp dirs. Simulate multi-module
  interactions and verify deterministic outcomes.
- Property tests: Use fuzzing on serialization boundaries and migration functions.
- Determinism: Expose deterministic RNG seeded per-test. Tests must assert exact state
  snapshots.
- Test harness helpers: `snapshotState()` and `assertStateEquals(expected: JsonNode)`.
- CI test coverage threshold and gating for PRs.

---

## Portability Tiers

**Tier 1 (fully supported, CI-tested):**
- Linux (x86_64, ARM)
- BSD (FreeBSD, OpenBSD, NetBSD)
- macOS (Intel, Apple Silicon)
- Windows (7, 8, 10, 11)
- Haiku OS

**Tier 2 (best-effort, community-supported):**
- Other POSIX-like systems
- Legacy UNIX variants

---

## Performance Benchmarks

- Avoid blocking host calls in main event loop; use async primitives where applicable.
- Use CBOR for production state blobs to reduce disk IO.
- Benchmarks: measure `saveState()` latency with large modules; target sub-100ms for
  typical module sizes < 1MB.

---

## Security Implementation

- Validate all inbound messages at module boundaries.
- Sandbox modules by restricting HostBindings surface area.
- Sign and checksum snapshots and serialized state.
- Handle untrusted module input with strict size limits and quotas.

---

## Accessibility Implementation

- Source code and documentation must be optimized for neurodivergent participation
  and comprehension: clear terminology, logical structure, minimal cognitive load,
  comprehensive inline comments, and visual aids where helpful.
- All public APIs must follow the ND-friendly comment style defined in
  `docs/implementation/COMMENT_STYLE.md`.
- Provide clear error messages and human-readable JSON dumps.
- Document all commands and expose `--help` via the Console `help` command.

---

## Operational Checklist

- Pre-deploy:
  - Run `nimble test` on CI matrix.
  - Export and verify snapshot integrity and schema versions.
- Deploy:
  - Ensure `runtime` binary built for target OS/arch.
  - Configure storage backend and backups.
  - Start with a health-check endpoint or CLI check: `runtime --check`.
- Monitoring:
  - Log critical lifecycle events and transaction commits.
  - Expose metrics: `tx.commit.latency`, `state.size.bytes`, `active.modules`.
- Recovery:
  - Steps to restore from snapshot.
  - Rollback procedure if migration fails (use per-deployment backup).

---

## Source Taxonomy (Planned)

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

## Examples

Minimal module registration and usage:

```nim
proc initCounter(ctx: var ModuleContext) =
  ctx.setState("count", %0)

proc handleCounter(ctx: var ModuleContext, msg: JsonNode): JsonNode =
  if msg["type"].getStr == "increment":
    let count = ctx.getState("count").get.getInt + 1
    ctx.setState("count", %count)
    result = %*{"count": count}

registerModule("counter", initCounter, handleCounter)

# Usage:
let rt = Runtime(backend)
rt.load()
rt.callModule("client", "counter", %*{"type": "increment"})
rt.save()
```

---

## Deliverables

- `src/runtime/*.nim` — core modules.
- `src/runtime/core.nim` — bootstrapping, lifecycle, and host binding.
- `src/runtime/api.nim` — public API with ND-friendly docs and examples.
- `src/runtime/persistence.nim` — backends, transaction API, three-layer redundancy,
  reconciliation, and streaming snapshot APIs.
- `src/runtime/config.nim` — `RuntimeConfig` types and `loadConfig()`.
- `src/runtime/messaging.nim` — envelope dispatch and debug introspection.
- `src/runtime/serialization.nim` — envelope, format support, and serializer abstraction.
- `config/runtime.cue` — Cue schema for runtime configuration.
- `proto/messaging.proto` — Protobuf schema for `MessageEnvelope` and payload types.
- `src/runtime/console.nim` — Console and tooling.
- `src/runtime/testing.nim` — test harnesses, deterministic RNG, state snapshots.
- `templates/cosmos_runtime_module.nim` — canonical ND-friendly module template.
- `docs/implementation/COMMENT_STYLE.md` — ND documentation and public API comment style guide.
- `tests/reconciliation_test.nim` — deterministic tests for redundancy and reconciliation.
- `tests/config_test.nim` — config loading, validation, invalid combination rejection.
- `tests/serialization_test.nim` — JSON and Protobuf round-trip tests.
- `tests/messaging_test.nim` — envelope dispatch and introspection tests.
- `tests/console_status_test.nim` — Console subsystem tests.
- `examples/counter.nim` — example module using the template.
- `nimble` package file.
- `Dockerfile` and CI config (`.github/workflows/ci.yml`).
- `docs/implementation/SPECIFICATION.md` and `docs/implementation/REQUIREMENTS.md`.
- `docs/implementation/IMPLEMENTATION-DETAILS.md` (this file).
- Migration registry and sample migration implementations.
- `.github/ND_DOCS_CHECKLIST.md` — PR checklist for ND docs and public APIs.

---

## Acceptance Criteria

- All public API functions documented in `api.nim` and follow ND-friendly comment style.
- Persistence backend implements atomic save/load semantics, exposes transaction API,
  and supports three-layer redundancy and reconciliation.
- Streaming snapshot APIs are present and used for blobs > 64KB.
- Serialization round-trip tests passing.
- Template file exists at `templates/cosmos_runtime_module.nim`.
- Persistence API stubs compile (or are clearly marked TODO) and tests run.
- CI runs across supported Nim versions with tests green.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*