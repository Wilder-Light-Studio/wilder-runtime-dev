# Wilder Cosmos 0.4.0
# Module name: status_memory_test Tests
# Module Path: tests/status_memory_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## status_memory_test.nim
#
## Summary: Chapter 6 status and memory model tests.
## Simile: Like load-testing a control panel where each gauge has a hard
##   limit and invariant checks must fail fast.
## Memory note: Covers schema validation, phase checks, memory categories,
##   escalation, and introspection reports.
## Flow: validate status fields -> validate phase wrappers -> enforce memory
##   caps -> verify warning/reject escalation -> verify usage reports.

import unittest
import json
import std/strutils
import std/tables
import ../src/cosmos/core/status
import ../src/cosmos/thing/thing

# Flow: Execute procedure with deterministic test helper behavior.
proc baseSchema(): StatusSchema =
  StatusSchema(
    schemaVersion: 1,
    fields: @[
      StatusField(name: "health", fieldType: "string", required: true,
        default: %*"ok", invariant: "nonEmpty"),
      StatusField(name: "temperature", fieldType: "int", required: true,
        default: %*25, invariant: "nonNegative"),
      StatusField(name: "load", fieldType: "float", required: false,
        default: %*0.0, invariant: "nonNegative")
    ]
  )

# Flow: Execute procedure with deterministic test helper behavior.
proc baseConcept(): Concept =
  createConcept(
    id = "concept-status",
    what = %*{},
    why = %*{},
    how = %*{},
    where = %*{},
    `when` = %*{},
    withSection = %*{},
    manifest = %*{}
  )

suite "status schema validation":
  test "validateStatus accepts valid status object":
    let schema = baseSchema()
    let status = %*{"health": "ok", "temperature": 42, "load": 0.25}
    check validateStatus(status, schema)

  test "validateStatus rejects missing required field":
    let schema = baseSchema()
    let status = %*{"temperature": 42}
    expect(ValueError):
      discard validateStatus(status, schema)

  test "validateStatus rejects wrong type":
    let schema = baseSchema()
    let status = %*{"health": "ok", "temperature": "hot"}
    expect(ValueError):
      discard validateStatus(status, schema)

  test "validateStatus rejects invariant violation":
    let schema = baseSchema()
    let status = %*{"health": "", "temperature": 42}
    expect(ValueError):
      discard validateStatus(status, schema)

  test "validateStatus rejects non-object status":
    let schema = baseSchema()
    expect(ValueError):
      discard validateStatus(%*[1, 2], schema)

suite "phase validation":
  test "validateStatusAtPhase includes phase context on load":
    let schema = baseSchema()
    let badStatus = %*{"health": "", "temperature": 10}
    try:
      discard validateStatusAtPhase(badStatus, schema, vpLoad)
      check false
    except ValueError as e:
      check "load" in e.msg

  test "validateThingStatus checks Thing status at mutation":
    let schema = baseSchema()
    let c = baseConcept()
    let t = instantiateThing("thing-status-1", c,
      %*{"health": "ok", "temperature": 10})
    check validateThingStatus(t, schema, vpMutation)

  test "validateThingStatus fails reconciliation when status invalid":
    let schema = baseSchema()
    let c = baseConcept()
    let t = instantiateThing("thing-status-2", c,
      %*{"health": "ok"})
    expect(ValueError):
      discard validateThingStatus(t, schema, vpReconciliation)

suite "memory cap and escalation":
  test "checkMemoryCap passes within cap":
    check checkMemoryCap(8, 10)

  test "checkMemoryCap rejects when exceeded":
    expect(ValueError):
      discard checkMemoryCap(12, 10)

  test "memory tracker records usage by category":
    let tracker = initMemoryTracker(100, 50, 30, 60)
    let v = recordMemoryUsage(tracker, mcState, 20, thingId = "t1")
    check v.level == melOk
    let report = memoryReportForThing(tracker, "t1")
    check report.byCategory[mcState] == 20
    check report.totalBytes == 20

  test "first over-cap violation is warning":
    let tracker = initMemoryTracker(10, 10, 10, 10)
    let v = recordMemoryUsage(tracker, mcState, 12, thingId = "t2")
    check v.level == melWarning
    check v.attempts == 1

  test "second over-cap violation is rejection":
    let tracker = initMemoryTracker(10, 10, 10, 10)
    discard recordMemoryUsage(tracker, mcState, 12, thingId = "t3")
    expect(ValueError):
      discard recordMemoryUsage(tracker, mcState, 1, thingId = "t3")

suite "memory introspection":
  test "memoryReportForThing returns module and thing view":
    let tracker = initMemoryTracker(100, 100, 100, 100)
    discard recordMemoryUsage(tracker, mcState, 30, thingId = "thing-a")
    discard recordMemoryUsage(tracker, mcPerception, 15, thingId = "thing-a")
    discard recordMemoryUsage(tracker, mcModule, 40, moduleId = "module-a")

    let report = memoryReportForThing(tracker, "thing-a", "module-a")
    check report.byCategory[mcState] == 30
    check report.byCategory[mcPerception] == 15
    check report.byCategory[mcModule] == 40
    check report.totalBytes == 85

  test "memoryReportGlobal aggregates all categories":
    let tracker = initMemoryTracker(100, 100, 100, 100)
    discard recordMemoryUsage(tracker, mcState, 10, thingId = "thing-a")
    discard recordMemoryUsage(tracker, mcPerception, 5, thingId = "thing-a")
    discard recordMemoryUsage(tracker, mcTemporal, 7, thingId = "thing-b")
    discard recordMemoryUsage(tracker, mcModule, 9, moduleId = "module-z")

    let report = memoryReportGlobal(tracker)
    check report.byCategory[mcState] == 10
    check report.byCategory[mcPerception] == 5
    check report.byCategory[mcTemporal] == 7
    check report.byCategory[mcModule] == 9
    check report.totalBytes == 31

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
