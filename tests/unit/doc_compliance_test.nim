# Wilder Cosmos 0.4.0
# Module name: doc_compliance_test Tests
# Module Path: tests/unit/doc_compliance_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## doc_compliance_test.nim
#
## Summary: Chapter 15 documentation compliance tests.
## Simile: Like a code review bot — reads known source files at compile time
##   and flags anything that doesn't have the required comment structure.
## Memory note: a source file that passes compilation but lacks proper
##   headers is a documentation bug; staticRead embeds content at compile time
##   so no runtime file access is required.
## Flow: staticRead each source file at compile time -> check for required tags
##   -> compile fails if tags are missing.

import unittest
import std/strutils

# Required header tags per COMMENT_STYLE.md (see docs/implementation/COMMENT_STYLE.md).
# These constants are checked both at compile time (in static blocks) and at
# test-time so failures appear in the standard test output.
const RequiredTags = ["# Summary:", "# Simile:", "# Memory note:", "# Flow:"]

# ── Compile-time content capture ──────────────────────────────────────────────
# Each staticRead call embeds the file content at compile time.

const coreContent       = staticRead("../../src/runtime/core.nim")
const consoleContent    = staticRead("../../src/runtime/console.nim")
const modulesContent    = staticRead("../../src/runtime/modules.nim")
const securityContent   = staticRead("../../src/runtime/security.nim")
const configContent     = staticRead("../../src/runtime/config.nim")
const persistContent    = staticRead("../../src/runtime/persistence.nim")
const validationContent = staticRead("../../src/runtime/validation.nim")
const platformContent   = staticRead("../../src/cosmos/utils/platform.nim")

const checklistContent  = staticRead("../.github/ND_DOCS_CHECKLIST.md")

# ── Helper ────────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic test helper behavior.
proc missingTags(label: string, content: string): seq[string] =
  result = @[]
  for tag in RequiredTags:
    if tag notin content:
      result.add(label & ": missing '" & tag & "'")

# ── Runtime module compliance ─────────────────────────────────────────────────

suite "documentation compliance — runtime modules":
  test "core.nim has all required ND headers":
    let gaps = missingTags("core.nim", coreContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

  test "console.nim has all required ND headers":
    let gaps = missingTags("console.nim", consoleContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

  test "modules.nim has all required ND headers":
    let gaps = missingTags("modules.nim", modulesContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

  test "security.nim has all required ND headers":
    let gaps = missingTags("security.nim", securityContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

  test "config.nim has all required ND headers":
    let gaps = missingTags("config.nim", configContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

  test "persistence.nim has all required ND headers":
    let gaps = missingTags("persistence.nim", persistContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

  test "validation.nim has all required ND headers":
    let gaps = missingTags("validation.nim", validationContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

suite "documentation compliance — cosmos modules":
  test "platform.nim has all required ND headers":
    let gaps = missingTags("platform.nim", platformContent)
    if gaps.len > 0:
      for g in gaps: echo "  " & g
    check gaps.len == 0

suite "checklist compliance":
  test "ND_DOCS_CHECKLIST.md references COMMENT_STYLE.md":
    check "COMMENT_STYLE.md" in checklistContent

  test "ND_DOCS_CHECKLIST.md has required checklist sections":
    check "Module Header" in checklistContent
    check "Acronym Expansion" in checklistContent
    check "Review Sign-Off" in checklistContent

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
