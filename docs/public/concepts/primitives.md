# Things, Concepts, Waves and the History

What this is. This page explains the Cosmos model: what exists, how it communicates
and how time works. The rules behind it are MVP-ONT-1 to MVP-ONT-11 in
[MVP-REQUIREMENTS.md](../../implementation/MVP-REQUIREMENTS.md).

## What Exists: Things

Only Things exist. Everything else is either a property of the Cosmos or a pattern
made from Things.

- **The Cosmos** is the root Thing. The runtime creates it, it has no parent, and
  every other Thing is inside it.
- **A Thing and its World are one thing.** The World is the Thing's inside: the
  Things it contains.
- **Every Thing has a scope path** that follows containment, such as `cosmos.synth.filter`.
- **A Thing exists with two fields:** WHO (its identity) and WHY (its purpose).

## Templates: Concepts

A Concept is a Thing that serves as a template, like a blueprint. Every Thing except
the Cosmos is made from a Concept.

- Concepts live together at `cosmos.concepts.<name>`, apart from the Things made from
  them.
- A Thing takes its WHY from its Concept unless it states its own.
- Modules, bundles and bridges are Things too, not separate kinds of unit.
- A Concept can be built from other Concepts (its PARTS) and the wires between them.
  Only a Concept with no parts needs code of its own.

[interrogative-manifest.md](interrogative-manifest.md) describes the file that
declares a Concept.

## Properties of the Cosmos

These aren't Things. They belong to the Cosmos as a whole.

### Waves

A wave is a message. Waves are the only way Things communicate.

- **Waves are global.** A wave spreads across the whole Cosmos, and every Thing with
  a matching sense perceives it.
- **A sense names a kind of wave.** A wave's kind is the name of what it carries,
  such as `notes`. A sense matches by exact name.
- **A wave has no address.** A Thing can't send a wave to a chosen Thing. Only wires
  direct waves.

### Wires

A wire is a wave constrained to a set origin and set destinations. It connects one
Thing's output to the inputs of one or more other Things.

- A wire carries either a Thing's whole output (`keys`) or one named part of it
  (`keys.notes`), like a single output jack on a hardware module.
- A wave carried by a wire goes only to the wire's destinations. It doesn't spread.
- Every wire is checked when its Concept loads. Each destination must accept what the
  wire carries, or the Concept is skipped with a warning.
- A go-between is a Thing in the middle, with a wire on each side.

### Perception

Perception is a Thing noticing a wave through one of its senses or receiving one along
a wire. Perceiving a wave tells a Thing about its source. It doesn't let the Thing act
on that source.

### Frames, Occurrences and the History

- **Time advances in frames.** A frame is complete when one round of changes to every
  Thing is complete. Cosmos time is counted in frames, never clock time.
- **A wave sent during a frame is perceived in the next frame,** so the order Things
  run in never changes what they perceive.
- **The history is a table with one row per frame.** The key is the frame. The value
  is the frame's changes: waves sent, state changes, Things added or removed,
  failures and operator requests, each with who caused it.
- **An occurrence is one row:** what happened, and when. Occurrences never change.

## Scope and Inheritance

- A Thing can act on itself and what it contains. Anything else reaches it only
  through its senses or a wire someone connected on purpose.
- People and AI act through the Cosmos's own interface, which can reach every Thing.
  Every request passes the same validation and is recorded.
- **Nothing is inherited.** Nothing flows from a parent Thing to the Things inside
  it. Taking declarations from your own Concept is instantiation, not inheritance.

## Building Status

This model is specified in
[MVP-SPECIFICATION.md](../../implementation/MVP-SPECIFICATION.md) §4B and §4C and
built in Phase 3. Today's code has Things, the Cosmos root, scope paths, the
scheduler and Concept manifests. Waves don't travel yet, senses and wires don't
exist, and the history is still recorded per event, not per frame.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
