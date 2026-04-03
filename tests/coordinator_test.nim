# Wilder Cosmos 0.4.0
# Module name: coordinator_test Tests
# Module Path: tests/coordinator_test.nim
# Summary: CLI contract tests for the runtime startup coordinator entrypoint.
# Simile: Like a launch-control verification panel, each case checks one flag or constraint.
# Memory note: keep tests explicit and isolated; use runCoordinatorMain for end-to-end cases.
# Flow: setup fixture -> invoke runCoordinatorMain or parse proc -> assert exit code and output.

import unittest
import std/[strutils, os, sequtils, options]
import harness
import ../src/cosmos_main

# ── parse / resolve helpers ───────────────────────────────────────────────────

suite "coordinator parse and resolve":
  test "watch without explicit console resolves to attach when not daemonizing":
    var opts = parseCoordinatorOptions(@["--config", "/x", "--watch", "./thing"])
    resolveConsoleMode(opts)
    check opts.consoleMode == ccmAttach

  test "watch without explicit console resolves to detach when daemonizing":
    var opts = parseCoordinatorOptions(@["--config", "/x", "--watch", "./thing", "--daemonize"])
    resolveConsoleMode(opts)
    check opts.consoleMode == ccmDetach

  test "explicit console detach is preserved with watch":
    var opts = parseCoordinatorOptions(@["--config", "/x", "--watch", "./thing", "--console", "detach"])
    resolveConsoleMode(opts)
    check opts.consoleMode == ccmDetach
    check opts.consoleModeExplicit

  test "daemonize flag sets daemonize field":
    let opts = parseCoordinatorOptions(@["--config", "/x", "--daemonize"])
    check opts.daemonize

  test "mode dev normalizes to development":
    let opts = parseCoordinatorOptions(@["--config", "/x", "--mode", "dev"])
    check opts.modeOverride == some("development")

  test "mode prod normalizes to production":
    let opts = parseCoordinatorOptions(@["--config", "/x", "--mode", "prod"])
    check opts.modeOverride == some("production")

  test "mode debug passes through":
    let opts = parseCoordinatorOptions(@["--config", "/x", "--mode", "debug"])
    check opts.modeOverride == some("debug")

# ── validation failures ───────────────────────────────────────────────────────

suite "coordinator validation failures":
  test "missing --config exits non-zero and includes usage":
    let (code, lines) = runCoordinatorMain(@[])
    check code != 0
    check lines.anyIt("--config" in it)

  test "unknown flag exits non-zero":
    let (code, lines) = runCoordinatorMain(@["--unknown-flag"])
    check code != 0

  test "bad mode exits non-zero":
    let (code, lines) = runCoordinatorMain(@["--config", "/x", "--mode", "staging"])
    check code != 0

  test "daemonize plus explicit console attach exits non-zero":
    let (code, lines) = runCoordinatorMain(@[
      "--config", "/x", "--daemonize", "--console", "attach"
    ])
    check code != 0

  test "watch plus explicit console detach exits non-zero":
    let (code, lines) = runCoordinatorMain(@[
      "--config", "/x", "--watch", "./thing", "--console", "detach"
    ])
    check code != 0

  test "watch plus daemonize exits non-zero (resolves to detach, then fails)":
    let (code, lines) = runCoordinatorMain(@[
      "--config", "/x", "--watch", "./thing", "--daemonize"
    ])
    check code != 0

  test "bad log-level exits non-zero":
    let (code, lines) = runCoordinatorMain(@["--config", "/x", "--log-level", "verbose"])
    check code != 0

  test "port zero exits non-zero":
    let (code, lines) = runCoordinatorMain(@["--config", "/x", "--port", "0"])
    check code != 0

  test "port over range exits non-zero":
    let (code, lines) = runCoordinatorMain(@["--config", "/x", "--port", "65536"])
    check code != 0

  test "port non-integer exits non-zero":
    let (code, lines) = runCoordinatorMain(@["--config", "/x", "--port", "abc"])
    check code != 0

# ── help sovereign ────────────────────────────────────────────────────────────

suite "coordinator help":
  test "--help exits zero with help text":
    let (code, lines) = runCoordinatorMain(@["--help"])
    check code == 0
    check lines.anyIt("cosmos" in it.toLowerAscii)

  test "-h exits zero":
    let (code, lines) = runCoordinatorMain(@["-h"])
    check code == 0

  test "--help bypasses missing --config (sovereign)":
    let (code, _) = runCoordinatorMain(@["--help"])
    check code == 0

  test "--help bypasses bad --mode value (sovereign)":
    let (code, _) = runCoordinatorMain(@["--help", "--mode", "bad"])
    check code == 0

# ── success path ──────────────────────────────────────────────────────────────

suite "coordinator success path":
  test "valid config exits zero with detach branch":
    setupTest("coordinator_success_detach")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")
    let (code, lines) = runCoordinatorMain(@["--config", configPath])
    check code == 0
    check lines.anyIt("detach" in it)
    teardownTest()

  test "valid config with log-level and port overrides exits zero":
    setupTest("coordinator_success_overrides")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")
    let (code, _) = runCoordinatorMain(@[
      "--config", configPath,
      "--log-level", "debug",
      "--port", "9090"
    ])
    check code == 0
    teardownTest()

  test "valid config with explicit console attach exits zero":
    setupTest("coordinator_success_attach")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")
    let (code, lines) = runCoordinatorMain(@["--config", configPath, "--console", "attach"])
    check code == 0
    check lines.anyIt("attach" in it)
    teardownTest()

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.