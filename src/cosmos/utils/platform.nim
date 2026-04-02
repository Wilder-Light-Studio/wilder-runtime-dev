# Wilder Cosmos 0.4.0
# Module name: platform
# Module Path: src/cosmos/utils/platform.nim
#
# Summary: Cross-platform portability layer — filesystem, time, and process
#   abstractions that compile unmodified on all Tier 1 targets.
# Simile: Like a thin adapter plug — hides platform differences so all
#   modules stay portable without #ifdef guards.
# Memory note: all platform-specific code lives here; nothing outside this
#   file may reference os.DirSep or platform-specific APIs directly.
# Flow: call these procs everywhere -> platform differences are isolated here.
## platform.nim
## Cross-platform portability layer.
## Tier 1 targets: Linux, BSD, macOS, Windows, Haiku.
## Nim minimum: 1.6 (std/os, std/times, std/monotimes are all 1.6+ stable).

## Example:
##   import cosmos/utils/platform
##   let p = platformJoinPath("tests", "tmp", "case1")
##   let t = platformGetEpochSeconds()

import std/[os, times, monotimes]

# ── Path Abstraction ──────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformJoinPath*(parts: varargs[string]): string =
  ## Join path components using the host platform separator.
  ## Simile: The adapter knows which plug shape to use; callers don't.
  ## Uses std/os.joinPath which is portable across all Tier 1 targets.
  if parts.len == 0:
    raise newException(ValueError, "platformJoinPath: requires at least one path component")
  result = parts[0]
  for i in 1 .. high(parts):
    result = os.joinPath(result, parts[i])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformDirSep*(): char =
  ## Return the platform directory separator ('/' or '\').
  result = os.DirSep

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformFileExists*(path: string): bool =
  ## Return true if path refers to an existing regular file.
  result = os.fileExists(path)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformDirExists*(path: string): bool =
  ## Return true if path refers to an existing directory.
  result = os.dirExists(path)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformCreateDir*(path: string) =
  ## Create directory (and parents) if it does not already exist.
  ## Simile: mkdir -p — safe to call even if the directory is already there.
  if not os.dirExists(path):
    os.createDir(path)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformGetCwd*(): string =
  ## Return the current working directory.
  result = os.getCurrentDir()

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformNormalizePath*(path: string): string =
  ## Normalize path separators and remove redundant segments.
  result = os.normalizedPath(path)

# ── Time Abstraction ──────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformGetEpochSeconds*(): int64 =
  ## Return the current Unix timestamp in seconds.
  ## Uses std/times which is portable on all Tier 1 targets.
  result = toUnix(getTime())

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformGetMonotonicMs*(): int64 =
  ## Return a monotonic clock value in milliseconds.
  ## Monotonic time is safe for elapsed-time measurement.
  result = ticks(getMonoTime()) div 1_000_000

# ── Process Abstraction ───────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformGetEnv*(key: string, default: string = ""): string =
  ## Read an environment variable, returning default if not set.
  ## Simile: A safe mailbox — if no letter is there, use the default.
  result = os.getEnv(key, default)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc platformIsEnvSet*(key: string): bool =
  ## Return true if the environment variable is set (regardless of value).
  result = os.existsEnv(key)

# ── Legacy Compat ─────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc joinPath*(parts: varargs[string]): string =
  ## Backward-compatible alias — prefer platformJoinPath for new code.
  result = platformJoinPath(parts)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
