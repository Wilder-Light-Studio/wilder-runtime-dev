# Wilder Cosmos 0.4.0
# Module name: module_test Tests
# Module Path: tests/unit/module_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## module_test.nim
#
## Summary: Chapter 12 module system tests — registration, load order, metadata.
## Simile: Like a hardware test for a slot board — each module slot snaps in
##   cleanly, and the boot order is always the same.
## Memory note: kernel modules load before loadable; both groups sorted
##   lexicographically within their tier.
## Flow: create registry -> register modules -> verify order and metadata.

import unittest
import json
import std/tables
import ../../src/runtime/modules
import ../../src/runtime/api
import ../../src/cosmos/core/manifest

# ── helpers ──────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic test helper behavior.
proc noInit(ctx: var ModuleContext) {.nimcall.} = discard

# Flow: Execute procedure with deterministic test helper behavior.
proc kernelMeta(name: string): ModuleMetadata =
  ModuleMetadata(name: name, kind: mkKernel, schemaVersion: 1,
                 memoryCap: 0, resourceBudget: 0, description: "kernel " & name)

# Flow: Execute procedure with deterministic test helper behavior.
proc loadableMeta(name: string, cap: int = 0): ModuleMetadata =
  ModuleMetadata(name: name, kind: mkLoadable, schemaVersion: 1,
                 memoryCap: cap, resourceBudget: 0, description: "loadable " & name)

# Flow: Build a deterministic valid contract manifest for module tests.
proc validContract(who: string): InterrogativeManifest =
  InterrogativeManifest(
    WHO: who,
    WHAT: "Deterministic module contract",
    WHY: "Describe module behavior without drift",
    WHERE: "runtime registry",
    WHEN: "startup",
    HOW: "declared in code",
    REQUIRES: @["runtime.core"],
    WANTS: @["runtime.logs"],
    PROVIDES: @[who & ".capability"],
    WITH: @["runtime.host"]
  )

# ── registration ─────────────────────────────────────────────────────────────

suite "module registration":
  test "new registry is empty":
    let reg = newModuleRegistry()
    check reg.entries.len == 0

  test "registerModule adds a module":
    let reg = newModuleRegistry()
    registerModule(reg, loadableMeta("alpha"))
    check reg.hasModule("alpha")

  test "duplicate name raises ValueError":
    let reg = newModuleRegistry()
    registerModule(reg, loadableMeta("alpha"))
    expect(ValueError):
      registerModule(reg, loadableMeta("alpha"))

  test "empty name raises ValueError":
    let reg = newModuleRegistry()
    expect(ValueError):
      registerModule(reg, ModuleMetadata(name: "", kind: mkLoadable, schemaVersion: 1))

  test "schemaVersion below 1 raises ValueError":
    let reg = newModuleRegistry()
    expect(ValueError):
      registerModule(reg, ModuleMetadata(name: "bad", kind: mkLoadable, schemaVersion: 0))

  test "module with initProc is stored":
    let reg = newModuleRegistry()
    registerModule(reg, loadableMeta("with-init"), noInit)
    check reg.getModule("with-init").initProc != nil

  test "cosmos-native module can attach a code-defined contract":
    let reg = newModuleRegistry()
    var meta = loadableMeta("native-contract")
    attachCodeDefinedContract(meta, validContract("native.contract"))
    registerModule(reg, meta)
    check reg.getModule("native-contract").meta.contractSource == mcsCodeDefined

  test "cosmos-native module rejects handwritten manifest authority":
    let reg = newModuleRegistry()
    var meta = loadableMeta("native-invalid")
    meta.contractSource = mcsHandWrittenManifest
    meta.contractManifest = validContract("native.invalid")
    expect(ValueError):
      registerModule(reg, meta)

  test "external process requires handwritten manifest and command":
    let reg = newModuleRegistry()
    var meta = loadableMeta("external-worker")
    attachExternalManifest(meta, "python", validContract("external.worker"),
      args = @["worker.py"], transport = mtStdInStdOut)
    registerModule(reg, meta)
    check reg.getModule("external-worker").meta.executionKind == mekExternalProcess
    check reg.getModule("external-worker").meta.contractSource == mcsHandWrittenManifest

  test "external process without handwritten manifest is rejected":
    let reg = newModuleRegistry()
    var meta = loadableMeta("external-missing")
    meta.executionKind = mekExternalProcess
    meta.contractSource = mcsCodeDefined
    meta.entryCommand = "python"
    expect(ValueError):
      registerModule(reg, meta)

# ── load order ────────────────────────────────────────────────────────────────

suite "deterministic load order":
  test "kernel modules load before loadable modules":
    let reg = newModuleRegistry()
    registerModule(reg, loadableMeta("z-plugin"))
    registerModule(reg, kernelMeta("a-kernel"))
    let ordered = loadModulesInOrder(reg)
    check ordered[0].meta.kind == mkKernel
    check ordered[1].meta.kind == mkLoadable

  test "within kernel tier: lexicographic order":
    let reg = newModuleRegistry()
    registerModule(reg, kernelMeta("z-core"))
    registerModule(reg, kernelMeta("a-core"))
    registerModule(reg, kernelMeta("m-core"))
    let names = loadedModuleNames(reg)
    check names == @["a-core", "m-core", "z-core"]

  test "within loadable tier: lexicographic order":
    let reg = newModuleRegistry()
    registerModule(reg, loadableMeta("zebra"))
    registerModule(reg, loadableMeta("alpha"))
    registerModule(reg, loadableMeta("middle"))
    let names = loadedModuleNames(reg)
    check names == @["alpha", "middle", "zebra"]

  test "mixed: kernels first, both tiers alphabetical":
    let reg = newModuleRegistry()
    registerModule(reg, loadableMeta("plugin-b"))
    registerModule(reg, kernelMeta("kern-b"))
    registerModule(reg, loadableMeta("plugin-a"))
    registerModule(reg, kernelMeta("kern-a"))
    let names = loadedModuleNames(reg)
    check names == @["kern-a", "kern-b", "plugin-a", "plugin-b"]

  test "empty registry returns empty load order":
    let reg = newModuleRegistry()
    check loadModulesInOrder(reg).len == 0

# ── memory cap ────────────────────────────────────────────────────────────────

suite "memory cap enforcement":
  test "usage within cap returns true":
    let meta = loadableMeta("capped", cap = 1024)
    check checkMemoryCap(meta, 512)

  test "usage at cap returns true":
    let meta = loadableMeta("capped", cap = 1024)
    check checkMemoryCap(meta, 1024)

  test "usage over cap returns false":
    let meta = loadableMeta("capped", cap = 1024)
    check not checkMemoryCap(meta, 2048)

  test "zero cap means unlimited":
    let meta = loadableMeta("unlimited", cap = 0)
    check checkMemoryCap(meta, high(int))

# ── metadata fields ───────────────────────────────────────────────────────────

suite "module metadata":
  test "kernel kind is stored correctly":
    let reg = newModuleRegistry()
    registerModule(reg, kernelMeta("k"))
    check reg.getModule("k").meta.kind == mkKernel

  test "loadable kind is stored correctly":
    let reg = newModuleRegistry()
    registerModule(reg, loadableMeta("l"))
    check reg.getModule("l").meta.kind == mkLoadable

  test "schemaVersion is stored":
    let reg = newModuleRegistry()
    registerModule(reg, ModuleMetadata(name: "v2", kind: mkLoadable,
                                       schemaVersion: 3, memoryCap: 0,
                                       resourceBudget: 0))
    check reg.getModule("v2").meta.schemaVersion == 3

  test "resourceBudget is stored":
    let reg = newModuleRegistry()
    registerModule(reg, ModuleMetadata(name: "budgeted", kind: mkLoadable,
                                       schemaVersion: 1, memoryCap: 0,
                                       resourceBudget: 500))
    check reg.getModule("budgeted").meta.resourceBudget == 500

  test "code-defined contracts generate JSON manifests":
    var meta = loadableMeta("json-contract")
    attachCodeDefinedContract(meta, validContract("json.contract"))
    let manifest = contractManifestJson(meta)
    check manifest["WHO"].getStr == "json.contract"
    check manifest["PROVIDES"][0].getStr == "json.contract.capability"

  test "getModule raises on missing module":
    let reg = newModuleRegistry()
    expect(KeyError):
      discard reg.getModule("not-there")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
