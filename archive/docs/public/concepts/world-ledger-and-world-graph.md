# World Ledger And World Graph

What this is. This page explains how structural world state is declared, persisted, and inspected.

## World Ledger

World Ledger is an append-only declarative record of:

- references (typed edges)
- claims (relational assertions)

Invariants include:

- no implicit references
- mutations flow through Occurrences
- validation at load
- persistence through the layered model

## World Graph

World graph is built as:

- nodes = Things
- edges = explicit references from World Ledger

No inferred edges are allowed by contract.

## Introspection

Console commands expose:

- `world` for structural edges
- `claims` for relational assertions

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
