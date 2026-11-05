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

- Every persisted entry carries `schemaVersion`, `epoch`, `checksum`, `origin`, `txId`
  and `timestamp`. Checksums are verified on every read.
- Writes go to a temporary file, then an atomic replace, so a crash never leaves a
  partial file.
- Keys are limited to `[a-zA-Z0-9_-]`, at most 128 characters.

## In the MVP

- **Unencrypted.** Data is stored in the clear (MVP-SAFE-6). Protecting data on disk
  is the operating system's job, for example BitLocker. The encryption code remains
  but is deferred.
- **The history lives here.** From Phase 3, each frame's row of changes is one
  persisted entry, key `frame-<N>`, in the layer the code still calls RECORD
  ([MVP-SPECIFICATION.md](../../implementation/MVP-SPECIFICATION.md) §4C.5).

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
