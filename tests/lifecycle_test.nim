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
import std/strutils
import ../src/runtime/core

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
  test "missing config file halts startup":
    let lc = freshLc()
    try:
      lc.stepLoadConfig("nonexistent/path/config.json")
      check false
    except StartupError as err:
      check err.haltedAt == lcConfigLoaded
      check err.recoveryGuidance.len > 0

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
    lc.stepOpenIngress()
    check lc.flags.ingressOpen
    check lc.step == lcRunning

# ── full startup / shutdown ───────────────────────────────────────────────────

suite "full startup and shutdown":
  test "startup with no config path raises on missing file":
    let lc = freshLc()
    try:
      startup(lc, "nonexistent/runtime.json")
      check false
    except StartupError as err:
      check err.haltedAt == lcConfigLoaded
      check err.recoveryGuidance.len > 0

  test "shutdown from running state reaches Stopped":
    let lc = configuredLc()
    lc.stepInitPersistence()
    lc.stepLoadEnvelope()
    lc.stepReconcile()
    lc.stepMigrate()
    lc.stepActivatePrefilter()
    lc.stepLoadModules(@[])
    lc.stepInitFrames()
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
