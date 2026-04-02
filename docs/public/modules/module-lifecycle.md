# Module Lifecycle

What this is. This page describes where module loading fits in runtime lifecycle.

## Lifecycle Position

Modules load after:

- reconciliation passes
- validating prefilter activates

Modules load in deterministic lexicographic order.

## Kinds

- Kernel modules: loaded first, stronger runtime expectations.
- Loadable modules: loaded after kernel modules in lexicographic order.

## Shutdown Relation

Runtime shutdown includes unloading modules after scheduler stop and snapshot steps.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
