# Wilder Cosmos 0.4.0
# Module name: encryption_mode
# Module Path: src/runtime/encryption_mode.nim
#
# encryption_mode.nim
# Runtime encryption-spectrum policy helpers.
# Summary: Map the configured encryption mode to explicit runtime policy flags.
# Simile: Like a circuit breaker panel, one mode selection controls several downstream rules.
# Memory note: keep policy explicit so storage and diagnostics do not invent their own semantics.
# Flow: accept typed mode -> derive stable policy object -> let callers enforce behavior.

import config

type
  EncryptionMetadataProfile* = enum
    empCleartext
    empStructural
    empMinimal
    empCiphertextOnly

  EncryptionPolicy* = object
    mode*: EncryptionMode
    storesPlaintext*: bool
    allowsOperatorPlaintextAccess*: bool
    permitsOperatorEscrow*: bool
    requiresKeyMaterial*: bool
    metadataProfile*: EncryptionMetadataProfile

# Flow: Map one typed encryption mode to a stable runtime policy contract.
proc policyFor*(mode: EncryptionMode): EncryptionPolicy =
  case mode
  of emClear:
    EncryptionPolicy(
      mode: mode,
      storesPlaintext: true,
      allowsOperatorPlaintextAccess: true,
      permitsOperatorEscrow: false,
      requiresKeyMaterial: false,
      metadataProfile: empCleartext
    )
  of emStandard:
    EncryptionPolicy(
      mode: mode,
      storesPlaintext: false,
      allowsOperatorPlaintextAccess: false,
      permitsOperatorEscrow: true,
      requiresKeyMaterial: true,
      metadataProfile: empStructural
    )
  of emPrivate:
    EncryptionPolicy(
      mode: mode,
      storesPlaintext: false,
      allowsOperatorPlaintextAccess: false,
      permitsOperatorEscrow: false,
      requiresKeyMaterial: true,
      metadataProfile: empMinimal
    )
  of emComplete:
    EncryptionPolicy(
      mode: mode,
      storesPlaintext: false,
      allowsOperatorPlaintextAccess: false,
      permitsOperatorEscrow: false,
      requiresKeyMaterial: true,
      metadataProfile: empCiphertextOnly
    )

# Flow: Return true when the selected mode requires encrypted content storage.
proc usesCiphertextStorage*(mode: EncryptionMode): bool =
  not policyFor(mode).storesPlaintext

# Flow: Return true when the selected mode requires content-encryption key material.
proc requiresKeyMaterial*(mode: EncryptionMode): bool =
  policyFor(mode).requiresKeyMaterial

# Flow: Map modes to a stable privacy rank for migration guardrails.
proc privacyRank*(mode: EncryptionMode): int =
  case mode
  of emClear: 0
  of emStandard: 1
  of emPrivate: 2
  of emComplete: 3

# Flow: Return true when the target mode is less private than the source mode.
proc isPrivacyDowngrade*(fromMode: EncryptionMode,
                         toMode: EncryptionMode): bool =
  privacyRank(toMode) < privacyRank(fromMode)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.