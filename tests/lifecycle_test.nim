# Wilder Cosmos 0.4.0
# Module name: lifecycle_test Tests
# Module Path: tests/lifecycle_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## lifecycle_test.nim
#
## Summary: Chapter 10 runtime lifecycle tests.
## Simile: Like a power-on-self-test for a spacecraft — every gate must
##   pass or the launch is scrubbed.
## Memory note: no module may run before reconciliation; no ingress before
##   prefilter.  Both gates must be explicit and verifiable.
## Flow: build lifecycle handle -> drive each step -> assert state transitions
##   and structured errors.

import unittest
import json
import std/strutils
import ../src/runtime/core
import ../src/runtime/capabilities
import ../src/runtime/config
import ../src/runtime/persistence

# ── helper ──────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic test helper behavior.
proc freshLc(): RuntimeLifecycle = newRuntimeLifecycle()

# Flow: Execute procedure with deterministic test helper behavior.
proc configuredLc(): RuntimeLifecycle =
  result = freshLc()
  result.step = lcConfigLoaded

# ── construction ─────────────────────────────────────────────────────────────

suite "lifecycle construction":
  test "new lifecycle starts in NotStarted state":
    let lc = freshLc()
    check lc.step == lcNotStarted

  test "new lifecycle has no gates open":
    let lc = freshLc()
    check not lc.flags.reconciliationPassed
    check not lc.flags.prefilterActivated
    check not lc.flags.ingressOpen

  test "new lifecycle has no loaded modules":
    let lc = freshLc()
    check lc.loadedModules.len == 0

# ── step 1 — load config ──────────────────────────────────────────────────────

suite "step 1 — load config":
  test "empty config path builds default config":
    let lc = freshLc()
    lc.stepLoadConfig("")
    check lc.step == lcConfigLoaded
    check lc.cfg.endpoint == "localhost"

# ── step 4 — reconciliation gate ─────────────────────────────────────────────

suite "step 4 — reconciliation gate":
  test "reconciliation sets gate flag":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    check lc.flags.reconciliationPassed
    check lc.step == lcReconciled

  test "step advances to Reconciled after success":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    check lc.step == lcReconciled

# ── step 5 — runtime policy migration gate ───────────────────────────────────

suite "step 5 — runtime policy migration gate":
  test "migrate seals configured encryption contract into runtime envelope":
    let lc = configuredLc()
    lc.cfg.encryptionMode = emPrivate
    lc.cfg.recoveryEnabled = false
    lc.cfg.operatorEscrow = false
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()

    lc.stepMigrate()

    let payload = lc.bridge.readEnvelope(RuntimeLayer, "runtime")
    check payload["encryptionMode"].getStr() == "private"
    check not payload["recoveryEnabled"].getBool()
    check not payload["operatorEscrow"].getBool()

  test "migrate halts on stored encryption mode mismatch":
    let lc = configuredLc()
    lc.cfg.encryptionMode = emStandard
    lc.cfg.recoveryEnabled = false
    lc.cfg.operatorEscrow = false
    lc.stepInitPersistence()
    discard beginTransaction(lc.bridge)
    lc.bridge.writeEnvelope(RuntimeLayer, "runtime", %*{
      "status": "ready",
      "encryptionMode": "clear",
      "recoveryEnabled": false,
      "operatorEscrow": false
    })
    discard commit(lc.bridge)
    lc.stepLoadEnvelope()
    lc.stepReconcile()

    try:
      lc.stepMigrate()
      check false
    except StartupError as err:
      check err.haltedAt == lcMigrated
      check "different encryptionMode" in err.recoveryGuidance

# ── step 6 — prefilter gate ───────────────────────────────────────────────────

suite "step 6 — prefilter gate":
  test "prefilter activation sets gate flag":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    check lc.flags.prefilterActivated

  test "prefilter activation records generation ID":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    check lc.prefilterGenerationId.len > 0

  test "step advances to PrefilterActive after success":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    check lc.step == lcPrefilterActive

# ── step 7 — module load order ────────────────────────────────────────────────

suite "step 7 — deterministic module load order":
  test "modules are loaded in lexicographic order":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@["zebra", "alpha", "middle"])
    check lc.loadedModules == @["alpha", "middle", "zebra"]

  test "zero modules is allowed":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    check lc.loadedModules.len == 0

  test "module load before reconciliation halts startup":
    let lc = freshLc()
    # Skip reconciliation — gate not passed.
    expect(StartupError):
      lc.stepLoadModules(@["some-module"])

suite "cosmos bootstrap invariants":
  test "stepInitFrames creates cosmos root and initializes scheduler and capability registry":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()

    check lc.cosmosRootId == "COSMOS"
    check lc.loadedThings.len >= 1
    check lc.loadedThings[0].id == "COSMOS"
    check lc.loadedThings[0].parentId == ""
    check lc.loadedThings[0].isCosmosRoot
    check lc.schedulerInitialized
    check lc.capabilityRegistryInitialized

  test "empty cosmos startup keeps only root thing":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
    lc.stepLoadUserThings(@[])

    var loadedUserThings = 0
    for thing in lc.loadedThings:
      if thing.loadStatus == tlsLoaded and not thing.isCosmosRoot:
        inc loadedUserThings
    check loadedUserThings == 0

  test "user things load as children of cosmos root":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
    lc.stepLoadUserThings(@["fsbridge", "logger"])

    var seenFs = false
    var seenLogger = false
    for thing in lc.loadedThings:
      if thing.id == "fsbridge" and thing.loadStatus == tlsLoaded:
        check thing.parentId == "COSMOS"
        seenFs = true
      if thing.id == "logger" and thing.loadStatus == tlsLoaded:
        check thing.parentId == "COSMOS"
        seenLogger = true
    check seenFs
    check seenLogger

  test "malformed or duplicate thing declarations do not halt startup":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
    lc.stepLoadUserThings(@["", "COSMOS", "worker", "worker"])

    var malformedSeen = false
    var reservedSeen = false
    var duplicateSeen = false
    for thing in lc.loadedThings:
      case thing.loadStatus
      of tlsSkippedMalformed:
        malformedSeen = true
      of tlsSkippedReservedRoot:
        reservedSeen = true
      of tlsSkippedDuplicate:
        duplicateSeen = true
      else:
        discard
    check malformedSeen
    check reservedSeen
    check duplicateSeen

# ── step 9 — ingress gate ─────────────────────────────────────────────────────

suite "step 9 — ingress gate":
  test "ingress blocked if reconciliation not passed":
    let lc = freshLc()
    try:
      lc.stepOpenIngress()
      check false
    except StartupError as err:
      check err.haltedAt == lcRunning
      check err.recoveryGuidance.len > 0

  test "ingress blocked if prefilter not activated":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    # skip prefilter activation
    try:
      lc.stepOpenIngress()
      check false
    except StartupError as err:
      check err.haltedAt == lcRunning
      check err.recoveryGuidance.len > 0

  test "ingress open after both gates pass":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
    lc.stepValidateCapabilities(@[], @[])
    lc.stepOpenIngress()
    check lc.flags.ingressOpen
    check lc.step == lcRunning

suite "capability gate":
  test "capability validation passes with empty declarations":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
    lc.stepValidateCapabilities(@[], @[])
    check lc.step == lcFramesRunning

  test "capability validation halts on missing provider":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
    expect(StartupError):
      lc.stepValidateCapabilities(
        @[],
        @[WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get")]
      )

# ── full startup / shutdown ───────────────────────────────────────────────────

suite "full startup and shutdown":
  test "startup with no config path succeeds with defaults":
    let lc = freshLc()
    startup(lc)
    check lc.step == lcRunning
    check lc.cosmosRootId == "COSMOS"
    check lc.frameLoopStarted

  test "shutdown from running state reaches Stopped":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
    lc.stepValidateCapabilities(@[], @[])
    lc.stepOpenIngress()
    check lc.step == lcRunning
    shutdown(lc)
    check lc.step == lcStopped
    check not lc.flags.ingressOpen

# ── startup banner ────────────────────────────────────────────────────────────

suite "startup banner":
  test "banner accumulates lines after full startup steps":
    let lc = configuredLc()
    lc.bannerLines = @[]
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    check lc.bannerLines.len > 0

  test "banner includes prefilter generation ID":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    var found = false
    for ln in lc.bannerLines:
      if "gen=" in ln:
        found = true
    check found

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
