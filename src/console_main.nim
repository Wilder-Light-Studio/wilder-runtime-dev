# Wilder Cosmos 0.4.0
# Module name: Console Main
# Module Path: src/console_main.nim
# Summary: Thin CLI entrypoint for console startup contract and launch flags.
# Simile: Like a launch checklist, it validates flags and hands off to runtime subsystems.
# Memory note: keep orchestration thin; do not duplicate console subsystem logic.
# Flow: parse args -> validate required config -> apply optional attach/watch -> report launch status.

import std/[strutils, options]
import runtime/[console, config]

const
  UsageText* =
    "Usage: console_main --config <path> [--mode <dev|debug|prod>] " &
    "[--encryption-mode <clear|standard|private|complete>] " &
    "[--attach <identity>] [--watch <path>] " &
    "[--log-level <trace|debug|info|warn|error>] [--port <N>] [--help]"
  ConsoleHelpText* =
    "Wilder Cosmos Console — attach and inspect a running runtime instance\n" &
    "\n" &
    "Usage:\n" &
    "  console_main --config <path> [options]\n" &
    "\n" &
    "Required:\n" &
    "  --config <path>           Runtime config file path\n" &
    "\n" &
    "Optional:\n" &
    "  --mode <dev|debug|prod>   Override runtime mode\n" &
    "  --encryption-mode <mode>  Override encryption mode (clear|standard|private|complete)\n" &
    "  --attach <identity>       Auto-attach to this identity on launch\n" &
    "  --watch <path>            Start watch on this path (requires --attach)\n" &
    "  --log-level <level>       Override log level (trace|debug|info|warn|error)\n" &
    "  --port <N>                Override port (1-65535)\n" &
    "  --help, -h                Print this help text and exit\n" &
    "\n" &
    "Examples:\n" &
    "  console_main --config config/runtime.json\n" &
    "  console_main --config config/runtime.json --attach operator --mode dev --log-level debug --watch /thing/a"

type
  ConsoleLaunchOptions* = object
    configPath*: string
    modeOverride*: string
    encryptionMode*: string
    attachIdentity*: string
    watchTarget*: string
    logLevel*: string
    port*: int
    wantHelp*: bool

# Flow: Convert CLI mode shorthand to config override values.
proc normalizeMode(raw: string): string =
  case raw.toLowerAscii.strip
  of "dev": "development"
  of "debug": "debug"
  of "prod": "production"
  else:
    raise newException(ValueError,
      "console_main: --mode must be one of dev|debug|prod")

# Flow: Parse command-line arguments into structured launch options.
proc parseLaunchOptions*(args: seq[string]): ConsoleLaunchOptions =
  # Pre-scan: --help/-h is sovereign; if present, return immediately.
  for arg in args:
    if arg == "--help" or arg == "-h":
      result.wantHelp = true
      return
  var i = 0
  while i < args.len:
    case args[i]
    of "--config":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --config requires a path")
      result.configPath = args[i + 1]
      i += 2
    of "--mode":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --mode requires a value")
      result.modeOverride = normalizeMode(args[i + 1])
      i += 2
    of "--encryption-mode":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --encryption-mode requires a value")
      result.encryptionMode = args[i + 1].toLowerAscii.strip
      i += 2
    of "--attach":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --attach requires an identity")
      result.attachIdentity = args[i + 1].strip
      i += 2
    of "--watch":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --watch requires a path")
      result.watchTarget = args[i + 1]
      i += 2
    of "--help", "-h":
      result.wantHelp = true
      i += 1
    of "--log-level":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --log-level requires a value")
      result.logLevel = args[i + 1].toLowerAscii.strip
      i += 2
    of "--port":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --port requires a value")
      try:
        result.port = parseInt(args[i + 1])
      except ValueError:
        raise newException(ValueError,
          "console_main: --port must be an integer, got '" & args[i + 1] & "'")
      i += 2
    else:
      raise newException(ValueError,
        "console_main: unknown argument '" & args[i] & "'")

# Flow: Validate required startup arguments and cross-flag constraints.
proc validateLaunchOptions*(opts: ConsoleLaunchOptions) =
  if opts.wantHelp:
    return
  if opts.configPath.strip.len == 0:
    raise newException(ValueError,
      "console_main: --config is required")
  if opts.logLevel.len > 0 and
     opts.logLevel notin ["trace", "debug", "info", "warn", "error"]:
    raise newException(ValueError,
      "console_main: --log-level must be one of trace|debug|info|warn|error")
  if opts.encryptionMode.len > 0 and
     opts.encryptionMode notin ["clear", "standard", "private", "complete"]:
    raise newException(ValueError,
      "console_main: --encryption-mode must be one of clear|standard|private|complete")
  if opts.port != 0 and (opts.port < 1 or opts.port > 65535):
    raise newException(ValueError,
      "console_main: --port must be in range 1-65535, got " & $opts.port)
  if opts.watchTarget.strip.len > 0 and opts.attachIdentity.strip.len == 0:
    raise newException(ValueError,
      "console_main: --watch requires --attach")

# Flow: Run launch orchestration and return exit code plus output lines.
proc runConsoleMain*(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  try:
    let opts = parseLaunchOptions(args)

    if opts.wantHelp:
      return (0, @[ConsoleHelpText])

    validateLaunchOptions(opts)

    var overrides = RuntimeConfigOverrides()
    if opts.modeOverride.len > 0:
      overrides.mode = some(opts.modeOverride)
    if opts.encryptionMode.len > 0:
      overrides.encryptionMode = some(opts.encryptionMode)
    if opts.logLevel.len > 0:
      overrides.logLevel = some(opts.logLevel)
    if opts.port != 0:
      overrides.port = some(opts.port)

    discard loadConfigWithOverrides(opts.configPath, overrides)

    let session = newConsoleSession()
    var lines: seq[string] = @[]
    lines.add("console: config loaded from " & opts.configPath)

    if opts.attachIdentity.len > 0:
      let attached = session.cmdAttach(opts.attachIdentity, {cpRead, cpWrite, cpAdmin})
      if not attached.ok:
        return (1, attached.lines)
      lines.add(attached.lines[0])

    if opts.watchTarget.len > 0:
      let watched = session.cmdWatch(opts.watchTarget)
      if not watched.ok:
        return (1, watched.lines)
      lines.add(watched.lines[0])

    lines.add(session.renderAll())
    return (0, lines)
  except ValueError as err:
    return (2, @[err.msg, UsageText])
  except CatchableError as err:
    return (1, @["console_main: launch failed - " & err.msg])

when isMainModule:
  import std/os
  let (exitCode, lines) = runConsoleMain(commandLineParams())
  for line in lines:
    echo line
  quit(exitCode)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
