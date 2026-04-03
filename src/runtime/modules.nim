# Wilder Cosmos 0.4.0
# Module name: modules
# Module Path: src/runtime/modules.nim
#
# Summary: Kernel/loadable module registry with deterministic load order.
# Simile: Like a plugin board — kernel slots are fixed at boot; loadable
#   slots snap in after reconciliation in alphabetical order.
# Memory note: registration is static (no dynamic loading); load order is
#   always lexicographic by module name; memory caps are enforced at register.
# Flow: define metadata -> registerModule -> loadModulesInOrder -> execute init.
## modules.nim
## Module system: kernel / loadable distinction, static registration,
## memory cap and resource budget, deterministic load order.

## Example:
##   import runtime/modules
##   let reg = newModuleRegistry()
##   registerModule(reg, ModuleMetadata(name: "core.ping", kind: mkKernel, ...))
##   for m in loadModulesInOrder(reg): echo m.name

import json
import std/[algorithm, tables, sequtils, strutils]
import api
import ../cosmos/core/manifest

# ── Types ─────────────────────────────────────────────────────────────────────

type
  ModuleExecutionKind* = enum
    ## Cosmos-native modules are authored in code and may emit generated manifests.
    ## External processes require handwritten manifests because the runtime cannot introspect them.
    mekCosmosNative
    mekExternalProcess

  ModuleContractSource* = enum
    ## Code-defined contracts are authoritative for Cosmos-native modules.
    ## Handwritten manifests are authoritative for external processes.
    mcsCodeDefined
    mcsHandWrittenManifest

  ModuleTransport* = enum
    mtNone
    mtStdInStdOut
    mtArgumentsOnly

  ModuleKind* = enum
    ## Kernel modules are loaded first and cannot be unloaded.
    ## Loadable modules are sorted lexicographically and loaded after reconcile.
    mkKernel    ## Built-in, always present, loaded before any loadable.
    mkLoadable  ## Optional; loaded in lexicographic order after kernel pass.

  ModuleMetadata* = object
    ## Static descriptor for a module.
    name*: string          ## Unique module name (non-empty, lowercase-dot convention).
    kind*: ModuleKind      ## Kernel or loadable.
    schemaVersion*: int    ## Schema version (must be >= 1).
    memoryCap*: int        ## Maximum memory budget in bytes (0 = unlimited).
    resourceBudget*: int   ## Maximum CPU ticks per frame (0 = unlimited).
    description*: string   ## Human-readable summary.
    executionKind*: ModuleExecutionKind ## Cosmos-native or external process.
    contractSource*: ModuleContractSource ## Code-defined or handwritten manifest.
    contractManifest*: InterrogativeManifest ## Contract surface for this module.
    entryCommand*: string  ## External process command when executionKind is external.
    entryArgs*: seq[string] ## External process arguments.
    transport*: ModuleTransport ## How the runtime communicates with the process.

  ModuleEntry* = object
    ## Registry entry: metadata + the init callback.
    meta*: ModuleMetadata
    initProc*: proc(ctx: var ModuleContext) {.nimcall.}

  ModuleRegistry* = ref object
    ## Central module registry; populated at registration time.
    entries*: Table[string, ModuleEntry]

# ── Constructor ───────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc newModuleRegistry*(): ModuleRegistry =
  ## Create an empty module registry.
  ## Simile: An empty slot panel — ready for modules to snap in.
  result = ModuleRegistry(entries: initTable[string, ModuleEntry]())

# Flow: Attach authoritative code-defined contract metadata for native modules.
proc attachCodeDefinedContract*(meta: var ModuleMetadata,
    manifest: InterrogativeManifest) =
  ## Attach a code-defined contract to a Cosmos-native module.
  meta.executionKind = mekCosmosNative
  meta.contractSource = mcsCodeDefined
  meta.contractManifest = manifest

# Flow: Attach handwritten manifest authority for external process modules.
proc attachExternalManifest*(meta: var ModuleMetadata,
    command: string,
    manifest: InterrogativeManifest,
    args: seq[string] = @[],
    transport: ModuleTransport = mtStdInStdOut) =
  ## Attach a handwritten manifest to an external process wrapper.
  meta.executionKind = mekExternalProcess
  meta.contractSource = mcsHandWrittenManifest
  meta.contractManifest = manifest
  meta.entryCommand = command
  meta.entryArgs = args
  meta.transport = transport

# Flow: Convert authoritative contract manifest to JSON representation.
proc contractManifestJson*(meta: ModuleMetadata): JsonNode =
  ## Generate a JSON manifest view from the authoritative contract in code.
  if not hasMeaningfulManifest(meta.contractManifest):
    return newJNull()
  manifestToJson(meta.contractManifest)

# Flow: Enforce module contract-source and execution-kind consistency.
proc validateModuleContract(meta: ModuleMetadata) =
  ## Enforce contract-authority rules for native modules and external wrappers.
  case meta.executionKind
  of mekCosmosNative:
    if meta.contractSource == mcsHandWrittenManifest:
      raise newException(ValueError,
        "modules: cosmos-native modules must define contracts in code")
    if hasMeaningfulManifest(meta.contractManifest):
      validateManifest(meta.contractManifest)
  of mekExternalProcess:
    if meta.contractSource != mcsHandWrittenManifest:
      raise newException(ValueError,
        "modules: external processes require a handwritten manifest")
    if not hasMeaningfulManifest(meta.contractManifest):
      raise newException(ValueError,
        "modules: external processes require a handwritten manifest")
    validateManifest(meta.contractManifest)
    if meta.entryCommand.strip.len == 0:
      raise newException(ValueError,
        "modules: external process command must not be empty")

# ── Registration ─────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc registerModule*(reg: ModuleRegistry,
                     meta: ModuleMetadata,
                     initProc: proc(ctx: var ModuleContext) {.nimcall.} = nil) =
  ## Register a module in the registry.
  ## Fails fast if name is empty, duplicated, or schemaVersion is invalid.
  ## Simile: Filing a form in the slot board — each name claims exactly one slot.
  if meta.name.strip.len == 0:
    raise newException(ValueError, "modules: module name must not be empty")
  if meta.schemaVersion < 1:
    raise newException(ValueError,
      "modules: schemaVersion must be >= 1 for module '" & meta.name & "'")
  validateModuleContract(meta)
  if reg.entries.hasKey(meta.name):
    raise newException(ValueError,
      "modules: duplicate module name '" & meta.name & "'")
  reg.entries[meta.name] = ModuleEntry(meta: meta, initProc: initProc)

# ── Load order ────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc loadModulesInOrder*(reg: ModuleRegistry): seq[ModuleEntry] =
  ## Return all registered modules in deterministic load order.
  ## Rule: kernel modules first (lexicographic), then loadable (lexicographic).
  ## Simile: Booting firmware before plugins — fixed order, no surprises.
  var kernels: seq[ModuleEntry]
  var loadables: seq[ModuleEntry]
  for _, entry in reg.entries.pairs:
    if entry.meta.kind == mkKernel:
      kernels.add(entry)
    else:
      loadables.add(entry)
  kernels.sort(proc(a, b: ModuleEntry): int = cmp(a.meta.name, b.meta.name))
  loadables.sort(proc(a, b: ModuleEntry): int = cmp(a.meta.name, b.meta.name))
  result = kernels & loadables

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc loadedModuleNames*(reg: ModuleRegistry): seq[string] =
  ## Convenience: return module names in load order.
  result = loadModulesInOrder(reg).mapIt(it.meta.name)

# ── Memory cap enforcement ────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc checkMemoryCap*(meta: ModuleMetadata, usedBytes: int): bool =
  ## Returns true if usedBytes is within the module's memoryCap.
  ## A cap of 0 means unlimited; returns true in that case.
  if meta.memoryCap == 0:
    return true
  usedBytes <= meta.memoryCap

# ── Lookup ────────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc getModule*(reg: ModuleRegistry, name: string): ModuleEntry =
  ## Look up a module by name.  Raises if not found.
  if not reg.entries.hasKey(name):
    raise newException(KeyError, "modules: no module named '" & name & "'")
  reg.entries[name]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc hasModule*(reg: ModuleRegistry, name: string): bool =
  ## Returns true if the module is registered.
  reg.entries.hasKey(name)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
