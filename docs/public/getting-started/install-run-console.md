# Install, Run, And Explore Console

What this is. This page gives practical commands to build, test and run the runtime
locally.

There's no installer: the MVP builds from source on one machine. The old installer
guide is archived at `archive/docs/public/getting-started/install-windows.md`.

## Prerequisites

- Windows 11 (the MVP's target; Linux follows)
- Nim 2.0.8 and Nimble
- PowerShell, for the repository scripts

## Build and Test

```powershell
nimble buildRuntime    # build bin/cosmos.exe
nimble verify          # the full gate: compliance check, then every test
nimble checkFast       # quicker (about 20 s): skips daemon tests
```

The gate ends with `Gate passed.` when every test passes or is a listed known failure
(`tests/KNOWN_FAILURES.txt`). If a test fails, its build and run logs are in
`tests/tmp/gate/logs/`.

## Run the Daemon

`cosmos start` runs the daemon in the terminal you start it from:

```powershell
bin\cosmos.exe start
```

Open a second terminal for everything else:

```powershell
bin\cosmos.exe inspect world
bin\cosmos.exe console
```

To stop the daemon today, close its terminal or press `Ctrl+C` there. Until Phase 2,
`cosmos stop`, `list`, `add`, `remove` and `mode` fail with "method not found".

The [Runtime CLI Guide](runtime-cli-guide.md) lists every command, what it does today
and what Phase 2 changes.

## What To Look For

- the startup banner, showing each startup step in order;
- if startup halts: the step it halted at, the reason and recovery guidance;
- `cosmos: daemon already active` if a daemon is already running on the port.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
