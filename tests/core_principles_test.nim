# Wilder Cosmos 0.4.0
# Module name: core_principles_test Tests
# Module Path: tests/core_principles_test.nim
# Summary: Core-principle behavioral checks for pull-based flow and reversible lifecycle.
# Simile: Like a flight simulation where participation and shutdown are always operator-controlled.
# Memory note: assertions stay behavior-focused so principle drift is detected early.
# Flow: verify pull-only delegation behavior -> verify startup/shutdown reversibility.

import unittest
import json
import std/[os, sets]
import harness
import ../src/runtime/core
import ../src/cosmos/runtime/delegation

# Flow: Write deterministic development config for lifecycle tests.
proc writeDevConfig(dir: string): string =
  let path = dir / "runtime.json"
  let node = %*{
    "mode": "development",
    "transport": "json",
    "logLevel": "debug",
    "endpoint": "localhost",
    "port": 8080
  }
  writeFile(path, $node)
  result = path

suite "core principles":
  test "delegation is pull-triggered and does not emit without request":
    let engine = initDelegationEngine()
    let results = processDelegationFrame(engine, 0)
    check results.len == 0

  test "delegation emits asynchronously after explicit request":
    let engine = initDelegationEngine()
    let req = emitDelegationOccurrence("thing.requester", "cap.search", %*{}, 1)

    let specialist = SpecialistDescriptor(
      thingId: "thing.specialist",
      provides: @["cap.search"],
      requires: @["cap.input"],
      how: "handles search"
    )

    var caps = initHashSet[string]()
    caps.incl("cap.input")
    queueDelegation(engine, req, @[specialist], caps)

    check processDelegationFrame(engine, 1).len == 0
    let at3 = processDelegationFrame(engine, 3)
    check at3.len == 1
    check at3[0].success

  test "startup and shutdown are reversible across runs":
    setupTest("core_principles_reversible")
    let cfgPath = writeDevConfig(testTmpDir)

    var lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check lc.step == lcRunning
    shutdown(lc)
    check lc.step == lcStopped

    lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check lc.step == lcRunning
    shutdown(lc)
    check lc.step == lcStopped
    teardownTest()

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
