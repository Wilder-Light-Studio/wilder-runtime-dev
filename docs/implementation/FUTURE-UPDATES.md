# Future Updates

**Started 2026-11-08.**

This is the one list of everything set aside from the minimum viable product (MVP). It is
written for a Neurodivergent (ND) reader. Nothing here is lost. Each entry says what it
was, why it waited, and when to bring it back.

**The rule:** anything cut from the MVP gets an entry here in the same change.

Existing code for these items can stay in place. It isn't part of the MVP tests.

## Cut on 2026-11-08, to Keep the MVP Simple

| Item | What it was | Why it waited | Bring it back when |
|---|---|---|---|
| Frame modes | `--mode step\|continuous\|periodic`, `cosmos mode`, `runtime.setMode` | Running at a frame rate, or paused with `step`, does the same job | A project needs a different way of running frames |
| `mode` setting | development, debug or production (`COSMOS_MODE`) | Its only effect was limiting log detail | Cosmos behaves differently in production |
| `transport` and `endpoint` settings | Choice of transport and host | JSON over localhost is the only option | A second transport or remote access exists |
| Log levels | `--loglevel`, `COSMOS_LOG_LEVEL`, trace to error | Logs only hold startup and shutdown notes | Cosmos logs enough to need filtering |
| File watch lists | `add watch`, `remove watch`, `list watch` | They store paths and do nothing with them | Something needs to react to file changes |
| Event subscriptions | `subscribe`, `unsubscribe` | One connection carries one request, so nothing can receive pushed events | A connection that stays open exists |
| `cosmos notify` | Notification command | Not needed for the MVP workflow | A project needs notifications |
| `cosmos scan` | Semantic scanner | Not needed to build Things | Phase XB resumes |
| `cosmos concept` and `cosmos capability` | Concept registry commands | `describe cosmos.concepts.<name>` shows the same information | Bulk Concept tools are needed |
| `cosmos ipc` | Sends a raw request | Every action already has a command | Debugging the channel needs it |
| `runtime.methods` and `cosmos methods` | List every action | `describe cosmos` does the same job | Never needed unless the Cosmos stops being a Thing |
| Short method names | `pause` as well as `runtime.pause` | Two names for one action | Never needed |
| Manual rhythm | Acts only when commanded | `call` does this job | A Thing must never act on waves |
| Sequence rhythm | Acts in declared steps | No current use | A project needs ordered steps |
| Console sessions | `attach`, `detach`, session tokens, identities and permissions | The console holds its own scope. One user | Several people share a Cosmos |
| Console `info`, `peek`, `world` | Separate views of a Thing | `dir` shows it all in one place | `dir` becomes too long to read |
| `cosmos console --attach` and `--watch` | Start-up options | No sessions, and `watch` is a command | Scripted console start-up is needed |
| Wires between different names | A wire sending `notes` to a sense called `pitch` | The names must match, which is one less thing to learn | Reusing Concepts needs renaming |
| Input declared in WANTS | WANTS naming what a Thing accepts | SENSES are the one place for inputs | Never needed |
| Falloff for waves | `projectionRadius`: waves fading with distance | Unused | A project needs distance |
| Replay command | Re-running a saved history | The history can be read. Replay needs deterministic Thing code | A project needs to re-run the past |
| Renaming a Thing | A command to change a label | Ids make it safe, but nothing needs it yet | Someone wants to rename |

## Deferred Earlier

| Item | Why it waited |
|---|---|
| Encryption Spectrum (Phase XF) and encrypted records (Phase XD) | One user. Revisit with a vetted cryptography library |
| Humane Offline Licensing (Phase XE) | Not needed for personal use |
| Installer, release matrix and promotion (Chapter 19A, Phase X release) | One machine, built from source |
| Protobuf transport and serializer switching | JSON only is one less decision |
| Cue schema validation workflow | JSON with validation in code is enough |
| Implementations in Python, Rust, Node and others | The contract is fixed (MVP-INT-6). The MVP uses Nim, with C where needed |
| References (Phase XH) | Decide when real Things need them. A reference may turn out to be a wire |
| World Ledger claims | Graph references are enough for navigation |
| Delegation and specialists | They keep working, but aren't tested for the MVP |
| Memory categories and caps | They keep working, but aren't tested for the MVP |
| Console `specialists`, `delegations`, `claims`, `run`, `set`, `instances` | Not needed for the MVP workflow |
| Multiple instances and federation | One instance. Connecting Cosmoses must check ids when they connect |
| BSD, macOS, Haiku and 7 to 10-year-old toolchains | Built and tested on Windows first. Linux and BSD are the likely places to deploy |
| Performance targets (startup under 2 seconds, frame rates) | Measure once the MVP is stable |
| REST interface | It would be one more thin client of the same table |
| Background mode for the running Cosmos | The foreground suits people and service managers |
| `cosmos restart` | Not designed yet |
| Access control on the command channel | Needed before any shared deployment |

## Audio Project

These belong to the separate audio project.

- Measure before writing the kernel specification: run LatencyMon, then a WASAPI-exclusive
  sine wave at the smallest stable buffer. Those numbers become the latency targets.
- Keep the first milestone small: one oscillator, played from a MIDI keyboard, with its
  latency measured.
- A synth and a MIDI editor are the target. A digital audio workstation is only a
  "possibly".
- Decide whether to use an existing engine, such as Faust or SuperCollider.

## Later Cleanup

- Rename `TempoKind`, `src/cosmos/tempo/` and `tempoHz` to rhythm and frame rate.
- Rename `RECORD`, `blip` and `morphos` in the code.
- Fold module, bundle and specialist types into Things.
- The prefilter's bitmasks no longer decide anything that its other checks don't. They
  could be removed.
- Make the project's version numbers agree.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
