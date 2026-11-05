# Wilder Cosmos Runtime — MVP Specification

**Status:** Draft for review (2026-11-05).
**Requirements:** [MVP-REQUIREMENTS.md](MVP-REQUIREMENTS.md). **Proof:**
[MVP-COMPLIANCE-MATRIX.md](MVP-COMPLIANCE-MATRIX.md).
**Full specification:** [SPECIFICATION.md](SPECIFICATION.md) is kept unchanged as the
long-term reference.

This file says how the MVP requirements are met. It follows the existing source order:
requirements say what must be true, this file says how, and the plan says when. When
this file and SPECIFICATION.md disagree, this file governs MVP work. Where
SPECIFICATION.md is already right, this file points to it instead of restating it.

Neurodivergent (ND) is spelled out here on first use, per MVP-DX-4.

---

## 1. Plausibility constraints

These keep the MVP in service of the real goal: personal music tools with a hardware
feel. They apply to every phase.

- **C1 — Timebox Cosmos.** Phases 1 and 2 (the gate, then the daemon and CLI) are
  committed. Phases 3 and 4 go ahead when the audio project needs them, not to make
  Cosmos complete for its own sake.
- **C2 — Measure before the kernel spec.** In the audio project, run LatencyMon, then
  a WASAPI-exclusive sine wave at the smallest stable buffer. Those numbers become the
  kernel's latency targets. Until then, any latency target is a guess.
- **C3 — Make the first audio milestone small.** One oscillator, played from a MIDI
  keyboard, with its latency measured. Everything else builds on that.
- **C4 — Scope.** A synth and a MIDI editor are the target. A DAW stays "possibly" and
  isn't planned.
- **C5 — Boundary.** Nothing audio-specific lives in this repo. The audio project uses
  Cosmos through its public surface (Things, the IPC contract in §4). An AI uses that
  same surface (§4A). Real-time rules,
  such as no allocation on the audio thread (any `seq`, `string` or `ref` can allocate
  under Nim 2's default memory management), belong to the kernel spec. Cosmos makes no
  real-time claim.

---

## 2. Already specified

These MVP areas are implemented to SPECIFICATION.md. Only the MVP differences are
listed.

| MVP area | SPECIFICATION.md | MVP difference |
|---|---|---|
| 1. Ontology | §4, §4.1, §4.1A, §4.1B | One kind of entity plus properties of the Cosmos (MVP-ONT-1, MVP-ONT-8). §4.1C–§4.1D (context, overrides) are retired (MVP-ONT-11). §4.1E (references) is deferred. |
| 2. Lifecycle | §5, §5A | None. |
| 3. Persistence | §2 | Records are stored CLEAR. Encrypted record is deferred. |
| 4. Validation | Validating Prefilter sections | None. |
| 5. Scheduler | Scheduler and Tempo sections | The daemon drives frames as in §3.3 below. |
| 6. Integration | Phase XA sections | Concepts, implementations and composition follow §4B. |
| 7. Configuration | Config sections | JSON only (no Cue). `port` reaches the daemon (§3.2). |
| 9. Console | §3.1–§3.6 | Reduced command set (MVP-CON-2). The entry point is §5 below. |

---

## 3. Daemon

This replaces SPECIFICATION.md §5B.2's "reserved commands" list and §5B.5. The daemon
model was added on 2026-04-13 (`f71f93a`) without a specification.

**Current state:** the IPC server keeps its own copy of state (a `things` name list, a
`tick` counter) that isn't connected to the runtime. `step` increments a counter
without running a frame. The frame loop and the IPC thread share one session without
coordination. `cosmos start` ignores all flags and config.

### 3.1 States

`Starting → Running → Stopping → Stopped`, plus `Halted` for a failed startup.
`Running` has a `paused` flag. Only `Running` accepts IPC requests other than `ping`.

### 3.2 Start

`cosmos start [--mode <step|continuous|periodic>] [--config <path>] [--with <path>]...
[--loglevel <info|warn|error|debug>] [--port <N>]`

1. Parse with the existing `parseStartOptions`, extended with `--port`.
2. Resolve config: defaults, then the file, then `COSMOS_*` environment variables, then
   flags (MVP-CFG-2). The resolved `port` is used for everything after this step.
3. Probe the port with `runtime.ping`, using the client timeouts in §4.4:
   - A Cosmos daemon answers: print `cosmos: daemon already running on port N`, exit 0.
   - Something else answers, or the port can't be bound: say so, exit 1.
   - Nothing answers: continue.
4. Run lifecycle startup (SPECIFICATION.md §5.1) with the resolved config and the
   `--with` bundles.
5. Bind the IPC listener, print `cosmos: daemon running on port N`, and enter the frame
   loop.

**The daemon runs in the foreground.** `cosmos start` blocks the terminal it runs in.
`Ctrl+C` there and `cosmos stop` from anywhere else run the same shutdown. This keeps
current behaviour, leaves no orphaned background process, and needs no Windows
detach code. A background mode is deferred.

### 3.3 Frame loop and the single writer

- **One writer.** Only the frame-loop thread changes runtime state. The IPC thread
  parses requests and puts them on a queue. The frame loop drains the queue between
  frames, applies each request and returns its response. This makes behaviour
  replayable (MVP-SCH-1) and removes the shared-state race.
- **`--mode step`:** start paused. Each `runtime.step` runs exactly one scheduler frame.
- **`--mode continuous`:** run frames back to back, yielding between them.
- **`--mode periodic`:** run frames at the configured tempo.
- `runtime.inspect`, `runtime.listThings` and the console read the lifecycle's real
  state, not an IPC-side copy.

### 3.4 Loading Things

`--with <path>` and `cosmos add thing <path>` both load through `loadCosmosBundle`
into the lifecycle as user Things, children of the Cosmos root. A malformed bundle is
skipped with a warning (MVP-LIFE-3). There is one bundle format: a folder containing
`manifest.json`. `cosmos startapp` writes that format (§7).

### 3.5 Stop

- `cosmos stop` sends `runtime.stop`. The daemon replies `{"status": "stopping"}`.
- The frame loop finishes the current frame, then runs shutdown (MVP-LIFE-6).
- The listener closes and the port is released, even if shutdown fails.
- The process exits 0, or 1 with a structured error.
- `Ctrl+C` in the daemon's terminal sets the same stop flag.
- With no daemon running, `cosmos stop` prints `cosmos: no daemon running on port N`
  and exits 1 (MVP-CLI-5).

---

## 4. IPC contract

This extends SPECIFICATION.md's Phase XC messaging section. The existing envelope is
kept.

### 4.1 Transport

Localhost TCP, bound to `127.0.0.1` only. One connection carries one request: the
client sends one JSON line, the server writes the response line and then any event
lines, and closes the connection.

### 4.2 Envelopes

- **Request:** `{"version"?, "id", "method", "params"?}`. With no `version`, `ipc-v1`
  is assumed, so existing clients keep working. Any other version gets
  `unsupported_version`.
- **Response:** `{"version": "ipc-v1", "id", "result"}` or `{"version": "ipc-v1",
  "id", "error": {"code", "message"}}`.
- **Error codes:** `invalid_request`, `method_not_found`, `unsupported_version`,
  `load_failure`, `not_running`.

### 4.3 Methods

The canonical names are `runtime.*`. The unprefixed aliases stay.

| Method | Status | Notes |
|---|---|---|
| `runtime.ping` | **New** | Returns `{"daemon": "cosmos", "version": "ipc-v1", "port"}`. |
| `runtime.stop` | **New** | §3.5. |
| `runtime.step`, `pause`, `resume`, `inspect`, `snapshot` | Rewire | Act on the lifecycle through the queue (§3.3). |
| `runtime.addThing`, `removeThing`, `listThings` | Rewire | Use real user Things (§3.4). |
| `runtime.setMode` | Rewire | Validate against `step|continuous|periodic` and apply it. |
| `runtime.addWatch`, `removeWatch`, `listWatch`, `subscribe`, `unsubscribe` | Keep | |
| `runtime.attach`, `console_render`, `console_dispatch` | **Fix** | See §5. |
| `runtime.detach` | **New** | Ends a console session. |

`runtime.start` and `runtime.restart` are removed from the client mapping. Starting is
a process action (§3.2), and `restart` is deferred. Until it returns, `cosmos restart`
is an unknown command (MVP-CLI-8).

### 4.4 Client rules

- Connect and read time out after 2 seconds. A timeout prints `cosmos: daemon on port
  N not responding` and exits 1. Nothing waits forever (MVP-SAFE-1).
- **Exit codes:** 0 means success. 1 means no daemon, a timeout or a transport failure.
  2 means a usage error or an error response from the daemon. This matches the current
  code.

---

## 4A. AI access

AI is a first-class user (MVP-AI-1 to MVP-AI-6). The design rule: **the IPC contract
is the one surface.** The CLI, the console and the MCP bridge are all clients of it,
and an AI can use either the CLI or MCP. REST is deferred. It would be another thin
client of the same table, so adding it later changes nothing underneath.
A new capability is added as an IPC method first, then mapped to a CLI verb or console
command, so parity holds by construction.

### 4A.1 One method table

`coordinator_ipc.nim` declares each method once: its name, a one-line summary, its
parameter and result shapes, and a `mutates` flag. That one table drives the
dispatcher, `runtime.methods`, the CLI help and the MCP tool list. This follows the
same rule as MVP-INT-1: declare once, reference everywhere.

### 4A.2 New methods

| Method | Returns |
|---|---|
| `runtime.methods` | The method table: name, summary, params, result, mutates. |
| `runtime.describe` `{target}` | A Thing descriptor: id, scope path, manifest, WANTS, PROVIDES with signatures, tempo, status, child ids. |
| `runtime.call` `{thing, provide, args}` | Builds an occurrence, validates it through the prefilter, delivers it in the next frame and returns the result. A validation failure returns the redacted failure occurrence (MVP-VAL-4). |

`runtime.listThings` returns short descriptors (id, scope path, WHY), not just names.

### 4A.2a The Cosmos interface (MVP-AI-7)

The Cosmos root's PROVIDES are the method table (§4A.1). So `runtime.describe
{target: "cosmos"}` returns the runtime's operations as PROVIDES with their
signatures, and `runtime.call {thing: "cosmos", provide: "step"}` is the same as
`runtime.step`. `runtime.methods` is a shortcut for `describe cosmos`. An AI learns
one pattern, describe then call, and it works the same on the runtime and on every
Thing in it. The method table remains the single declaration, so nothing is
duplicated.

### 4A.3 Origin

Every request has an origin identity: the attached console identity, `params.origin`,
or `cli` by default. The MCP bridge sets `mcp:<client name>`. The origin is recorded on
the occurrences and records a request produces (MVP-PER-2 already carries `origin`), so
any change, by a person or an AI, can be traced to who made it.

### 4A.4 CLI for AI

Every method has a `cosmos` verb: `cosmos methods`, `cosmos describe <target>` and
`cosmos call <thing> <provide> [--args-json <json>]`, alongside the existing daemon
verbs. Each one prints the JSON response envelope, as the daemon verbs already do, and
uses the §4.4 exit codes. No verb prompts or needs a terminal, so a script or an AI
agent can drive the whole runtime from a shell.

### 4A.5 MCP bridge

`cosmos mcp [--port <N>]` is a stdio MCP server, a separate process that's a client of
the daemon, like `cosmos ipc`.

- **Tools:** one per method in `runtime.methods`, so `runtime.describe` becomes
  `cosmos_describe`. Descriptions and input schemas come from the method table.
- **No daemon:** the server stays up and each tool returns a clear "no daemon running
  on port N" error. It degrades instead of stalling.
- **Off means off:** if `cosmos mcp` isn't running, the daemon behaves exactly as
  before.

---

## 4B. Concepts and implementations

Designing Concepts and implementing them is the developer's main activity
(MVP-INT-5 to MVP-INT-7). A Concept is a Thing that serves as a template (MVP-ONT-7).

### 4B.1 One manifest form

Every Concept is a `manifest.json` in a bundle folder (§3.4). It holds:

- `who`, `why`, and any optional interrogatives;
- `wants` and `provides`, each with signatures;
- for a composite Concept, `parts` (named Concepts) and `wires`;
- for a Concept with no parts, `implementation` (§4B.2).

**Precedent:** `wrapExternalProcessThing` already pairs a handwritten manifest with an
implementation command. **Departs** from SPECIFICATION §19A.5 and §19A.7. Today, native Nim modules generate their contract
from code while external ones use a handwritten manifest. Under this rule, both use
the manifest. Nim code can still generate the file, but the file is the declaration.

### 4B.2 The input/output/error contract

An implementation exchanges one JSON object per line:

- **Input:** waves delivered to it, in the shape `runtime.call` uses: `provide`,
  `args`, plus `from` and `tick`.
- **Output:** waves it emits, `{"provide", "args"}`, and results, `{"result"}`.
- **Error:** `{"code", "message"}`. The Cosmos records each one as an occurrence. A
  crash or a malformed line suspends the Thing (MVP-SCH-3) and never stops the
  Cosmos (MVP-SAFE-1).

**In the MVP,** `implementation` names a Nim module, which may use C through
`{.importc.}`. It runs in-process through an adapter that passes these same messages.
The existing `etStdInStdOut` transport is the shape that separate-process
implementations will use later.

**Audio note (C5):** audio-rate signals never travel this way. An audio Concept's
implementation is its control part. Its signal part runs in the audio kernel.

### 4B.3 Composition

Instantiating a composite Concept creates a Thing whose children are one Thing per
part, at scope paths under it (`cosmos.synth.filter`), plus one wire Thing per wire.
Its own `wants` and `provides` are wired to its parts' ports. Other Things connect to
those, not to the parts directly. `runtime.describe` can still show everything inside.
A patch is a composite Concept, which is what compiles into the audio kernel's graph.

---

## 5. Console

`cosmos console [--attach <identity>] [--watch <path>]`. The identity defaults to
`operator`.

- **Fix:** today `runtime.attach` stores the console session under the request's `id`,
  so the following render and dispatch requests, which have different ids, get a fresh
  detached session. Instead, `attach` returns a `session` token. `console_render`,
  `console_dispatch` and `detach` must send `params.session`. An unknown token gets
  `invalid_request`.
- `exit` sends `runtime.detach` and then exits 0. `Ctrl+C` in `watch` returns to the
  layout (MVP-CON-6).
- With no daemon, it prints the §4.4 message and exits 1.
- `console_main` is removed once its tests have moved here (MVP-CON-7).

---

## 6. CLI routing

`runCoordinatorMain` dispatches on the first argument before calling `parseArgs`:

| First argument | Handler | Notes |
|---|---|---|
| none, `--help`, `-h` | help text, exit 0 | Starts nothing (MVP-CLI-1). |
| `start` | §3.2 | |
| `stop`, `inspect`, `list`, `step`, `mode`, `add`, `remove`, `methods`, `describe`, `call` | IPC (§4, §4A.4) | |
| `mcp` | §4A.5 | |
| `console` | §5 | |
| `startapp`, `capabilities`, `concept`, `capability`, `scan`, `ipc`, `notify` | existing `run…Command` procs | These are present but unreachable since `f71f93a` (MVP-CLI-6). |
| anything else | usage text, exit 2 | MVP-CLI-8. |

**Known tension:** "mode" means two things. Config `mode` (`COSMOS_MODE`) is
`development|debug|production`, and `start --mode` is the frame strategy. The MVP keeps
both as they are. Renaming one is a later decision.

---

## 7. The startapp loop

The MVP's headline test: three commands from nothing to an inspected Thing.

```
cosmos startapp hello
cosmos start --with hello        # in its own terminal (§3.2)
cosmos inspect hello
```

`startapp` must write `manifest.json` (`id`, `version`, plus WHO and WHY), the format
`loadCosmosBundle` reads. Today it writes `cosmos.toml` and `build-manifest.json`,
which nothing in `src/` reads. Drop them unless something starts reading them.

---

## 8. Gate

- **Discovery, not a list (MVP-GATE-1).** `nimble test` runs every `.nim` file under
  `tests/` except `tests/harness.nim`. Adding a file adds it to the gate.
- **No hangs (MVP-GATE-3).** Each file runs under a 90-second limit. Hitting the limit
  is a failure.
- **Fast check (MVP-GATE-4).** `nimble checkFast` skips tests that import `net` or
  `osproc` (sockets and processes). Tests stay in their existing folders.
  `coordinator_test` starts the daemon without importing either, so until Phase 2 it
  still runs in the fast check and uses its full time limit.
- **Daemon tests.** Start `cosmos start` as a subprocess with `COSMOS_PORT` set to a
  free port. Wait up to 5 seconds for `runtime.ping`. Run the test. Stop the daemon
  with `runtime.stop`, and kill the process if it hasn't exited within 5 seconds.
- **Clone-safe (MVP-GATE-2).** Nothing the gate reads may be ignored or untracked:
  - `.github/ND_DOCS_CHECKLIST.md` exists nowhere: not on disk and not in history.
    Recreate it as `docs/implementation/ND_DOCS_CHECKLIST.md`, which is tracked.
  - `scripts/build/*.ps1` exists nowhere either. `.gitignore`'s `build/` matches
    `scripts/build/`. Anchor it as `/build/`, and make `buildRuntime` a direct
    `nim c -d:release` command.
  - CI workflows are deferred, since the MVP targets one machine.
- **Known failures are listed, not hidden.** `tests/KNOWN_FAILURES.txt` names each file
  expected to fail, with its reason and the phase that fixes it. The gate reports
  those files as KNOWN and still passes. A listed file that starts passing fails the
  gate until its line is removed, so the list can't go stale. The runner is
  `scripts/verify/run_tests.ps1`.
- **Proc-style tests count.** Files that use `assert` in `proc`s, rather than
  `unittest`, pass by exit code. Converting them is optional.

---

## 9. Phases

The plan sequences these. Each phase ends when its rows in the compliance matrix are
**Verified**.

| Phase | Scope | Commitment (C1) |
|---|---|---|
| **1. Trustworthy gate** | §8. Fix the compile errors. Bring every file into the gate, passing or recorded as a known failure. | Committed |
| **2. Daemon, CLI and AI access** | §3–§6, including §4A | Committed |
| **3. The startapp loop** | §7, §4B (manifest, Nim implementation, one composite example) | When the audio project needs it |
| **4. Close matrix gaps** | Remaining Gap rows | When the audio project needs it |

Phase 2 is building work, not just repair. The daemon's IPC side was never connected
to the runtime.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
