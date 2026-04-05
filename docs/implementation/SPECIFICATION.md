# WILDER COSMOS RUNTIME — PHASE X SPECIFICATION (v0.1.1)

This document defines the executable specification for:

- DRY wants/provides contracts
- capability discovery and startup gating
- multi-module provide bindings
- Nim-first boundary derivation
- `cosmos capabilities` and `cosmos concept resolve` CLI behavior

This specification supplements `docs/implementation/SPECIFICATION-NIM.md` and is normative for Phase X.

---

## 1. Capability Graph Data Contract

### 1.1 Canonical Keys

- `ThingKey := thingName`
- `ProvideKey := thingName + "." + provideName`
- `WantRef := thingName | thingName + "." + provideName`

Normalization rules:

- Trim leading/trailing whitespace on all identifiers.
- Empty identifiers are invalid.
- Capability matching is case-sensitive after normalization.

### 1.2 Graph Records

Implement these records (or equivalent fields) in runtime data structures:

- `ThingNode`:
  - `thingName: string`
  - `moduleId: string`
- `ProvideNode`:
  - `thingName: string`
  - `provideName: string`
  - `signature: string`
  - `declaredIn: string` (boundary source id)
- `WantNode`:
  - `consumerThing: string`
  - `reference: string`
  - `expectedSignature: string` (optional; empty means provider canonical)
  - `declaredIn: string`
- `ModuleBinding`:
  - `provideKey: string`
  - `moduleType: string` (`nim|python|rust|node|binary`)
  - `moduleRef: string`
  - `entrypoint: string`
  - `abiVersion: string`

### 1.3 Graph Snapshot

Startup must produce one immutable capability graph snapshot containing:

- all `ThingNode` entries
- all `ProvideNode` entries
- all `WantNode` entries
- all `ModuleBinding` entries
- computed `bindings` (want -> provide)
- computed `issues`
- `startupEligible: bool`

---

## 2. Resolution Algorithm

### 2.1 Input

- `provides: seq[ProvideNode]`
- `wants: seq[WantNode]`
- `moduleBindings: seq[ModuleBinding]`

### 2.2 Deterministic Steps

1. Normalize all identifiers.
2. Reject malformed declarations (empty thing/provide/signature fields).
3. Index providers by `thingName` and `provideKey`.
4. Validate module bindings:
   - every declared provide has exactly one implementation binding,
   - no implementation for undeclared provides,
   - no duplicate implementation claims for one `provideKey`.
5. Resolve each want:
   - if whole-Thing want, expand to all provides in provider thing.
   - if point want, resolve exact `provideKey`.
6. Validate signatures:
   - provider signature is canonical,
   - if `expectedSignature` is present, it must equal provider signature.
7. Emit `CapabilityBinding` rows for successful resolution.
8. Emit `CapabilityIssue` rows for failures and orphaned provides.
9. Compute `startupEligible`:
   - false if any fatal issue exists,
   - true otherwise.

### 2.3 Complexity Targets

- Build indexes: `O(P)`
- Resolve wants: `O(W + E)` where `E` is whole-Thing expansion count
- No quadratic scan over all providers for each want

---

## 3. Error Conditions and Startup Gate

### 3.1 Issue Kinds

Runtime must represent at least these issue kinds:

- `MissingProviderThing`
- `MissingProvide`
- `ProviderConflict`
- `SignatureMismatch`
- `OrphanedProvide`
- `MissingImplementation`
- `UndeclaredProvideImplementation`
- `ImplementationConflict`

### 3.2 Fatal vs Non-Fatal

Fatal issues (startup must fail):

- `MissingProviderThing`
- `MissingProvide`
- `ProviderConflict`
- `SignatureMismatch`
- `MissingImplementation`
- `UndeclaredProvideImplementation`
- `ImplementationConflict`

Non-fatal issues:

- `OrphanedProvide`

### 3.3 Startup Refusal Contract

If any fatal issue exists:

- runtime must refuse to start,
- lifecycle state must halt before module execution,
- structured error output must include:
  - `haltedAt: "capability-resolution"`
  - `reason: <first fatal issue summary>`
  - `recoveryGuidance: <operator action>`

---

## 4. Multi-Module Binding ABI

### 4.1 Stable Registration Shape

Each implementation module must register with:

- `provideKey`
- `moduleType`
- `moduleRef`
- `entrypoint`
- `abiVersion`

### 4.2 Compatibility Rules

- `abiVersion` must match one supported runtime ABI string.
- `provideKey` must reference a declared provider boundary.
- One and only one active implementation binding per `provideKey`.

### 4.3 Binding Phase

Binding must execute at startup in this order:

1. load declarations (Nim boundary and/or manual Concept)
2. load implementation descriptors
3. validate binding constraints
4. finalize capability graph
5. open runtime lifecycle

---

## 5. Nim-first Boundary and Concept Derivation

### 5.1 Source Inputs

The Concept Derivation Engine must accept:

- Nim boundary declarations
- manual Concept files

SEM input is optional and must not be required for Phase X correctness.

### 5.2 Extraction Rules

- Extract provides from canonical provider boundary declarations.
- Extract wants references from boundary declarations.
- Do not infer or duplicate signatures from consumer wants.
- Validate extracted signatures using provider canonical declarations.

### 5.3 Registry Population

The derivation engine must emit registry entries that include:

- thing identity
- provides (name + signature)
- wants references
- resolution status
- binding metadata

---

## 6. CLI Specification

### 6.1 `cosmos capabilities`

Required behavior:

- list all Things in the graph
- list all provides
- list all wants
- list resolution status and issue counts

Minimum output contract (line-oriented):

- `things: <N>`
- `provides: <N>`
- `wants: <N>`
- `bindings: <N>`
- `issues: <N>`
- one issue line per issue: `issue: <IssueKind> <Reference>`

Exit codes:

- `0` when command executes successfully (regardless of issue count)
- `2` for invalid CLI arguments

### 6.2 `cosmos concept resolve`

Required behavior:

- accept one `--want` target
- show mapping from want to provider capability
- show unresolved, ambiguous, or mismatch diagnostics

Minimum output contract:

- success:
  - `resolve: ok`
  - `bindings: <N>`
  - `binding: <WantRef> -> <Thing.provide> [<signature>]`
- failure:
  - `resolve: unresolved - <detail>`

Exit codes:

- `0` for resolved mappings
- `2` for unresolved or invalid arguments

---

## 7. Compliance and Testability Matrix

Phase X implementation is complete only when:

- requirement-level tests exist for each issue kind and startup gate behavior
- deterministic output tests exist for both CLI commands
- module binding validation tests cover all binding error classes
- concept derivation tests verify Nim-first extraction and registry population
- no consumer-side signature duplication is required by any test or runtime path
