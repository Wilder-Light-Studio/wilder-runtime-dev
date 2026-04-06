# Wilder Cosmos 0.4.0
# Module name: Cosmos Main
# Module Path: src/cosmos_main.nim
# Summary: Thin CLI entrypoint for runtime startup coordinator launch contract and flags.
# Simile: Like a mission control checklist, it validates launch parameters and hands off to the runtime lifecycle.
# Memory note: keep orchestration thin; do not duplicate config or lifecycle logic.
# Flow: parse args -> resolve console mode -> validate -> load config -> emit startup report.

import std/[os, strutils, options, json, times]
import runtime/config
import runtime/capabilities
import runtime/concepts
import runtime/coordinator_ipc
import runtime/scanner
import runtime/startapp
import cosmos/thing/thing

type
  CoordinatorConsoleMode* = enum
    ccmDetach, ccmAuto, ccmAttach

  CoordinatorLaunchOptions* = object
    configPath*: string
    modeOverride*: Option[string]       ## development|debug|production
    encryptionMode*: Option[string]     ## clear|standard|private|complete
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
    "[--encryption-mode <clear|standard|private|complete>] " &
    "[--console <auto|attach|detach>] [--watch <path>] [--daemonize] " &
    "[--log-level <trace|debug|info|warn|error>] [--port <N>] [--help]"
  CoordinatorHelpText* =
    "Wilder Cosmos Runtime -- launch and coordinate a Cosmos instance\n" &
    "\n" &
    "Subcommands:\n" &
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
    "  cosmos --config <path> [options]\n" &
    "\n" &
    "Required:\n" &
    "  --config <path>                      Runtime config file path\n" &
    "\n" &
    "Optional:\n" &
    "  --mode <dev|debug|prod>              Override runtime mode\n" &
    "  --encryption-mode <mode>             Override encryption mode (clear|standard|private|complete)\n" &
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
    for issue in resolution.issues:
      if issueIsFatal(issue):
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
      let session = newIpcSession()
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

    var session = newIpcSession()
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

# Flow: Run coordinator launch orchestration and return exit code plus output lines.
proc runCoordinatorMain*(args: seq[string]): tuple[exitCode: int, lines: seq[string]] =
  if args.len > 0 and args[0] == "capabilities":
    return runCapabilitiesCommand(args[1 .. ^1])
  if args.len > 0 and args[0] == "ipc":
    return runIpcCommand(args[1 .. ^1])
  if args.len > 0 and args[0] == "notify":
    return runNotifyCommand(args[1 .. ^1])
  if args.len > 0 and args[0] == "scan":
    return runScanCommand(args[1 .. ^1])
  if args.len > 1 and args[0] == "capability" and args[1] == "conflicts":
    return runCapabilityConflictsCommand(args[2 .. ^1])
  if args.len > 1 and args[0] == "concept" and args[1] == "resolve":
    return runConceptResolveCommand(args[2 .. ^1])
  if args.len > 1 and args[0] == "concept" and args[1] == "show":
    return runConceptShowCommand(args[2 .. ^1])
  if args.len > 1 and args[0] == "concept" and args[1] == "validate":
    return runConceptValidateCommand(args[2 .. ^1])
  if args.len > 1 and args[0] == "concept" and args[1] == "export":
    return runConceptExportCommand(args[2 .. ^1])
  if args.len > 1 and args[0] == "concept" and args[1] == "registry":
    return runConceptRegistryCommand(args[2 .. ^1])
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
    if opts.encryptionMode.isSome:
      overrides.encryptionMode = opts.encryptionMode
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