# Wilder Cosmos 0.4.0
# Module name: Cosmos Main
# Module Path: src/cosmos_main.nim
# Summary: Thin CLI entrypoint for runtime startup coordinator launch contract and flags.
# Simile: Like a mission control checklist, it validates launch parameters and hands off to the runtime lifecycle.
# Memory note: keep orchestration thin; do not duplicate config or lifecycle logic.
# Flow: parse args -> resolve console mode -> validate -> load config -> emit startup report.

import std/[os, strutils, options, json, times, tables, algorithm, threadpool]
import runtime/config
import runtime/capabilities
import runtime/concepts
import runtime/coordinator_ipc
import runtime/scanner
import runtime/startapp
import runtime/core
import cosmos/thing/thing
import cosmos/runtime/scheduler
import cli_parser

type
  RuntimeStartMode = enum
    rsmStep
    rsmContinuous
    rsmPeriodic

  StartLaunchOptions = object
    configPath: string
    runtimeMode: RuntimeStartMode
    withPaths: seq[string]
    logLevel: string

  CoordinatorConsoleMode* = enum
    ccmDetach, ccmAuto, ccmAttach

  CoordinatorLaunchOptions* = object
    configPath*: Option[string]         ## optional config file path
    modeOverride*: Option[string]       ## development|debug|production (required if no config)
    transport*: Option[string]          ## json|protobuf (required if no config)
    encryptionMode*: Option[string]     ## clear|standard|private|complete
    logLevel*: Option[string]           ## trace|debug|info|warn|error (required if no config)
    endpoint*: Option[string]           ## hostname/IP (required if no config)
    port*: Option[int]                  ## 1-65535 (required if no config)
    consoleMode*: CoordinatorConsoleMode
    consoleModeExplicit*: bool          ## true if --console was explicitly provided
    watchTarget*: Option[string]
    daemonize*: bool
    startupProvides*: seq[ProvideDeclaration]
    startupWants*: seq[WantDeclaration]
    startupBindings*: seq[ModuleBindingDeclaration]
    wantHelp*: bool

  CoordinatorStartupReport* = object
    consoleBranch*: string              ## "detach" | "auto" | "attach"
    configPath*: string
    modeResolved*: string
    exitCode*: int

const
  CoordinatorUsageText* =
    "Usage: cosmos [--config <path>] [--mode <dev|debug|prod>] [--transport <json|protobuf>] " &
    "[--log-level <trace|debug|info|warn|error>] [--endpoint <host>] [--port <N>] " &
    "[--encryption-mode <clear|standard|private|complete>] " &
    "[--console <auto|attach|detach>] [--watch <path>] [--daemonize] " &
    "[--capability-provide <Thing.provide:signature>] " &
    "[--capability-want <Thing|Thing.provide>] " &
    "[--capability-bind <Thing.provide:moduleType:moduleRef:entrypoint:abiVersion>] " &
    "[--help]"
  CoordinatorHelpText* =
    "Wilder Cosmos Runtime -- command interface\n" &
    "\n" &
    "Commands:\n" &
    "  start [--mode <step|continuous|periodic>] [--config <path>] [--with <path>]... [--loglevel <info|warn|error|debug>]\n" &
    "  capabilities\n" &
    "  ipc request --method <name> [--id <id>] [--params-json <json>] [--subscribe <event>]... [--tcp] [--host <host>] [--port <N>]\n" &
    "  ipc endpoint [--host <host>] [--port <N>]\n" &
    "  ipc serve [--host <host>] [--port <N>] [--max-requests <N>]\n" &
    "  notify format --time <iso> --level <level> --component <component> --message <text>\n" &
    "  scan [path] [--json]\n" &
    "  capability conflicts [path]\n" &
    "  concept resolve --want <Thing|Thing.provide> [--expect-signature <sig>] --provide <Thing.provide:signature>...\n" &
    "  concept show --file <path> [--source-kind programmatic|manual] [--derived-from <str>]\n" &
    "  concept validate --file <path>\n" &
    "  concept export --file <path> [--source-kind programmatic|manual] [--derived-from <str>]\n" &
    "  concept registry [--file <path>]... | concept registry inspect --id <id> [--file <path>]...\n" &
    "  startapp [path] [--name <name>] [--mode <dev|debug|prod>] [--transport <json|protobuf>] [--no-template]\n" &
    "\n" &
    "Usage:\n" &
    "  cosmos\n" &
    "      Show this help text.\n" &
    "  cosmos start [options]\n" &
    "      Start runtime explicitly.\n" &
    "\n" &
    "Optional:\n" &
    "  (start) --mode <step|continuous|periodic>     Runtime frame strategy (default: continuous)\n" &
    "  (start) --config <path>                       Optional world/runtime config path\n" &
    "  (start) --with <path>                         Optional Thing or directory to load (repeatable)\n" &
    "  (start) --loglevel <info|warn|error|debug>   Optional startup log level\n" &
    "  --capability-provide <decl>          Startup capability provide declaration\n" &
    "  --capability-want <ref>              Startup capability want declaration\n" &
    "  --capability-bind <decl>             Startup capability implementation binding\n" &
    "  --help, -h                           Print this help text and exit\n" &
    "\n" &
    "Reserved (not implemented yet):\n" &
    "  inspect, shell, daemon, stop, list, attach, detach\n" &
    "\n" &
    "Examples:\n" &
    "  cosmos\n" &
    "  cosmos start\n" &
    "  cosmos start --mode step\n" &
    "  cosmos start --config ./world.json\n" &
    "  cosmos start --with ./things/fsbridge --with ./things/logger\n" &
    "  cosmos start --mode step --config ./world.json --with ./things/fsbridge"

const
  StartHelpText* =
    "Usage: cosmos start [--mode <step|continuous|periodic>] [--config <path>] " &
    "[--with <path>]... [--loglevel <info|warn|error|debug>]"

let ReservedCommands = ["inspect", "shell", "daemon", "stop", "list", "attach", "detach"]

const
  StartAppHelpText* =
    "Usage: cosmos startapp [path] [--name <name>] [--mode <dev|debug|prod>] " &
    "[--transport <json|protobuf>] [--no-template]"
  CapabilitiesHelpText* =
    "Usage: cosmos capabilities [--want <Thing|Thing.provide>] [--expect-signature <sig>] " &
    "[--provide <Thing.provide:signature>] " &
    "[--bind <Thing.provide:moduleType:moduleRef:entrypoint:abiVersion>]..."
  ConceptResolveHelpText* =
    "Usage: cosmos concept resolve --want <Thing|Thing.provide> [--expect-signature <sig>] " &
    "--provide <Thing.provide:signature> " &
    "[--bind <Thing.provide:moduleType:moduleRef:entrypoint:abiVersion>]..."
  ScanHelpText* =
    "Usage: cosmos scan [path] [--json]"
  CapabilityConflictsHelpText* =
    "Usage: cosmos capability conflicts [path]"
  IpcRequestHelpText* =
    "Usage: cosmos ipc request --method <name> [--id <id>] [--params-json <json>] [--subscribe <event>]... [--tcp] [--host <host>] [--port <N>]"
  IpcEndpointHelpText* =
    "Usage: cosmos ipc endpoint [--host <host>] [--port <N>]"
  IpcServeHelpText* =
    "Usage: cosmos ipc serve [--host <host>] [--port <N>] [--max-requests <N>]"
  NotifyFormatHelpText* =
    "Usage: cosmos notify format --time <iso> --level <level> --component <component> --message <text>"
  ConceptShowHelpText* =
    "Usage: cosmos concept show --file <path> [--source-kind programmatic|manual] [--derived-from <str>]"
  ConceptValidateHelpText* =
    "Usage: cosmos concept validate --file <path>"
  ConceptExportHelpText* =
    "Usage: cosmos concept export --file <path> [--source-kind programmatic|manual] [--derived-from <str>]"
  ConceptRegistryHelpText* =
    "Usage: cosmos concept registry [--file <path>]... | " &
    "cosmos concept registry inspect --id <id> [--file <path>]..."

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

# Flow: Parse Thing.provide:moduleType:moduleRef:entrypoint:abiVersion into one module binding declaration.
proc parseBindingArg(raw: string): ModuleBindingDeclaration =
  let trimmed = raw.strip
  let fields = trimmed.split(':')
  if fields.len != 5:
    raise newException(ValueError,
      "capabilities: --bind must be Thing.provide:moduleType:moduleRef:entrypoint:abiVersion")

  let parsed = parseWantReference(fields[0].strip)
  if parsed.isWholeThing:
    raise newException(ValueError,
      "capabilities: --bind requires Thing.provide form")

  ModuleBindingDeclaration(
    provideKey: parsed.thingName & "." & parsed.provideName,
    moduleType: fields[1].strip,
    moduleRef: fields[2].strip,
    entrypoint: fields[3].strip,
    abiVersion: fields[4].strip
  )

# Flow: Parse declaration arguments shared by capabilities and concept resolve commands.
proc parseResolutionArgs(args: seq[string],
                        requireWant: bool): tuple[
                          provides: seq[ProvideDeclaration],
                          wants: seq[WantDeclaration],
                          bindings: seq[ModuleBindingDeclaration]
                        ] =
  var wantRef = ""
  var expectedSignature = ""
  var provides: seq[ProvideDeclaration] = @[]
  var bindings: seq[ModuleBindingDeclaration] = @[]
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
    of "--bind":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "capabilities: --bind requires a value")
      bindings.add(parseBindingArg(args[i + 1]))
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
  (provides, wants, bindings)

# Flow: Convert CLI mode shorthand to config override values.
proc normalizeCoordinatorMode(raw: string): string =
  case raw.toLowerAscii.strip
  of "dev":   "development"
  of "debug": "debug"
  of "prod":  "production"
  else:
    raise newException(ValueError,
      "cosmos: --mode must be one of dev|debug|prod")

# Flow: Parse and normalize encryption mode to canonical config text.
proc normalizeCoordinatorEncryptionMode(raw: string): string =
  encryptionModeName(parseEncryptionMode(raw))

# Flow: Guard accidental root-level traversal for CLI filesystem arguments.
proc rejectFilesystemRoot(path: string, flagName: string) =
  let normalized = absolutePath(path.strip)
  if normalized.len == 0:
    raise newException(ValueError,
      flagName & ": path must not be empty")
  if parentDir(normalized) == normalized:
    raise newException(ValueError,
      flagName & ": refusing filesystem root path '" & normalized & "'")

var cliRequestCounter = 0

# Flow: Generate a per-invocation request id for CLI IPC frames.
proc nextCliRequestId(): string =
  inc cliRequestCounter
  "cli-" & $int(epochTime() * 1000) & "-" & $cliRequestCounter

# Flow: Parse startup capability want reference for launch-time fatal-gate checks.
proc parseStartupCapabilityWant(raw: string): WantDeclaration =
  let trimmed = raw.strip
  discard parseWantReference(trimmed)
  WantDeclaration(
    consumerThing: "startup",
    reference: trimmed,
    expectedSignature: ""
  )

# Flow: Derive one concept registry snapshot from runtime boundary declarations.
proc buildDerivedConceptRegistry(provides: seq[ProvideDeclaration],
                                 wants: seq[WantDeclaration],
                                 bindings: seq[ModuleBindingDeclaration]): ConceptRegistry =
  result = newConceptRegistry()
  var seen = initTable[string, bool]()

  for provide in provides:
    let thing = provide.thingName.strip
    if thing.len > 0:
      seen[thing] = true

  for want in wants:
    let consumer = want.consumerThing.strip
    if consumer.len > 0 and consumer != "cli" and consumer != "startup":
      seen[consumer] = true
    let parsed = parseWantReference(want.reference)
    if parsed.thingName.len > 0:
      seen[parsed.thingName] = true

  var thingNames: seq[string] = @[]
  for thing, _ in seen.pairs:
    thingNames.add(thing)
  thingNames.sort(system.cmp[string])

  for thing in thingNames:
    registerConceptFromBoundaryDeclarations(
      result,
      thing,
      provides,
      wants,
      bindings,
      derivedFrom = "nim-boundary"
    )

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
      result.configPath = some(args[i + 1])
      i += 2
    of "--mode":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --mode requires a value")
      result.modeOverride = some(normalizeCoordinatorMode(args[i + 1]))
      i += 2
    of "--transport":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --transport requires a value")
      let t = args[i + 1].toLowerAscii.strip
      if t notin ["json", "protobuf"]:
        raise newException(ValueError,
          "cosmos: --transport must be one of json|protobuf, got '" & t & "'")
      result.transport = some(t)
      i += 2
    of "--endpoint":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --endpoint requires a value")
      result.endpoint = some(args[i + 1].strip)
      i += 2
    of "--encryption-mode":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --encryption-mode requires a value")
      result.encryptionMode = some(normalizeCoordinatorEncryptionMode(args[i + 1]))
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
    of "--capability-provide":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --capability-provide requires a value")
      result.startupProvides.add(parseProvideArg(args[i + 1]))
      i += 2
    of "--capability-want":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --capability-want requires a value")
      result.startupWants.add(parseStartupCapabilityWant(args[i + 1]))
      i += 2
    of "--capability-bind":
      if i + 1 >= args.len:
        raise newException(ValueError,
          "cosmos: --capability-bind requires a value")
      result.startupBindings.add(parseBindingArg(args[i + 1]))
      i += 2
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

# Flow: Parse runtime start mode from CLI.
proc parseRuntimeStartMode(raw: string): RuntimeStartMode =
  case raw.strip.toLowerAscii
  of "step": rsmStep
  of "continuous": rsmContinuous
  of "periodic": rsmPeriodic
  else:
    raise newException(ValueError,
      "start: --mode must be one of step|continuous|periodic")

# Flow: Validate start command log level.
proc parseStartLogLevel(raw: string): string =
  let level = raw.strip.toLowerAscii
  if level notin ["info", "warn", "error", "debug"]:
    raise newException(ValueError,
      "start: --loglevel must be one of info|warn|error|debug")
  level

# Flow: Parse explicit runtime start command options.
proc parseStartOptions(args: seq[string]): StartLaunchOptions =
  result.runtimeMode = rsmContinuous
  result.withPaths = @[]
  result.logLevel = "info"
  var i = 0
  while i < args.len:
    case args[i]
    of "--help", "-h":
      raise newException(ValueError, "start: help-requested")
    of "--mode":
      if i + 1 >= args.len:
        raise newException(ValueError, "start: --mode requires a value")
      result.runtimeMode = parseRuntimeStartMode(args[i + 1])
      i += 2
    of "--config":
      if i + 1 >= args.len:
        raise newException(ValueError, "start: --config requires a path")
      result.configPath = args[i + 1].strip
      i += 2
    of "--with":
      if i + 1 >= args.len:
        raise newException(ValueError, "start: --with requires a path")
      result.withPaths.add(args[i + 1].strip)
      i += 2
    of "--loglevel":
      if i + 1 >= args.len:
        raise newException(ValueError, "start: --loglevel requires a value")
      result.logLevel = parseStartLogLevel(args[i + 1])
      i += 2
    else:
      raise newException(ValueError,
        "start: unknown argument '" & args[i] & "'")

# Flow: Collect deterministic Thing IDs from one --with path list.
proc collectThingIdsFromPaths(paths: seq[string]): tuple[ids: seq[string], warnings: seq[string]] =
  var expandedFiles: seq[string] = @[]
  var warnings: seq[string] = @[]

  for rawPath in paths:
    let path = rawPath.strip
    if path.len == 0:
      warnings.add("start: warning - empty --with path ignored")
      continue
    if fileExists(path):
      expandedFiles.add(path)
      continue
    if dirExists(path):
      for filePath in walkDirRec(path):
        if fileExists(filePath):
          expandedFiles.add(filePath)
      continue
    warnings.add("start: warning - --with path not found: " & path)

  expandedFiles.sort(system.cmp[string])
  var ids: seq[string] = @[]
  for filePath in expandedFiles:
    let name = splitFile(filePath).name.strip
    if name.len == 0:
      warnings.add("start: warning - could not derive Thing id from path: " & filePath)
    else:
      ids.add(name)
  (ids, warnings)

# Flow: Launch the runtime as a long-running daemon.
proc launchDaemon(): int =
  try:
    let lc = newRuntimeLifecycle()
    startup(lc)
    
    echo "cosmos: daemon initialized"
    lc.printBanner()
    
    let session = newIpcSession(lc)
    
    # Start IPC server in a background thread
    var ipcThread: Thread[IpcSession]
    proc ipcServerThread(session: IpcSession) {.thread.} =
      discard serveIpcTcp(session)
    createThread(ipcThread, ipcServerThread, session)
    
    echo "cosmos: IPC server listening on " & ipcEndpointUri()
    
    # Main loop: Frame execution
    while true:
      if session.state.paused:
        sleep(100)
      else:
        # In a real implementation, this would be the scheduler's frame loop
        # For now, we simulate the frame loop
        discard executeFrame(lc.schedulerState, @[])
        sleep(16) # ~60fps
        
  except CatchableError as err:
    echo "cosmos: daemon fatal error - " & err.msg
    return 1
  return 0

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

  if opts.configPath.isSome and opts.configPath.get().strip.len == 0:
    raise newException(ValueError,
      "cosmos: --config path must not be empty")

  if opts.endpoint.isSome and opts.endpoint.get().strip.len == 0:
    raise newException(ValueError,
      "cosmos: --endpoint must not be empty")
  
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
  
  if opts.encryptionMode.isSome:
    let mode = opts.encryptionMode.get()
    if mode notin ["clear", "standard", "private", "complete"]:
      raise newException(ValueError,
        "cosmos: --encryption-mode must be one of clear|standard|private|complete")
  
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
    let graph = buildCapabilityGraph(
      parsed.provides,
      parsed.wants,
      parsed.bindings,
      enforceBindingCoverage = parsed.bindings.len > 0
    )
    let resolution = graph.resolution
    var lines = @[
      "things: " & $graph.things.len,
      "providers: " & $parsed.provides.len,
      "wants: " & $parsed.wants.len,
      "signatures: " & $graph.signatures.len,
      "moduleBindings: " & $parsed.bindings.len,
      "bindings: " & $resolution.bindings.len,
      "issues: " & $resolution.issues.len,
      "startupEligible: " & $graph.startupEligible
    ]

    for thing in graph.things:
      lines.add("thing: " & thing)
    for provide in graph.provides:
      lines.add("provide: " & provide.thingName & "." &
        provide.provideName & " [" & provide.signature & "]")
    for want in graph.wants:
      lines.add("want: " & want.consumerThing & " -> " & want.reference)
    for binding in graph.moduleBindings:
      lines.add("moduleBinding: " & binding.provideKey & " -> " &
        binding.moduleType & ":" & binding.moduleRef & ":" &
        binding.entrypoint & ":" & binding.abiVersion)

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
    let resolution = resolveCapabilities(
      parsed.provides,
      parsed.wants,
      parsed.bindings,
      enforceBindingCoverage = parsed.bindings.len > 0
    )
    var fatalIssues: seq[CapabilityIssue] = @[]
    for issue in resolution.issues:
      if issueIsFatal(issue):
        fatalIssues.add(issue)

    if fatalIssues.len > 0:
      var lines = @["resolve: unresolved"]
      for issue in fatalIssues:
        lines.add("cause: " & issue.detail)
      lines.add(ConceptResolveHelpText)
      return (2, lines)

    if resolution.bindings.len == 0:
      return (2, @["resolve: unresolved - no binding produced", ConceptResolveHelpText])

    let registry = buildDerivedConceptRegistry(parsed.provides, parsed.wants, parsed.bindings)
    let conceptIds = listConceptIds(registry)

    var lines = @[
      "resolve: ok",
      "bindings: " & $resolution.bindings.len,
      "concepts-derived: " & $conceptIds.len
    ]
    for binding in resolution.bindings:
      lines.add("binding: " & binding.reference & " -> " &
        binding.providerThing & "." & binding.provideName &
        " [" & binding.signature & "]")
    return (0, lines)
  except ValueError as err:
    if err.msg == "capabilities: help-requested":
      return (0, @[ConceptResolveHelpText])
    return (2, @[err.msg, ConceptResolveHelpText])

# Flow: Parse a concept JSON file into a Concept object.
proc loadConceptFromFile(path: string): Concept =
  rejectFilesystemRoot(path, "concept: --file")
  if not fileExists(path):
    raise newException(ValueError,
      "concept: file not found: '" & path & "'")
  let raw = readFile(path)
  let node = parseJson(raw)
  if node.kind != JObject:
    raise newException(ValueError,
      "concept: file must contain a JSON object")
  let id = node{"id"}.getStr("").strip
  if id.len == 0:
    raise newException(ValueError,
      "concept: 'id' field must not be empty")
  let whyNode      = if node.hasKey("why"):      node["why"]      else: %*{}
  let whatNode     = if node.hasKey("what"):     node["what"]     else: %*{}
  let howNode      = if node.hasKey("how"):      node["how"]      else: %*{}
  let whereNode    = if node.hasKey("where"):    node["where"]    else: %*{}
  let whenNode     = if node.hasKey("when"):     node["when"]     else: %*{}
  let withNode     = if node.hasKey("with"):     node["with"]     else: %*{}
  let manifestNode = if node.hasKey("manifest"): node["manifest"] else: %*{}
  createConcept(id, whatNode, whyNode, howNode, whereNode, whenNode, withNode, manifestNode)

# Flow: Map CLI source kind string to ConceptSourceKind enum.
proc normalizeConceptSourceKind(raw: string): ConceptSourceKind =
  case raw.strip.toLowerAscii
  of "", "manual":
    cskManual
  of "programmatic", "code":
    cskProgrammatic
  else:
    raise newException(ValueError,
      "concept: --source-kind must be programmatic or manual, got '" & raw & "'")

# Flow: Execute concept validate CLI command.
proc runConceptValidateCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 0 or (args.len == 1 and (args[0] == "--help" or args[0] == "-h")):
    return (0, @[ConceptValidateHelpText])
  var filePath = ""
  var i = 0
  while i < args.len:
    case args[i]
    of "--help", "-h":
      return (0, @[ConceptValidateHelpText])
    of "--file":
      if i + 1 >= args.len:
        return (2, @["concept validate: --file requires a path", ConceptValidateHelpText])
      filePath = args[i + 1]
      i += 2
    else:
      return (2, @["concept validate: unknown argument '" & args[i] & "'", ConceptValidateHelpText])
  if filePath.len == 0:
    return (2, @["concept validate: --file is required", ConceptValidateHelpText])
  try:
    let c = loadConceptFromFile(filePath)
    validateConcept(c)
    return (0, @["validate: ok", "concept: " & c.id])
  except ValueError as err:
    return (2, @["validate: error - " & err.msg])
  except JsonParsingError as err:
    return (2, @["validate: error - invalid JSON: " & err.msg])

# Flow: Execute concept show CLI command.
proc runConceptShowCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 0 or (args.len == 1 and (args[0] == "--help" or args[0] == "-h")):
    return (0, @[ConceptShowHelpText])
  var filePath = ""
  var sourceKindRaw = "manual"
  var derivedFrom = ""
  var i = 0
  while i < args.len:
    case args[i]
    of "--help", "-h":
      return (0, @[ConceptShowHelpText])
    of "--file":
      if i + 1 >= args.len:
        return (2, @["concept show: --file requires a path", ConceptShowHelpText])
      filePath = args[i + 1]
      i += 2
    of "--source-kind":
      if i + 1 >= args.len:
        return (2, @["concept show: --source-kind requires a value", ConceptShowHelpText])
      sourceKindRaw = args[i + 1]
      i += 2
    of "--derived-from":
      if i + 1 >= args.len:
        return (2, @["concept show: --derived-from requires a value", ConceptShowHelpText])
      derivedFrom = args[i + 1]
      i += 2
    else:
      return (2, @["concept show: unknown argument '" & args[i] & "'", ConceptShowHelpText])
  if filePath.len == 0:
    return (2, @["concept show: --file is required", ConceptShowHelpText])
  try:
    let c = loadConceptFromFile(filePath)
    validateConcept(c)
    let sourceKind = normalizeConceptSourceKind(sourceKindRaw)
    let sourceLabel = if sourceKind == cskProgrammatic: "programmatic" else: "manual"
    return (0, @[
      "concept: " & c.id,
      "source: " & sourceLabel,
      "derived-from: " & (if derivedFrom.len > 0: derivedFrom else: "(not set)"),
      "valid: true"
    ])
  except ValueError as err:
    return (2, @["concept show: error - " & err.msg, ConceptShowHelpText])
  except JsonParsingError as err:
    return (2, @["concept show: error - invalid JSON: " & err.msg, ConceptShowHelpText])

# Flow: Execute concept export CLI command.
proc runConceptExportCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 0 or (args.len == 1 and (args[0] == "--help" or args[0] == "-h")):
    return (0, @[ConceptExportHelpText])
  var filePath = ""
  var sourceKindRaw = "manual"
  var dfRaw = "manual-file"
  var i = 0
  while i < args.len:
    case args[i]
    of "--help", "-h":
      return (0, @[ConceptExportHelpText])
    of "--file":
      if i + 1 >= args.len:
        return (2, @["concept export: --file requires a path", ConceptExportHelpText])
      filePath = args[i + 1]
      i += 2
    of "--source-kind":
      if i + 1 >= args.len:
        return (2, @["concept export: --source-kind requires a value", ConceptExportHelpText])
      sourceKindRaw = args[i + 1]
      i += 2
    of "--derived-from":
      if i + 1 >= args.len:
        return (2, @["concept export: --derived-from requires a value", ConceptExportHelpText])
      dfRaw = args[i + 1]
      i += 2
    else:
      return (2, @["concept export: unknown argument '" & args[i] & "'", ConceptExportHelpText])
  if filePath.len == 0:
    return (2, @["concept export: --file is required", ConceptExportHelpText])
  try:
    let c = loadConceptFromFile(filePath)
    validateConcept(c)
    let sourceKind = normalizeConceptSourceKind(sourceKindRaw)
    let reg = newConceptRegistry()
    case sourceKind
    of cskProgrammatic:
      registerProgrammaticConcept(reg, c, derivedFrom = dfRaw)
    of cskManual:
      registerManualConcept(reg, c, derivedFrom = dfRaw)
    let exported = exportEffectiveConcept(reg, c.id)
    return (0, @[exported.pretty])
  except ValueError as err:
    return (2, @["concept export: error - " & err.msg, ConceptExportHelpText])
  except JsonParsingError as err:
    return (2, @["concept export: error - invalid JSON: " & err.msg, ConceptExportHelpText])

# Flow: Execute concept registry list and inspect commands.
proc runConceptRegistryCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 0 or (args.len == 1 and (args[0] == "--help" or args[0] == "-h")):
    return (0, @[ConceptRegistryHelpText])
  let isInspect = args.len > 0 and args[0] == "inspect"
  let parseArgs = if isInspect: args[1 .. ^1] else: args
  var files: seq[string] = @[]
  var sourceKinds: seq[string] = @[]
  var derivedFroms: seq[string] = @[]
  var inspectId = ""
  var i = 0
  while i < parseArgs.len:
    case parseArgs[i]
    of "--help", "-h":
      return (0, @[ConceptRegistryHelpText])
    of "--file":
      if i + 1 >= parseArgs.len:
        return (2, @["concept registry: --file requires a path", ConceptRegistryHelpText])
      files.add(parseArgs[i + 1])
      sourceKinds.add("manual")
      derivedFroms.add("manual-file")
      i += 2
    of "--source-kind":
      if i + 1 >= parseArgs.len:
        return (2, @["concept registry: --source-kind requires a value", ConceptRegistryHelpText])
      if sourceKinds.len > 0:
        sourceKinds[^1] = parseArgs[i + 1]
      i += 2
    of "--derived-from":
      if i + 1 >= parseArgs.len:
        return (2, @["concept registry: --derived-from requires a value", ConceptRegistryHelpText])
      if derivedFroms.len > 0:
        derivedFroms[^1] = parseArgs[i + 1]
      i += 2
    of "--id":
      if i + 1 >= parseArgs.len:
        return (2, @["concept registry: --id requires a value", ConceptRegistryHelpText])
      inspectId = parseArgs[i + 1]
      i += 2
    else:
      return (2, @["concept registry: unknown argument '" & parseArgs[i] & "'", ConceptRegistryHelpText])
  try:
    let reg = newConceptRegistry()
    for j in 0 ..< files.len:
      let c = loadConceptFromFile(files[j])
      validateConcept(c)
      let sk = normalizeConceptSourceKind(sourceKinds[j])
      case sk
      of cskProgrammatic:
        registerProgrammaticConcept(reg, c, derivedFrom = derivedFroms[j])
      of cskManual:
        registerManualConcept(reg, c, derivedFrom = derivedFroms[j])
    if isInspect:
      if inspectId.len == 0:
        return (2, @["concept registry inspect: --id is required", ConceptRegistryHelpText])
      let record = conceptRegistryRecord(reg, inspectId)
      return (0, @[record.pretty])
    let ids = listConceptIds(reg)
    var lines: seq[string] = @["concepts: " & $ids.len]
    for id in ids:
      let rec = conceptRegistryRecord(reg, id)
      lines.add("concept: " & id & " [" & rec["effectiveSourceKind"].getStr("?") & "]")
    return (0, lines)
  except ValueError as err:
    return (2, @["concept registry: error - " & err.msg, ConceptRegistryHelpText])
  except KeyError as err:
    return (2, @["concept registry: not found - " & err.msg, ConceptRegistryHelpText])
  except JsonParsingError as err:
    return (2, @["concept registry: invalid JSON - " & err.msg, ConceptRegistryHelpText])

# Flow: Execute semantic scanner subcommand for one target path.
proc runScanCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  var target = getCurrentDir()
  var asJson = false
  var i = 0
  while i < args.len:
    case args[i]
    of "--help", "-h":
      return (0, @[ScanHelpText])
    of "--json":
      asJson = true
      inc i
    else:
      if args[i].startsWith("--"):
        return (2, @["scan: unknown argument '" & args[i] & "'", ScanHelpText])
      target = args[i]
      inc i

  try:
    rejectFilesystemRoot(target, "scan")
    if asJson:
      return (0, @[scanThingsJson(target).pretty])
    let things = scanPath(target)
    let conflicts = findCapabilityConflicts(things)
    return (0, @[
      "scan: ok",
      "target: " & target,
      "things: " & $things.len,
      "conflicts: " & $conflicts.len
    ])
  except ValueError as err:
    return (2, @["scan: failed - " & err.msg, ScanHelpText])

# Flow: Execute capability conflict report command from scanner output.
proc runCapabilityConflictsCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len > 0 and (args[0] == "--help" or args[0] == "-h"):
    return (0, @[CapabilityConflictsHelpText])
  let target = if args.len > 0: args[0] else: getCurrentDir()
  try:
    let conflicts = findCapabilityConflicts(scanPath(target))
    if conflicts.len == 0:
      return (0, @["capability conflicts: none"]) 
    var lines = @["capability conflicts: " & $conflicts.len]
    for conflict in conflicts:
      lines.add(conflict)
    return (0, lines)
  except ValueError as err:
    return (2, @["capability conflicts: failed - " & err.msg, CapabilityConflictsHelpText])

# Flow: Execute IPC request/endpoint command set for deterministic schema contracts.
proc runIpcCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 0 or args[0] == "--help" or args[0] == "-h":
    return (0, @[IpcRequestHelpText, IpcEndpointHelpText, IpcServeHelpText])

  case args[0]
  of "endpoint":
    var host = IpcDefaultHost
    var port = IpcDefaultPort
    var i = 1
    while i < args.len:
      case args[i]
      of "--help", "-h":
        return (0, @[IpcEndpointHelpText])
      of "--host":
        if i + 1 >= args.len:
          return (2, @["ipc endpoint: --host requires a value", IpcEndpointHelpText])
        host = args[i + 1]
        i += 2
      of "--port":
        if i + 1 >= args.len:
          return (2, @["ipc endpoint: --port requires a value", IpcEndpointHelpText])
        try:
          port = parseInt(args[i + 1])
        except ValueError:
          return (2, @["ipc endpoint: --port must be an integer", IpcEndpointHelpText])
        i += 2
      else:
        return (2, @["ipc endpoint: unknown argument '" & args[i] & "'", IpcEndpointHelpText])
    try:
      return (0, @[ipcEndpointUri(host, port)])
    except ValueError as err:
      return (2, @[err.msg, IpcEndpointHelpText])

  of "serve":
    var host = IpcDefaultHost
    var port = IpcDefaultPort
    var maxRequests = 0
    var i = 1
    while i < args.len:
      case args[i]
      of "--help", "-h":
        return (0, @[IpcServeHelpText])
      of "--host":
        if i + 1 >= args.len:
          return (2, @["ipc serve: --host requires a value", IpcServeHelpText])
        host = args[i + 1]
        i += 2
      of "--port":
        if i + 1 >= args.len:
          return (2, @["ipc serve: --port requires a value", IpcServeHelpText])
        try:
          port = parseInt(args[i + 1])
        except ValueError:
          return (2, @["ipc serve: --port must be an integer", IpcServeHelpText])
        i += 2
      of "--max-requests":
        if i + 1 >= args.len:
          return (2, @["ipc serve: --max-requests requires a value", IpcServeHelpText])
        try:
          maxRequests = parseInt(args[i + 1])
        except ValueError:
          return (2, @["ipc serve: --max-requests must be an integer", IpcServeHelpText])
        i += 2
      else:
        return (2, @["ipc serve: unknown argument '" & args[i] & "'", IpcServeHelpText])

    try:
      let lc = newRuntimeLifecycle()
      let session = newIpcSession(lc)
      let handled = serveIpcTcp(session, host, port, maxRequests)
      return (0, @["ipc serve: handled " & $handled & " request(s)"])
    except ValueError as err:
      return (2, @[err.msg, IpcServeHelpText])
    except CatchableError as err:
      return (1, @["ipc serve: failed - " & err.msg])

  of "request":
    var requestId = nextCliRequestId()
    var requestMethod = ""
    var params = %*{}
    var subscribeEvents: seq[string] = @[]
    var useTcp = false
    var host = IpcDefaultHost
    var port = IpcDefaultPort
    var i = 1
    while i < args.len:
      case args[i]
      of "--help", "-h":
        return (0, @[IpcRequestHelpText])
      of "--id":
        if i + 1 >= args.len:
          return (2, @["ipc request: --id requires a value", IpcRequestHelpText])
        requestId = args[i + 1]
        i += 2
      of "--method":
        if i + 1 >= args.len:
          return (2, @["ipc request: --method requires a value", IpcRequestHelpText])
        requestMethod = args[i + 1]
        i += 2
      of "--params-json":
        if i + 1 >= args.len:
          return (2, @["ipc request: --params-json requires a value", IpcRequestHelpText])
        try:
          let parsed = parseJson(args[i + 1])
          if parsed.kind != JObject:
            return (2, @["ipc request: --params-json must decode to a JSON object", IpcRequestHelpText])
          params = parsed
        except JsonParsingError as err:
          return (2, @["ipc request: invalid JSON - " & err.msg, IpcRequestHelpText])
        i += 2
      of "--subscribe":
        if i + 1 >= args.len:
          return (2, @["ipc request: --subscribe requires an event key", IpcRequestHelpText])
        subscribeEvents.add(args[i + 1])
        i += 2
      of "--tcp":
        useTcp = true
        i += 1
      of "--host":
        if i + 1 >= args.len:
          return (2, @["ipc request: --host requires a value", IpcRequestHelpText])
        host = args[i + 1]
        i += 2
      of "--port":
        if i + 1 >= args.len:
          return (2, @["ipc request: --port requires a value", IpcRequestHelpText])
        try:
          port = parseInt(args[i + 1])
        except ValueError:
          return (2, @["ipc request: --port must be an integer", IpcRequestHelpText])
        i += 2
      else:
        return (2, @["ipc request: unknown argument '" & args[i] & "'", IpcRequestHelpText])

    if requestMethod.strip.len == 0:
      return (2, @["ipc request: --method is required", IpcRequestHelpText])

    let requestNode = %*{
      "id": requestId,
      "method": requestMethod,
      "params": params
    }
    let subscribeRequestId = requestId & "-subscribe"

    if useTcp:
      try:
        if subscribeEvents.len > 0:
          let subscribeFrames = sendIpcTcpRequest(host, port, %*{
            "id": subscribeRequestId,
            "method": "subscribe",
            "params": {
              "events": subscribeEvents
            }
          })
          if subscribeFrames.len > 0 and subscribeFrames[0].hasKey("error"):
            return (2, @[subscribeFrames[0].pretty])
        let frames = sendIpcTcpRequest(host, port, requestNode)
        if frames.len == 0:
          return (2, @["ipc request: no response from server", IpcRequestHelpText])
        var lines: seq[string] = @[]
        for frame in frames:
          lines.add(frame.pretty)
        let exitCode = if frames[0].hasKey("error"): 2 else: 0
        return (exitCode, lines)
      except ValueError as err:
        return (2, @[err.msg, IpcRequestHelpText])
      except CatchableError as err:
        return (1, @["ipc request: transport failure - " & err.msg])

    let lc = newRuntimeLifecycle()
    var session = newIpcSession(lc)
    if subscribeEvents.len > 0:
      discard handleRequest(session, %*{
        "id": subscribeRequestId,
        "method": "subscribe",
        "params": {
          "events": subscribeEvents
        }
      })
    let frames = dispatchRequest(session, requestNode)
    var lines: seq[string] = @[]
    for frame in frames:
      lines.add(frame.pretty)
    let exitCode = if frames[0].hasKey("error"): 2 else: 0
    return (exitCode, lines)

  else:
    return (2, @["ipc: expected 'request', 'endpoint', or 'serve'", IpcRequestHelpText, IpcEndpointHelpText, IpcServeHelpText])

# Flow: Execute human-readable notification formatter command.
proc runNotifyCommand(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len == 0 or args[0] == "--help" or args[0] == "-h":
    return (0, @[NotifyFormatHelpText])
  if args[0] != "format":
    return (2, @["notify: expected 'format'", NotifyFormatHelpText])

  var time = ""
  var level = ""
  var component = ""
  var message = ""
  var i = 1
  while i < args.len:
    case args[i]
    of "--help", "-h":
      return (0, @[NotifyFormatHelpText])
    of "--time":
      if i + 1 >= args.len:
        return (2, @["notify format: --time requires a value", NotifyFormatHelpText])
      time = args[i + 1]
      i += 2
    of "--level":
      if i + 1 >= args.len:
        return (2, @["notify format: --level requires a value", NotifyFormatHelpText])
      level = args[i + 1]
      i += 2
    of "--component":
      if i + 1 >= args.len:
        return (2, @["notify format: --component requires a value", NotifyFormatHelpText])
      component = args[i + 1]
      i += 2
    of "--message":
      if i + 1 >= args.len:
        return (2, @["notify format: --message requires a value", NotifyFormatHelpText])
      message = args[i + 1]
      i += 2
    else:
      return (2, @["notify format: unknown argument '" & args[i] & "'", NotifyFormatHelpText])

  try:
    let line = formatNotificationLine(time, level, component, message)
    return (0, @[line])
  except ValueError as err:
    return (2, @[err.msg, NotifyFormatHelpText])

# Flow: Map a parsed Git-style command to an IPC method and parameters.
proc commandToIpcRequest(cmd: ParsedCommand): tuple[`method`: string, params: JsonNode] =
  if cmd.verb == cvConsole:
    raise newException(ValueError, "console: use interactive mode")
  var params = %*{}
  case cmd.verb
  of cvStart:
    return ("runtime.start", params)
  of cvStop:
    return ("runtime.stop", params)
  of cvRestart:
    return ("runtime.restart", params)
  of cvAdd:
    case cmd.noun
    of nnWatch:
      if cmd.args.len == 0: raise newException(ValueError, "add watch: path required")
      params["path"] = %cmd.args[0]
      return ("runtime.addWatch", params)
    of nnThing:
      if cmd.args.len == 0: raise newException(ValueError, "add thing: bundle required")
      params["bundle"] = %cmd.args[0]
      return ("runtime.addThing", params)
    else: raise newException(ValueError, "add: expected noun watch or thing")
  of cvRemove:
    case cmd.noun
    of nnWatch:
      if cmd.args.len == 0: raise newException(ValueError, "remove watch: path required")
      params["path"] = %cmd.args[0]
      return ("runtime.removeWatch", params)
    of nnThing:
      if cmd.args.len == 0: raise newException(ValueError, "remove thing: id required")
      params["id"] = %cmd.args[0]
      return ("runtime.removeThing", params)
    else: raise newException(ValueError, "remove: expected noun watch or thing")
  of cvList:
    case cmd.noun
    of nnWatch: return ("runtime.listWatch", params)
    of nnThing: return ("runtime.listThings", params)
    else: raise newException(ValueError, "list: expected noun watch or thing")
  of cvMode:
    if cmd.args.len == 0: raise newException(ValueError, "mode: mode name required")
    params["mode"] = %cmd.args[0]
    return ("runtime.setMode", params)
  of cvInspect:
    if cmd.args.len == 0: raise newException(ValueError, "inspect: target required")
    params["target"] = %cmd.args[0]
    return ("runtime.inspect", params)
  of cvStep:
    var count = 1
    if cmd.flags.hasKey("--count"):
      count = parseInt(cmd.flags["--count"])
    params["count"] = %count
    return ("runtime.step", params)

# Flow: Handle interactive console session.
proc handleConsoleInteractive() =
  echo "Connecting to Cosmos Console..."
  
  # 1. Attach
  let identity = "operator"
  let attachReq = %*{
    "id": "cli-attach",
    "method": "runtime.attach",
    "params": %*{"identity": identity}
  }
  discard sendIpcTcpRequest(IpcDefaultHost, IpcDefaultPort, attachReq)
  
  # 2. Interactive Loop
  var running = true
  while running:
    # Render current state
    let renderReq = %*{
      "id": "cli-render",
      "method": "runtime.console_render",
      "params": %*{}
    }
    let renderFrames = sendIpcTcpRequest(IpcDefaultHost, IpcDefaultPort, renderReq)
    if renderFrames.len > 0:
      echo renderFrames[0]["result"].getStr("render")
    
    stdout.write("> ")
    stdout.flush()
    
    let input = readLine(stdin)
    if input == nil or input.strip == "exit":
      running = false
      continue
    
    if input.strip.len == 0:
      continue
      
    # Dispatch command
    let dispatchReq = %*{
      "id": "cli-dispatch",
      "method": "runtime.console_dispatch",
      "params": %*{"input": input}
    }
    let dispatchFrames = sendIpcTcpRequest(IpcDefaultHost, IpcDefaultPort, dispatchReq)
    if dispatchFrames.len > 0:
      let res = dispatchFrames[0]["result"]
      let lines = res["lines"].getArray()
      for line in lines:
        echo line.getStr()

# Flow: Run coordinator launch orchestration using Git-style CLI grammar.
proc runCoordinatorMain*(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  let parsed = parseArgs(args)
  case parsed
  of err(msg):
    return (2, @[msg])
  of ok(cmd):
    if cmd.verb == cvStart:
      # Check if daemon is already running
      try:
        let check = sendIpcTcpRequest(IpcDefaultHost, IpcDefaultPort, %*{
          "id": "ping",
          "method": "runtime.ping",
          "params": %*{}
        })
        if check.len > 0:
          return (0, @["cosmos: daemon already active"])
      except CatchableError:
        # Daemon not running, proceed to launch
        let exitCode = launchDaemon()
        return (exitCode, @["cosmos: daemon launched successfully"])

    if cmd.verb == cvConsole:
      handleConsoleInteractive()
      return (0, @["cosmos: console session closed"])

    # For all other commands, communicate with the daemon via IPC
    try:
      let (`method`, params) = commandToIpcRequest(cmd)
      let requestNode = %*{
        "id": nextCliRequestId(),
        "method": `method`,
        "params": params
      }
      let frames = sendIpcTcpRequest(IpcDefaultHost, IpcDefaultPort, requestNode)
      if frames.len == 0:
        return (1, @["cosmos: no response from daemon"])
      
      var lines: seq[string] = @[]
      for frame in frames:
        lines.add(frame.pretty)
      
      let exitCode = if frames[0].hasKey("error"): 2 else: 0
      return (exitCode, lines)
    except ValueError as err:
      return (2, @[err.msg])
    except CatchableError as err:
      return (1, @["cosmos: daemon communication failure - " & err.msg])

when isMainModule:
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