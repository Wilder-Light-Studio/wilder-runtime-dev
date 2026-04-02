# Concept, Thing, Occurrence, Perception

What this is. This page defines the four ontology primitives and how they relate.

## Concept

Concept is an immutable template. Its minimal universal contract is:

- identity
- WHY

Additional sections and a manifest may be present when a world needs them.

Common sections include:

- Identity
- Location
- Perception
- Emission
- Tempo
- Status
- Interrogative Manifest

## Thing

Thing is the runtime instantiation of a Concept. Its only universal requirement is identity.

Concept association, status, metadata, and manifest-backed surfaces are world-defined additions.

## Occurrence

Occurrence is an immutable projection event and the only allowed mechanism of world change.
In communication flows, these projections are carried as Waves on the runtime bus.

Core fields include:

- id
- source
- epoch
- payload
- projection radius

## Perception

Perception is a local awareness event produced by matching filters. It is passive and bounded.

## Relationship Sketch

- Concept defines identity and purpose first, then optional structure.
- Thing is a live instance of that shape.
- Occurrence carries change signals.
- Wave is the communication form of those signals between Things.
- Perception records local awareness of relevant signals.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
