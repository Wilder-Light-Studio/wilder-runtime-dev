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
  UsageText* = "Usage: console_main --config <path> [--mode <dev|debug|prod>] [--attach <identity>] [--watch <path>]"

type
  ConsoleLaunchOptions* = object
    configPath*: string
    modeOverride*: string
    attachIdentity*: string
    watchTarget*: string

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
    else:
      raise newException(ValueError,
        "console_main: unknown argument '" & args[i] & "'")

# Flow: Validate required startup arguments and cross-flag constraints.
proc validateLaunchOptions*(opts: ConsoleLaunchOptions) =
  if opts.configPath.strip.len == 0:
    raise newException(ValueError,
      "console_main: --config is required")
  if opts.watchTarget.strip.len > 0 and opts.attachIdentity.strip.len == 0:
    raise newException(ValueError,
      "console_main: --watch requires --attach")

# Flow: Run launch orchestration and return exit code plus output lines.
proc runConsoleMain*(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  try:
    let opts = parseLaunchOptions(args)
    validateLaunchOptions(opts)

    var overrides = RuntimeConfigOverrides()
    if opts.modeOverride.len > 0:
      overrides.mode = some(opts.modeOverride)

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
