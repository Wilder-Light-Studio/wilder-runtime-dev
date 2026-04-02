# Wilder Cosmos 0.4.0
# Module name: validation_checksum_test Tests
# Module Path: tests/validation_checksum_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## validation_checksum_test.nim
#
## Summary: SHA256 checksum validation and integrity tests.
## Simile: Like cryptographic notary seals ensuring data hasn't been tampered with.
## Memory note: checksums are deterministic; recompute always on deserialization.
## Flow: compute hash -> compare -> fail-fast on mismatch.

import unittest
import ../src/runtime/validation

# Flow: Execute procedure with deterministic test helper behavior.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

suite "validateChecksum tests":
  test "checksum matches":
    let data = toBytes("hello world")
    let expected = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    check validateChecksum(data, expected)

  test "checksum matches with uppercase expected":
    let data = toBytes("hello world")
    let expected = "B94D27B9934D3E08A52E52D7DA7DABFAC484EFE37A5380EE9088F7ACE2EFCDE9"
    check validateChecksum(data, expected)

  test "checksum mismatch raises":
    let data = toBytes("hello world")
    let wrong = "0000000000000000000000000000000000000000000000000000000000000000"
    expect(ValueError):
      discard validateChecksum(data, wrong)

  test "invalid expected checksum format raises":
    let data = toBytes("hello world")
    expect(ValueError):
      discard validateChecksum(data, "not-a-valid-sha256")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
