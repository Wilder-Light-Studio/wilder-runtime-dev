# Wilder Cosmos 0.4.0
# Module name: delegation
# Module Path: src/cosmos/runtime/delegation.nim
#
# Summary: Delegation engine for capability-based specialist routing through
#   Occurrence-based requests and asynchronous results.
# Simile: Like a dispatch desk that receives one request, selects one specialist,
#   and posts the result on a later frame.
# Memory note: matching is deterministic (narrowest capability, then lexical ID);
#   results are always asynchronous at least two frames later.
# Flow: emit delegation occurrence -> select specialist -> queue pending result ->
#   process frame and emit delegation result occurrences.

import json
import std/[algorithm, options, sets]
import ../thing/thing

type
  DelegationOccurrence* = object
    id*: string
    requesterThingId*: string
    targetCapability*: string
    payload*: JsonNode
    epoch*: int64

  DelegationResult* = object
    delegationId*: string
    source*: string
    success*: bool
    payload*: JsonNode
    errorMessage*: string
    epoch*: int64

  SpecialistDescriptor* = object
    thingId*: string
    provides*: seq[string]
    requires*: seq[string]
    how*: string

  PendingKind = enum
    pkMatched
    pkNoMatch

  PendingDelegation = object
    occurrence: DelegationOccurrence
    specialistId: string
    emitAtEpoch: int64
    kind: PendingKind

  DelegationEngine* = ref object
    epoch*: int64
    pending*: seq[PendingDelegation]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateSpecialistDescriptor*(s: SpecialistDescriptor): bool =
  if s.thingId.len == 0:
    raise newException(ValueError,
      "specialist descriptor: thingId cannot be empty")
  if s.how.len == 0:
    raise newException(ValueError,
      "specialist descriptor: HOW cannot be empty")
  if s.provides.len == 0:
    raise newException(ValueError,
      "specialist descriptor: PROVIDES cannot be empty")
  if s.requires.len == 0:
    raise newException(ValueError,
      "specialist descriptor: REQUIRES cannot be empty")
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc makeDelegationId(requesterThingId, targetCapability: string,
    epoch: int64): string =
  "deleg_" & requesterThingId & "_" & targetCapability & "_" & $epoch

# Flow: Create delegation request occurrence from Thing.
proc emitDelegationOccurrence*(requesterThingId,
    targetCapability: string,
    payload: JsonNode,
    epoch: int64): DelegationOccurrence =
  if requesterThingId.len == 0:
    raise newException(ValueError,
      "delegation occurrence: requesterThingId cannot be empty")
  if targetCapability.len == 0:
    raise newException(ValueError,
      "delegation occurrence: targetCapability cannot be empty")

  result = DelegationOccurrence(
    id: makeDelegationId(requesterThingId, targetCapability, epoch),
    requesterThingId: requesterThingId,
    targetCapability: targetCapability,
    payload: payload,
    epoch: epoch
  )

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc requirementsSatisfied(reqs: seq[string], available: HashSet[string]): bool =
  for r in reqs:
    if r notin available:
      return false
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc matchingProvidesCount(s: SpecialistDescriptor, target: string): int =
  var n = 0
  for p in s.provides:
    if p == target:
      n = n + 1
  n

# Flow: Deterministically choose specialist by capability and prerequisites.
proc matchSpecialist*(targetCapability: string,
    specialists: seq[SpecialistDescriptor],
    availableCapabilities: HashSet[string]): Option[SpecialistDescriptor] =
  var candidates: seq[SpecialistDescriptor] = @[]
  for s in specialists:
    discard validateSpecialistDescriptor(s)
    if targetCapability notin s.provides:
      continue
    if not requirementsSatisfied(s.requires, availableCapabilities):
      continue
    candidates.add(s)

  if candidates.len == 0:
    return none(SpecialistDescriptor)

  candidates.sort(proc(a, b: SpecialistDescriptor): int =
    let byNarrow = system.cmp(matchingProvidesCount(a, targetCapability),
      matchingProvidesCount(b, targetCapability))
    if byNarrow != 0:
      return byNarrow
    system.cmp(a.thingId, b.thingId)
  )

  some(candidates[0])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc initDelegationEngine*(): DelegationEngine =
  new(result)
  result.epoch = 0
  result.pending = @[]

# Flow: Queue delegation result for asynchronous delivery (>= 2 frames).
proc queueDelegation*(engine: DelegationEngine,
    occurrence: DelegationOccurrence,
    specialists: seq[SpecialistDescriptor],
    availableCapabilities: HashSet[string]) =
  let matched = matchSpecialist(occurrence.targetCapability,
    specialists, availableCapabilities)
  if matched.isSome:
    engine.pending.add(PendingDelegation(
      occurrence: occurrence,
      specialistId: matched.get.thingId,
      emitAtEpoch: occurrence.epoch + 2,
      kind: pkMatched
    ))
  else:
    engine.pending.add(PendingDelegation(
      occurrence: occurrence,
      specialistId: "runtime",
      emitAtEpoch: occurrence.epoch + 2,
      kind: pkNoMatch
    ))

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc successResult(p: PendingDelegation, epoch: int64): DelegationResult =
  DelegationResult(
    delegationId: p.occurrence.id,
    source: p.specialistId,
    success: true,
    payload: %*{
      "delegated": true,
      "capability": p.occurrence.targetCapability
    },
    errorMessage: "",
    epoch: epoch
  )

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc noMatchResult(p: PendingDelegation, epoch: int64): DelegationResult =
  DelegationResult(
    delegationId: p.occurrence.id,
    source: "runtime",
    success: false,
    payload: %*{},
    errorMessage: "delegation: no matching specialist",
    epoch: epoch
  )

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc failureResult(p: PendingDelegation,
    epoch: int64,
    msg: string): DelegationResult =
  DelegationResult(
    delegationId: p.occurrence.id,
    source: p.specialistId,
    success: false,
    payload: %*{},
    errorMessage: msg,
    epoch: epoch
  )

# Flow: Process one frame and deliver due delegation results.
proc processDelegationFrame*(engine: DelegationEngine,
    frameEpoch: int64,
    failingSpecialists: HashSet[string] = initHashSet[string]()): seq[DelegationResult] =
  engine.epoch = frameEpoch
  var keep: seq[PendingDelegation] = @[]
  for p in engine.pending:
    if frameEpoch < p.emitAtEpoch:
      keep.add(p)
      continue

    case p.kind
    of pkNoMatch:
      result.add(noMatchResult(p, frameEpoch))
    of pkMatched:
      if p.specialistId in failingSpecialists:
        result.add(failureResult(p, frameEpoch,
          "delegation: specialist execution failed"))
      else:
        result.add(successResult(p, frameEpoch))
  engine.pending = keep

# Flow: Convert delegation result to Occurrence delivery message.
proc delegationResultToOccurrence*(r: DelegationResult): Occurrence =
  let payload = %*{
    "delegationId": r.delegationId,
    "source": r.source,
    "success": r.success,
    "payload": r.payload,
    "errorMessage": r.errorMessage
  }
  createOccurrence(
    id = "deleg_result_" & r.delegationId & "_" & $r.epoch,
    source = r.source,
    epoch = r.epoch,
    payload = payload,
    radius = 1
  )

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
