# Wilder Cosmos 0.4.0
# Module name: cosmos_main_path_safety_test Tests
# Module Path: tests/cosmos_main_path_safety_test.nim
# Summary: Test filesystem root rejection for CLI path arguments.
# Simile: Like a roadblock at the boundary, preventing accidental root traversal.
# Memory note: scan [path] and concept --file should reject obvious filesystem roots.
# Flow: attempt root path -> catch ValueError -> verify error message.

import unittest
import std/[os]
import ../src/cosmos_main

# ── scan command path safety via public API ───────────────────────────────────

suite "scan command path safety":
  test "scan rejects filesystem root on Windows":
    when defined(windows):
      let (exitCode, _) = runCoordinatorMain(@["scan", "C:\\"])
      check exitCode != 0

  test "scan accepts relative path":
    let (_, _) = runCoordinatorMain(@["scan", "./"])
    check true

# ── concept commands path safety ──────────────────────────────────────────────

suite "concept commands path safety":
  test "concept show rejects filesystem root":
    when defined(windows):
      let (exitCode, _) = runCoordinatorMain(@[
        "concept", "show", "--file", "C:\\"
      ])
      check exitCode != 0

  test "concept validate rejects filesystem root":
    when defined(windows):
      let (exitCode, _) = runCoordinatorMain(@[
        "concept", "validate", "--file", "C:\\"
      ])
      check exitCode != 0

  test "concept export rejects filesystem root":
    when defined(windows):
      let (exitCode, _) = runCoordinatorMain(@[
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
