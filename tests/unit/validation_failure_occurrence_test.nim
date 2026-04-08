# Wilder Cosmos 0.4.0
# Module name: validation_failure_occurrence_test Tests
# Module Path: tests/unit/validation_failure_occurrence_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## validation_failure_occurrence_test.nim
#
## Summary: Validation failure occurrence and redaction tests.
## Simile: Like security redaction ensuring failures don't leak sensitive data.
## Memory note: never log full payloads in production; test redaction always.
## Flow: trigger validation error -> capture occurrence -> verify redaction.

import unittest
import json
import std/strutils
import ../../src/runtime/validation

suite "ValidationFailureOccurrence":
  test "failure occurrence has required fields":
    let occ = newValidationFailure(
      "ingress",
      100,
      "abc123",
      vfTypeMismatch,
      "payload.id",
      "VAL_FIELD_TYPE",
      "deadbeef",
      42
    )
    check occ.id.len > 0
    check occ.source == "ingress"
    check occ.targetKey == "abc123"
    check occ.failureKind == vfTypeMismatch
    check occ.payloadByteLen == 42

  test "target key and failure kind are preserved":
    let occ = newValidationFailure(
      "ingress",
      101,
      "digest-key",
      vfMissingRequiredField,
      "payload.user.id",
      "VAL_REQUIRED_FIELD",
      "abcd",
      11
    )
    check occ.targetKey == "digest-key"
    check occ.failureKind == vfMissingRequiredField
    check occ.rulePath == "payload.user.id"

  test "failure occurrence json is safe and complete":
    let occ = newValidationFailure(
      "ingress",
      102,
      "digest-key",
      vfUnknownFieldRejected,
      "payload.extra",
      "VAL_UNKNOWN_FIELD",
      "abcd",
      13
    )
    let j = toJson(occ)
    check j.hasKey("id")
    check j.hasKey("targetKey")
    check j.hasKey("payloadDigest")
    check j["failureKind"].getStr() == "vfUnknownFieldRejected"

  test "safe log line does not include secret field values":
    let secret = "password=super-secret"
    let occ = newValidationFailure(
      "ingress",
      103,
      "digest-key",
      vfTypeMismatch,
      "payload.password",
      "VAL_FIELD_TYPE",
      "abcd",
      secret.len
    )
    let line = safeFailureLogLine(occ)
    check line.contains("payloadDigest=abcd")
    check not line.contains(secret)

  test "failure id is deterministic for identical inputs":
    let a = newValidationFailure("ingress", 200, "k", vfMaskMismatch, "p", "D", "X", 1)
    let b = newValidationFailure("ingress", 200, "k", vfMaskMismatch, "p", "D", "X", 1)
    check a.id == b.id

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
