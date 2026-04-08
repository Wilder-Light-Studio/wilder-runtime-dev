# Wilder Cosmos 0.4.0
# Module name: world_test Tests
# Module Path: tests/unit/world_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## world_test.nim
#
## Summary: Chapter 7 tests for World Ledger and World Graph behavior.
## Simile: Like replaying a flight recorder to confirm only logged moves
##   appear in the reconstructed map.
## Memory note: no implicit edges; single root invariant is strict.
## Flow: append ledger mutations -> validate graph construction ->
##   verify persistence round-trip -> enforce single-root and no-implicit-edges.

import unittest
import json
import ../../src/cosmos/thing/thing
import ../../src/cosmos/runtime/ledger
import ../../src/runtime/persistence

# Flow: Execute procedure with deterministic test helper behavior.
proc mkOcc(id: string, epoch: int64): Occurrence =
  createOccurrence(id = id, source = "thing-source", epoch = epoch, payload = %*{})

suite "world ledger mutations":
  test "append reference and claim are stored append-only":
    var ledger = initWorldLedger()

    appendReference(ledger, mkOcc("o1", 1), LedgerReference(
      fromThing: "thing-a", toThing: "thing-b", relation: "parent", epoch: 1
    ))
    appendClaim(ledger, mkOcc("o2", 2), LedgerClaim(
      thingId: "thing-a", claimKey: "role", claimValue: %*"root", epoch: 2
    ))

    check ledger.references.len == 1
    check ledger.claims.len == 1
    check ledger.references[0].fromThing == "thing-a"
    check ledger.claims[0].claimKey == "role"

  test "invalid reference is rejected":
    var ledger = initWorldLedger()
    expect(ValueError):
      appendReference(ledger, mkOcc("o3", 3), LedgerReference(
        fromThing: "", toThing: "thing-b", relation: "parent", epoch: 3
      ))

suite "world graph construction":
  test "graph reconstructs nodes and edges from references":
    var ledger = initWorldLedger()
    appendReference(ledger, mkOcc("o4", 4), LedgerReference(
      fromThing: "root", toThing: "child1", relation: "parent", epoch: 4
    ))
    appendReference(ledger, mkOcc("o5", 5), LedgerReference(
      fromThing: "root", toThing: "child2", relation: "parent", epoch: 5
    ))
    appendClaim(ledger, mkOcc("o6", 6), LedgerClaim(
      thingId: "isolated", claimKey: "label", claimValue: %*"x", epoch: 6
    ))

    let graph = buildWorldGraph(ledger)
    check graph.nodes.len == 4
    check graph.edges.len == 2
    check noImplicitEdges(ledger, graph)

  test "single root invariant passes for one-root graph":
    var ledger = initWorldLedger()
    appendReference(ledger, mkOcc("o7", 7), LedgerReference(
      fromThing: "root", toThing: "child", relation: "parent", epoch: 7
    ))
    let graph = buildWorldGraph(ledger)
    check enforceSingleRoot(graph)

  test "single root invariant fails for disconnected roots":
    var ledger = initWorldLedger()
    appendReference(ledger, mkOcc("o8", 8), LedgerReference(
      fromThing: "root1", toThing: "child1", relation: "parent", epoch: 8
    ))
    appendReference(ledger, mkOcc("o9", 9), LedgerReference(
      fromThing: "root2", toThing: "child2", relation: "parent", epoch: 9
    ))
    let graph = buildWorldGraph(ledger)
    expect(ValueError):
      discard enforceSingleRoot(graph)

suite "world ledger persistence":
  test "persist and load world ledger via in-memory bridge":
    var ledger = initWorldLedger()
    appendReference(ledger, mkOcc("o10", 10), LedgerReference(
      fromThing: "root", toThing: "child", relation: "parent", epoch: 10
    ))
    appendClaim(ledger, mkOcc("o11", 11), LedgerClaim(
      thingId: "child", claimKey: "type", claimValue: %*"agent", epoch: 11
    ))

    let bridge = newInMemoryBridge(schemaVersion = 1, origin = "world-test")
    check persistWorldLedger(bridge, ledger, "ledgerA")

    let loaded = loadWorldLedger(bridge, "ledgerA")
    check loaded.references.len == 1
    check loaded.claims.len == 1
    check loaded.references[0].toThing == "child"

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
