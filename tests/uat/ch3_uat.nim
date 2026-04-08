# Wilder Cosmos 0.4.0
# Module name: ch3_uat Tests
# Module Path: tests/uat/ch3_uat.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## ch3_uat.nim
#
## Summary: Chapter 3 User Acceptance Test validating persistence and recovery.
## Simile: Like a flight checklist before release, ensuring safety constraints hold.
## Memory note: Chapter 3 UAT validates persistence, recovery, migration, and safety invariants.
## Flow: test persistence -> test recovery -> test migration -> verify constraints.

## Module: Chapter 3 User Acceptance Test (UAT)
## Purpose: This suite acts like a flight checklist before release.
## Summary: Validates persistence, recovery, migration, and safety constraints.

import unittest
import json
import std/[tables, os, strutils, sequtils]
import harness
import ../../src/runtime/persistence
import ../../src/runtime/validation

const
  BadChecksum =
    "0000000000000000000000000000000000000000000000000000000000000000"
  SigningKey = "ch3-signing-key"

# Flow: Execute procedure with deterministic test helper behavior.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

suite "Chapter 3 UAT":
  test "UAT-CH3-001 transaction commit persists state":
    var bridge = newInMemoryBridge()
    let txId = beginTransaction(bridge)
    check txId.len > 0
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"status": "ok"})
    check commit(bridge)
    check bridge.readEnvelope(RuntimeLayer, "runtime")["status"].getStr() ==
      "ok"

  test "UAT-CH3-002 failed invariant rejects commit and preserves state":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"before": true})
    check commit(bridge)

    discard beginTransaction(bridge)
    bridge.writeEnvelope(
      RuntimeLayer,
      "runtime",
      %*{"before": false, "secret": "do-not-leak"}
    )
    # Force checksum mismatch in staged envelope to trigger commit rollback.
    let stagedKey = bridge.stagedWrites.keys.toSeq[0]
    bridge.stagedWrites[stagedKey]["checksum"] = %BadChecksum

    expect(PersistenceError):
      discard commit(bridge)

    let payload = bridge.readEnvelope(RuntimeLayer, "runtime")
    check payload["before"].getBool()

  test "UAT-CH3-003 rollback restores pre-transaction state":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"version": "a"})
    check commit(bridge)

    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"version": "b"})
    rollback(bridge)

    let payload = bridge.readEnvelope(RuntimeLayer, "runtime")
    check payload["version"].getStr() == "a"

  test "UAT-CH3-004 checksum mismatch fails read fail-fast":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(ModulesLayer, "mod.alpha", %*{"k": "v"})
    check commit(bridge)

    bridge.modulesLayer["mod.alpha"]["checksum"] = %BadChecksum
    expect(ValueError):
      discard bridge.readEnvelope(ModulesLayer, "mod.alpha")

  test "UAT-CH3-005 malformed metadata fails read fail-fast":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(ModulesLayer, "mod.beta", %*{"k": 1})
    check commit(bridge)

    bridge.modulesLayer["mod.beta"].delete("origin")
    expect(ValueError):
      discard bridge.readEnvelope(ModulesLayer, "mod.beta")

  test "UAT-CH3-006 reconciliation recovers single-layer failure":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"ok": true})
    bridge.writeEnvelope(ModulesLayer, "mod.gamma", %*{"count": 1})
    bridge.writeEnvelope(TxlogLayer, "tx-1", %*{"event": "commit"})
    check commit(bridge)

    bridge.runtimeLayer["runtime"]["checksum"] = %BadChecksum
    let res = reconcile(bridge)
    check res.success

  test "UAT-CH3-007 migration chain completes with validation":
    var bridge = newInMemoryBridge(schemaVersion = 2)
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"version": 1})
    check commit(bridge)

    let env = bridge.loadEnvelope(RuntimeLayer, "runtime")
    var migrators = initTable[int, MigrationStep]()
    migrators[2] = proc(payload: JsonNode): JsonNode =
      result = payload
      result["migrated"] = %true

    let migrated = migrateEnvelope(bridge, env, 3, migrators)
    check migrated["schemaVersion"].getInt() == 3
    check migrated["payload"].hasKey("migrated")

  test "UAT-CH3-008 migration pre-check failure halts safely":
    var bridge = newInMemoryBridge(schemaVersion = 3)
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"version": 3})
    check commit(bridge)

    let env = bridge.loadEnvelope(RuntimeLayer, "runtime")
    var migrators = initTable[int, MigrationStep]()
    expect(PersistenceError):
      discard migrateEnvelope(bridge, env, 2, migrators)

  test "UAT-CH3-009 valid signed snapshot imports successfully":
    var source = newInMemoryBridge()
    discard beginTransaction(source)
    source.writeEnvelope(RuntimeLayer, "runtime", %*{
      "state": "green",
      "encryptionMode": "standard",
      "recoveryEnabled": false,
      "operatorEscrow": false
    })
    source.writeEnvelope(ModulesLayer, "mod.delta", %*{"value": 42})
    check commit(source)

    let snapshot = exportSnapshot(source, "snap-001", SigningKey)
    check snapshot["payload"]["runtimeContract"]["encryptionMode"].getStr() ==
      "standard"
    var target = newInMemoryBridge()
    importSnapshot(target, snapshot, SigningKey)
    check target.readEnvelope(RuntimeLayer, "runtime")["state"].getStr() ==
      "green"

  test "UAT-CH3-009A snapshot export records runtime encryption contract":
    var source = newInMemoryBridge()
    discard beginTransaction(source)
    source.writeEnvelope(RuntimeLayer, "runtime", %*{
      "state": "green",
      "encryptionMode": "private",
      "recoveryEnabled": false,
      "operatorEscrow": false
    })
    check commit(source)

    let snapshot = exportSnapshot(source, "snap-001a", SigningKey)
    check snapshot["payload"]["runtimeContract"]["encryptionMode"].getStr() ==
      "private"
    check not snapshot["payload"]["runtimeContract"]["recoveryEnabled"].getBool()

  test "UAT-CH3-010 invalid snapshot signature is rejected":
    var source = newInMemoryBridge()
    discard beginTransaction(source)
    source.writeEnvelope(RuntimeLayer, "runtime", %*{"state": "blue"})
    check commit(source)

    var snapshot = exportSnapshot(source, "snap-002", SigningKey)
    snapshot["signature"] = %"tampered"

    var target = newInMemoryBridge()
    expect(PersistenceError):
      importSnapshot(target, snapshot, SigningKey)

  test "UAT-CH3-010A snapshot import rejects mismatched runtime contract":
    var source = newInMemoryBridge()
    discard beginTransaction(source)
    source.writeEnvelope(RuntimeLayer, "runtime", %*{
      "state": "blue",
      "encryptionMode": "standard",
      "recoveryEnabled": false,
      "operatorEscrow": false
    })
    check commit(source)

    var snapshot = exportSnapshot(source, "snap-002a", SigningKey)
    snapshot["payload"]["runtimeContract"]["encryptionMode"] = %"complete"
    snapshot["checksum"] = %computeSha256(toBytes($snapshot["payload"]))
    snapshot["signature"] = %signSnapshot(snapshot, SigningKey)

    var target = newInMemoryBridge()
    expect(PersistenceError):
      importSnapshot(target, snapshot, SigningKey)

  test "UAT-CH3-011 stream APIs preserve large blob integrity":
    var bridge = newInMemoryBridge()
    let largeText = repeat('x', StreamChunkSize + 1024)
    let data = toBytes(largeText)

    discard beginTransaction(bridge)
    bridge.writeStreamBlob(ModulesLayer, "blob.large", data)
    check commit(bridge)

    let readBack = bridge.readStreamBlob(ModulesLayer, "blob.large")
    check readBack.len == data.len
    check $readBack.len == $(StreamChunkSize + 1024)

  test "UAT-CH3-012 file bridge creates required storage layout":
    setupTest("ch3_uat_file_layout")
    defer: teardownTest()

    discard newFileBridge(testTmpDir)
    check dirExists(testTmpDir / "state")
    check dirExists(testTmpDir / "state" / "modules")
    check dirExists(testTmpDir / "state" / "txlog")
    check dirExists(testTmpDir / "state" / "snapshots")

  test "UAT-CH3-014 file bridge roundtrip rewrites without temp residue":
    setupTest("ch3_uat_file_roundtrip")
    defer: teardownTest()

    var bridge = newFileBridge(testTmpDir)

    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"status": "cold"})
    check commit(bridge)

    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"status": "warm"})
    check commit(bridge)

    let payload = bridge.readEnvelope(RuntimeLayer, "runtime")
    check payload["status"].getStr() == "warm"
    check fileExists(testTmpDir / "state" / "runtime.json")
    check not fileExists(testTmpDir / "state" / "runtime.json.tmp")

  test "UAT-CH3-015 txlog entries use epoch files and suppress duplicates":
    setupTest("ch3_uat_txlog_epoch")
    defer: teardownTest()

    var bridge = newFileBridge(testTmpDir)
    let txId = beginTransaction(bridge)
    bridge.writeEnvelope(TxlogLayer, txId, %*{"event": "commit"})

    let stagedTxlog = bridge.stagedWrites.values.toSeq[0]
    rollback(bridge)

    bridge.persistEnvelope(TxlogLayer, txId, stagedTxlog)
    bridge.persistEnvelope(TxlogLayer, txId, stagedTxlog)

    let txlogPath = testTmpDir / "state" / "txlog" / "1.txlog"
    check fileExists(txlogPath)

    let lines = readFile(txlogPath).splitLines().filterIt(it.strip.len > 0)
    check lines.len == 1

    let entry = parseJson(lines[0])
    check entry["recordKey"].getStr() == txId
    check bridge.listLayerKeys(TxlogLayer) == @[txId]
    check bridge.loadEnvelope(TxlogLayer, txId)["txId"].getStr() == txId

  test "UAT-CH3-016 snapshots persist with deterministic epoch naming":
    setupTest("ch3_uat_snapshot_persist")
    defer: teardownTest()

    var source = newInMemoryBridge()
    discard beginTransaction(source)
    source.writeEnvelope(RuntimeLayer, "runtime", %*{"state": "snapshotted"})
    check commit(source)

    let snapshotEnv = exportSnapshot(source, "snap-file-001", SigningKey)
    var bridge = newFileBridge(testTmpDir)
    bridge.persistEnvelope(SnapshotsLayer, "snap-file-001", snapshotEnv)

    let snapshotPath = testTmpDir / "state" / "snapshots" / "1_snapshot.json"
    check fileExists(snapshotPath)
    let stored = parseJson(readFile(snapshotPath))
    check stored["recordKey"].getStr() == "snap-file-001"
    check bridge.loadEnvelope(SnapshotsLayer, "snap-file-001")["signature"].getStr() ==
      snapshotEnv["signature"].getStr()

  test "UAT-CH3-017 corrupt persisted snapshot fails fast on load":
    setupTest("ch3_uat_snapshot_corrupt")
    defer: teardownTest()

    var source = newInMemoryBridge()
    discard beginTransaction(source)
    source.writeEnvelope(RuntimeLayer, "runtime", %*{"state": "valid"})
    check commit(source)

    let snapshotEnv = exportSnapshot(source, "snap-corrupt-001", SigningKey)
    var bridge = newFileBridge(testTmpDir)
    bridge.persistEnvelope(SnapshotsLayer, "snap-corrupt-001", snapshotEnv)

    let snapshotPath = testTmpDir / "state" / "snapshots" / "1_snapshot.json"
    var stored = parseJson(readFile(snapshotPath))
    stored["checksum"] = %BadChecksum
    writeFile(snapshotPath, stored.pretty)

    expect(ValueError):
      discard bridge.loadEnvelope(SnapshotsLayer, "snap-corrupt-001")

  test "UAT-CH3-018 failed restore preserves existing file state":
    setupTest("ch3_uat_restore_atomic")
    defer: teardownTest()

    var bridge = newFileBridge(testTmpDir)
    discard beginTransaction(bridge)
    bridge.writeEnvelope(RuntimeLayer, "runtime", %*{"state": "stable"})
    bridge.writeEnvelope(ModulesLayer, "mod.alpha", %*{"version": 1})
    check commit(bridge)

    let runtimeBefore = bridge.loadEnvelope(RuntimeLayer, "runtime")
    let modulesBefore = bridge.loadEnvelope(ModulesLayer, "mod.alpha")

    var snapshot = initTable[string, JsonNode]()
    snapshot["runtime:runtime"] = runtimeBefore

    var invalidModule = parseJson($modulesBefore)
    invalidModule["checksum"] = %BadChecksum
    snapshot["modules:mod.alpha"] = invalidModule

    expect(PersistenceError):
      bridge.restoreSnapshot(snapshot)

    check bridge.readEnvelope(RuntimeLayer, "runtime")["state"].getStr() == "stable"
    check bridge.readEnvelope(ModulesLayer, "mod.alpha")["version"].getInt() == 1

  test "UAT-CH3-013 errors do not leak raw payload":
    var bridge = newInMemoryBridge()
    discard beginTransaction(bridge)
    bridge.writeEnvelope(
      ModulesLayer,
      "mod.secret",
      %*{"secret": "TOP-SECRET-RAW"}
    )
    check commit(bridge)

    bridge.modulesLayer["mod.secret"]["checksum"] = %BadChecksum
    try:
      discard bridge.readEnvelope(ModulesLayer, "mod.secret")
      check false
    except ValueError as e:
      check "TOP-SECRET-RAW" notin e.msg
# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
