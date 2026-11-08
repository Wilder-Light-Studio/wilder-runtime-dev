# Why Cosmos Is Built This Way

**Written 2026-11-08.**

This document explains the reasoning behind the requirements and specification. It is
written for a Neurodivergent (ND) reader. Each entry stands alone, so you can jump to
whatever you are wondering about.

- [The plain-language guide](MVP-PLAIN-LANGUAGE.md) says **what** Cosmos does.
- This document says **why** it does it that way.
- [The glossary](../public/glossary/cosmos-terms.md) defines the words.

**How each entry works:**

- **Choice:** what was decided.
- **Why:** the reasoning.
- **Cost:** what it gives up. Every choice costs something.
- **Not chosen:** the alternatives that were turned down, when there were any.

Reasons come from the project's records and decisions. Where a reason is an inference,
the entry says **Likely reason**.

## Contents

1. [The rules behind every choice](#the-rules-behind-every-choice)
2. [Purpose](#purpose)
3. [What exists](#what-exists)
4. [Communication](#communication)
5. [Time and history](#time-and-history)
6. [Scope and inheritance](#scope-and-inheritance)
7. [Building with Concepts](#building-with-concepts)
8. [Running Cosmos](#running-cosmos)
9. [AI access](#ai-access)
10. [The data firewall](#the-data-firewall)
11. [Saving data](#saving-data)
12. [Tests](#tests)
13. [Order of work and deployment](#order-of-work-and-deployment)
14. [Tensions still open](#tensions-still-open)

---

## The Rules Behind Every Choice

Five rules decide most questions. When a choice below seems odd, one of these is usually
the reason.

| Rule | In short |
|---|---|
| **Simple** | Fewer decisions to explain. Answering a disagreement by adding a setting avoids the decision |
| **Intuitive** | Less to hold in your head, and less physical work. The most common action should be the closest |
| **Aesthetics matter** | It has to feel right. That includes full accessibility, which wins when the two conflict |
| **Stacking** | A new layer must never break what is underneath it. Failing means less function, never a freeze |
| **Use what is already there** | Find the existing way first. A new way has to beat it, and any departure must say why |

The last rule is why the technical documents say **Departs** next to some decisions.
Each one marks a place where an older rule was deliberately changed, so nobody "fixes"
it back later.

---

## Purpose

### Cosmos is for building anything

- **Choice:** Cosmos is a general way to build things. Music tools are the first use,
  not the only one.
- **Why:** The goal is a logical way of building that suits an ADHD mind: one kind of
  entity, uniform Concepts, visible wires, no hidden behaviour, and a record of what
  happened. That is useful well beyond music.
- **Cost:** Cosmos can't take shortcuts that would only suit audio.
- **Not chosen:** Delaying Concepts and wires until the audio project needed them. This
  was the first plan. It changed because every use needs Concepts that compose.

### Audio stays out of this project

- **Choice:** Nothing about audio goes in Cosmos. Audio projects use it from outside.
- **Why:** Real-time audio has strict rules that a general runtime shouldn't carry.
  Keeping them apart stops either one from bending the other.
- **Cost:** There will be a boundary to cross between them.

### Prove things before claiming them

- **Choice:** Phase 1 made the tests trustworthy before anything else was built.
- **Why:** The older documents claimed chapters were complete that the tests couldn't
  run. If the tests can't be trusted, nothing else can be either.
- **Cost:** A whole phase produced no new features.

---

## What Exists

### Everything is a Thing

- **Choice:** There is one kind of entity. Everything that exists is a Thing.
- **Why:** One kind of object means one set of rules to remember. You inspect and
  connect everything the same way. This is the core of the project.
- **Cost:** The code still has separate types for modules, bundles and specialists.
  Folding them in is later work.
- **Not chosen:** The older "five primitives" design.

### A Concept is also a Thing

- **Choice:** Concepts are Things that act as templates, kept at `cosmos.concepts`.
- **Why:** If templates were a different kind of object, the "one kind of entity" rule
  would have an exception. As Things, they can be described the same way as everything
  else.
- **Cost:** A Concept is a Thing that never runs or receives waves, which needs
  explaining.

### The Cosmos is a Thing too

- **Choice:** The top level is a Thing. Its abilities are the runtime's own operations.
- **Why:** An AI or person learns one pattern, describe then call, and it works on
  everything, including Cosmos itself.

### Waves, wires and the history are not Things

- **Choice:** They are properties of the Cosmos.
- **Why:** This keeps the model small. It also matches the older rule that wires are
  containment over wave propagation. **Likely reason:** if a wire were a Thing, it would
  need connecting to things, and those connections would need explaining too.
- **Cost:** A wire can't be inspected at an address of its own.

### Standard words, unless the idea is truly Cosmos's own

- **Choice:** Use standard terms where one fits: history, occurrence, change, frame.
  Keep distinctive names where they earn it: Thing, Concept, wave, wire, sense.
- **Why:** Every invented word is something to remember. The earlier names wink, smile,
  morphos, blip and tick were retired for that reason.
- **Why the meaning is checked first:** "timestamp" was considered and rejected, because
  a frame is virtual time, not clock time.

### "Rhythm", not "tempo"

- **Choice:** When a Thing acts is its rhythm.
- **Why:** Tempo means speed, and the music tools need that word for that meaning.

---

## Communication

### Waves are the only way Things talk

- **Choice:** Things communicate only through waves.
- **Why:** One route means nothing happens out of sight. Everything can be recorded and
  replayed.
- **Cost:** Simple requests take at least one frame.

### Waves spread everywhere unless wired

- **Choice:** A wave reaches every Thing with a matching sense. A wire narrows it.
- **Why:** Spreading makes it easy to listen without setting anything up. Wires give
  precise, visible connections when you want them.
- **Cost:** A wave with a common name reaches every Thing sensing it.

### Senses match by exact name

- **Choice:** No patterns or wildcards.
- **Why:** You can read a name and know what it matches. A pattern needs working out.

### A wire is like a cable from an output jack

- **Choice:** Each thing a Thing PROVIDES can be wired separately.
- **Why:** It matches the hardware feel the music tools are aiming for, and it stays
  useful outside music.

### Wires are checked before anything travels

- **Choice:** When a Concept loads, each destination must be able to accept what the
  wire carries. If not, that Concept is skipped with a warning.
- **Why:** Mistakes show up immediately, with a clear message, instead of as strange
  behaviour later. Skipping one Concept follows the stacking rule: the rest keeps working.

### Waves have no address

- **Choice:** A wave never names its destination.
- **Why:** A Thing can't reach outside its scope by addressing something. This is a
  guarantee from how it is built, not a check that could be forgotten.

### A call uses a one-time wire

- **Choice:** When a person or AI asks a Thing to act, the Cosmos makes a wire for that
  one wave.
- **Why:** It reuses the wire idea, and waves stay address-free.
- **Not chosen:** A separate direct route, which would be a second way to communicate.
  Addressed waves, which would need a scope check on every wave.

### Calls have ticket numbers

- **Choice:** Each call has a number, and its answer carries the same number.
- **Why:** Explicit over implicit. Nothing has to be assumed from the order things
  arrive in.
- **Not chosen:** One call at a time, where the match would be assumed.

### A paused call waits and says so

- **Choice:** It replies at once with its ticket. The next `step` shows the answer.
- **Why:** Stepping is for watching closely. Refusing would force you to resume, which
  lets frames run on and loses your place. A timeout would falsely say Cosmos is broken.

---

## Time and History

### Time is counted in frames

- **Choice:** Cosmos time is frames, never the clock.
- **Why:** The same starting point always gives the same result. Clock time differs
  every run, so it can't be replayed.
- **Cost:** Frames aren't the audio clock, so audio projects need a bridge between them.

### A wave arrives in the next frame

- **Choice:** A wave sent in one frame is received at the start of the next.
- **Why:** The order Things take their turns can never change what they hear. That
  removes a whole family of confusing bugs.
- **Cost:** Each hop takes one frame.

### The history is one row per frame

- **Choice:** The frame is when. The changes are what.
- **Why:** It is the standard event-log pattern, and it is simple to read: what
  happened, and when.

### Deliveries aren't recorded

- **Choice:** The history stores waves, not who received them.
- **Why:** Who received a wave follows from the wires and senses at that moment, so
  storing it would record the same fact twice.
- **The exception:** a call's one-time wire leaves no other trace, so its destination is
  recorded.

### The history can be read and filtered

- **Choice:** `cosmos history`, with a filter for one Thing.
- **Why:** "What did this Thing do?" is likely the most common question. Without the
  filter, you would have to read every row yourself.

---

## Scope and Inheritance

### A Thing can only act on itself and what is inside it

- **Choice:** Anything else reaches it only through senses or wires.
- **Why:** You can understand a Thing by looking at the Thing.
- **How it is enforced:** by construction. A Thing's code only ever has its own input
  and output, so there is nothing to forget to check.

### Nothing is inherited

- **Choice:** Nothing passes from a parent to the Things inside it.
- **Why:** Inherited behaviour is hidden behaviour. To understand a Thing you would have
  to know everything above it. "Explicit over implicit, always."
- **Cost:** Some things have to be stated more than once.
- **Not chosen:** The older context inheritance and override rules, which are retired
  for good rather than postponed.

---

## Building with Concepts

### One manifest form

- **Choice:** Every Concept is one `manifest.json`, whatever language it uses.
- **Why:** One thing to learn.
- **Not chosen:** Separate formats for bundles and native modules, and code-based
  Concepts overriding written ones.

### Declared once, referred to everywhere

- **Choice:** What a Thing offers is declared by that Thing. Others refer to it by name.
- **Why:** Two copies of a fact eventually disagree.

### Code only uses input, output and error

- **Choice:** One JSON message per line, with no other channels.
- **Why:** It is simple, inspectable and works in any language. It builds on what Cosmos
  already had for outside programs.
- **Cost:** It is slower than direct calls. Audio signals never travel this way.

### Concepts can be built from Concepts

- **Choice:** A Concept can be made of parts and the wires between them.
- **Why:** Composition is the main activity of building with Cosmos. A synth patch is
  one example.

---

## Running Cosmos

### It runs in the foreground

- **Choice:** `cosmos start` stays open in its terminal.
- **Why:** It leaves no forgotten background program, and needs no special Windows code.
  It is also what service managers on Linux and BSD expect.
- **Cost:** It occupies a terminal window.

### One part changes anything

- **Choice:** Commands wait in a queue and run between frames.
- **Why:** Two things can't collide, and runs stay replayable.
- **Cost:** A command waits until the current frame ends.

### Settings are optional

- **Choice:** With no settings file, Cosmos uses defaults.
- **Why:** The first command should just work. A missing file means reduced function,
  not a failure.

### Broken Things are skipped

- **Choice:** A malformed Thing is skipped with a warning. Startup continues.
- **Why:** One bad Thing shouldn't stop all the others.

### The port comes from settings

- **Choice:** No command has a fixed port.
- **Why:** Tests need free ports so they can run side by side.
- **Not chosen:** Skipping tests when port 7700 is busy, because tests would then skip
  silently.

### JSON only

- **Choice:** One data format.
- **Why:** One less decision, and people can read it.

### One console

- **Choice:** `cosmos console` is the only way in.
- **Why:** Two ways in meant two sets of options to remember.

### The console shows scope and folder on separate lines

- **Choice:** One line for which Thing you are in, one for where inside it.
- **Why:** They are two different facts. Visible state beats remembered state.
- **Cost:** One more line on screen.

### Scopes can be entered and listed, like Python's `dir()`

- **Choice:** Once inside a scope, commands need no name, and `dir` lists its structures
  and procs.
- **Why:** Less typing, and you can see what is available instead of remembering it.
- **Cost:** Commands now depend on where you are, so the scope line must stay visible.
- **Not chosen:** Listing private procs, which would break scope. Running arbitrary code,
  which would bypass the data firewall.

### Logs go to the terminal and a file

- **Choice:** `cosmos logs` reads the file directly.
- **Why:** The moment you most need logs is after a crash. A tool that needs the broken
  program to explain the problem doesn't help.
- **Not chosen:** Terminal only, which disappears. Memory only, which dies in the crash.

---

## AI Access

### One set of controls

- **Choice:** The command line, console and AI tools all use the same channel.
- **Why:** AI is a first-class user. If there is no human-only path, the two can never
  drift apart.

### One table of actions

- **Choice:** Each action is declared once. Commands, help and AI tools come from it.
- **Why:** Nothing can be forgotten, because nothing is listed twice.

### Every action has a command

- **Choice:** No exceptions.
- **Why:** There is no list of exceptions to remember.
- **Cost:** A longer help page, so common commands come first.

### Commands that need no running Cosmos are in the table too

- **Choice:** `startapp` and similar commands are in the same table.
- **Why:** An AI should be able to create a Thing from nothing, the same as a person.

### `describe` replaced `inspect`

- **Choice:** `describe cosmos` shows the running state. `inspect` is retired.
- **Why:** The Cosmos is a Thing like any other, so a second word would be a second way
  to do one thing.

### Every change records who made it

- **Choice:** Each change carries its origin.
- **Why:** You can always trace what a person or AI did.

---

## The Data Firewall

### No bad data reaches a Concept's code

- **Choice:** Every piece of data from outside is checked before anything acts on it.
- **Why:** Code that can trust its input is simpler and safer. The bug can't start in
  the code if bad data never arrives.

### One table, built from what is already declared

- **Choice:** Rules come from the table of actions and from PROVIDES signatures.
- **Why:** A rule written separately from its declaration will eventually disagree with
  it.

### Rules are built when a Concept loads

- **Choice:** Not when Cosmos is compiled.
- **Why:** Things can be added while Cosmos runs. A table fixed at compile time couldn't
  know about them. Rules are still prepared before any data arrives.

### A Thing's output counts as outside data

- **Choice:** Waves are checked when a Thing sends them.
- **Why:** The code behind one Thing is outside data as far as another Thing is
  concerned.

### Calls inside Cosmos aren't checked

- **Choice:** The firewall sits where data comes in, not on every internal call.
- **Why:** The Nim compiler already guarantees those types. Checking again adds cost and
  no safety.

### It must be bullet-proof

- **Choice:** It must never fail open, must be exact and unforgeable, must have limits,
  must reveal nothing, and must have every known attack in its tests.
- **Why:** It is the one place everything depends on. An audit found that its original
  tests had passed while serious defects remained.
- **The honest limit:** testing can't prove there are no bugs left. It can prove every
  known kind of attack is handled.

### Failing means refusing

- **Choice:** Any error inside the checker is a rejection.
- **Why:** When something unexpected happens, letting the data through is the dangerous
  direction.

### Unknown fields are always rejected

- **Choice:** There is one policy.
- **Why:** The alternatives either quietly change the data or let unchecked data
  through.

---

## Saving Data

### Three layers

- **Choice:** Current state, a log that only grows, and signed snapshots.
- **Why:** Any one layer can be damaged and the state can still be rebuilt.

### Write to a temporary file, then swap

- **Choice:** A file is never written in place.
- **Why:** A crash can't leave half a file.

### Data isn't encrypted in the first version

- **Choice:** Cosmos makes no privacy claim. The operating system protects the disk.
- **Why:** With one user there is nobody to protect against yet. The existing cipher is
  home-made, and a false sense of safety is worse than none.

---

## Tests

### Tests are found, not listed

- **Choice:** Every test file runs automatically.
- **Why:** A list can miss things without anyone noticing.

### Known failures are listed openly

- **Choice:** A test expected to fail is written down with its reason. If it starts
  passing, the check fails until the list is updated.
- **Why:** The list can't go out of date, and failures can't be hidden.

### "False pass" is a real status

- **Choice:** The progress table can say a test passes for the wrong reason.
- **Why:** A green result that proves nothing is worse than a red one. The data firewall
  turned out to be exactly this case.

---

## Order of Work and Deployment

### Phases 1 to 3 are committed

- **Choice:** Phase 4 only happens when a project needs it.
- **Why:** Cosmos exists to build things, not to be complete for its own sake.

### Measure audio before setting targets

- **Choice:** Latency numbers come from measurements.
- **Why:** Until then, any target is a guess.

### One folder holds everything Cosmos writes

- **Choice:** Even where the system's convention would split things up.
- **Why:** There is one place to remember, one thing to back up and one thing to delete.
  Removing Cosmos leaves the system as it was.
- **Cost:** It departs from Linux, BSD and macOS conventions.

### It gets its own account, and never runs as root

- **Choice:** A dedicated account that can't log in.
- **Why:** If something goes wrong, the damage stops at Cosmos's own folder.

---

## Tensions Still Open

These are real trade-offs, stated openly.

| Tension | Where it stands |
|---|---|
| "Mode" means two things: the settings' mode and how frames run | Both kept for now |
| Built on Windows, likely deployed on Linux and BSD | The tests haven't run there yet |
| Checking every wave costs time | Audio signals don't travel this way, and speed gets measured later |
| The command channel has no access control | Only deploy where you trust every account |
| A sense names a wave but not its shape | [Question 8](MVP-PLAIN-LANGUAGE.md#still-undecided), for Phase 3 |
| Whether to use an existing audio engine or write one | Not decided. It belongs to the audio project |

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
