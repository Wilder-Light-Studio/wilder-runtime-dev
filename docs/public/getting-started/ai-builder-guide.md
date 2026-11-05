# Wilder Cosmos — AI Builder Developer Guide

**Last updated:** 2026-11-05

---

## Purpose

This guide is for AI builders and for developers working alongside AI. In Cosmos, AI
is a first-class user: it can discover, inspect and operate everything a person can,
through the same surface. This guide covers the model, how an AI reaches the runtime,
and the conventions for working in the code. It follows the Neurodivergent (ND)
documentation style used across the project.

---

## 1. The Model

- **Thing:** the only kind of entity. The Cosmos is the root Thing.
- **Concept:** a Thing that serves as a template. Every other Thing is made from one.
- **Wave:** a message that reaches every Thing with a matching sense.
- **Wire:** a wave constrained to a set origin and set destinations.
- **Frame:** one round of changes. The history has one row per frame.
- **Scope:** a Thing acts only on itself and what it contains. Nothing is inherited.

[Concepts](../concepts/primitives.md) explains each one. The rules are in
[MVP-REQUIREMENTS.md](../../implementation/MVP-REQUIREMENTS.md) section 1.

---

## 2. How an AI Reaches Cosmos

There's one surface: the daemon's method table. The `cosmos` command, the console and
the Model Context Protocol (MCP) bridge are all thin clients of it, so there's no
human-only path and no AI-only path (MVP-AI-1 to MVP-AI-7).

| Want to | Use |
|---|---|
| See every operation | `cosmos methods` |
| Learn about a Thing | `cosmos describe <target>` |
| Invoke what a Thing PROVIDES | `cosmos call <thing> <provide> --args-json <json>` |
| Operate the runtime itself | `describe cosmos`, then `call cosmos <operation>` |
| Work through MCP | `cosmos mcp`: one tool per method, such as `cosmos_describe` |

- Every command prints a JSON response and never asks a question.
- Exit codes: `0` success, `1` no daemon or a timeout, `2` a usage or daemon error.
- Every request passes the same validation as a person's, and every change is
  recorded in the history with its origin, such as `mcp:<client name>`.

**Status:** this surface is built in Phase 2. Today only `cosmos start`, `inspect`,
`step` and `console` reach the daemon. See the
[Runtime CLI Guide](runtime-cli-guide.md).

---

## 3. Getting Started in the Code

1. Clone the repository and run `nimble verify`. It should end with `Gate passed.`
2. Read, in order:
   - [STATUS.md](../../../STATUS.md): where things stand.
   - [MVP-REQUIREMENTS.md](../../implementation/MVP-REQUIREMENTS.md): what must be
     true.
   - [MVP-SPECIFICATION.md](../../implementation/MVP-SPECIFICATION.md): how it's
     built.
   - [MVP-COMPLIANCE-MATRIX.md](../../implementation/MVP-COMPLIANCE-MATRIX.md): what's
     proven.
   - [DEVELOPMENT-GUIDELINES.md](../../implementation/DEVELOPMENT-GUIDELINES.md) and
     [COMMENT_STYLE.md](../../implementation/COMMENT_STYLE.md).
3. Look at [examples/counter.nim](../../../examples/counter.nim) for a working module.

---

## 4. Conventions

- **ND-friendly writing:**
  - Expand every acronym on first use, such as Neurodivergent (ND).
  - Use plain, direct language and short sentences.
  - Avoid figurative or emotional language in procedural docs.
- **Explicit over implicit:** no hidden behaviour, no inheritance, no side effects
  a reader can't see.
- **Determinism:** say whether a procedure is deterministic. Replayability is a
  requirement (MVP-SCH-1).
- **Header comments:** every Nim file has Summary, Simile, Memory note and Flow lines,
  and a `# Flow:` comment before each `proc`. `nimble compliance` checks both.
- **Validation:** public procedures validate input at the boundary and fail fast.
- **Templates:** new modules start from `templates/cosmos_runtime_module.nim`, new
  tests from `templates/test_module.nim`, or use `scripts/dev/new_nim_module.ps1`.
- **Proof:** a change counts when its requirement's matrix row is updated and
  `nimble verify` passes.

---

## 5. Where Things Live

- **Things and waves:** [thing.nim](../../../src/cosmos/thing/thing.nim),
  [wave.nim](../../../src/cosmos/wave/wave.nim).
- **Scope and capabilities:** [ontology.nim](../../../src/runtime/ontology.nim),
  [capabilities.nim](../../../src/runtime/capabilities.nim).
- **Manifest:** [manifest.nim](../../../src/cosmos/core/manifest.nim).
- **Scheduler and rhythm:** [scheduler.nim](../../../src/cosmos/runtime/scheduler.nim),
  [tempo.nim](../../../src/cosmos/tempo/tempo.nim) (renamed later).
- **Persistence:** [persistence.nim](../../../src/runtime/persistence.nim).
- **Daemon and IPC:** [coordinator_ipc.nim](../../../src/runtime/coordinator_ipc.nim),
  [cosmos_main.nim](../../../src/cosmos_main.nim).

---

## 6. ND-Friendly Checklist

- [ ] All acronyms expanded on first use
- [ ] Short, direct sentences
- [ ] Determinism noted for all APIs
- [ ] Examples are executable
- [ ] `nimble verify` passes

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
