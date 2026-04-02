# Wilder Cosmos 0.4.0
# Module name: test_module
# Module Path: templates/test_module.nim
## test_module.nim
#
## Summary: Test module template for new test suites.
## Simile: Like a blueprint for consistent test structure.
## Memory note: use this template for new test files to maintain style consistency.
## Flow: copy template -> replace placeholders -> add test cases.

# Summary: Nim unittest template with harness integration.
# Simile: Like a reusable fixture rack, it standardizes test startup and teardown.
# Memory note: keep placeholder tests minimal and deterministic.
# Flow: copy template -> replace placeholders -> run through nimble test.

# Test Module Template
# Summary: Nim `unittest` template with harness integration.
# Usage:
#   1. Copy this file into `tests/` and rename it (e.g. `tests/mymodule_test.nim`).
#   2. Replace `<module_name>` with your module name.
#   3. Uncomment the import for the module under test.
#   4. Add suites and tests.
# Run with: nim c -r tests/mymodule_test.nim
#         or: nimble test

import unittest
import std/os  # needed for path operations used by the harness

# Import the shared test harness (provides setupTest, teardownTest, loadJson, writeJson).
import harness

# Import the module under test:
# import ../src/runtime/<module_name>

suite "<module_name> — basic":
  test "placeholder — replace with real assertion":
    check true

suite "<module_name> — with harness":
  test "setup and teardown a temp directory":
    setupTest("<module_name>_example")
    check testTmpDir.len > 0
    teardownTest()
    check testTmpDir.len == 0
# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.