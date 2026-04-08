# Wilder Cosmos 0.4.0
# Module name: reconciliation_test Tests
# Module Path: tests/unit/reconciliation_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## reconciliation_test.nim
#
## Summary: Reconciliation tests verifying deterministic recovery across layer-failure scenarios.
## Simile: Like repair crew restoring safe baseline after system failures.
## Memory note: reconciliation is deterministic; test all failure paths systematically.
## Flow: create failure scenario -> trigger reconciliation -> verify safe state.

## Module: Reconciliation Test
## Purpose: Reconciliation behaves like a repair crew restoring safe baseline.
## Summary: Verifies deterministic recovery across layer-failure scenarios.

import unittest
import json
import std/[tables, strutils, sequtils, algorithm]
import harness
import ../../src/runtime/persistence

const
  BadChecksum =
    "0000000000000000000000000000000000000000000000000000000000000000"

suite "Chapter 3 reconciliation":
  test "single-layer failure recovers runtime layer":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"version": "0.3.0"})
    bridge.writeEnvelope(ModulesLayer, "mod.alpha", %*{"ok": true})
    bridge.writeEnvelope(TxlogLayer, "tx-1", %*{"event": "commit"})
    check commit(bridge)

    # Corrupt runtime layer checksum and verify deterministic recovery.
    bridge.runtimeLayer["runtime"]["checksum"] = %BadChecksum
    let res = reconcile(bridge)
    check res.success
    check RuntimeLayer notin res.layersUsed
    check res.messages.join(" ").toLowerAscii.contains("runtime rebuilt")
    check bridge.readEnvelope(RuntimeLayer, "runtime").hasKey("status")

  test "bit-rot in module layer is detected and reset":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"epoch": 1})
    bridge.writeEnvelope(ModulesLayer, "mod.beta", %*{"status": "healthy"})
    bridge.writeEnvelope(TxlogLayer, "tx-2", %*{"event": "commit"})
    check commit(bridge)

    bridge.modulesLayer["mod.beta"]["checksum"] = %BadChecksum
    let res = reconcile(bridge)
    check res.success
    check "modules" in res.messages.join(" ").toLowerAscii
    check bridge.listLayerKeys(ModulesLayer).len == 0

  test "partial write in txlog creates recovery marker":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"ready": true})
    bridge.writeEnvelope(ModulesLayer, "mod.gamma", %*{"enabled": true})
    bridge.writeEnvelope(TxlogLayer, "tx-3", %*{"event": "commit"})
    check commit(bridge)

    bridge.txlogLayer["tx-3"]["checksum"] = %BadChecksum
    let res = reconcile(bridge)
    check res.success
    let txKeys = bridge.listLayerKeys(TxlogLayer)
    check txKeys.len >= 1
    check txKeys.anyIt(it.startsWith("recovery-"))

  test "file-backed txlog keys remain deterministic across epoch files":
    setupTest("reconciliation_file_txlog_order")
    defer: teardownTest()

    var bridge = newFileBridge(testTmpDir)

    let firstTx = beginTransaction(bridge)
    bridge.writeEnvelope(TxlogLayer, firstTx, %*{"event": "commit-1"})
    let firstEnv = bridge.stagedWrites.values.toSeq[0]
    rollback(bridge)
    bridge.persistEnvelope(TxlogLayer, firstTx, firstEnv)

    let secondTx = beginTransaction(bridge)
    bridge.writeEnvelope(TxlogLayer, secondTx, %*{"event": "commit-2"})
    let secondEnv = bridge.stagedWrites.values.toSeq[0]
    rollback(bridge)
    bridge.persistEnvelope(TxlogLayer, secondTx, secondEnv)

    let keys = bridge.listLayerKeys(TxlogLayer)
    var expected = @[firstTx, secondTx]
    expected.sort(system.cmp[string])
    check keys == expected
    check bridge.loadEnvelope(TxlogLayer, firstTx)["txId"].getStr() == firstTx
    check bridge.loadEnvelope(TxlogLayer, secondTx)["txId"].getStr() == secondTx

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
