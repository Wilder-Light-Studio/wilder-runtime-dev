# Wilder Cosmos 0.4.0
# Module name: scheduler
# Module Path: src/cosmos/runtime/scheduler.nim
#
# Summary: Deterministic frame scheduler with bounded execution, cooperative
#   yielding, replay support, and failure isolation.
# Simile: Like an air-traffic controller that advances one frame at a time,
#   enforces per-Thing limits, and isolates failing lanes.
# Memory note: ordering is deterministic by thingId/moduleId; repeated failures
#   trigger suspension after a fixed threshold.
# Flow: advance epoch -> sort work -> process each item with bounds ->
#   isolate failures -> emit results -> return replayable frame summary.

import json
import std/[algorithm, sets, strutils, tables]
import ../thing/thing
import ../tempo/tempo

type
  SchedulerError* = object of CatchableError

  FrameWorkItem* = object
    thingId*: string
    moduleId*: string
    tempo*: TempoKind
    incoming*: seq[Occurrence]
    workUnits*: int
    emitPayloads*: seq[JsonNode]
    forceFailure*: bool

  ThingFailure* = object
    thingId*: string
    moduleId*: string
    message*: string
    attempts*: int
    suspended*: bool

  FrameResult* = object
    epoch*: int64
    processedThings*: seq[string]
    yieldedThings*: seq[string]
    suspendedThings*: seq[string]
    failures*: seq[ThingFailure]
    emitted*: seq[Occurrence]
    digest*: string

  SchedulerState* = ref object
    epoch*: int64
    perThingBudget*: int
    suspensionThreshold*: int
    failureCounts*: Table[string, int]
    suspended*: HashSet[string]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc makeDigest(value: string): string =
  var acc: uint64 = 1469598103934665603'u64
  for c in value:
    acc = acc xor uint64(ord(c))
    acc = acc * 1099511628211'u64
  toHex(acc)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc itemKey(item: FrameWorkItem): string =
  item.thingId & "|" & item.moduleId

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc ensureValidItem(item: FrameWorkItem) =
  if item.thingId.len == 0:
    raise newException(SchedulerError,
      "scheduler: thingId cannot be empty")
  if item.moduleId.len == 0:
    raise newException(SchedulerError,
      "scheduler: moduleId cannot be empty")
  if item.workUnits < 0:
    raise newException(SchedulerError,
      "scheduler: workUnits cannot be negative")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc initSchedulerState*(perThingBudget: int = 4,
    suspensionThreshold: int = 2): SchedulerState =
  if perThingBudget <= 0:
    raise newException(SchedulerError,
      "scheduler: perThingBudget must be positive")
  if suspensionThreshold <= 0:
    raise newException(SchedulerError,
      "scheduler: suspensionThreshold must be positive")

  new(result)
  result.epoch = 0
  result.perThingBudget = perThingBudget
  result.suspensionThreshold = suspensionThreshold
  result.failureCounts = initTable[string, int]()
  result.suspended = initHashSet[string]()

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc sortWork(items: seq[FrameWorkItem]): seq[FrameWorkItem] =
  result = items
  result.sort(proc(a, b: FrameWorkItem): int =
    system.cmp(itemKey(a), itemKey(b))
  )

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc pushUnique(dst: var seq[string], value: string) =
  if value notin dst:
    dst.add(value)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc makeOccurrence(thingId: string, epoch: int64,
    idx: int, payload: JsonNode): Occurrence =
  createOccurrence(
    id = "sched_" & thingId & "_" & $epoch & "_" & $idx,
    source = thingId,
    epoch = epoch,
    payload = payload,
    radius = 1
  )

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc computeResultDigest(frameResult: FrameResult): string =
  var raw = $frameResult.epoch & "|"
  for id in frameResult.processedThings:
    raw.add(id & ",")
  raw.add("|")
  for id in frameResult.yieldedThings:
    raw.add(id & ",")
  raw.add("|")
  for id in frameResult.suspendedThings:
    raw.add(id & ",")
  raw.add("|")
  for o in frameResult.emitted:
    raw.add(o.id & ";")
  makeDigest(raw)

# Flow: Execute one deterministic frame with bounded work and isolated errors.
proc executeFrame*(state: SchedulerState,
    requested: seq[FrameWorkItem]): FrameResult =
  state.epoch = state.epoch + 1
  result.epoch = state.epoch

  let ordered = sortWork(requested)
  for item in ordered:
    ensureValidItem(item)

    let key = itemKey(item)
    if item.thingId in state.suspended:
      result.suspendedThings.pushUnique(item.thingId)
      continue

    result.processedThings.add(key)

    if item.forceFailure:
      let nextAttempts = state.failureCounts.getOrDefault(item.thingId, 0) + 1
      state.failureCounts[item.thingId] = nextAttempts
      var suspendedNow = false
      if nextAttempts >= state.suspensionThreshold:
        state.suspended.incl(item.thingId)
        result.suspendedThings.pushUnique(item.thingId)
        suspendedNow = true
      result.failures.add(ThingFailure(
        thingId: item.thingId,
        moduleId: item.moduleId,
        message: "scheduler: isolated failure",
        attempts: nextAttempts,
        suspended: suspendedNow
      ))
      continue

    # Successful run clears accumulated failures for that Thing.
    if item.thingId in state.failureCounts:
      state.failureCounts.del(item.thingId)

    if item.workUnits > state.perThingBudget:
      result.yieldedThings.pushUnique(item.thingId)
      continue

    for i, payload in item.emitPayloads:
      result.emitted.add(makeOccurrence(item.thingId, state.epoch, i, payload))

  result.digest = computeResultDigest(result)

# Flow: Replay one frame from same input to confirm deterministic digest.
proc replayFrame*(perThingBudget: int,
    suspensionThreshold: int,
    requested: seq[FrameWorkItem]): FrameResult =
  let state = initSchedulerState(perThingBudget, suspensionThreshold)
  executeFrame(state, requested)

# Flow: Determine if scheduler state currently has a suspended Thing.
proc isThingSuspended*(state: SchedulerState, thingId: string): bool =
  thingId in state.suspended

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
