# Wilder Cosmos 0.4.0
# Module name: Cosmos Main
# Module Path: src/cosmos_main.nim
# Summary: Thin CLI entrypoint for runtime startup coordinator launch contract and flags.
# Simile: Like a mission control checklist, it validates launch parameters and hands off to the runtime lifecycle.
# Memory note: keep orchestration thin; do not duplicate config or lifecycle logic.
# Flow: parse args -> resolve console mode -> validate -> load config -> emit startup report.

import std/[os, strutils, options]
import runtime/config
import runtime/capabilities
import runtime/startapp

type
  CoordinatorConsoleMode* = enum
    ccmDetach, ccmAuto, ccmAttach

  CoordinatorLaunchOptions* = object
    configPath*: string
    modeOverride*: Option[string]       ## development|debug|production
    logLevel*: Option[string]           ## trace|debug|info|warn|error
    port*: Option[int]                  ## 1-65535
    consoleMode*: CoordinatorConsoleMode
    consoleModeExplicit*: bool          ## true if --console was explicitly provided
    watchTarget*: Option[string]
    daemonize*: bool
    wantHelp*: bool

  CoordinatorStartupReport* = object
    consoleBranch*: string              ## "detach" | "auto" | "attach"
    configPath*: string
    modeResolved*: string
    exitCode*: int

const
  CoordinatorUsageText* =
    "Usage: cosmos --config <path> [--mode <dev|debug|prod>] " &
    "[--console <auto|attach|detach>] [--watch <path>] [--daemonize] " &
    "[--log-level <trace|debug|info|warn|error>] [--port <N>] [--help]"
  CoordinatorHelpText* =
    "Wilder Cosmos Runtime -- launch and coordinate a Cosmos instance\n" &
    "\n" &
    "Subcommands:\n" &
    "  capabilities\n" &
    "  concept resolve --want <Thing|Thing.provide> [--expect-signature <sig>] --provide <Thing.provide:signature>...\n" &
    "  startapp [path] [--name <name>] [--mode <dev|debug|prod>] [--transport <json|protobuf>] [--no-template]\n" &
    "\n" &
    "Usage:\n" &
    "  cosmos --config <path> [options]\n" &
    "\n" &
    "Required:\n" &
    "  --config <path>                      Runtime config file path\n" &
    "\n" &
    "Optional:\n" &
    "  --mode <dev|debug|prod>              Override runtime mode\n" &
    "  --console <auto|attach|detach>       Console launch mode (default: detach)\n" &
    "  --watch <path>                       Watch target on initial attach\n" &
    "  --daemonize                          Run in background/detached mode\n" &
    "  --log-level <level>                  Override log level (trace|debug|info|warn|error)\n" &
    "  --port <N>                           Override port (1-65535)\n" &
    "  --help, -h                           Print this help text and exit\n" &
    "\n" &
    "Examples:\n" &
    "  cosmos --config config/runtime.json\n" &
    "  cosmos --config config/runtime.json --watch /thing/a --console attach --mode dev --log-level debug"

const
  StartAppHelpText* =
    "Usage: cosmos startapp [path] [--name <name>] [--mode <dev|debug|prod>] " &
    "[--transport <json|protobuf>] [--no-template]"
  CapabilitiesHelpText* =
    "Usage: cosmos capabilities [--want <Thing|Thing.provide>] [--expect-signature <sig>] " &
    "[--provide <Thing.provide:signature>]..."
  ConceptResolveHelpText* =
    "Usage: cosmos concept resolve --want <Thing|Thing.provide> [--expect-signature <sig>] " &
    "--provide <Thing.provide:signature>..."

# Flow: Parse Thing.provide:signature into one provider declaration.
proc parseProvideArg(raw: string): ProvideDeclaration =
  let trimmed = raw.strip
  let colon = trimmed.find(':')
  if colon < 0:
    raise newException(ValueError,
      "capabilities: --provide must be Thing.provide:signature")
  let capabilityRef = trimmed[0 ..< colon].strip
  let signature = trimmed[colon + 1 .. ^1].strip
  if signature.len == 0:
    raise newException(ValueError,
      "capabilities: --provide signature must not be empty")
  let parsed = parseWantReference(capabilityRef)
  if parsed.isWholeThing:
    raise newException(ValueError,
      "capabilities: --provide requires Thing.provide form")
  ProvideDeclaration(
    thingName: parsed.thingName,
    provideName: parsed.provideName,
    signature: signature
  )

# Flow: Parse declaration arguments shared by capabilities and concept resolve commands.
proc parseResolutionArgs(args: seq[string],
                        requireWant: bool): tuple[provides: seq[ProvideDeclaration],
                                                   wants: seq[WantDeclaration]] =
  var wantRef = ""
  var expectedSignature = ""
  var provides: seq[ProvideDeclaration] = @[]
  var i = 0
  while i < args.len:
    case args[i]
    of "--want":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "capabilities: --want requires a value")
      wantRef = args[i + 1]
      i += 2
    of "--expect-signature":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "capabilities: --expect-signature requires a value")
      expectedSignature = args[i + 1]
      i += 2
    of "--provide":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "capabilities: --provide requires a value")
      provides.add(parseProvideArg(args[i + 1]))
      i += 2
    of "--help", "-h":
      raise newException(ValueError,
        "capabilities: help-requested")
    else:
      raise newException(ValueError,
        "capabilities: unknown argument '" & args[i] & "'")

  if requireWant and wantRef.len == 0:
    raise newException(ValueError,
      "capabilities: --want is required")

  var wants: seq[WantDeclaration] = @[]
  if wantRef.len > 0:
    wants.add(WantDeclaration(
      consumerThing: "cli",
      reference: wantRef,
      expectedSignature: expectedSignature
    ))
  (provides, wants)

# Flow: Convert CLI mode shorthand to config override values.
proc normalizeCoordinatorMode(raw: string): string =
  case raw.toLowerAscii.strip
  of "dev":   "development"
  of "debug": "debug"
  of "prod":  "production"
  else:
    raise newException(ValueError,
      "cosmos: --mode must be one of dev|debug|prod")

# Flow: Parse command-line arguments into structured coordinator launch options.
proc parseCoordinatorOptions*(args: seq[string]): CoordinatorLaunchOptions =
  # Pre-scan: --help/-h is sovereign; if present, return immediately.
  for arg in args:
    if arg == "--help" or arg == "-h":
      result.wantHelp = true
      return
  result.consoleMode = ccmDetach
  var i = 0
  while i < args.len:
    case args[i]
    of "--config":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --config requires a path")
      result.configPath = args[i + 1]
      i += 2
    of "--mode":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --mode requires a value")
      result.modeOverride = some(normalizeCoordinatorMode(args[i + 1]))
      i += 2
    of "--console":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --console requires a value (auto|attach|detach)")
      case args[i + 1].toLowerAscii.strip
      of "auto":   result.consoleMode = ccmAuto
      of "attach": result.consoleMode = ccmAttach
      of "detach": result.consoleMode = ccmDetach
      else:
        raise newException(ValueError,
          "cosmos: --console must be one of auto|attach|detach")
      result.consoleModeExplicit = true
      i += 2
    of "--watch":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --watch requires a path")
      result.watchTarget = some(args[i + 1])
      i += 2
    of "--daemonize":
      result.daemonize = true
      i += 1
    of "--log-level":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --log-level requires a value")
      result.logLevel = some(args[i + 1].toLowerAscii.strip)
      i += 2
    of "--port":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --port requires a value")
      try:
        result.port = some(parseInt(args[i + 1]))
      except ValueError:
        raise newException(ValueError,
          "cosmos: --port must be an integer, got '" & args[i + 1] & "'")
      i += 2
    of "--help", "-h":
      result.wantHelp = true
      i += 1
    else:
      raise newException(ValueError,
        "cosmos: unknown argument '" & args[i] & "'")

# Flow: Resolve effective console mode when --watch is set without explicit --console.
proc resolveConsoleMode*(opts: var CoordinatorLaunchOptions) =
  if opts.watchTarget.isSome and not opts.consoleModeExplicit:
    if opts.daemonize:
      opts.consoleMode = ccmDetach
    else:
      opts.consoleMode = ccmAttach

# Flow: Validate coordinator launch options and cross-flag constraints.
proc validateCoordinatorOptions*(opts: CoordinatorLaunchOptions) =
  if opts.wantHelp:
    return
  if opts.configPath.strip.len == 0:
    raise newException(ValueError,
      "cosmos: --config is required")
  if opts.daemonize and opts.consoleModeExplicit and opts.consoleMode == ccmAttach:
    raise newException(ValueError,
      "cosmos: --daemonize and --console attach are incompatible")
  if opts.watchTarget.isSome and opts.consoleMode == ccmDetach:
    raise newException(ValueError,
      "cosmos: --watch requires an attached console mode; " &
      "use --console attach or omit --daemonize")
  if opts.logLevel.isSome:
    let lvl = opts.logLevel.get()
    if lvl notin ["trace", "debug", "info", "warn", "error"]:
      raise newException(ValueError,
        "cosmos: --log-level must be one of trace|debug|info|warn|error")
  if opts.port.isSome:
    let p = opts.port.get()
    if p < 1 or p > 65535:
      raise newException(ValueError,
        "cosmos: --port must be in range 1-65535, got " & $p)

# Flow: Execute startapp subcommand with deterministic defaults and staged writes.
proc runStartAppCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  try:
    var opts = StartAppOptions(
      targetDir: getCurrentDir(),
      appName: "",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    var i = 0
    var targetExplicit = false
    while i < args.len:
      case args[i]
      of "--help", "-h":
        return (0, @[StartAppHelpText])
      of "--name":
        if i + 1 >= args.len:
          raise newException(ValueError,
            "startapp: --name requires a value")
        opts.appName = args[i + 1]
        i += 2
      of "--mode":
        if i + 1 >= args.len:
          raise newException(ValueError,
            "startapp: --mode requires a value")
        opts.mode = args[i + 1]
        i += 2
      of "--transport":
        if i + 1 >= args.len:
          raise newException(ValueError,
            "startapp: --transport requires a value")
        opts.transport = args[i + 1]
        i += 2
      of "--no-template":
        opts.includeTemplate = false
        i += 1
      else:
        if args[i].startsWith("--"):
          raise newException(ValueError,
            "startapp: unknown argument '" & args[i] & "'")
        if targetExplicit:
          raise newException(ValueError,
            "startapp: only one target path may be provided")
        opts.targetDir = args[i]
        targetExplicit = true
        i += 1
    return (0, scaffoldApp(opts))
  except ValueError as err:
    return (2, @[err.msg, StartAppHelpText])
  except CatchableError as err:
    return (1, @["startapp: failed - " & err.msg])

# Flow: Execute capabilities subcommand with deterministic summary output.
proc runCapabilitiesCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 1 and (args[0] == "--help" or args[0] == "-h"):
    return (0, @[CapabilitiesHelpText])
  try:
    let parsed = parseResolutionArgs(args, requireWant = false)
    let resolution = resolveCapabilities(parsed.provides, parsed.wants)
    var lines = @[
      "providers: " & $parsed.provides.len,
      "wants: " & $parsed.wants.len,
      "bindings: " & $resolution.bindings.len,
      "issues: " & $resolution.issues.len
    ]
    for issue in resolution.issues:
      lines.add("issue: " & $issue.kind & " " & issue.reference)
    return (0, lines)
  except ValueError as err:
    if err.msg == "capabilities: help-requested":
      return (0, @[CapabilitiesHelpText])
    return (2, @[err.msg, CapabilitiesHelpText])

# Flow: Execute concept resolve subcommand for a single want mapping inspection.
proc runConceptResolveCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 1 and (args[0] == "--help" or args[0] == "-h"):
    return (0, @[ConceptResolveHelpText])
  try:
    let parsed = parseResolutionArgs(args, requireWant = true)
    let resolution = resolveCapabilities(parsed.provides, parsed.wants)
    for issue in resolution.issues:
      if issue.kind in [cikMissingProviderThing, cikMissingProvide,
                        cikProviderConflict, cikSignatureMismatch]:
        return (2, @["resolve: unresolved - " & issue.detail, ConceptResolveHelpText])
    if resolution.bindings.len == 0:
      return (2, @["resolve: unresolved - no binding produced", ConceptResolveHelpText])

    var lines = @["resolve: ok", "bindings: " & $resolution.bindings.len]
    for binding in resolution.bindings:
      lines.add("binding: " & binding.reference & " -> " &
        binding.providerThing & "." & binding.provideName &
        " [" & binding.signature & "]")
    return (0, lines)
  except ValueError as err:
    if err.msg == "capabilities: help-requested":
      return (0, @[ConceptResolveHelpText])
    return (2, @[err.msg, ConceptResolveHelpText])

# Flow: Run coordinator launch orchestration and return exit code plus output lines.
proc runCoordinatorMain*(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len > 0 and args[0] == "capabilities":
    return runCapabilitiesCommand(args[1 .. ^1])
  if args.len > 1 and args[0] == "concept" and args[1] == "resolve":
    return runConceptResolveCommand(args[2 .. ^1])
  if args.len > 0 and args[0] == "startapp":
    return runStartAppCommand(args[1 .. ^1])
  try:
    var opts = parseCoordinatorOptions(args)

    if opts.wantHelp:
      return (0, @[CoordinatorHelpText])

    resolveConsoleMode(opts)
    validateCoordinatorOptions(opts)

    var overrides = RuntimeConfigOverrides()
    if opts.modeOverride.isSome:
      overrides.mode = opts.modeOverride
    if opts.logLevel.isSome:
      overrides.logLevel = opts.logLevel
    if opts.port.isSome:
      overrides.port = opts.port

    discard loadConfigWithOverrides(opts.configPath, overrides)

    let branchName = case opts.consoleMode
      of ccmDetach: "detach"
      of ccmAttach: "attach"
      of ccmAuto:   "auto"

    let modeStr = if opts.modeOverride.isSome: opts.modeOverride.get()
                  else: "from-config"

    let report = CoordinatorStartupReport(
      consoleBranch: branchName,
      configPath:    opts.configPath,
      modeResolved:  modeStr,
      exitCode:      0
    )
    return (0, @[
      "cosmos: config loaded from " & report.configPath,
      "cosmos: startup branch " & report.consoleBranch,
      "cosmos: mode " & report.modeResolved
    ])
  except ValueError as err:
    return (2, @[err.msg, CoordinatorUsageText])
  except CatchableError as err:
    return (1, @["cosmos: launch failed - " & err.msg])

when isMainModule:
  import std/os
  let (exitCode, lines) = runCoordinatorMain(commandLineParams())
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