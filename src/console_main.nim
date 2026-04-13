# Wilder Cosmos 0.4.0
# Module name: console_main
# Module Path: src/console_main.nim
#
# Summary: Console CLI entrypoint for runtime startup with attach/watch flags.
# Simile: Like a launch checklist, validates launch parameters and hands off to runtime.
# Memory note: keep orchestration thin; do not duplicate config or lifecycle logic.
# Flow: parse args -> validate constraints -> load config -> emit startup report.

import std/[os, strutils, options, json, times]
import runtime/console
import runtime/config

type
  ConsoleLaunchOptions* = object
    configPath*: Option[string]
    attachIdentity*: Option[string]
    watchTarget*: Option[string]
    logLevel*: Option[string]
    encryptionMode*: Option[string]
    port*: Option[int]
    wantHelp*: bool

const
  ConsoleUsageText* =
    "Usage: console_main [--config <path>] [--attach <identity>] [--watch <path>] " &
    "[--log-level <trace|debug|info|warn|error>] [--encryption-mode <clear|standard|private|complete>] " &
    "[--port <N>] [--help]"
  ConsoleHelpText* =
    "Wilder Cosmos Runtime -- console interface\n" &
    "\n" &
    "Usage:\n" &
    "  console_main [--config <path>] [--attach <identity>] [--watch <path>]\n" &
    "  console_main --help\n" &
    "\n" &
    "Options:\n" &
    "  --config <path>              Path to runtime configuration file\n" &
    "  --attach <identity>          Identity to attach to console session\n" &
    "  --watch <path>               Path to watch (requires --attach)\n" &
    "  --log-level <level>          Log level: trace|debug|info|warn|error\n" &
    "  --encryption-mode <mode>     Encryption mode: clear|standard|private|complete\n" &
    "  --port <N>                   Port number: 1-65535\n" &
    "  --help, -h                   Print this help text and exit\n" &
    "\n" &
    "Examples:\n" &
    "  console_main --config ./runtime.json --attach operator-alpha\n" &
    "  console_main --config ./runtime.json --attach operator-beta --watch /thing/b\n" &
    "  console_main --help\n"

# Flow: Parse console command-line arguments into structured launch options.
proc parseConsoleOptions*(args: seq[string]): ConsoleLaunchOptions =
  # Pre-scan: --help/-h is sovereign; if present, return immediately.
  for arg in args:
    if arg == "--help" or arg == "-h":
      result.wantHelp = true
      return
  result.configPath = none(string)
  result.attachIdentity = none(string)
  result.watchTarget = none(string)
  result.logLevel = none(string)
  result.encryptionMode = none(string)
  result.port = none(int)
  
  var i = 0
  while i < args.len:
    case args[i]
    of "--config":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --config requires a path")
      result.configPath = some(args[i + 1])
      i += 2
    of "--attach":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --attach requires an identity")
      result.attachIdentity = some(args[i + 1])
      i += 2
    of "--watch":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --watch requires a path")
      result.watchTarget = some(args[i + 1])
      i += 2
    of "--log-level":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --log-level requires a value")
      result.logLevel = some(args[i + 1].toLowerAscii.strip)
      i += 2
    of "--encryption-mode":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --encryption-mode requires a value")
      result.encryptionMode = some(args[i + 1].toLowerAscii.strip)
      i += 2
    of "--port":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "console_main: --port requires a value")
      try:
        result.port = some(parseInt(args[i + 1]))
      except ValueError:
        raise newException(ValueError,
          "console_main: --port must be an integer, got '" & args[i + 1] & "'")
      i += 2
    of "--help", "-h":
      result.wantHelp = true
      i += 1
    else:
      raise newException(ValueError,
        "console_main: unknown argument '" & args[i] & "'")

# Flow: Validate console launch options and cross-flag constraints.
proc validateConsoleOptions*(opts: ConsoleLaunchOptions) =
  if opts.wantHelp:
    return

  if opts.configPath.isSome and opts.configPath.get().strip.len == 0:
    raise newException(ValueError,
      "console_main: --config path must not be empty")

  if opts.watchTarget.isSome and opts.attachIdentity.isNone:
    raise newException(ValueError,
      "console_main: --watch requires --attach")

  if opts.logLevel.isSome:
    let lvl = opts.logLevel.get()
    if lvl notin ["trace", "debug", "info", "warn", "error"]:
      raise newException(ValueError,
        "console_main: --log-level must be one of trace|debug|info|warn|error")

  if opts.encryptionMode.isSome:
    let mode = opts.encryptionMode.get()
    if mode notin ["clear", "standard", "private", "complete"]:
      raise newException(ValueError,
        "console_main: --encryption-mode must be one of clear|standard|private|complete")

  if opts.port.isSome:
    let p = opts.port.get()
    if p < 1 or p > 65535:
      raise newException(ValueError,
        "console_main: --port must be in range 1-65535, got " & $p)

# Flow: Execute console main entrypoint with deterministic output.
proc runConsoleMain*(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  try:
    let opts = parseConsoleOptions(args)
    
    if opts.wantHelp:
      return (0, @[ConsoleHelpText])
    
    validateConsoleOptions(opts)
    
    # Create console session for output
    let cs = newConsoleSession()
    
    # If config is provided, validate it exists
    if opts.configPath.isSome:
      let configPath = opts.configPath.get()
      if not fileExists(configPath):
        return (1, @["console_main: config file not found: " & configPath])
    
    # If attach is provided, attach the session
    if opts.attachIdentity.isSome:
      let identity = opts.attachIdentity.get()
      discard cs.cmdAttach(identity, {cpRead, cpWrite, cpAdmin})
    
    # Build output lines
    var lines: seq[string] = @[]
    
    if opts.attachIdentity.isSome:
      lines.add("attached: " & opts.attachIdentity.get())
    
    if opts.watchTarget.isSome:
      lines.add("watch: active")
    
    if opts.logLevel.isSome:
      lines.add("log-level: " & opts.logLevel.get())
    
    if opts.encryptionMode.isSome:
      lines.add("encryption-mode: " & opts.encryptionMode.get())
    
    if opts.port.isSome:
      lines.add("port: " & $opts.port.get())
    
    if lines.len == 0:
      lines.add("console_main: ready")
    
    return (0, lines)
    
  except ValueError as err:
    return (2, @[err.msg, ConsoleUsageText])
  except CatchableError as err:
    return (1, @["console_main: failed - " & err.msg])

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.