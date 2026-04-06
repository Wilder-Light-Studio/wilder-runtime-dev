# Wilder Cosmos 0.4.0
# Module name: validation
# Module Path: src/runtime/validation.nim
#
# validation.nim
# Reusable validation helpers for data handling best practices.
# Summary: Input validation at proc boundaries using fail-fast approach.
# Simile: a validator is a firewall checking data before it enters the system.
# Memory note: validation fails fast; never corrupt silently.
# Flow: input received → validate bounds/structure → fail-fast → proceed or error.

import json
import checksums/sha2
import std/[strutils, tables, sequtils]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc computeSha256*(data: openArray[byte]): string

type
  PrimitiveType* = enum
    ptAny
    ptString
    ptInt
    ptFloat
    ptBool
    ptObject
    ptArray
    ptNull

  ExtraFieldPolicy* = enum
    efRejectUnknown
    efIgnoreUnknown
    efAllowUnknown

  ValidationFailureKind* = enum
    vfUnknownSignature
    vfArgumentCountMismatch
    vfTypeMismatch
    vfMissingRequiredField
    vfUnknownFieldRejected
    vfOrderingViolation
    vfCardinalityViolation
    vfMaskMismatch
    vfNotValidated

  FieldRule* = object
    path*: string
    expectedType*: PrimitiveType
    required*: bool
    minItems*: int
    maxItems*: int

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

  ValidationIndex* = object
    byKey*: Table[string, ValidationRecord]
    byRoute*: Table[string, string]
    generationId*: string
    sourceDigests*: seq[string]

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

  InboundMessage* = object
    namespaceId*: string
    symbolId*: string
    contractVersion*: int
    args*: seq[JsonNode]

  PrefilterDecision* = object
    validated*: bool
    normalizedArgs*: seq[JsonNode]
    failure*: ValidationFailureOccurrence

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc primitiveTypeName(t: PrimitiveType): string =
  case t
  of ptAny: "any"
  of ptString: "string"
  of ptInt: "int"
  of ptFloat: "float"
  of ptBool: "bool"
  of ptObject: "object"
  of ptArray: "array"
  of ptNull: "null"

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc nodeMatchesType(n: JsonNode, expected: PrimitiveType): bool =
  case expected
  of ptAny:
    true
  of ptString:
    n.kind == JString
  of ptInt:
    n.kind == JInt
  of ptFloat:
    n.kind in {JInt, JFloat}
  of ptBool:
    n.kind == JBool
  of ptObject:
    n.kind == JObject
  of ptArray:
    n.kind == JArray
  of ptNull:
    n.kind == JNull

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc canonicalTypeVector*(args: seq[ArgumentRule]): seq[string] =
  for arg in args:
    result.add(arg.name & ":" & primitiveTypeName(arg.expectedType))

# Flow: Encode a string with a length prefix to prevent delimiter injection.
proc lenPrefixed(s: string): string =
  $s.len & ":" & s

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc deriveSignatureDigest*(namespaceId, symbolId: string,
    arity: int,
    contractVersion: int,
    typeVector: seq[string]): string =
  # Length-prefix all variable-length fields so that different field combinations
  # cannot produce the same preimage (prevents delimiter-injection collisions).
  let nsNorm = namespaceId.toLowerAscii.strip
  let symNorm = symbolId.toLowerAscii.strip
  let tvStr = typeVector.join(",").toLowerAscii
  let preimage = lenPrefixed(nsNorm) & "|" &
    lenPrefixed(symNorm) & "|" & $arity & "|" &
    $contractVersion & "|" & lenPrefixed(tvStr)
  result = computeSha256(toBytes(preimage))[0 .. 31]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc buildValidationMask*(arg: ArgumentRule): ValidationMask =
  if arg.fields.len > 64:
    raise newException(ValueError,
      "buildValidationMask: ArgumentRule has " & $arg.fields.len &
      " fields; maximum is 64. Reduce field count or split into nested rules.")
  var requiredBits: uint64 = 0'u64
  var typeBits: uint64 = 0'u64
  var cardinalityBits: uint64 = 0'u64

  for i, field in arg.fields:
    if i >= 64:
      break
    let bit = 1'u64 shl i
    if field.required:
      requiredBits = requiredBits or bit
      if field.expectedType != ptAny:
        typeBits = typeBits or bit
    if field.required and (field.minItems >= 0 or field.maxItems >= 0):
      cardinalityBits = cardinalityBits or bit

  var orderingBit: uint64 = 0'u64
  if arg.enforceOrdering:
    orderingBit = 1'u64

  result = ValidationMask(
    requiredBits: requiredBits,
    typeBits: typeBits,
    orderingBit: orderingBit,
    cardinalityBits: cardinalityBits,
    width: min(arg.fields.len, 64)
  )

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc buildValidationRecord*(namespaceId, symbolId: string,
    contractVersion: int,
    args: seq[ArgumentRule],
    sourceDigest: string = ""): ValidationRecord =
  let vector = canonicalTypeVector(args)
  let key = deriveSignatureDigest(namespaceId, symbolId, args.len, contractVersion, vector)
  result = ValidationRecord(
    namespaceId: namespaceId,
    symbolId: symbolId,
    arity: args.len,
    contractVersion: contractVersion,
    canonicalTypeVector: vector,
    keyDigest: key,
    args: args,
    sourceDigest: sourceDigest
  )
  for arg in args:
    result.masks.add(buildValidationMask(arg))

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc buildValidationIndex*(records: seq[ValidationRecord],
    generationId: string,
    sourceDigests: seq[string] = @[]): ValidationIndex =
  result.generationId = generationId
  result.sourceDigests = sourceDigests
  result.byKey = initTable[string, ValidationRecord]()
  result.byRoute = initTable[string, string]()

  for r in records:
    if r.keyDigest in result.byKey:
      raise newException(ValueError,
        "buildValidationIndex: signature digest collision detected")
    result.byKey[r.keyDigest] = r
    let route = r.namespaceId.toLowerAscii.strip & "|" &
      r.symbolId.toLowerAscii.strip & "|" & $r.contractVersion & "|" &
      $r.arity
    result.byRoute[route] = r.keyDigest

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc computePayloadMaskNoAlloc*(arg: ArgumentRule,
    payload: JsonNode,
    mask: var PayloadMask,
    normalized: var JsonNode,
    unknownFieldFound: var bool,
    orderingViolation: var bool,
    cardinalityViolation: var bool,
    firstTypeMismatchPath: var string,
    firstMissingPath: var string,
    firstUnknownPath: var string) =
  mask.requiredBits = 0
  mask.typeBits = 0
  mask.orderingBit = 0
  mask.cardinalityBits = 0
  mask.width = min(arg.fields.len, 64)
  unknownFieldFound = false
  orderingViolation = false
  cardinalityViolation = false
  firstTypeMismatchPath = ""
  firstMissingPath = ""
  firstUnknownPath = ""

  if payload.kind != JObject:
    if firstTypeMismatchPath.len == 0:
      firstTypeMismatchPath = "$"
    normalized = payload
    return

  normalized = newJObject()
  let declared = arg.fields.mapIt(it.path)
  var observedOrder: seq[string] = @[]

  for i, field in arg.fields:
    if i >= 64:
      break
    let bit = 1'u64 shl i
    if payload.hasKey(field.path):
      let node = payload[field.path]
      observedOrder.add(field.path)
      if arg.extraFieldPolicy != efRejectUnknown or field.path in declared:
        normalized[field.path] = node
      mask.requiredBits = mask.requiredBits or bit

      if nodeMatchesType(node, field.expectedType):
        mask.typeBits = mask.typeBits or bit
      elif firstTypeMismatchPath.len == 0:
        firstTypeMismatchPath = field.path

      if field.minItems >= 0 or field.maxItems >= 0:
        var count = -1
        if node.kind == JArray:
          count = node.len
        elif node.kind == JObject:
          count = node.len

        if count >= 0:
          let minOk = field.minItems < 0 or count >= field.minItems
          let maxOk = field.maxItems < 0 or count <= field.maxItems
          if minOk and maxOk:
            mask.cardinalityBits = mask.cardinalityBits or bit
          else:
            cardinalityViolation = true
    else:
      if field.required and firstMissingPath.len == 0:
        firstMissingPath = field.path

  if arg.enforceOrdering and arg.knownFieldOrder.len > 0:
    var orderOk = true
    var j = 0
    for key, _ in payload:
      if key in declared:
        if j >= arg.knownFieldOrder.len or arg.knownFieldOrder[j] != key:
          orderOk = false
          break
        inc j
    if orderOk:
      mask.orderingBit = 1
    else:
      orderingViolation = true

  for key, value in payload:
    if key notin declared:
      unknownFieldFound = true
      if firstUnknownPath.len == 0:
        firstUnknownPath = key
      if arg.extraFieldPolicy == efAllowUnknown:
        normalized[key] = value

  if arg.minItems >= 0 or arg.maxItems >= 0:
    var count = 1
    if payload.kind == JArray:
      count = payload.len
    let minOk = arg.minItems < 0 or count >= arg.minItems
    let maxOk = arg.maxItems < 0 or count <= arg.maxItems
    if minOk and maxOk:
      mask.cardinalityBits = mask.cardinalityBits or (1'u64 shl 63)
    else:
      cardinalityViolation = true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc maskConjunctionPass*(validationMask: ValidationMask,
    payloadMask: PayloadMask): bool =
  var diff: uint64 = 0
  diff = diff or ((validationMask.requiredBits and payloadMask.requiredBits) xor validationMask.requiredBits)
  diff = diff or ((validationMask.typeBits and payloadMask.typeBits) xor validationMask.typeBits)
  diff = diff or ((validationMask.orderingBit and payloadMask.orderingBit) xor validationMask.orderingBit)
  diff = diff or ((validationMask.cardinalityBits and payloadMask.cardinalityBits) xor validationMask.cardinalityBits)
  result = diff == 0'u64

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc failureId(epoch: int64,
    targetKey: string,
    kind: ValidationFailureKind,
    payloadDigest: string): string =
  let preimage = $epoch & "|" & targetKey & "|" & $kind & "|" & payloadDigest
  result = computeSha256(toBytes(preimage))[0 .. 15]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc newValidationFailure*(source: string,
    epoch: int64,
    targetKey: string,
    kind: ValidationFailureKind,
    rulePath: string,
    diagnosticsCode: string,
    payloadDigest: string,
    payloadByteLen: int): ValidationFailureOccurrence =
  result = ValidationFailureOccurrence(
    id: failureId(epoch, targetKey, kind, payloadDigest),
    source: source,
    epoch: epoch,
    targetKey: targetKey,
    failureKind: kind,
    rulePath: rulePath,
    diagnosticsCode: diagnosticsCode,
    payloadDigest: payloadDigest,
    payloadByteLen: payloadByteLen
  )

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc toJson*(f: ValidationFailureOccurrence): JsonNode =
  result = %*{
    "id": f.id,
    "source": f.source,
    "epoch": f.epoch,
    "targetKey": f.targetKey,
    "failureKind": $f.failureKind,
    "rulePath": f.rulePath,
    "diagnosticsCode": f.diagnosticsCode,
    "payloadDigest": f.payloadDigest,
    "payloadByteLen": f.payloadByteLen
  }

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc safeFailureLogLine*(f: ValidationFailureOccurrence): string =
  result = "validation_failure " &
    "id=" & f.id &
    " kind=" & $f.failureKind &
    " targetKey=" & f.targetKey &
    " rulePath=" & f.rulePath &
    " diagnostics=" & f.diagnosticsCode &
    " payloadDigest=" & f.payloadDigest &
    " payloadByteLen=" & $f.payloadByteLen

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc prefilterValidate*(index: ValidationIndex,
    inbound: InboundMessage,
    source: string,
    epoch: int64): PrefilterDecision =
  let route = inbound.namespaceId.toLowerAscii.strip & "|" &
    inbound.symbolId.toLowerAscii.strip & "|" & $inbound.contractVersion &
    "|" & $inbound.args.len

  var key = ""
  if route in index.byRoute:
    key = index.byRoute[route]
  else:
    let routePrefix = inbound.namespaceId.toLowerAscii.strip & "|" &
      inbound.symbolId.toLowerAscii.strip & "|" & $inbound.contractVersion & "|"
    for k, v in index.byRoute:
      if k.startsWith(routePrefix):
        key = v
        break
    if key.len == 0:
      key = deriveSignatureDigest(
        inbound.namespaceId,
        inbound.symbolId,
        inbound.args.len,
        inbound.contractVersion,
        @[]
      )

  var payloadDigest = computeSha256(toBytes($(%*{"args": inbound.args})))
  var payloadLen = $(%*{"args": inbound.args})

  if key notin index.byKey:
    result.failure = newValidationFailure(
      source,
      epoch,
      key,
      vfUnknownSignature,
      "signature",
      "VAL_UNKNOWN_SIGNATURE",
      payloadDigest,
      payloadLen.len
    )
    return

  let record = index.byKey[key]
  if inbound.args.len != record.args.len:
    result.failure = newValidationFailure(
      source,
      epoch,
      record.keyDigest,
      vfArgumentCountMismatch,
      "args",
      "VAL_ARG_COUNT",
      payloadDigest,
      payloadLen.len
    )
    return

  var normalizedArgs: seq[JsonNode] = @[]
  for i, argRule in record.args:
    let payload = inbound.args[i]
    if not nodeMatchesType(payload, argRule.expectedType):
      result.failure = newValidationFailure(
        source,
        epoch,
        record.keyDigest,
        vfTypeMismatch,
        "$arg[" & $i & "]",
        "VAL_ARG_TYPE",
        payloadDigest,
        payloadLen.len
      )
      return

    var payloadMask: PayloadMask
    var normalizedArg = newJNull()
    var unknownFieldFound: bool
    var orderingViolation: bool
    var cardinalityViolation: bool
    var firstTypeMismatchPath: string
    var firstMissingPath: string
    var firstUnknownPath: string

    computePayloadMaskNoAlloc(
      argRule,
      payload,
      payloadMask,
      normalizedArg,
      unknownFieldFound,
      orderingViolation,
      cardinalityViolation,
      firstTypeMismatchPath,
      firstMissingPath,
      firstUnknownPath
    )

    if firstMissingPath.len > 0:
      result.failure = newValidationFailure(
        source,
        epoch,
        record.keyDigest,
        vfMissingRequiredField,
        firstMissingPath,
        "VAL_REQUIRED_FIELD",
        payloadDigest,
        payloadLen.len
      )
      return

    if firstTypeMismatchPath.len > 0:
      result.failure = newValidationFailure(
        source,
        epoch,
        record.keyDigest,
        vfTypeMismatch,
        firstTypeMismatchPath,
        "VAL_FIELD_TYPE",
        payloadDigest,
        payloadLen.len
      )
      return

    if unknownFieldFound and argRule.extraFieldPolicy == efRejectUnknown:
      result.failure = newValidationFailure(
        source,
        epoch,
        record.keyDigest,
        vfUnknownFieldRejected,
        firstUnknownPath,
        "VAL_UNKNOWN_FIELD",
        payloadDigest,
        payloadLen.len
      )
      return

    if orderingViolation:
      result.failure = newValidationFailure(
        source,
        epoch,
        record.keyDigest,
        vfOrderingViolation,
        "$arg[" & $i & "]",
        "VAL_ORDERING",
        payloadDigest,
        payloadLen.len
      )
      return

    if cardinalityViolation:
      result.failure = newValidationFailure(
        source,
        epoch,
        record.keyDigest,
        vfCardinalityViolation,
        "$arg[" & $i & "]",
        "VAL_CARDINALITY",
        payloadDigest,
        payloadLen.len
      )
      return

    let validationMask = record.masks[i]
    if not maskConjunctionPass(validationMask, payloadMask):
      result.failure = newValidationFailure(
        source,
        epoch,
        record.keyDigest,
        vfMaskMismatch,
        "$arg[" & $i & "]",
        "VAL_MASK",
        payloadDigest,
        payloadLen.len
      )
      return

    if argRule.extraFieldPolicy == efIgnoreUnknown:
      normalizedArgs.add(normalizedArg)
    else:
      normalizedArgs.add(payload)

  result.validated = true
  result.normalizedArgs = normalizedArgs

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc dispatchValidated*(decision: PrefilterDecision,
    dispatch: proc (args: seq[JsonNode]): bool): bool =
  if not decision.validated:
    raise newException(ValueError,
      "dispatchValidated: payload is not validated")
  result = dispatch(decision.normalizedArgs)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc admitValidatedOccurrence*(decision: PrefilterDecision): bool =
  if not decision.validated:
    raise newException(ValueError,
      "admitValidatedOccurrence: payload is not validated")
  result = true

# -- Public validation procedures -- ---------------------------------------------------------

## Validate non-empty string (SPEC §24.2)
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateNonEmpty*(s: string): bool =
  ## Flow: check length > 0, return result.z
  ## Raises: ValueError if string is empty.
  if s.len == 0: # Guard against empty strings, which are often invalid inputs.
    raise newException(ValueError,
      "validateNonEmpty: string cannot be empty")
  return true

## Validate integer in range [min, max] (SPEC §24.2)
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateRange*(v: int, min: int, max: int): bool =
  ## Flow: check v >= min and v <= max, return result.
  ## Raises: ValueError if v is out of bounds.
  if v < min or v > max: # Guard against out-of-range values, which can cause logic errors or security issues.
    raise newException(ValueError,
      "validateRange: value " & $v & " not in [" & $min & ", " & $max & "]")
  return true

## Validate port number [1, 65535] (SPEC §24.2)
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validatePortRange*(port: int): bool =
  ## Flow: validate numeric range [1, 65535].
  ## Raises: ValueError if port is invalid.
  return validateRange(port, 1, 65535) 

## Validate JSON structure has required fields (SPEC §24.2)
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateStructure*(n: JsonNode, requiredFields: seq[string]): bool =
  ## Flow: check all required fields present, fail-fast on missing.
  ## Raises: ValueError if any required field is missing.
  if n.isNil: # 
    raise newException(ValueError,
      "validateStructure: JsonNode is nil")
  if n.kind != JObject:
    raise newException(ValueError,
      "validateStructure: JsonNode must be an object")
  
  for field in requiredFields:
    if field notin n:
      raise newException(ValueError,
        "validateStructure: missing required field '" & field & "'")
  
  return true

## Validate SHA256 checksum (SPEC §24.4)
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateChecksum*(data: openArray[byte], expected: string): bool =
  ## Flow: compute SHA256 hash of data, compare with expected (case-insensitive).
  ## Raises: ValueError if checksum mismatch.
  if expected.len == 0: # Guard against empty expected checksum, which is invalid input.
    raise newException(ValueError,
      "validateChecksum: expected checksum cannot be empty")

  if expected.len != 64:
    raise newException(ValueError,
      "validateChecksum: expected checksum must be 64 hex characters")

  for c in expected:
    if c notin HexDigits:
      raise newException(ValueError,
        "validateChecksum: expected checksum must be hexadecimal")
  
  let actual = computeSha256(data) # Compute actual checksum of data.
  
  if actual != expected.toLowerAscii: # Compare actual vs expected, ignoring case.
    raise newException(ValueError,
      "validateChecksum: checksum mismatch")

  return true # passed validation

## Validate JSON checksum by string (SPEC §24.4)
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateJsonChecksum*(jsonStr: string,
    expected: string): bool =
  ## Flow: compute checksum of JSON string, verify against expected.
  ## Raises: ValueError if checksum mismatch.
  var bytes = newSeq[byte](jsonStr.len)
  for i in 0 ..< jsonStr.len:
    bytes[i] = byte(jsonStr[i])
  return validateChecksum(bytes, expected)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc computeSha256*(data: openArray[byte]): string =
  ## Compute checksum of data using SHA256 algorithm.
  var asChars = newSeq[char](data.len)
  for i in 0 ..< data.len:
    asChars[i] = char(data[i])

  let digest = secureHash(Sha_256, asChars)
  result = toLowerAscii($digest)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
