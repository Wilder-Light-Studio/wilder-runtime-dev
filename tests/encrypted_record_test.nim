# Wilder Cosmos 0.4.0
# Module name: encrypted_record_test Tests
# Module Path: tests/encrypted_record_test.nim
# Summary: Contract tests for deterministic encrypted RECORD entry behavior.
# Simile: Like verifying sealed envelopes, we test both seal consistency and chain links.
# Memory note: reconciliation checks metadata only and never requires payload decrypt.
# Flow: build entries -> validate deterministic encryption -> validate structural chain checks.

import unittest
import json
import ../src/runtime/encrypted_record
import ../src/runtime/config

suite "encrypted RECORD deterministic behavior":
  test "same input yields same ciphertext and hash":
    let payload = %*{"event": "wave", "v": 1}
    let a = buildEncryptedRecordEntry(payload, "k-1", 1, "occurrence", "anon-a", "")
    let b = buildEncryptedRecordEntry(payload, "k-1", 1, "occurrence", "anon-a", "")
    check a.encryptedPayload == b.encryptedPayload
    check a.encryptedPayloadHash == b.encryptedPayloadHash

  test "payload change yields different ciphertext hash":
    let a = buildEncryptedRecordEntry(%*{"event": "wave"}, "k-1", 1, "occurrence", "anon-a", "")
    let b = buildEncryptedRecordEntry(%*{"event": "world"}, "k-1", 1, "occurrence", "anon-a", "")
    check a.encryptedPayloadHash != b.encryptedPayloadHash

  test "decrypt round-trip restores original payload":
    let payload = %*{"event": "snapshot", "revision": 3}
    let entry = buildEncryptedRecordEntry(payload, "k-2", 1, "snapshot", "anon-b", "")
    let restored = decryptDeterministicPayload(
      entry.encryptedPayload,
      "k-2",
      entry.sequence,
      entry.entryType,
      entry.authorId,
      entry.previousHash
    )
    check restored == payload

  test "clear mode stores plaintext deterministically":
    let payload = %*{"event": "clear", "revision": 1}
    let entry = buildRecordEntryForMode(payload, emClear, "", 1, "snapshot", "anon-c", "")
    check entry.encryptedPayload == $payload
    check restoreRecordPayloadForMode(entry, emClear, "") == payload

  test "protected modes require key material":
    expect(ValueError):
      discard buildRecordEntryForMode(%*{"event": "secure"}, emComplete, "", 1, "snapshot", "anon-c", "")

  test "standard summary hides payload but keeps author":
    let payload = %*{"event": "standard", "revision": 2}
    let entry = buildRecordEntryForMode(payload, emStandard, "k-std", 1, "snapshot", "anon-d", "")
    let summary = summarizeRecordEntryForMode(entry, emStandard)
    check summary["contentVisible"].getBool == false
    check summary["authorId"].getStr() == "anon-d"
    check not summary.hasKey("payload")

  test "complete summary hides payload and author":
    let payload = %*{"event": "complete", "revision": 3}
    let entry = buildRecordEntryForMode(payload, emComplete, "k-complete", 1, "snapshot", "anon-e", "")
    let summary = summarizeRecordEntryForMode(entry, emComplete)
    check summary["contentVisible"].getBool == false
    check not summary.hasKey("authorId")
    check not summary.hasKey("payload")

suite "encrypted RECORD metadata reconciliation":
  test "metadata chain validation accepts valid sequence and previous hash":
    let first = buildEncryptedRecordEntry(%*{"v": 1}, "k-1", 1, "occurrence", "anon", "")
    let second = buildEncryptedRecordEntry(%*{"v": 2}, "k-1", 2, "occurrence", "anon", first.encryptedPayloadHash)
    check validateRecordChainMetadata(@[first, second])

  test "metadata chain validation rejects previous hash mismatch":
    let first = buildEncryptedRecordEntry(%*{"v": 1}, "k-1", 1, "occurrence", "anon", "")
    var second = buildEncryptedRecordEntry(%*{"v": 2}, "k-1", 2, "occurrence", "anon", first.encryptedPayloadHash)
    second.previousHash = "bad"
    check validateRecordChainMetadata(@[first, second]) == false

  test "triumvirate comparison uses structural metadata tuple":
    let first = buildEncryptedRecordEntry(%*{"v": 1}, "k-1", 1, "occurrence", "anon", "")
    let second = buildEncryptedRecordEntry(%*{"v": 2}, "k-1", 2, "occurrence", "anon", first.encryptedPayloadHash)
    let copyA = @[first, second]
    let copyB = @[first, second]
    var copyC = @[first, second]
    check compareTriumvirateMetadata(copyA, copyB, copyC)
    copyC[1].entryType = "evidence"
    check compareTriumvirateMetadata(copyA, copyB, copyC) == false

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
