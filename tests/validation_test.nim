# Wilder Cosmos 0.4.0
# Module name: validation_test Tests
# Module Path: tests/validation_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## validation_test.nim
#
## Summary: Validation helper tests for Chapter 2 acceptance coverage.
## Simile: Like security audits verifying the gatekeeper stays vigilant.
## Memory note: all validators must fail on invalid input; test both paths.
## Flow: test success paths, fail-fast behavior, and secure error messages.

import unittest
import json
import std/strutils
import ../src/runtime/validation

# Flow: Execute procedure with deterministic test helper behavior.
proc toBytes(s: string): seq[byte] =
  ## Flow: convert string to deterministic bytes for checksum tests.
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

suite "validation helpers":
  test "validateNonEmpty accepts non-empty string":
    check validateNonEmpty("runtime")

  test "validateNonEmpty rejects empty string":
    expect(ValueError):
      discard validateNonEmpty("")

  test "validateRange accepts in-range value":
    check validateRange(7, 1, 10)

  test "validateRange rejects out-of-range value":
    expect(ValueError):
      discard validateRange(11, 1, 10)

  test "validatePortRange accepts boundaries":
    check validatePortRange(1)
    check validatePortRange(65535)

  test "validatePortRange rejects invalid boundaries":
    expect(ValueError):
      discard validatePortRange(0)
    expect(ValueError):
      discard validatePortRange(65536)

  test "validateStructure accepts required JSON fields":
    let n = %*{"id": "abc", "payload": 1}
    check validateStructure(n, @["id", "payload"])

  test "validateStructure rejects missing field":
    let n = %*{"id": "abc"}
    expect(ValueError):
      discard validateStructure(n, @["id", "payload"])

  test "validateChecksum rejects mismatch with sanitized message":
    let secretPayload = "apiKey=top-secret"
    let data = toBytes(secretPayload)
    let wrong = repeat('0', 64)

    try:
      discard validateChecksum(data, wrong)
      check false
    except ValueError as e:
      check "checksum mismatch" in e.msg
      check secretPayload notin e.msg

  test "validateJsonChecksum accepts known digest":
    let payload = "hello world"
    let digest = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    check validateJsonChecksum(payload, digest)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
