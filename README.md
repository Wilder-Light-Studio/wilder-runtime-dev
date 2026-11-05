<p align="left">
  <img src="docs/assets/wilder-cosmos-v3.png" alt="Wilder Cosmos Logo" width="300"/>
</p>

# Wilder Cosmos

Cosmos is a way to build things logically, in a style suited to a Neurodivergent
(ND), ADHD mind: one kind of entity, uniform Concepts, visible wires, no hidden
behaviour, and a history of everything that happened. It's written in Nim.

It's for building anything. The first use is a set of personal music tools (a MIDI
editor and a synth), which live in their own projects and use Cosmos through its
public surface. Nothing audio-specific lives in this repository.

Contact: [teamwilder@wildercode.org](mailto:teamwilder@wildercode.org)

## The Model

- **Everything that exists is a Thing.** The Cosmos is the root Thing. A Thing's
  inside is its World, and its scope is itself and what it contains.
- **Concepts are templates.** A Concept is a Thing that serves as a blueprint, and
  every other Thing is made from one. Concepts compose: a Concept can be built from
  other Concepts and the wires between them.
- **Things talk only through waves.** A wave spreads across the whole Cosmos to every
  Thing with a matching sense. A wire is a wave constrained to a set origin and set
  destinations.
- **Time advances in frames.** The history has one row per frame: what happened, and
  when, in Cosmos time.
- **Explicit over implicit, always.** Nothing is inherited from a parent. A Thing
  knows only what its Concept declares, what it senses and what is wired to it.
- **AI is a first-class user.** Everything a person can do through the command line
  or console, an AI can do through the command line or the Model Context Protocol
  (MCP).

The full rules are in [MVP-REQUIREMENTS.md](docs/implementation/MVP-REQUIREMENTS.md).

## Status

Cosmos is being re-scoped to a Minimum Viable Product (MVP). [STATUS.md](STATUS.md)
always has the current state and the next tasks.

| Phase | Scope | State |
|---|---|---|
| 1. Trustworthy gate | Every test runs, nothing hangs, passes from a fresh clone | Done |
| 2. Daemon, CLI and AI access | `cosmos start`/`stop`, IPC, console, MCP | Next |
| 3. The startapp loop | Concepts, waves, wires, the history | Committed |
| 4. Close remaining gaps | Whatever the matrix still shows | When a project needs it |

**What works today:** the runtime core is built and tested: startup and shutdown,
three-layer persistence, the validating prefilter, the frame scheduler, capability
resolution and the console's command logic.

**What doesn't yet:** the daemon's command line is partly broken. Phase 2 fixes it.

- `cosmos start` runs the daemon, but `stop`, `list`, `add`, `remove` and `mode` fail
  with "method not found". Only `inspect`, `step` and `console` reach it.
- The daemon keeps its own list of Things, separate from the runtime.
- `cosmos --help`, `startapp`, `capabilities`, `concept`, `scan`, `ipc` and `notify`
  aren't reachable.
- The port is fixed at 7700.

## Quick Start

### Prerequisites

- Windows 11 (the MVP's target; Linux follows)
- Nim 2.0.8 and Nimble
- PowerShell, for the repository scripts

### Build and test

```powershell
nimble buildRuntime    # build bin/cosmos.exe
nimble verify          # the full gate: compliance check, then every test
```

The gate should end with `Gate passed.`: 46 tests pass and 4 are known failures,
listed with reasons in `tests/KNOWN_FAILURES.txt`. Phase 2 fixes all four.

### Run

`cosmos start` runs the daemon in the terminal you start it from. Use a second
terminal for other commands.

```powershell
bin\cosmos.exe start
```

The [Runtime CLI Guide](docs/public/getting-started/runtime-cli-guide.md) lists
every command, what it does today and what Phase 2 changes.

## Documentation

| Read this | For |
|---|---|
| [STATUS.md](STATUS.md) | Where things stand and what's next |
| [CHEATSHEET.md](CHEATSHEET.md) | Copy-paste commands |
| [MVP-REQUIREMENTS.md](docs/implementation/MVP-REQUIREMENTS.md) | What must be true |
| [MVP-SPECIFICATION.md](docs/implementation/MVP-SPECIFICATION.md) | How it's built |
| [MVP-COMPLIANCE-MATRIX.md](docs/implementation/MVP-COMPLIANCE-MATRIX.md) | Which requirements are proven, by which tests |
| [docs/public/index.md](docs/public/index.md) | Guides, concepts and API reference |
| [DEVELOPMENT-GUIDELINES.md](docs/implementation/DEVELOPMENT-GUIDELINES.md) | How to work in this repository |

The full [REQUIREMENTS.md](docs/implementation/REQUIREMENTS.md) and
[SPECIFICATION.md](docs/implementation/SPECIFICATION.md) are kept unchanged as the
long-term reference. Where they disagree with the MVP files, the MVP files govern.
Superseded material is in [archive/](archive/README.md).

## Repository Map

```text
src/
  cosmos/          Things, waves, scheduler, rhythm (tempo/), manifest
  runtime/         lifecycle, persistence, validation, IPC, console, config
  modules/         runtime modules
  cosmos_main.nim  the cosmos command
tests/
  unit/  integration/  uat/
  KNOWN_FAILURES.txt
docs/
  implementation/  requirements, specification, compliance matrix
  public/          guides, concepts, API reference
scripts/
  dev/             scaffolding helpers
  verify/          the gate (run_tests.ps1, check_requirements.ps1)
templates/         module and header templates
examples/
archive/           superseded and deferred material, kept for reference
```

## Development Workflow

1. Read the requirement you're changing in
   [MVP-REQUIREMENTS.md](docs/implementation/MVP-REQUIREMENTS.md).
2. Change the code and its tests.
3. Update the requirement's row in the compliance matrix.
4. Run `nimble verify`.

A phase is complete only when its tests pass in the gate. Continuous integration is
deferred while the MVP targets one machine. The Codeberg `.woodpecker.yml` predates
the MVP and isn't part of the gate.

## Module Scaffolding

To create a Nim module with the project's header comments (Summary, Simile, Memory
note, Flow), run without arguments for interactive mode:

```powershell
.\scripts\dev\new_nim_module.ps1
```

Header templates live in `templates/headers/`. The
[CHEATSHEET](CHEATSHEET.md) shows the full form with every argument.

## License

This project is licensed under the **Wilder Foundation License 1.0**. Read the full
license text in [LICENSE](LICENSE).

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
