# Wilder Cosmos 0.4.0
# Module name: serialization_test Tests
# Module Path: tests/unit/serialization_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## serialization_test.nim
#
## Summary: Serialization envelope and typed round-trip tests for Chapter 2.
## Simile: Like testing a shipping container to ensure contents survive transport.
## Memory note: checksum validation is mandatory; test corruption detection paths.
## Flow: verify checksum envelope integrity, corruption detection, and typed decode.

import unittest
import json
import ../../src/runtime/api
import ../../src/runtime/config
import ../../src/runtime/serialization

suite "serialization envelope":
  test "envelopeWrap generates SHA256 checksum metadata":
    let env = envelopeWrap(%*{"id": "msg-1", "v": 1}, 1)
    check env.hasKey("checksum")
    check env["checksum"].kind == JString
    check env["checksum"].getStr().len == 64
    check env["origin"].getStr() == "runtime"

  test "envelopeUnwrap rejects payload corruption":
    var env = envelopeWrap(%*{"k": "value"}, 1)
    env["payload"] = %*{"k": "tampered"}

    expect(ValueError):
      discard envelopeUnwrap(env)

  test "serializeWithEnvelope and deserializeWithEnvelope round-trip RuntimeState":
    let state = RuntimeState(
      epoch: EpochCounter(42),
      version: "0.1.1",
      name: "alpha"
    )

    let env = serializeWithEnvelope(state, 2)
    let decoded = deserializeWithEnvelope[RuntimeState](env)

    check decoded.epoch.int == 42
    check decoded.version == "0.1.1"
    check decoded.name == "alpha"

  test "deserializeWithEnvelope rejects type mismatch":
    let env = envelopeWrap(%*{"x": 1}, 1)
    expect(ValueError):
      discard deserializeWithEnvelope[StatusField](env)

  test "selectSerializer chooses json serializer from config transport":
    let s = selectSerializer(tkJson)
    check s.kind == skJson

  test "selectSerializer chooses protobuf serializer and rejects when unavailable":
    let s = selectSerializer(tkProtobuf)
    check s.kind == skProtobuf
    expect(ValueError):
      discard s.encode(%*{"id": "m1"})

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
