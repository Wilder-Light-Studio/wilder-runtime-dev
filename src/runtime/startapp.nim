# Wilder Cosmos 0.4.0
# Module name: startapp
# Module Path: src/runtime/startapp.nim
# Summary: Deterministic application scaffold generation for the initial Phase X CLI slice.
# Simile: Like a template jig, it cuts the same starter shape every time before developers customize it.
# Memory note: scaffold generation must stage writes before moving into place.
# Flow: validate target -> stage scaffold -> write files -> move staged directory -> report outputs.

import json
import std/[os, strutils]

const
  MaxStartAppNameLength = 64

type
  StartAppOptions* = object
    targetDir*: string
    appName*: string
    mode*: string
    transport*: string
    includeTemplate*: bool

# Flow: Derive an app name from the target directory when the caller omits one.
proc defaultAppName*(targetDir: string): string =
  let tail = splitPath(targetDir).tail.strip
  if tail.len == 0: "cosmos-app" else: tail

# Flow: Normalize startapp mode text to the runtime config vocabulary.
proc normalizeStartAppMode*(raw: string): string =
  case raw.strip.toLowerAscii
  of "", "dev", "development": "development"
  of "debug": "debug"
  of "prod", "production": "production"
  else:
    raise newException(ValueError,
      "startapp: mode must be one of dev|debug|prod")

# Flow: Normalize startapp transport text to the runtime config vocabulary.
proc normalizeStartAppTransport*(raw: string): string =
  case raw.strip.toLowerAscii
  of "", "json": "json"
  of "protobuf": "protobuf"
  else:
    raise newException(ValueError,
      "startapp: transport must be one of json|protobuf")

# Flow: Validate app name content before rendering into generated source/templates.
proc validateStartAppName(name: string) =
  if name.len == 0:
    raise newException(ValueError,
      "startapp: app name must not be empty")
  if name.len > MaxStartAppNameLength:
    raise newException(ValueError,
      "startapp: app name must be <= " & $MaxStartAppNameLength & " characters")
  for ch in name:
    if ch notin {'a'..'z', 'A'..'Z', '0'..'9', '_', '-', ' ', '.'}:
      raise newException(ValueError,
        "startapp: app name contains invalid character '" & $ch & "'")

# Flow: Build the canonical cosmos.toml payload for one starter app.
proc renderCosmosToml(opts: StartAppOptions): string =
  "app_name = \"" & opts.appName & "\"\n" &
  "runtime_mode = \"" & opts.mode & "\"\n" &
  "transport = \"" & opts.transport & "\"\n"

# Flow: Build a machine-readable starter build manifest.
proc renderBuildManifest(opts: StartAppOptions): JsonNode =
  %*{
    "appName": opts.appName,
    "runtimeMode": opts.mode,
    "transport": opts.transport,
    "templates": if opts.includeTemplate: @["starter"] else: @[]
  }

# Flow: Write a complete staged scaffold tree for one application.
proc writeStagedScaffold(stageDir: string, opts: StartAppOptions) =
  createDir(stageDir)
  createDir(stageDir / "src")
  writeFile(stageDir / "cosmos.toml", renderCosmosToml(opts))
  writeFile(stageDir / "build-manifest.json", renderBuildManifest(opts).pretty())
  writeFile(stageDir / "src" / "main.nim",
    "echo \"Starting " & opts.appName & " via cosmos.exe\"\n")
  if opts.includeTemplate:
    createDir(stageDir / "templates")
    writeFile(stageDir / "templates" / "starter.txt",
      "starter-template=" & opts.appName & "\n")

# Flow: Generate a starter application using staged writes and atomic move.
proc scaffoldApp*(opts: StartAppOptions): seq[string] =
  let targetDir = opts.targetDir.strip
  if targetDir.len == 0:
    raise newException(ValueError,
      "startapp: target directory must not be empty")

  let parent = parentDir(targetDir)
  if parent.len > 0 and not dirExists(parent):
    raise newException(ValueError,
      "startapp: parent directory does not exist")

  if dirExists(targetDir):
    for _ in walkDir(targetDir):
      raise newException(ValueError,
        "startapp: target directory must be empty or absent")
    raise newException(ValueError,
      "startapp: target directory must be empty or absent")

  var normalized = opts
  if normalized.appName.strip.len == 0:
    normalized.appName = defaultAppName(targetDir)
  validateStartAppName(normalized.appName)
  normalized.mode = normalizeStartAppMode(normalized.mode)
  normalized.transport = normalizeStartAppTransport(normalized.transport)

  let stageDir = targetDir & ".tmp-startapp"
  if dirExists(stageDir):
    removeDir(stageDir)

  try:
    writeStagedScaffold(stageDir, normalized)
    moveDir(stageDir, targetDir)
  except CatchableError:
    if dirExists(stageDir):
      removeDir(stageDir)
    raise

  @[
    "cosmos: scaffold created at " & targetDir,
    "cosmos: generated cosmos.toml, src/, and build-manifest.json",
    "cosmos: next step -> cosmos.exe --config " & (targetDir / "cosmos.toml")
  ]

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.