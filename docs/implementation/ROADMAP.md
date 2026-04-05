# WILDER COSMOS RUNTIME — ROADMAP

This document tracks future improvement ideas that are not yet committed chapter work.

It is intentionally non-normative. Canonical behavior remains defined in:

- `REQUIREMENTS.md`
- `SPECIFICATION-NIM.md`
- `PLAN.md`

Use this roadmap to capture candidate work, discuss tradeoffs, and prepare future planning updates.

---

## How to Use This Document

- Add ideas as short, testable outcomes.
- Keep entries implementation-oriented, not marketing-oriented.
- Link the relevant requirements/spec sections when known.
- Move items into `PLAN.md` only when scope, ownership, and acceptance criteria are clear.

## Status Legend

- `Captured`: Idea logged, not yet researched.
- `Shaping`: Scope and constraints are being explored.
- `Planned`: Candidate for near-term planning cycle.
- `Scheduled`: Assigned to an upcoming chapter/phase.
- `Done`: Implemented and verified.
- `Deferred`: Explicitly postponed.

## Prioritization Guide

Score each idea on:

- Impact on correctness, reliability, or operator safety.
- Risk reduction for startup, validation, reconciliation, and persistence.
- Delivery cost (engineering and verification effort).
- Dependency pressure (what else is blocked by this work).

Recommended ordering rule:

1. Correctness and safety first.
2. Determinism and reproducibility second.
3. Developer/operator ergonomics third.
4. Performance optimization when correctness baselines are stable.

---

## Idea Backlog

| ID | Area | Idea | Why It Matters | Dependencies | Status | Notes |
|----|------|------|----------------|--------------|--------|-------|
| RI-001 | Validation | Add property-based and fuzz tests for envelope decode, checksum handling, and malformed payload boundaries. | Improves boundary hardening and catches parser edge cases early. | Existing serialization and validation suites. | Captured | Start with deterministic seeds to keep CI reproducible. |
| RI-002 | Messaging | Add strict transport compatibility tests between JSON and Protobuf envelope paths. | Reduces drift risk between serializer implementations. | Ch 2/2B serializer baseline. | Captured | Include negative cases for checksum and field mismatch behavior. |
| RI-003 | Persistence | Add crash-recovery simulation tests around txlog replay and snapshot restore interruption. | Strengthens durability guarantees under abrupt process termination. | Current reconciliation + file backend behavior. | Captured | Include power-loss style interruption scenarios. |
| RI-004 | Startup | Add a startup diagnostics summary object for gate results (config, reconcile, prefilter, ingress). | Gives operators a deterministic startup evidence record. | Existing startup gates and host event logs. | Shaping | Keep output redacted and machine-parseable. |
| RI-005 | Security | Add secret redaction policy checks to all structured error/event emitters. | Prevents accidental sensitive data disclosure in logs and failures. | Existing host observability + tests. | Captured | Add regression fixtures for common secret patterns. |
| RI-006 | Performance | Add benchmark baselines for prefilter lookup, startup gating latency, and reconciliation throughput. | Supports evidence-based optimization and regression detection. | Stable benchmark harness and representative fixtures. | Shaping | Record thresholds with hardware/context annotations. |
| RI-007 | Tooling | Add automated artifact generation for API docs and compliance snapshots in CI. | Keeps documentation evidence synchronized with code changes. | Existing compliance scripts and CI workflow. | Captured | Prefer deterministic artifact naming/versioning. |
| RI-008 | Developer Experience | Add a local "fast verify" profile with strict but reduced runtime for edit loops. | Improves development speed without dropping critical safety checks. | Current `nimble verify` and test tagging strategy. | Planned | Define mandatory tests that always remain in fast profile. |
| RI-009 | Release | Add reproducible release packaging checksums and manifest validation as a required gate. | Increases release trust and traceability. | Existing release scripts. | Captured | Align with current checksum generation scripts. |
| RI-010 | Modules | Publish an integration sample pack for runtime modules and cosmos modules with failure-mode examples. | Lowers onboarding friction and improves extension quality. | Existing templates + examples. | Captured | Include both happy path and boundary-failure samples. |

---

## Promotion Checklist (Roadmap -> Plan)

An idea should move from this roadmap into `PLAN.md` when all are true:

- Problem statement is concrete and evidence-backed.
- Scope boundaries are documented.
- Acceptance criteria are testable.
- Requirement/spec touchpoints are identified.
- Verification strategy (tests/scripts) is defined.

## Review Cadence

- Review roadmap items at each planning checkpoint.
- Remove stale items that no longer align with requirements.
- Promote only items with clear acceptance criteria and verification paths.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*