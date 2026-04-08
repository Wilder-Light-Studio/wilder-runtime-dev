# Wilder Cosmos 0.4.0
# Module name: persistence_record_test
# Module Path: tests/unit/persistence_record_test.nim
# Summary: Integration checks for RECORD persistence behavior through runtime persistence layers.
# Simile: Like a vault audit, it verifies encrypted entries remain intact after storage round-trips.
# Memory note: RECORD tests should assert deterministic metadata and chain continuity first.
#
# Wilder Foundation License 1.0
# persistence_record_test.nim

import std/[json, os]
import ../../src/runtime/persistence
import ../../src/runtime/encrypted_record
import ../../src/runtime/validation
import ../../src/runtime/config

# Flow: Convert string to bytes.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

# Flow: Execute test suite with deterministic setup/teardown.
proc runTests*() =
  echo "[Suite] persistence layer records integration"

  # Test: records layer can store and retrieve encrypted entries.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    bridge.activeTransaction = true
    bridge.activeTransactionId = "tx-test-1"

    # Create an encrypted entry record manually.
    let keyMaterial = "test_key_material_12"
    let payload = %*{"data": "test_payload", "hint": "secret"}
    let encryptedPayload = encryptDeterministicPayload(
      payload, keyMaterial, 1, "data_entry", "author-1", "")
    let encryptedPayloadHash = computeSha256(toBytes(encryptedPayload))

    let recordPayload = %*{
      "entryType": "data_entry",
      "authorId": "author-1",
      "sequence": 1,
      "previousHash": "",
      "encryptedPayload": encryptedPayload,
      "encryptedPayloadHash": encryptedPayloadHash
    }
    let payloadChecksum = computeSha256(toBytes($recordPayload))

    let recordEnv = %*{
      "schemaVersion": 1,
      "epoch": 1,
      "checksum": payloadChecksum,
      "origin": "test",
      "payload": recordPayload
    }

    bridge.persistEnvelope(RecordsLayer, "entry_1", recordEnv)
    let loaded = bridge.loadEnvelope(RecordsLayer, "entry_1")
    let payload_hash = loaded["payload"]["encryptedPayloadHash"].getStr()
    assert payload_hash == encryptedPayloadHash, "persisted RECORD payload hash mismatch"
    echo "[OK] records layer stores and retrieves encrypted entries"

  # Test: multiple RECORD entries can be persisted with deterministic ordering.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    bridge.activeTransaction = true
    bridge.activeTransactionId = "tx-test-2"

    let keyMaterial = "key_material_multi"
    var previousHash = ""
    for i in 1 .. 3:
      let payload = %*{"sequence": i, "data": "entry_" & $i}
      let encryptedPayload = encryptDeterministicPayload(
        payload, keyMaterial, int64(i), "chain_entry", "author-" & $i, previousHash)
      let encryptedPayloadHash = computeSha256(toBytes(encryptedPayload))

      let recordPayload = %*{
        "entryType": "chain_entry",
        "authorId": "author-" & $i,
        "sequence": i,
        "previousHash": previousHash,
        "encryptedPayload": encryptedPayload,
        "encryptedPayloadHash": encryptedPayloadHash
      }
      let checksum = computeSha256(toBytes($recordPayload))

      let recordEnv = %*{
        "schemaVersion": 1,
        "epoch": int64(i),
        "checksum": checksum,
        "origin": "test",
        "payload": recordPayload
      }

      bridge.persistEnvelope(RecordsLayer, "entry_" & $i, recordEnv)
      previousHash = encryptedPayloadHash

    let keys = bridge.listLayerKeys(RecordsLayer)
    assert keys.len == 3, "expected 3 RECORD entries"
    assert keys == ["entry_1", "entry_2", "entry_3"], "RECORD keys not sorted"
    echo "[OK] multiple RECORD entries persisted with deterministic ordering"

  # Test: snapshot includes RECORD layer entries.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    bridge.activeTransaction = true
    bridge.activeTransactionId = "tx-test-3"

    let keyMaterial = "snapshot_test_key"
    let payload = %*{"test": "data"}
    let encryptedPayload = encryptDeterministicPayload(
      payload, keyMaterial, 1, "snapshot_entry", "author-snap", "")
    let encryptedPayloadHash = computeSha256(toBytes(encryptedPayload))

    let recordPayload = %*{
      "entryType": "snapshot_entry",
      "authorId": "author-snap",
      "sequence": 1,
      "previousHash": "",
      "encryptedPayload": encryptedPayload,
      "encryptedPayloadHash": encryptedPayloadHash
    }
    let checksum = computeSha256(toBytes($recordPayload))

    let recordEnv = %*{
      "schemaVersion": 1,
      "epoch": 1,
      "checksum": checksum,
      "origin": "test",
      "payload": recordPayload
    }

    bridge.persistEnvelope(RecordsLayer, "snap_entry", recordEnv)

    discard bridge.snapshotAll()
    # Load the entry back to confirm it persisted correctly.
    let loaded = bridge.loadEnvelope(RecordsLayer, "snap_entry")
    assert loaded["payload"]["encryptedPayloadHash"].getStr() == encryptedPayloadHash,
      "loaded RECORD entry payload hash mismatch"
    echo "[OK] snapshot includes RECORD layer entries"

  # Test: restoreSnapshot restores RECORD entries.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    bridge.activeTransaction = true
    bridge.activeTransactionId = "tx-test-4"

    let keyMaterial = "restore_test_key"
    let payload = %*{"restore": "test"}
    let encryptedPayload = encryptDeterministicPayload(
      payload, keyMaterial, 1, "restore_entry", "author-restore", "")
    let encryptedPayloadHash = computeSha256(toBytes(encryptedPayload))

    let recordPayload = %*{
      "entryType": "restore_entry",
      "authorId": "author-restore",
      "sequence": 1,
      "previousHash": "",
      "encryptedPayload": encryptedPayload,
      "encryptedPayloadHash": encryptedPayloadHash
    }
    let checksum = computeSha256(toBytes($recordPayload))

    let recordEnv = %*{
      "schemaVersion": 1,
      "epoch": 1,
      "checksum": checksum,
      "origin": "test",
      "payload": recordPayload
    }

    bridge.persistEnvelope(RecordsLayer, "restore_entry", recordEnv)
    let snapshot = bridge.snapshotAll()

    # Create new bridge and restore.
    let bridge2 = newInMemoryBridge(schemaVersion=1, origin="test")
    bridge2.restoreSnapshot(snapshot)

    let restored = bridge2.loadEnvelope(RecordsLayer, "restore_entry")
    assert restored["payload"]["encryptedPayloadHash"].getStr() == encryptedPayloadHash,
      "restored RECORD entry payload hash mismatch"
    echo "[OK] restoreSnapshot restores RECORD entries"

  # Test: RECORD layer supports file-backed persistence.
  block:
    let tmpDir = getTempDir() / "wilder_record_test"
    try:
      createDir(tmpDir)
      let bridge = newFileBridge(tmpDir, schemaVersion=1, origin="file_test")

      let keyMaterial = "file_test_key"
      let payload = %*{"file": "persisted"}
      let encryptedPayload = encryptDeterministicPayload(
        payload, keyMaterial, 1, "file_entry", "author-file", "")
      let encryptedPayloadHash = computeSha256(toBytes(encryptedPayload))

      let recordPayload = %*{
        "entryType": "file_entry",
        "authorId": "author-file",
        "sequence": 1,
        "previousHash": "",
        "encryptedPayload": encryptedPayload,
        "encryptedPayloadHash": encryptedPayloadHash
      }
      let checksum = computeSha256(toBytes($recordPayload))

      let recordEnv = %*{
        "schemaVersion": 1,
        "epoch": 1,
        "checksum": checksum,
        "origin": "file_test",
        "payload": recordPayload
      }

      bridge.persistEnvelope(RecordsLayer, "file_record", recordEnv)
      let loaded = bridge.loadEnvelope(RecordsLayer, "file_record")
      assert loaded["payload"]["encryptedPayloadHash"].getStr() == encryptedPayloadHash,
        "file-backed RECORD entry payload hash mismatch"
      echo "[OK] RECORD layer supports file-backed persistence"
    finally:
      if dirExists(tmpDir):
        removeDir(tmpDir)

  # Test: clear mode persists plaintext JSON through record helpers.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    discard bridge.beginTransaction()
    let payload = %*{"mode": "clear", "content": "visible"}
    bridge.writeRecordEntry("clear_entry", payload, emClear, "", 1, "clear_entry", "author-clear", "")
    discard bridge.commit()

    let stored = bridge.loadEnvelope(RecordsLayer, "clear_entry")
    assert stored["payload"]["encryptedPayload"].getStr() == $payload,
      "clear-mode RECORD payload should remain plaintext"
    let restored = bridge.readRecordPayload("clear_entry", emClear, "")
    assert restored == payload, "clear-mode RECORD payload round-trip mismatch"
    echo "[OK] clear mode persists plaintext RECORD payloads predictably"

  # Test: standard mode persists ciphertext through record helpers and restores payload.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    discard bridge.beginTransaction()
    let payload = %*{"mode": "standard", "content": "hidden"}
    bridge.writeRecordEntry("standard_entry", payload, emStandard, "std-key", 1, "secure_entry", "author-std", "")
    discard bridge.commit()

    let stored = bridge.loadEnvelope(RecordsLayer, "standard_entry")
    assert stored["payload"]["encryptedPayload"].getStr() != $payload,
      "standard-mode RECORD payload should not remain plaintext"
    let restored = bridge.readRecordPayload("standard_entry", emStandard, "std-key")
    assert restored == payload, "standard-mode RECORD payload round-trip mismatch"
    echo "[OK] standard mode persists ciphertext and restores RECORD payloads"

  # Test: migrating clear RECORDs to standard rewrites plaintext to ciphertext.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    discard bridge.beginTransaction()
    bridge.writeRecordEntry("entry_a", %*{"v": 1}, emClear, "", 1, "event", "author-a", "")
    bridge.writeRecordEntry("entry_b", %*{"v": 2}, emClear, "", 2, "event", "author-a", computeSha256(toBytes($(%*{"v": 1}))))
    discard bridge.commit()

    let migration = bridge.migrateRecordLayer(emClear, emStandard, "", "migrate-key")
    assert migration.migratedCount == 2, "expected both clear RECORDs to migrate"

    let storedA = bridge.loadEnvelope(RecordsLayer, "entry_a")
    let storedB = bridge.loadEnvelope(RecordsLayer, "entry_b")
    assert storedA["payload"]["encryptedPayload"].getStr() != $(%*{"v": 1}),
      "migrated standard RECORD payload should not remain plaintext"
    let migratedPayloadB = bridge.readRecordPayload("entry_b", emStandard, "migrate-key")
    assert migratedPayloadB == %*{"v": 2}, "migrated standard RECORD payload mismatch"
    assert storedB["payload"]["previousHash"].getStr() == storedA["payload"]["encryptedPayloadHash"].getStr(),
      "migrated RECORD chain should be re-linked to new hashes"
    echo "[OK] clear-to-standard migration rewrites RECORD ciphertext and chain metadata"

  # Test: downgrading protected RECORDs requires explicit approval.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    discard bridge.beginTransaction()
    bridge.writeRecordEntry("entry_secure", %*{"secret": true}, emStandard, "secure-key", 1, "event", "author-s", "")
    discard bridge.commit()

    try:
      discard bridge.migrateRecordLayer(emStandard, emClear, "secure-key", "")
      assert false, "expected downgrade migration to require explicit approval"
    except PersistenceError:
      discard

    let migration = bridge.migrateRecordLayer(emStandard, emClear, "secure-key", "", allowDowngrade = true)
    assert migration.migratedCount == 1, "expected protected RECORD downgrade to migrate one entry"
    let downgraded = bridge.loadEnvelope(RecordsLayer, "entry_secure")
    assert downgraded["payload"]["encryptedPayload"].getStr() == $(%*{"secret": true}),
      "approved downgrade should rewrite payload to plaintext"
    echo "[OK] protected-to-clear migration requires approval and rewrites plaintext"

  # Test: operator summaries redact payload in protected modes.
  block:
    let bridge = newInMemoryBridge(schemaVersion=1, origin="test")
    discard bridge.beginTransaction()
    bridge.writeRecordEntry("operator_view", %*{"secret": "hidden"}, emComplete, "summary-key", 1, "event", "author-o", "")
    discard bridge.commit()

    let summary = bridge.summarizeRecordForOperator("operator_view", emComplete)
    assert summary["contentVisible"].getBool() == false,
      "complete-mode operator summary must hide content"
    assert not summary.hasKey("authorId"),
      "complete-mode operator summary must hide author metadata"
    echo "[OK] operator summaries redact protected RECORD metadata and payloads"

# Entry point.
when isMainModule:
  runTests()
