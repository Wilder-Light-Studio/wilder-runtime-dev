# Wilder Cosmos 0.4.0
# Module name: ontology_test Tests
# Module Path: tests/unit/ontology_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## ontology_test.nim
#
## Summary: Unit tests for the four ontological primitives — Concept,
##   Occurrence (OCC), Perception (PER), and Thing — defined in
##   src/cosmos/thing/thing.nim.
## Simile: Like a quality-control checklist for the core building blocks
##   before any larger assembly is attempted.
## Memory note: These tests must cover all four Chapter 4 acceptance criteria:
##   type compilation and serialization, Thing lifecycle, Occurrence (OCC)
##   emission, and Perception (PER) filtering. Keep in sync with thing.nim.
## Flow: create primitive types -> verify lifecycle rules ->
##   verify Occurrence (OCC) emission -> verify Perception (PER) filtering ->
##   verify JSON round-trip serialization.

import unittest
import json
import ../../src/cosmos/core/manifest
import ../../src/cosmos/thing/thing

# ===========================================================================
# Suite 1 — Type construction
# Covers: all four types can be created with valid inputs.
# ===========================================================================

suite "Concept construction":
  test "createConcept produces a Concept with the given id":
    let c = createConcept(
      id = "concept-alpha",
      what = %*{"purpose": "test"},
      why  = %*{"rationale": "unit test"},
      how  = %*{"mechanism": "direct"},
      where = %*{"scope": "local"},
      `when` = %*{"temporal": "always"},
      withSection = %*{"deps": []},
      manifest = %*{"ref": "manifest-alpha"}
    )
    check c.id == "concept-alpha"
    check c.whatSection["purpose"].getStr == "test"
    check c.manifest["ref"].getStr == "manifest-alpha"

suite "Occurrence construction":
  test "createOccurrence produces an Occurrence with correct fields":
    let occ = createOccurrence(
      id = "occ-001",
      source = "thing-a",
      epoch = 10,
      payload = %*{"event": "tick"},
      radius = 2
    )
    check occ.id == "occ-001"
    check occ.source == "thing-a"
    check occ.epoch == 10
    check occ.projectionRadius == 2

  test "createOccurrence defaults projectionRadius to 1":
    let occ = createOccurrence("occ-002", "thing-b", 1, %*{})
    check occ.projectionRadius == 1

  test "createOccurrence raises on empty id":
    expect(ValueError):
      discard createOccurrence("", "thing-a", 1, %*{})

  test "createOccurrence raises on empty source":
    expect(ValueError):
      discard createOccurrence("occ-003", "", 1, %*{})

  test "createOccurrence raises on negative projectionRadius":
    expect(ValueError):
      discard createOccurrence("occ-004", "thing-a", 1, %*{}, radius = -1)

suite "Perception construction":
  test "createPerception produces a Perception with correct fields":
    let per = createPerception(
      occurrenceId = "occ-001",
      thingId = "thing-a",
      epoch = 5,
      filtered = false
    )
    check per.occurrenceId == "occ-001"
    check per.thingId == "thing-a"
    check per.epoch == 5
    check per.filtered == false

  test "createPerception defaults filtered to true":
    let per = createPerception("occ-002", "thing-b", 1)
    check per.filtered == true

  test "createPerception raises on empty occurrenceId":
    expect(ValueError):
      discard createPerception("", "thing-a", 1)

  test "createPerception raises on empty thingId":
    expect(ValueError):
      discard createPerception("occ-001", "", 1)

# ===========================================================================
# Suite 2 — Thing lifecycle
# Covers: instantiation from Concept, activate, deactivate,
#   updateStatus guard, recordPerception guard.
# ===========================================================================

suite "Thing lifecycle":
# Flow: Execute procedure with deterministic test helper behavior.
  proc makeConcept(): Concept =
    createConcept(
      id = "concept-lifecycle",
      what = %*{}, why = %*{}, how = %*{},
      where = %*{}, `when` = %*{}, withSection = %*{},
      manifest = %*{}
    )

  test "instantiateThing creates an active Thing":
    let c = makeConcept()
    let t = instantiateThing("thing-001", c, %*{"state": "init"}, epoch = 0)
    check t.id == "thing-001"
    check t.conceptId == "concept-lifecycle"
    check t.active == true
    check t.epoch == 0
    check t.perceptionLog.len == 0

  test "Thing with only identity is valid":
    let t = createThing("thing-minimal")
    validateThing(t)
    check t.conceptId == ""

  test "instantiateThing raises on empty thingId":
    expect(ValueError):
      discard instantiateThing("", makeConcept(), %*{})

  test "instantiateThing raises when concept id is empty":
    var c = makeConcept()
    c.id = ""
    expect(ValueError):
      discard instantiateThing("thing-002", c, %*{})

  test "deactivateThing marks Thing inactive":
    let c = makeConcept()
    var t = instantiateThing("thing-003", c, %*{})
    deactivateThing(t)
    check t.active == false

  test "activateThing marks Thing active":
    let c = makeConcept()
    var t = instantiateThing("thing-004", c, %*{})
    deactivateThing(t)
    activateThing(t)
    check t.active == true

  test "updateStatus increments epoch and updates status":
    let c = makeConcept()
    var t = instantiateThing("thing-005", c, %*{"state": "init"})
    updateStatus(t, %*{"state": "running"})
    check t.status["state"].getStr == "running"
    check t.epoch == 1

  test "updateStatus raises on inactive Thing":
    let c = makeConcept()
    var t = instantiateThing("thing-006", c, %*{})
    deactivateThing(t)
    expect(ValueError):
      updateStatus(t, %*{"state": "bad"})

  test "recordPerception appends to perceptionLog":
    let c = makeConcept()
    var t = instantiateThing("thing-007", c, %*{})
    let per = createPerception("occ-001", "thing-007", 1)
    recordPerception(t, per)
    check t.perceptionLog.len == 1
    check t.perceptionLog[0].occurrenceId == "occ-001"

  test "recordPerception raises on inactive Thing":
    let c = makeConcept()
    var t = instantiateThing("thing-008", c, %*{})
    deactivateThing(t)
    let per = createPerception("occ-001", "thing-008", 1)
    expect(ValueError):
      recordPerception(t, per)

# ===========================================================================
# Suite 3 — Occurrence emission
# Covers: emitOccurrence produces a well-formed Occurrence from a Thing.
# ===========================================================================

suite "Occurrence emission":
  test "emitOccurrence produces an Occurrence with correct source and epoch":
    let occ = emitOccurrence("thing-emit-a", epoch = 7, payload = %*{"val": 42})
    check occ.source == "thing-emit-a"
    check occ.epoch == 7
    check occ.payload["val"].getInt == 42

  test "emitOccurrence id encodes thingId and epoch":
    let occ = emitOccurrence("thing-emit-b", epoch = 3, payload = %*{})
    check occ.id == "occ_thing-emit-b_3"

  test "emitOccurrence sets default projectionRadius to 1":
    let occ = emitOccurrence("thing-emit-c", epoch = 1, payload = %*{})
    check occ.projectionRadius == 1

# ===========================================================================
# Suite 4 — Perception filtering
# Covers: filterOccurrence is deterministic; inactive Things never accept.
# ===========================================================================

suite "Perception filtering":
# Flow: Execute procedure with deterministic test helper behavior.
  proc makeThing(id: string): Thing =
    let c = createConcept(
      id = "concept-filter",
      what = %*{}, why = %*{}, how = %*{},
      where = %*{}, `when` = %*{}, withSection = %*{},
      manifest = %*{}
    )
    instantiateThing(id, c, %*{})

  test "filterOccurrence returns true for an active Thing":
    let t = makeThing("thing-filter-a")
    let occ = createOccurrence("occ-f1", "thing-other", 1, %*{})
    check filterOccurrence(t, occ) == true

  test "filterOccurrence returns false for an inactive Thing":
    var t = makeThing("thing-filter-b")
    deactivateThing(t)
    let occ = createOccurrence("occ-f2", "thing-other", 1, %*{})
    check filterOccurrence(t, occ) == false

  test "filterOccurrence is deterministic — same inputs same result":
    let t = makeThing("thing-filter-c")
    let occ = createOccurrence("occ-f3", "thing-other", 1, %*{"data": "x"})
    let r1 = filterOccurrence(t, occ)
    let r2 = filterOccurrence(t, occ)
    check r1 == r2

# ===========================================================================
# Suite 5 — JSON serialization round-trip
# Covers: all four types compile and serialize; Thing round-trips via JSON.
# ===========================================================================

suite "Thing JSON serialization":
  test "thingToJson produces a JSON object with required fields":
    let c = createConcept(
      id = "concept-serial",
      what = %*{}, why = %*{}, how = %*{},
      where = %*{}, `when` = %*{}, withSection = %*{},
      manifest = %*{}
    )
    let t = instantiateThing("thing-serial-a", c, %*{"state": "ok"})
    let j = thingToJson(t)
    check j.kind == JObject
    check j["id"].getStr == "thing-serial-a"
    check j["conceptId"].getStr == "concept-serial"
    check j["active"].getBool == true

  test "thingFromJson round-trips a Thing":
    let c = createConcept(
      id = "concept-serial2",
      what = %*{}, why = %*{}, how = %*{},
      where = %*{}, `when` = %*{}, withSection = %*{},
      manifest = %*{}
    )
    var t = instantiateThing("thing-serial-b", c, %*{"state": "saved"})
    let per = createPerception("occ-rtrip", "thing-serial-b", 2)
    recordPerception(t, per)

    let j = thingToJson(t)
    let t2 = thingFromJson(j)

    check t2.id == t.id
    check t2.conceptId == t.conceptId
    check t2.active == t.active
    check t2.perceptionLog.len == 1
    check t2.perceptionLog[0].occurrenceId == "occ-rtrip"

  test "thingFromJson raises on non-object input":
    expect(ValueError):
      discard thingFromJson(%*[1, 2, 3])

  test "thingFromJson raises when id is missing":
    expect(ValueError):
      discard thingFromJson(%*{"conceptId": "c1"})

  test "thingFromJson accepts identity-only Things":
    let t = thingFromJson(%*{"id": "t1"})
    validateThing(t)
    check t.id == "t1"
    check t.conceptId == ""

suite "External process wrappers":
  test "wrapExternalProcessThing supports stdin/stdout wrappers":
    let wrapped = wrapExternalProcessThing(
      thingId = "external-stdin-stdout",
      command = "python",
      manifest = InterrogativeManifest(
        WHO: "external.counter",
        WHAT: "Counter process wrapper",
        WHY: "Expose an existing process as a Thing",
        WHERE: "host process boundary",
        WHEN: "on demand",
        HOW: "stdin/stdout message exchange",
        REQUIRES: @["stdio"],
        WANTS: @["structured-json"],
        PROVIDES: @["counter.increment"],
        WITH: @["external.counter.bin"]
      ),
      args = @["examples/counter.py"],
      transport = etStdInStdOut
    )
    check wrapped.thing.id == "external-stdin-stdout"
    check wrapped.conceptBlueprint.id == "external.counter"
    check wrapped.thing.metadata["transport"].getStr == "stdin/stdout"

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
