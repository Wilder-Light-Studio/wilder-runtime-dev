# Wilder Cosmos 0.4.0
# Module name: messaging_test Tests
# Module Path: tests/messaging_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## messaging_test.nim
#
## Summary: Message dispatch tests for validation and mode-aware logging.
## Simile: Like testing a switchboard to ensure routing works correctly.
## Memory note: test both valid and invalid envelopes; verify logging behavior per mode.
## Flow: construct envelope -> dispatch -> validate handling -> check logging.

## Flow: dispatch valid/invalid envelopes and assert debug vs production logging behavior.

import unittest
import json
import std/strutils
import ../src/runtime/config
import ../src/runtime/messaging

suite "messaging dispatch":
  test "dispatches valid envelope":
    let cfg = RuntimeConfig(
      mode: rmDevelopment,
      transport: tkJson,
      logLevel: llInfo,
      endpoint: "localhost",
      port: 8080
    )

    let env = MessageEnvelope(
      id: "m1",
      `type`: "Ping",
      version: 1,
      timestamp: 1000,
      payload: %*{"message": "ok"}
    )

    var dispatched = false
    let ok = dispatchEnvelope(
      env,
      cfg,
      # Flow: Validate payload route callback for the dispatch path.
      proc (payload: JsonNode): bool =
        dispatched = payload["message"].getStr() == "ok"
        return true,
      # Flow: Consume debug callback output without side effects.
      proc (msg: string) = discard
    )

    check ok
    check dispatched

  test "rejects invalid envelope before dispatch":
    let cfg = RuntimeConfig(
      mode: rmDevelopment,
      transport: tkJson,
      logLevel: llInfo,
      endpoint: "localhost",
      port: 8080
    )

    let env = MessageEnvelope(
      id: "",
      `type`: "Ping",
      version: 1,
      timestamp: 1000,
      payload: %*{"message": "ok"}
    )

    expect(ValueError):
      discard dispatchEnvelope(
        env,
        cfg,
        # Flow: Provide acceptance callback while validating envelope rejection.
        proc (payload: JsonNode): bool = true,
        # Flow: Provide no-op log callback for rejection test path.
        proc (msg: string) = discard
      )

  test "logs full envelope in debug mode":
    let cfg = RuntimeConfig(
      mode: rmDebug,
      transport: tkJson,
      logLevel: llDebug,
      endpoint: "localhost",
      port: 8080
    )

    let env = MessageEnvelope(
      id: "m2",
      `type`: "Ping",
      version: 1,
      timestamp: 1001,
      payload: %*{"message": "debug"}
    )

    var logs: seq[string] = @[]
    discard dispatchEnvelope(
      env,
      cfg,
      # Flow: Provide acceptance callback for debug logging test.
      proc (payload: JsonNode): bool = true,
      # Flow: Capture debug log callback output for assertion.
      proc (msg: string) = logs.add(msg)
    )

    check logs.len == 1
    check logs[0].contains("dispatchEnvelope(debug)")

  test "does not log envelope in production mode":
    let cfg = RuntimeConfig(
      mode: rmProduction,
      transport: tkJson,
      logLevel: llInfo,
      endpoint: "localhost",
      port: 8080
    )

    let env = MessageEnvelope(
      id: "m3",
      `type`: "Ping",
      version: 1,
      timestamp: 1002,
      payload: %*{"message": "prod"}
    )

    var logs: seq[string] = @[]
    discard dispatchEnvelope(
      env,
      cfg,
      # Flow: Provide acceptance callback for production logging test.
      proc (payload: JsonNode): bool = true,
      # Flow: Capture production log callback output for assertion.
      proc (msg: string) = logs.add(msg)
    )

    check logs.len == 0

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
