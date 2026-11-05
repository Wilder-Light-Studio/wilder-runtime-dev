# Startup Sequence

What this is. This page gives a plain operational view of runtime startup and shutdown
order (MVP-LIFE-1 to MVP-LIFE-6).

## Startup Order

1. Load configuration (optional: documented defaults are used without one).
2. Load the runtime envelope.
3. Reconcile the persistence layers.
4. Run migrations.
5. Activate the validating prefilter.
6. Load runtime modules in deterministic order.
7. Create the Cosmos root Thing.
8. Start the scheduler.
9. Build the capability registry.
10. Load user Things.
11. Run the frame loop.

## Gate Conditions

- No module runs before reconciliation passes.
- No input is accepted before the prefilter is active.
- Starting with zero user Things succeeds. Missing world files never block startup.
- A malformed user Thing is skipped with a warning and never blocks startup.
- A failed step halts startup with a structured error: where it halted, why, and how
  to recover. The guidance never includes file paths, secrets or payload contents.

## Shutdown Order

1. Flush pending transactions.
2. Write a final snapshot.
3. Stop the scheduler.
4. Unload modules.
5. Close persistence.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
