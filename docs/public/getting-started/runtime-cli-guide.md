# Runtime CLI Guide

What this is. This page lists every `cosmos` command: what it does today, and what
Phase 2 changes. Phase 2's design is in
[MVP-SPECIFICATION.md](../../implementation/MVP-SPECIFICATION.md) §3 to §6.

---

## One Command, One Daemon

Everything goes through one program, `cosmos` (`src/cosmos_main.nim`, built to
`bin/cosmos.exe`). Its grammar is `cosmos <verb> [noun] [args]`.

- `cosmos start` runs the daemon: the running Cosmos. It stays in the terminal you
  start it from.
- Every other command is a client. It connects to the daemon over localhost, sends
  one request and prints the response.
- The console is a client too.

People and AI use the same commands. Every command prints a JSON response and never
asks a question, so a script or an AI agent can drive the runtime from a shell.

---

## Commands

| Command | What it does | Today | After Phase 2 |
|---|---|---|---|
| `cosmos start` | Run the daemon in this terminal | Works. Port fixed at 7700; flags ignored | Accepts `--mode`, `--config`, `--with`, `--loglevel`, `--port` |
| `cosmos stop` | Stop the daemon cleanly | Fails: "method not found" | Finishes the frame, shuts down, frees the port |
| `cosmos list things` | List loaded Things | Fails: "method not found" (see below) | Lists real Things with id, scope path and WHY |
| `cosmos add thing <bundle>` | Load a bundle folder | Fails: "method not found" | Loads into the runtime |
| `cosmos remove thing <id>` | Remove a Thing | Fails: "method not found" | Removes from the runtime |
| `cosmos add watch <path>`, `remove watch`, `list watch` | Manage watched paths | Fail: "method not found" | Work |
| `cosmos inspect <target>` | Show runtime state | Works, but shows the daemon's own copy, not the runtime | Retired. `cosmos describe cosmos` shows the runtime's real state |
| `cosmos step` | Advance one frame | Counts, without running a frame | Runs exactly one frame |
| `cosmos mode <step\|continuous\|periodic>` | Change how frames run | Fails: "method not found" | Validated and applied |
| `cosmos console` | Open the interactive console | Opens, but forgets you between commands | Keeps the session (see below) |
| `cosmos --help` | Show usage | Prints usage, but exits with an error | Prints usage, exits 0, starts nothing |
| `cosmos restart` | — | Accepted | Removed until it's designed |

### Why "method not found"

The daemon lowercases each request's method name before looking it up, but the names
it looks for have capitals (`addThing`, `listThings`, `setMode`). So every method with
a capital letter fails, and only `step`, `inspect`, `pause`, `resume`, `snapshot`,
`attach` and `subscribe` get through. `ping` and `stop` aren't handled at all. Found
on 2026-11-05; Phase 2 fixes it.

### Unreachable today

`startapp`, `capabilities`, `concept`, `scan`, `ipc` and `notify` still exist in the
code, but the command line stopped routing to them in April 2026. Phase 2 reconnects
them.

### New in Phase 2

| Command | What it does |
|---|---|
| `cosmos methods` | List every daemon operation, its inputs and whether it changes anything |
| `cosmos describe <target>` | Describe any Thing, including the Cosmos itself |
| `cosmos call <thing> <provide> [--args-json <json>]` | Invoke something a Thing PROVIDES |
| `cosmos history [--last <N>] [--frame <N>] [--thing <name>]` | Show what happened |
| `cosmos logs [--last <N>]` | Read the log file, even after a crash |
| `cosmos pause`, `resume`, `snapshot` | The remaining daemon operations. Every operation gets a command |
| `cosmos mcp` | Serve every operation as a Model Context Protocol (MCP) tool |

`describe` then `call` works the same on every Thing, and on the Cosmos: its PROVIDES
are the runtime's own operations, such as `step` and `stop`.

### Exit codes

- `0`: success.
- `1`: no daemon, a timeout or a connection failure. Nothing waits more than 2
  seconds (from Phase 2).
- `2`: a usage error, or an error response from the daemon.

---

## The Console

`cosmos console` opens an interactive session with the daemon. After Phase 2 it
accepts `--attach <identity>` (default `operator`) and `--watch <path>`.

The layout has three lines, in this order: a status bar, the current scope and the
prompt.

### Attaching

Most commands need an attached identity:

```
attach operator
```

Attaching sets your identity, grants `read` permission, clears any earlier session
state and unlocks the inspection commands.

| Permission | What it allows |
|---|---|
| `read` | Inspection and navigation: `ls`, `cd`, `pwd`, `info`, `peek`, `state`, `world`, `watch` |
| `write` | Changes |
| `admin` | Managing sessions |

### Commands

| Command | Does |
|---|---|
| `ls` | List what's in the current scope |
| `cd <path>` | Change the current scope (changes nothing else) |
| `pwd` | Show the current scope |
| `info <target>`, `peek <target>`, `state <target>` | Inspect a Thing |
| `world` | Show the current World |
| `watch <path>` | Follow a Thing live; `Ctrl+C` returns to the layout |
| `attach <identity>`, `detach` | Start or end a session |
| `help`, `clear`, `exit` | Help, clear the screen, leave |

`attach`, `help`, `clear` and `exit` work without an attached identity. Every other
command says clearly that it needs one.

### Detaching

`detach` cancels watches, clears the session and resets the scope and prompt. `exit`
detaches and then closes the console.

---

## Quick Reference

| Task | Command |
|---|---|
| Start the daemon | `cosmos start` |
| Stop the daemon | `Ctrl+C` in its terminal (`cosmos stop` from Phase 2) |
| See what's loaded | `cosmos list things` |
| Inspect | `cosmos inspect world` |
| Open the console | `cosmos console` |

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
