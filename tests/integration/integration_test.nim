# Wilder Cosmos 0.4.0
# Module name: integration_test Tests
# Module Path: tests/integration/integration_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## integration_test.nim
#
## Summary: End-to-end integration test — full startup sequence through ingress
##   and clean shutdown.
## Simile: Like a ground-to-air systems check before first flight.
## Memory note: uses harness for temp config file; exercises all 9 startup steps
##   and both gate invariants in sequence.
## Flow: write config -> startup() -> assert Running -> shutdown() -> assert Stopped.

import unittest
import std/[os, json, strutils, options]
import harness
import ../../src/runtime/core
import ../../src/runtime/config
import ../../src/runtime/persistence
import ../../src/runtime/observability
import ../../src/runtime/capabilities

# ── Helpers ───────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic test helper behavior.
proc writeDevConfig(dir: string): string =
  ## Write a minimal development config to `dir` and return the path.
  let path = dir / "runtime.json"
  let node = %*{
    "mode": "development",
    "transport": "json",
    "logLevel": "debug",
    "endpoint": "localhost",
    "port": 8080
  }
  writeFile(path, $node)
  result = path

# ── Full startup/shutdown sequence ────────────────────────────────────────────

suite "integration — full startup and shutdown":
  test "startup reaches Running state":
    setupTest("integration_startup")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check lc.step == lcRunning
    teardownTest()

  test "ingress is open after startup":
    setupTest("integration_ingress")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check lc.flags.ingressOpen
    teardownTest()

  test "both gates are passed after startup":
    setupTest("integration_gates")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check lc.flags.reconciliationPassed
    check lc.flags.prefilterActivated
    teardownTest()

  test "shutdown reaches Stopped state":
    setupTest("integration_shutdown")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check lc.step == lcRunning
    shutdown(lc)
    check lc.step == lcStopped
    teardownTest()

  test "ingress is closed after shutdown":
    setupTest("integration_ingress_closed")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    shutdown(lc)
    check not lc.flags.ingressOpen
    teardownTest()

  test "startup with named modules loads them in lexicographic order":
    setupTest("integration_modules")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @["tempo", "archive", "messenger"])
    check lc.loadedModules == @["archive", "messenger", "tempo"]
    teardownTest()

  test "startup produces a non-empty banner":
    setupTest("integration_banner")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check lc.bannerLines.len > 0
    teardownTest()

  test "startup applies config overrides before opening ingress":
    setupTest("integration_config_overrides")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[], @[], RuntimeConfigOverrides(
      mode: some("debug"),
      logLevel: some("warn"),
      port: some(9091)
    ))
    check lc.step == lcRunning
    check lc.cfg.mode == rmDebug
    check lc.cfg.logLevel == llWarn
    check lc.cfg.port == 9091
    check lc.bridge.readEnvelope("runtime", "runtime")["encryptionMode"].getStr() ==
      "standard"
    teardownTest()

  test "startup seals overridden encryption mode into runtime envelope":
    setupTest("integration_encryption_policy_seal")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[], @[], RuntimeConfigOverrides(
      encryptionMode: some("private")
    ))
    let payload = lc.bridge.readEnvelope("runtime", "runtime")
    check payload["encryptionMode"].getStr() == "private"
    teardownTest()

  test "startup loads config exactly once":
    setupTest("integration_single_config_load")
    let cfgPath = writeDevConfig(testTmpDir)
    resetConfigLoadInvocationCount()
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check getConfigLoadInvocationCount() == 1
    teardownTest()

  test "shutdown does not trigger extra config load":
    setupTest("integration_no_config_reload")
    let cfgPath = writeDevConfig(testTmpDir)
    resetConfigLoadInvocationCount()
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    check getConfigLoadInvocationCount() == 1
    shutdown(lc)
    check getConfigLoadInvocationCount() == 1
    teardownTest()

  test "startup and shutdown emit required host events safely":
    setupTest("integration_host_events")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    shutdown(lc)

    check lc.eventSink.countEvents(evStartupStep) == 12
    check lc.eventSink.countEvents(evReconcilePass) == 1
    check lc.eventSink.countEvents(evMigrate) == 1
    check lc.eventSink.countEvents(evPrefilterActivated) == 1
    check lc.eventSink.countEvents(evShutdown) == 1

    for event in lc.eventSink.events:
      check event.message.len > 0
      check cfgPath notin event.message
      check "secret" notin event.message.toLowerAscii
      check "{" notin event.message
      check "}" notin event.message
    teardownTest()

  test "banner contains startup-complete line":
    setupTest("integration_banner_complete")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(lc, cfgPath, @[])
    var found = false
    for ln in lc.bannerLines:
      if "startup complete" in ln:
        found = true
    check found
    teardownTest()

# ── Failure-path invariants ───────────────────────────────────────────────────

suite "integration — failure-path invariants":
  test "missing config file halts startup before any gate":
    let lc = newRuntimeLifecycle()
    try:
      startup(lc, "nonexistent_dir/runtime.json", @[])
      check false
    except StartupError as err:
      check err.haltedAt == lcConfigLoaded
      check err.recoveryGuidance.len > 0
    check not lc.flags.reconciliationPassed
    check not lc.flags.prefilterActivated
    check not lc.flags.ingressOpen

  test "step advances for each step called individually":
    let lc = newRuntimeLifecycle()
    check lc.step == lcNotStarted
    lc.step = lcConfigLoaded
    lc.stepInitPersistence()
    check lc.step == lcPersistenceReady
    lc.stepLoadEnvelope()
    check lc.step == lcEnvelopeLoaded
    lc.stepReconcile()
    check lc.step == lcReconciled
    lc.stepMigrate()
    check lc.step == lcMigrated
    lc.stepActivatePrefilter()
    check lc.step == lcPrefilterActive
    lc.stepLoadModules(@[])
    check lc.step == lcModulesLoaded
    lc.stepInitFrames()
    check lc.step == lcFramesRunning
    lc.stepValidateCapabilities(@[], @[])
    lc.stepOpenIngress()
    check lc.step == lcRunning

  test "startup halts on fatal capability issue before ingress":
    setupTest("integration_capability_halt")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    try:
      startup(
        lc,
        cfgPath,
        @[],
        @[],
        RuntimeConfigOverrides(),
        @[],
        @[WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get")]
      )
      check false
    except StartupError as err:
      check err.haltedAt == lcRunning
    check not lc.flags.ingressOpen
    teardownTest()

  test "startup continues with orphaned capability warnings only":
    setupTest("integration_capability_warning")
    let cfgPath = writeDevConfig(testTmpDir)
    let lc = newRuntimeLifecycle()
    startup(
      lc,
      cfgPath,
      @[],
      @[],
      RuntimeConfigOverrides(),
      @[ProvideDeclaration(thingName: "Telemetry", provideName: "publish", signature: "(json)->bool")],
      @[]
    )
    check lc.step == lcRunning
    check lc.flags.ingressOpen
    teardownTest()

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
