# Wilder Cosmos 0.4.0
# Module name: encryption_mode_test Tests
# Module Path: tests/unit/encryption_mode_test.nim
# Summary: Tests for encryption spectrum policy helpers and migration guardrails.
# Simile: Like a mode-selection panel test bench, each case verifies one policy flag flips correctly.
# Memory note: every mode must produce a stable, deterministic policy object with no hidden defaults.
# Flow: resolve mode -> assert policy flags -> assert metadata profile -> assert migration guardrails.

import unittest
import ../../src/runtime/encryption_mode
import ../../src/runtime/config

# ── policyFor ─────────────────────────────────────────────────────────────────

suite "policyFor clear mode":
  test "storesPlaintext is true":
    check policyFor(emClear).storesPlaintext == true

  test "allowsOperatorPlaintextAccess is true":
    check policyFor(emClear).allowsOperatorPlaintextAccess == true

  test "permitsOperatorEscrow is false":
    check policyFor(emClear).permitsOperatorEscrow == false

  test "requiresKeyMaterial is false":
    check policyFor(emClear).requiresKeyMaterial == false

  test "metadataProfile is empCleartext":
    check policyFor(emClear).metadataProfile == empCleartext

suite "policyFor standard mode":
  test "storesPlaintext is false":
    check policyFor(emStandard).storesPlaintext == false

  test "allowsOperatorPlaintextAccess is false":
    check policyFor(emStandard).allowsOperatorPlaintextAccess == false

  test "permitsOperatorEscrow is true":
    check policyFor(emStandard).permitsOperatorEscrow == true

  test "requiresKeyMaterial is true":
    check policyFor(emStandard).requiresKeyMaterial == true

  test "metadataProfile is empStructural":
    check policyFor(emStandard).metadataProfile == empStructural

suite "policyFor private mode":
  test "storesPlaintext is false":
    check policyFor(emPrivate).storesPlaintext == false

  test "allowsOperatorPlaintextAccess is false":
    check policyFor(emPrivate).allowsOperatorPlaintextAccess == false

  test "permitsOperatorEscrow is false":
    check policyFor(emPrivate).permitsOperatorEscrow == false

  test "requiresKeyMaterial is true":
    check policyFor(emPrivate).requiresKeyMaterial == true

  test "metadataProfile is empMinimal":
    check policyFor(emPrivate).metadataProfile == empMinimal

suite "policyFor complete mode":
  test "storesPlaintext is false":
    check policyFor(emComplete).storesPlaintext == false

  test "allowsOperatorPlaintextAccess is false":
    check policyFor(emComplete).allowsOperatorPlaintextAccess == false

  test "permitsOperatorEscrow is false":
    check policyFor(emComplete).permitsOperatorEscrow == false

  test "requiresKeyMaterial is true":
    check policyFor(emComplete).requiresKeyMaterial == true

  test "metadataProfile is empCiphertextOnly":
    check policyFor(emComplete).metadataProfile == empCiphertextOnly

# ── usesCiphertextStorage ─────────────────────────────────────────────────────

suite "usesCiphertextStorage":
  test "clear does not use ciphertext storage":
    check usesCiphertextStorage(emClear) == false

  test "standard uses ciphertext storage":
    check usesCiphertextStorage(emStandard) == true

  test "private uses ciphertext storage":
    check usesCiphertextStorage(emPrivate) == true

  test "complete uses ciphertext storage":
    check usesCiphertextStorage(emComplete) == true

# ── requiresKeyMaterial ───────────────────────────────────────────────────────

suite "requiresKeyMaterial":
  test "clear does not require key material":
    check requiresKeyMaterial(emClear) == false

  test "standard requires key material":
    check requiresKeyMaterial(emStandard) == true

  test "private requires key material":
    check requiresKeyMaterial(emPrivate) == true

  test "complete requires key material":
    check requiresKeyMaterial(emComplete) == true

# ── privacyRank ───────────────────────────────────────────────────────────────

suite "privacyRank ordering":
  test "clear has rank 0":
    check privacyRank(emClear) == 0

  test "standard has rank 1":
    check privacyRank(emStandard) == 1

  test "private has rank 2":
    check privacyRank(emPrivate) == 2

  test "complete has rank 3":
    check privacyRank(emComplete) == 3

  test "each mode has a strictly higher rank than the preceding mode":
    check privacyRank(emStandard) > privacyRank(emClear)
    check privacyRank(emPrivate) > privacyRank(emStandard)
    check privacyRank(emComplete) > privacyRank(emPrivate)

# ── isPrivacyDowngrade ────────────────────────────────────────────────────────

suite "isPrivacyDowngrade migration guardrails":
  test "complete to private is a downgrade":
    check isPrivacyDowngrade(emComplete, emPrivate) == true

  test "complete to standard is a downgrade":
    check isPrivacyDowngrade(emComplete, emStandard) == true

  test "complete to clear is a downgrade":
    check isPrivacyDowngrade(emComplete, emClear) == true

  test "private to standard is a downgrade":
    check isPrivacyDowngrade(emPrivate, emStandard) == true

  test "private to clear is a downgrade":
    check isPrivacyDowngrade(emPrivate, emClear) == true

  test "standard to clear is a downgrade":
    check isPrivacyDowngrade(emStandard, emClear) == true

  test "same mode is not a downgrade":
    check isPrivacyDowngrade(emComplete, emComplete) == false
    check isPrivacyDowngrade(emPrivate, emPrivate) == false
    check isPrivacyDowngrade(emStandard, emStandard) == false
    check isPrivacyDowngrade(emClear, emClear) == false

  test "clear to standard is not a downgrade":
    check isPrivacyDowngrade(emClear, emStandard) == false

  test "standard to private is not a downgrade":
    check isPrivacyDowngrade(emStandard, emPrivate) == false

  test "private to complete is not a downgrade":
    check isPrivacyDowngrade(emPrivate, emComplete) == false

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
