# Runtime At A Glance

What this is. This page explains the runtime at a high level so you can orient quickly.

## Startup Sequence

The implemented lifecycle runs in strict order:

1. Load configuration.
2. Initialize persistence backend.
3. Load runtime envelope.
4. Reconcile layers.
5. Run migrations.
6. Activate validating prefilter.
7. Load modules in deterministic order.
8. Initialize scheduler, tempo, and world graph.
9. Open ingress and run frames.

No partial startup is allowed. On failure, startup halts with a structured error.

## Main Subsystems

- Runtime core: lifecycle control and startup gates.
- Validation and prefilter: admission control before dispatch.
- Serialization: envelope wrap and unwrap with checksums.
- Persistence: layered state, txlog, and snapshots.
- Messaging: structured envelopes across module boundaries.
- Modules: kernel and loadable registrations.

## Mental Model

Think of the runtime as an airlock system:

- outer door: ingress request enters
- pressure check: prefilter validates shape and route
- inner door: only validated payload reaches dispatch

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
