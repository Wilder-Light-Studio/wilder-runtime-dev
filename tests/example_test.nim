# Wilder Cosmos 0.4.0
# Module name: example_test Tests
# Module Path: tests/example_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## example_test.nim
#
## Summary: Example test demonstrating harness usage and the test template pattern.
## Simile: Like a worked example in a textbook — shows the pattern, produces a
##   result, and is correct enough to learn from.
## Memory note: keep this file minimal; it exists to demonstrate harness import
##   and typical test structure, not to exhaustively cover any module.
## Flow: import harness -> open suite -> setup -> exercise -> teardown.

import unittest
import std/[os, json]
import harness

# ── Harness usage demonstration ───────────────────────────────────────────────

suite "example — harness usage":
  test "setup produces an accessible temp directory":
    setupTest("example_usage")
    check testTmpDir.len > 0
    check dirExists(testTmpDir)
    teardownTest()
    check not dirExists(testTmpDir)

  test "write and retrieve a value from a JSON fixture":
    setupTest("example_fixture")
    let fixture = %*{"runtime": "wilder-cosmos", "ready": true}
    let path = testTmpDir / "fixture.json"
    writeJson(path, fixture)
    let loaded = loadJson(path)
    check loaded["runtime"].getStr() == "wilder-cosmos"
    check loaded["ready"].getBool() == true
    teardownTest()

  test "nested JSON survives a round-trip through the file system":
    setupTest("example_nested")
    let node = %*{
      "meta": {
        "version": 2,
        "author": "wilder"
      },
      "items": [1, 2, 3]
    }
    let path = testTmpDir / "nested.json"
    writeJson(path, node)
    let loaded = loadJson(path)
    check loaded["meta"]["version"].getInt() == 2
    check loaded["items"].len == 3
    teardownTest()

# ── Standalone assertions (no harness) ───────────────────────────────────────

suite "example — standalone checks":
  test "true is true":
    check true

  test "string concatenation":
    let s = "wilder" & "-cosmos"
    check s == "wilder-cosmos"

  test "integer arithmetic":
    check 2 + 2 == 4

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
