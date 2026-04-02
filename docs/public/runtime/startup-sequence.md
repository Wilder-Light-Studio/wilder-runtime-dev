# Startup Sequence

What this is. This page gives a plain operational view of runtime startup and shutdown order.

## Startup Order

1. Load configuration.
2. Initialize persistence backend.
3. Load runtime envelope.
4. Reconcile layers.
5. Run migrations.
6. Activate validating prefilter.
7. Load modules in deterministic order.
8. Initialize scheduler, tempo, world graph.
9. Start frame loop and open ingress.

## Gate Conditions

- No module load before reconciliation pass.
- No ingress before prefilter activation.
- On failure, startup halts with a structured startup error.

## Shutdown Order

1. Flush transactions.
2. Write snapshots.
3. Stop scheduler and tempo.
4. Unload modules.
5. Close persistence backend.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
