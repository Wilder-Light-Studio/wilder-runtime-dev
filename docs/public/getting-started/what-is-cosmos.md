# What Is Cosmos

What this is. This page gives a plain-language definition of Cosmos and the model it
uses.

Cosmos is a way to build things logically, in a style suited to a Neurodivergent
(ND), ADHD mind. It's a runtime written in Nim. You describe what you're building as
Concepts, Cosmos makes Things from them, and the Things talk to each other through
waves and wires. Nothing is hidden: every Thing can be inspected, and every change is
recorded in a history.

It's for building anything. The first uses are personal music tools (a MIDI editor
and a synth) and a rhyming dictionary app. Those live in their own projects.

## The Model in Six Lines

- **Everything that exists is a Thing.** The Cosmos itself is the root Thing.
- **Concepts are templates.** Every other Thing is made from one, and Concepts can be
  built from other Concepts.
- **Waves are how Things talk.** A wave spreads to every Thing with a matching sense.
- **Wires are directed waves.** A wire carries a Thing's output to the inputs of the
  Things it names.
- **Time moves in frames.** The history has one row per frame: what happened, and
  when.
- **Explicit over implicit.** Nothing is inherited from a parent. A Thing knows only
  what its Concept declares, what it senses and what is wired to it.

[Concepts](../concepts/primitives.md) explains each of these in more detail.

## Who Uses It

People and AI are equal users. Everything a person can do through the `cosmos`
command or the console, an AI can do through the same command or through the Model
Context Protocol (MCP). The CLI and MCP parts are being built in Phase 2.

## What It Is Not

- It isn't a plugin host where code can bypass startup gates or validation.
- It doesn't accept unvalidated input: everything passes the validating prefilter
  first.
- It doesn't keep hidden state: every change is recorded, with who made it.
- It isn't real-time audio software. Audio projects run their own kernel and use
  Cosmos for structure, control and inspection.

## Next Step

Continue to [runtime-at-a-glance.md](runtime-at-a-glance.md) for the startup flow and
the main parts of the runtime.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
