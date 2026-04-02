# Cosmos Terms

What this is. This page is a compact glossary for terms used in runtime and concept documentation.

- Concept: Immutable template whose universal minimum is identity plus WHY.
- Thing: Runtime instance whose universal minimum is identity.
- Occurrence: Immutable event that carries world-change intent.
- Perception: Local awareness event produced by matching conditions.
- Interrogative Manifest: Optional declarative contract. When present, all interrogatives must be non-empty. For Cosmos-native modules it is generated from code; for external processes it may be handwritten.
- Status: Structured state fields attached to a Thing.
- Status Schema: Versioned declaration of status fields and invariants.
- Invariant: Rule that must remain true at validation points.
- Memory Model: Categories and limits for stored runtime information.
- State Memory: Persisted status state.
- Perception Memory: Bounded queue of perception events.
- Temporal Memory: Frame and epoch counters.
- Module Memory: Memory budget assigned to a module.
- World Ledger: Append-only record of declared references and claims.
- World Graph: Node and edge view built from declared references.
- Claim: Declared relational assertion in the world model.
- Reference: Explicit typed edge between Things.
- Epoch: Shared frame identifier used for deterministic ordering.
- Tempo: Timing mode for execution cadence.
- Scheduler: Runtime component that orders execution within frame semantics.
- Runtime Lifecycle: Ordered startup and shutdown sequence.
- Reconciliation: Startup process that resolves layered persistence state.
- Prefilter: Validation gate that blocks unvalidated ingress.
- Validation Record: Signature-linked structural validation definition.
- Validation Mask: Precomputed bit-level structure expectation.
- Payload Mask: Runtime-computed structural observation for inbound payload.
- Module Registry: Runtime table of statically registered modules.
- Kernel Module: Built-in module with stronger startup and compatibility expectations.
- Loadable Module: Optional module loaded after kernel pass in deterministic order.
- Host Bindings: Runtime-provided functions exposed to modules.
- Startup Error: Structured startup failure with halted step and recovery guidance.
- Envelope: Serialized wrapper containing payload plus metadata and checksum.
- Checksum: Digest used to verify payload integrity.
- Transport: Configured serialization channel selection.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
