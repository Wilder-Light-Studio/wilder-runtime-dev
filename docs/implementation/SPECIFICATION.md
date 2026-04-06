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

---

## 10. Security & Input Validation Specification

### 10.1 Input Sanitization

#### 10.1.1 Application Name Validation
- **Caller:** `startapp.nim:scaffoldApp()`
- **Input:** app name string from CLI `--name` flag
- **Validation:**
  - Trim leading/trailing whitespace
  - Check length: must be 1–64 characters after trimming
  - Check characters: must match regex `^[a-zA-Z0-9_\-\.\  ]+$`
    - Alphanumeric: [a-zA-Z0-9]
    - Underscore: `_`
    - Hyphen: `-`
    - Dot: `.`
    - Space: ` ` (space character)
  - Reject quotes (`"`, `'`), backslashes (`\`), newlines (`\n`, `\r`), and control chars
- **On Valid:** Proceed to template generation
- **On Invalid:** Raise `ValueError` with message: `"Invalid app name: must be 1–64 alphanumeric, underscore, hyphen, dot, or space characters"`
- **Test:** `tests/startapp_validation_test.nim` (9 test cases)

#### 10.1.2 Persistence Key Sanitization
- **Caller:** `persistence.nim:sanitizeKey()`
- **Input:** key string from caller (e.g., module name, transaction ID prefix)
- **Processing:**
  - Allowlist characters: `[a-zA-Z0-9_\-]` (alphanumeric, underscore, hyphen)
  - Normalize dots (`.`) to underscores (`_`)
  - Drop all other characters silently (no error on invalid chars)
  - Truncate to max 128 characters if longer
- **Output:** sanitized key string
- **Example:** `"module.name@1.0"` → `"module_name_1_0"` (after normalization and dropping @)
- **Note:** Allowlist-based approach replaces prior denylist for security

#### 10.1.3 Filesystem Path Validation (CLI Arguments)
- **Caller:** `cosmos_main.nim:rejectFilesystemRoot()`
- **Input:** filesystem path string from CLI args (e.g., `--file`, positional [path] arg)
- **Rejection Criteria:**
  - Windows root: `C:\`, `C:/`, `D:\`, etc. (drive letter + colon + separator)
  - Unix root: `/`
  - UNC paths: `\\server\share` (Windows network)
  - Relative path starting with `..` is allowed (design choice)
  - Relative path `./` is allowed
- **On Rejected:** Raise `ValueError` with message: `"Path must not be a filesystem root"`
- **On Accepted:** Proceed with path operations
- **Callsites:** `loadConceptFromFile()`, `runScanCommand()`
- **Test:** `tests/cosmos_main_path_safety_test.nim` (5 test cases)

---

### 10.2 Ciphertext Integrity & Authentication

#### 10.2.1 HMAC-SHA256 Authentication Tag
- **Module:** `encrypted_record.nim`
- **Primitive:** RFC 2104 HMAC using SHA256
- **Field Name:** `payloadAuthTag` on `EncryptedRecordEntry` type
- **Generation:**
  - Input preimage: `ciphertext || epoch || txId || checksum || schemaVersion`
  - (Length-prefixed encoding per §10.3.1 to prevent delimiter injection)
  - Symmetric key: entry key material (same key used for XOR encryption)
  - Output: hex-encoded 64-character string (256-bit SHA256)
- **Verification:**
  - In `verifyAndDecryptRecordEntry()`: compute fresh auth tag from ciphertext + metadata
  - Compare with stored `payloadAuthTag` using constant-time comparison
  - If mismatch: raise `RecordVerificationError("Auth tag mismatch")`
  - If match: proceed to decrypt using XOR with original key
- **JSON Serialization:**
  - Field serialized as-is in JSON
  - Old records (missing `payloadAuthTag`) default to `""` (empty string)
  - Empty auth tag is treated as "unverified" but still decryptable (backward compatibility during migration)
- **Test:** `tests/encrypted_record_test.nim` round-trip verification

#### 10.2.2 Safe Decryption API
- **Proc:** `verifyAndDecryptRecordEntry(entry: EncryptedRecordEntry; keyMaterial: string): string`
- **Contract:**
  - Verifies auth tag before decryption
  - Returns plaintext on success
  - Raises `RecordVerificationError` on auth failure
  - Raises `RecordDecryptionError` on XOR/format failure
- **Callers:** All code paths that decrypt entry ciphertexts from storage

---

### 10.3 Nonce & Signature Derivation Security

#### 10.3.1 Length-Prefixed Encoding
- **Purpose:** Prevent delimiter injection in multi-field hash preimages
- **Format:** For each field in preimage:
  ```
  <length-as-big-endian-u32><field-bytes>
  ```
- **Example:** Preimage for ["hello", "world"] encodes as:
  ```
  0x00000005 "hello" 0x00000005 "world"
  ```
- **Callsites:**
  - `encrypted_record.nim:deriveNonce()` — nonce length-prefixed from entry metadata
  - `validation.nim:deriveSignatureDigest()` — signature preimage length-prefixed
- **Test:** Implicit in encrypted_record_test round-trip and validation_firewall_test

#### 10.3.2 Nonce Derivation
- **Proc:** `deriveNonce(entry: EncryptedRecordEntry): string`
- **Input:** entry metadata (`epoch`, `txId`, `checksum`)
- **Process:**
  1. Encode `epoch` as length-prefixed u32
  2. Encode `txId` as length-prefixed string
  3. Encode `checksum` as length-prefixed hex string
  4. Concatenate: `[epoch][txId][checksum]`
  5. Hash result with SHA256
  6. Use first 16 bytes (128 bits) of hash as nonce
- **Output:** 16-byte nonce for XOR counter-mode encryption
- **Note:** No field can inject into another field via delimiter tricks

---

### 10.4 Key Derivation & Runtime Configuration

#### 10.4.1 Shutdown Snapshot Signing Key Resolution
- **Proc:** `core.nim:resolveShutdownSnapshotSigningKey(config: RuntimeConfig): string`
- **Flow:**
  1. Check environment variable `COSMOS_SHUTDOWN_SNAPSHOT_SIGNING_KEY`
  2. If present and non-empty: use as signing key (return immediately)
  3. If missing or empty: derive key from `config` fields:
     - Concatenate: `config.endpoint || ":" || config.port || ":" || config.mode || ":" || config.encryptionMode`
     - Hash with SHA256
     - Use first 32 bytes (256 bits) as derived key
  4. Return resolved key
- **Usage:** Shutdown snapshot export uses resolved key for HMAC signature
- **Test:** Implicit in lifecycle_test and shutdown flow

#### 10.4.2 Environment Override Pattern
- **Variable:** `COSMOS_SHUTDOWN_SNAPSHOT_SIGNING_KEY`
- **Behavior:** If set, completely overrides config-derived fallback
- **Security Model:** Operator has explicit control over signing key without code change
- **Note:** Production deployments should set this variable for deterministic key management

---

### 10.5 IPC Request ID Generation

#### 10.5.1 Request ID Format
- **Format:** `cli-<epochMilliseconds>-<counter>`
- **Components:**
  - `cli` prefix: identifies CLI invocation source
  - `epochMilliseconds`: UNIX epoch milliseconds at CLI start (8-11 digit number)
  - counter: 0-based incrementing counter for each request in same invocation
- **Example:** `cli-1692374400123-0`, `cli-1692374400123-1`

#### 10.5.2 ID Generation
- **Proc:** `cosmos_main.nim:nextCliRequestId(): string`
- **State:** Module-level variables:
  - `cliRequestCounter: int = 0` (per-invocation counter)
- **Logic:**
  1. Get current epoch milliseconds: `times.epochTimeMs` or equivalent
  2. Increment `cliRequestCounter`
  3. Format: `"cli-" & $epochMs & "-" & $(cliRequestCounter - 1)`
  4. Return formatted ID
- **Per-Invocation Reset:** `cliRequestCounter` resets on each new CLI invocation (new module instance)

#### 10.5.3 Subscribe ID Derivation
- **Proc:** Derived in `cosmos_main` request handler
- **Logic:** `subscribeRequestId = requestId & "-subscribe"`
- **Example:** Request `cli-1692374400123-0` → Subscribe `cli-1692374400123-0-subscribe`
- **Usage:** Used in both TCP IPC frames and in-process subscription registration
- **Note:** Subscribe ID is no longer a hardcoded singleton like `"cli-subscribe"`

#### 10.5.4 IPC Frame Format
- **Frame structure:** `{requestId: string, ...other fields...}`
- **Callsites:**
  - TCP subscribe frames: `requestId` field set to `subscribeRequestId`
  - In-process subscription: `requestId` field set to `subscribeRequestId`
  - Watch frames: `requestId` field set to derived unique ID
- **Invariant:** No hardcoded request IDs; all IDs must be generated per invocation
- **Test:** `tests/cosmos_main_ipc_id_test.nim` (2 test cases)

---

### 10.6 Exception Handling

#### 10.6.1 Bare Exception Ban
- **Rule:** All `except:` blocks must specify `except CatchableError:` or more specific type
- **Rationale:** Bare `except:` catches fatal exceptions (OutOfMemoryError, NilAccessDefect, StackOverflowError) that should halt immediately
- **Exception:** Emergency panic-and-exit contexts only; document with comment
- **Callsites:** Primarily reconciliation, persistence, and message handling (high-risk exception paths)
- **Test:** Implicit in existing test suites; regression via linting

---

### 10.7 Security Test Suites — Coverage Summary

| Requirement | Test Suite | Test Cases | Artifact |
|---|---|---|---|
| App name validation (injection) | startapp_validation_test | 9 | tests/startapp_validation_test.nim |
| Path traversal rejection | cosmos_main_path_safety_test | 5 | tests/cosmos_main_path_safety_test.nim |
| Dynamic IPC request IDs | cosmos_main_ipc_id_test | 2 | tests/cosmos_main_ipc_id_test.nim |
| AEAD auth tag verification | encrypted_record_test | (existing round-trip + auth) | tests/encrypted_record_test.nim |
| Length-prefixed encoding | validation_firewall_test | (implicit preimage tests) | tests/validation_firewall_test.nim |
| Bare exception handling | record_reconciliation_test | (implicit Catchable tests) | tests/record_reconciliation_test.nim |

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
