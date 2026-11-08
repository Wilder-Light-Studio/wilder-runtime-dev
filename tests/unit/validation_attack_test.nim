# Wilder Cosmos 0.4.0
# Module name: validation_attack_test Tests
# Module Path: tests/unit/validation_attack_test.nim
#
# Summary: Attacks the prefilter with bad data to prove MVP-VAL-6 (bullet-proof).
# Simile: Like a locksmith testing a lock, each case tries one specific way to get past it.
# Memory note: each test maps to a defect in MVP-PLAN.md; never weaken one to make it pass.
# Flow: build rule -> send hostile input -> assert rejection, exact matching and silence.
#
# Abbreviations used in this file:
#   JSON  = JavaScript Object Notation
#   NaN   = Not a Number
#   NUL   = the character with code zero
#   MVP   = minimum viable product
#   pt... = primitive type (for example, ptString is the primitive type "string")
#   vf... = validation failure (for example, vfArgumentCountMismatch)
#   VAL_  = prefix of a validation diagnostics code

import unittest
import json
import std/[math, random, strutils, tables]
import ../../src/runtime/validation

const
  RandomizedTestSeed = 20261108
  RandomizedMessageCount = 20000
  NestingDepthLimit = 64

# Flow: Build one required-by-default object field rule with no item limits.
proc fieldRule(fieldName: string,
    expectedType: PrimitiveType,
    required = true): FieldRule =
  FieldRule(path: fieldName, expectedType: expectedType, required: required,
    minItems: -1, maxItems: -1)

# Flow: Build one argument rule for an object with the given field rules.
proc objectArgument(argumentName: string, fields: seq[FieldRule]): ArgumentRule =
  ArgumentRule(name: argumentName, expectedType: ptObject, required: true,
    fields: fields, enforceOrdering: false, knownFieldOrder: @[],
    minItems: -1, maxItems: -1)

# Flow: Build one argument rule for a plain value, which has no field rules.
proc plainArgument(argumentName: string,
    expectedType: PrimitiveType,
    minItems = -1,
    maxItems = -1): ArgumentRule =
  ArgumentRule(name: argumentName, expectedType: expectedType, required: true,
    fields: @[], enforceOrdering: false, knownFieldOrder: @[],
    minItems: minItems, maxItems: maxItems)

# Flow: Build a rule index holding the given records.
proc indexOfRecords(records: seq[ValidationRecord]): ValidationIndex =
  buildValidationIndex(records, "attack", @["attack"])

# Flow: Build a rule index holding one record, named test/symbol.
proc indexOfOneArgument(argument: ArgumentRule): ValidationIndex =
  indexOfRecords(@[buildValidationRecord("test", "symbol", 1, @[argument])])

# Flow: Run the prefilter for one namespace and symbol.
proc checkMessage(index: ValidationIndex,
    namespaceId, symbolId: string,
    arguments: seq[JsonNode]): PrefilterDecision =
  prefilterValidate(index, InboundMessage(namespaceId: namespaceId,
    symbolId: symbolId, contractVersion: 1, args: arguments), "attack", 1)

# Flow: Run the prefilter with one argument against the record test/symbol.
proc checkValue(index: ValidationIndex, value: JsonNode): PrefilterDecision =
  checkMessage(index, "test", "symbol", @[value])

# Flow: Build arrays nested to exactly the given depth.
proc nestedArrays(depth: int): JsonNode =
  result = newJArray()
  for _ in 2 .. depth:
    let outerArray = newJArray()
    outerArray.add(result)
    result = outerArray

let nameFieldIndex = indexOfOneArgument(
  objectArgument("value", @[fieldRule("name", ptString)]))

suite "Attack: exact values":
  test "defect 10: valid plain values pass":
    check checkValue(indexOfOneArgument(plainArgument("value", ptString)), %"hello").validated
    check checkValue(indexOfOneArgument(plainArgument("value", ptInt)), %5).validated
    check checkValue(indexOfOneArgument(plainArgument("value", ptFloat)), %1.5).validated
    check checkValue(indexOfOneArgument(plainArgument("value", ptBool)), %true).validated
    check checkValue(indexOfOneArgument(plainArgument("value", ptArray)), %*[1, 2]).validated
    check checkValue(indexOfOneArgument(plainArgument("value", ptNull)), newJNull()).validated

  test "defect 10: wrong plain values are still rejected":
    check not checkValue(indexOfOneArgument(plainArgument("value", ptString)), %5).validated
    check not checkValue(indexOfOneArgument(plainArgument("value", ptInt)), %"5").validated
    check not checkValue(indexOfOneArgument(plainArgument("value", ptInt)), %1.5).validated
    check not checkValue(indexOfOneArgument(plainArgument("value", ptArray)), %*{"a": 1}).validated

  test "an argument with no field rules accepts any matching value":
    let anyValueIndex = indexOfOneArgument(plainArgument("value", ptAny))
    check checkValue(anyValueIndex, %*{"any": "thing"}).validated
    check checkValue(anyValueIndex, %5).validated
    let anyObjectIndex = indexOfOneArgument(plainArgument("value", ptObject))
    check checkValue(anyObjectIndex, %*{"any": "thing"}).validated

  test "item limits apply to a plain array":
    let limitedIndex = indexOfOneArgument(plainArgument("value", ptArray, 1, 2))
    check checkValue(limitedIndex, %*[1]).validated
    check not checkValue(limitedIndex, %*[]).validated
    check not checkValue(limitedIndex, %*[1, 2, 3]).validated

  test "item limits reject a value that has no items":
    let argument = objectArgument("value", @[FieldRule(path: "tags",
      expectedType: ptAny, required: false, minItems: 1, maxItems: 3)])
    check not checkValue(indexOfOneArgument(argument), %*{"tags": 5}).validated

  test "defect 5: a number too large for int never passes as text":
    let oversizedNumber = parseJson("""{"name": 123456789012345678901234567890}""")
    check not checkValue(nameFieldIndex, oversizedNumber).validated

  test "defect 5: a too-large number is rejected even where any value is allowed":
    let oversizedNumber = parseJson("""{"x": [123456789012345678901234567890]}""")
    let anyValueIndex = indexOfOneArgument(plainArgument("value", ptAny))
    check not checkValue(anyValueIndex, oversizedNumber).validated

  test "a real string made of digits still passes":
    check checkValue(nameFieldIndex, %*{"name": "12345678901234567890123456789"}).validated

  test "defect 6: infinity and NaN are rejected":
    let floatFieldIndex = indexOfOneArgument(
      objectArgument("value", @[fieldRule("amount", ptFloat)]))
    check not checkValue(floatFieldIndex, parseJson("""{"amount": 1e999}""")).validated
    check not checkValue(floatFieldIndex, parseJson("""{"amount": -1e999}""")).validated
    check not checkValue(floatFieldIndex, %*{"amount": NaN}).validated
    check checkValue(floatFieldIndex, %*{"amount": 1.5}).validated

  test "defect 7: NUL and invalid text are rejected":
    check not checkValue(nameFieldIndex, parseJson("{\"name\": \"a\\u0000b\"}")).validated
    check not checkValue(nameFieldIndex, %*{"name": "a\xFF\xFEb"}).validated

  test "defect 7: bad text is rejected inside field names and nested values":
    let anyValueIndex = indexOfOneArgument(plainArgument("value", ptAny))
    check not checkValue(anyValueIndex, %*{"a\xFF": 1}).validated
    check not checkValue(anyValueIndex, %*{"a": [{"b": "c\xFF"}]}).validated

  test "valid unicode text passes":
    check checkValue(nameFieldIndex, %*{"name": "héllo 音楽 🎵"}).validated

  test "an unknown field is always rejected":
    check not checkValue(nameFieldIndex, %*{"name": "ok", "extra": 1}).validated

  test "defect 14: the policies that alter or admit data are gone":
    check not compiles(efIgnoreUnknown)
    check not compiles(efAllowUnknown)

suite "Attack: names and lookup":
  test "defect 3: a separator in a name can't share another name's rules":
    let index = indexOfRecords(@[
      buildValidationRecord("a|b", "c", 1,
        @[objectArgument("first", @[fieldRule("x", ptInt)])]),
      buildValidationRecord("a", "b|c", 1,
        @[objectArgument("second", @[fieldRule("x", ptString)])])])
    check checkMessage(index, "a|b", "c", @[%*{"x": 1}]).validated
    check not checkMessage(index, "a|b", "c", @[%*{"x": "bad"}]).validated
    check checkMessage(index, "a", "b|c", @[%*{"x": "good"}]).validated
    check not checkMessage(index, "a", "b|c", @[%*{"x": 1}]).validated

  test "defect 4: names differing only by capitals keep separate rules":
    let index = indexOfRecords(@[
      buildValidationRecord("test", "Notes", 1,
        @[objectArgument("first", @[fieldRule("x", ptInt)])]),
      buildValidationRecord("test", "notes", 1,
        @[objectArgument("second", @[fieldRule("x", ptString)])])])
    check checkMessage(index, "test", "Notes", @[%*{"x": 1}]).validated
    check not checkMessage(index, "test", "Notes", @[%*{"x": "bad"}]).validated
    check checkMessage(index, "test", "notes", @[%*{"x": "good"}]).validated

  test "defect 4: lookup is exact":
    check not checkMessage(nameFieldIndex, "TEST", "symbol", @[%*{"name": "ok"}]).validated
    check not checkMessage(nameFieldIndex, "test", "SYMBOL", @[%*{"name": "ok"}]).validated
    check not checkMessage(nameFieldIndex, " test", "symbol", @[%*{"name": "ok"}]).validated

  test "a row that would collide is a load error":
    expect(ValueError):
      discard indexOfRecords(@[
        buildValidationRecord("test", "symbol", 1, @[plainArgument("a", ptInt)]),
        buildValidationRecord("test", "symbol", 1, @[plainArgument("b", ptString)])])

  test "defect 13: a wrong argument count uses a direct lookup":
    check compiles(nameFieldIndex.bySymbol.len)
    let oneArgument = buildValidationRecord("test", "symbol", 1,
      @[plainArgument("a", ptInt)])
    let twoArguments = buildValidationRecord("test", "symbol", 1,
      @[plainArgument("a", ptInt), plainArgument("b", ptInt)])
    let index = indexOfRecords(@[oneArgument, twoArguments])
    let decision = checkMessage(index, "test", "symbol", @[%1, %2, %3])
    check not decision.validated
    check decision.failure.failureKind == vfArgumentCountMismatch
    check decision.failure.targetKey == oneArgument.keyDigest

suite "Attack: forging a pass":
  test "defect 2: a pass can't be built outside the checker":
    check not compiles(PrefilterDecision(validated: true))
    check not compiles(PrefilterDecision(normalizedArgs: @[%"x"]))

  test "defect 2: an existing decision can't be changed to a pass":
    var decision: PrefilterDecision
    template assignPass() =
      decision.validated = true
    check not compiles(assignPass())

  test "the value delivered can't be changed after the check":
    let payload = %*{"name": "original"}
    let decision = checkValue(nameFieldIndex, payload)
    check decision.validated
    payload["name"] = %"changed"
    check decision.normalizedArgs[0]["name"].getStr() == "original"

suite "Attack: reveal nothing":
  let hostileFieldName = "secret=hunter2\nvalidation_failure id=FORGED"
  let decision = checkValue(nameFieldIndex, %*{"name": "ok", hostileFieldName: 1})

  test "defect 8: a rejected field's name isn't in the failure":
    check not decision.validated
    check decision.failure.rulePath == "$unknown"
    check "hunter2" notin $decision.failure.toJson()

  test "defect 9: a rejected field's name can't add a log line":
    let logLine = safeFailureLogLine(decision.failure)
    check "\n" notin logLine
    check "FORGED" notin logLine

  test "a log line can't be split by a newline inside a rule's own name":
    let argument = objectArgument("value",
      @[fieldRule("a\nvalidation_failure id=FORGED", ptString)])
    let failedDecision = checkValue(indexOfOneArgument(argument), %*{})
    check not failedDecision.validated
    check "\n" notin safeFailureLogLine(failedDecision.failure)

suite "Attack: bounded nesting":
  test "nesting at the limit passes":
    let arrayIndex = indexOfOneArgument(plainArgument("value", ptArray))
    check checkValue(arrayIndex, nestedArrays(NestingDepthLimit)).validated

  test "nesting past the limit is rejected":
    let arrayIndex = indexOfOneArgument(plainArgument("value", ptArray))
    let anyValueIndex = indexOfOneArgument(plainArgument("value", ptAny))
    check not checkValue(arrayIndex, nestedArrays(NestingDepthLimit + 1)).validated
    check not checkValue(anyValueIndex, nestedArrays(5000)).validated

type
  SampleValue = object
    node: JsonNode
    typeName: string
    isSafe: bool
    itemCount: int

# Flow: Build the pool of good and hostile values the randomized test draws from.
proc sampleValuePool(): seq[SampleValue] =
  let oversizedNumber = parseJson("[123456789012345678901234567890]")[0]
  let infinity = parseJson("[1e999]")[0]
  result = @[
    SampleValue(node: %"text", typeName: "string", isSafe: true),
    SampleValue(node: %"", typeName: "string", isSafe: true),
    SampleValue(node: %"123", typeName: "string", isSafe: true),
    SampleValue(node: %5, typeName: "int", isSafe: true),
    SampleValue(node: %(-1), typeName: "int", isSafe: true),
    SampleValue(node: %1.5, typeName: "float", isSafe: true),
    SampleValue(node: %true, typeName: "bool", isSafe: true),
    SampleValue(node: newJNull(), typeName: "null", isSafe: true),
    SampleValue(node: %*[], typeName: "array", isSafe: true, itemCount: 0),
    SampleValue(node: %*[1], typeName: "array", isSafe: true, itemCount: 1),
    SampleValue(node: %*[1, 2, 3, 4], typeName: "array", isSafe: true, itemCount: 4),
    SampleValue(node: %*{"a": 1}, typeName: "object", isSafe: true, itemCount: 1),
    SampleValue(node: oversizedNumber, typeName: "string", isSafe: false),
    SampleValue(node: infinity, typeName: "float", isSafe: false),
    SampleValue(node: %"a\0b", typeName: "string", isSafe: false),
    SampleValue(node: %"\xFF", typeName: "string", isSafe: false),
    SampleValue(node: %*[%"\xFF"], typeName: "array", isSafe: false, itemCount: 1),
    SampleValue(node: nil, typeName: "nil", isSafe: false)
  ]

# Flow: Decide, independently of the checker, whether a sample fits a field.
proc sampleFitsField(sample: SampleValue, expectedField: string): bool =
  if not sample.isSafe:
    return false
  case expectedField
  of "float": sample.typeName in ["int", "float"]
  of "tags": sample.typeName == "array" and sample.itemCount in 1 .. 3
  else: sample.typeName == expectedField

# Flow: Count random messages where the checker and an independent oracle disagree.
proc countRandomizedDisagreements(messageCount: int): int =
  let index = indexOfOneArgument(objectArgument("value", @[
    fieldRule("id", ptString),
    fieldRule("count", ptInt),
    fieldRule("ratio", ptFloat, required = false),
    FieldRule(path: "tags", expectedType: ptArray, required: false,
      minItems: 1, maxItems: 3)]))
  let pool = sampleValuePool()
  var randomSource = initRand(RandomizedTestSeed)
  const fields = [("id", "string", true), ("count", "int", true),
                  ("ratio", "float", false), ("tags", "tags", false)]
  for _ in 1 .. messageCount:
    let message = newJObject()
    var expectedToPass = true
    for (fieldName, expectedField, isRequired) in fields:
      let includeField = randomSource.rand(99) < (if isRequired: 90 else: 50)
      if includeField:
        let sample = pool[randomSource.rand(pool.high)]
        message[fieldName] = sample.node
        expectedToPass = expectedToPass and sample.sampleFitsField(expectedField)
      elif isRequired:
        expectedToPass = false
    if randomSource.rand(99) < 15:
      message["extra"] = %1
      expectedToPass = false
    if checkValue(index, message).validated != expectedToPass:
      inc result

suite "Attack: randomized":
  test "the checker matches an independent oracle on random messages":
    check countRandomizedDisagreements(RandomizedMessageCount) == 0

suite "Attack: never fails open":
  test "an error inside the checker is a rejection":
    var brokenRecord = buildValidationRecord("test", "symbol", 1,
      @[objectArgument("value", @[fieldRule("name", ptString)])])
    brokenRecord.masks = @[]
    let decision = checkValue(indexOfRecords(@[brokenRecord]), %*{"name": "ok"})
    check not decision.validated
    check decision.failure.diagnosticsCode == "VAL_INTERNAL"

  test "defect 1: a nil value nested inside data is rejected":
    let messageWithNil = newJObject()
    messageWithNil["name"] = nil
    check not checkValue(nameFieldIndex, messageWithNil).validated

  test "defect 1: a nil argument is rejected, not a crash":
    check not checkValue(nameFieldIndex, nil).validated

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
