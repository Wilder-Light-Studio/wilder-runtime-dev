# WILDER COSMOS RUNTIME — IMPLEMENTATION PLAN (v0.1.1)

*Derived from the frozen REQUIREMENTS.md and SPECIFICATION-NIM.md.*
*Each chapter maps to one or more SPEC sections.*
*Implementation details live in `src/implement/IMPLEMENTATION-DETAILS.md`.*

---

## How to Use This Plan

- Chapters are ordered by dependency. Complete them in sequence.
- Each chapter lists its SPEC sections, deliverables, and acceptance criteria.
- Branch naming: `chapter-NN/short-description`
- Commit prefix: `ch-NN: description`
- Every chapter ends with a PR containing passing tests.

---

## Priority Execution Order

The following priority sequence governs near-term implementation. Items marked
**parallel** may proceed simultaneously when their shared prerequisites are met.

| Priority | Chapter(s) | Deliverables | Prerequisites |
|----------|-----------|-------------|---------------|
| **P0** | **Ch 2C** — Validating Prefilter | Generator, runtime loader, payload mask builder, mask conjunction check, `ValidationFailureOccurrence`, `validation_firewall_test.nim`, `validation_firewall_perf_test.nim`, `validation_table_generation_test.nim`, `validation_failure_occurrence_test.nim` | Ch 2 (types + validation helpers) |
| **P0A** | **Phase VF** — Validation Firewall Vocabulary Refactor | Requirements/spec terminology alignment, Chapter 2 validation firewall reference doc, plan/compliance updates, comment and test text cleanup | Ch 2C |
| **P0** | **Ch 2 (2.7–2.9) + Ch 2B** — Serialization & Messaging *(parallel with 2C)* | Deterministic JSON serializer, Protobuf schema + bindings, envelope checksum hooks, round-trip tests | Ch 2 (types), Ch 2A (config) |
| **P1** | **Ch 3** — Persistence | `FileBackend`, `InMemoryBackend`, streaming for blobs > 64 KB, three-layer reconciliation tests | Ch 2C (prefilter types), Ch 2B (serialization) |
| **P2** | **Ch 10** — Startup Sequence | Prefilter activation gate, reconciliation enforcement before ingress, startup tests | Ch 2C, Ch 3 |
| **P2A** | **Host Hardening Extension** | FileBridge durability, lifecycle guidance, config overrides, host observability, console CLI entrypoint, hardening test gate | Ch 2, Ch 3, Ch 10, Ch 11 |
| **P3A** | **Ch 20** — Runtime Start Coordinator | `cosmos.exe`/`cosmos` startup coordinator, flag/switch parser, optional attached console launch, coordinator tests | Ch 10, Ch 11, Host Hardening |
| **P3** | **Ch 99** — Test Harness & CI Gating | Harness completion, core tests required for merges, CI workflow | All P0–P2 tests passing |
| **P4** | **Ch 14** — Security & Performance | Microbenchmarks for prefilter hot path, perception filtering, startup time; iterate on results | Ch 10 (full startup) |

---

## Minimal Acceptance Checklist

All items below must be satisfied before broad implementation (Ch 4+) begins.

### Prefilter (Ch 2C)
- [ ] Build-time masks generated from canonical sources for every signature.
- [ ] Runtime index loads and activates before first dispatch.
- [ ] Hot-path lookup is O(1) per signature key.
- [ ] Mask conjunction comparison is constant-time with respect to mask width.
- [ ] Payload mask computation is zero-allocation.
- [ ] Prefilter failures produce redacted, deterministic `ValidationFailureOccurrence`s.

### Serialization (Ch 2 + 2B)
- [ ] JSON round-trip tests pass for all `MessageEnvelope` and payload types.
- [ ] Protobuf round-trip tests pass for all `MessageEnvelope` and payload types.
- [ ] Envelope checksum validated on load; corruption halts with structured error.

### Persistence (Ch 3)
- [ ] `FileBackend` and `InMemoryBackend` implemented and passing all tests.
- [ ] Three-layer reconciliation tests pass (all three IMPL-defined scenarios).
- [ ] Streaming APIs work for blobs > 64 KB with integrity validation.

### Startup (Ch 10)
- [ ] Prefilter activation enforced before ingress is enabled.
- [ ] Reconciliation enforced before module execution.
- [ ] Startup halts with structured error on prefilter or reconciliation failure.

### Tests & CI (Ch 99)
- [ ] Unit, perf, and integration tests for prefilter, serialization, persistence, and startup pass.
- [ ] Core tests are CI-gated and required for merges.

### Diagnostics
- [ ] Prefilter failures produce redacted, deterministic failure Occurrences.
- [ ] Error messages never expose sensitive data.

---

## Host Hardening Extension

This extension captures post-baseline hardening work for the host/runtime surface.
Normative behavior lives in `docs/REQUIREMENTS.md` and `docs/SPECIFICATION-NIM.md`.
This section records Phase 2 hardening closure and remaining operational follow-ups.

**Status:** ✅ Implementation complete across HH-1 through HH-4, with HH-5 closure checks integrated into normal verification.

### Scope

- HH-1 extends Chapter 3 persistence with durable file I/O, txlog replay guarantees, snapshot restore hardening, and atomic replace behavior.
- HH-2 extends Chapter 10 lifecycle with explicit gate enforcement and operator-facing recovery guidance.
- HH-3 extends Chapters 2 and 10 with Cue validation workflow, env/CLI override precedence, and structured host observability.
- HH-4 extends Chapter 11 with a thin `src/console_main.nim` entrypoint and launch-time console semantics.
- HH-5 extends Chapter 99 with hardening-specific verification and merge gating.

### Work Packages

#### HH-1 Persistence Hardening
- ✅ File-backed `persistEnvelope`/`loadEnvelope` path handling with checksum validation on read implemented.
- ✅ Newline-delimited per-epoch txlog append behavior with replay idempotence implemented.
- ✅ `snapshotAll`/`restoreSnapshot` hardening implemented with checksum/signature validation and atomic replacement safeguards.
- ✅ Deterministic file layout verified: `state/runtime.json`, `state/modules/`, `state/txlog/`, `state/snapshots/`.
- ✅ Coverage added in `tests/ch3_uat.nim` and `tests/reconciliation_test.nim` for roundtrip, replay, corrupt snapshot, and restore-failure resilience.

#### HH-2 Lifecycle and Error Hardening
- ✅ Enforced module loading gate after reconciliation.
- ✅ Enforced ingress gate after prefilter activation.
- ✅ Structured `StartupError` guidance flow (`recoveryGuidance`) implemented.
- ✅ Gate and structured halt assertions covered in `tests/lifecycle_test.nim` and `tests/integration_test.nim`.

#### HH-3 Config and Observability Hardening
- ✅ Added `scripts/validate_config.ps1` Cue validation shim for exported config.
- ✅ Extended config loading for file < env < CLI precedence.
- ✅ Added host event logging for startup, reconcile, migrate, prefilter activation, and shutdown.
- ✅ Added safe-event assertions to ensure host logs avoid raw payload/secret leakage patterns.
- ✅ Extended `tests/config_test.nim` and `tests/integration_test.nim` for override precedence and host-event assertions.

#### HH-4 Console Entrypoint Hardening
- ✅ Added `src/console_main.nim` thin orchestration entrypoint.
- ✅ Added `--config`, `--mode`, `--attach`, and `--watch` launch flag support.
- ✅ Enforced non-zero exit and usage output when `--config` is missing.
- ✅ Ensured detach resets session state and terminates active watch state.
- ✅ Extended `tests/console_status_test.nim` with launch-contract and watch-stop coverage.

#### HH-5 Hardening Verification Gate
- ✅ Hardening tests are promoted in normal verification flow.
- ✅ Compliance matrix and plan tracking were updated alongside hardening implementation.
- ✅ Compliance and compile gates are currently green for the hardening surface.
- ⚠️ Cue CLI-backed execution of `scripts/validate_config.ps1` remains environment-dependent and should be run in operator environments with Cue installed.

### Exit Criteria

- ✅ Hardening tests for HH-1 through HH-4 are implemented and green.
- ✅ Verification workflow includes hardening checks without partial-startup regressions in current repo validation runs.
- ✅ No exported API removals/signature breaks were introduced by the hardening extension.
- ✅ Changelog includes host-hardening completion notes.

---

## Chapter 1 — Foundations & Taxonomy

**SPEC:** §1 Core Principles, §14 Taxonomy
**Goal:** Scaffold the project structure and enforce architectural constraints.
**Status:** ✅ **COMPLETE** — All tasks finished. Taxonomy scaffolded under `src/`; all runtime core stubs created with ND-friendly headers; `config.nims` configured; `wilder_cosmos_runtime.nimble` updated to v0.1.1; test placeholders and docs added. All new stubs compile.

### Completed Tasks

1.1. ✅ Scaffold the source taxonomy from SPEC §14
1.2. ✅ Create `src/runtime/core.nim` — ND-friendly module with startup/shutdown stubs
1.3. ✅ Create `src/runtime/serialization.nim` — envelope functions with SHA256 checksums
1.4. ✅ Create `src/runtime/testing.nim` — test helpers
1.5. ✅ Verify existing files have correct module headers (api.nim, console.nim, persistence.nim)
1.6. ✅ Update `.nimble` file to version 0.1.1, verify requires "nim >= 1.6"
1.7. ✅ Create `config.nims` at project root with source path resolution

### Acceptance Criteria

✅ All taxonomy directories exist and are populated.
✅ All core module files exist with ND-friendly headers.
✅ `nimble check` passes.
✅ `config.nims` present; direct `nim c` on any `src/` module resolves correctly.
✅ `envelopeWrap` and `envelopeUnwrap` use SHA256 checksums.
✅ All module headers follow ND-friendly style guide.

---

## Chapter 2 — Data Model & Serialization

**SPEC:** §2.2 Envelope Metadata, §7 Status Model, §23 Serialization Transport (base types), §24 Data Handling and Validation
**IMPL:** Public API types, Serialization Implementation, Input Validation Framework
**Goal:** Define all core Nim types, serialization envelope, serializer base types, and implement data validation best practices.
**Status:** ✅ **COMPLETE** — All types, validation helpers, serialization envelopes, and config loading fully implemented with real SHA256 checksums. Tests written and passing: `validation_test.nim` (10 tests), `serialization_test.nim` (6 tests), `config_test.nim` (6 tests).

### Updated Tasks

2.1. ✅ Define `RuntimeState`, `ModuleState`, `ModuleContext`, `HostBindings` types in `src/runtime/api.nim`.
2.2. ✅ Define `StatusField`, `StatusSchema` types (SPEC §7.1).
2.3. ✅ Define `ReconcileResult` type.
2.4. ✅ `src/runtime/validation.nim` — all validation helper procedures implemented with real SHA256.
2.5. ✅ `src/runtime/api.nim` — type-safe distinct types, `moduleContext_create`, `statusField_create` with fail-fast validation.
2.6. ✅ `envelopeWrap` and `envelopeUnwrap` in `src/runtime/serialization.nim` with real SHA256 checksum validation.
2.7. ✅ JSON serialization round-trip for all types with checksum verification. `serializeWithEnvelope`/`deserializeWithEnvelope` implemented.
2.8. ✅ `tests/validation_test.nim` — all validation helpers covered, error cases, sanitized error messages.
2.9. ✅ `tests/serialization_test.nim` — checksum validation, round-trip, corruption detection, serializer selection.
2.10. ✅ `SerializerKind`, `Serializer` base type, `JsonSerializer`, `ProtobufSerializer`, and `selectSerializer` implemented in `src/runtime/serialization.nim`.

### Acceptance
- All types compile.
- Validation module provides reusable helpers and all are covered by tests.
- All required public procs in `api.nim` validate inputs with fail-fast behavior.
- Serialization round-trip tests pass (JSON with checksum validation).
- Envelope checksum validation works with SHA256, not a placeholder hash.
- `SerializerKind` and `Serializer` base type compile.
- Error messages are descriptive and never expose sensitive data.
- Input validation follows efficiency best practices (short-circuit, compile-time checks).

---

## Chapter 2A — Runtime Configuration

**SPEC:** §21 Runtime Configuration, §24 Data Handling and Validation
**Goal:** Load, validate, and expose runtime configuration from a Cue-exported source.
**Status:** ✅ **COMPLETE** — `config/runtime.cue` schema defined; `src/runtime/config.nim` implemented with `RuntimeMode`, `TransportKind`, `LogLevel`, `RuntimeConfig`, and `loadConfig()`; all validation rules enforced; `tests/config_test.nim` passing (6 tests). Host-hardening follow-up for validation script and override precedence is tracked in the Host Hardening Extension (HH-3).

### Tasks
2A.1. Create `config/runtime.cue` — Cue schema with all fields, validation rules, and
      sane defaults (SPEC §21.1, §21.2).
2A.2. Implement `src/runtime/config.nim` — `RuntimeMode`, `TransportKind`, `LogLevel`,
      `RuntimeConfig` types; `loadConfig(path: string): RuntimeConfig` proc.
2A.3. Implement validation at load time using helpers from `src/runtime/validation.nim`:
      - Reject invalid field combinations (§21.2) with structured errors (e.g., 
        `mode = "production"` with `logLevel ∈ {"trace","debug"}`)
      - Validate port range [1, 65535] using `validatePortRange`
      - Validate endpoint non-empty using `validateNonEmpty`
      - Log validation failures with context but never expose sensitive data
 **(Pending)**
2A.4. Wire `loadConfig()` into startup step 1 (§5.1, Ch 10); no subsystem reads raw
      config after startup.
2A.5. Write tests: `tests/config_test.nim` — valid debug load, valid production load,
      invalid combination rejection, missing config file, port boundary tests (0, 1, 65535, 65536).

### Acceptance
- `loadConfig()` parses a Cue-exported JSON file into `RuntimeConfig` using validated input.
- Invalid configurations produce structured errors at load time.
- `mode = "production"` with `logLevel ∈ {"trace","debug"}` is rejected.
- Validation uses centralized helpers from `runtime/validation.nim`.
- Config is injected into all subsystems; no subsystem reads raw config after startup.

---

## Chapter 2B — Messaging System & Transport

**SPEC:** §22 Messaging System, §23 Serialization Transport, §24 Data Handling and Validation
**Goal:** Define the Protobuf message schema, implement the serializer abstraction,
wire transport selection to config, and validate all message inputs.
**Status:** ✅ **COMPLETE** — `proto/messaging.proto` defined; `JsonSerializer` and `ProtobufSerializer` implemented in `src/runtime/serialization.nim`; `src/runtime/messaging.nim` implemented with envelope dispatch, debug/production mode logging, and inbound validation; `selectSerializer()` wired to config transport; tests passing: `serialization_test.nim` (6 tests), `messaging_test.nim` (4 tests).

### Tasks
2B.1. Create `proto/messaging.proto` — `MessageEnvelope` with `id`, `type`, `version`,
      `timestamp`, and `oneof payload`; define `Ping` and `ConfigUpdate` payload types
      (SPEC §22.1, §22.2). Apply forward-compatibility rules (§22.3).
2B.2. Generate or hand-write Nim bindings for `MessageEnvelope` and payload types.
2B.3. Implement `JsonSerializer` in `src/runtime/serialization.nim` — stable,
      deterministic, round-trippable JSON encoding of `MessageEnvelope` (§23.3).
      Include checksum validation using `validateChecksum` from `runtime/validation.nim`.
2B.4. Implement `ProtobufSerializer` in `src/runtime/serialization.nim` — Protobuf
      encoding/decoding via generated bindings (§23.4).
      Include structure validation using `validateStructure` from `runtime/validation.nim`.
2B.5. Implement serializer factory: select active `Serializer` from
      `RuntimeConfig.transport` at startup (§23.2).
2B.6. Implement `src/runtime/messaging.nim` — envelope dispatch; full envelope logging
      in `debug` mode; no logging overhead in `production` mode (§22.4).
      Validate all inbound messages using `validateStructure` before dispatch.
2B.7. Write tests: `tests/serialization_test.nim` — JSON round-trip, Protobuf
      round-trip, correct serializer selected by config, filesystem bridge always JSON,
      checksum validation on deserialization, malformed message rejection.
2B.8. Write tests: `tests/messaging_test.nim` — envelope dispatch, debug introspection
      logging present, production mode logging absent, invalid envelope rejection.

### Acceptance
- JSON serializer round-trips `MessageEnvelope` + all payload types with checksum validation.
- Protobuf serializer round-trips `MessageEnvelope` + all payload types with structure validation.
- Active serializer is selected from `RuntimeConfig.transport` at startup.
- All envelopes validated before dispatch; invalid messages produce structured errors.
- Debug mode logs all envelopes; production mode does not.
- Filesystem bridge always uses JSON regardless of `transport`.
- Error messages never expose sensitive data; validation uses centralized helpers.

---

## Chapter 2C — Validating Prefilter Runtime Gate

**SPEC:** §24.9 Validating Prefilter Runtime Specification, §24.10 Data Structures,
§24.10.4 Validation and Payload Masks, §24.11 Lifecycle,
§24.12 Error and Failure Occurrence Semantics,
§24.13 No-Copying and Regeneration Contract, §24.14 Performance and Constraints
**Goal:** Implement the signature-keyed validating prefilter with mask-based
structural validation so only structurally validated data can be dispatched or
recorded as normal domain Occurrences.
**Status:** ✅ **COMPLETE** — All prefilter types, mask derivation, signature-key derivation, payload mask computation, mask conjunction check, ingress pipeline, dispatch/admission gates, and redacted failure Occurrences implemented in `src/runtime/validation.nim`; generated table in `src/runtime/prefilter_table_generated.nim`; all four test suites passing: `validation_firewall_test.nim` (12), `validation_firewall_perf_test.nim` (3), `validation_table_generation_test.nim` (5), `validation_failure_occurrence_test.nim` (5).

### Tasks
2C.1. Define prefilter core types in `src/runtime/validation.nim` (or split module if needed):
      `ValidationSignatureKey`, `FieldRule`, `ArgumentRule`, `ValidationRecord`,
      `ValidationIndex`, `ValidationFailureOccurrence`, `ValidationMask`,
      `PayloadMask`, and supporting enums.
2C.2. Implement canonical signature-key derivation (stable preimage normalization +
      SHA-256 digest truncation to 128-bit key digest) with collision detection.
2C.3. Implement `ValidationMask` derivation from `ArgumentRule` / `FieldRule`
      sequences: set required-presence bits, type-constraint bits, ordering bit,
      and cardinality bits. Store masks in `ValidationRecord.masks`.
2C.4. Implement prefilter table generator from canonical schema/signature sources:
      emit `src/runtime/prefilter_table_generated.nim` automatically during build,
      including precomputed validation masks per record.
2C.5. Implement runtime startup activation: load generated table, verify record
      invariants and mask widths, build immutable O(1) lookup index, block ingress
      until active.
2C.6. Implement payload mask computation: zero-allocation runtime function that
      builds a `PayloadMask` from an inbound payload using the same bit layout
      as the corresponding `ValidationMask`.
2C.7. Implement mask conjunction check: `(validationMask AND payloadMask) ==
      validationMask`, constant-time with respect to mask width. On failure,
      identify first failing mask region for `ValidationFailureKind`.
2C.8. Implement ingress prefilter pipeline:
      resolve target signature -> lookup record -> compute payload mask ->
      mask AND comparison -> evaluate extra-field policy -> short-circuit on
      first failure.
2C.9. Implement dispatch and admission gates:
      - only `Validated` payloads reach procs/functions,
      - only `Validated` payloads become normal domain Occurrences.
2C.10. Implement prefilter-failure Occurrence emission with redacted diagnostics:
      include digests/metadata/rule identifiers, exclude raw invalid payload bytes.
2C.11. Implement no-copying and regeneration behavior:
      regenerate when artifacts are stale or missing; fail startup if regeneration
      cannot produce a valid prefilter index.
2C.12. Write tests: `tests/validation_firewall_test.nim` — unknown signature,
      arg mismatch, type mismatch, missing field, unknown-field policy,
      ordering/cardinality violations, mask conjunction pass/fail, gate enforcement.
2C.13. Write tests: `tests/validation_firewall_perf_test.nim` — O(1) lookup,
      constant-time mask comparison, zero-allocation payload mask computation,
      no dynamic schema parsing on hot path.
2C.14. Write tests: `tests/validation_table_generation_test.nim` — generated
      artifact correctness, source digest conformance, regeneration drift
      prevention, no manual prefilter table copying.
2C.15. Write tests: `tests/validation_failure_occurrence_test.nim` — deterministic
      redacted diagnostics, negative dispatch checks, and proof that invalid
      payload bytes are never surfaced to user code or operator-facing output.

### Acceptance
- Prefilter index is generated from canonical sources with no manual table copying.
- Validation masks are precomputed at build time for every signature.
- Runtime startup fails if the prefilter table cannot be validated/activated.
- Unvalidated payloads cannot reach user procs/functions.
- Unvalidated payloads cannot be recorded as normal domain Occurrences.
- Hot-path structural validation uses mask conjunction, not field-by-field traversal.
- Mask comparison is constant-time with respect to mask width.
- Payload mask computation does not allocate.
- Prefilter failures produce deterministic failure Occurrences with safe diagnostics.
- Hot path uses O(1) signature-key lookup and no dynamic schema parsing.

---

## Phase VF — Validation Firewall Vocabulary Refactor

**Goal:** Apply validation firewall terminology across normative documentation, plan artifacts, comments, and user-facing test text while preserving identifiers and underscore-delimited filenames.
**Status:** ✅ **COMPLETE** — Requirements, specification, development guidelines, compliance tracking, plan artifacts, and Chapter 2 prefilter reference material now use validation firewall terminology; Chapter 2C test artifact names and user-facing suite labels are aligned with the updated vocabulary.

### Tasks
VF.1. Update `docs/implementation/REQUIREMENTS.md` terms and principle language to validation firewall terminology.
VF.2. Update `docs/implementation/SPECIFICATION-NIM.md` implementation-principle language and Chapter 2 source references.
VF.3. Create `docs/implementation/Chapter2/VALIDATION-FIREWALL-REQUIREMENTS.md` as the canonical Chapter 2 reference target for validating prefilter requirements.
VF.4. Update `docs/implementation/DEVELOPMENT-GUIDELINES.md` and `docs/implementation/COMPLIANCE-MATRIX.md` to track the new terminology.
VF.5. Update mirrored plan artifacts and Chapter 2C planning references to record this refactor as a completed implementation phase.
VF.6. Rename Chapter 2C membrane-named test artifacts and user-facing suite labels to validation firewall equivalents, then sync all workflow, script, and documentation references.

### Acceptance
- Normative docs use validation firewall terminology for whole-word occurrences.
- Chapter 2 validating prefilter references resolve to an existing validation firewall requirements document.
- Plan and compliance artifacts record the vocabulary refactor as completed work.
- Chapter 2C test artifact names are aligned with validation firewall terminology across docs, CI, and scripts.

---

## Chapter 3 — Persistence Model

**SPEC:** §2 Persistence Model (all subsections), §24 Data Handling and Validation
**IMPL:** Persistence Implementation, ACID Semantics, Storage Layout, Migration
**Goal:** Three-layer persistence with reconciliation and validated data integrity.
**Status:** ✅ **COMPLETE** — `InMemoryBridge` and `FileBridge` implemented in `src/runtime/persistence.nim`; transactions, rollback, reconciliation (three scenarios), streaming, migration, and snapshot sign/verify all implemented; tests passing: `reconciliation_test.nim` (3 tests), `ch3_uat.nim` (13 tests). File-backed durability and txlog hardening follow-up is tracked in the Host Hardening Extension (HH-1).

### Tasks
3.1. Define `PersistenceBridge` interface in `src/runtime/persistence.nim`.
3.2. Implement `InMemoryBridge` (for tests) with validation hooks.
3.3. Implement `FileBridge` with validated storage layout:
     `state/runtime.json`, `state/modules/`, `state/txlog/`, `state/snapshots/`.
3.4. Implement envelope metadata: `schemaVersion`, `epoch`, `checksum`, `origin`.
     Validate checksum on all read operations using `validateChecksum` from `runtime/validation.nim`.
3.5. Implement `beginTransaction()`, `commit()`, `rollback()` with invariant validation
     after each commit.
3.6. Implement reconciliation rules (three scenarios from IMPL) with checksum validation
     at each step using helpers from `runtime/validation.nim`.
3.7. Implement streaming read/write for blobs > 64 KB with checksum validation.
3.8. Implement migration strategy: `migrate_vN_to_vNplus1` with validation pre/post-migration.
3.9. Implement snapshot export/import with signing and checksum verification using
     `validateChecksum` and `validateStructure`.
3.10. Write tests: `tests/reconciliation_test.nim` — simulate single-layer failure,
      bit-rot, partial writes. Verify rebuild from any two layers.
      Test checksum validation failures halt operations with structured errors.

### Acceptance
- `InMemoryBridge` and `FileBridge` pass all persistence tests.
- Reconciliation works for all three scenarios with checksum validation at each step.
- Checksum validation failures halt operations (never corrupt silently).
- Streaming APIs work for large blobs with integrity validation.
- Migration chain executes correctly with pre/post validation.
- Error messages for validation failures are descriptive and never expose sensitive data.


---

## Chapter 4 — Ontology

**SPEC:** §4 Ontology (Concept, Occurrence, Perception, Thing)
**IMPL:** Ontology Implementation
**Goal:** Implement the four ontological primitives.
**Status:** ✅ **COMPLETE** — All four primitive types and lifecycle procs implemented in `src/cosmos/thing/thing.nim`; `tests/ontology_test.nim` written and all 30 tests passing.

### Tasks
4.1. Define `Concept` type with six sections + Interrogative Manifest reference.
4.2. Define `Occurrence` type (`id`, `source`, `epoch`, `payload`, `projectionRadius`).
4.3. Define `Perception` type (`occurrenceId`, `thingId`, `epoch`, `filtered`).
4.4. Define `Thing` type (`id`, `conceptId`, `status`, `perceptionLog`, `epoch`,
     `metadata`).
4.5. Implement Thing lifecycle: instantiation, active, destruction.
4.6. Implement Occurrence projection and Perception filtering.
4.7. ✅ Write tests: `tests/ontology_test.nim` — Thing instantiation from Concept,
     Occurrence emission, Perception matching, status validation.

### Acceptance
- All four primitive types compile and serialize.
- Thing lifecycle works end-to-end.
- Perception filtering is correct and deterministic.

---

## Chapter 5 — Interrogative Manifest

**SPEC:** §6 Interrogative Manifest, §6.2 Specialist Declaration
**IMPL:** Interrogative Manifest (Nim Type)
**Goal:** Implement the ten interrogatives with validation.
**Status:** ✅ **COMPLETE** — `InterrogativeManifest` type defined in `src/cosmos/core/manifest.nim`; Concepts now validate on minimal WHO/WHY requirements when no manifest is present; `validateManifest` enforces all interrogative fields non-empty only when a manifest is present; `validateSpecialist` enforces non-empty `PROVIDES` and `REQUIRES`; native module contracts are code-defined and manifest views are generated from code; external-process wrappers accept handwritten manifests as authoritative; tests cover manifest validation, minimal ontology rules, and native/external contract authority.

### Tasks
5.1. ✅ Define `InterrogativeManifest` type (10 fields).
5.2. ✅ Implement validation: full manifests require all interrogative fields non-empty when present.
5.3. ✅ Wire minimal Concept validation and conditional manifest checks into Concept load behavior.
5.4. ✅ Implement specialist capability validation: `PROVIDES` and `REQUIRES` non-empty.
5.5. ✅ Write tests for manifest validation, minimal ontology validity, and native/external contract authority.

### Acceptance
- Concepts with identity plus WHY pass without a manifest.
- Valid manifests pass validation when present.
- Missing or empty manifest fields produce structured errors when a manifest is present.
- Specialist declarations validate correctly.

---

## Chapter 6 — Status & Memory Model

**SPEC:** §7 Status Model, §8 Memory Model
**IMPL:** Memory Enforcement
**Goal:** Status schema with invariant checking and bounded memory.
**Status:** ✅ **COMPLETE** — `src/cosmos/core/status.nim` implemented with status schema validation, phase-aware invariant checks (load/mutation/reconciliation), memory categories, mutation-time cap enforcement, warning→rejection escalation, and memory introspection reports; tests added in `tests/status_memory_test.nim` and compile clean in this environment.

### Tasks
6.1. ✅ Implement `StatusSchema` validation against Thing state.
6.2. ✅ Implement invariant checking at load, after mutation, during reconciliation.
6.3. ✅ Implement memory categories: state, perception, temporal, module.
6.4. ✅ Implement mutation-time memory enforcement (`memoryCap`).
6.5. ✅ Implement escalation: warning → rejection → structured error on repeated
      violation.
6.6. ✅ Implement memory introspection (queryable per-module and per-Thing).
6.7. ✅ Write tests: `tests/status_memory_test.nim`.

### Acceptance
- Invariant violations produce structured errors.
- Memory cap enforcement rejects over-limit mutations.
- Memory usage is queryable.

---

## Chapter 7 — World Ledger & World Graph

**SPEC:** §10 World Ledger, §11 World Graph
**IMPL:** World Ledger Implementation
**Goal:** Declarative relationship model and navigable world structure.
**Status:** ✅ **COMPLETE** — `src/cosmos/runtime/ledger.nim` implemented with append-only ledger references/claims, load-time validation, persistence integration through `PersistenceBridge`, deterministic world graph reconstruction, explicit-edge enforcement, and single-root invariant checks; `tests/world_test.nim` added and passing.

### Tasks
7.1. ✅ Define `LedgerReference` and `LedgerClaim` types.
7.2. ✅ Implement append-only ledger with Occurrence-based mutation.
7.3. ✅ Implement ledger persistence within the three-layer model.
7.4. ✅ Implement load-time validation of references and claims.
7.5. ✅ Build the world graph from ledger references (nodes = Things, edges = references).
7.6. ✅ Implement single root Thing invariant.
7.7. ✅ Write tests: `tests/world_test.nim` — ledger mutations, graph construction,
     no implicit edges.

### Acceptance
- References and claims persist and validate.
- World graph is reconstructible from persisted state.
- No implicit edges exist.

---

## Chapter 8 — Scheduler & Tempo

**SPEC:** §12 Scheduler & Tempo
**IMPL:** Scheduler & Tempo Implementation
**Goal:** Deterministic frame loop with five tempo types.
**Status:** ✅ **COMPLETE** — `src/cosmos/runtime/scheduler.nim` implemented with deterministic frame execution order, bounded per-Thing work budget, cooperative yielding, failure isolation, repeated-failure suspension, and deterministic replay digest; `tests/scheduler_test.nim` added and passing.

### Tasks
8.1. ✅ Implement tempo types: Caused (Event), Periodic, Continuous, Manual, Sequence.
8.2. Implement the frame loop: advance epoch → collect Occurrences → evaluate
     perceptions → deliver → allow emission → yield.
8.2. ✅ Implement the frame loop: advance epoch → collect Occurrences → evaluate
      perceptions → deliver → allow emission → yield.
8.3. ✅ Implement deterministic ordering (epoch order, lexicographic Thing/module order).
8.4. ✅ Implement bounded execution (per-Thing time limit per frame).
8.5. ✅ Implement cooperative yielding.
8.6. ✅ Implement error boundaries: per-Thing failure isolation, repeated failure
     suspension.
8.7. ✅ Implement frame replay: given same state + Occurrences → identical result.
8.8. ✅ Write tests: `tests/scheduler_test.nim` — determinism, replay, error isolation,
     tempo types.

### Acceptance
- Frame loop is deterministic and replayable.
- All five tempo types work correctly.
- Failed Things are isolated; other Things continue.
- Repeated failures trigger suspension.

---

## Chapter 9 — Delegation

**SPEC:** §9 Delegation Model
**IMPL:** Delegation Implementation
**Goal:** Voluntary, Occurrence-based delegation and specialist matching.
**Status:** ✅ **COMPLETE** — `src/cosmos/runtime/delegation.nim` implemented with `DelegationOccurrence`/`DelegationResult`, delegation emission, deterministic specialist matching (narrowest capability + lexical fallback), asynchronous result delivery (>=2 frames), no-match and specialist-failure handling, and specialist declaration validation; `tests/delegation_test.nim` added and passing.

### Tasks
9.1. ✅ Define `DelegationOccurrence` and `DelegationResult` types.
9.2. ✅ Implement delegation emission (Thing sends a delegation Wave via `DelegationOccurrence`).
9.3. ✅ Implement specialist matching: scan `PROVIDES`, narrowest-capability tiebreaker,
     lexicographic fallback.
9.4. ✅ Implement result delivery via `DelegationResult` Occurrence.
9.5. ✅ Implement failure handling: no match → auto-failure result; specialist failure →
     structured error result.
9.6. ✅ Implement load-time validation of specialist declarations.
9.7. ✅ Write tests: `tests/delegation_test.nim` — matching, result delivery, no-match
     failure, multi-specialist tiebreaker.

### Acceptance
- Delegation flows through Occurrences only.
- Matching is deterministic.
- Results are delivered asynchronously (span ≥ 2 frames).
- Delegation creates no implicit relationships.

---

## Chapter 10 — Runtime Lifecycle

**SPEC:** §5 Runtime Lifecycle, §24.11.2 Runtime Startup and Activation
**IMPL:** Startup Implementation
**Goal:** Deterministic startup and shutdown sequences with prefilter and
reconciliation gates enforced before ingress.
**Status:** ✅ COMPLETE — `src/runtime/core.nim` full 9-step lifecycle; 20 tests passing. Structured recovery-guidance and host-observability hardening follow-up is tracked in the Host Hardening Extension (HH-2, HH-3).

### Tasks
10.1. Implement startup sequence (8 steps + prefilter gate) in `src/runtime/core.nim`:
      1. Load configuration.
      2. Initialize persistence backend.
      3. Load runtime envelope.
      4. Reconcile layers — halt on irreconcilable divergence.
      5. Run migrations.
      6. **Activate prefilter** — load generated table, verify invariants/digests/mask
         widths, build immutable index, block ingress until active (§24.11.2).
      7. Load modules in deterministic order.
      8. Initialize scheduler, tempo, world graph.
      9. Begin frame loop — ingress opens only after steps 4 and 6 succeed.
10.2. Implement shutdown sequence (5 steps).
10.3. Enforce invariants:
      - No partial startup.
      - No silent failure.
      - No module execution before reconciliation completes.
      - **No ingress before prefilter activation succeeds.**
10.4. Implement startup error handling: halt, structured error, recovery path.
      Prefilter activation failure and reconciliation failure both halt startup.
10.5. Implement startup banner (from IMPL: version, mode, modules, backend, reconcile
      status, prefilter generation ID, epoch).
10.6. Write tests: `tests/lifecycle_test.nim` — successful startup/shutdown, failure
      at each step, invariant enforcement, prefilter activation gate, reconciliation
      gate.

### Acceptance
- Startup completes all 9 steps or halts with a structured error.
- Shutdown flushes, snapshots, and closes cleanly.
- No module runs before reconciliation.
- **No ingress before prefilter activation.**
- Prefilter and reconciliation failures halt startup with structured errors.
- Startup banner prints correct information including prefilter generation ID.

---

## Chapter 11 — Console Subsystem

**SPEC:** §3 Console (all subsections)
**IMPL:** Console Implementation
**Goal:** Three-layer Console with all 20 commands.
**Status:** ✅ COMPLETE — `src/runtime/console.nim` full 3-layer + 20 commands; 56 tests passing. Launch-time CLI entrypoint hardening follow-up is tracked in the Host Hardening Extension (HH-4).

### Tasks
11.1. Implement three-layer rendering: Status Bar, Scope Line, Prompt Line.
11.2. Implement attach/detach protocol (identity, permissions, capabilities,
      layout init, cache clear).
11.3. Implement navigation commands: `ls`, `cd`, `pwd`.
11.4. Implement introspection commands: `info`, `peek`, `watch`, `state`.
11.5. Implement delegation introspection: `specialists`, `delegations`.
11.6. Implement world ledger introspection: `world`, `claims`.
11.7. Implement execution commands: `run`, `set`, `call`.
11.8. Implement instance management: `attach`, `detach`, `instances`.
11.9. Implement ergonomics: `help`, `clear`, `exit`.
11.10. Implement `ls` output rules (flat list, Thing/dir/virtual/file formatting).
11.11. Implement `watch` full-screen mode with `Ctrl+C` resume.
11.12. Implement preconditions: unattached commands vs attached-only commands.
11.13. Extend `tests/console_status_test.nim` — all layers, all commands, attach/detach.

### Acceptance
- Three-layer layout renders correctly.
- All 20 commands dispatch and produce correct output.
- Attach/detach protocol works cleanly.
- Unattached commands work; attached-only commands error when detached.

---

## Chapter 12 — Module System

**SPEC:** §13 Module System
**IMPL:** Core Modules
**Goal:** Kernel/loadable architecture with canonical template.
**Status:** ✅ COMPLETE — `src/runtime/modules.nim` kernel/loadable registry, lexicographic load order, memory cap; template updated; 21 tests passing.

### Tasks
12.1. Implement kernel vs loadable module distinction in `core.nim`.
12.2. Implement `registerModule` with static registration.
12.3. Implement module metadata: `memoryCap`, `resourceBudget`.
12.4. Implement deterministic module load order (lexicographic).
12.5. Update `templates/cosmos_runtime_module.nim` to match frozen spec.
12.6. Write tests: `tests/module_test.nim` — registration, load order, metadata.

### Acceptance
- Modules register and load in deterministic order.
- Template compiles and follows ND-friendly comment style.
- Memory cap and resource budget are enforced.

---

## Chapter 13 — Portability

**SPEC:** §15 Portability
**Goal:** Cross-platform portability layer.
**Status:** ✅ COMPLETE — `src/cosmos/utils/platform.nim` full portability layer (path, time, env, process); 14 tests passing.

### Tasks
13.1. Implement portability layer: filesystem, time, process abstractions.
13.2. Isolate all platform-specific code behind the portability layer.
13.3. Verify compilation on Tier 1 targets: Linux, BSD, macOS, Windows, Haiku.
13.4. Test with toolchains 7–10 years old (Nim 1.6 minimum).

### Acceptance
- Runtime compiles unmodified on all Tier 1 platforms.
- No platform-specific code outside the portability layer.

---

## Chapter 14 — Security & Performance

**SPEC:** §16 Performance, §17 Security, §24.14 Prefilter Performance
**Goal:** Enforce boundaries, meet performance targets, and iterate on
microbenchmark results.
**Status:** ✅ COMPLETE — `src/runtime/security.nim` instance boundary, mode validation, channel isolation, microbenchmark helpers; 23 tests passing.

### Tasks
14.1. Implement read/write protection at the instance boundary.
14.2. Implement explicit mode validation (no silent promotion).
14.3. Verify no hidden channels between instances or modules.
14.4. Benchmark startup time (target < 2 seconds on Tier 1).
14.5. Benchmark perception filtering (target: interactive frame rates).
14.6. Verify memory usage is bounded and deterministic.
14.7. Run prefilter microbenchmarks and iterate:
      - O(1) signature-key lookup latency.
      - Constant-time mask conjunction (vary mask widths).
      - Zero-allocation payload mask computation (verify via allocator counters).
      - No dynamic schema parsing on hot path (verify via profiler).
14.8. Run serialization microbenchmarks:
      - JSON round-trip throughput.
      - Protobuf round-trip throughput.
      - Envelope checksum overhead.
14.9. Run persistence microbenchmarks:
      - Reconciliation time for each three-layer scenario.
      - Streaming read/write throughput for blobs > 64 KB.
14.10. Document results and iterate: file issues for any target misses,
       re-benchmark after fixes.

### Acceptance
- Security invariants hold under test.
- Startup < 2 seconds.
- Perception filtering meets frame rate targets.
- Prefilter hot path meets O(1) lookup, constant-time mask comparison, and
  zero-allocation payload mask targets.
- Serialization round-trip performance is documented and within budget.
- Persistence reconciliation and streaming performance is documented.
- All microbenchmark results are tracked and regressions flagged.

---

## Chapter 15 — Documentation & ND Accessibility

**SPEC:** §18 Documentation
**Goal:** Complete, offline, ND-friendly documentation.
**Status:** ✅ COMPLETE — ND checklist and source-comment pass complete; public documentation IA finalized; chapter acceptance criteria satisfied with PR-template checklist reference.

### Tasks
15.1. Ensure all public APIs follow `docs/COMMENT_STYLE.md`.
15.2. Add beginner comments, similes, and memory notes to all public procs.
15.3. Verify all documentation is in-repo and viewable offline.
15.4. Create `.github/ND_DOCS_CHECKLIST.md` — PR checklist for ND docs.
15.5. Review all source files for clear terminology, logical structure, minimal
      cognitive load.
15.6. Add `docs/index.md` as the documentation landing page with links to
      `docs/public/` and `src/implement/`.
15.7. Scaffold `docs/public/` with section roots:
      `getting-started/`, `concepts/`, `runtime/`, `modules/`, `glossary/`.
15.8. Author newcomer documentation pages for runtime overview, console entry,
      first module guidance, and architecture orientation.
15.9. Author concept pages for Concept, Thing, Occurrence, Perception,
      Interrogative Manifest, Status and Memory, World Ledger/World Graph,
      Scheduler/Tempo.
15.10. Author runtime pages for validating prefilter, serialization,
       persistence, startup sequence, configuration and transport, and
       hardening posture.
15.11. Author module pages for authoring flow, lifecycle, boundaries, and
       best practices.
15.12. Produce glossary pages defining Cosmos terms in short, neutral language.
15.13. Reorganize documentation paths to the target IA by moving files where
       needed and updating relative links.
15.14. Preserve `src/implement/` content except link/path fixes.

### Acceptance
- All public APIs have ND-friendly comments.
- Documentation checklist exists and is referenced in PR template.
- No external dependencies for documentation.
- `docs/index.md` exists and routes newcomers to public docs first.
- `docs/public/` sections exist with complete required topic coverage.
- Implementation docs remain preserved; any edits are limited to link fixes.
- Documentation links resolve after reorganization.

---

## Chapter 16 — Packaging, Release & Archive

**SPEC:** §19 Packaging, §20 Archive Completeness
**Goal:** Self-contained releases and archive.
**Status:** ✅ COMPLETE — `examples/counter.nim`, `Dockerfile`, `.github/workflows/ci.yml`; nimble testCompile/test tasks updated; tagged v0.4.0-wip.

### Tasks
16.1. Verify `.nimble` is the single source of truth for version and metadata.
16.2. Create `examples/counter.nim` — example module using the template.
16.3. Create `Dockerfile` for reproducible builds.
16.4. Create `.github/workflows/ci.yml` — test matrix across Nim versions and
      platforms.
16.5. Verify archive is self-contained: all code, docs, templates, metadata present.
16.6. Verify `nimble test` passes on CI.
16.7. Tag release `v0.1.1-wip`.

### Acceptance
- `nimble test` green on CI across platforms.
- Archive builds and tests with zero external dependencies.
- Release is self-contained and verifiable.

---

## Phase 4 Extension — Chapter 19A Binary Build, Installer, and Release Tooling

**SPEC:** §19A Binary Build, Installer, and Release Tooling
**Goal:** Implement cross-platform artifact automation, installer contracts, checksums,
manifest emission, and release-channel publishing foundations.
**Status:** ✅ COMPLETE — release matrix workflow now includes staged build/package/sign/verify-signature/publish scaffold flow, checksum automation, installer contract checks, uninstall residue checks, and channel-aware manifest metadata.

### Tasks
19A.1. ✅ Add release artifact workflow skeleton with explicit target matrix:
      windows-amd64, linux-amd64, linux-arm64, darwin-amd64, darwin-arm64.
19A.2. ✅ Add machine-readable `release-manifest.json` generation tooling.
19A.3. ✅ Add artifact checksum generation and verification gates (SHA-256).
19A.4. ✅ Add installer mode contract checks (`user` and `system`) for filesystem layout.
19A.5. ✅ Add uninstall residue checks for installer-owned paths.
19A.6. ✅ Add signing stage scaffolding (Windows/macOS/Linux) with explicit TODO gates.
19A.7. ✅ Add release channel metadata handling (`stable` and `preview`).
19A.8. ✅ Wire CI compliance check to fail when required 19A matrix targets are missing.

### Acceptance
- Release tooling defines all required target matrix entries from SPEC §19A.1.
- Manifest generation emits required fields per artifact.
- Checksum generation and verification are automated in workflow.
- Installer mode and uninstall contracts are validated by tests/gates.
- Signing and publish stages are explicitly represented in pipeline ordering.
- Channel-aware release outputs exist for `stable` and `preview`.

---

## Phase XA — DRY Wants/Provides and Capability Discovery

**SPEC:** §19B Phase XA — DRY Wants/Provides and Capability Discovery Specification
**Goal:** Implement deterministic capability discovery and resolution with DRY provider
boundaries, startup-gated failure behavior, and CLI visibility for capability mapping.
**Status:** 🚧 IN PROGRESS — normative requirements and specification added; runtime
resolver implementation and tests are beginning.

### Dependencies

- Ch 5 interrogative manifest model for PROVIDES/WANTS surface semantics.
- Ch 10 lifecycle gate ordering for pre-ingress capability resolution.
- Ch 12 module system for implementation binding metadata.
- Phase X concept CLI routing surface for command expansion through `cosmos.exe`.

### Outputs

- Capability graph resolver with deterministic provider and want resolution.
- Structured capability issue model (missing provider/provide, conflict, signature mismatch,
      orphaned provide).
- `cosmos capabilities` CLI surface.
- Initial `cosmos concept resolve` mapping-introspection CLI surface.
- Edge-case test coverage for fatal resolution failures and deterministic behavior.

### Tasks

XA.1. Add runtime capability model and resolver module with deterministic ordering.
XA.2. Add startup-gate integration points for pre-ingress capability validation.
XA.3. Add CLI command `cosmos capabilities` with deterministic output contract.
XA.4. Add CLI command `cosmos concept resolve` for explicit mapping introspection.
XA.5. Add tests for missing provider Thing, missing provide, provider conflict,
      signature mismatch, and deterministic whole-Thing expansion.
XA.6. Update compliance matrix and implementation docs references after verification.

### Acceptance

- Capability keys resolve deterministically for repeated runs with identical declarations.
- Fatal capability issues halt startup before ingress opens.
- Whole-Thing wants expand deterministically and without duplicated bindings.
- `cosmos capabilities` shows Things, provides, wants, and resolution status.
- `cosmos concept resolve` reports explicit mappings and unresolved causes.
- Edge-case tests cover all fatal issue classes and pass in CI.

---

## Phase XB — Dynamic Semantic Scanner and Relationship Extraction

**SPEC:** §19C Phase XB — Dynamic Semantic Scanner and Relationship Extraction Specification
**Goal:** Implement deterministic codebase scanning that emits canonical Thing objects
with inferred needs/wants/provides/conflicts/before/after metadata and CLI inspection.
**Status:** 🚧 IN PROGRESS — normative requirements/specification updates are in;
scanner module, CLI integration, and test coverage are being implemented.

### Dependencies

- Ch 4 ontology primitives for Thing object integration.
- Ch 5 interrogative and capability semantics for relationship vocabulary.
- Ch 20B CLI entrypoint routing for scan/conflict commands.
- Phase XA capability naming conventions for inferred provide conflict keys.

### Outputs

- Deterministic scanner module for `.nim` trees.
- Inference engine for needs/wants/provides/conflicts/before/after.
- Canonical Thing-based scanner output.
- `cosmos scan` CLI command.
- `cosmos capability conflicts` CLI command.
- Scanner unit and CLI tests for deterministic behavior and edge conditions.

### Tasks

XB.1. Implement scanner file discovery and deterministic parsing pipeline.
XB.2. Implement relationship inference and Thing metadata emission.
XB.3. Implement duplicate provide conflict detection across scanned Things.
XB.4. Add `cosmos scan` command with summary and JSON output modes.
XB.5. Add `cosmos capability conflicts` command.
XB.6. Add scanner tests for inference, conflicts, and deterministic output.
XB.7. Update compliance matrix and changelog after test verification.

### Acceptance

- Scanner produces stable ordered outputs for repeated scans of unchanged inputs.
- Scanner emits Thing objects with required relationship metadata fields.
- Duplicate provide declarations are surfaced as deterministic conflict entries.
- `cosmos scan` and `cosmos capability conflicts` commands pass CLI contract tests.
- Scanner tests pass in local verification workflow.

---

## Dependency Graph

```
Ch 1  Foundations  ✅
  │
Ch 2  Data Model & Serialization (2.1–2.6 ✅, 2.7–2.9 pending)
  │
Ch 2A Runtime Configuration
  │
  ├──────────── PARALLEL TRACK ────────────┐
  │                                        │
Ch 2B Messaging & Transport  ◄──P0──►  Ch 2C Validating Prefilter
  │                                        │
  └──────────── CONVERGE ──────────────────┘
     │
Ch 3  Persistence  ◄── P1
     │
Ch 10 Lifecycle (prefilter gate + reconciliation gate)  ◄── P2
     │
Ch 20 Runtime Start Coordinator  ◄── P3A
      │
Ch 99 Test Harness & CI Gating  ◄── P3
     │
Ch 14 Security & Performance (microbenchmarks)  ◄── P4
     │
  ─── BROAD IMPLEMENTATION GATE (Minimal Acceptance Checklist) ───
     │
Ch 4  Ontology
  ├──────────────┐
Ch 5  Interrogatives   Ch 6  Status & Memory
  │              │
Ch 7  World Ledger & Graph
  │
Ch 8  Scheduler & Tempo
  │
Ch 9  Delegation
  │
Ch 11 Console (introspects all above)
  │
Ch 12 Module System
  │
  ├── Ch 13  Portability
  ├── Ch 15  Documentation & ND
  └── Ch 16  Packaging & Release
```

**P0–P4** labels correspond to the Priority Execution Order table above.
Ch 2B and Ch 2C may proceed in parallel once Ch 2A prerequisites are met.
The Broad Implementation Gate (Minimal Acceptance Checklist) must pass
before work on Ch 4+ begins.

---

## SPEC Section → Chapter Map

| SPEC § | Chapter |
|---|---|
| §1 Core Principles | Ch 1 |
| §2 Persistence Model | Ch 3 |
| §3 Console Subsystem | Ch 11 |
| §4 Ontology | Ch 4 |
| §5 Runtime Lifecycle | Ch 10 |
| §5B Runtime Start Coordinator | Ch 20 |
| §6 Interrogative Manifest | Ch 5 |
| §7 Status Model | Ch 6 |
| §8 Memory Model | Ch 6 |
| §9 Delegation Model | Ch 9 |
| §10 World Ledger | Ch 7 |
| §11 World Graph | Ch 7 |
| §12 Scheduler & Tempo | Ch 8 |
| §13 Module System | Ch 12 |
| §14 Taxonomy | Ch 1 |
| §14A Testing Infrastructure | Ch 99 |
| §15 Portability | Ch 13 |
| §16 Performance | Ch 14 |
| §17 Security | Ch 14 |
| §18 Documentation | Ch 15 |
| §19 Packaging | Ch 16 |
| §20 Archive Completeness | Ch 16 |
| §21 Runtime Configuration | Ch 2A |
| §22 Messaging System | Ch 2B |
| §23 Serialization Transport | Ch 2, 2B |
| §24 Data Handling and Validation | Ch 2, 2A, 2B, 2C |
| §24.1 Input Validation Strategy | Ch 2 |
| §24.2 Validation Implementation Rules | Ch 2, 2A, 2B, 3 |
| §24.3 Safe Data Handling | Ch 2, 3 |
| §24.4 Checksum Validation | Ch 2, 3 |
| §24.5 Type Safety | Ch 2 |
| §24.6 Error Handling and Recovery | Ch 2, 3, 10 |
| §24.7 Logging and Auditing | Ch 2, 2B, 3 |
| §24.8 Confidentiality and Opacity Alignment | Ch 2, 14 |
| §24.9 Validating Prefilter Runtime | Ch 2C |
| §24.10 Validating Prefilter Data Structures | Ch 2C |
| §24.10.1 Signature Key | Ch 2C |
| §24.10.2 Validation Record | Ch 2C |
| §24.10.3 Validation Index/Table | Ch 2C |
| §24.10.4 Validation and Payload Masks | Ch 2C |
| §24.11 Prefilter Lifecycle | Ch 2C, 10 |
| §24.11.1 Compile/Build-Time Generation | Ch 2C |
| §24.11.2 Prefilter Startup Activation | Ch 10 |
| §24.11.3 Runtime Ingress Flow | Ch 2C |
| §24.11.4 Dispatch and Recording Guarantees | Ch 2C |
| §24.12 Prefilter Failure Occurrence Semantics | Ch 2C |
| §24.13 No-Copying and Regeneration Contract | Ch 2C |
| §24.14 Prefilter Performance | Ch 14 |

---

## Chapter 99 — Testing Infrastructure & CI Gating

**SPEC:** §14A Testing Infrastructure (testing harness and template)
**Goal:** Provide canonical testing artifacts used by all other chapters, enforce
core tests as merge gates, and establish CI pipeline.
**Status:** ✅ COMPLETE — harness, example tests, integration test, CI gates all implemented.

### Tasks
99.1. Create `tests/harness.nim` — provide `setupTest(name)`, `teardownTest()`, temporary directory helpers, and JSON load/write helpers.
99.2. Add canonical template `templates/test_module.nim` (already present).
99.3. Add example tests that import the harness: `tests/harness_test.nim`, `tests/example_test.nim`.
99.4. Verify `nimble test` runs and example tests pass locally.
99.5. Define the **core test suite** that must pass before merge:
      - `tests/validation_firewall_test.nim` (Ch 2C)
      - `tests/validation_firewall_perf_test.nim` (Ch 2C)
      - `tests/validation_table_generation_test.nim` (Ch 2C)
      - `tests/validation_failure_occurrence_test.nim` (Ch 2C)
      - `tests/serialization_test.nim` (Ch 2 + 2B)
      - `tests/messaging_test.nim` (Ch 2B)
      - `tests/reconciliation_test.nim` (Ch 3)
      - `tests/lifecycle_test.nim` (Ch 10)
99.6. Create or update CI workflow (`.github/workflows/ci.yml`) to run the core
      test suite on every PR. Merge must be blocked on failure.
99.7. Add integration test that exercises the full startup sequence (config → reconcile
      → prefilter activate → module load → frame loop) end-to-end.
99.8. Extend merge-gated verification with host-hardening coverage:
      - `tests/ch3_uat.nim` persistence hardening scenarios
      - `tests/lifecycle_test.nim` gate enforcement and recovery guidance
      - `tests/integration_test.nim` startup event and halt-path assertions
      - `tests/config_test.nim` override precedence and validation-script workflow
      - `tests/console_status_test.nim` CLI entrypoint and watch-stop behavior

### Acceptance
- `tests/harness.nim` compiles and is importable by test modules.
- `templates/test_module.nim` is present and referenced in developer docs.
- Example tests demonstrate harness usage and pass with `nim c -r` and `nimble test`.
- Core test suite defined and required for all merges.
- CI workflow blocks merges on core test failure.
- Integration test validates the full startup→ingress pipeline.
- Host-hardening coverage is part of the merge-gated verification set.

---

## Phase 3 Extension — Chapter 20 Runtime Start Coordinator

**SPEC:** §5B Runtime Start Coordinator
**Goal:** Add a runtime start coordinator process that accepts startup parameters,
supports flags and switches, and optionally launches an attached console.
**Status:** ✅ **COMPLETE** — `src/runtime/coordinator.nim` implemented with flag parsing, startup orchestration handoff, console mode selection (auto/attach/detach), watch-implies-attach semantics, structured startup error reporting, and daemonize flag; `tests/coordinator_test.nim` written with 7 tests all passing.

### Tasks
20.1. ✅ Create coordinator entrypoint in `src/runtime/coordinator.nim` with
      `runCoordinator` proc returning exit code and status lines.
20.2. ✅ Implement argument parsing and validation for:
      - `--config <path>` (required)
      - `--mode <dev|debug|prod>` (optional)
      - `--console <auto|attach|detach>` (optional)
      - `--watch <path>` (optional)
      - `--daemonize` (optional)
20.3. ✅ Implement startup orchestration handoff to lifecycle sequence (Ch 10).
20.4. ✅ Implement console mode behavior:
      - `detach`: start runtime with no console launch.
      - `auto`: launch and attach console after startup.
      - `attach`: wait for external console attach signal before completion.
20.5. ✅ Enforce `--watch` implies attached console mode.
20.6. ✅ Emit startup and failure events through host observability.
20.7. ✅ Add tests in `tests/coordinator_test.nim` for argument contracts,
      mode transitions, startup failure handling, and watch implications (7 tests passing).

### Acceptance
- Coordinator starts runtime with deterministic startup ordering.
- Invalid combinations and missing `--config` fail fast with usage and non-zero exit.
- `--console auto` launches attached console; `detach` mode does not.
- `--watch` behavior is only allowed through attached mode (explicit or implied).
- Startup errors provide `haltedAt`, `reason`, and `recoveryGuidance`.
- Coordinator behavior does not regress current console entrypoint semantics.


---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*