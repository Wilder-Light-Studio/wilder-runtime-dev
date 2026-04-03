# Wilder Cosmos 0.4.0
# Module name: runtime_home_test Tests
# Module Path: tests/runtime_home_test.nim
# Summary: Tests for runtime-home resolution and canonical tree creation.
# Simile: Like checking a site blueprint, each test confirms the runtime puts the right folders in the right place.
# Memory note: keep OS-path assertions normalized so tests stay deterministic on Windows hosts.
# Flow: resolve root -> ensure tree -> assert required directories and ownership rules.

import unittest
import std/[os, strutils]
import harness
import ../src/runtime/home

proc normalizePath(path: string): string =
  path.replace('\\', '/').replace("//", "/")

suite "runtime home resolution":
  test "windows user root uses canonical sandbox mapping":
    let root = resolveRuntimeHomeRoot(imUser, "windows", "sandbox")
    check normalizePath(root) == "sandbox/UserProfile/.wilder/cosmos"

  test "linux system root uses canonical sandbox mapping":
    let root = resolveRuntimeHomeRoot(imSystem, "linux", "sandbox")
    check normalizePath(root) == "sandbox/var/lib/wilder/cosmos"

  test "ownership rules match phase x contract":
    check runtimeHomeOwnership("config") == rhoUserEditable
    check runtimeHomeOwnership("registry") == rhoToolOwned
    check runtimeHomeOwnership("projects") == rhoOptionalProjects
    check runtimeHomeOwnership("bin") == rhoRuntimeTools

suite "runtime home tree creation":
  test "ensureRuntimeHomeTree creates all required directories":
    setupTest("runtime_home_tree")
    defer: teardownTest()
    let root = testTmpDir / ".wilder" / "cosmos"
    createDir(testTmpDir / ".wilder")
    ensureRuntimeHomeTree(root)
    for dirName in RuntimeHomeDirs:
      check dirExists(root / dirName)

  test "runtimeHomePath rejects empty child":
    expect(ValueError):
      discard runtimeHomePath("root", "")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.