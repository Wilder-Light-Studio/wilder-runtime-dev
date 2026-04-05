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
import std/[strutils, algorithm, sets]

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

  IpcSession* = ref object
    state*: IpcServerState
    subscriptions*: HashSet[string]
    pushQueue*: seq[JsonNode]
    notificationLines*: seq[string]

# Flow: Build deterministic default IPC state used by CLI simulation and tests.
proc defaultIpcServerState*(): IpcServerState =
  IpcServerState(
    paused: false,
    tempoHz: 60,
    health: "ok",
    reconciliation: "clean",
    things: @["Runtime", "World", "Scheduler"],
    snapshotRevision: 0,
    tick: 0
  )

# Flow: Create a new in-memory IPC session with deterministic initial state.
proc newIpcSession*(state: IpcServerState = defaultIpcServerState()): IpcSession =
  result = IpcSession(
    state: state,
    subscriptions: initHashSet[string](),
    pushQueue: @[],
    notificationLines: @[]
  )

# Flow: Return true when host value is localhost-safe for this phase.
proc isLocalhostHost*(host: string): bool =
  host.toLowerAscii.strip in ["127.0.0.1", "localhost", "::1"]

# Flow: Build validated coordinator IPC localhost endpoint URI.
proc ipcEndpointUri*(host: string = "127.0.0.1", port: int = 7700): string =
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
    "tick": session.state.tick
  }

# Flow: Handle one request envelope and return deterministic response envelope.
proc handleRequest*(session: IpcSession, request: JsonNode): JsonNode =
  try:
    let parsed = validateRequest(request)
    let requestMethod = parsed.requestMethod.toLowerAscii
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
    of "subscribe", "runtime.subscribe":
      let names = parseEventNames(parsed.params)
      for name in names:
        session.subscriptions.incl(name)
      return successResponse(parsed.id, %*{
        "subscribed": names,
        "count": session.subscriptions.card
      })
    of "unsubscribe", "runtime.unsubscribe":
      let names = parseEventNames(parsed.params)
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