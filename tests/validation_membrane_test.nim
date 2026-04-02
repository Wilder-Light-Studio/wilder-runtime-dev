# Wilder Cosmos 0.4.0
# Module name: validation_membrane_test Tests
# Module Path: tests/validation_membrane_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## validation_membrane_test.nim
#
## Summary: Concrete membrane behavior tests for Chapter 2C acceptance.
## Simile: Like testing a biological membrane deciding what passes through.
## Memory note: membrane behavior is deterministic; test prefilter coverage thoroughly.
## Flow: test prefilter -> test membrane behavior -> verify fail-fast -> check performance.

import unittest
import json
import std/strutils
import ../src/runtime/validation

# Flow: Execute procedure with deterministic test helper behavior.
proc buildRecord(policy: ExtraFieldPolicy = efRejectUnknown,
    enforceOrdering = false,
    minItems = -1,
    maxItems = -1): ValidationRecord =
  let arg = ArgumentRule(
    name: "payload",
    expectedType: ptObject,
    required: true,
    fields: @[
      FieldRule(path: "id", expectedType: ptString, required: true, minItems: -1, maxItems: -1),
      FieldRule(path: "count", expectedType: ptInt, required: true, minItems: -1, maxItems: -1),
      FieldRule(path: "tags", expectedType: ptArray, required: false, minItems: 1, maxItems: 3)
    ],
    extraFieldPolicy: policy,
    enforceOrdering: enforceOrdering,
    knownFieldOrder: @["id", "count", "tags"],
    minItems: minItems,
    maxItems: maxItems
  )
  result = buildValidationRecord("runtime", "Dispatch", 1, @[arg], "source:v1")

# Flow: Execute procedure with deterministic test helper behavior.
proc buildIndex(record: ValidationRecord): ValidationIndex =
  result = buildValidationIndex(@[record], "gen-1", @["source:v1"])

# Flow: Execute procedure with deterministic test helper behavior.
proc inbound(namespaceId, symbolId: string,
    contractVersion: int,
    args: seq[JsonNode]): InboundMessage =
  result = InboundMessage(
    namespaceId: namespaceId,
    symbolId: symbolId,
    contractVersion: contractVersion,
    args: args
  )

suite "ValidationMembrane":
  test "unknown signature emits failure occurrence":
    let idx = buildValidationIndex(@[], "gen-1")
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x", "count": 1}])
    let decision = prefilterValidate(idx, msg, "ingress", 10)
    check not decision.validated
    check decision.failure.failureKind == vfUnknownSignature

  test "argument count mismatch rejected":
    let record = buildRecord()
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[])
    let decision = prefilterValidate(idx, msg, "ingress", 11)
    check not decision.validated
    check decision.failure.failureKind == vfArgumentCountMismatch

  test "type mismatch rejected":
    let record = buildRecord()
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": 99, "count": 1}])
    let decision = prefilterValidate(idx, msg, "ingress", 12)
    check not decision.validated
    check decision.failure.failureKind == vfTypeMismatch

  test "missing required field rejected":
    let record = buildRecord()
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x"}])
    let decision = prefilterValidate(idx, msg, "ingress", 13)
    check not decision.validated
    check decision.failure.failureKind == vfMissingRequiredField
    check decision.failure.rulePath == "count"

  test "unknown field reject policy blocks ingress":
    let record = buildRecord(efRejectUnknown)
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x", "count": 1, "extra": "x"}])
    let decision = prefilterValidate(idx, msg, "ingress", 14)
    check not decision.validated
    check decision.failure.failureKind == vfUnknownFieldRejected

  test "unknown field ignore policy strips unknowns":
    let record = buildRecord(efIgnoreUnknown)
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x", "count": 1, "extra": "secret"}])
    let decision = prefilterValidate(idx, msg, "ingress", 15)
    check decision.validated
    check not decision.normalizedArgs[0].hasKey("extra")

  test "ordering violation rejected when ordering enforced":
    let record = buildRecord(efIgnoreUnknown, true)
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"count": 1, "id": "x"}])
    let decision = prefilterValidate(idx, msg, "ingress", 16)
    check not decision.validated
    check decision.failure.failureKind == vfOrderingViolation

  test "cardinality violation rejected":
    let record = buildRecord(efIgnoreUnknown)
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x", "count": 1, "tags": @[] }])
    let decision = prefilterValidate(idx, msg, "ingress", 17)
    check not decision.validated
    check decision.failure.failureKind == vfCardinalityViolation

  test "validated payload can dispatch":
    let record = buildRecord(efIgnoreUnknown)
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x", "count": 1, "tags": @["a"]}])
    let decision = prefilterValidate(idx, msg, "ingress", 18)
    check decision.validated

    var called = false
    let dispatched = dispatchValidated(
      decision,
      # Flow: Dispatch normalized args through validation-gated callback.
      proc (args: seq[JsonNode]): bool =
        called = args.len == 1 and args[0]["id"].getStr() == "x"
        return true
    )
    check dispatched
    check called

  test "dispatch gate blocks unvalidated payload":
    let record = buildRecord()
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x"}])
    let decision = prefilterValidate(idx, msg, "ingress", 19)
    check not decision.validated
    expect(ValueError):
      # Flow: Confirm dispatch gate rejects unvalidated payload callback.
      discard dispatchValidated(decision, proc (args: seq[JsonNode]): bool = true)

  test "admission gate blocks unvalidated payload":
    let record = buildRecord()
    let idx = buildIndex(record)
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x"}])
    let decision = prefilterValidate(idx, msg, "ingress", 20)
    check not decision.validated
    expect(ValueError):
      discard admitValidatedOccurrence(decision)

  test "failure log is redacted":
    let record = buildRecord(efRejectUnknown)
    let idx = buildIndex(record)
    let secret = "token=super-secret"
    let msg = inbound("runtime", "Dispatch", 1, @[%*{"id": "x", "count": 1, "extra": secret}])
    let decision = prefilterValidate(idx, msg, "ingress", 21)
    check not decision.validated
    let line = safeFailureLogLine(decision.failure)
    check line.contains("payloadDigest=")
    check not line.contains(secret)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
