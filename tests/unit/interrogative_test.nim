# Wilder Cosmos 0.4.0
# Module name: interrogative_test Tests
# Module Path: tests/unit/interrogative_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## interrogative_test.nim
#
## Summary: Unit tests for the Interrogative Manifest (IM) type, validation,
##   optional manifest handling, JSON conversion, and Concept load-time wiring.
##   Covers SPEC §6 and §6.2.
## Simile: Like a boundary check — Concepts may stay minimal, but any
##   manifest that appears must be fully declared.
## Memory note: Concepts validate on WHO + WHY only when no manifest is
##   present. A present manifest must have all ten interrogatives non-empty.
## Flow: test minimal Concept validation -> test manifest completeness ->
##   test specialist constraints -> test JSON conversion -> test Concept
##   load-time behavior.

import unittest
import json
import std/strutils
import ../../src/cosmos/core/manifest
import ../../src/cosmos/thing/thing

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Flow: Execute procedure with deterministic test helper behavior.
proc validManifest(): InterrogativeManifest =
  ## Produce a fully populated valid InterrogativeManifest (IM).
  InterrogativeManifest(
    WHO:      "cosmos.health-monitor",
    WHAT:     "Monitors runtime health metrics each epoch",
    WHY:      "Ensure stability and detect anomalies early",
    WHERE:    "runtime layer",
    WHEN:     "every scheduler epoch",
    HOW:      "polls subsystem status, emits Occurrence on change",
    REQUIRES: @["cosmos.scheduler"],
    WANTS:    @["cosmos.logger"],
    PROVIDES: @["health.status"],
    WITH:     @["cosmos.diagnostics"]
  )

# Flow: Execute procedure with deterministic test helper behavior.
proc specialistManifest(): InterrogativeManifest =
  ## Produce a valid specialist InterrogativeManifest (IM).
  InterrogativeManifest(
    WHO:      "cosmos.json-formatter",
    WHAT:     "Formats structured data as JSON for transport",
    WHY:      "Decouple formatting logic from message dispatch",
    WHERE:    "transport layer",
    WHEN:     "on every outbound message",
    HOW:      "applies deterministic JSON encoding to payload",
    REQUIRES: @["cosmos.serialization"],
    WANTS:    @["cosmos.trace"],
    PROVIDES: @["format.json"],
    WITH:     @["cosmos.dispatch"]
  )

# ===========================================================================
# Suite 1 — Valid manifest passes
# ===========================================================================

suite "validateManifest — valid inputs":
  test "fully populated manifest passes without error":
    validateManifest(validManifest())
    check true

  test "minimal Concept is valid without a manifest":
    let c = createConcept(
      id = "concept-minimal",
      what = %*{},
      why = %*{"description": "purpose is present"},
      how = %*{},
      where = %*{},
      `when` = %*{},
      withSection = %*{},
      manifest = %*{}
    )
    validateConcept(c)
    check true

  test "present JSON manifest with all fields passes Concept validation":
    let c = createConcept(
      id = "concept-manifested",
      what = %*{},
      why = %*{"description": "purpose is present"},
      how = %*{},
      where = %*{},
      `when` = %*{},
      withSection = %*{},
      manifest = manifestToJson(validManifest())
    )
    validateConcept(c)
    check true

suite "validateConcept — minimal requirements":
  test "Concept without WHY is invalid even when manifest is absent":
    let c = createConcept(
      id = "concept-invalid",
      what = %*{},
      why = %*{},
      how = %*{},
      where = %*{},
      `when` = %*{},
      withSection = %*{},
      manifest = %*{}
    )
    expect(ValueError):
      validateConcept(c)

  test "partial JSON manifest is rejected when present":
    let c = createConcept(
      id = "concept-partial-manifest",
      what = %*{},
      why = %*{"description": "purpose is present"},
      how = %*{},
      where = %*{},
      `when` = %*{},
      withSection = %*{},
      manifest = %*{"WHO": "concept-partial-manifest", "WHY": "present"}
    )
    expect(ValueError):
      validateConcept(c)

# ===========================================================================
# Suite 2 — Required manifest fields rejected when empty
# ===========================================================================

suite "validateManifest — empty field rejection":
  test "raises when WHO is empty":
    var m = validManifest()
    m.WHO = ""
    expect(ValueError):
      validateManifest(m)

  test "raises when WHAT is empty":
    var m = validManifest()
    m.WHAT = ""
    expect(ValueError):
      validateManifest(m)

  test "raises when WHY is empty":
    var m = validManifest()
    m.WHY = ""
    expect(ValueError):
      validateManifest(m)

  test "raises when WHERE is empty":
    var m = validManifest()
    m.WHERE = ""
    expect(ValueError):
      validateManifest(m)

  test "raises when WHEN is empty":
    var m = validManifest()
    m.WHEN = ""
    expect(ValueError):
      validateManifest(m)

  test "raises when HOW is empty":
    var m = validManifest()
    m.HOW = ""
    expect(ValueError):
      validateManifest(m)

  test "raises when REQUIRES is empty":
    var m = validManifest()
    m.REQUIRES = @[]
    expect(ValueError):
      validateManifest(m)

  test "raises when WITH is empty":
    var m = validManifest()
    m.WITH     = @[]
    expect(ValueError):
      validateManifest(m)

# ===========================================================================
# Suite 3 — Specialist capability validation (SPEC §6.2)
# ===========================================================================

suite "validateSpecialist — specialist constraints":
  test "fully declared specialist passes":
    validateSpecialist(specialistManifest())
    check true

  test "raises when PROVIDES is empty":
    var m = specialistManifest()
    m.PROVIDES = @[]
    expect(ValueError):
      validateSpecialist(m)

  test "error message names PROVIDES for empty sequence":
    var m = specialistManifest()
    m.PROVIDES = @[]
    try:
      validateSpecialist(m)
      check false
    except ValueError as e:
      check "PROVIDES" in e.msg

  test "raises when REQUIRES is empty":
    var m = specialistManifest()
    m.REQUIRES = @[]
    expect(ValueError):
      validateSpecialist(m)

  test "error message names REQUIRES for empty sequence":
    var m = specialistManifest()
    m.REQUIRES = @[]
    try:
      validateSpecialist(m)
      check false
    except ValueError as e:
      check "REQUIRES" in e.msg

  test "specialist manifest remains subject to full manifest validation":
    var m = specialistManifest()
    m.WANTS = @[]
    expect(ValueError):
      validateSpecialist(m)

# ===========================================================================
# Suite 4 — JSON conversion
# ===========================================================================

suite "manifestToJson — serialization":
  test "produces a JSON object with all ten keys":
    let m = validManifest()
    let j = manifestToJson(m)
    check j.kind == JObject
    for key in ["WHO","WHAT","WHY","WHERE","WHEN","HOW",
                "REQUIRES","WANTS","PROVIDES","WITH"]:
      check j.hasKey(key)

  test "string fields round-trip correctly":
    let m = validManifest()
    let j = manifestToJson(m)
    check j["WHO"].getStr  == m.WHO
    check j["WHAT"].getStr == m.WHAT
    check j["WHY"].getStr  == m.WHY
    check j["WHERE"].getStr == m.WHERE
    check j["WHEN"].getStr  == m.WHEN
    check j["HOW"].getStr   == m.HOW

  test "sequence fields round-trip correctly":
    let m = validManifest()
    let j = manifestToJson(m)
    check j["REQUIRES"].kind == JArray
    check j["REQUIRES"].len  == m.REQUIRES.len
    check j["PROVIDES"][0].getStr == m.PROVIDES[0]

  test "empty sequence fields serialize to empty JSON arrays":
    var m = validManifest()
    m.WANTS = @[]
    m.WITH  = @[]
    let j = manifestToJson(m)
    check j["WANTS"].kind == JArray
    check j["WANTS"].len  == 0
    check j["WITH"].len   == 0

# ===========================================================================
# Suite 5 — Concept load-time wiring (task 5.3)
# ===========================================================================

suite "createConceptWithManifest — load-time validation":
  test "valid manifest creates a Concept successfully":
    let c = createConceptWithManifest(
      id = "concept-manifest-a",
      what = %*{"purpose": "test"},
      why  = %*{"rationale": "unit test"},
      how  = %*{"mechanism": "direct"},
      where = %*{"scope": "local"},
      `when` = %*{"temporal": "always"},
      withSection = %*{},
      m = validManifest()
    )
    check c.id == "concept-manifest-a"

  test "manifest fields are stored in concept.manifest as JSON":
    let m = validManifest()
    let c = createConceptWithManifest(
      id = "concept-manifest-b",
      what = %*{}, why = %*{}, how = %*{},
      where = %*{}, `when` = %*{}, withSection = %*{},
      m = m
    )
    check c.manifest["WHO"].getStr == m.WHO
    check c.manifest["PROVIDES"][0].getStr == m.PROVIDES[0]

  test "invalid manifest blocks Concept creation":
    var m = validManifest()
    m.WHO = ""
    expect(ValueError):
      discard createConceptWithManifest(
        id = "concept-manifest-c",
        what = %*{}, why = %*{}, how = %*{},
        where = %*{}, `when` = %*{}, withSection = %*{},
        m = m
      )

  test "empty HOW blocks Concept creation at load time":
    var m = validManifest()
    m.HOW = ""
    expect(ValueError):
      discard createConceptWithManifest(
        id = "concept-manifest-d",
        what = %*{}, why = %*{}, how = %*{},
        where = %*{}, `when` = %*{}, withSection = %*{},
        m = m
      )

  test "Concept validation still permits manifest absence":
    let c = createConcept(
      id = "concept-no-manifest",
      what = %*{},
      why = %*{"description": "purpose is present"},
      how = %*{},
      where = %*{},
      `when` = %*{},
      withSection = %*{},
      manifest = %*{}
    )
    validateConcept(c)
    check true

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
