# What Is Cosmos

What this is. This page gives a plain-language definition of the Cosmos model used by this runtime.

Wilder Cosmos Runtime is a deterministic world-state runtime implemented in Nim. It combines:

- a Thing/World model with one primitive seen as Thing, World, and Scope
- a minimal existence contract (WHO and WHY)
- Occurrence as the only mechanism of change
- wave-based communication (Waves, not precepts)
- local awareness through Perception
- strict boundary validation
- structured messaging and serialization
- persistence with reconciliation at startup
- a module surface for runtime and optional userland behavior

A useful physical metaphor is a workshop with a ledger and a scheduler:

- the ledger records what happened
- the scheduler decides when steps execute
- validation gates decide what is allowed in

The project is requirements-first: behavior is defined in docs and enforced by tests.

## What It Is Not

- It is not an ad-hoc plugin host where modules can bypass startup gates.
- It is not a runtime that permits unvalidated ingress.
- It is not a hidden-state system; core state transitions are explicit and structured.

## Next Step

Continue to `runtime-at-a-glance.md` for the startup flow and subsystem map.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
