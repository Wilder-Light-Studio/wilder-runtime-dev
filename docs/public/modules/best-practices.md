# Module Best Practices

What this is. This page lists practical habits for module code that behaves predictably under runtime constraints.

## Recommended Practices

- Keep module names stable and explicit.
- Validate external inputs at boundaries.
- Keep side effects narrow and observable.
- Respect memory cap and resource budget metadata.
- Prefer deterministic data shapes and ordering.
- Write tests that cover both valid and invalid payloads.

## Documentation Practices

- Explain module intent in one sentence.
- Record assumptions in comments and tests.
- Keep examples small and executable.

## Anti-Patterns

- hidden cross-module state sharing
- dynamic behavior that bypasses startup gates
- schema version jumps without migration plan

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
