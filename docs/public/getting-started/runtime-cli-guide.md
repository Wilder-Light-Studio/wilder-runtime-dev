# Runtime CLI Guide

What this is. This page walks you through the two CLI entrypoints — starting the runtime and connecting a console — as well as attaching to and detaching from a live session.

---

## The Two Entrypoints

The runtime ships with two separate entry programs.

| Entrypoint | Source | Purpose |
|---|---|---|
| `cosmos` | `src/cosmos_main.nim` | Start the runtime. Optionally launch a console. |
| `console_main` | `src/console_main.nim` | Connect a console to an already-running instance. |

Use `cosmos` to bring up a new instance. Use `console_main` when the runtime is already running and you want to inspect or interact with it.

---

## Starting the Runtime

Build and run the coordinator entrypoint:

```powershell
nim c -r src/cosmos_main.nim -- --config config/runtime.json
```

This starts the runtime in detached mode — no console is launched. The runtime completes startup and runs.

### Console modes

Use `--console` to choose how the console behaves at startup:

```powershell
# No console (default — same as not passing --console)
nim c -r src/cosmos_main.nim -- --config config/runtime.json --console detach

# Start runtime then launch an attached console automatically
nim c -r src/cosmos_main.nim -- --config config/runtime.json --console auto

# Start runtime and open the console ready for explicit attach
nim c -r src/cosmos_main.nim -- --config config/runtime.json --console attach
```

### Daemonize

`--daemonize` runs the runtime in detached/background mode. It cannot be combined with `--console attach` — that combination is rejected at startup.

```powershell
nim c -r src/cosmos_main.nim -- --config config/runtime.json --daemonize
```

### Watch flag shorthand

If you pass `--watch` without an explicit `--console` flag, console mode resolves contextually:

- With `--daemonize`: resolves to **detach** (watch is then incompatible — startup fails; pass `--console attach` explicitly if you want watch with a console)
- Without `--daemonize`: resolves to **attach** automatically

```powershell
# Resolves to attach mode; starts watch on /thing/a when connected
nim c -r src/cosmos_main.nim -- --config config/runtime.json --watch /thing/a
```

### Override flags

```powershell
nim c -r src/cosmos_main.nim -- --config config/runtime.json --mode dev --log-level debug --port 8080 --console attach
```

`--mode` accepts `dev`, `debug`, or `prod`. `--log-level` accepts `trace`, `debug`, `info`, `warn`, or `error`. `--port` must be in range 1-65535. Overrides apply on top of the config file and environment; they do not alter the file itself.

### Inline help

```powershell
nim c -r src/cosmos_main.nim -- --help
```

Prints the full flag reference with examples and exits 0. Works in any argument order, including before or after invalid flags.

---

## Starting a Console Session

Use `console_main` to connect to a runtime that is already running.

```powershell
nim c -r src/console_main.nim -- --config config/runtime.json
```

This opens the console in an unattached state. You can then attach interactively (see below).

### Auto-attach on launch

Pass `--attach <identity>` to attach immediately on startup:

```powershell
nim c -r src/console_main.nim -- --config config/runtime.json --attach operator
```

### Watch on launch

Pass `--watch` together with `--attach` to open into watch mode directly:

```powershell
nim c -r src/console_main.nim -- --config config/runtime.json --attach operator --watch /thing/a
```

`--watch` requires `--attach`. Without an identity, the flag is rejected.

### Override flags

```powershell
nim c -r src/console_main.nim -- --config config/runtime.json --attach operator --mode dev --log-level debug --port 8080
```

### Inline help

```powershell
nim c -r src/console_main.nim -- --help
```

---

## Attaching to a Running Session

Once the console is open, use the `attach` command:

```
attach <identity>
```

Example:

```
attach operator
```

What attach does:
- Sets your identity for the session.
- Grants default `read` permission.
- Clears any previous session state (path, watch state, cached permissions).
- Unlocks all introspection commands: `ls`, `cd`, `info`, `peek`, `watch`, `state`, `specialists`, `delegations`, `world`, and more.

### Permissions

The default permission is `read`. Additional permissions can be granted at attach time:

| Permission | What it allows |
|---|---|
| `read` | State introspection, navigation, `ls`, `info`, `peek`, `state` |
| `write` | Mutations — `set`, `call`, `run` |
| `admin` | Instance management — `attach`, `detach`, `instances` |

### Capabilities

Capabilities inform the console how your client behaves. They are set at attach time:

| Capability | Effect |
|---|---|
| `ansi` | Enables ANSI colour and cursor codes in output |
| `fullscreen` | Enables `watch` full-screen mode |
| `mouse` | Reserved; not active today |

---

## Detaching

Run the `detach` command from an active session:

```
detach
```

What detach clears:
- Session identity
- Permissions and capabilities
- Current navigation path
- Prompt state
- Active watch state

The console remains open and can be re-attached. The runtime is not affected.

### Confirmed output

On success:

```
detached: operator
```

If no session is attached:

```
error: detach: no session attached
```

---

## Quick Reference

| Goal | Command |
|---|---|
| Start runtime, no console | `cosmos --config <path>` |
| Start runtime, auto console | `cosmos --config <path> --console auto` |
| Start runtime, ready to attach | `cosmos --config <path> --console attach` |
| Start runtime in background | `cosmos --config <path> --daemonize` |
| Connect console only | `console_main --config <path>` |
| Connect and auto-attach | `console_main --config <path> --attach <identity>` |
| Connect and watch | `console_main --config <path> --attach <identity> --watch <path>` |
| Attach in session | `attach <identity>` |
| Detach in session | `detach` |
| See all flags | `cosmos --help` / `console_main --help` |

---
*Copyright 2026 Wilder. All rights reserved.*
*Contact: teamwilder@wildercode.org*
*Licensed under the Wilder Foundation License 1.0.*
*See LICENSE for details.*