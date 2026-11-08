# Cosmos Terms

What this is. This page is the one list of words used in Cosmos, in plain language.
It is written for a Neurodivergent (ND) reader: each entry stands alone.

The [plain-language guide](../../implementation/MVP-PLAIN-LANGUAGE.md) explains how the
ideas fit together. The exact rules are in
[MVP-REQUIREMENTS.md](../../implementation/MVP-REQUIREMENTS.md).

**Keeping this list current:** a new word is added here in the same change that first
uses it. A word that stops being used moves to [Retired Words](#retired-words).

## What Exists in a Cosmos

- **Thing:** The only kind of entity. Everything that exists is a Thing.
- **Thing id:** The permanent unique number Cosmos gives a Thing when it is created.
- **Cosmos id:** The permanent unique id a Cosmos receives on its first run.
- **Label:** A Thing's readable name. It can change, and nothing internal depends on it.
- **The Cosmos:** The top-level Thing. Cosmos creates it at startup. It has no parent
  and holds every other Thing.
- **World:** The inside of a Thing: the Things it contains. A Thing and its World are
  one.
- **Concept:** A description that Things are made from, like a template. A Concept is
  also a Thing.
- **Composite Concept:** A Concept built from other Concepts and the wires between them.
- **Part:** A Concept used inside a composite Concept.
- **Scope:** What a Thing can act on: itself and what it contains.
- **Scope path:** A Thing's address, written with dots, such as `cosmos.synth.filter`.
- **Implementation:** The code that does a Thing's work.
- **Suspended:** Stopped from taking turns, usually after failing repeatedly. The rest
  of the Cosmos keeps running.
- **Module:** A Thing that extends Cosmos itself.
- **Bundle:** A folder holding a Concept's `manifest.json` file.
- **Bridge:** A Thing that connects Cosmos to something outside it.

## Declaring a Concept

- **Manifest:** The `manifest.json` file that declares a Concept.
- **Interrogatives:** The question-word labels in a manifest, written in capitals. WHO
  and WHY are the only required ones.
- **WHO:** Its name, which is also its identity.
- **WHY:** What it is for.
- **WHAT:** What it is.
- **WHERE:** Where it is stored.
- **WHEN:** When it acts. The older documents put a Thing's rhythm here.
- **HOW:** How it works.
- **REQUIRES:** What it must have to run.
- **WANTS:** Which providers it depends on.
- **PROVIDES:** What it offers as output. Each one works like a separate output jack.
- **WITH:** What it works alongside.
- **VERSION:** Which version of the Concept this is.
- **SENSES:** A Thing's inputs: each a wave name and the shape it accepts.
- **PARTS:** The Concepts a composite Concept is built from.
- **WIRES:** The connections inside a composite Concept.
- **IMPLEMENTATION:** The manifest entry that names a Thing's code.
- **Signature:** The exact shape of the data a WANTS or PROVIDES uses.

## Messages

- **Wave:** A message from a Thing. Without a wire, it spreads across the whole Cosmos.
- **Sense:** A wave name a Thing listens for. The name must match exactly.
- **Wire:** A connection that sends a Thing's waves only to chosen Things. A wire is not
  a Thing.
- **One-time wire:** A wire the Cosmos makes for a single call. It carries one wave and
  then ends.
- **Ticket:** The number given to a call. The answer comes back with the same number.
- **Perception:** A Thing noticing a wave through a sense, or receiving one on a wire.
- **Payload:** The data carried inside a message.

## Time and History

- **Frame:** One round in which every Thing gets its turn. Cosmos counts time in frames,
  never clock time.
- **Epoch:** The code's name for the frame counter.
- **Change:** One thing that happened during a frame.
- **Occurrence:** One row of the history: a frame and all its changes. It can never be
  altered.
- **History:** The table of everything that has happened, with one row per frame.
- **Origin:** Who caused a change: a Thing, a person or an AI client.
- **Rhythm:** When a Thing acts: Event, Periodic or Continuous. The
  code calls it `TempoKind` until a later rename.
- **Event (rhythm):** Acts when something happens that it perceives.
- **Periodic (rhythm):** Acts at a fixed interval.
- **Continuous (rhythm):** Acts every frame.
- **Turn:** One Thing's chance to act in a frame, with a marked end and a time limit.
- **Frame rate:** How fast the running Cosmos runs frames in `periodic` mode.
- **Deterministic:** The same starting point always gives the same result.
- **Non-deterministic:** The result can differ between runs.

## Running Cosmos

- **Daemon:** The technical name for the running Cosmos, started by `cosmos start`. It
  stays open in its own terminal window.
- **Terminal:** The text window where commands are typed.
- **Runtime home (home folder):** The one folder that holds everything Cosmos writes.
- **Service manager:** The part of an operating system that starts programs at boot and
  restarts them if they fail, such as systemd on Linux.
- **Service account:** An account that exists only to run one program. Nobody logs in
  with it.
- **Scheduler:** The part that runs frames and gives each Thing its turn.
- **Runtime:** The Cosmos program itself.
- **Runtime lifecycle:** The fixed order of steps for starting and stopping.
- **Startup error:** A report saying where startup stopped, why, and how to recover.
- **Structured error:** An error in a fixed format that both people and programs can
  read.
- **Host event:** A fixed-format note about a startup or shutdown stage.
- **Log file:** The saved copy of Cosmos's host events. `cosmos logs` reads it.
- **Capability graph:** The map of which Thing's PROVIDES satisfies which Thing's WANTS.
- **Reconciliation:** Confirming at startup that the saved copies of the data agree, and
  rebuilding them if needed.
- **Migration:** Updating saved data from an older format to a newer one.

## Commands and Access

- **Command-line interface (CLI):** The `cosmos` commands typed into a terminal.
- **Console:** The interactive screen for looking around a running Cosmos.
- **Scope line:** The console line showing which Thing you are in.
- **Folder line:** The console line showing where you are inside that Thing's folder.
- **dir:** The console command listing a Thing's declared structures and procs.
- **Operator:** A person or AI giving Cosmos commands.
- **Command channel:** The one route for talking to the running Cosmos.
- **Inter-process communication (IPC):** The technical name for the command channel. It
  only works on your own computer.
- **Method:** One action available on the command channel, such as `runtime.step`.
- **Method table:** The one list of every method. It drives the commands, the console
  and the AI tools.
- **Describe, then call:** The pattern for using any Thing. `describe` shows what it can
  do. `call` asks it to do one of those things.
- **Model Context Protocol (MCP):** A standard way to connect AI tools to a program.
- **Port:** A numbered connection point on your computer. The default for Cosmos is
  7700.
- **JavaScript Object Notation (JSON):** A plain text format for structured data.
- **startapp:** The command that creates a new Thing that is ready to load.

## Saving and Checking Data

- **Persistence:** Saving data so it survives after Cosmos stops.
- **Primary state:** The first of the three saved layers: the current data.
- **Transaction log:** The second layer: a running log that only ever gets added to.
- **Snapshot:** The third layer: a signed saved copy of the state.
- **Persisted entry:** One saved item, with its checksum, origin and frame.
- **Checksum:** A value calculated from data that reveals if the data was damaged.
- **Envelope:** Data wrapped with information about itself, such as its version and
  checksum.
- **Data firewall:** The rule that no bad data reaches a Concept's code. The prefilter
  enforces it.
- **Fail closed:** When something goes wrong, refuse. The opposite, fail open, lets data
  through.
- **Prefilter:** The check every piece of incoming data passes before anything acts on
  it.
- **Validation:** Checking that data is the right shape before using it.
- **Validation record / mask:** The prepared rules that data is checked against.

## Project Words

- **Minimum viable product (MVP):** The first complete version of Cosmos.
- **Requirements:** What must be true.
- **Specification (spec):** How it will work.
- **Plan:** When each piece gets built.
- **Phase:** A stage of the work. Phases 1 to 3 are committed.
- **Reference deployment:** The recommended way to run Cosmos as an always-on service.
- **Gate:** The full set of automatic checks. `nimble verify` runs it.
- **Fast check:** The checks that start nothing. `nimble checkFast` runs it.
- **Compliance matrix:** The table showing each requirement, its test and its status.
- **Known failure:** A test expected to fail, listed with its reason.
- **False pass:** A test that passes for the wrong reason.
- **Stacking:** The design rule that a new layer must never break what is underneath it.
- **Nim:** The programming language Cosmos is written in.
- **Audio kernel:** The planned part of the separate audio project that produces sound.
  It is not part of Cosmos.

## Retired Words

- **RECORD:** was the name for an internalized occurrence. Now: a change in the history.
- **wink, smile, morphos, blip, tick:** earlier names for time and change. Now: frame,
  change, occurrence.
- **Five primitives:** now one entity (the Thing) plus properties of the Cosmos.
- **Context inheritance and overrides:** retired. Nothing is inherited.
- **Precept:** older word for wave.
- **inspect (command):** retired in Phase 2. Now: `describe`.
- **Tempo (as a Thing's timing):** now rhythm. Tempo keeps its musical meaning, speed.

## Set Aside for Later

- **World Ledger, Claim, Reference:** deferred until real Things need them.
- **Memory categories:** kept in code, not part of the MVP.
- **Specialist, Delegation:** kept in code, not part of the MVP.
- **Encryption mode:** deferred. The MVP stores data unencrypted.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
