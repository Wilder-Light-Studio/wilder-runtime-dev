# Scheduler And Tempo

What this is. This page describes how time and execution cadence are modeled.

## Tempo Types

The specified tempo types are:

- Event
- Periodic
- Continuous
- Manual
- Sequence

## Scheduler Invariants

- deterministic ordering
- bounded execution
- cooperative yielding

## Frame Semantics

- each frame is an immutable snapshot
- all Occurrences in a frame share the same epoch
- replay should reconstruct identical world state for identical inputs

A simple metaphor is a film reel: each frame is fixed once exposed, and playback order matters.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
