# Encryption Modes Roadmap

This document captures a possible future enhancement for runtime and product privacy posture.

It is exploratory and non-normative. It does not change current runtime behavior, configuration, or requirements.

## Goal

Define a clear, comprehensible spectrum of encryption modes that expresses trust boundaries between user, device, and operator.

## Proposed Modes

| Mode | Operator Access | Recovery | Sync | Description |
|------|-----------------|----------|------|-------------|
| `open` | Full | Yes | Yes | Standard cloud mode |
| `standard` | No content, metadata visible | Yes | Yes | Client-side encrypted content |
| `private` | No content, minimal metadata | Limited | Yes | Strong privacy with optional recovery |
| `closed` | None (E2EE) | No | User-controlled | Fully sealed mode |
| `local` | None | User-controlled | No | Offline, device-only |

## Candidate Roadmap Entry

- Status: Captured
- Area: Security / Privacy / Runtime Configuration
- Idea: Introduce declarative encryption modes: `open`, `standard`, `private`, `closed`, and `local`.
- Why it matters: Gives users and operators a shared vocabulary for privacy posture, recovery guarantees, sync behavior, and trust boundaries.
- Dependencies: Key management model, persistence model, sync semantics, recovery policy, metadata minimization rules, and configuration schema design.
- Notes: This should be designed as a policy layer over lower-level encryption primitives rather than as a single algorithm choice.

## Directional Scope

- Define what content, metadata, and operator-visible evidence exist in each mode.
- Specify recovery guarantees and failure semantics for key loss.
- Decide which modes permit sync, escrow, device transfer, and operator-assisted recovery.
- Map each mode onto concrete runtime configuration and validation rules.
- Separate local-only behavior from cloud-synchronized behavior.

## Acceptance Criteria For Future Planning

- Each mode has a precise contract for content visibility, metadata visibility, recovery, and sync.
- The configuration model can express the chosen mode without ambiguity.
- Startup and validation paths reject incompatible combinations deterministically.
- Documentation distinguishes current behavior from future enhancement behavior.
- Verification strategy covers key-loss, recovery, sync, and metadata exposure cases.

## Open Questions

- Whether `standard` permits optional escrow by default or only by explicit opt-in.
- Whether `private` and `closed` differ only by recovery semantics or also by metadata surface.
- Whether `local` is a distinct encryption mode or an orthogonal storage/sync policy.
- How operator-observable metadata should be minimized without breaking diagnostics and reconciliation.
- Whether mode selection is global, profile-scoped, workspace-scoped, or record-scoped.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*