# Wilder Cosmos 0.4.0
# Module name: cosmos_runtime_module
# Module Path: templates/cosmos_runtime_module.nim
# Summary: Canonical Cosmos Runtime module template.
# Simile: A pre-printed form — fill in the blanks and snap into the registry.
# Memory note: increment schemaVersion and add migration logic when state
#   shape changes; keep memoryCap and resourceBudget explicit.
# Flow: declare metadata -> implement initFn -> call registerModule.
## cosmos_runtime_module.nim (template)
## Canonical module structure for the Wilder Cosmos Runtime.
## Copy this file, rename, and fill in your implementation.

## Example usage (after copying):
##   import runtime/modules, runtime/api
##   # then define your module below and call registerModule(reg, meta, initFn).

import json
import runtime/modules
import runtime/api

# ── Module metadata ───────────────────────────────────────────────────────────

const
  moduleName* = "example"       ## Unique module name (lowercase-dot convention).
  moduleSchemaVersion* = 1      ## Increment when state shape changes.

let exampleMeta* = ModuleMetadata(
  name: moduleName,
  kind: mkLoadable,             ## mkKernel for built-ins, mkLoadable for plugins.
  schemaVersion: moduleSchemaVersion,
  memoryCap: 4 * 1024 * 1024,  ## 4 MiB cap; set to 0 for unlimited.
  resourceBudget: 1000,         ## CPU ticks per frame; 0 for unlimited.
  description: "Example module — replace with your own purpose."
)

# ── Module state ──────────────────────────────────────────────────────────────

type
  ExampleState* = object
    ## Replace with your module's state shape.
    counter*: int
    lastMessage*: string

# ── Init function ─────────────────────────────────────────────────────────────

# Flow: Initialize module defaults into context configuration.
proc initExample*(ctx: var ModuleContext) {.nimcall.} =
  ## Called once at module load.  Set default state here.
  ## Simile: Filling in the form before filing it — defaults first.
  ctx.state.config = %*{
    "counter": 0,
    "lastMessage": ""
  }

# ── Message handler (optional) ────────────────────────────────────────────────

# Flow: Handle incoming message updates and return the resulting state.
proc handleExample*(ctx: var ModuleContext, msg: JsonNode): JsonNode =
  ## Process an incoming message.
  ## Flow: check key -> apply update -> return updated state.
  if msg.hasKey("increment"):
    let inc = msg["increment"].getInt
    let cur = ctx.state.config{"counter"}.getInt
    ctx.state.config["counter"] = %(cur + inc)
    ctx.state.config["lastMessage"] = %"Incremented!"
  result = ctx.state.config

# ── Registration ──────────────────────────────────────────────────────────────
# Flow: Call registerModule at startup to add this module to the registry.
#   reg must be the shared ModuleRegistry created by newModuleRegistry().

# registerModule(reg, exampleMeta, initExample)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
