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

suite "startapp subcommand":
  test "startapp generates scaffold files":
    setupTest("startapp_generates_scaffold")
    defer: teardownTest()
    let targetDir = testTmpDir / "demo-app"
    let (code, lines) = runCoordinatorMain(@["startapp", targetDir, "--mode", "dev"])
    check code == 0
    check dirExists(targetDir / "src")
    check fileExists(targetDir / "cosmos.toml")
    check fileExists(targetDir / "build-manifest.json")
    check lines.anyIt("scaffold created" in it)

  test "startapp rejects non-empty target directory":
    setupTest("startapp_rejects_nonempty")
    defer: teardownTest()
    let targetDir = testTmpDir / "occupied-app"
    createDir(targetDir)
    writeFile(targetDir / "sentinel.txt", "occupied")
    let (code, _) = runCoordinatorMain(@["startapp", targetDir])
    check code != 0

suite "capabilities subcommand":
  test "capabilities returns deterministic summary output":
    let (code, lines) = runCoordinatorMain(@[
      "capabilities",
      "--provide", "Lexicons.get:(string)->string",
      "--want", "Lexicons.get",
      "--expect-signature", "(string)->string"
    ])
    check code == 0
    check lines.anyIt("providers: 1" in it)
    check lines.anyIt("wants: 1" in it)
    check lines.anyIt("bindings: 1" in it)
    check lines.anyIt("providers:" in it)
    check lines.anyIt("bindings:" in it)
    check lines.anyIt("issues:" in it)

  test "capabilities help exits zero":
    let (code, lines) = runCoordinatorMain(@["capabilities", "--help"])
    check code == 0
    check lines.anyIt("Usage: cosmos capabilities" in it)

  test "capabilities rejects unknown args":
    let (code, lines) = runCoordinatorMain(@["capabilities", "--bad"])
    check code != 0
    check lines.anyIt("unknown argument" in it)

suite "concept resolve subcommand":
  test "concept resolve returns mapping for resolved want":
    let (code, lines) = runCoordinatorMain(@[
      "concept", "resolve",
      "--want", "Lexicons.get",
      "--expect-signature", "(string)->string",
      "--provide", "Lexicons.get:(string)->string"
    ])
    check code == 0
    check lines.anyIt("resolve: ok" in it)
    check lines.anyIt("binding:" in it)

  test "concept resolve fails on unresolved mapping":
    let (code, lines) = runCoordinatorMain(@[
      "concept", "resolve",
      "--want", "Lexicons.get"
    ])
    check code != 0
    check lines.anyIt("unresolved" in it)

  test "concept resolve help exits zero":
    let (code, lines) = runCoordinatorMain(@[
      "concept", "resolve", "--help"
    ])
    check code == 0
    check lines.anyIt("Usage: cosmos concept resolve" in it)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.