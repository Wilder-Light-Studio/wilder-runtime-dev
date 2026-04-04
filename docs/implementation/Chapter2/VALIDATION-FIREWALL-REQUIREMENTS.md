# Wilder Cosmos Runtime - Validation Firewall Requirements

This chapter-level requirements file defines the canonical validating prefilter boundary for Chapter 2C.
It aligns terminology with the runtime-wide validation firewall vocabulary update.

## Purpose

- The validation firewall executes before dispatch and before Occurrence recording.
- The validation firewall prevents structurally invalid inbound payloads from reaching user code.
- The validation firewall emits deterministic validation failures without exposing raw invalid payload data.

## Core Requirements

- Validation rules must be keyed by stable proc/function signatures and resolved through an O(1) lookup index on the hot path.
- The runtime must not dynamically parse schemas on the hot path.
- Structural validation must use build-time validation masks and runtime payload masks with the canonical conjunction check `(validationMask AND payloadMask) == validationMask`.
- Payload mask computation must remain zero-allocation for the hot-path validation flow.
- The validation firewall must fail fast on the first structural violation.
- Only validated payloads may be dispatched or recorded as normal domain Occurrences.
- Validation failures must be represented as explicit Occurrences with clear semantics.
- Validation failures must exclude raw payload bytes and other sensitive invalid-input content from operator-facing output.

## Canonical Sources

- Requirements source: `docs/implementation/REQUIREMENTS.md`
- Specification source: `docs/implementation/SPECIFICATION-NIM.md` §24.9–§24.14
- Plan source: `docs/implementation/PLAN.md` Chapter 2C and the validation firewall vocabulary phase
- Verification source: `docs/implementation/COMPLIANCE-MATRIX.md`
