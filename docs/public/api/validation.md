# validation — Prefilter & Input Validation

> Source: `src/runtime/validation.nim`

Input validation at proc boundaries using a fail-fast approach. Provides reusable validation helpers for checksums, structures, and ranges, plus a deterministic bitmask-based prefilter for inbound message validation.

---

## Types

### `PrimitiveType`

```nim
PrimitiveType* = enum
  ptAny, ptString, ptInt, ptFloat, ptBool, ptObject, ptArray, ptNull
```

### `ExtraFieldPolicy`

```nim
ExtraFieldPolicy* = enum
  efRejectUnknown, efIgnoreUnknown, efAllowUnknown
```

### `ValidationFailureKind`

```nim
ValidationFailureKind* = enum
  vfUnknownSignature
  vfArgumentCountMismatch
  vfTypeMismatch
  ## … additional failure kinds
```

### `FieldRule`

Structural constraint on one JSON field.

```nim
FieldRule* = object
  path*: string
  expectedType*: PrimitiveType
  required*: bool
  minItems*: int
  maxItems*: int
```

### `ArgumentRule`

Structural constraint on one argument position.

```nim
ArgumentRule* = object
  name*: string
  expectedType*: PrimitiveType
  required*: bool
  fields*: seq[FieldRule]
  extraFieldPolicy*: ExtraFieldPolicy
  enforceOrdering*: bool
  knownFieldOrder*: seq[string]
  minItems*: int
  maxItems*: int
```

### `ValidationMask` / `PayloadMask`

Fixed-width bitmasks precomputed from rules and inbound payloads for fast conjunction-based validation.

```nim
ValidationMask* = object
  requiredBits*: uint64
  typeBits*: uint64
  orderingBit*: uint64
  cardinalityBits*: uint64
  width*: int

PayloadMask* = object
  requiredBits*: uint64
  typeBits*: uint64
  orderingBit*: uint64
  cardinalityBits*: uint64
  width*: int
```

### `ValidationRecord`

Signature validation record combining rules, masks, and metadata.

```nim
ValidationRecord* = object
  namespaceId*: string
  symbolId*: string
  arity*: int
  contractVersion*: int
  canonicalTypeVector*: seq[string]
  keyDigest*: string
  args*: seq[ArgumentRule]
  masks*: seq[ValidationMask]
  sourceDigest*: string
```

### `ValidationIndex`

Index of validation records keyed by digest, with a generation ID for cache invalidation.

```nim
ValidationIndex* = object
  byKey*: Table[string, ValidationRecord]
  byRoute*: Table[string, string]
  generationId*: string
  sourceDigests*: seq[string]
```

### `InboundMessage`

```nim
InboundMessage* = object
  namespaceId*: string
  symbolId*: string
  contractVersion*: int
  args*: seq[JsonNode]
```

### `PrefilterDecision`

```nim
PrefilterDecision* = object
  validated*: bool
  normalizedArgs*: seq[JsonNode]
  failure*: ValidationFailureOccurrence
```

### `ValidationFailureOccurrence`

```nim
ValidationFailureOccurrence* = object
  id*: string
  source*: string
  epoch*: int64
  targetKey*: string
  failureKind*: ValidationFailureKind
  rulePath*: string
  diagnosticsCode*: string
  payloadDigest*: string
  payloadByteLen*: int
```

---

## Procedures

### Building Validation Structures

```nim
proc canonicalTypeVector*(args: seq[ArgumentRule]): seq[string]
proc deriveSignatureDigest*(namespaceId, symbolId: string, arity, contractVersion: int,
                             typeVector: seq[string]): string
proc buildValidationMask*(arg: ArgumentRule): ValidationMask
proc buildValidationRecord*(namespaceId, symbolId: string, contractVersion: int,
                              args: seq[ArgumentRule], sourceDigest: string): ValidationRecord
proc buildValidationIndex*(records: seq[ValidationRecord], generationId: string,
                             sourceDigests: seq[string]): ValidationIndex
```

### Prefilter Validation

```nim
proc prefilterValidate*(index: ValidationIndex, inbound: InboundMessage,
                          source: string, epoch: int64): PrefilterDecision
```
Validate an inbound message against the prefilter index. Returns a decision with normalized args on success.

```nim
proc maskConjunctionPass*(validationMask: ValidationMask,
                           payloadMask: PayloadMask): bool
```
Boolean AND comparison for fast mask validation.

```nim
proc dispatchValidated*(decision: PrefilterDecision, dispatch: proc): bool
proc admitValidatedOccurrence*(decision: PrefilterDecision): bool
```

### Simple Validators

```nim
proc validateNonEmpty*(s: string): bool
proc validateRange*(v: int, min: int, max: int): bool
proc validatePortRange*(port: int): bool
proc validateStructure*(n: JsonNode, requiredFields: seq[string]): bool
proc validateChecksum*(data: openArray[byte], expected: string): bool
proc validateJsonChecksum*(jsonStr: string, expected: string): bool
proc computeSha256*(data: openArray[byte]): string
```

### Failure Reporting

```nim
proc newValidationFailure*(source: string, epoch: int64, targetKey: string,
                             kind: ValidationFailureKind, rulePath: string,
                             diagnosticsCode: string, payloadDigest: string,
                             payloadByteLen: int): ValidationFailureOccurrence
proc toJson*(f: ValidationFailureOccurrence): JsonNode
proc safeFailureLogLine*(f: ValidationFailureOccurrence): string
```
