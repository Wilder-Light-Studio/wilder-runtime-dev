# Wilder Cosmos 0.4.0
# Module name: scheduler_test Tests
# Module Path: tests/scheduler_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## scheduler_test.nim
#
## Summary: Chapter 8 tests for deterministic scheduler behavior, replay,
##   bounded execution, error isolation, suspension, and tempo coverage.
## Simile: Like checking a metronome and safety breaker together.
## Memory note: deterministic ordering uses thingId/moduleId lexical sort.
## Flow: test tempo kinds -> test deterministic frame output -> test replay ->
##   test bounded yielding -> test failure isolation and suspension.

import unittest
import json
import ../src/cosmos/runtime/scheduler
import ../src/cosmos/tempo/tempo

# Flow: Execute procedure with deterministic test helper behavior.
proc mkItem(thingId, moduleId: string,
    tempo: TempoKind,
    workUnits: int,
    payloads: seq[JsonNode] = @[],
    fail: bool = false): FrameWorkItem =
  FrameWorkItem(
    thingId: thingId,
    moduleId: moduleId,
    tempo: tempo,
    incoming: @[],
    workUnits: workUnits,
    emitPayloads: payloads,
    forceFailure: fail
  )

suite "tempo kinds":
  test "all five tempo kinds are available":
    check describeTempo(Event) == "tempo: Event"
    check describeTempo(Periodic) == "tempo: Periodic"
    check describeTempo(Continuous) == "tempo: Continuous"
    check describeTempo(Manual) == "tempo: Manual"
    check describeTempo(Sequence) == "tempo: Sequence"

suite "deterministic frame loop":
  test "execution order is lexicographic by thing/module":
    let s = initSchedulerState(perThingBudget = 5, suspensionThreshold = 2)
    let req = @[
      mkItem("thing-b", "mod-z", Event, 1),
      mkItem("thing-a", "mod-z", Event, 1),
      mkItem("thing-a", "mod-a", Event, 1)
    ]

    let r = executeFrame(s, req)
    check r.processedThings[0] == "thing-a|mod-a"
    check r.processedThings[1] == "thing-a|mod-z"
    check r.processedThings[2] == "thing-b|mod-z"

  test "same input produces same digest and outputs":
    let req = @[
      mkItem("thing-a", "mod-a", Event, 1, @[%*{"p": 1}]),
      mkItem("thing-b", "mod-a", Periodic, 1, @[%*{"p": 2}])
    ]

    let s1 = initSchedulerState(5, 2)
    let s2 = initSchedulerState(5, 2)
    let r1 = executeFrame(s1, req)
    let r2 = executeFrame(s2, req)

    check r1.digest == r2.digest
    check r1.emitted.len == r2.emitted.len
    check r1.emitted[0].id == r2.emitted[0].id

suite "bounded execution and cooperative yield":
  test "thing above budget is yielded and does not emit":
    let s = initSchedulerState(perThingBudget = 2, suspensionThreshold = 2)
    let req = @[
      mkItem("thing-a", "mod-a", Continuous, 3, @[%*{"x": 1}]),
      mkItem("thing-b", "mod-a", Event, 1, @[%*{"x": 2}])
    ]

    let r = executeFrame(s, req)
    check "thing-a" in r.yieldedThings
    check r.emitted.len == 1
    check r.emitted[0].source == "thing-b"

suite "failure isolation and suspension":
  test "failing thing does not block other things":
    let s = initSchedulerState(perThingBudget = 5, suspensionThreshold = 2)
    let req = @[
      mkItem("thing-fail", "mod-a", Event, 1, fail = true),
      mkItem("thing-ok", "mod-a", Event, 1, @[%*{"ok": true}])
    ]

    let r = executeFrame(s, req)
    check r.failures.len == 1
    check r.failures[0].thingId == "thing-fail"
    check r.emitted.len == 1
    check r.emitted[0].source == "thing-ok"

  test "repeated failures suspend thing":
    let s = initSchedulerState(perThingBudget = 5, suspensionThreshold = 2)
    discard executeFrame(s, @[mkItem("thing-x", "mod-a", Event, 1, fail = true)])
    let r2 = executeFrame(s, @[mkItem("thing-x", "mod-a", Event, 1, fail = true)])

    check isThingSuspended(s, "thing-x")
    check "thing-x" in r2.suspendedThings

suite "frame replay":
  test "replayFrame returns deterministic digest":
    let req = @[
      mkItem("thing-a", "mod-a", Sequence, 1, @[%*{"v": 1}]),
      mkItem("thing-b", "mod-b", Manual, 1, @[%*{"v": 2}])
    ]

    let r1 = replayFrame(5, 2, req)
    let r2 = replayFrame(5, 2, req)

    check r1.digest == r2.digest
    check r1.processedThings == r2.processedThings
    check r1.emitted.len == 2

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
