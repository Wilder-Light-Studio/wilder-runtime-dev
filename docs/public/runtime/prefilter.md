# Validating Prefilter

What this is. This page describes the runtime boundary gate that blocks unvalidated ingress from reaching dispatch.

**MVP status:** the checker is built and tested, but it isn't connected yet. Nothing in
the running program calls it, and its table holds one entry. The guarantees below are
the design, not today's behaviour (MVP-VAL-2, MVP-VAL-3). MVP-SPECIFICATION §4D has
the design: Phase 2 connects commands, and Phase 3 connects Things and waves.

## Role

The validating prefilter is activated during startup before ingress opens. It checks target signature identity and payload structure.

## Validation Shape

At high level:

- lookup validation record by signature digest
- validate argument count
- compute payload masks
- compare against precomputed validation masks
- reject on failure and emit validation-failure occurrence

## Guarantees

- unvalidated payload does not reach user code
- unvalidated payload does not become normal domain occurrence
- gate activation is required before ingress

## Practical Picture

Think of prefilter as a keyed mold: only payloads with the expected shape pass through.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
