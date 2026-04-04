# Wilder Cosmos 0.4.0
# Module name: validation_firewall_perf_test Tests
# Module Path: tests/validation_firewall_perf_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## validation_firewall_perf_test.nim
#
## Summary: Bounded performance checks for prefilter lookup and hot-path validation.
## Simile: Like stress testing to ensure the gatekeeper doesn't slow down traffic.
## Memory note: prefilter lookup must stay under budget; profile aggressively.
## Flow: measure prefilter lookup -> measure validation -> verify bounds.

import unittest
import json
import std/[times, tables]
import ../src/runtime/validation

# Flow: Execute procedure with deterministic test helper behavior.
proc makeRecord(i: int): ValidationRecord =
  let arg = ArgumentRule(
    name: "payload",
    expectedType: ptObject,
    required: true,
    fields: @[
      FieldRule(path: "id", expectedType: ptString, required: true, minItems: -1, maxItems: -1)
    ],
    extraFieldPolicy: efIgnoreUnknown,
    enforceOrdering: false,
    knownFieldOrder: @[],
    minItems: -1,
    maxItems: -1
  )
  result = buildValidationRecord("runtime", "Sym" & $i, 1, @[arg], "src")

# Flow: Execute procedure with deterministic test helper behavior.
proc makeIndex(size: int): ValidationIndex =
  var records: seq[ValidationRecord] = @[]
  for i in 0 ..< size:
    records.add(makeRecord(i))
  result = buildValidationIndex(records, "gen")

suite "ValidationFirewallPerf":
  test "lookup remains bounded as table grows":
    let small = makeIndex(10)
    let large = makeIndex(1000)
    let keySmall = makeRecord(9).keyDigest
    let keyLarge = makeRecord(999).keyDigest

    var s0 = cpuTime()
    for _ in 0 ..< 10000:
      discard small.byKey[keySmall]
    let smallElapsed = cpuTime() - s0

    s0 = cpuTime()
    for _ in 0 ..< 10000:
      discard large.byKey[keyLarge]
    let largeElapsed = cpuTime() - s0

    check smallElapsed < 0.5
    check largeElapsed < 0.5

  test "payload mask computation reuses caller-provided storage":
    let arg = ArgumentRule(
      name: "payload",
      expectedType: ptObject,
      required: true,
      fields: @[
        FieldRule(path: "id", expectedType: ptString, required: true, minItems: -1, maxItems: -1)
      ],
      extraFieldPolicy: efIgnoreUnknown,
      enforceOrdering: false,
      knownFieldOrder: @[],
      minItems: -1,
      maxItems: -1
    )

    var mask: PayloadMask
    var normalized = newJNull()
    var unknownFieldFound = false
    var orderingViolation = false
    var cardinalityViolation = false
    var firstTypeMismatchPath = ""
    var firstMissingPath = ""
    var firstUnknownPath = ""

    computePayloadMaskNoAlloc(
      arg,
      %*{"id": "x", "extra": 1},
      mask,
      normalized,
      unknownFieldFound,
      orderingViolation,
      cardinalityViolation,
      firstTypeMismatchPath,
      firstMissingPath,
      firstUnknownPath
    )

    check mask.width == 1
    check normalized.kind == JObject
    check normalized.hasKey("id")

  test "mask conjunction comparison is constant work for fixed width":
    let v = ValidationMask(requiredBits: 0b11, typeBits: 0b11, orderingBit: 0, cardinalityBits: 0, width: 2)
    let ok = PayloadMask(requiredBits: 0b11, typeBits: 0b11, orderingBit: 0, cardinalityBits: 0, width: 2)
    let bad = PayloadMask(requiredBits: 0b01, typeBits: 0b11, orderingBit: 0, cardinalityBits: 0, width: 2)

    check maskConjunctionPass(v, ok)
    check not maskConjunctionPass(v, bad)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.