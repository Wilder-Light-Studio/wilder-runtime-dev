# Wilder Cosmos 0.4.0
# Module name: tempo
# Module Path: src/cosmos/tempo/tempo.nim
#
# Summary: Tempo scheduling semantics for Things and Occurrences.
# Simile: Like a clock mode selector — picks the rhythm at which a
#   Thing fires its behavior.
# Memory note: TempoKind is sealed; add variants only in the
#   ontology chapter.
# Flow: define enum -> provide human-readable description helper.
## tempo.nim
## Tempo types stub (Event, Periodic, Continuous, Manual, Sequence)
## Tempo defines scheduling semantics for Things and Occurrences.

type
  TempoKind* = enum
    Event, Periodic, Continuous, Manual, Sequence

# Flow: Provide human-readable description for tempo kind.
proc describeTempo*(t: TempoKind): string =
  ## Human-readable description for tooling and tests.
  result = "tempo: " & $t

## Example:
##   echo describeTempo(Periodic)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
