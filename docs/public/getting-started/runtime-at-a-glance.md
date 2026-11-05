# Runtime At A Glance

What this is. This page explains the runtime at a high level so you can orient quickly.

## Startup Sequence

Startup runs in a fixed order (MVP-LIFE-1):

1. Load configuration (optional: defaults are used if there's none).
2. Load the runtime envelope.
3. Reconcile the persistence layers.
4. Run migrations.
5. Activate the validating prefilter.
6. Load runtime modules.
7. Create the Cosmos root Thing.
8. Start the scheduler.
9. Build the capability registry.
10. Load user Things.
11. Run the frame loop.

A failed step halts startup with a structured error saying where it stopped, why,
and how to recover. A malformed user Thing is skipped with a warning and never stops
startup. Starting with no user Things at all is fine.

## Main Parts

- **Runtime core:** the startup and shutdown order and its gates.
- **Validating prefilter:** checks every input before anything acts on it.
- **Scheduler:** runs frames in a deterministic order, with a time budget per Thing.
- **Persistence:** primary state, an append-only transaction log, and snapshots.
- **Capabilities:** matches what each Thing WANTS to what other Things PROVIDE.
- **Daemon and IPC:** the running Cosmos, reached over localhost by the `cosmos`
  command, the console and, from Phase 2, MCP.

## Mental Model

Think of the runtime as an airlock:

- outer door: input arrives;
- pressure check: the prefilter validates its shape and route;
- inner door: only validated input reaches a Thing or becomes a change in the history.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
