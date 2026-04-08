# Wilder Cosmos 0.4.0
# Module name: portability_test Tests
# Module Path: tests/unit/portability_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## portability_test.nim
#
## Summary: Chapter 13 portability layer tests.
## Simile: Like plugging the adapter into each socket type — verify it
##   fits and conducts correctly without modification.
## Memory note: all tests use only portability-layer procs; no raw os.* calls.
## Flow: call each platform proc -> verify result type and basic behavior.

import unittest
import std/strutils
import ../../src/cosmos/utils/platform

suite "path abstractions":
  test "platformJoinPath joins two segments":
    let p = platformJoinPath("tests", "tmp")
    check p.len > 0
    check "tests" in p
    check "tmp" in p

  test "platformJoinPath joins three segments":
    let p = platformJoinPath("a", "b", "c")
    check "a" in p
    check "b" in p
    check "c" in p

  test "platformDirSep returns slash or backslash":
    let sep = platformDirSep()
    check sep == '/' or sep == '\\'

  test "platformFileExists returns false for non-existent file":
    check not platformFileExists("no_such_file_xyzzy_12345.txt")

  test "platformDirExists returns false for non-existent dir":
    check not platformDirExists("no_such_dir_xyzzy_12345")

  test "platformGetCwd returns non-empty string":
    check platformGetCwd().len > 0

  test "platformNormalizePath returns non-empty for valid path":
    let n = platformNormalizePath("a/b/../c")
    check n.len > 0

  test "legacy joinPath alias works":
    let p = joinPath("x", "y")
    check "x" in p
    check "y" in p

suite "time abstractions":
  test "platformGetEpochSeconds returns positive value":
    check platformGetEpochSeconds() > 0

  test "platformGetMonotonicMs returns non-negative value":
    check platformGetMonotonicMs() >= 0

  test "two monotonic readings are non-decreasing":
    let t1 = platformGetMonotonicMs()
    let t2 = platformGetMonotonicMs()
    check t2 >= t1

suite "environment abstractions":
  test "platformGetEnv returns default for unset variable":
    let v = platformGetEnv("WILDER_COSMOS_NOT_SET_XYZ", "default-val")
    check v == "default-val"

  test "platformIsEnvSet returns false for unset variable":
    check not platformIsEnvSet("WILDER_COSMOS_NOT_SET_XYZ")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
