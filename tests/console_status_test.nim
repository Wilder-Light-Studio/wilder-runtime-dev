# Wilder Cosmos 0.4.0
# Module name: console_status_test Tests
# Module Path: tests/console_status_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

# Comprehensive console subsystem tests — Chapter 11.
## console_status_test.nim
#
## Summary: Console three-layer rendering, 20 commands, attach/detach, and
##   precondition enforcement tests.
## Simile: Like acceptance tests for a full instrument panel.
## Memory note: cover every command; each unattached command must fail cleanly.
## Flow: new session -> attach -> exercise commands -> detach -> verify teardown.

import unittest
import std/[strutils, os, sequtils]

# Import shared test harness (creates/cleans test tmp dirs)
import harness
import ../src/runtime/console
import ../src/console_main

# ── helpers ──────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic test helper behavior.
proc attachedSession(identity = "op", perms: set[ConsolePerm] = {cpRead, cpWrite, cpAdmin}): ConsoleSession =
  result = newConsoleSession()
  discard result.cmdAttach(identity, perms)

# ── three-layer rendering ─────────────────────────────────────────────────────

suite "three-layer rendering":
  test "status bar shows unattached when new":
    let cs = newConsoleSession()
    check "unattached" in cs.renderStatusBar()

  test "status bar shows identity when attached":
    let cs = attachedSession("alice")
    check "alice" in cs.renderStatusBar()

  test "scope line shows / at root":
    let cs = attachedSession()
    check cs.renderScopeLine() == "/"

  test "scope line shows path after cd":
    let cs = attachedSession()
    discard cs.cmdCd("things")
    check cs.renderScopeLine() == "/things"

  test "prompt line includes scope and prompt text":
    let cs = attachedSession()
    let p = cs.renderPromptLine()
    check "/" in p
    check ">" in p

  test "renderAll returns three lines":
    let cs = attachedSession()
    let rendered = cs.renderAll()
    check rendered.splitLines().len == 3

# ── attach / detach ───────────────────────────────────────────────────────────

suite "attach and detach":
  test "attach succeeds with valid identity":
    let cs = newConsoleSession()
    let r = cs.cmdAttach("bob", {cpRead})
    check r.ok
    check cs.attach.attached
    check cs.attach.identity == "bob"

  test "attach with empty identity fails":
    let cs = newConsoleSession()
    let r = cs.cmdAttach("")
    check not r.ok

  test "detach clears session state":
    let cs = attachedSession("bob")
    discard cs.cmdCd("nested")
    discard cs.cmdWatch("thing-a")
    let r = cs.cmdDetach()
    check r.ok
    check not cs.attach.attached
    check cs.currentPath.len == 0
    check not cs.watchState.active
    check cs.renderScopeLine() == "/"

  test "detach from unattached session fails":
    let cs = newConsoleSession()
    let r = cs.cmdDetach()
    check not r.ok

  test "instances returns empty when none registered":
    let cs = attachedSession()
    let r = cs.cmdInstances()
    check r.ok

# ── navigation commands ───────────────────────────────────────────────────────

suite "navigation commands":
  test "ls returns error when unattached":
    let cs = newConsoleSession()
    let r = cs.cmdLs()
    check not r.ok

  test "ls on empty path returns empty indicator":
    let cs = attachedSession()
    let r = cs.cmdLs()
    check r.ok
    check r.lines[0] == "(empty)"

  test "ls lists Thing entries with @ prefix":
    let cs = attachedSession()
    let r = cs.cmdLs(@["@thing-a", "dir/", "file.txt"])
    check r.ok
    check r.lines.len == 3

  test "cd changes scope":
    let cs = attachedSession()
    discard cs.cmdCd("cosmos")
    check cs.currentPath == @["cosmos"]

  test "cd .. moves up":
    let cs = attachedSession()
    discard cs.cmdCd("cosmos")
    discard cs.cmdCd("..")
    check cs.currentPath.len == 0

  test "cd / resets to root":
    let cs = attachedSession()
    discard cs.cmdCd("cosmos")
    discard cs.cmdCd("/")
    check cs.currentPath.len == 0

  test "pwd shows current path":
    let cs = attachedSession()
    discard cs.cmdCd("things")
    let r = cs.cmdPwd()
    check r.ok
    check "/things" in r.lines[0]

  test "pwd requires attached session":
    let cs = newConsoleSession()
    check not cs.cmdPwd().ok

# ── introspection commands ────────────────────────────────────────────────────

suite "introspection commands":
  test "info requires attached session":
    check not newConsoleSession().cmdInfo("x").ok

  test "info returns ok for target":
    let cs = attachedSession()
    check cs.cmdInfo("thing-a").ok

  test "peek requires attached session":
    check not newConsoleSession().cmdPeek("x").ok

  test "peek returns ok for target":
    let cs = attachedSession()
    check cs.cmdPeek("thing-a").ok

  test "watch activates watch state":
    let cs = attachedSession()
    let r = cs.cmdWatch("thing-a")
    check r.ok
    check cs.watchState.active
    check cs.watchState.targetPath == "thing-a"

  test "watch requires attached session":
    check not newConsoleSession().cmdWatch("x").ok

  test "exitWatch deactivates watch state":
    let cs = attachedSession()
    discard cs.cmdWatch("thing-a")
    let r = cs.exitWatch()
    check r.ok
    check not cs.watchState.active

  test "state requires attached session":
    check not newConsoleSession().cmdState("x").ok

  test "state returns ok for target":
    let cs = attachedSession()
    check cs.cmdState("thing-a").ok

# ── delegation commands ───────────────────────────────────────────────────────

suite "delegation introspection":
  test "specialists requires attached session":
    check not newConsoleSession().cmdSpecialists().ok

  test "specialists returns ok when attached":
    check attachedSession().cmdSpecialists().ok

  test "delegations requires attached session":
    check not newConsoleSession().cmdDelegations().ok

  test "delegations returns ok when attached":
    check attachedSession().cmdDelegations().ok

# ── world ledger commands ─────────────────────────────────────────────────────

suite "world ledger introspection":
  test "world requires attached session":
    check not newConsoleSession().cmdWorld().ok

  test "world returns ok when attached":
    check attachedSession().cmdWorld().ok

  test "claims requires attached session":
    check not newConsoleSession().cmdClaims().ok

  test "claims returns ok when attached":
    check attachedSession().cmdClaims().ok

# ── execution commands ────────────────────────────────────────────────────────

suite "execution commands":
  test "run requires attached session":
    check not newConsoleSession().cmdRun("t").ok

  test "run requires write permission":
    let cs = newConsoleSession()
    discard cs.cmdAttach("reader", {cpRead})
    check not cs.cmdRun("t").ok

  test "run succeeds with write permission":
    check attachedSession().cmdRun("t").ok

  test "set requires attached session":
    check not newConsoleSession().cmdSet("t", "f", "v").ok

  test "set requires write permission":
    let cs = newConsoleSession()
    discard cs.cmdAttach("reader", {cpRead})
    check not cs.cmdSet("t", "f", "v").ok

  test "set succeeds with write permission":
    check attachedSession().cmdSet("t", "field", "val").ok

  test "call requires attached session":
    check not newConsoleSession().cmdCall("t", "msg").ok

  test "call requires write permission":
    let cs = newConsoleSession()
    discard cs.cmdAttach("reader", {cpRead})
    check not cs.cmdCall("t", "msg").ok

  test "call succeeds with write permission":
    check attachedSession().cmdCall("t", "ping").ok

# ── ergonomics ────────────────────────────────────────────────────────────────

suite "ergonomics":
  test "help returns lines listing all command groups":
    let cs = attachedSession()
    let r = cs.cmdHelp()
    check r.ok
    check r.lines.len >= 6

  test "clear returns ok":
    let cs = attachedSession()
    check cs.cmdClear().ok

  test "exit detaches and returns goodbye":
    let cs = attachedSession()
    let r = cs.cmdExit()
    check r.ok
    check "goodbye" in r.lines[0]
    check not cs.attach.attached

# ── dispatcher ────────────────────────────────────────────────────────────────

suite "command dispatcher":
  test "dispatches ls":
    let cs = attachedSession()
    check cs.dispatch("ls").ok

  test "dispatches cd":
    let cs = attachedSession()
    let r = cs.dispatch("cd things")
    check r.ok
    check cs.currentPath == @["things"]

  test "dispatches help":
    let cs = attachedSession()
    check cs.dispatch("help").ok

  test "unknown command returns error":
    let cs = attachedSession()
    let r = cs.dispatch("xyzzy")
    check not r.ok
    check "unknown command" in r.lines[0]

  test "empty input returns ok empty line":
    let cs = attachedSession()
    check cs.dispatch("").ok

  test "unattached ls via dispatcher fails":
    let cs = newConsoleSession()
    check not cs.dispatch("ls").ok

# ── placeholder harness compatibility ────────────────────────────────────────

suite "console_status placeholder suite":
  test "placeholder test":
    setupTest("console_status_test")
    check true
    teardownTest()

# ── console cli entrypoint ───────────────────────────────────────────────────

suite "console cli entrypoint":
  test "missing --config exits non-zero and prints usage":
    let (code, lines) = runConsoleMain(@[])
    check code != 0
    check lines.len >= 2
    check "--config" in lines.join(" ")

  test "config + attach launches successfully":
    setupTest("console_main_launch_attach")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    let (code, lines) = runConsoleMain(@[
      "--config", configPath,
      "--attach", "operator-alpha"
    ])
    check code == 0
    check lines.anyIt("attached: operator-alpha" in it)
    teardownTest()

  test "watch requires attach":
    setupTest("console_main_watch_requires_attach")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    let (code, lines) = runConsoleMain(@[
      "--config", configPath,
      "--watch", "/thing/a"
    ])
    check code != 0
    check lines.anyIt("--watch requires --attach" in it)
    teardownTest()

  test "watch starts when attach is present":
    setupTest("console_main_watch_attach")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    let (code, lines) = runConsoleMain(@[
      "--config", configPath,
      "--attach", "operator-beta",
      "--watch", "/thing/b"
    ])
    check code == 0
    check lines.anyIt("watch: active" in it)
    teardownTest()

# ── console cli new flags ─────────────────────────────────────────────────────

suite "console cli help flag":
  test "--help exits zero with help text":
    let (code, lines) = runConsoleMain(@["--help"])
    check code == 0
    check lines.anyIt("console_main" in it or "--config" in it)

  test "-h exits zero":
    let (code, lines) = runConsoleMain(@["-h"])
    check code == 0

  test "--help bypasses missing --config (sovereign)":
    let (code, _) = runConsoleMain(@["--help"])
    check code == 0

suite "console cli log-level flag":
  test "--log-level debug with valid config exits zero":
    setupTest("console_loglevel_accept")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")
    let (code, _) = runConsoleMain(@["--config", configPath, "--log-level", "debug"])
    check code == 0
    teardownTest()

  test "--encryption-mode private with valid config exits zero":
    setupTest("console_encryption_mode_accept")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")
    let (code, _) = runConsoleMain(@["--config", configPath, "--encryption-mode", "private"])
    check code == 0
    teardownTest()

  test "--log-level invalid value exits non-zero":
    let (code, _) = runConsoleMain(@["--config", "/x", "--log-level", "verbose"])
    check code != 0

  test "--encryption-mode invalid value exits non-zero":
    let (code, _) = runConsoleMain(@["--config", "/x", "--encryption-mode", "sealed"])
    check code != 0

suite "console cli port flag":
  test "--port 9090 with valid config exits zero":
    setupTest("console_port_accept")
    let configPath = testTmpDir / "runtime.json"
    writeFile(configPath, """{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")
    let (code, _) = runConsoleMain(@["--config", configPath, "--port", "9090"])
    check code == 0
    teardownTest()

  test "--port non-integer exits non-zero":
    let (code, _) = runConsoleMain(@["--config", "/x", "--port", "abc"])
    check code != 0

  test "--port zero exits non-zero":
    let (code, _) = runConsoleMain(@["--config", "/x", "--port", "0"])
    check code != 0

  test "new flags preserve watch requires attach constraint":
    let (code, lines) = runConsoleMain(@[
      "--config", "/x",
      "--watch", "/thing/a",
      "--log-level", "debug"
    ])
    check code != 0
    check lines.anyIt("--watch requires --attach" in it)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
