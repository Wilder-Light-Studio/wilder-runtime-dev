# Persistence

What this is. This page describes the layered persistence model and reconciliation behavior.

## Layers

Runtime persistence includes layers such as:

- runtime
- modules
- txlog
- snapshots

## Core Behaviors

- envelope-based record storage
- checksum validation on read and restore paths
- reconciliation before module execution
- snapshot and transaction workflows

## File-Backed vs In-Memory

The runtime supports in-memory and file-backed persistence bridges in code, with deterministic key and layer handling.

## Safety Posture

Persistence operations fail fast on invalid envelopes, unsupported layers, and malformed staged keys.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
