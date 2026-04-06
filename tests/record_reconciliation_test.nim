# Wilder Cosmos 0.4.0
# Module name: record_reconciliation_test
# Module Path: tests/record_reconciliation_test.nim
# Summary: Test coverage for metadata-only reconciliation outcomes across three RECORD copies.
# Simile: Like a chain inspector, it catches sequence and hash breaks without touching payload plaintext.
# Memory note: keep copy fixtures deterministic so status classification remains stable.
#
# Wilder Foundation License 1.0
# record_reconciliation_test.nim

import std/[json, strutils]
import ../src/runtime/record_reconciliation

# Flow: Execute test suite with deterministic setup/teardown.
proc runTests*() =
  echo "[Suite] record reconciliation"

  # Test: healthy reconciliation when all three copies agree.
  block:
    # Three identical copies of RECORD entries.
    let copy = @[
      %*{
        "sequence": 1,
        "entryType": "data_entry",
        "encryptedPayloadHash": "abc123",
        "previousHash": ""
      },
      %*{
        "sequence": 2,
        "entryType": "data_entry",
        "encryptedPayloadHash": "def456",
        "previousHash": "abc123"
      }
    ]

    let reconcResult = reconcileTriumvirate(copy, copy, copy)
    assert reconcResult.status == rcHealthy, "should be healthy when all copies match"
    assert reconcResult.healthyCount == 3, "all three copies should be valid"
    assert reconcResult.brokenKeys.len == 0, "no broken keys"
    echo "[OK] healthy reconciliation with consensual copies"

  # Test: chain broken when sequence is not strictly increasing.
  block:
    let brokenCopy = @[
      %*{
        "sequence": 1,
        "entryType": "data_entry",
        "encryptedPayloadHash": "abc123",
        "previousHash": ""
      },
      %*{
        "sequence": 3,  # Should be 2
        "entryType": "data_entry",
        "encryptedPayloadHash": "def456",
        "previousHash": "abc123"
      }
    ]

    let goodCopy = @[
      %*{
        "sequence": 1,
        "entryType": "data_entry",
        "encryptedPayloadHash": "abc123",
        "previousHash": ""
      },
      %*{
        "sequence": 2,
        "entryType": "data_entry",
        "encryptedPayloadHash": "def456",
        "previousHash": "abc123"
      }
    ]

    let reconcResult = reconcileTriumvirate(brokenCopy, goodCopy, goodCopy)
    assert reconcResult.status == rcChainBroken, "should detect chain broken in copy 1"
    assert reconcResult.healthyCount == 2, "only 2 copies valid"
    assert reconcResult.brokenKeys.len == 1, "one broken key"
    echo "[OK] chain broken status detected for non-increasing sequence"

  # Test: hash mismatch when previous hash chain is broken.
  block:
    let copy1 = @[
      %*{
        "sequence": 1,
        "entryType": "data_entry",
        "encryptedPayloadHash": "abc123",
        "previousHash": ""
      },
      %*{
        "sequence": 2,
        "entryType": "data_entry",
        "encryptedPayloadHash": "def456",
        "previousHash": "abc123"
      }
    ]

    let copy2 = @[
      %*{
        "sequence": 1,
        "entryType": "data_entry",
        "encryptedPayloadHash": "abc123",
        "previousHash": ""
      },
      %*{
        "sequence": 2,
        "entryType": "data_entry",
        "encryptedPayloadHash": "zzz999",  # Divergence while chain remains structurally valid
        "previousHash": "abc123"
      }
    ]

    let reconcResult = reconcileTriumvirate(copy1, copy2, copy1)
    assert reconcResult.status == rcHashMismatch, "should detect hash mismatch"
    echo "[OK] hash mismatch status detected for divergent metadata"

  # Test: sequence error when copy lengths differ.
  block:
    let copy1 = @[
      %*{
        "sequence": 1,
        "entryType": "data_entry",
        "encryptedPayloadHash": "abc123",
        "previousHash": ""
      }
    ]

    let copy2 = @[
      %*{
        "sequence": 1,
        "entryType": "data_entry",
        "encryptedPayloadHash": "abc123",
        "previousHash": ""
      },
      %*{
        "sequence": 2,
        "entryType": "data_entry",
        "encryptedPayloadHash": "def456",
        "previousHash": "abc123"
      }
    ]

    let reconcResult = reconcileTriumvirate(copy1, copy2, copy1)
    assert reconcResult.status == rcSequenceError, "should detect sequence error"
    echo "[OK] sequence error status detected for length mismatch"

  # Test: report formatting is deterministic.
  block:
    let reconcResult = ReconciliationResult(
      status: rcHealthy,
      description: "all copies agree",
      healthyCount: 3,
      brokenKeys: @[]
    )

    let report = formatReconciliationReport(reconcResult)
    assert report.find("reconciliation_status=rcHealthy") >= 0, "status included"
    assert report.find("healthy_copies=3") >= 0, "healthy count included"
    echo "[OK] reconciliation report formatting works deterministically"

# Entry point.
when isMainModule:
  runTests()
