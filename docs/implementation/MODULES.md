# Modules Guide

This document explains the difference between `src/modules/` and
`src/runtime_modules/` in Wilder Cosmos Runtime.

The split exists to keep the runtime core clear, stable, and intentional.

## The Short Version

- `src/runtime_modules/` is for modules that are part of the runtime itself.
- `src/modules/` is for modules that are optional, experimental, or otherwise
  not part of the trusted runtime core.

## Runtime Modules

Put a module in `src/runtime_modules/` when it must be treated as part of the
runtime's shipped surface.

Typical cases:

- core services
- platform adapters the runtime depends on
- persistence backends with stronger compatibility expectations
- modules that must be initialized deterministically at startup

Runtime modules carry stronger expectations around stability, lifecycle order,
and long-term compatibility.

## Single Source Of Truth: Code-Defined Contracts

Cosmos-native modules must define their contracts in code.

- Code is the authoritative source.
- Generated manifests are allowed as derived artifacts.
- Hand-maintained manifests for Cosmos-native modules are not the source of truth.

This keeps the MVP contract surface aligned with the runtime behavior actually shipped.

## Regular Modules

Put a module in `src/modules/` when it is useful but not required to define the
runtime's core behavior.

Typical cases:

- examples and demonstrations
- experimental capabilities
- optional integrations
- replaceable extensions

These modules can evolve more freely because they are not the same thing as the
runtime's core shipped surface.

## Wrapping External Processes With Hand-Written Manifests

External processes do not expose a Cosmos-native code contract the runtime can inspect.

Use handwritten manifests for wrappers around:

- resident services
- scripts
- binaries
- pipes and filters
- stdin/stdout workers
- AI model adapters

For these wrappers, the handwritten manifest is authoritative by design.

## Why The Separation Matters

This split helps the repository stay understandable and disciplined.

- Stability: core runtime behavior stays separate from optional behavior.
- Packaging: shipped runtime pieces are easier to identify and reason about.
- Lifecycle: startup-critical modules are not mixed with modules that can remain
  optional.
- Maintenance: stronger guarantees can be applied only where they are needed.

## Placement Guidance

Use `src/runtime/` or `src/runtime_modules/` for code that belongs to the core
runtime path.

Use `src/modules/` for code that demonstrates, extends, or experiments with the
runtime without defining its required behavior.

If a module starts as optional and later becomes part of the runtime's required
surface, move it into `src/runtime_modules/` only when it is ready to carry the
stronger stability and lifecycle expectations that come with that position.

Native modules may keep their manifest absent until a derived manifest view is needed.
External wrappers require a handwritten manifest from the start.

## Examples

- `src/runtime_modules/file-backend`
  A built-in persistence backend with strict reconciliation expectations.

- `src/modules/counter-example`
  A simple module used to demonstrate the module API.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*