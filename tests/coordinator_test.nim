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

  test "encryption mode passes through":
    let opts = parseCoordinatorOptions(@["--config", "/x", "--encryption-mode", "complete"])
    check opts.encryptionMode == some("complete")

# ── validation failures ───────────────────────────────────────────────────────

suite "coordinator validation failures":
  test "zero-arg launch shows help and does not start runtime":
    let (code, lines) = runCoordinatorMain(@[])
    check code == 0
    check lines.anyIt("Commands:" in it)
    check not lines.anyIt("runtime started" in it)

  test "start command with no args starts runtime":
    let (code, lines) = runCoordinatorMain(@["start"])
    check code == 0
    check lines.anyIt("runtime started" in it)

  test "unknown flag exits non-zero":
    let (code, _) = runCoordinatorMain(@["--unknown-flag"])
    check code != 0

  test "bad mode exits non-zero":
    let (code, _) = runCoordinatorMain(@["start", "--mode", "staging"])
    check code != 0

  test "bad loglevel exits non-zero":
    let (code, _) = runCoordinatorMain(@["start", "--loglevel", "verbose"])
    check code != 0

  test "unknown start option exits non-zero":
    let (code, _) = runCoordinatorMain(@["start", "--daemonize"])
    check code != 0

  test "reserved command exits non-zero":
    let (code, lines) = runCoordinatorMain(@["inspect"])
    check code != 0
    check lines.anyIt("reserved" in it)

  test "missing value for --with exits non-zero":
    let (code, _) = runCoordinatorMain(@["start", "--with"])
    check code != 0

# ── help sovereign ────────────────────────────────────────────────────────────

suite "coordinator help":
  test "--help exits zero with help text":
    let (code, lines) = runCoordinatorMain(@["--help"])
    check code == 0
    check lines.anyIt("cosmos" in it.toLowerAscii)

  test "-h exits zero":
    let (code, _) = runCoordinatorMain(@["-h"])
    check code == 0

  test "--help bypasses missing --config (sovereign)":
    let (code, _) = runCoordinatorMain(@["--help"])
    check code == 0

  test "--help bypasses bad --mode value (sovereign)":
    let (code, _) = runCoordinatorMain(@["--help", "--mode", "bad"])
    check code == 0

# ── success path ──────────────────────────────────────────────────────────────

suite "coordinator success path":
  test "valid config exits zero via start command":
    setupTest("coordinator_success_detach")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")
    let (code, lines) = runCoordinatorMain(@["start", "--config", configPath])
    check code == 0
    check lines.anyIt("runtime started" in it)
    teardownTest()

  test "start with step mode exits zero":
    setupTest("coordinator_success_overrides")
    let (code, lines) = runCoordinatorMain(@["start", "--mode", "step"])
    check code == 0
    check lines.anyIt("frame mode step" in it)
    teardownTest()

  test "start with --with loads user things":
    setupTest("coordinator_success_attach")
    let thingPath = testTmpDir / "fsbridge.nim"
    writeFile(thingPath, "discard")
    let (code, lines) = runCoordinatorMain(@["start", "--with", thingPath])
    check code == 0
    check lines.anyIt("user things loaded" in it)
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
      "--bind", "Lexicons.get:nim:src/runtime/lexicons.nim:registerLexicons:cap-abi-v1",
      "--want", "Lexicons.get",
      "--expect-signature", "(string)->string"
    ])
    check code == 0
    check lines.anyIt("things: 2" in it)
    check lines.anyIt("providers: 1" in it)
    check lines.anyIt("wants: 1" in it)
    check lines.anyIt("signatures: 1" in it)
    check lines.anyIt("moduleBindings: 1" in it)
    check lines.anyIt("bindings: 1" in it)
    check lines.anyIt("startupEligible: true" in it)
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
      "--provide", "Lexicons.get:(string)->string",
      "--bind", "Lexicons.get:nim:src/runtime/lexicons.nim:registerLexicons:cap-abi-v1"
    ])
    check code == 0
    check lines.anyIt("resolve: ok" in it)
    check lines.anyIt("binding:" in it)
    check lines.anyIt("concepts-derived:" in it)

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

suite "scan subcommand":
  test "scan summary succeeds":
    setupTest("scan_summary")
    defer: teardownTest()
    writeFile(testTmpDir / "a.nim", "proc alpha*(): int = 1\n")
    let (code, lines) = runCoordinatorMain(@["scan", testTmpDir])
    check code == 0
    check lines.anyIt("scan: ok" in it)
    check lines.anyIt("things: 1" in it)

  test "scan json mode returns payload":
    setupTest("scan_json")
    defer: teardownTest()
    writeFile(testTmpDir / "a.nim", "proc alpha*(): int = 1\n")
    let (code, lines) = runCoordinatorMain(@["scan", testTmpDir, "--json"])
    check code == 0
    check lines.len == 1
    check "scan:a.nim" in lines[0]

suite "capability conflicts subcommand":
  test "conflicts command reports conflicts":
    setupTest("scan_conflicts")
    defer: teardownTest()
    writeFile(testTmpDir / "a.nim", "proc duplicate*(): int = 1\n")
    writeFile(testTmpDir / "b.nim", "proc duplicate*(): int = 2\n")
    let (code, lines) = runCoordinatorMain(@["capability", "conflicts", testTmpDir])
    check code == 0
    check lines.anyIt("capability conflicts:" in it)
    check lines.anyIt("duplicate@" in it)

suite "ipc subcommand":
  test "ipc command help includes serve contract":
    let (code, lines) = runCoordinatorMain(@["ipc", "--help"])
    check code == 0
    check lines.anyIt("ipc serve" in it)

  test "ipc endpoint returns validated localhost URI":
    let (code, lines) = runCoordinatorMain(@["ipc", "endpoint", "--port", "7788"])
    check code == 0
    check lines.len == 1
    check lines[0] == "tcp://127.0.0.1:7788"

  test "ipc request pause returns structured success":
    let (code, lines) = runCoordinatorMain(@[
      "ipc", "request", "--id", "req-1", "--method", "pause"
    ])
    check code == 0
    check lines.len >= 1
    check "\"version\": \"ipc-v1\"" in lines[0]
    check "\"paused\": true" in lines[0]

  test "ipc request with subscription emits event line":
    let (code, lines) = runCoordinatorMain(@[
      "ipc", "request",
      "--method", "pause",
      "--subscribe", "runtime.paused"
    ])
    check code == 0
    check lines.len == 2
    check "\"event\": \"runtime.paused\"" in lines[1]

  test "ipc request unknown method returns error exit":
    let (code, lines) = runCoordinatorMain(@[
      "ipc", "request", "--method", "does.not.exist"
    ])
    check code != 0
    check "\"method_not_found\"" in lines[0]

  test "ipc request rejects non-integer tcp port":
    let (code, lines) = runCoordinatorMain(@[
      "ipc", "request", "--method", "inspect", "--tcp", "--port", "nope"
    ])
    check code != 0
    check lines.anyIt("--port must be an integer" in it)

suite "notify subcommand":
  test "notify format emits line oriented output":
    let (code, lines) = runCoordinatorMain(@[
      "notify", "format",
      "--time", "2026-04-05T10:00:00Z",
      "--level", "warn",
      "--component", "reconcile",
      "--message", "drift detected"
    ])
    check code == 0
    check lines.len == 1
    check lines[0] == "[2026-04-05T10:00:00Z] [WARN] [reconcile] drift detected"

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.