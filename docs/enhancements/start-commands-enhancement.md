Cosmos Runtime — Architecture PromptEmpty Boot, Hot‑Load, Git‑Style CLI, Developer Sovereignty,
Transparent Packaging, and Introspection‑Only Modes

1. Single Entry Point and Daemon Model

The Cosmos runtime has a single, stable entry point:

cosmos start [--flags]

This always starts (or attaches to) the long‑running daemon. There is no
separate “dev server” or alternate executable. This makes Cosmos easy to
wrap with systemd, Windows Task Scheduler, launchd, Docker, etc.

The daemon is responsible for:
- booting the substrate
- starting the scheduler
- running the frame loop
- exposing introspection surfaces
- managing watched locations and installed Things

2. Empty Boot

The runtime must be able to start in an empty state with:

- no Things
- no constellations
- no manifests

Booting the runtime initializes only:
- the substrate
- the scheduler
- the frame loop
- the introspection surfaces

No application code is required to start the runtime.

3. Git‑Style Command Structure

Cosmos uses a Git‑like CLI grammar:

cosmos <verb> <object> --flags

Examples:

Daemon lifecycle:
cosmos start --mode=aware
cosmos start --mode=step
cosmos stop
cosmos restart

Watch management:
cosmos add watch /path/to/app
cosmos remove watch /path/to/app
cosmos list watch

Thing management:
cosmos add thing screenkeys.cosmos
cosmos remove thing screenkeys
cosmos list things

Mode switching:
cosmos mode step
cosmos mode debug
cosmos mode clear
cosmos mode encrypted

Introspection:
cosmos inspect world
cosmos inspect thing screenkeys
cosmos inspect events
cosmos inspect busses

Frame control:
cosmos step
cosmos step --count=10

This structure is explicit, composable, and predictable.

4. Watch Management (Pull Model)

The runtime does not assume any fixed folder structure. Instead, the
developer explicitly declares which directories the daemon should watch:

cosmos add watch /path/to/app
cosmos remove watch /path/to/app
cosmos list watch

Watched directories are where constellations/Things live. The runtime:

- watches these paths
- detects new or changed files
- hot‑loads or reloads Things
- surfaces errors loudly

No magic discovery. No required boilerplate tree. The developer chooses
where their code lives.

5. Thing Management and Transparent Packaging

A Thing can be installed explicitly via a `.cosmos` bundle:

cosmos add thing screenkeys.cosmos
cosmos remove thing screenkeys
cosmos list things

A `.cosmos` bundle is:

- transparent (inspectable, unpackable)
- manifest‑driven
- not opaque like a JAR

Example structure (either as a folder or a simple archive):

screenkeys.cosmos/
manifest.json
src/
input_adapter.nim
assets/
icons/

The manifest defines:
- Thing id
- entry points
- capabilities
- dependencies

The runtime loads Things based on manifests, not folder names or conventions.

6. Hot‑Load Behavior and Error Semantics

Hot‑load must never fail silently.

When a Thing or manifest fails to load or reload, the runtime must produce:

- a clear error message
- the file path
- the line (or location) that triggered the failure
- the Thing or manifest id
- the invariant that was violated
- the expected shape or contract
- a suggested fix or next step

Hot‑load must be:
- deterministic
- explicit
- safe
- debuggable

No “it just didn’t load.” No silent failures.

7. Developer Sovereignty: Push vs Pull

Cosmos supports two workflows, chosen by the developer:

Pull mode (default):
- runtime watches directories (via `add watch`)
- changes are automatically detected and loaded
- gentle, ND‑ergonomic, low‑pressure

Example:
cosmos start --mode=aware
cosmos add watch ~/cosmos-apps

Push mode (optional):
- runtime does not auto‑watch
- developer explicitly triggers reloads or installs
- deterministic and intentional

Example:
cosmos start --no-watch
cosmos add thing screenkeys.cosmos
cosmos reload (or equivalent)

Both modes preserve identical runtime semantics. Only workflow changes.

8. Modes Are Introspection‑Only

Cosmos modes (step, aware, debug, encrypted, clear) must never change
runtime behavior or semantics. They only change visibility and control
over time.

- step:
- manual frame advancement
- world is frozen between frames
- safe, deterministic inspection

- aware:
- normal continuous frame loop
- Things run their lifecycles
- events flow normally

- debug:
- expanded introspection surfaces
- more logging
- routing tables, pending events, state diffs visible

- encrypted:
- hides sensitive state and payloads
- restricts certain introspection surfaces
- preserves invariants while protecting privacy

- clear:
- full transparency
- all introspection surfaces open
- all state and routing visible

Modes are like opening or closing blinds, not changing the room. They do
not alter execution order, semantics, or behavior. There is no “dev server”
vs “prod server” divergence.

9. No Dev/Prod Divergence

Cosmos must behave identically in all environments:

- same semantics in dev and prod
- same loading rules
- same error behavior
- same hot‑load behavior

There is no special “dev server” with different routing, static handling,
or caching. No Django‑style `runserver` vs Apache/nginx mismatch.

The runtime is a substrate, not a framework with multiple personalities.

10. Installers

Installers are allowed, but they must only perform explicit actions the
developer could perform manually, such as:

- installing `.cosmos` bundles:
cosmos add thing screenkeys.cosmos

- configuring watch paths:
cosmos add watch ~/cosmos-apps

- setting up OS‑level supervision:
systemd / Task Scheduler / launchd wrapping:
cosmos start [--flags]

Installers must not:
- introduce hidden behavior
- create opaque structures
- rely on implicit conventions
- perform magic discovery

They are thin convenience layers over explicit, deterministic operations.

11. Explicit‑Over‑Implicit Invariants

Cosmos avoids rigid boilerplate trees and opaque bundles, but it does not
sacrifice explicitness. Instead, explicitness is expressed through:

- manifests (declaring what exists and how it loads)
- explicit CLI verbs (add/remove/list/inspect/mode/start/stop)
- explicit watch paths
- explicit Thing installation
- loud, actionable errors
- transparent packaging

The runtime must never:
- guess based on folder names
- auto‑discover Things via magic patterns
- hide behavior behind conventions
- silently ignore failures

Filesystem layout is flexible. Meaning and behavior are explicit.

12. Core Runtime Invariants

- One substrate, one world.
- Single entry point: `cosmos start`.
- Empty boot is valid.
- Hot‑load is explicit, deterministic, and never silent.
- Modes never change semantics, only visibility and time control.
- Developer chooses push or pull workflow.
- No required boilerplate tree or rigid folder structure.
- Things are manifest‑driven and transparently packaged.
- Installers only automate explicit actions.
- No dev/prod behavioral divergence.

