# Install, Run, And Explore Console

What this is. This page gives practical commands to build, test, and inspect the runtime locally.

## Prerequisites

- Nim 1.6 or newer
- Nimble
- PowerShell on Windows for helper scripts

## Core Commands

```powershell
nimble build
nimble compliance
nimble testCompile
nimble test
nimble verify
```

## Console Entry

The console entrypoint supports:

- `--config <path>` (required)
- `--mode <dev|debug|prod>`
- `--attach <identity>`
- `--watch <path>` (requires `--attach`)
- `--log-level <trace|debug|info|warn|error>`
- `--port <N>` (1–65535)
- `--help`/`-h`

Examples:

```powershell
# Minimal
nim c -r src/console_main.nim -- --config config/runtime.json

# Full attach with overrides
nim c -r src/console_main.nim -- --config config/runtime.json --attach local-dev --mode dev --log-level debug --watch /thing/a
```

Coordinator entrypoint supports startup plus optional console launch:

- `--config <path>` (required)
- `--mode <dev|debug|prod>`
- `--console <auto|attach|detach>`
- `--watch <path>` (attached console mode only)
- `--daemonize`
- `--log-level <trace|debug|info|warn|error>`
- `--port <N>` (1–65535)
- `--help`/`-h`

Examples:

```powershell
# Minimal
nim c -r src/cosmos_main.nim -- --config config/runtime.json

# Full start with watchable console session
nim c -r src/cosmos_main.nim -- --config config/runtime.json --watch /thing/a --console attach --mode dev --log-level debug
```

Pass `--help` to either entrypoint to see the full flag reference.
If launch arguments are invalid, the entrypoint exits non-zero and prints usage.
If startup halts, operator output includes halt step, reason, and recovery guidance.

## What To Look For

- lifecycle completion lines
- startup halt reason and recovery guidance if startup fails
- deterministic module load ordering

## Uncertainty Note

Exact config export and invocation wrappers can vary by local setup. Use repository scripts and the current `README.md` command list as primary guidance.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
