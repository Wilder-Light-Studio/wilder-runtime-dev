# Wilder Cosmos 0.4.0
# Module name: validation_table_generation_test Tests
# Module Path: tests/validation_table_generation_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## validation_table_generation_test.nim
#
## Summary: Generated prefilter table verification tests.
## Simile: Like testing an automatically generated lookup table for correctness.
## Memory note: prefilter tables are generated; verify generation matches specification.
## Flow: generate table -> verify entries -> test lookup -> validate completeness.

import unittest
import std/tables
import ../src/runtime/validation
import ../src/runtime/prefilter_table_generated

suite "ValidationTableGeneration":
  test "generated table contains registered signatures":
    let records = generatedValidationRecords()
    check records.len >= 1
    check records[0].namespaceId == "runtime"
    check records[0].symbolId == "Ping"

  test "generated records are deterministic":
    let a = generatedValidationRecords()
    let b = generatedValidationRecords()
    check a.len == b.len
    for i in 0 ..< a.len:
      check a[i].keyDigest == b[i].keyDigest
      check a[i].sourceDigest == b[i].sourceDigest

  test "source digest list is embedded":
    let digests = generatedSourceDigests()
    check digests.len >= 3
    check digests[0].len > 0

  test "load generated index validates collisions":
    let idx = loadGeneratedValidationIndex()
    check idx.byKey.len == generatedValidationRecords().len

  test "contract version change changes digest":
    let arg = ArgumentRule(
      name: "payload",
      expectedType: ptObject,
      required: true,
      fields: @[
        FieldRule(path: "message", expectedType: ptString, required: true, minItems: -1, maxItems: -1)
      ],
      extraFieldPolicy: efIgnoreUnknown,
      enforceOrdering: false,
      knownFieldOrder: @[],
      minItems: -1,
      maxItems: -1
    )
    let v1 = buildValidationRecord("runtime", "Ping", 1, @[arg], "src")
    let v2 = buildValidationRecord("runtime", "Ping", 2, @[arg], "src")
    check v1.keyDigest != v2.keyDigest

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
