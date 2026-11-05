# Cosmos Terms

What this is. This page is a compact glossary for terms used in runtime and concept
documentation. The rules behind the model terms are in
[MVP-REQUIREMENTS.md](../../implementation/MVP-REQUIREMENTS.md) section 1.

## The Model

- Thing: The only kind of entity. Everything that exists is a Thing.
- World: A Thing's inside: the Things it contains. A Thing and its World are one.
- Cosmos: The root Thing, created by the runtime, with no parent.
- Concept: A Thing that serves as a template. Every other Thing is made from one.
- Scope: What a Thing can act on: itself and what it contains.
- Scope path: A Thing's dot-separated address, such as `cosmos.synth.filter`.
- Manifest: The `manifest.json` file that declares a Concept.
- Interrogatives: The manifest's uppercase fields: WHO, WHAT, WHY, WHERE, WHEN, HOW,
  REQUIRES, WANTS, PROVIDES and WITH. WHO and WHY are required.
- WANTS / PROVIDES: What a Thing accepts and what it offers, with signatures.
- Part: A Concept used inside a composite Concept.
- Wave: A message. Waves spread across the whole Cosmos to every matching sense.
- Sense: A kind of wave a Thing perceives, matched by exact name.
- Wire: A wave constrained to a set origin and set destinations.
- Perception: A Thing noticing a wave through a sense, or receiving one on a wire.
- Frame: One round of changes to every Thing. Cosmos time is counted in frames.
- Change: One thing that happened during a frame, such as a wave or a state change.
- Occurrence: One row of the history: a frame and its changes. Never changes.
- History: The table of everything that happened, with one row per frame.
- Origin: Who caused a change: a Thing, a person or an AI client.
- Epoch: The code's name for the frame counter.

## The Runtime

- Rhythm: When a Thing acts: Event, Periodic, Continuous, Manual or Sequence.
  `TempoKind` in code until a later rename.
- Frame rate: How fast the daemon runs frames in `periodic` mode.
- Scheduler: Runs frames in a deterministic order with a time budget per Thing.
- Runtime lifecycle: The fixed startup and shutdown order.
- Startup error: A structured failure saying where startup halted, why, and how to
  recover.
- Prefilter: The validation gate every input passes before anything acts on it.
- Validation record / mask: The precomputed structure a payload is checked against.
- Reconciliation: Rebuilding state at startup from the persistence layers.
- Persisted entry: One saved item, with its checksum, origin and frame.
- Envelope: A saved or sent payload wrapped with metadata and a checksum.
- Capability graph: The match between every Thing's WANTS and other Things' PROVIDES.
- Daemon: The running Cosmos, started by `cosmos start`.
- IPC: The localhost connection the `cosmos` command, console and MCP use to reach the
  daemon.
- Method table: The one list of daemon operations. It drives the CLI, the console and
  MCP.
- Module: A Thing that extends the runtime.
- Bundle: A folder holding a Concept's `manifest.json`.

## Retired Terms

- RECORD: was the name for an internalized occurrence. Now: a change in the history.
- wink, smile, morphos, blip, tick: earlier names for time and change. Now: frame,
  change, occurrence.
- Five primitives: now one entity (the Thing) plus properties of the Cosmos.
- Context inheritance and overrides: retired. Nothing is inherited.
- Precept: older word for wave.
- Tempo (as a Thing's timing): now rhythm. Tempo keeps its musical meaning, speed.

## Deferred Terms

- World Ledger, Claim, Reference: deferred until real Things need them.
- Memory categories: kept in code, not part of the MVP.
- Specialist, Delegation: kept in code, not part of the MVP.
- Encryption mode: deferred. The MVP stores data unencrypted.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
