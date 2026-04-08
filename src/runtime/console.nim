# Wilder Cosmos 0.4.0
# Module name: console
# Module Path: src/runtime/console.nim
#
# Summary: Three-layer console with 20 commands and attach/detach protocol.
# Simile: Like a ship's instrument panel — three layers of readout (status,
#   scope, prompt) with full operator command dispatch.
# Memory note: unattached commands fail early; all output is machine-parseable
#   where practical; watch mode captures full-screen state.
# Flow: attach session -> render layers -> dispatch command -> return output.
## console.nim
## Console subsystem — three-layer rendering, 20 commands, attach/detach
## protocol, and precondition enforcement.

## Example:
##   import runtime/console
##   let cs = newConsoleSession()
##   cs.attach("operator", @["read", "write"])
##   echo cs.dispatch("ls")

import json
import std/[strutils, tables]
import ontology

# ── Types ─────────────────────────────────────────────────────────────────────

type
  ConsolePerm* = enum
    ## Permissions an attached session may hold.
    cpRead    ## May read state, run introspection commands.
    cpWrite   ## May set values, call execution commands.
    cpAdmin   ## May attach/detach instances.

  ConsoleCapability* = enum
    ## Optional capabilities the client supports.
    ccAnsi      ## Client renders ANSI colour/cursor codes.
    ccFullScreen ## Client supports watch full-screen mode.
    ccMouse     ## Client has pointer input (unused today but reserved).

  AttachFlags* = object
    ## State set at attach time and cleared at detach time.
    identity*: string
    permissions*: set[ConsolePerm]
    capabilities*: set[ConsoleCapability]
    attached*: bool

  WatchState* = object
    ## Captured state for watch full-screen mode.
    active*: bool
    targetPath*: string
    snapshotLines*: seq[string]

  RuntimeIntrospectionState* = object
    ## Global read-only runtime state exposed by introspection commands.
    frame*: int64
    blip*: string
    morphos*: string
    uptime*: int64
    schedulerMode*: string

  ConsoleSession* = ref object
    ## Live console session handle.  One per connected operator.
    attach*: AttachFlags
    currentPath*: seq[string]   ## Namespace path segments (cd/pwd).
    statusLine*: string         ## Status bar content (refreshed each render).
    scopeLine*: string          ## Scope line content.
    promptText*: string         ## Current prompt text.
    watchState*: WatchState
    runtimeState*: RuntimeIntrospectionState
    instanceRegistry*: Table[string, string] ## instanceId -> identity

  ConsoleOutput* = object
    ## Result of executing a console command.
    ok*: bool
    lines*: seq[string]

# ── Constructor ───────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc newConsoleSession*(): ConsoleSession =
  ## Create a fresh, unattached console session.
  ## Simile: An empty cockpit — instruments ready but no pilot yet logged in.
  result = ConsoleSession(
    attach: AttachFlags(attached: false),
    currentPath: @[],
    statusLine: "",
    scopeLine: "",
    promptText: "> ",
    watchState: WatchState(active: false),
    runtimeState: RuntimeIntrospectionState(
      frame: 0,
      blip: "steady",
      morphos: "stable",
      uptime: 0,
      schedulerMode: "idle"
    ),
    instanceRegistry: initTable[string, string]()
  )

# ── Helpers ───────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc ok(lines: seq[string]): ConsoleOutput =
  ConsoleOutput(ok: true, lines: lines)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc ok(line: string): ConsoleOutput =
  ConsoleOutput(ok: true, lines: @[line])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc err(msg: string): ConsoleOutput =
  ConsoleOutput(ok: false, lines: @["error: " & msg])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc requireAttached(cs: ConsoleSession): bool =
  ## Returns true if attached; callers should return early if false.
  cs.attach.attached

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc requirePerm(cs: ConsoleSession, p: ConsolePerm): bool =
  p in cs.attach.permissions

# ── Three-layer rendering ─────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc renderStatusBar*(cs: ConsoleSession): string =
  ## Layer 1: Status bar - runtime version, mode, and attach status.
  ## Simile: The top instrument row — always visible, always current.
  let who = if cs.attach.attached: "[" & cs.attach.identity & "]" else: "[unattached]"
  result = "Wilder Cosmos Runtime | " & who

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc renderScopeLine*(cs: ConsoleSession): string =
  ## Layer 2: Scope line — current namespace path.
  renderScope(cs.currentPath)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc renderPromptLine*(cs: ConsoleSession): string =
  ## Layer 3: Prompt line — ready to accept input.
  result = cs.renderScopeLine() & " " & cs.promptText

proc introspectionValue(cs: ConsoleSession, target: string): string =
  let key = target.toLowerAscii()
  case key
  of "frame": $cs.runtimeState.frame
  of "blip": cs.runtimeState.blip
  of "morphos": cs.runtimeState.morphos
  of "uptime": $cs.runtimeState.uptime
  of "scheduler.mode": cs.runtimeState.schedulerMode
  else: ""

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc renderAll*(cs: ConsoleSession): string =
  ## Render all three layers as a multi-line string.
  result = cs.renderStatusBar() & "\n" &
           cs.renderScopeLine() & "\n" &
           cs.renderPromptLine()

# ── Attach / Detach Protocol ──────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdAttach*(cs: ConsoleSession,
               identity: string,
               perms: set[ConsolePerm] = {cpRead},
               caps: set[ConsoleCapability] = {}): ConsoleOutput =
  ## Attach an operator session.
  ## Clears layout state and permission cache from any previous attachment.
  if identity.strip.len == 0:
    return err("attach: identity must not be empty")
  cs.attach = AttachFlags(
    identity: identity,
    permissions: perms,
    capabilities: caps,
    attached: true
  )
  cs.currentPath = @[]
  cs.watchState = WatchState(active: false)
  ok("attached: " & identity)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdDetach*(cs: ConsoleSession): ConsoleOutput =
  ## Detach the current operator session.  Clears all session state.
  if not cs.requireAttached:
    return err("detach: no session attached")
  let who = cs.attach.identity
  cs.attach = AttachFlags(attached: false)
  cs.currentPath = @[]
  cs.promptText = "> "
  cs.watchState = WatchState(active: false)
  ok("detached: " & who)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdInstances*(cs: ConsoleSession): ConsoleOutput =
  ## List registered instances.
  if not cs.requireAttached:
    return err("instances: requires attached session")
  if cs.instanceRegistry.len == 0:
    return ok("(no instances registered)")
  var lines: seq[string]
  for id, who in cs.instanceRegistry.pairs:
    lines.add(id & "  " & who)
  ok(lines)

# ── Navigation Commands ───────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdLs*(cs: ConsoleSession, entries: seq[string] = @[]): ConsoleOutput =
  ## List things at current path.
  ## Output rules: flat list; Things prefixed with @, dirs with /, files plain.
  if not cs.requireAttached:
    return err("ls: requires attached session")
  if entries.len == 0:
    return ok("(empty)")
  var lines: seq[string]
  for e in entries:
    # Formatting: Things start with @, dirs end with /, others plain.
    if e.startsWith("@"):
      lines.add(e)
    elif e.endsWith("/"):
      lines.add(e)
    else:
      lines.add(e)
  ok(lines)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdCd*(cs: ConsoleSession, path: string): ConsoleOutput =
  ## Change scope to path.  ".." moves up one level.
  if not cs.requireAttached:
    return err("cd: requires attached session")
  try:
    cs.currentPath = resolveScope(path, cs.currentPath)
  except ValueError as e:
    return err("cd: " & e.msg)
  ok(cs.renderScopeLine())

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdPwd*(cs: ConsoleSession): ConsoleOutput =
  ## Print current scope path.
  if not cs.requireAttached:
    return err("pwd: requires attached session")
  ok(cs.renderScopeLine())

# ── Introspection Commands ────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdInfo*(cs: ConsoleSession, target: string): ConsoleOutput =
  ## Show identity and metadata for a Thing or namespace.
  if not cs.requireAttached:
    return err("info: requires attached session")
  let value = cs.introspectionValue(target)
  if value.len > 0:
    return ok(target & "=" & value)
  ok("info: " & target & " (stub — expand with ontology lookup)")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdPeek*(cs: ConsoleSession, target: string): ConsoleOutput =
  ## Show the current field values of a Thing's status.
  if not cs.requireAttached:
    return err("peek: requires attached session")
  let value = cs.introspectionValue(target)
  if value.len > 0:
    return ok(target & "=" & value)
  ok("peek: " & target & " (stub — expand with status lookup)")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdWatch*(cs: ConsoleSession, target: string): ConsoleOutput =
  ## Enter full-screen watch mode for a Thing.  Ctrl+C resumes normal mode.
  ## In non-interactive contexts this records watch state for inspection.
  if not cs.requireAttached:
    return err("watch: requires attached session")
  cs.watchState = WatchState(
    active: true,
    targetPath: target,
    snapshotLines: @["watching: " & target]
  )
  ok("watch: active on " & target & " (Ctrl+C to resume)")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc exitWatch*(cs: ConsoleSession): ConsoleOutput =
  ## Exit full-screen watch mode and resume normal prompt.
  cs.watchState = WatchState(active: false)
  ok("watch: exited")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdState*(cs: ConsoleSession, target: string): ConsoleOutput =
  ## Print raw state JSON for a Thing.
  if not cs.requireAttached:
    return err("state: requires attached session")
  let key = target.toLowerAscii()
  if key in ["frame", "blip", "morphos", "uptime", "scheduler.mode"]:
    return ok($(%*{
      "key": key,
      "value": cs.introspectionValue(key)
    }))
  ok("state: " & target & " (stub — expand with state serializer)")

# ── Delegation Introspection ──────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdSpecialists*(cs: ConsoleSession): ConsoleOutput =
  ## List registered specialist descriptors.
  if not cs.requireAttached:
    return err("specialists: requires attached session")
  ok("specialists: (stub — wire up delegation engine)")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdDelegations*(cs: ConsoleSession): ConsoleOutput =
  ## List pending and completed delegation occurrences.
  if not cs.requireAttached:
    return err("delegations: requires attached session")
  ok("delegations: (stub — wire up delegation engine)")

# ── World Ledger Introspection ────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdWorld*(cs: ConsoleSession): ConsoleOutput =
  ## Print world ledger summary.
  if not cs.requireAttached:
    return err("world: requires attached session")
  ok("world: (stub — wire up world ledger)")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdClaims*(cs: ConsoleSession): ConsoleOutput =
  ## List current claims from the world ledger.
  if not cs.requireAttached:
    return err("claims: requires attached session")
  ok("claims: (stub — wire up world ledger)")

# ── Execution Commands ────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdRun*(cs: ConsoleSession, target: string, args: seq[string] = @[]): ConsoleOutput =
  ## Invoke a delegation or frame on target.
  if not cs.requireAttached:
    return err("run: requires attached session")
  if not cs.requirePerm(cpWrite):
    return err("run: requires write permission")
  ok("run: " & target & (if args.len > 0: " " & args.join(" ") else: "") &
     " (stub — wire up execution)")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdSet*(cs: ConsoleSession, target: string, field: string, value: string): ConsoleOutput =
  ## Set a status field value on target.
  if not cs.requireAttached:
    return err("set: requires attached session")
  if not cs.requirePerm(cpWrite):
    return err("set: requires write permission")
  ok("set: " & target & "." & field & " = " & value & " (stub)")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdCall*(cs: ConsoleSession, target: string, msg: string): ConsoleOutput =
  ## Send a named message to target.
  if not cs.requireAttached:
    return err("call: requires attached session")
  if not cs.requirePerm(cpWrite):
    return err("call: requires write permission")
  ok("call: " & target & " <- " & msg & " (stub)")

# ── Ergonomics ────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdHelp*(cs: ConsoleSession): ConsoleOutput =
  ## Print all available commands and their brief descriptions.
  ok(@[
    "Navigation:     ls [path]  cd <path>  pwd",
    "Introspection:  info <t>   peek <t>   watch <t>   state <t>",
    "Delegation:     specialists  delegations",
    "World:          world  claims",
    "Execution:      run <t> [args]  set <t> <f> <v>  call <t> <msg>",
    "Instances:      attach <id>  detach  instances",
    "Ergonomics:     help  clear  exit"
  ])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdClear*(cs: ConsoleSession): ConsoleOutput =
  ## Clear console output buffer (client-side in interactive use).
  ok("") # Signal a clear to the client; actual clearing is client-side.

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc cmdExit*(cs: ConsoleSession): ConsoleOutput =
  ## Detach and signal the client to close.
  discard cs.cmdDetach()
  ok("goodbye")

# ── Command Dispatcher ────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc dispatch*(cs: ConsoleSession, input: string): ConsoleOutput =
  ## Parse and dispatch a single command line.
  ## Simile: the bridge operator calling out orders — each word has one meaning.
  let parts = input.strip.splitWhitespace()
  if parts.len == 0:
    return ok("")
  let cmd = parts[0].toLowerAscii
  let args = if parts.len > 1: parts[1 ..^ 1] else: @[]

  case cmd
  # Navigation
  of "ls":
    cs.cmdLs(args)
  of "cd":
    if args.len == 0: err("cd: path required")
    else: cs.cmdCd(args[0])
  of "pwd":
    cs.cmdPwd()
  # Introspection
  of "info":
    if args.len == 0: err("info: target required")
    else: cs.cmdInfo(args[0])
  of "peek":
    if args.len == 0: err("peek: target required")
    else: cs.cmdPeek(args[0])
  of "watch":
    if args.len == 0: err("watch: target required")
    else: cs.cmdWatch(args[0])
  of "state":
    if args.len == 0: err("state: target required")
    else: cs.cmdState(args[0])
  # Delegation
  of "specialists":
    cs.cmdSpecialists()
  of "delegations":
    cs.cmdDelegations()
  # World
  of "world":
    cs.cmdWorld()
  of "claims":
    cs.cmdClaims()
  # Execution
  of "run":
    if args.len == 0: err("run: target required")
    else: cs.cmdRun(args[0], if args.len > 1: args[1 ..^ 1] else: @[])
  of "set":
    if args.len < 3: err("set: usage: set <target> <field> <value>")
    else: cs.cmdSet(args[0], args[1], args[2 ..^ 1].join(" "))
  of "call":
    if args.len < 2: err("call: usage: call <target> <message>")
    else: cs.cmdCall(args[0], args[1 ..^ 1].join(" "))
  # Instance management
  of "attach":
    if args.len == 0: err("attach: identity required")
    else: cs.cmdAttach(args[0])
  of "detach":
    cs.cmdDetach()
  of "instances":
    cs.cmdInstances()
  # Ergonomics
  of "help":
    cs.cmdHelp()
  of "clear":
    cs.cmdClear()
  of "exit":
    cs.cmdExit()
  else:
    err("unknown command: " & cmd & " (type 'help' for a list)")

# ── Legacy stub ───────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc printRuntimeStatus*() =
  ## Print a brief runtime status summary to stdout.
  ## Kept for backward compatibility with existing call-sites.
  let cs = newConsoleSession()
  discard cs.cmdAttach("system", {cpRead})
  echo cs.renderStatusBar()

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
