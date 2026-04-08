# Wilder Cosmos 0.4.0
# Module name: semantic_scanner_test Tests
# Module Path: tests/unit/semantic_scanner_test.nim
# Summary: Tests for deterministic semantic scanning and relationship inference.
# Simile: Like a site survey, each test validates one inferred relationship from static structure.
# Memory note: scanner tests must remain deterministic and file-order independent.
# Flow: create fixtures -> run scanner -> assert inferred metadata.

import unittest
import std/[os, sequtils, json, strutils]
import harness
import ../../src/runtime/scanner
import ../../src/cosmos/thing/thing

# Flow: Locate one scanned Thing by normalized relative source path.
proc findThingByPath(things: seq[Thing], sourcePath: string): int =
  for i, thing in things:
    if thing.metadata["sourcePath"].getStr == sourcePath:
      return i
  -1

suite "semantic scanner inference":
  test "imports infer needs and after relationships":
    setupTest("scanner_imports")
    defer: teardownTest()

    let aFile = testTmpDir / "a.nim"
    let bFile = testTmpDir / "b.nim"
    writeFile(aFile, "import b\nproc alpha*(): int = 1\n")
    writeFile(bFile, "proc beta*(): int = 2\n")

    let things = scanPath(testTmpDir)
    check things.len == 2
    let idx = findThingByPath(things, "a.nim")
    check idx >= 0
    check things[idx].metadata["needs"].getElems.mapIt(it.getStr).contains("b")
    check things[idx].metadata["after"].getElems.mapIt(it.getStr).contains("b")

  test "annotations and comments infer provides and wants":
    setupTest("scanner_annotations")
    defer: teardownTest()

    let f = testTmpDir / "annotated.nim"
    writeFile(f,
      "## Provides: report.generate\n" &
      "## Wants: lexicons.get\n" &
      "proc report*(): int = 1\n" &
      "# @provides(\"manual.provide\")\n" &
      "# @wants(\"manual.want\")\n")

    let things = scanPath(testTmpDir)
    check things.len == 1
    let provides = things[0].metadata["provides"].getElems.mapIt(it.getStr)
    let wants = things[0].metadata["wants"].getElems.mapIt(it.getStr)
    check provides.contains("report")
    check provides.contains("report.generate")
    check provides.contains("manual.provide")
    check wants.contains("lexicons.get")
    check wants.contains("manual.want")

  test "duplicate provides infer conflicts":
    setupTest("scanner_conflicts")
    defer: teardownTest()

    writeFile(testTmpDir / "a.nim", "proc duplicate*(): int = 1\n")
    writeFile(testTmpDir / "b.nim", "proc duplicate*(): int = 2\n")

    let things = scanPath(testTmpDir)
    let conflicts = findCapabilityConflicts(things)
    check conflicts.len >= 2
    check conflicts.anyIt("duplicate@" in it)

  test "scanner output is deterministic for repeated runs":
    setupTest("scanner_deterministic")
    defer: teardownTest()

    writeFile(testTmpDir / "a.nim", "import b\nproc alpha*(): int = 1\n")
    writeFile(testTmpDir / "b.nim", "proc beta*(): int = 2\n")

    let first = $scanThingsJson(testTmpDir)
    let second = $scanThingsJson(testTmpDir)
    check first == second

  test "invalid root raises":
    expect(ValueError):
      discard scanPath(testTmpDir / "missing")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
