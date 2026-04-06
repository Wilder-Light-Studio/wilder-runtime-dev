# Wilder Cosmos 0.4.0
# Module name: concepts
# Module Path: src/runtime/concepts.nim
# Summary: In-memory Concept registry and effective-source resolution for Phase X.
# Simile: Like a dispatch ledger, it keeps both authored and derived Concept sources while picking one effective contract.
# Memory note: programmatic Concepts always override manual Concepts when both exist for the same identity.
# Flow: register sources -> resolve effective Concept -> export stable ABI payload.

import json
import std/[algorithm, sequtils, tables, strutils]
import validation
import capabilities
import cosmos/thing/thing

type
  ConceptSourceKind* = enum
    cskProgrammatic
    cskManual

  RegisteredConcept* = object
    conceptId*: string
    sourceKind*: ConceptSourceKind
    schemaVersion*: int
    derivedFrom*: string
    conceptDef*: Concept

  ConceptRegistry* = ref object
    entries*: Table[string, seq[RegisteredConcept]]

const
  ConceptAbiVersion* = "concept-abi-v1"

# Flow: Convert string to bytes for checksum generation.
proc stringToBytes(raw: string): seq[byte] =
  result = newSeq[byte](raw.len)
  for i in 0 ..< raw.len:
    result[i] = byte(raw[i])

# Flow: Convert source enum to stable serialized representation.
proc sourceKindLabel(kind: ConceptSourceKind): string =
  case kind
  of cskProgrammatic: "programmatic"
  of cskManual: "manual"

# Flow: Create an empty Concept registry.
proc newConceptRegistry*(): ConceptRegistry =
  ConceptRegistry(entries: initTable[string, seq[RegisteredConcept]]())

# Flow: Validate one registry candidate before insertion.
proc validateRegisteredConcept(conceptDef: Concept,
                               sourceKind: ConceptSourceKind,
                               schemaVersion: int,
                               derivedFrom: string) =
  validateConcept(conceptDef)
  if schemaVersion < 1:
    raise newException(ValueError,
      "concepts: schemaVersion must be >= 1")
  if derivedFrom.strip.len == 0:
    raise newException(ValueError,
      "concepts: derivedFrom must not be empty")
  if conceptDef.id.strip.len == 0:
    raise newException(ValueError,
      "concepts: concept id must not be empty")
  discard sourceKind

# Flow: Register one Concept source, preserving one slot per source kind per identity.
proc registerConcept(reg: ConceptRegistry,
                     conceptDef: Concept,
                     sourceKind: ConceptSourceKind,
                     schemaVersion: int,
                     derivedFrom: string) =
  validateRegisteredConcept(conceptDef, sourceKind, schemaVersion, derivedFrom)
  let conceptId = conceptDef.id.strip
  var current = reg.entries.getOrDefault(conceptId)
  for existing in current:
    if existing.sourceKind == sourceKind:
      raise newException(ValueError,
        "concepts: duplicate " & sourceKindLabel(sourceKind) &
        " concept for '" & conceptId & "'")
  current.add(RegisteredConcept(
    conceptId: conceptId,
    sourceKind: sourceKind,
    schemaVersion: schemaVersion,
    derivedFrom: derivedFrom.strip,
    conceptDef: conceptDef
  ))
  reg.entries[conceptId] = current

# Flow: Register a programmatic Concept source.
proc registerProgrammaticConcept*(reg: ConceptRegistry,
                                  conceptDef: Concept,
                                  schemaVersion: int = 1,
                                  derivedFrom: string = "code-derived") =
  registerConcept(reg, conceptDef, cskProgrammatic, schemaVersion, derivedFrom)

# Flow: Register a manual Concept source.
proc registerManualConcept*(reg: ConceptRegistry,
                            conceptDef: Concept,
                            schemaVersion: int = 1,
                            derivedFrom: string = "manual-file") =
  registerConcept(reg, conceptDef, cskManual, schemaVersion, derivedFrom)

# Flow: Check whether any source is registered for one concept identity.
proc hasConcept*(reg: ConceptRegistry, conceptId: string): bool =
  reg.entries.hasKey(conceptId.strip)

# Flow: Check whether both programmatic and manual sources exist for one identity.
proc hasConflict*(reg: ConceptRegistry, conceptId: string): bool =
  let normalized = conceptId.strip
  if not reg.entries.hasKey(normalized):
    return false
  var hasProgrammatic = false
  var hasManual = false
  for entry in reg.entries[normalized]:
    case entry.sourceKind
    of cskProgrammatic: hasProgrammatic = true
    of cskManual: hasManual = true
  hasProgrammatic and hasManual

# Flow: Return concept ids in deterministic order.
proc listConceptIds*(reg: ConceptRegistry): seq[string] =
  for conceptId, _ in reg.entries.pairs:
    result.add(conceptId)
  result.sort(system.cmp[string])

# Flow: Resolve the effective Concept by precedence order.
proc resolveEffectiveConcept*(reg: ConceptRegistry,
                              conceptId: string): RegisteredConcept =
  let normalized = conceptId.strip
  if not reg.entries.hasKey(normalized):
    raise newException(KeyError,
      "concepts: no concept named '" & normalized & "'")
  var manualCandidate: RegisteredConcept
  var hasManualCandidate = false
  for entry in reg.entries[normalized]:
    if entry.sourceKind == cskProgrammatic:
      return entry
    if entry.sourceKind == cskManual:
      manualCandidate = entry
      hasManualCandidate = true
  if hasManualCandidate:
    return manualCandidate
  raise newException(KeyError,
    "concepts: concept '" & normalized & "' has no usable sources")

# Flow: Build a deterministic ABI payload for the effective Concept.
proc exportEffectiveConcept*(reg: ConceptRegistry, conceptId: string): JsonNode =
  let entry = resolveEffectiveConcept(reg, conceptId)
  let sections = %*{
    "what": entry.conceptDef.whatSection,
    "why": entry.conceptDef.whySection,
    "how": entry.conceptDef.howSection,
    "where": entry.conceptDef.whereSection,
    "when": entry.conceptDef.whenSection,
    "with": entry.conceptDef.withSection
  }
  let checksum = computeSha256(stringToBytes($sections))
  %*{
    "abiVersion": ConceptAbiVersion,
    "conceptId": entry.conceptId,
    "sourceKind": sourceKindLabel(entry.sourceKind),
    "schemaVersion": entry.schemaVersion,
    "checksumSha256": checksum,
    "manifest": entry.conceptDef.manifest,
    "sections": sections,
    "derivedFrom": entry.derivedFrom
  }

# Flow: Build an inspectable registry record for one concept identity.
proc conceptRegistryRecord*(reg: ConceptRegistry, conceptId: string): JsonNode =
  let normalized = conceptId.strip
  let effective = resolveEffectiveConcept(reg, normalized)
  %*{
    "conceptId": normalized,
    "effectiveSourceKind": sourceKindLabel(effective.sourceKind),
    "hasProgrammatic": reg.entries[normalized].anyIt(it.sourceKind == cskProgrammatic),
    "hasManual": reg.entries[normalized].anyIt(it.sourceKind == cskManual),
    "derivedFrom": effective.derivedFrom,
    "schemaVersion": effective.schemaVersion
  }

# Flow: Derive and register one programmatic Concept from capability boundaries.
proc registerConceptFromBoundaryDeclarations*(reg: ConceptRegistry,
                                              thingName: string,
                                              provides: seq[ProvideDeclaration],
                                              wants: seq[WantDeclaration],
                                              moduleBindings: seq[ModuleBindingDeclaration] = @[],
                                              schemaVersion: int = 1,
                                              derivedFrom: string = "nim-boundary") =
  let normalizedThing = thingName.strip
  if normalizedThing.len == 0:
    raise newException(ValueError,
      "concepts: thingName must not be empty for boundary derivation")

  var provideEntries: seq[JsonNode] = @[]
  for provide in provides:
    if provide.thingName.strip == normalizedThing:
      provideEntries.add(%*{
        "provide": provide.provideName.strip,
        "signature": provide.signature.strip
      })

  var wantEntries: seq[JsonNode] = @[]
  for want in wants:
    if want.consumerThing.strip == normalizedThing:
      wantEntries.add(%*{
        "reference": want.reference.strip,
        "expectedSignature": want.expectedSignature.strip
      })

  var bindingEntries: seq[JsonNode] = @[]
  let keyPrefix = normalizedThing & "."
  for binding in moduleBindings:
    if binding.provideKey.strip.startsWith(keyPrefix):
      bindingEntries.add(%*{
        "provideKey": binding.provideKey.strip,
        "moduleType": binding.moduleType.strip,
        "moduleRef": binding.moduleRef.strip,
        "entrypoint": binding.entrypoint.strip,
        "abiVersion": binding.abiVersion.strip
      })

  provideEntries.sort(proc(a, b: JsonNode): int =
    let byProvide = system.cmp(a["provide"].getStr(""), b["provide"].getStr(""))
    if byProvide != 0:
      return byProvide
    system.cmp(a["signature"].getStr(""), b["signature"].getStr(""))
  )

  wantEntries.sort(proc(a, b: JsonNode): int =
    let byReference = system.cmp(a["reference"].getStr(""), b["reference"].getStr(""))
    if byReference != 0:
      return byReference
    system.cmp(a["expectedSignature"].getStr(""), b["expectedSignature"].getStr(""))
  )

  bindingEntries.sort(proc(a, b: JsonNode): int =
    let byKey = system.cmp(a["provideKey"].getStr(""), b["provideKey"].getStr(""))
    if byKey != 0:
      return byKey
    let byType = system.cmp(a["moduleType"].getStr(""), b["moduleType"].getStr(""))
    if byType != 0:
      return byType
    let byRef = system.cmp(a["moduleRef"].getStr(""), b["moduleRef"].getStr(""))
    if byRef != 0:
      return byRef
    let byEntrypoint = system.cmp(a["entrypoint"].getStr(""), b["entrypoint"].getStr(""))
    if byEntrypoint != 0:
      return byEntrypoint
    system.cmp(a["abiVersion"].getStr(""), b["abiVersion"].getStr(""))
  )

  let conceptDef = createConcept(
    normalizedThing,
    %*{
      "description": "Capability boundary for " & normalizedThing
    },
    %*{
      "description": "Programmatically derived from Nim-first boundary declarations"
    },
    %*{
      "provides": provideEntries,
      "wants": wantEntries,
      "moduleBindings": bindingEntries
    },
    %*{
      "source": "runtime.capability-graph"
    },
    %*{
      "phase": "startup"
    },
    %*{
      "capabilityRefs": wantEntries.mapIt(it["reference"].getStr(""))
    },
    %*{}
  )

  registerProgrammaticConcept(reg,
    conceptDef,
    schemaVersion = schemaVersion,
    derivedFrom = derivedFrom)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.