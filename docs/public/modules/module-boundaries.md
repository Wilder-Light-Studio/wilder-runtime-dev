# Module Boundaries

What this is. This page defines practical boundaries between modules and runtime internals.

## Boundary Rules

- Module inputs should be validated at public boundaries.
- Modules should use host bindings instead of reaching into runtime internals.
- Module state updates should follow declared schema and budgets.
- Cross-module interaction should use messaging contracts, not hidden shared memory.

## Repository Boundary

- `src/runtime/` is substrate and lifecycle machinery.
- `src/runtime_modules/` is built-in runtime module surface.
- `src/modules/` is optional userland or extension surface.

## Why It Matters

Boundary discipline keeps startup deterministic and failure diagnosis clear.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
