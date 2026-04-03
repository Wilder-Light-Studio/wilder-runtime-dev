# Wilder Cosmos 0.4.0
# Module name: home
# Module Path: src/runtime/home.nim
# Summary: Runtime-home path resolution and directory ownership helpers for Phase X.
# Simile: Like a site plan, it fixes where each runtime-owned path belongs before tools build on top.
# Memory note: user and system roots must resolve deterministically across supported OS targets.
# Flow: resolve install root -> classify ownership -> ensure required tree exists.

import std/[os, strutils]

type
  InstallMode* = enum
    imUser
    imSystem

  RuntimeHomeOwnership* = enum
    rhoUserEditable
    rhoToolOwned
    rhoOptionalProjects
    rhoRuntimeTools
    rhoOperationalData

const
  RuntimeHomeDirs* = [
    "config",
    "logs",
    "cache",
    "messages",
    "projects",
    "registry",
    "bin",
    "temp"
  ]

# Flow: Detect the current host OS using a stable project-local label.
proc detectHostOs*(): string =
  when defined(windows):
    "windows"
  elif defined(macosx):
    "darwin"
  else:
    "linux"

# Flow: Validate an OS label and normalize whitespace/case.
proc normalizeTargetOs(targetOs: string): string =
  let normalized = targetOs.strip.toLowerAscii
  if normalized.len == 0:
    return detectHostOs()
  if normalized notin ["windows", "linux", "darwin"]:
    raise newException(ValueError,
      "home: target OS must be one of windows|linux|darwin")
  normalized

# Flow: Return the canonical runtime-home root for one install mode and OS.
proc resolveRuntimeHomeRoot*(mode: InstallMode,
                             targetOs: string = "",
                             sandboxRoot: string = ""): string =
  let osName = normalizeTargetOs(targetOs)
  let useSandbox = sandboxRoot.strip.len > 0
  case osName
  of "windows":
    case mode
    of imUser:
      if useSandbox:
        sandboxRoot / "UserProfile" / ".wilder" / "cosmos"
      else:
        getHomeDir() / ".wilder" / "cosmos"
    of imSystem:
      if useSandbox:
        sandboxRoot / "ProgramData" / "Wilder" / "Cosmos"
      else:
        getEnv("ProgramData", r"C:\ProgramData") / "Wilder" / "Cosmos"
  of "linux", "darwin":
    case mode
    of imUser:
      if useSandbox:
        sandboxRoot / "home" / ".wilder" / "cosmos"
      else:
        getHomeDir() / ".wilder" / "cosmos"
    of imSystem:
      if useSandbox:
        sandboxRoot / "var" / "lib" / "wilder" / "cosmos"
      else:
        "/var/lib/wilder/cosmos"
  else:
    raise newException(ValueError, "home: unsupported target OS")

# Flow: Classify ownership expectations for one runtime-home child directory.
proc runtimeHomeOwnership*(dirName: string): RuntimeHomeOwnership =
  case dirName.strip
  of "config": rhoUserEditable
  of "registry": rhoToolOwned
  of "projects": rhoOptionalProjects
  of "bin": rhoRuntimeTools
  of "logs", "cache", "messages", "temp": rhoOperationalData
  else:
    raise newException(ValueError,
      "home: unknown runtime-home directory '" & dirName & "'")

# Flow: Materialize the canonical runtime-home directory tree idempotently.
proc ensureRuntimeHomeTree*(root: string) =
  let trimmed = root.strip
  if trimmed.len == 0:
    raise newException(ValueError,
      "home: runtime-home root must not be empty")
  if not dirExists(trimmed):
    createDir(trimmed)
  for dirName in RuntimeHomeDirs:
    let path = trimmed / dirName
    if not dirExists(path):
      createDir(path)

# Flow: Return one canonical child path under a resolved runtime-home root.
proc runtimeHomePath*(root: string, child: string): string =
  let trimmedRoot = root.strip
  let trimmedChild = child.strip
  if trimmedRoot.len == 0:
    raise newException(ValueError,
      "home: runtime-home root must not be empty")
  if trimmedChild.len == 0:
    raise newException(ValueError,
      "home: runtime-home child must not be empty")
  trimmedRoot / trimmedChild

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.