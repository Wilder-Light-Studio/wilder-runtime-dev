# Wilder Cosmos 0.4.0
# Module name: harness Tests
# Module Path: tests/harness.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## harness.nim
#
## Summary: Shared test harness with setup, teardown, and JSON helpers.
## Simile: Like a test infrastructure providing common utilities for all test suites.
## Memory note: keep harness utilities generic; extend only when needed across multiple tests.
## Flow: provide helpers -> initialize fixtures -> clean up -> report results.

# Test harness — shared helpers for unit tests
# Provides minimal setup/teardown and JSON helper utilities.


import os, json

var testTmpDir*: string = ""

# Flow: Execute procedure with deterministic test helper behavior.
proc setupTest*(name: string) =
  ## Create a per-test temporary directory and expose it via env var
  let base = joinPath("tests", "tmp")
  if not dirExists(base):
    createDir(base)
  let td = joinPath(base, name)
  if dirExists(td):
    # ensure a clean directory
    removeDir(td)
  createDir(td)
  testTmpDir = td

# Flow: Execute procedure with deterministic test helper behavior.
proc teardownTest*() =
  ## Remove the temporary directory created by `setupTest` (best-effort)
  let td = testTmpDir
  if td.len > 0 and dirExists(td):
    try:
      removeDir(td)
    except:
      discard
  testTmpDir = ""

# Flow: Execute procedure with deterministic test helper behavior.
proc loadJson*(path: string): JsonNode =
  ## Convenience: load and parse JSON from a file
  result = parseJson(readFile(path))

# Flow: Execute procedure with deterministic test helper behavior.
proc writeJson*(path: string, node: JsonNode) =
  writeFile(path, node.pretty())


# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
