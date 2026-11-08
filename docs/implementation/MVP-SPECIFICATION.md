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

These keep the MVP in service of its first real use: personal music tools with a
hardware feel. They apply to every phase.

- **C1 — Timebox Cosmos.** Phases 1 to 3 (the gate, the daemon and CLI, then the
  startapp loop with Concepts, waves and wires) are committed. Phase 4 goes ahead
  when a project needs it, not to make Cosmos complete for its own sake. Revised on
  2026-11-05: Phase 3 used to wait on the audio project, but Cosmos is for building
  anything, and every use needs Concepts that compose.
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
| 1. Ontology | §4, §4.1, §4.1A, §4.1B | One kind of entity plus properties of the Cosmos (MVP-ONT-1, MVP-ONT-8). §4.1C–§4.1D (context, overrides) are retired (MVP-ONT-11). §4.1E (references) is deferred. The how for MVP-ONT-7 to MVP-ONT-11 is §4C below. |
| 2. Lifecycle | §5, §5A | None. |
| 3. Persistence | §2 | Records are stored CLEAR. Encrypted record is deferred. |
| 4. Validation | Validating Prefilter sections | Rules are built from declarations, and every way in is listed (§4D). |
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
[--loglevel <trace|debug|info|warn|error>] [--port <N>]`

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
- **`--mode periodic`:** run frames at the configured frame rate.
- While paused, the frame loop keeps draining the queue. Only frames stop.
- `runtime.describe`, `runtime.listThings` and the console read the lifecycle's real
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

### 3.6 Logs

This gives the host events of SPECIFICATION.md §5A somewhere to go (MVP-LIFE-8).

- **Where.** Each host event is one JSON line, written to the daemon's terminal (the
  error stream) and to `logs/cosmos.log` in the runtime home (`home.nim`). `logs/` is
  already part of that tree.
- **Two runs kept.** `cosmos start` renames an existing `cosmos.log` to
  `cosmos.previous.log`, replacing any older one.
- **Levels.** `trace`, `debug`, `info`, `warn` or `error`, from the loaded config
  (MVP-CFG-2). `evError` and `evReconcileHalt` are `error`. Other host events are
  `info`. Events below the level are not written. Production mode can't go below
  `info`, which is the existing rule.
- **Degrade.** If the file can't be written, the daemon prints one warning and carries
  on (MVP-SAFE-1).
- **Reading.** `cosmos logs [--last <N>]` prints the last lines of the file, 50 by
  default. It reads the file directly and needs no daemon, so it works after a crash
  (MVP-SAFE-2).

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
| `runtime.step`, `pause`, `resume`, `snapshot` | Rewire | Act on the lifecycle through the queue (§3.3). `runtime.step` returns the frame number and the answers to any calls completed in that frame (§4A.2b). |
| `runtime.addThing`, `removeThing`, `listThings` | Rewire | Use real user Things (§3.4). |
| `runtime.setMode` | Rewire | Validate against `step|continuous|periodic` and apply it. |
| `runtime.addWatch`, `removeWatch`, `listWatch`, `subscribe`, `unsubscribe` | Keep | |
| `runtime.attach`, `console_render`, `console_dispatch` | **Fix** | See §5. |
| `runtime.detach` | **New** | Ends a console session. |

`runtime.start` and `runtime.restart` are removed from the client mapping. Starting is
a process action (§3.2), and `restart` is deferred. Until it returns, `cosmos restart`
is an unknown command (MVP-CLI-8).

`runtime.inspect` is retired. `runtime.describe {target: "cosmos"}` returns the same
state (§4A.2a). **Departs** from the required `inspect` method in SPECIFICATION.md's
Phase XC section: with `describe` in place, it would be a second way to do one thing.

### 4.4 Client rules

- Connect and read time out after 2 seconds. A timeout prints `cosmos: daemon on port
  N not responding` and exits 1. Nothing waits forever (MVP-SAFE-1).
- **Exit codes:** 0 means success. 1 means no daemon, a timeout or a transport failure.
  2 means a usage error or an error response from the daemon. This matches the current
  code.

---

## 4A. AI access

AI is a first-class user (MVP-AI-1 to MVP-AI-8). The design rule: **the IPC contract
is the one surface.** The CLI, the console and the MCP bridge are all clients of it,
and an AI can use either the CLI or MCP. REST is deferred. It would be another thin
client of the same table, so adding it later changes nothing underneath.
A new capability is added as an IPC method first, then mapped to a CLI verb or console
command, so parity holds by construction.

### 4A.1 One method table

`coordinator_ipc.nim` declares each method once: its name, its CLI verb, a one-line
summary, its parameter and result shapes, a `mutates` flag and a `needsDaemon` flag.
That one table drives the dispatcher, `runtime.methods`, the CLI verbs and help, and
the MCP tool list. This follows the same rule as MVP-INT-1: declare once, reference
everywhere.

A method with `needsDaemon: false` runs in the client process, with no connection to
the daemon. These are `startapp`, `capabilities`, `concept`, `capability`, `scan`,
`notify` and `logs`. Their handlers are the existing `run…Command` procs, plus §3.6.

### 4A.2 New methods

| Method | Returns |
|---|---|
| `runtime.methods` | The method table: name, summary, params, result, mutates. |
| `runtime.describe` `{target}` | A Thing descriptor: id, scope path, manifest, WANTS, PROVIDES with signatures, rhythm, status, child ids. |
| `runtime.call` `{thing, provide, args}` | Validates a wave through the prefilter and delivers it on a one-time wire in the next frame (§4A.2b). A validation failure returns the redacted failure change (MVP-VAL-4). |
| `runtime.history` `{last?, frame?, thing?}` | History rows, newest last. With no parameters, the last 20. `frame` returns that one frame. `thing` keeps only the changes involving that Thing and skips rows left empty. |
| `runtime.logs` `{last?}` | The last lines of the log file (§3.6). `needsDaemon: false`. |

`runtime.listThings` returns short descriptors (id, scope path, WHY), not just names.

### 4A.2a The Cosmos interface (MVP-AI-7)

The Cosmos root's PROVIDES are the method table (§4A.1). So `runtime.describe
{target: "cosmos"}` returns the runtime's operations as PROVIDES with their
signatures, and `runtime.call {thing: "cosmos", provide: "step"}` is the same as
`runtime.step`. `runtime.methods` is a shortcut for `describe cosmos`. An AI learns
one pattern, describe then call, and it works the same on the runtime and on every
Thing in it. The method table remains the single declaration, so nothing is
duplicated.

The Cosmos's status holds the runtime state: `paused`, the frame strategy, the current
frame, `health`, `reconciliation`, `snapshotRevision`, `watchedPaths` and the frame
rate. A call to the Cosmos runs the matching method directly, with no wave or ticket.

### 4A.2b Calls

`runtime.call` is how an operator asks a Thing to act.

- **Route.** The Cosmos creates a one-time wire from itself to the Thing, carrying one
  wave (MVP-ONT-8). The wave has no address (§4C.3). Only operators can do this: an
  implementation's output has no form for it (§4B.2), so scope still holds (§4C.6).
- **Ticket.** Each call gets a ticket: a number unique within the daemon's run. The
  input line carries it, and the implementation's `result` line returns it (§4B.2).
- **Reply.** If the answer arrives within 1 second, the response is
  `{"ticket", "result"}`. Otherwise the response is `{"ticket", "status": "waiting"}`,
  sent after that 1 second, or at once while paused. Either way it arrives before the
  client's 2-second limit (§4.4).
- **Answers that come later.** Every answer is recorded as a `result` change (§4C.5).
  While stepping, `runtime.step` returns the answers from its frame. At other times,
  `cosmos history --thing <name>` shows them.
- **No answer.** A Thing that never answers blocks nothing. Its ticket simply never
  gets a `result` change.

### 4A.3 Origin

Every request has an origin identity: the attached console identity, `params.origin`,
or `cli` by default. The MCP bridge sets `mcp:<client name>`. The origin is recorded on
the changes and persisted entries a request produces (MVP-PER-2 already carries `origin`), so
any change, by a person or an AI, can be traced to who made it.

### 4A.4 CLI for AI

Every method has a `cosmos` verb, generated from the method table (§4A.1), with no
exceptions. That includes `cosmos methods`, `cosmos describe <target>`, `cosmos call
<thing> <provide> [--args-json <json>]`, `cosmos history [--last <N>] [--frame <N>]
[--thing <name>]` and `cosmos logs [--last <N>]`, alongside the existing daemon verbs.
Help shows common verbs first and the console's own methods last. Each one prints the JSON response envelope, as the daemon verbs already do, and
uses the §4.4 exit codes. No verb prompts or needs a terminal, so a script or an AI
agent can drive the whole runtime from a shell.

### 4A.5 MCP bridge

`cosmos mcp [--port <N>]` is a stdio MCP server, a separate process that's a client of
the daemon, like `cosmos ipc`.

- **Tools:** one per method in `runtime.methods`, so `runtime.describe` becomes
  `cosmos_describe`. Descriptions and input schemas come from the method table.
- **No daemon:** the server stays up. Tools with `needsDaemon: false` still work. The
  others return a clear "no daemon running on port N" error. It degrades instead of
  stalling.
- **Off means off:** if `cosmos mcp` isn't running, the daemon behaves exactly as
  before.

---

## 4B. Concepts and implementations

Designing Concepts and implementing them is the developer's main activity
(MVP-INT-5 to MVP-INT-7). A Concept is a Thing that serves as a template (MVP-ONT-7).

### 4B.1 One manifest form

Every Concept is a `manifest.json` in a bundle folder (§3.4), with the fields set by
MVP-INT-5. The keys are uppercase, following `ManifestStringKeys` and
`ManifestSeqKeys` in `manifest.nim`:

- `WHO` (the identity and id), `VERSION`, and the interrogatives WHAT, WHY, WHERE,
  WHEN, HOW, REQUIRES, WANTS, PROVIDES and WITH. PROVIDES and WANTS carry
  signatures (§4D.3);
- `SENSES`: the wave kinds the Thing perceives;
- for a Concept with no parts, `IMPLEMENTATION` (§4B.2);
- for a composite Concept, `PARTS` (named Concepts) and `WIRES`.

**Precedent:** `wrapExternalProcessThing` already pairs a handwritten manifest with an
implementation command. **Departs** from SPECIFICATION §19A.5 and §19A.7. Today, native Nim modules generate their contract
from code while external ones use a handwritten manifest. Under this rule, both use
the manifest. Nim code can still generate the file, but the file is the declaration.

### 4B.2 The input/output/error contract

An implementation exchanges one JSON object per line:

- **Input:** waves delivered to it, in the shape `runtime.call` uses: `provide`,
  `args`, plus `from` and `frame`. A call also carries `ticket`, which is how the code
  tells a request from a wave it heard. On a call, `provide` names the Thing's own
  PROVIDES. On any other wave, it names the sender's.
- **Output:** waves it emits, `{"provide", "args"}`, results, `{"ticket", "result"}`,
  and its own state, `{"status"}` (§4C.3).
- **Error:** `{"code", "message"}`. The Cosmos records each one as a change in the history. A
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
part, at scope paths under it (`cosmos.synth.filter`). Its wires connect them. A wire
is a constrained wave, not a Thing (MVP-ONT-8), so it has no scope path. Its own
`wants` and `provides` are wired to its parts' ports. Other Things connect to those,
not to the parts directly. `runtime.describe` can still show everything inside. A
patch is a composite Concept, which is what compiles into the audio kernel's graph.

**Wire form.** Each entry in WIRES names an origin and one or more destinations:

```json
{"from": "keys.notes", "to": ["osc", "display"]}
```

`from` uses the MVP-INT-1 reference form. `keys` carries every wave on its output, and
`keys.notes` carries only the waves whose `provide` is `notes` (§4B.2). The output
stays one stream, and the wire selects from it by `provide`. `to` lists the
destinations, whose input receives those waves.

**Wire check.** The origin's PROVIDES declare what its output can carry, and each
destination's WANTS declare what its input accepts. When the Concept loads, the
capability graph compares what the wire carries (one PROVIDES, or all of them) with
each destination's WANTS, using the check it already runs for every WANTS
(`capabilities.nim`, MVP-INT-3). If any destination can't accept something the wire
carries, a structured diagnostic names the wire and that destination. The Concept is
then skipped with a warning (MVP-LIFE-3), and startup continues. No wave travels on a
wire that hasn't passed this check. The payload of each wave is still validated by the
prefilter (MVP-VAL-3).

---

## 4C. Ontology

This is how MVP-ONT-7 to MVP-ONT-11 are built. It changes the types in `thing.nim`
and `wave.nim`, the frame loop in `scheduler.nim` and root setup in `core.nim`. The
module registry, bundle loader internals and specialist code stay as they are.
Folding them in is later work (MVP-ONT-7).

### 4C.1 The tree

```
cosmos                  the root, made from nothing
cosmos.concepts         holds every loaded Concept
cosmos.concepts.hello   the Concept hello: a template
cosmos.hello            a Thing made from hello
```

- **Concepts.** Loading a bundle (§3.4) registers its manifest in the Concept
  registry (`concepts.nim`) and creates a Concept Thing at `cosmos.concepts.<WHO>`.
  Its status is its manifest, so `runtime.describe` shows it like any Thing. A
  Concept Thing is a template: it has no rhythm, never runs in a frame and receives
  no waves.
- **The `concepts` Thing** is made from a built-in Concept the runtime declares (WHO
  `concepts`, WHY "holds the Concepts loaded in this Cosmos"). That Concept sits under
  it like any other. So every Thing except the root is an instance of a Concept.
- **Instances.** `--with` and `cosmos add thing` then create an instance at
  `cosmos.<WHO>`, as §3.4 says. A composite's parts sit inside it (§4B.3).
  `Thing.conceptId` already records which Concept a Thing comes from.
- **Reserved name.** `concepts` is reserved at the root, the same way the root's own
  id is (`tlsSkippedReservedRoot`). A bundle whose WHO is `concepts` is skipped with
  a warning (MVP-LIFE-3).

### 4C.2 WHY

A Thing's WHY is the one it states (in its PARTS entry or the `addThing` params), or
else its Concept's (MVP-ONT-2). `runtime.describe` shows the WHY and whether it came
from the Thing or the Concept, so nobody has to work it out. If neither has one, the
Thing is skipped with a structured error (MVP-LIFE-3).

### 4C.3 Waves

- **Type.** The `Wave` stub in `wave.nim` becomes the real wave: `source` (a Thing
  id), `provide` (its kind), `args`, `frame` and `origin` (§4A.3). The falloff hook
  `projectionRadius` moves to it from `Occurrence`, still unused.
- **Kind.** A wave's kind is its `provide` name, which every output line already
  carries (§4B.2).
- **No addresses.** A wave has no destination field. Where it goes is decided only by
  wires and senses (§4C.4), so a Thing can't reach outside its scope by addressing.
  An operator's call uses a one-time wire (§4A.2b).
- **State.** An implementation reports its own state with an output line
  `{"status": {...}}`, which replaces its status and is recorded as a change. This
  joins the output forms in §4B.2. An output line in any other form is malformed
  (§4B.2).

### 4C.4 Delivery

At the end of frame N, the Cosmos routes every wave emitted during it:

1. **Wired.** If any wire's `from` matches the wave (its source, and its `provide`
   when the wire names one), the wave goes to those wires' destinations only. It
   doesn't radiate (MVP-ONT-8).
2. **Global.** Otherwise it radiates: every Thing whose SENSES lists the wave's
   `provide`, by exact name, perceives it. There are no patterns or wildcards.
3. **Next frame.** Each Thing receives its waves in its input at the start of frame
   N+1, ordered by source id, then by the order they were sent.

Delivering in the next frame means the order Things run in within a frame never
changes what they hear, so the same state and the same waves always give the same
frame (MVP-SCH-1). The scheduler's per-Thing `incoming` list already has this shape.

- Suspended Things and Concept Things receive nothing.
- A wave that matches no wire and no sense is still recorded. Nothing perceives it.
- `filterOccurrence`, which accepts everything today, is replaced by this routing.
  `Thing.perceptionLog` is dropped, because what a Thing perceived follows from the
  history (§4C.5).

### 4C.5 The history

- **Rows.** One row per frame: `{"frame": N, "changes": [...]}`. The frame is the
  scheduler's `epoch`.
- **Change kinds:**
  - `wave`: source, provide, args. A call also records its destination and ticket;
  - `result`: the answer to a call, with its ticket;
  - `status`: a Thing's new state;
  - `added` and `removed`: a Thing and its Concept;
  - `failure` and `suspended`: from the scheduler's `FrameResult`;
  - `rejected`: a prefilter failure change (MVP-VAL-4);
  - `request`: an operator's request applied by the frame loop (§3.3), with its
    method.

  Every change carries `origin` (§4A.3). Changes keep the order the frame produced
  them in.
- **No duplicates.** Deliveries aren't recorded. They follow from the row's waves and
  the wires and senses in place, and those change only through recorded `added` and
  `removed` changes. A call's one-time wire leaves no other trace, so its `wave` change
  names the destination. The history replays without storing anything twice.
- **Storage.** Each row is one persisted entry, key `frame-<N>`, written through the
  existing layer the code calls RECORD (`writeRecordEntry`) and committed at the end
  of its frame. A frame with no changes writes nothing. Reading it returns an empty
  row.
- **Code.** `emitOccurrence` and the scheduler's `makeOccurrence` become change
  builders, and `Occurrence` becomes the row type. `FrameResult.emitted` becomes the
  row's `wave` changes, and the frame digest is computed over the row.
- **Later.** Renaming `RECORD` in the code, and the console's `blip` and `morphos`
  (MVP-ONT-9).

### 4C.6 Scope

Scope (MVP-ONT-10) is enforced by construction, not by a check on every action:

- An implementation receives only its own input and writes only its own output and
  errors (§4B.2). It holds no handle to any other Thing.
- Its output can only change its own status and send waves, and it can't choose
  where they go (§4C.3).
- In the MVP, only a Thing with no parts runs code (MVP-INT-7), so a composite
  reaches its interior only through its wires.
- Operators act through the Cosmos's interface (§4A.2a), whose scope is everything.
  Every request passes the prefilter and is recorded with its origin (MVP-AI-4).

### 4C.7 No inheritance

- Remove `Thing.overrideDeltas` and `applyOverrides`. `resolveContext` stops merging
  config, capabilities, logs and relationships down from ancestors, and returns only
  the Thing's own. Nothing in the runtime calls these today. Only
  `ch4_ontology_test` and `resolveReference` do.
- `resolveReference` returns the target id and its local metadata, with no merged
  context ("a reference no longer inherits target context", MVP-ONT-11).
- `thingFromJson` ignores an `overrideDeltas` field in saved data, so older saved
  Things still load.
- The override cases in `ch4_ontology_test` are replaced by a test that proves a
  parent's config never reaches its child.

---

## 4D. The data firewall

No bad data reaches a Concept's code (MVP-VAL-2, MVP-VAL-3, MVP-VAL-5).

**Current state:** `prefilterValidate` in `validation.nim` works and is tested, but
nothing in `src/` calls it. `prefilter_table_generated.nim` holds one hand-written
entry, `runtime.Ping`, and no generator exists. `stepActivatePrefilter` checks the
table and then discards it.

**Reuse.** The checker, its masks and `ValidationRecord` stay, with the fixes in §4D.2,
§4D.5 and §4D.6.

### 4D.1 One table

The lifecycle owns one `ValidationIndex` for the life of the daemon.

| Rows come from | Built |
|---|---|
| The method table's parameter shapes (§4A.1) | At startup step 6, before any input is accepted |
| Each Concept's PROVIDES signatures (§4B.1) | When the Concept loads, before any Thing made from it runs |

- `prefilter_table_generated.nim` is removed. Its tests move to the method table's rows.
- The existing halt on an empty table stays. Method rows mean it should never fire.
- New rows are added by the frame loop, between frames (§3.3).
- Every row is built at startup or load, so no schema is parsed on the hot path.
- `needsDaemon: false` methods use the same rows, in the client process.

### 4D.2 Names match exactly

The index stops lowercasing names, which is the same rule senses use (MVP-ONT-8). Its
lookup key is length-prefixed, as the signature digest is. So `Notes` and `notes`, or
`a|b` + `c` and `a` + `b|c`, can never share a lookup entry. A row that would collide
is a load error.

### 4D.3 Signatures

A signature is the text that `capabilities.nim` already compares:
`(argument,argument)->result`.

| Word | Accepts |
|---|---|
| `string`, `int`, `float`, `bool`, `array`, `object`, `null` | That JSON type |
| `json` | Any JSON value. The field isn't checked further, and `describe` shows that |
| `{pitch:int,label?:string}` | An object with these fields. `?` marks an optional field. A field not listed is rejected |

- Fields are checked one level deep in the MVP. A field that holds more can use `json`
  or `object`.
- A wave's `args` is a JSON array with one item per argument.
- At load, a signature is parsed once and rewritten in one standard form, with no
  spaces and with fields sorted. The capability graph compares that form.
- An unknown word, or more than 64 fields (the mask limit), is a structured diagnostic.
  The Concept is skipped with a warning (MVP-INT-3, MVP-LIFE-3).
- The part after `->` is compared by the capability graph. It isn't checked at run time.

### 4D.4 Every way in

| Way in | Checked against | On failure |
|---|---|---|
| A command request | That method's row | `invalid_request` response, and a `rejected` change |
| A command that needs no daemon | That method's row | Usage error, exit 2 |
| `runtime.call` | The called Thing's PROVIDES row | The redacted failure is returned, a `rejected` change is recorded, and nothing is delivered |
| A wave on an implementation's output | The sender's PROVIDES row for that name | A `rejected` change is recorded, and nothing is routed. It counts as a failure for MVP-SCH-3 |

- A wave whose name has no row in its sender's PROVIDES is rejected as an unknown
  signature.
- Each check runs where the data arrives, so a wave is checked once, before routing.
- Answers and `status` lines go to operators and the history, not to other Things. They
  are only checked for line form (§4B.2).
- A failed check never shows the bad data. It records the rule, a digest and the size
  (MVP-VAL-4).

**Other ways in have their own checks,** which stay as they are: config (MVP-CFG-3),
saved data (MVP-PER-2) and manifests (MVP-INT-3).

**Inside Cosmos,** the Nim compiler guarantees the types passed between procs. The
guards from MVP-VAL-1 also stay. The table doesn't replace them.

### 4D.5 No route can skip it

Delivery to an implementation, and the handler for each method, accept a passed
`PrefilterDecision` rather than raw JSON (`dispatchValidated` already has this shape).
A new route that forgets the check doesn't compile.

The decision's fields are private, so only `prefilterValidate` can produce a pass.

MVP-VAL-3 needs a test that sends a bad request through the real command path and proves
the handler never ran. A test that calls the checker directly doesn't prove it.

### 4D.6 Bullet-proof

This is how MVP-VAL-6 is met.

**It never fails open.**

- The whole check runs inside one error boundary. Any error is a rejection.
- A nil value is rejected.

**It is bounded.** These are starting values.

- A message over 1 MiB is rejected before it is parsed.
- Nesting deeper than 64 levels is rejected before parsing.
- The server drops a client that hasn't sent a complete line within 2 seconds.
- A wrong argument count is rejected without scanning the table.

**It is exact.**

| Rule | Requirement |
|---|---|
| Any type | A matching plain value passes |
| `int` | A whole number that fits in 64 bits |
| `float` | A finite number. Infinity and NaN are rejected |
| `string` | Valid UTF-8 with no NUL character |
| A number too large for `int` | Rejected, including where any value is allowed |
| Unknown fields | Always rejected |

`efIgnoreUnknown` and `efAllowUnknown` are removed. **Departs** from the extra-field
policies in REQUIREMENTS Validating Prefilter: the first silently changes data, and the
second lets unchecked data through.

**A message is parsed once.** The value that was checked is the value delivered.

**It reveals nothing.**

- A failure's `rulePath` only contains names from the rule. An unknown field is reported
  as `$unknown`, never by its own name.
- Every value written to a log line, including `source`, is escaped, so it can't start a
  new line.

**Proof in the gate:**

- One test per defect in MVP-PLAN.md, written to fail before its fix.
- One rejection test for each rule above.
- A randomized test with a fixed seed. It proves no crash, and that nothing invalid
  passes. The fixed seed keeps it deterministic.

Testing can't prove there are no bugs left. This bar means every known kind of attack is
covered, and every new one gets a test.

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
| any verb in the method table (§4A.1) | IPC (§4, §4A.4), or in the client when `needsDaemon` is false | Includes `stop`, `list`, `step`, `mode`, `add`, `remove`, `methods`, `describe`, `call`, `history` and `logs`. |
| `mcp` | §4A.5 | |
| `console` | §5 | |
| `startapp`, `capabilities`, `concept`, `capability`, `scan`, `notify` | method table, `needsDaemon: false` (§4A.1) | Existing `run…Command` procs, unreachable since `f71f93a` (MVP-CLI-6). |
| `ipc` | existing `runIpcCommand` | Sends a raw request. It's a client, not an action, so it isn't in the method table. |
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
cosmos describe hello
```

`startapp` must write `manifest.json` in the one manifest format (§4B.1), with at
least WHO, VERSION and WHY. `loadCosmosBundle` must read that format. Today it writes `cosmos.toml` and `build-manifest.json`,
which nothing in `src/` reads. Drop them unless something starts reading them.

---

## 8. Gate

- **Discovery, not a list (MVP-GATE-1).** `nimble test` runs every `.nim` file under
  `tests/` except `tests/harness.nim`. Adding a file adds it to the gate.
- **No hangs (MVP-GATE-3).** Each file runs under a 90-second limit. Hitting the limit
  is a failure.
- **Daemon tests are found by a rule.** A file that imports `net`, `osproc` or
  `cosmos_main` can open sockets, start processes or start the daemon, so it's a
  daemon test. Tests stay in their existing folders.
- **Parallel (2026-11-05).** Files are built and run up to one per processor at a
  time. Daemon tests can reach the daemon's port, so they run one at a time, alongside
  the others. `-Jobs 1` runs everything one at a time. Results print as each file
  finishes. On the development machine: 96 s for the full gate (most of it
  `coordinator_test` waiting out its limit until Phase 2), down from about 210 s.
- **Fast check (MVP-GATE-4).** `nimble checkFast` skips daemon tests: 22 s for 46
  files on the development machine.
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

[MVP-PLAN.md](MVP-PLAN.md) sequences these and holds the reference deployment. Each
phase ends when its rows in the compliance matrix are
**Verified**.

| Phase | Scope | Commitment (C1) |
|---|---|---|
| **1. Trustworthy gate** | §8. Fix the compile errors. Bring every file into the gate, passing or recorded as a known failure. | Committed |
| **2. Daemon, CLI and AI access** | §3–§6, including §4A, and §4D for commands | Committed |
| **3. The startapp loop** | §7, §4B (manifest, Nim implementation, one composite example), §4C (ontology), §4D for Things and waves | Committed |
| **4. Close matrix gaps** | Remaining Gap rows | When a project needs it |

Phase 2 is building work, not just repair. The daemon's IPC side was never connected
to the runtime.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
