# Wilder Cosmos 0.4.0
# Module name: concept_registry_test Tests
# Module Path: tests/concept_registry_test.nim
# Summary: Tests for effective Concept resolution and ABI export.
# Simile: Like a contract arbitration panel, the registry must pick the right source every time.
# Memory note: programmatic Concepts always win over manual Concepts for the same identity.
# Flow: create concepts -> register sources -> resolve effective concept -> assert exported ABI.

import unittest
import json
import ../src/runtime/concepts
import ../src/cosmos/thing/thing

# Flow: Build canonical Concept fixtures for registry tests.
proc makeConcept(id: string, whyText: string): Concept =
  createConcept(
    id,
    %*{"description": "what"},
    %*{"description": whyText},
    %*{"description": "how"},
    %*{"description": "where"},
    %*{"description": "when"},
    %*{"description": "with"},
    %*{}
  )

suite "concept registry effective source":
  test "programmatic concept overrides manual concept":
    let reg = newConceptRegistry()
    registerManualConcept(reg, makeConcept("alpha", "manual fallback"))
    registerProgrammaticConcept(reg, makeConcept("alpha", "derived contract"))
    let effective = resolveEffectiveConcept(reg, "alpha")
    check effective.sourceKind == cskProgrammatic
    check hasConflict(reg, "alpha")

  test "manual concept is effective when no programmatic source exists":
    let reg = newConceptRegistry()
    registerManualConcept(reg, makeConcept("beta", "manual only"))
    let effective = resolveEffectiveConcept(reg, "beta")
    check effective.sourceKind == cskManual

  test "duplicate source kind is rejected":
    let reg = newConceptRegistry()
    registerManualConcept(reg, makeConcept("gamma", "first"))
    expect(ValueError):
      registerManualConcept(reg, makeConcept("gamma", "second"))

suite "concept registry export":
  test "exported abi includes source kind and checksum":
    let reg = newConceptRegistry()
    registerProgrammaticConcept(reg, makeConcept("delta", "derived"), derivedFrom = "module.delta")
    let exported = exportEffectiveConcept(reg, "delta")
    check exported["abiVersion"].getStr == ConceptAbiVersion
    check exported["sourceKind"].getStr == "programmatic"
    check exported["checksumSha256"].getStr.len > 0
    check exported["derivedFrom"].getStr == "module.delta"

  test "registry record reports both source flags":
    let reg = newConceptRegistry()
    registerManualConcept(reg, makeConcept("epsilon", "manual"))
    registerProgrammaticConcept(reg, makeConcept("epsilon", "programmatic"))
    let record = conceptRegistryRecord(reg, "epsilon")
    check record["hasProgrammatic"].getBool
    check record["hasManual"].getBool
    check record["effectiveSourceKind"].getStr == "programmatic"

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.