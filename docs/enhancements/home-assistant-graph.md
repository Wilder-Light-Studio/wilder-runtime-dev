# Home Assistant Graph Wrapper

> **Home:** this note is a possible future project. It lives here until that project
> exists, then it moves there. Nothing in it is a Cosmos runtime requirement.

**Status:** Idea (added 2026-11-08). Nothing is decided.

**The idea:** a graph-based wrapper for Home Assistant devices and automations.

## Why It May Suit Cosmos

These are first thoughts, not decisions.

| Home Assistant | Cosmos |
|---|---|
| A device | A Thing |
| A kind of device | A Concept |
| A trigger or state change | A wave |
| An automation | A composite Concept, with visible wires |
| What fired, and when | The history |

For a Neurodivergent (ND) user, the appeal is seeing how the house is connected in one
graph, and being able to check what happened and why.

## The Boundary

- It would be its own project and use Cosmos through its public surface.
- Nothing specific to Home Assistant goes in the Cosmos repository.
- It would connect through Home Assistant's own interfaces, using a bridge Thing.

## Questions for Later

1. Does it only show the graph, or also change devices and automations?
2. Do automations stay in Home Assistant, or move into Cosmos?
3. Does "graph" mean a visual editor, a data model, or both?

It would need to run all the time, so it is a likely first use of the
[reference deployment](../implementation/MVP-PLAN.md#reference-deployment).

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
