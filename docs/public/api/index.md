# API Reference

This section documents the public types, procedures, and constants exported by each Wilder Cosmos Runtime module. All signatures are taken from the source of truth in `src/runtime/`.

## Sections

| Page | Covers |
|------|--------|
| [core.md](core.md) | Lifecycle, startup sequence, shutdown |
| [api.md](api.md) | Public contract types, host bindings, module context |
| [config.md](config.md) | Configuration loading, modes, overrides |
| [persistence.md](persistence.md) | Three-layer bridge, transactions, snapshots |
| [serialization.md](serialization.md) | Envelope wrapping, checksums, serializer abstraction |
| [messaging.md](messaging.md) | Message envelope dispatch |
| [modules.md](modules.md) | Module registry, lifecycle, load order |
| [capabilities.md](capabilities.md) | Capability resolver, provides/wants, binding graph |
| [concepts.md](concepts.md) | Concept registry with source resolution |
| [ontology.md](ontology.md) | Scope, context, override, and reference resolution |
| [validation.md](validation.md) | Prefilter, bitmask validation, input checks |
| [security.md](security.md) | Instance boundaries, channel isolation |
| [encryption.md](encryption.md) | Encrypted RECORD entries, encryption modes and policy |
| [observability.md](observability.md) | Structured host event sink |
| [console.md](console.md) | Three-layer console, commands, attach/detach |
| [coordinator-ipc.md](coordinator-ipc.md) | IPC request/response over JSON-lines TCP |
| [scanner.md](scanner.md) | Semantic source scanner |
| [home.md](home.md) | Runtime-home path resolution |
| [startapp.md](startapp.md) | Application scaffold generation |
| [record-reconciliation.md](record-reconciliation.md) | Metadata-only RECORD copy reconciliation |
| [testing.md](testing.md) | Shared test helpers |

## Conventions

- **Exported symbols** are marked with `*` in Nim source.
- **Distinct types** carry domain constraints (e.g. `EpochCounter` must be non-negative).
- **Enums** use two-letter prefixes scoped to their module (e.g. `rm` for `RuntimeMode`).
- Procedures that begin with `step` belong to the deterministic startup sequence.
- This reference supplements the [Specification](../implementation/SPECIFICATION.md) and [Requirements](../implementation/REQUIREMENTS.md); treat those as canonical when conflicts arise.

---
*© 2026 Wilder. All rights reserved.*
*Licensed under the Wilder Foundation License 1.0.*
