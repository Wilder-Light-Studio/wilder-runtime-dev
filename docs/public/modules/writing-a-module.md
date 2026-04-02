# Writing A Module

What this is. This page provides a minimal authoring pattern for module code and registration.

## Placement Decision

- Use `src/runtime_modules/` for built-in runtime behavior.
- Use `src/modules/` for optional or replaceable behavior.

## Authoring Steps

1. Start from a project template.
2. Define module metadata (name, kind, schema version, budgets).
3. Define the contract source.
4. Implement initialization behavior.
5. Register with the module registry.
6. Add tests under `tests/`.

## Single Source Of Truth: Code-Defined Contracts

Cosmos-native modules define their contract in code.

- The code contract is authoritative.
- Any manifest for a native module is generated from that code contract.
- Native modules should not depend on hand-maintained manifest files.

This preserves the MVP guarantee that native module behavior and declared contract do not drift apart.

## Wrapping External Processes With Hand-Written Manifests

External processes cannot be introspected by the runtime. That includes:

- long-running resident processes
- stdin/stdout tools
- pipes and filters
- scripts and binaries
- AI models or adapters

These integrations should be wrapped as Things using handwritten manifests.

- The handwritten manifest is authoritative for the external wrapper.
- This is required for interoperability and is not considered drift.
- The runtime should treat stdin/stdout wrappers as first-class external Things.

## Manifest Guidance

- Native modules: manifest optional at authoring time and generated from code when needed.
- External processes: handwritten manifest required.

## Determinism Reminder

Names and registration shape affect deterministic loading. Keep naming clear and stable.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
