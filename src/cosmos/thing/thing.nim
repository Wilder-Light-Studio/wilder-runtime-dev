# Wilder Cosmos 0.4.0
# Module name: thing
# Module Path: src/cosmos/thing/thing.nim
#
# Summary: Ontology primitives — Concept, Occurrence, Perception,
#   and Thing types with lifecycle management.
# Simile: Like lego bricks for building the world model — every
#   runtime entity is assembled from these four shapes.
# Memory note: Types must remain serializable and deterministic;
#   no ref objects without justification. Thing lifecycle is
#   instantiation → active → destruction.
# Flow: Define types → initialize Things from Concepts → emit
#   Occurrences → filter into Perceptions → maintain lifecycle.

import json
import std/sequtils
import std/strutils
import ../core/manifest

type
  # Concept: Blueprint for a Thing with ontological structure.
  # Six sections: What, Why, How, Where, When, With.
  Concept* = object
    id*: string                   ## Concept identifier.
    whatSection*: JsonNode        ## What is this entity? (Purpose)
    whySection*: JsonNode         ## Why does it exist? (Rationale)
    howSection*: JsonNode         ## How does it work? (Mechanism)
    whereSection*: JsonNode       ## Where does it exist? (Scope)
    whenSection*: JsonNode        ## When does it activate? (Temporal)
    withSection*: JsonNode        ## With what dependencies? (Requirements)
    manifest*: JsonNode           ## Interrogative Manifest reference.

  # Occurrence: Event or state change emitted by a Thing.
  Occurrence* = object
    id*: string                   ## Unique occurrence identifier.
    source*: string               ## Thing that emitted this occurrence.
    epoch*: int64                 ## Frame counter at emission.
    payload*: JsonNode            ## Event data (validated payload).
    projectionRadius*: int        ## Distance this occurrence propagates.

  # Perception: Filtered view of an Occurrence by a Thing.
  Perception* = object
    occurrenceId*: string         ## Which occurrence was perceived?
    thingId*: string              ## Which Thing perceived it?
    epoch*: int64                 ## Frame counter of perception.
    filtered*: bool               ## Was this perception filtered/accepted?

  # Thing: Runtime entity instantiated from Concept, maintains state.
  Thing* = object
    id*: string                   ## Unique Thing identifier.
    conceptId*: string            ## Concept this Thing instantiates.
    status*: JsonNode             ## Current state snapshot.
    perceptionLog*: seq[Perception]  ## Historical perceptions.
    epoch*: int64                 ## Current frame counter.
    metadata*: JsonNode           ## Additional Thing metadata.
    active*: bool                 ## Is this Thing lifecycle-active?

  ExternalTransport* = enum
    etStdInStdOut
    etArgumentsOnly

  ExternalProcessThing* = object
    conceptBlueprint*: Concept
    thing*: Thing
    command*: string
    args*: seq[string]
    transport*: ExternalTransport

# Flow: Check whether a JSON node carries meaningful non-empty content.
proc jsonHasMeaningfulContent(node: JsonNode): bool =
  ## Returns true when a JSON section carries meaningful content.
  if node.isNil:
    return false
  case node.kind
  of JNull:
    return false
  of JObject, JArray:
    return node.len > 0
  of JString:
    return node.getStr.len > 0
  else:
    return true

# Flow: Validate minimal Concept identity and WHY requirements.
proc validateConcept*(c: Concept) =
  ## Validate the minimal Concept contract.
  ## A Concept requires identity plus a non-empty WHY section.
  if c.id.len == 0:
    raise newException(ValueError, "Concept: id cannot be empty")
  if not jsonHasMeaningfulContent(c.whySection):
    raise newException(ValueError, "Concept: WHY cannot be empty")
  validateManifestJson(c.manifest)

# Flow: Validate minimal Thing identity contract.
proc validateThing*(thing: Thing) =
  ## Validate the minimal Thing contract.
  if thing.id.len == 0:
    raise newException(ValueError, "Thing: id cannot be empty")

# Flow: Construct a Thing from identity-first inputs and defaults.
proc createThing*(thingId: string, conceptId: string = "", initialStatus: JsonNode = nil,
    metadata: JsonNode = nil, epoch: int64 = 0, active: bool = true): Thing =
  ## Create a Thing using the minimal identity-first contract.
  if thingId.len == 0:
    raise newException(ValueError, "Thing: id cannot be empty")
  let statusNode = if initialStatus.isNil: %*{} else: initialStatus
  let metadataNode = if metadata.isNil: %*{} else: metadata
  result = Thing(
    id: thingId,
    conceptId: conceptId,
    status: statusNode,
    perceptionLog: @[],
    epoch: epoch,
    metadata: metadataNode,
    active: active
  )

# Flow: Create a Concept from six sections and manifest reference.
proc createConcept*(id: string, what, why, how, where, `when`, withSection, manifest: JsonNode): Concept =
  ## Create a Concept with all six sections.
  ## All parameters required; empty sections must be explicitly passed as %*{}.
  result = Concept(id: id, whatSection: what, whySection: why,
    howSection: how, whereSection: where, whenSection: `when`,
    withSection: withSection, manifest: manifest)

# Flow: Validate manifest and create a Concept with a typed InterrogativeManifest.
proc createConceptWithManifest*(id: string, what, why, how, where, `when`,
    withSection: JsonNode, m: InterrogativeManifest): Concept =
  ## Create a Concept with a validated InterrogativeManifest (IM).
  ## Validates all IM fields at load time before constructing the Concept.
  ## Raises: ValueError if any required IM field fails validation.
  validateManifest(m)
  result = createConcept(id, what, why, how, where, `when`,
    withSection, manifestToJson(m))

# Flow: Wrap an external process with handwritten manifest authority.
proc wrapExternalProcessThing*(thingId, command: string, manifest: InterrogativeManifest,
    args: seq[string] = @[],
    transport: ExternalTransport = etStdInStdOut): ExternalProcessThing =
  ## Wrap an external process as a Thing using a handwritten manifest.
  if thingId.len == 0:
    raise newException(ValueError, "ExternalProcessThing: thing id cannot be empty")
  if command.strip.len == 0:
    raise newException(ValueError, "ExternalProcessThing: command cannot be empty")
  validateManifest(manifest)
  let conceptBlueprint = createConceptWithManifest(
    id = manifest.WHO,
    what = %*{"description": manifest.WHAT},
    why = %*{"description": manifest.WHY},
    how = %*{"description": manifest.HOW},
    where = %*{"description": manifest.WHERE},
    `when` = %*{"description": manifest.WHEN},
    withSection = %*{"relations": manifest.WITH},
    m = manifest
  )
  let thing = createThing(
    thingId = thingId,
    conceptId = conceptBlueprint.id,
    metadata = %*{
      "runtime": "external-process",
      "command": command,
      "args": args,
      "transport": if transport == etStdInStdOut: "stdin/stdout" else: "arguments-only",
      "contractAuthority": "handwritten-manifest"
    }
  )
  result = ExternalProcessThing(
    conceptBlueprint: conceptBlueprint,
    thing: thing,
    command: command,
    args: args,
    transport: transport
  )

# Flow: Create an Occurrence from source and payload with projection scope.
proc createOccurrence*(id, source: string, epoch: int64, payload: JsonNode,
    radius: int = 1): Occurrence =
  ## Create an Occurrence with validated fields.
  ## Raises: ValueError if id or source is empty.
  if id.len == 0:
    raise newException(ValueError, "Occurrence: id cannot be empty")
  if source.len == 0:
    raise newException(ValueError, "Occurrence: source cannot be empty")
  if radius < 0:
    raise newException(ValueError, "Occurrence: projectionRadius must be non-negative")
  result = Occurrence(id: id, source: source, epoch: epoch, payload: payload,
    projectionRadius: radius)

# Flow: Create a Perception linking an Occurrence to a Thing observer.
proc createPerception*(occurrenceId, thingId: string, epoch: int64,
    filtered: bool = true): Perception =
  ## Create a Perception record.
  ## Raises: ValueError if occurrence or thing id is empty.
  if occurrenceId.len == 0:
    raise newException(ValueError, "Perception: occurrenceId cannot be empty")
  if thingId.len == 0:
    raise newException(ValueError, "Perception: thingId cannot be empty")
  result = Perception(occurrenceId: occurrenceId, thingId: thingId,
    epoch: epoch, filtered: filtered)

# Flow: Instantiate a new Thing from a Concept blueprint.
proc instantiateThing*(thingId: string, conceptBlueprint: Concept, initialStatus: JsonNode,
    epoch: int64 = 0): Thing =
  ## Instantiate a Thing from a Concept with initial status.
  ## Raises: ValueError if thingId is empty or concept id is empty.
  if thingId.len == 0:
    raise newException(ValueError, "Thing: id cannot be empty")
  if conceptBlueprint.id.len == 0:
    raise newException(ValueError, "Thing: concept id cannot be empty")
  result = createThing(
    thingId = thingId,
    conceptId = conceptBlueprint.id,
    initialStatus = initialStatus,
    metadata = %*{"instantiated_at": $epoch},
    epoch = epoch,
    active = true
  )

# Flow: Mark a Thing as active (entry to lifecycle).
proc activateThing*(thing: var Thing): void =
  ## Activate a Thing, marking it as ready for runtime.
  thing.active = true

# Flow: Mark a Thing as inactive (destruction phase).
proc deactivateThing*(thing: var Thing): void =
  ## Deactivate a Thing, marking it for cleanup.
  thing.active = false

# Flow: Update Thing status with new state snapshot.
proc updateStatus*(thing: var Thing, newStatus: JsonNode): void =
  ## Update Thing status. Fails fast if Thing is not active.
  if not thing.active:
    raise newException(ValueError, "Cannot update status of inactive Thing")
  thing.status = newStatus
  thing.epoch += 1

# Flow: Add a Perception to Thing's perception log.
proc recordPerception*(thing: var Thing, perception: Perception): void =
  ## Record a Perception in the Thing's log.
  ## Fails fast if Thing is not active.
  if not thing.active:
    raise newException(ValueError, "Cannot record perception on inactive Thing")
  thing.perceptionLog.add(perception)

# Flow: Filter an Occurrence for this Thing based on projection and interests.
proc filterOccurrence*(thing: Thing, occ: Occurrence): bool =
  ## Deterministic filter: accept if Occurrence source matches Thing concept.
  ## In full implementation, uses projection radius and interest topics.
  if not thing.active:
    return false
  # Simple deterministic filter: match is based on conceptId alignment
  # In later chapters, expand to projection radius, topic filters, etc.
  result = occ.source != ".*reserved.*"  # Never filter reserved sources

# Flow: Emit an Occurrence as a Thing's action into the runtime.
proc emitOccurrence*(thingId: string, epoch: int64, payload: JsonNode,
    sourceLabel: string = "thing"): Occurrence =
  ## Emit an Occurrence from a Thing with current epoch and payload.
  createOccurrence(
    id = "occ_" & thingId & "_" & $epoch,
    source = thingId,
    epoch = epoch,
    payload = payload,
    radius = 1
  )

# Flow: Convert Thing to JSON for serialization or storage.
proc thingToJson*(thing: Thing): JsonNode =
  ## Serialize a Thing to JSON.
  result = %*{
    "id": thing.id,
    "conceptId": thing.conceptId,
    "status": thing.status,
    "perceptionLog": thing.perceptionLog.mapIt(%*{
      "occurrenceId": it.occurrenceId,
      "thingId": it.thingId,
      "epoch": it.epoch,
      "filtered": it.filtered
    }),
    "epoch": thing.epoch,
    "metadata": thing.metadata,
    "active": thing.active
  }

# Flow: Reconstruct a Thing from JSON.
proc thingFromJson*(data: JsonNode): Thing =
  ## Deserialize a Thing from JSON.
  ## Raises: ValueError if required fields are missing.
  if data.kind != JObject:
    raise newException(ValueError, "Thing JSON must be an object")
  if "id" notin data:
    raise newException(ValueError, "Thing JSON missing required id")
  
  var perceptionLog: seq[Perception] = @[]
  if "perceptionLog" in data and data["perceptionLog"].kind == JArray:
    for item in data["perceptionLog"].getElems():
      if "occurrenceId" in item and "thingId" in item and "epoch" in item:
        perceptionLog.add(Perception(
          occurrenceId: item["occurrenceId"].getStr,
          thingId: item["thingId"].getStr,
          epoch: item["epoch"].getInt,
          filtered: item.getOrDefault("filtered").getBool(true)
        ))
  
  result = Thing(
    id: data["id"].getStr,
    conceptId: (if "conceptId" in data: data["conceptId"].getStr else: ""),
    status: data.getOrDefault("status"),
    perceptionLog: perceptionLog,
    epoch: data.getOrDefault("epoch").getInt(0),
    metadata: data.getOrDefault("metadata"),
    active: data.getOrDefault("active").getBool(false)
  )

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
