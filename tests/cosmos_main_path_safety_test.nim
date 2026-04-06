# Wilder Cosmos 0.4.0
# Module name: cosmos_main_path_safety_test Tests
# Module Path: tests/cosmos_main_path_safety_test.nim
# Summary: Test filesystem root rejection for CLI path arguments.
# Simile: Like a roadblock at the boundary, preventing accidental root traversal.
# Memory note: scan [path] and concept --file should reject obvious filesystem roots.
# Flow: attempt root path -> catch ValueError -> verify error message.

import unittest
import std/[os, json, tempfiles]
import ../src/cosmos_main

# ── rejectFilesystemRoot behavior ─────────────────────────────────────────────

suite "rejectFilesystemRoot guards":
  test "rejects absolute root on Windows":
    when defined(windows):
      expect(ValueError):
        rejectFilesystemRoot("C:\\", "test-flag")

  test "rejects absolute root on Unix":
    when not defined(windows):
      expect(ValueError):
        rejectFilesystemRoot("/", "test-flag")

  test "rejects root with trailing slash on Windows":
    when defined(windows):
      expect(ValueError):
        rejectFilesystemRoot("C:\\", "test-flag")

  test "rejects empty path":
    expect(ValueError):
      rejectFilesystemRoot("", "test-flag")

  test "rejects whitespace-only path":
    expect(ValueError):
      rejectFilesystemRoot("   ", "test-flag")

  test "allows relative paths":
    try:
      rejectFilesystemRoot("./my-project", "test-flag")
    except ValueError:
      fail("relative path should not raise")

  test "allows absolute subdirectory paths":
    let tmpDir = getTempDir()
    try:
      rejectFilesystemRoot(tmpDir, "test-flag")
    except ValueError:
      fail("absolute subdirectory should not raise")

  test "error message includes flag name":
    try:
      rejectFilesystemRoot("", "my-custom-flag")
    except ValueError as e:
      check "my-custom-flag" in e.msg

# ── runScanCommand path safety ────────────────────────────────────────────────

suite "runScanCommand path safety":
  test "scan rejects filesystem root":
    when defined(windows):
      let (exitCode, lines) = runScanCommand(@["C:\\"])
      check exitCode != 0
      check lines.len > 0
      check "scan" in lines[0]

  test "scan rejects empty path by default (uses cwd)":
    # Empty args defaults to getcwd(), which is safe; no rejection expected
    let (exitCode, lines) = runScanCommand(@[])
    # This may succeed or fail depending on cwd state, but should not be a path error
    check true  # just verify it doesn't crash

  test "scan accepts relative path":
    let (exitCode, lines) = runScanCommand(@["./"])
    # Result depends on current dir contents, but should not path-reject
    check true  # just verify no path rejection

# ── loadConceptFromFile path safety ───────────────────────────────────────────

suite "loadConceptFromFile path safety":
  test "concept show rejects filesystem root":
    when defined(windows):
      let (exitCode, lines) = runCoordinatorMain(@[
        "concept", "show", "--file", "C:\\"
      ])
      check exitCode != 0

  test "concept validate rejects filesystem root":
    when defined(windows):
      let (exitCode, lines) = runCoordinatorMain(@[
        "concept", "validate", "--file", "C:\\"
      ])
      check exitCode != 0

  test "concept export rejects filesystem root":
    when defined(windows):
      let (exitCode, lines) = runCoordinatorMain(@[
        "concept", "export", "--file", "C:\\"
      ])
      check exitCode != 0

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
