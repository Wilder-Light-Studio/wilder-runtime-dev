# Wilder Cosmos 0.4.0
# Module name: delegation_test Tests
# Module Path: tests/unit/delegation_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## delegation_test.nim
#
## Summary: Chapter 9 delegation model tests.
## Simile: Like dispatch routing tests for a help desk with deterministic
##   assignment and delayed ticket closure.
## Memory note: results must be asynchronous by at least two frames.
## Flow: emit delegation -> match specialist -> queue -> process frames ->
##   verify success/no-match/failure behaviors and deterministic tie-breaks.

import unittest
import json
import std/sets
import std/options
import ../../src/cosmos/runtime/delegation

# Flow: Execute procedure with deterministic test helper behavior.
proc mkSpec(id: string, provides, requires: seq[string], how: string): SpecialistDescriptor =
  SpecialistDescriptor(
    thingId: id,
    provides: provides,
    requires: requires,
    how: how
  )

suite "specialist descriptor validation":
  test "valid specialist descriptor passes":
    check validateSpecialistDescriptor(mkSpec("spec-a", @["cap.a"], @["req.a"], "deterministic"))

  test "empty provides is rejected":
    expect(ValueError):
      discard validateSpecialistDescriptor(mkSpec("spec-a", @[], @["req.a"], "x"))

suite "matching rules":
  test "match chooses lexicographic specialist on tie":
    var available = initHashSet[string]()
    available.incl("req.a")

    let specs = @[
      mkSpec("spec-z", @["cap.a"], @["req.a"], "h"),
      mkSpec("spec-a", @["cap.a"], @["req.a"], "h")
    ]

    let m = matchSpecialist("cap.a", specs, available)
    check isSome(m)
    check m.get.thingId == "spec-a"

  test "no match when requirements unsatisfied":
    let specs = @[mkSpec("spec-a", @["cap.a"], @["missing.req"], "h")]
    let m = matchSpecialist("cap.a", specs, initHashSet[string]())
    check isNone(m)

suite "delegation flow":
  test "delegation result is asynchronous (>=2 frames)":
    let occ = emitDelegationOccurrence("thing-a", "cap.a", %*{"x": 1}, 10)
    let specs = @[mkSpec("spec-a", @["cap.a"], @["req.a"], "h")]
    var available = initHashSet[string]()
    available.incl("req.a")

    let engine = initDelegationEngine()
    queueDelegation(engine, occ, specs, available)

    let r11 = processDelegationFrame(engine, 11)
    check r11.len == 0

    let r12 = processDelegationFrame(engine, 12)
    check r12.len == 1
    check r12[0].success

  test "no-match creates runtime failure result":
    let occ = emitDelegationOccurrence("thing-a", "cap.unknown", %*{}, 20)
    let engine = initDelegationEngine()
    queueDelegation(engine, occ, @[], initHashSet[string]())

    let r = processDelegationFrame(engine, 22)
    check r.len == 1
    check r[0].success == false
    check r[0].source == "runtime"

  test "specialist failure creates structured error result":
    let occ = emitDelegationOccurrence("thing-a", "cap.a", %*{}, 30)
    let specs = @[mkSpec("spec-a", @["cap.a"], @["req.a"], "h")]
    var available = initHashSet[string]()
    available.incl("req.a")

    let engine = initDelegationEngine()
    queueDelegation(engine, occ, specs, available)

    var failing = initHashSet[string]()
    failing.incl("spec-a")

    let r = processDelegationFrame(engine, 32, failing)
    check r.len == 1
    check r[0].success == false
    check r[0].source == "spec-a"
    check r[0].errorMessage.len > 0

  test "result can be delivered as occurrence":
    let res = DelegationResult(
      delegationId: "d1",
      source: "spec-a",
      success: true,
      payload: %*{"ok": true},
      errorMessage: "",
      epoch: 40
    )
    let occ = delegationResultToOccurrence(res)
    check occ.source == "spec-a"
    check occ.payload["delegationId"].getStr == "d1"

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
