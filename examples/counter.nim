# Wilder Cosmos 0.4.0
# Module name: counter
# Module Path: examples/counter.nim
#
# Summary: Counter module â€” minimal example of a loadable Cosmos Runtime module.
# Simile: Like a tally counter at a turnstile â€” one input increments the count;
#   the current total is always readable.
# Memory note: keep state in the ModuleContext config field; never hold module
#   state in a global variable.
# Flow: register module -> initCounter sets default state -> handleCounter
#   increments on "increment" message -> state is returned as JSON.
## counter.nim
## Example counter module â€” demonstrates the module registration pattern.
## Copy this file as a starting point for your own Cosmos Runtime module.

## Example usage:
##   import runtime/modules, runtime/api
##   let reg = newModuleRegistry()
##   registerModule(reg, counterMeta, initCounter)

import json
import ../src/runtime/modules
import ../src/runtime/api

# â”€â”€ Module metadata â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const counterModuleName* = "example.counter"

let counterMeta* = ModuleMetadata(
  name: counterModuleName,
  kind: mkLoadable,
  schemaVersion: 1,
  memoryCap: 1 * 1024 * 1024,  ## 1 MiB cap.
  resourceBudget: 100,          ## 100 ticks per frame.
  description: "Counter module â€” increments a counter on each message."
)

# â”€â”€ Init â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc initCounter*(ctx: var ModuleContext) {.nimcall.} =
  ## Initialise counter state to zero.
  ## Flow: called once at registration -> sets counter to 0.
  ctx.state.config = %*{"counter": 0, "lastMessage": ""}

# â”€â”€ Message handler â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc handleCounter*(ctx: var ModuleContext, msg: JsonNode): JsonNode =
  ## Handle an incoming message.
  ## Flow: check for "increment" key -> add value to counter -> return state.
  if msg.hasKey("increment"):
    let delta = msg["increment"].getInt(1)
    let cur = ctx.state.config{"counter"}.getInt
    ctx.state.config["counter"] = %(cur + delta)
    ctx.state.config["lastMessage"] = %("incremented by " & $delta)
  if msg.hasKey("reset"):
    ctx.state.config["counter"] = %0
    ctx.state.config["lastMessage"] = %"reset"
  result = ctx.state.config

# â”€â”€ Registration helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc registerCounter*(reg: ModuleRegistry) =
  ## Register the counter module with an existing registry.
  ## Flow: call at startup -> module available from first frame.
  registerModule(reg, counterMeta, initCounter)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
