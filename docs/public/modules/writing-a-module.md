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

## One Manifest Form

Today, Cosmos-native modules define their contract in code, and external processes use
a handwritten manifest.

The MVP changes this (MVP-INT-5): every Concept, native or external, is declared the
same way, in one `manifest.json`
([interrogative-manifest.md](../concepts/interrogative-manifest.md)). Nim code may
still generate that file, but the file is the declaration. The code-defined path
remains until Phase 3 moves modules over.

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

- Native modules: today, the contract is in code. From Phase 3, a manifest, which code
  may generate.
- External processes: handwritten manifest required.
- Implementations talk only through input, output and error, one JSON message per
  line (MVP-INT-6). In the MVP they're written in Nim, or C where needed.

## Determinism Reminder

Names and registration shape affect deterministic loading. Keep naming clear and stable.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
