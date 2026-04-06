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

---

## 8. Phase XE Licensing Addendum (Offline-first, Humane, Propagation-safe)

This addendum defines executable behavior for the licensing phase and must remain
consistent with `docs/implementation/REQUIREMENTS.md` (Phase XE) and
`docs/implementation/SPECIFICATION-NIM.md` §19F.

### 8.1 Installer Flow

- First-run licensing flow must provide clear local choices: paid path or complimentary hardship path.
- Local license generation is available only after explicit agreement to the Wilder License text.
- Declining optional transparency email has no effect on license generation or runtime behavior.
- No hidden or automatic network calls are allowed in installer licensing paths.

### 8.2 Local License Generation and File Structure

- Generation must be deterministic and offline-only.
- Local license file must be human-readable and include at minimum:
  - `schemaVersion`
  - `runtimeVersion`
  - `licenseMode` (`paid` or `complimentary`)
  - `generatedAt`
  - `identityFingerprint`
  - `agreementRef`
  - `signature`
- Validation uses only local checks (structure, signature, version compatibility).

### 8.3 Optional Transparency Email Invocation

- Email workflow must be one-time, optional, explicit, and user-initiated.
- Template content must be visible and editable before send.
- Decline and delivery failure paths are deterministic no-ops for licensing/runtime behavior.

### 8.4 Deactivation and Liberation Behavior

- Valid local license presence deactivates licensing enforcement checks for that runtime version.
- No periodic renewal or remote revalidation is permitted.
- Three-year liberation timer is version-scoped and local-only.
- On timer expiry, licensing enforcement for that version permanently deactivates.

### 8.5 Runtime Integration and Error Contract

- Runtime evaluates licensing state deterministically using local artifacts and release metadata.
- Structured states include: `licensed`, `unlicensed`, `liberated`, and `invalid_local_license`.
- Errors must remain deterministic and must not expose sensitive local identity data.

### 8.6 Testability Contract

- Deterministic generation for identical inputs.
- Valid paid/complimentary generation and validation coverage.
- Invalid/tampered local license detection coverage.
- No-network guarantees across generation, validation, deactivation, and liberation paths.
- Optional transparency-email decline and failure no-op coverage.
- Liberation timer expiry deactivation coverage.

---

## 9. Phase XF Encryption Spectrum Addendum

This addendum defines executable behavior for the Cosmos encryption spectrum and must
remain consistent with `docs/implementation/REQUIREMENTS.md` (Phase XF) and
`docs/implementation/SPECIFICATION-NIM.md` §19G and §21.

### 9.1 Mode Selector and Scope

- Runtime configuration must expose `encryptionMode` with canonical values
  `clear|standard|private|complete`.
- The selected mode applies to RECORD payloads, eidela state, persisted runtime state
  containing user data, exports, and backup artifacts.
- The mode selector is a policy contract layered over existing encryption primitives and
  reconciliation behavior, not a single algorithm switch.

### 9.2 CLEAR Behavior

- `clear` bypasses Cosmos-managed content-encryption and key-derivation layers.
- User data may be stored in plaintext for deterministic education and testing flows.
- User-facing surfaces must present `clear` as non-private.

### 9.3 STANDARD Behavior

- `standard` encrypts user content client-side before operator-controlled persistence.
- Structural metadata required for routing, timestamps, sizes, and deterministic
  reconciliation may remain visible.
- Recovery features require explicit user opt-in.

### 9.4 PRIVATE and COMPLETE Behavior

- `private` encrypts all user content client-side and minimizes metadata beyond
  `standard`, while permitting only explicit user-provisioned recovery.
- `complete` enforces end-to-end encryption with no operator plaintext access, no
  operator escrow, and no hidden recovery channel.
- `complete` must fail deterministically when required end-to-end key material is
  unavailable.

### 9.5 Migration and Failure Contract

- Startup must reject invalid mode names, missing required key material, and impossible
  recovery combinations.
- Migration to a less private mode must require explicit user-visible confirmation.
- Migration to a more private mode must complete required re-encryption before the new
  mode becomes active.

### 9.6 Testability Contract

- Deterministic mode parsing and startup validation coverage.
- CLEAR bypass coverage.
- No-plaintext-access coverage for `standard`, `private`, and `complete`.
- Metadata exposure and migration guardrail coverage.
