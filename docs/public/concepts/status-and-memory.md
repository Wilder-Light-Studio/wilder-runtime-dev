# Status And Memory Model

What this is. This page describes status schema expectations and memory categories used by the runtime model.

## Status Model

Status is schema-driven and versioned.

A status field includes:

- name
- field type
- required flag
- default value
- optional invariant

Invariant checks occur:

- at load
- after mutation
- during reconciliation

## Memory Categories

- State memory: persisted status.
- Perception memory: bounded FIFO queue.
- Temporal memory: frame and epoch counters.
- Module memory: soft cap (default noted in spec as 1 MB).

## Enforcement

Memory constraints are checked during mutation and violations produce structured errors.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
