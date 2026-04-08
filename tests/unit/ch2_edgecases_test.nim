# Wilder Cosmos 0.4.0
# Module name: ch2_edgecases_test Tests
# Module Path: tests/unit/ch2_edgecases_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## ch2_edgecases_test.nim
#
## Summary: Chapter 2 edge-case coverage for validation and serialization boundaries.
## Simile: Like stress-testing the guards at the system boundary.
## Memory note: edge cases catch silent failures; maintain full coverage.
## Flow: test boundary conditions -> verify fail-fast -> check error messages.

import unittest
import json
import std/strutils
import ../../src/runtime/validation
import ../../src/runtime/serialization

# Flow: Execute procedure with deterministic test helper behavior.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

suite "chapter2 edge cases":
  test "validateChecksum rejects empty and malformed expected digest":
    let payload = toBytes("hello")

    expect(ValueError):
      discard validateChecksum(payload, "")

    expect(ValueError):
      discard validateChecksum(payload, "abc")

    expect(ValueError):
      discard validateChecksum(payload, repeat('z', 64))

  test "validateJsonChecksum supports uppercase expected digest":
    let payload = "hello world"
    let digestUpper = "B94D27B9934D3E08A52E52D7DA7DABFAC484EFE37A5380EE9088F7ACE2EFCDE9"
    check validateJsonChecksum(payload, digestUpper)

  test "envelopeUnwrap rejects non-string checksum":
    let env = %*{
      "schemaVersion": 1,
      "payload": %*{"a": 1},
      "checksum": 123,
      "timestamp": "2026-03-31T00:00:00Z",
      "origin": "runtime"
    }
    expect(ValueError):
      discard envelopeUnwrap(env)

  test "signature digest is stable across casing and whitespace":
    let a = deriveSignatureDigest(" runtime ", " Dispatch ", 1, 1, @["payload:object"])
    let b = deriveSignatureDigest("RUNTIME", "DISPATCH", 1, 1, @["payload:object"])
    check a == b

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
