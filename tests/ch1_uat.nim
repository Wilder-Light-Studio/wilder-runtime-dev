# Wilder Cosmos 0.4.0
# Module name: ch1_uat Tests
# Module Path: tests/ch1_uat.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## ch1_uat.nim
#
## Summary: Chapter 1 User Acceptance Test verifying scaffold structure.
## Simile: Like a checklist ensuring all foundational pieces are present.
## Memory note: Chapter 1 UAT validates project layout; keep in sync with init.
## Flow: verify files -> check directories -> report status.

# Chapter 1 — User Acceptance Test
# Verifies the Chapter 1 scaffold and required files/directories exist.

import os, unittest

let requiredFiles = @[
  "config.nims",
  "wilder_cosmos_runtime.nimble",
  "templates/test_module.nim",
  "tests/harness.nim",
  "src/runtime/core.nim",
  "src/runtime/serialization.nim",
  "src/runtime/testing.nim",
  "src/runtime/api.nim",
  "src/runtime/console.nim",
  "src/runtime/persistence.nim",
  "src/cosmos/core/manifest.nim",
  "src/cosmos/thing/thing.nim",
  "src/cosmos/wave/wave.nim",
  "src/cosmos/tempo/tempo.nim",
  "src/cosmos/utils/platform.nim"
]

suite "Chapter 1 UAT":
  test "required files and dirs exist":
    for f in requiredFiles:
      check fileExists(f) or dirExists(f)

  test "src runtime directory present":
    check dirExists("src/runtime")

  test "src cosmos directory present":
    check dirExists("src/cosmos")

  test "templates directory present":
    check dirExists("templates")

  test "tests harness available":
    check fileExists("tests/harness.nim")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
