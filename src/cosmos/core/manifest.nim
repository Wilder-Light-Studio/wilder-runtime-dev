# Wilder Cosmos 0.4.0
# Module name: manifest
# Module Path: src/cosmos/core/manifest.nim
#
# Summary: Interrogative Manifest (IM) type, validation, and JSON conversion
#   for Cosmos Concepts. Implements SPEC §6 and §6.2.
# Simile: Like a contract sheet — if a manifest exists, every declared slot
#   must actually contain usable content.
# Memory note: Concepts may omit manifests entirely; when a manifest is
#   present, all interrogative fields must be non-empty. Specialists must have
#   non-empty PROVIDES and REQUIRES.
# Flow: define IM type -> detect manifest presence -> validate manifest
#   content -> validate specialist constraints -> convert to JsonNode.

import json

const
  ManifestStringKeys* = ["WHO", "WHAT", "WHY", "WHERE", "WHEN", "HOW"]
  ManifestSeqKeys* = ["REQUIRES", "WANTS", "PROVIDES", "WITH"]

type
  InterrogativeManifest* = object
    ## The ten interrogatives every Concept must declare (SPEC §6).
    WHO*: string          ## Identity: who owns or is responsible for this Concept.
    WHAT*: string         ## Purpose: what this Concept represents.
    WHY*: string          ## Rationale: why this Concept exists.
    WHERE*: string        ## Scope: where this Concept operates.
    WHEN*: string         ## Temporal: when this Concept is active.
    HOW*: string          ## Mechanism: how this Concept works.
    REQUIRES*: seq[string] ## Prerequisites this Concept depends on.
    WANTS*: seq[string]    ## Optional dependencies this Concept prefers.
    PROVIDES*: seq[string] ## Capabilities this Concept exposes to others.
    WITH*: seq[string]     ## Peers or collaborators this Concept works with.

proc hasMeaningfulManifest*(m: InterrogativeManifest): bool =
  ## Returns true when any manifest field carries content.
  m.WHO.len > 0 or m.WHAT.len > 0 or m.WHY.len > 0 or m.WHERE.len > 0 or
    m.WHEN.len > 0 or m.HOW.len > 0 or m.REQUIRES.len > 0 or m.WANTS.len > 0 or
    m.PROVIDES.len > 0 or m.WITH.len > 0

proc manifestPresent*(manifest: JsonNode): bool =
  ## Returns true when a JSON manifest is present and not structurally empty.
  if manifest.isNil:
    return false
  case manifest.kind
  of JNull:
    return false
  of JObject, JArray:
    return manifest.len > 0
  of JString:
    return manifest.getStr.len > 0
  else:
    return true

proc validateNonEmptyItems(fieldName: string, values: seq[string]) =
  ## Fail fast on empty list fields or empty entries within list fields.
  if values.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: " & fieldName & " cannot be empty")
  for value in values:
    if value.len == 0:
      raise newException(ValueError,
        "InterrogativeManifest: " & fieldName & " cannot contain empty values")

proc requireStringField(manifest: JsonNode, key: string) =
  ## Validate one required string field in a JSON manifest.
  if key notin manifest or manifest[key].kind != JString or manifest[key].getStr.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: " & key & " cannot be empty")

proc requireSeqField(manifest: JsonNode, key: string) =
  ## Validate one required sequence field in a JSON manifest.
  if key notin manifest or manifest[key].kind != JArray or manifest[key].len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: " & key & " cannot be empty")
  for item in manifest[key].items:
    if item.kind != JString or item.getStr.len == 0:
      raise newException(ValueError,
        "InterrogativeManifest: " & key & " cannot contain empty values")

# Flow: Validate all required fields of an InterrogativeManifest (IM).
proc validateManifest*(m: InterrogativeManifest) =
  ## Validate an InterrogativeManifest (IM): all ten interrogatives must be
  ## non-empty when a manifest is present.
  ## Raises: ValueError identifying the first empty required field.
  if m.WHO.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: WHO cannot be empty")
  if m.WHAT.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: WHAT cannot be empty")
  if m.WHY.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: WHY cannot be empty")
  if m.WHERE.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: WHERE cannot be empty")
  if m.WHEN.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: WHEN cannot be empty")
  if m.HOW.len == 0:
    raise newException(ValueError,
      "InterrogativeManifest: HOW cannot be empty")
  validateNonEmptyItems("REQUIRES", m.REQUIRES)
  validateNonEmptyItems("WANTS", m.WANTS)
  validateNonEmptyItems("PROVIDES", m.PROVIDES)
  validateNonEmptyItems("WITH", m.WITH)

proc validateManifestJson*(manifest: JsonNode) =
  ## Validate a JSON manifest only when one is actually present.
  ## Raises: ValueError if the manifest shape is incomplete or empty.
  if not manifestPresent(manifest):
    return
  if manifest.kind != JObject:
    raise newException(ValueError,
      "InterrogativeManifest: manifest must be a JSON object")
  for key in ManifestStringKeys:
    requireStringField(manifest, key)
  for key in ManifestSeqKeys:
    requireSeqField(manifest, key)

# Flow: Validate a specialist Concept's manifest (SPEC §6.2).
proc validateSpecialist*(m: InterrogativeManifest) =
  ## Validate specialist capability declaration on top of base manifest rules.
  ## Specialists must declare non-empty PROVIDES and REQUIRES.
  ## Raises: ValueError if any specialist constraint is not met.
  validateManifest(m)
  if m.PROVIDES.len == 0:
    raise newException(ValueError,
      "specialist manifest: PROVIDES must declare at least one capability")
  if m.REQUIRES.len == 0:
    raise newException(ValueError,
      "specialist manifest: REQUIRES must declare at least one prerequisite")

# Flow: Convert InterrogativeManifest (IM) to JsonNode for Concept storage.
proc manifestToJson*(m: InterrogativeManifest): JsonNode =
  ## Serialize an InterrogativeManifest (IM) to JsonNode.
  ## Used to populate the Concept.manifest field.
  result = %*{
    "WHO":      m.WHO,
    "WHAT":     m.WHAT,
    "WHY":      m.WHY,
    "WHERE":    m.WHERE,
    "WHEN":     m.WHEN,
    "HOW":      m.HOW,
    "REQUIRES": m.REQUIRES,
    "WANTS":    m.WANTS,
    "PROVIDES": m.PROVIDES,
    "WITH":     m.WITH
  }

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
