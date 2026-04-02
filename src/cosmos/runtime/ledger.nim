# Wilder Cosmos 0.4.0
# Module name: ledger
# Module Path: src/cosmos/runtime/ledger.nim
#
# Summary: Append-only World Ledger and deterministic World Graph construction.
# Simile: Like an aircraft black box: every relationship and claim is appended,
#   never rewritten, then replayed into a navigable structure.
# Memory note: graph edges come only from explicit references; no implicit edges.
# Flow: append reference/claim -> validate ledger -> persist/load -> build graph.

import json
import std/[algorithm, tables, sequtils]
import ../thing/thing
import ../../runtime/persistence
import ../../runtime/validation

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

type
  LedgerReference* = object
    fromThing*: string
    toThing*: string
    relation*: string
    epoch*: int64

  LedgerClaim* = object
    thingId*: string
    claimKey*: string
    claimValue*: JsonNode
    epoch*: int64

  WorldLedger* = object
    references*: seq[LedgerReference]
    claims*: seq[LedgerClaim]

  WorldGraphEdge* = object
    fromThing*: string
    toThing*: string
    relation*: string

  WorldGraph* = object
    nodes*: seq[string]
    edges*: seq[WorldGraphEdge]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc initWorldLedger*(): WorldLedger =
  result.references = @[]
  result.claims = @[]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateReference(refEntry: LedgerReference) =
  if refEntry.fromThing.len == 0:
    raise newException(ValueError,
      "ledger reference: fromThing cannot be empty")
  if refEntry.toThing.len == 0:
    raise newException(ValueError,
      "ledger reference: toThing cannot be empty")
  if refEntry.relation.len == 0:
    raise newException(ValueError,
      "ledger reference: relation cannot be empty")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateClaim(claim: LedgerClaim) =
  if claim.thingId.len == 0:
    raise newException(ValueError,
      "ledger claim: thingId cannot be empty")
  if claim.claimKey.len == 0:
    raise newException(ValueError,
      "ledger claim: claimKey cannot be empty")

# Flow: Append a relationship mutation sourced by an Occurrence.
proc appendReference*(ledger: var WorldLedger,
    sourceOccurrence: Occurrence,
    refEntry: LedgerReference) =
  discard sourceOccurrence
  validateReference(refEntry)
  ledger.references.add(refEntry)

# Flow: Append a claim mutation sourced by an Occurrence.
proc appendClaim*(ledger: var WorldLedger,
    sourceOccurrence: Occurrence,
    claim: LedgerClaim) =
  discard sourceOccurrence
  validateClaim(claim)
  ledger.claims.add(claim)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc referenceToJson(refEntry: LedgerReference): JsonNode =
  %*{
    "fromThing": refEntry.fromThing,
    "toThing": refEntry.toThing,
    "relation": refEntry.relation,
    "epoch": refEntry.epoch
  }

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc claimToJson(claim: LedgerClaim): JsonNode =
  %*{
    "thingId": claim.thingId,
    "claimKey": claim.claimKey,
    "claimValue": claim.claimValue,
    "epoch": claim.epoch
  }

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc ledgerToJson*(ledger: WorldLedger): JsonNode =
  result = %*{
    "references": ledger.references.mapIt(referenceToJson(it)),
    "claims": ledger.claims.mapIt(claimToJson(it))
  }

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc ledgerFromJson*(payload: JsonNode): WorldLedger =
  if payload.kind != JObject:
    raise newException(ValueError, "world ledger: payload must be object")
  if "references" notin payload or payload["references"].kind != JArray:
    raise newException(ValueError,
      "world ledger: references array is required")
  if "claims" notin payload or payload["claims"].kind != JArray:
    raise newException(ValueError,
      "world ledger: claims array is required")

  result = initWorldLedger()
  for item in payload["references"].items:
    let refEntry = LedgerReference(
      fromThing: item["fromThing"].getStr,
      toThing: item["toThing"].getStr,
      relation: item["relation"].getStr,
      epoch: item["epoch"].getInt
    )
    validateReference(refEntry)
    result.references.add(refEntry)

  for item in payload["claims"].items:
    let claim = LedgerClaim(
      thingId: item["thingId"].getStr,
      claimKey: item["claimKey"].getStr,
      claimValue: item["claimValue"],
      epoch: item["epoch"].getInt
    )
    validateClaim(claim)
    result.claims.add(claim)

# Flow: Validate references and claims at load time.
proc validateWorldLedger*(ledger: WorldLedger): bool =
  for refEntry in ledger.references:
    validateReference(refEntry)
  for claim in ledger.claims:
    validateClaim(claim)
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc addUniqueNode(nodes: var seq[string], id: string) =
  if id notin nodes:
    nodes.add(id)

# Flow: Build deterministic world graph from explicit ledger references only.
proc buildWorldGraph*(ledger: WorldLedger): WorldGraph =
  for refEntry in ledger.references:
    result.nodes.addUniqueNode(refEntry.fromThing)
    result.nodes.addUniqueNode(refEntry.toThing)
    result.edges.add(WorldGraphEdge(
      fromThing: refEntry.fromThing,
      toThing: refEntry.toThing,
      relation: refEntry.relation
    ))

  # Claims contribute nodes but no edges.
  for claim in ledger.claims:
    result.nodes.addUniqueNode(claim.thingId)

  result.nodes.sort(system.cmp[string])
  result.edges.sort(proc(a, b: WorldGraphEdge): int =
    let ka = a.fromThing & "|" & a.toThing & "|" & a.relation
    let kb = b.fromThing & "|" & b.toThing & "|" & b.relation
    system.cmp(ka, kb)
  )

# Flow: Enforce exactly one root Thing in world graph.
proc enforceSingleRoot*(graph: WorldGraph): bool =
  var indegree = initTable[string, int]()
  for n in graph.nodes:
    indegree[n] = 0
  for e in graph.edges:
    if e.toThing notin indegree:
      indegree[e.toThing] = 0
    indegree[e.toThing] = indegree[e.toThing] + 1
    if e.fromThing notin indegree:
      indegree[e.fromThing] = 0

  var rootCount = 0
  for _, d in indegree.pairs:
    if d == 0:
      rootCount = rootCount + 1

  if rootCount != 1:
    raise newException(ValueError,
      "world graph: single root invariant violated")
  true

# Flow: Ensure graph edges exist only when explicitly declared by ledger references.
proc noImplicitEdges*(ledger: WorldLedger, graph: WorldGraph): bool =
  var allowed = initTable[string, bool]()
  for r in ledger.references:
    allowed[r.fromThing & "|" & r.toThing & "|" & r.relation] = true

  for e in graph.edges:
    let key = e.fromThing & "|" & e.toThing & "|" & e.relation
    if key notin allowed:
      raise newException(ValueError,
        "world graph: implicit edge detected")
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc envelopeForLedger(bridge: PersistenceBridge, payload: JsonNode): JsonNode =
  let serialized = $payload
  let checksum = computeSha256(toBytes(serialized))
  result = %*{
    "schemaVersion": bridge.schemaVersion,
    "epoch": bridge.epoch,
    "checksum": checksum,
    "origin": bridge.origin,
    "payload": payload
  }

# Flow: Persist world ledger to modules layer of persistence bridge.
proc persistWorldLedger*(bridge: PersistenceBridge,
    ledger: WorldLedger,
    key: string = "world_ledger"): bool =
  let payload = ledgerToJson(ledger)
  let env = envelopeForLedger(bridge, payload)
  bridge.persistEnvelope(ModulesLayer, key, env)
  true

# Flow: Load world ledger from modules layer and validate.
proc loadWorldLedger*(bridge: PersistenceBridge,
    key: string = "world_ledger"): WorldLedger =
  let env = bridge.loadEnvelope(ModulesLayer, key)
  let payload = unwrapEnvelope(env)
  result = ledgerFromJson(payload)
  discard validateWorldLedger(result)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
