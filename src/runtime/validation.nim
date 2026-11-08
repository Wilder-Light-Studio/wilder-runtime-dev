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
#
# Abbreviations used in this file:
#   JSON  = JavaScript Object Notation
#   UTF-8 = Unicode Transformation Format, 8-bit
#   NUL   = the character with code zero
#   NaN   = Not a Number
#   SHA   = Secure Hash Algorithm
#   MiB   = mebibyte (1,048,576 bytes)
#   pt... = primitive type (for example, ptString)
#   vf... = validation failure (for example, vfTypeMismatch)
#   uvi.. = unsafe value issue (for example, uviNil)
#   VAL_  = prefix of a validation diagnostics code

import json
import checksums/sha2
import std/[math, strutils, tables, sequtils]
from std/unicode import validateUtf8

const
  MaxMessageBytes* = 1_048_576       ## 1 MiB: larger messages are refused unparsed.
  MaxNestingDepth* = 64              ## Deeper arrays and objects are refused.
  UnknownFieldRulePath* = "$unknown" ## Reported instead of an unknown field's own name.

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
    vfUnsafeValue
    vfInternalError

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
    bySymbol*: Table[string, string] ## First row for a name and version, at any argument count.
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
    ## Fields are private: only prefilterValidate can produce a passing decision.
    validated: bool
    normalizedArgs: seq[JsonNode]
    failure: ValidationFailureOccurrence

# Flow: Report whether the checker passed this message.
proc validated*(decision: PrefilterDecision): bool =
  decision.validated

# Flow: Return the checked arguments of a passing decision.
proc normalizedArgs*(decision: PrefilterDecision): seq[JsonNode] =
  decision.normalizedArgs

# Flow: Return the failure record of a rejected decision.
proc failure*(decision: PrefilterDecision): ValidationFailureOccurrence =
  decision.failure

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

# Flow: Build the exact lookup key for one name, version and argument count.
proc routeKey(namespaceId, symbolId: string, contractVersion, arity: int): string =
  lenPrefixed(namespaceId) & "|" & lenPrefixed(symbolId) & "|" &
    $contractVersion & "|" & $arity

# Flow: Build the exact lookup key for one name and version, at any argument count.
proc symbolKey(namespaceId, symbolId: string, contractVersion: int): string =
  lenPrefixed(namespaceId) & "|" & lenPrefixed(symbolId) & "|" & $contractVersion

# Flow: Derive the signature digest from exact names, so different names never match.
proc deriveSignatureDigest*(namespaceId, symbolId: string,
    arity: int,
    contractVersion: int,
    typeVector: seq[string]): string =
  # Length-prefix all variable-length fields so that different field combinations
  # cannot produce the same preimage (prevents delimiter-injection collisions).
  let preimage = lenPrefixed(namespaceId) & "|" &
    lenPrefixed(symbolId) & "|" & $arity & "|" &
    $contractVersion & "|" & lenPrefixed(typeVector.join(","))
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

# Flow: Build the rule index. A row that would share another row's lookup is a load error.
proc buildValidationIndex*(records: seq[ValidationRecord],
    generationId: string,
    sourceDigests: seq[string] = @[]): ValidationIndex =
  result.generationId = generationId
  result.sourceDigests = sourceDigests
  result.byKey = initTable[string, ValidationRecord]()
  result.byRoute = initTable[string, string]()
  result.bySymbol = initTable[string, string]()

  for r in records:
    if r.keyDigest in result.byKey:
      raise newException(ValueError,
        "buildValidationIndex: signature digest collision detected")
    let route = routeKey(r.namespaceId, r.symbolId, r.contractVersion, r.arity)
    if route in result.byRoute:
      raise newException(ValueError,
        "buildValidationIndex: two rows share one name and argument count")
    result.byKey[r.keyDigest] = r
    result.byRoute[route] = r.keyDigest
    let symbol = symbolKey(r.namespaceId, r.symbolId, r.contractVersion)
    if symbol notin result.bySymbol:
      result.bySymbol[symbol] = r.keyDigest

# Flow: Return true when a value is a container whose item count is within its limits.
proc itemCountAllowed(node: JsonNode, minItems, maxItems: int): bool =
  if node.kind notin {JArray, JObject}:
    return false
  let count = node.len
  (minItems < 0 or count >= minItems) and (maxItems < 0 or count <= maxItems)

# Flow: Compare a payload with one argument rule and record what was found.
proc computePayloadMaskNoAlloc*(arg: ArgumentRule,
    payload: JsonNode,
    mask: var PayloadMask,
    unknownFieldFound: var bool,
    orderingViolation: var bool,
    cardinalityViolation: var bool,
    firstTypeMismatchPath: var string,
    firstMissingPath: var string) =
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

  # An argument with no field rules is a plain value: its type and item count decide.
  if arg.fields.len == 0:
    if not nodeMatchesType(payload, arg.expectedType):
      firstTypeMismatchPath = "$"
    if arg.minItems >= 0 or arg.maxItems >= 0:
      cardinalityViolation = not itemCountAllowed(payload, arg.minItems, arg.maxItems)
    return

  if payload.kind != JObject:
    firstTypeMismatchPath = "$"
    return

  let declared = arg.fields.mapIt(it.path)

  for i, field in arg.fields:
    if i >= 64:
      break
    let bit = 1'u64 shl i
    if payload.hasKey(field.path):
      let node = payload[field.path]
      mask.requiredBits = mask.requiredBits or bit

      if nodeMatchesType(node, field.expectedType):
        mask.typeBits = mask.typeBits or bit
      elif firstTypeMismatchPath.len == 0:
        firstTypeMismatchPath = field.path

      if field.minItems >= 0 or field.maxItems >= 0:
        if itemCountAllowed(node, field.minItems, field.maxItems):
          mask.cardinalityBits = mask.cardinalityBits or bit
        else:
          cardinalityViolation = true
    elif field.required and firstMissingPath.len == 0:
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

  for key, _ in payload:
    if key notin declared:
      unknownFieldFound = true

  if arg.minItems >= 0 or arg.maxItems >= 0:
    cardinalityViolation = cardinalityViolation or
      not itemCountAllowed(payload, arg.minItems, arg.maxItems)

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

# Flow: Escape control characters and spaces so a value can't alter a log line's shape.
proc escapeForLog(text: string): string =
  for character in text:
    if character <= ' ' or character == '\x7F':
      result.add("\\x" & toHex(ord(character), 2))
    else:
      result.add(character)

# Flow: Build one log line that holds only escaped, rule-derived metadata.
proc safeFailureLogLine*(f: ValidationFailureOccurrence): string =
  result = "validation_failure " &
    "id=" & escapeForLog(f.id) &
    " kind=" & $f.failureKind &
    " targetKey=" & escapeForLog(f.targetKey) &
    " rulePath=" & escapeForLog(f.rulePath) &
    " diagnostics=" & escapeForLog(f.diagnosticsCode) &
    " payloadDigest=" & escapeForLog(f.payloadDigest) &
    " payloadByteLen=" & $f.payloadByteLen

# Flow: Refuse an oversized or too deeply nested message line before it is parsed.
proc precheckMessage*(line: string): string =
  ## Returns "" when the line may be parsed, otherwise the reason it may not.
  if line.len > MaxMessageBytes:
    return "message exceeds size limit"
  var depth = 0
  var insideText = false
  var escapedCharacter = false
  for character in line:
    if insideText:
      if escapedCharacter:
        escapedCharacter = false
      elif character == '\\':
        escapedCharacter = true
      elif character == '"':
        insideText = false
    else:
      case character
      of '"':
        insideText = true
      of '[', '{':
        inc depth
        if depth > MaxNestingDepth:
          return "message exceeds nesting limit"
      of ']', '}':
        if depth > 0:
          dec depth
      else:
        discard
  return ""

type
  UnsafeValueIssue = enum
    ## Why a value can't be accepted, whatever its rule says.
    uviNone
    uviNil
    uviTooDeep
    uviNumberOutOfRange
    uviNotFinite
    uviBadText

# Flow: Return true when text is valid UTF-8 and holds no NUL character.
proc textIsSafe(text: string): bool =
  '\0' notin text and validateUtf8(text) == -1

# Flow: Detect a number too large for int, which the JSON parser stores as unquoted text.
proc isOversizedNumber(node: JsonNode): bool =
  node.str.len > 0 and node.str[0] in {'-', '0' .. '9'} and ($node)[0] != '"'

# Flow: Walk a whole value and report the first reason it can't be accepted.
proc findUnsafeValue(node: JsonNode, depth: int): UnsafeValueIssue =
  if node.isNil:
    return uviNil
  case node.kind
  of JString:
    if isOversizedNumber(node):
      return uviNumberOutOfRange
    if not textIsSafe(node.str):
      return uviBadText
  of JFloat:
    if classify(node.fnum) in {fcNan, fcInf, fcNegInf}:
      return uviNotFinite
  of JArray:
    if depth > MaxNestingDepth:
      return uviTooDeep
    for item in node.elems:
      let issue = findUnsafeValue(item, depth + 1)
      if issue != uviNone:
        return issue
  of JObject:
    if depth > MaxNestingDepth:
      return uviTooDeep
    for fieldName, fieldValue in node.fields.pairs:
      if not textIsSafe(fieldName):
        return uviBadText
      let issue = findUnsafeValue(fieldValue, depth + 1)
      if issue != uviNone:
        return issue
  else:
    discard
  return uviNone

# Flow: Return the diagnostics code for one unsafe value issue.
proc diagnosticsCodeFor(issue: UnsafeValueIssue): string =
  case issue
  of uviNone: ""
  of uviNil: "VAL_NIL"
  of uviTooDeep: "VAL_DEPTH"
  of uviNumberOutOfRange: "VAL_NUMBER_RANGE"
  of uviNotFinite: "VAL_NOT_FINITE"
  of uviBadText: "VAL_BAD_TEXT"

# Flow: Digest the arguments for a failure record, or a fixed value if they can't be printed.
proc fingerprintArguments(arguments: seq[JsonNode],
    printable: bool): tuple[digest: string, byteLength: int] =
  if not printable:
    return (computeSha256(toBytes("")), 0)
  let text = $(%*{"args": arguments})
  (computeSha256(toBytes(text)), text.len)

# Flow: Check one message against its rule. May raise; prefilterValidate contains that.
proc checkInboundMessage(index: ValidationIndex,
    inbound: InboundMessage,
    source: string,
    epoch: int64): PrefilterDecision =
  var unsafeIssue = uviNone
  for argument in inbound.args:
    unsafeIssue = findUnsafeValue(argument, 1)
    if unsafeIssue != uviNone:
      break
  # Only the first issue is known, so any unsafe value may also hold a nil.
  # Unsafe values are therefore never turned into text.
  let printable = unsafeIssue == uviNone

  template reject(targetKey: string,
      kind: ValidationFailureKind,
      rulePath: string,
      diagnosticsCode: string) =
    let fingerprint = fingerprintArguments(inbound.args, printable)
    result.failure = newValidationFailure(source, epoch, targetKey, kind, rulePath,
      diagnosticsCode, fingerprint.digest, fingerprint.byteLength)
    return

  if unsafeIssue != uviNone:
    reject("", vfUnsafeValue, "$", diagnosticsCodeFor(unsafeIssue))

  var key = index.byRoute.getOrDefault(routeKey(inbound.namespaceId,
    inbound.symbolId, inbound.contractVersion, inbound.args.len))
  if key.len == 0:
    # A known name with the wrong argument count, found without scanning the table.
    key = index.bySymbol.getOrDefault(symbolKey(inbound.namespaceId,
      inbound.symbolId, inbound.contractVersion))
  if key.len == 0 or key notin index.byKey:
    reject(deriveSignatureDigest(inbound.namespaceId, inbound.symbolId,
      inbound.args.len, inbound.contractVersion, @[]),
      vfUnknownSignature, "signature", "VAL_UNKNOWN_SIGNATURE")

  let record = index.byKey[key]
  if inbound.args.len != record.args.len:
    reject(record.keyDigest, vfArgumentCountMismatch, "args", "VAL_ARG_COUNT")
  if record.masks.len != record.args.len:
    reject(record.keyDigest, vfInternalError, "$", "VAL_INTERNAL")

  var checkedArguments: seq[JsonNode] = @[]
  for argumentNumber, argumentRule in record.args:
    let payload = inbound.args[argumentNumber]
    let argumentPath = "$arg[" & $argumentNumber & "]"
    if not nodeMatchesType(payload, argumentRule.expectedType):
      reject(record.keyDigest, vfTypeMismatch, argumentPath, "VAL_ARG_TYPE")

    var payloadMask: PayloadMask
    var unknownFieldFound: bool
    var orderingViolation: bool
    var cardinalityViolation: bool
    var firstTypeMismatchPath: string
    var firstMissingPath: string
    computePayloadMaskNoAlloc(argumentRule, payload, payloadMask, unknownFieldFound,
      orderingViolation, cardinalityViolation, firstTypeMismatchPath, firstMissingPath)

    if firstMissingPath.len > 0:
      reject(record.keyDigest, vfMissingRequiredField, firstMissingPath, "VAL_REQUIRED_FIELD")
    if firstTypeMismatchPath.len > 0:
      reject(record.keyDigest, vfTypeMismatch, firstTypeMismatchPath, "VAL_FIELD_TYPE")
    if unknownFieldFound:
      # Never report the field's own name: it is incoming data.
      reject(record.keyDigest, vfUnknownFieldRejected, UnknownFieldRulePath, "VAL_UNKNOWN_FIELD")
    if orderingViolation:
      reject(record.keyDigest, vfOrderingViolation, argumentPath, "VAL_ORDERING")
    if cardinalityViolation:
      reject(record.keyDigest, vfCardinalityViolation, argumentPath, "VAL_CARDINALITY")
    if not maskConjunctionPass(record.masks[argumentNumber], payloadMask):
      reject(record.keyDigest, vfMaskMismatch, argumentPath, "VAL_MASK")

    # A private copy: the sender can't change the value after it was checked.
    checkedArguments.add(payload.copy())

  result.validated = true
  result.normalizedArgs = checkedArguments

# Flow: Run the check inside one error boundary, so any internal error is a rejection.
proc prefilterValidate*(index: ValidationIndex,
    inbound: InboundMessage,
    source: string,
    epoch: int64): PrefilterDecision =
  try:
    result = checkInboundMessage(index, inbound, source, epoch)
  except CatchableError, Defect:
    result = PrefilterDecision(validated: false,
      failure: newValidationFailure(source, epoch, "", vfInternalError, "$",
        "VAL_INTERNAL", "", 0))

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
