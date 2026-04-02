# Wilder Cosmos 0.4.0
# Module name: wave
# Module Path: src/cosmos/wave/wave.nim
#
# Summary: Wave emission stubs for propagating Occurrences on the
#   runtime bus.
# Simile: Like dropping a pebble in water — a Wave carries an
#   Occurrence outward to all listening Things.
# Memory note: Waves must stay lightweight; payload is a string
#   until typed in a later chapter.
# Flow: define Wave type -> provide emit stub -> expand in
#   delegation chapter.
## wave.nim
## Wave emission and handling stubs.
## Waves represent propagated Occurrences; keep them light-weight.

type
  Wave* = object
    id*: string
    payload*: string

# Flow: Emit a Wave to the runtime bus.
proc emitWave*(w: Wave) =
  ## Emit a Wave to the runtime bus (stub).
  discard

## Example:
##   emitWave(Wave(id: "w1", payload: "hello"))

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
