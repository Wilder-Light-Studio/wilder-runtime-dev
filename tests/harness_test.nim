# Wilder Cosmos 0.4.0
# Module name: harness_test Tests
# Module Path: tests/harness_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## harness_test.nim
#
## Summary: Tests for the shared test harness — setup, teardown, and JSON helpers.
## Simile: Like testing the test-rig before you trust any result it produces.
## Memory note: harness must stay generic; these tests guard backward compatibility.
## Flow: call setupTest -> verify dir created -> write/read JSON -> call teardownTest
##   -> verify dir removed.

import unittest
import std/[os, json, strutils]
import harness

suite "harness — setupTest / teardownTest":
  test "setupTest creates the temp directory":
    setupTest("harness_setup")
    check testTmpDir.len > 0
    check dirExists(testTmpDir)
    teardownTest()

  test "teardownTest removes the directory":
    setupTest("harness_teardown")
    let td = testTmpDir
    check dirExists(td)
    teardownTest()
    check not dirExists(td)

  test "testTmpDir is reset to empty after teardown":
    setupTest("harness_reset")
    teardownTest()
    check testTmpDir.len == 0

  test "setupTest with the same name gives a clean directory":
    setupTest("harness_clean")
    let td = testTmpDir
    # Place a sentinel file to confirm it is removed on re-setup.
    writeFile(td / "sentinel.txt", "exists")
    teardownTest()
    setupTest("harness_clean")
    check not fileExists(testTmpDir / "sentinel.txt")
    teardownTest()

  test "sequential setups for different names do not conflict":
    setupTest("harness_a")
    let tdA = testTmpDir
    teardownTest()
    setupTest("harness_b")
    let tdB = testTmpDir
    check tdA != tdB
    teardownTest()

suite "harness — JSON helpers":
  test "writeJson creates a file":
    setupTest("harness_json_write")
    let path = testTmpDir / "data.json"
    let node = %*{"key": "value"}
    writeJson(path, node)
    check fileExists(path)
    teardownTest()

  test "loadJson reads the file written by writeJson":
    setupTest("harness_json_roundtrip")
    let path = testTmpDir / "roundtrip.json"
    let node = %*{"name": "wilder", "version": 1}
    writeJson(path, node)
    let loaded = loadJson(path)
    check loaded["name"].getStr() == "wilder"
    check loaded["version"].getInt() == 1
    teardownTest()

  test "loadJson preserves nested objects":
    setupTest("harness_json_nested")
    let path = testTmpDir / "nested.json"
    let node = %*{"outer": {"inner": true}}
    writeJson(path, node)
    let loaded = loadJson(path)
    check loaded["outer"]["inner"].getBool() == true
    teardownTest()

  test "writeJson pretty-prints output (contains newline)":
    setupTest("harness_json_pretty")
    let path = testTmpDir / "pretty.json"
    writeJson(path, %*{"a": 1})
    let raw = readFile(path)
    check "\n" in raw
    teardownTest()

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
