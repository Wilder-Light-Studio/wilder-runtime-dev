# Wilder Cosmos 0.4.0
# Module name: coordinator_ipc
# Module Path: src/runtime/coordinator_ipc.nim
#
# coordinator_ipc.nim
# Deterministic coordinator IPC request/response/event handling.
# Summary: Validate IPC requests, mutate bounded session state, and emit structured responses/events.
# Simile: Like a control bridge radio, it accepts only known commands and speaks a stable protocol.
# Memory note: validate before dispatch; return structured errors; keep output stable for equal input.
# Flow: validate request -> dispatch method -> build response -> queue subscribed events.

import json
import std/[strutils, algorithm, sets, net, os, tables]
import runtime/core
import runtime/bundle_loader
import runtime/console

const
  IpcVersion* = "ipc-v1"

type
  IpcServerState* = object
    paused*: bool
    tempoHz*: int
    health*: string
    reconciliation*: string
    things*: seq[string]
    snapshotRevision*: int
    tick*: int
    watchedPaths*: seq[string]
    consoleSessions*: Table[string, ConsoleSession]

  IpcSession* = ref object
    state*: IpcServerState
    subscriptions*: HashSet[string]
    pushQueue*: seq[JsonNode]
    notificationLines*: seq[string]
    lifecycle*: RuntimeLifecycle

const
  IpcDefaultHost* = "127.0.0.1"
  IpcDefaultPort* = 7700

# Flow: Build deterministic default IPC state used by CLI simulation and tests.
proc defaultIpcServerState*(): IpcServerState =
  IpcServerState(
    paused: false,
    tempoHz: 60,
    health: "ok",
    reconciliation: "clean",
    things: @["Runtime", "World", "Scheduler"],
    snapshotRevision: 0,
    tick: 0,
    watchedPaths: @[],
    consoleSessions: initTable[string, ConsoleSession]()
  )

# Flow: Create a new in-memory IPC session with deterministic initial state.
proc newIpcSession*(lc: RuntimeLifecycle, state: IpcServerState = defaultIpcServerState()): IpcSession =
  result = IpcSession(
    state: state,
    subscriptions: initHashSet[string](),
    pushQueue: @[],
    notificationLines: @[],
    lifecycle: lc
  )

# Flow: Return true when host value is localhost-safe for this phase.
proc isLocalhostHost*(host: string): bool =
  host.toLowerAscii.strip in ["127.0.0.1", "localhost", "::1"]

# Flow: Build validated coordinator IPC localhost endpoint URI.
proc ipcEndpointUri*(host: string = IpcDefaultHost, port: int = IpcDefaultPort): string =
  let normalizedHost = host.strip
  if normalizedHost.len == 0:
    raise newException(ValueError,
      "ipc: host must not be empty")
  if not isLocalhostHost(normalizedHost):
    raise newException(ValueError,
      "ipc: host must be localhost for Phase XC")
  if port < 1 or port > 65535:
    raise newException(ValueError,
      "ipc: port must be in range 1-65535")
  "tcp://127.0.0.1:" & $port

# Flow: Build one deterministic error object for IPC response payloads.
proc ipcError(code: string, message: string): JsonNode =
  %*{"code": code, "message": message}

# Flow: Build one deterministic success response envelope.
proc successResponse(id: string, resultNode: JsonNode): JsonNode =
  %*{
    "version": IpcVersion,
    "id": id,
    "result": resultNode
  }

# Flow: Build one deterministic error response envelope.
proc errorResponse(id: string, code: string, message: string): JsonNode =
  %*{
    "version": IpcVersion,
    "id": id,
    "error": ipcError(code, message)
  }

# Flow: Parse and validate request envelope shape before method dispatch.
proc validateRequest*(request: JsonNode): tuple[id: string, requestMethod: string, params: JsonNode] =
  if request.kind != JObject:
    raise newException(ValueError,
      "ipc: request must be a JSON object")
  if not request.hasKey("id") or request["id"].kind != JString or
     request["id"].getStr.strip.len == 0:
    raise newException(ValueError,
      "ipc: request.id must be a non-empty string")
  if not request.hasKey("method") or request["method"].kind != JString or
     request["method"].getStr.strip.len == 0:
    raise newException(ValueError,
      "ipc: request.method must be a non-empty string")

  var params = %*{}
  if request.hasKey("params"):
    if request["params"].kind != JObject:
      raise newException(ValueError,
        "ipc: request.params must be a JSON object")
    params = request["params"]

  result = (
    id: request["id"].getStr.strip,
    requestMethod: request["method"].getStr.strip,
    params: params
  )

# Flow: Queue event when subscription set contains event key or wildcard.
proc queueEvent(session: IpcSession, eventName: string, payload: JsonNode) =
  let wildcard = session.subscriptions.contains("*")
  if session.subscriptions.contains(eventName) or wildcard:
    session.pushQueue.add(%*{
      "version": IpcVersion,
      "event": eventName,
      "payload": payload
    })

# Flow: Parse event list from params for subscription operations.
proc parseEventNames(params: JsonNode): seq[string] =
  if not params.hasKey("events") or params["events"].kind != JArray:
    raise newException(ValueError,
      "ipc: params.events must be an array")
  for item in params["events"].items:
    if item.kind != JString:
      raise newException(ValueError,
        "ipc: each events entry must be a string")
    let name = item.getStr.strip
    if name.len == 0:
      raise newException(ValueError,
        "ipc: events entries must not be empty")
    result.add(name)
  result.sort(system.cmp[string])
  var uniqueNames: seq[string] = @[]
  for name in result:
    if uniqueNames.len == 0 or uniqueNames[^1] != name:
      uniqueNames.add(name)
  result = uniqueNames

# Flow: Emit deterministic snapshot of current IPC state for inspect command.
proc inspectPayload(session: IpcSession): JsonNode =
  var orderedThings = session.state.things
  orderedThings.sort(system.cmp[string])
  %*{
    "paused": session.state.paused,
    "tempoHz": session.state.tempoHz,
    "health": session.state.health,
    "things": orderedThings,
    "reconciliation": session.state.reconciliation,
    "snapshotRevision": session.state.snapshotRevision,
    "tick": session.state.tick,
    "watchedPaths": session.state.watchedPaths
  }

# Flow: Drain and clear queued push events in stable FIFO order.
proc drainPushEvents*(session: IpcSession): seq[JsonNode]

# Flow: Handle one request envelope and return deterministic response envelope.
proc handleRequest*(session: IpcSession, request: JsonNode): JsonNode =
  try:
    let parsed = validateRequest(request)
    let requestMethod = parsed.requestMethod.toLowerAscii
    let params = parsed.params
    case requestMethod
    of "pause", "runtime.pause":
      session.state.paused = true
      session.queueEvent("runtime.paused", %*{"paused": true})
      return successResponse(parsed.id, %*{"paused": true})
    of "resume", "runtime.resume":
      session.state.paused = false
      session.queueEvent("runtime.resumed", %*{"paused": false})
      return successResponse(parsed.id, %*{"paused": false})
    of "step", "runtime.step":
      session.state.tick = session.state.tick + 1
      session.queueEvent("runtime.step", %*{"tick": session.state.tick})
      return successResponse(parsed.id, %*{"tick": session.state.tick})
    of "snapshot", "runtime.snapshot":
      session.state.snapshotRevision = session.state.snapshotRevision + 1
      let snapshotId = "snapshot-" & $session.state.snapshotRevision
      session.queueEvent("runtime.snapshot", %*{
        "snapshotId": snapshotId,
        "revision": session.state.snapshotRevision
      })
      return successResponse(parsed.id, %*{
        "snapshotId": snapshotId,
        "revision": session.state.snapshotRevision
      })
    of "inspect", "runtime.inspect":
      return successResponse(parsed.id, session.inspectPayload())
    of "addWatch", "runtime.addWatch":
      let path = params.getStr("path")
      session.state.watchedPaths.add(path)
      session.queueEvent("runtime.watchAdded", %*{"path": path})
      return successResponse(parsed.id, %*{"status": "added", "path": path})
    of "removeWatch", "runtime.removeWatch":
      let path = params.getStr("path")
      var newPaths: seq[string] = @[]
      for p in session.state.watchedPaths:
        if p != path: newPaths.add(p)
      session.state.watchedPaths = newPaths
      session.queueEvent("runtime.watchRemoved", %*{"path": path})
      return successResponse(parsed.id, %*{"status": "removed", "path": path})
    of "listWatch", "runtime.listWatch":
      return successResponse(parsed.id, %*{"paths": session.state.watchedPaths})
    of "addThing", "runtime.addThing":
      let bundlePath = params.getStr("bundle")
      let loadResult = loadCosmosBundle(bundlePath)
      
      if loadResult.loadStatus != tlsLoaded:
        return errorResponse(parsed.id, "load_failure", 
          "Hot-load failed: " & loadResult.errorMsg & 
          " at " & loadResult.location & 
          ". Expected a valid .cosmos bundle with manifest.json.")
      
      let thingId = loadResult.manifest.id
      session.state.things.add(thingId) 
      session.queueEvent("runtime.thingAdded", %*{"id": thingId, "version": loadResult.manifest.version})
      return successResponse(parsed.id, %*{"status": "installed", "id": thingId})
    of "removeThing", "runtime.removeThing":
      let id = params.getStr("id")
      var newThings: seq[string] = @[]
      for t in session.state.things:
        if t != id: newThings.add(t)
      session.state.things = newThings
      session.queueEvent("runtime.thingRemoved", %*{"id": id})
      return successResponse(parsed.id, %*{"status": "removed", "id": id})
    of "listThings", "runtime.listThings":
      return successResponse(parsed.id, %*{"things": session.state.things})
    of "setMode", "runtime.setMode":
      let mode = params.getStr("mode")
      session.queueEvent("runtime.modeChanged", %*{"mode": mode})
      return successResponse(parsed.id, %*{"status": "mode set", "mode": mode})
    of "attach", "runtime.attach":
      let identity = params.getStr("identity")
      let cs = newConsoleSession()
      discard cs.cmdAttach(identity)
      session.state.consoleSessions[parsed.id] = cs
      return successResponse(parsed.id, %*{"status": "attached", "identity": identity})
    of "console_dispatch", "runtime.console_dispatch":
      let input = params.getStr("input")
      let cs = session.state.consoleSessions.getOrDefault(parsed.id, newConsoleSession())
      let output = cs.dispatch(input)
      return successResponse(parsed.id, %*{"ok": output.ok, "lines": output.lines})
    of "console_render", "runtime.console_render":
      let cs = session.state.consoleSessions.getOrDefault(parsed.id, newConsoleSession())
      return successResponse(parsed.id, %*{"render": cs.renderAll()})
    of "subscribe", "runtime.subscribe":
      let names = parseEventNames(params)
      for name in names:
        session.subscriptions.incl(name)
      return successResponse(parsed.id, %*{
        "subscribed": names,
        "count": session.subscriptions.card
      })
    of "unsubscribe", "runtime.unsubscribe":
      let names = parseEventNames(params)
      for name in names:
        session.subscriptions.excl(name)
      return successResponse(parsed.id, %*{
        "unsubscribed": names,
        "count": session.subscriptions.card
      })
    else:
      return errorResponse(parsed.id, "method_not_found",
        "ipc: unsupported method '" & parsed.requestMethod & "'")
  except ValueError as err:
    return errorResponse("unknown", "invalid_request", err.msg)

# Flow: Dispatch one request into a response followed by queued push events.
proc dispatchRequest*(session: IpcSession, request: JsonNode): seq[JsonNode] =
  let response = handleRequest(session, request)
  result = @[response]
  for eventNode in drainPushEvents(session):
    result.add(eventNode)

# Flow: Parse one JSON request line and return JSON response/event lines.
proc dispatchRequestLine*(session: IpcSession, line: string): seq[string] =
  let payload = line.strip
  if payload.len == 0:
    return @[$errorResponse("unknown", "invalid_request", "ipc: request frame must not be empty")]

  try:
    let request = parseJson(payload)
    for node in dispatchRequest(session, request):
      result.add($node)
  except JsonParsingError as err:
    result = @[$errorResponse("unknown", "invalid_request", "ipc: invalid JSON - " & err.msg)]

# Flow: Serve localhost TCP JSON-lines requests with one session for deterministic state.
proc serveIpcTcp*(session: IpcSession,
                  host: string = IpcDefaultHost,
                  port: int = IpcDefaultPort,
                  maxRequests: int = 0): int =
  ## maxRequests == 0 means serve until process termination.
  ## SECURITY: ipcEndpointUri validates that host is localhost-only.  The socket
  ## bind below is also pinned to "127.0.0.1" — keep it that way; never replace
  ## with "" or "0.0.0.0" which would expose the IPC port to all interfaces.
  discard ipcEndpointUri(host, port)
  if maxRequests < 0:
    raise newException(ValueError,
      "ipc: maxRequests must be >= 0")

  var server = newSocket()
  try:
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr(Port(port), "127.0.0.1")
    server.listen()

    while maxRequests == 0 or result < maxRequests:
      var client: Socket
      server.accept(client)
      try:
        let requestLine = client.recvLine()
        for outputLine in dispatchRequestLine(session, requestLine):
          client.send(outputLine & "\n")
      finally:
        client.close()
      inc result
  finally:
    server.close()

# Flow: Send one request to localhost TCP JSON-lines endpoint and read all frames.
proc sendIpcTcpRequest*(host: string,
                        port: int,
                        request: JsonNode): seq[JsonNode] =
  discard ipcEndpointUri(host, port)
  var client = newSocket()
  try:
    client.connect("127.0.0.1", Port(port))
    client.send($request & "\n")
    while true:
      let line = client.recvLine()
      if line.len == 0:
        break
      let trimmed = line.strip
      if trimmed.len == 0:
        continue
      result.add(parseJson(trimmed))
  finally:
    client.close()

# Flow: Return queued push events and clear queue in one deterministic operation.
proc drainPushEvents*(session: IpcSession): seq[JsonNode] =
  result = session.pushQueue
  session.pushQueue = @[]

# Flow: Format one notification line for human-readable console streams.
proc formatNotificationLine*(time: string,
                             level: string,
                             component: string,
                             message: string): string =
  let t = time.strip
  let l = level.toUpperAscii.strip
  let c = component.strip
  let m = message.strip
  if t.len == 0:
    raise newException(ValueError,
      "notify: time must not be empty")
  if l.len == 0:
    raise newException(ValueError,
      "notify: level must not be empty")
  if c.len == 0:
    raise newException(ValueError,
      "notify: component must not be empty")
  if m.len == 0:
    raise newException(ValueError,
      "notify: message must not be empty")
  "[" & t & "] [" & l & "] [" & c & "] " & m

# Flow: Append one formatted notification line to session-side notification history.
proc appendNotification*(session: IpcSession,
                         time: string,
                         level: string,
                         component: string,
                         message: string): string =
  let line = formatNotificationLine(time, level, component, message)
  session.notificationLines.add(line)
  line

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.