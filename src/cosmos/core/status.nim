# Wilder Cosmos 0.4.0
# Module name: status
# Module Path: src/cosmos/core/status.nim
#
# Summary: 
#
#   Status schema validation and bounded memory enforcement for Things
#   and modules.
#
# Simile: 
#
#   Like a circuit breaker panel — validates each line and trips in a
#   controlled way before unsafe overloads spread.
#
# Memory note: 
#
#   status checks run at load, mutation, and reconciliation;
#   memory escalation is warning first, then deterministic rejection.
#
# Flow: 
#
#   validate status shape -> evaluate invariants -> enforce memory caps ->
#   escalate on repeated violations -> expose introspection reports.

import json
import std/[tables, strutils]
import ../thing/thing

type
  ValidationPhase* = enum
    vpLoad
    vpMutation
    vpReconciliation

  StatusField* = object
    name*: string
    fieldType*: string
    required*: bool
    default*: JsonNode
    invariant*: string

  StatusSchema* = object
    fields*: seq[StatusField]
    schemaVersion*: int

  MemoryCategory* = enum
    mcState
    mcPerception
    mcTemporal
    mcModule

  MemoryEscalationLevel* = enum
    melOk
    melWarning
    melReject

  MemoryViolation* = object
    thingId*: string
    moduleId*: string
    category*: MemoryCategory
    usedBytes*: int
    capBytes*: int
    attempts*: int
    level*: MemoryEscalationLevel
    message*: string

  MemoryReport* = object
    thingId*: string
    moduleId*: string
    totalBytes*: int
    byCategory*: Table[MemoryCategory, int]
    level*: MemoryEscalationLevel
    violationCount*: int

  MemoryTracker* = ref object
    caps*: Table[MemoryCategory, int]
    globalUsage*: Table[MemoryCategory, int]
    usageByThing*: Table[string, Table[MemoryCategory, int]]
    usageByModule*: Table[string, Table[MemoryCategory, int]]
    violationCount*: int

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc isTypeMatch(node: JsonNode, fieldType: string): bool =
  case fieldType.toLowerAscii
  of "string":
    node.kind == JString
  of "int":
    node.kind == JInt
  of "float":
    node.kind in {JInt, JFloat}
  of "bool":
    node.kind == JBool
  of "object":
    node.kind == JObject
  of "array":
    node.kind == JArray
  of "any":
    true
  else:
    false

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc evaluateInvariant(fieldName: string, node: JsonNode, invariant: string): bool =
  if invariant.len == 0:
    return true

  case invariant.toLowerAscii
  of "nonempty":
    if node.kind == JString:
      return node.getStr().len > 0
    if node.kind in {JArray, JObject}:
      return node.len > 0
    return false
  of "nonnegative":
    if node.kind in {JInt, JFloat}:
      return node.getFloat() >= 0
    return false
  of "positive":
    if node.kind in {JInt, JFloat}:
      return node.getFloat() > 0
    return false
  of "nonzero":
    if node.kind in {JInt, JFloat}:
      return node.getFloat() != 0
    return false
  else:
    raise newException(ValueError,
      "status invariant error: unsupported invariant '" & invariant & "' for field '" & fieldName & "'")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc phaseName(phase: ValidationPhase): string =
  case phase
  of vpLoad: "load"
  of vpMutation: "mutation"
  of vpReconciliation: "reconciliation"

# Flow: Validate status JSON against schema field requirements and declared types.
proc validateStatus*(status: JsonNode, schema: StatusSchema): bool =
  ## Validate status structure and required fields.
  ## Raises: ValueError with field-specific message when invalid.
  if status.kind != JObject:
    raise newException(ValueError,
      "status validation error: status must be a JSON object")

  if schema.schemaVersion <= 0:
    raise newException(ValueError,
      "status validation error: schemaVersion must be positive")

  for field in schema.fields:
    if field.name.len == 0:
      raise newException(ValueError,
        "status validation error: schema field name cannot be empty")

    if field.required and not status.hasKey(field.name):
      raise newException(ValueError,
        "status validation error: missing required field '" & field.name & "'")

    if status.hasKey(field.name):
      let value = status[field.name]
      if not isTypeMatch(value, field.fieldType):
        raise newException(ValueError,
          "status validation error: field '" & field.name & "' expected type '" & field.fieldType & "'")

      discard evaluateInvariant(field.name, value, field.invariant)

  true

# Flow: Run status validation with phase-specific context for runtime lifecycle.
proc validateStatusAtPhase*(status: JsonNode,
    schema: StatusSchema,
    phase: ValidationPhase): bool =
  ## Validate status at load, mutation, or reconciliation checkpoints.
  ## Raises: ValueError with phase-specific context.
  try:
    return validateStatus(status, schema)
  except ValueError as e:
    raise newException(ValueError,
      "status " & phaseName(phase) & " check failed: " & e.msg)

# Flow: Validate Thing status at lifecycle checkpoints.
proc validateThingStatus*(t: Thing,
    schema: StatusSchema,
    phase: ValidationPhase): bool =
  ## Validate a Thing's status against schema at a lifecycle phase.
  validateStatusAtPhase(t.status, schema, phase)

# Flow: Estimate memory bytes for a JSON status payload deterministically.
proc estimateJsonBytes*(data: JsonNode): int =
  ## Deterministic estimate based on canonical JSON string length.
  len($data)

# Flow: Validate memory cap for mutation-time enforcement.
proc checkMemoryCap*(currentSize: int, memoryCap: int): bool =
  ## Check if current size is within memory cap.
  ## Raises: ValueError when cap is exceeded.
  if memoryCap <= 0:
    raise newException(ValueError,
      "memory cap error: memoryCap must be positive")
  if currentSize > memoryCap:
    raise newException(ValueError,
      "memory cap exceeded: used=" & $currentSize & " cap=" & $memoryCap)
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc initCategoryTable(): Table[MemoryCategory, int] =
  result = initTable[MemoryCategory, int]()
  result[mcState] = 0
  result[mcPerception] = 0
  result[mcTemporal] = 0
  result[mcModule] = 0

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc toLevel(attempts: int): MemoryEscalationLevel =
  if attempts <= 0:
    melOk
  elif attempts == 1:
    melWarning
  else:
    melReject

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc mkViolation(thingId, moduleId: string,
    category: MemoryCategory,
    usedBytes, capBytes, attempts: int): MemoryViolation =
  let level = toLevel(attempts)
  let msg =
    if level == melWarning:
      "memory warning: category=" & $category & " used=" & $usedBytes & " cap=" & $capBytes
    else:
      "memory rejection: category=" & $category & " used=" & $usedBytes & " cap=" & $capBytes

  MemoryViolation(
    thingId: thingId,
    moduleId: moduleId,
    category: category,
    usedBytes: usedBytes,
    capBytes: capBytes,
    attempts: attempts,
    level: level,
    message: msg
  )

# Flow: Create a tracker with per-category caps and zeroed usage.
proc initMemoryTracker*(stateCap,
    perceptionCap,
    temporalCap,
    moduleCap: int): MemoryTracker =
  ## Initialize memory tracking for all four memory categories.
  if stateCap <= 0 or perceptionCap <= 0 or temporalCap <= 0 or moduleCap <= 0:
    raise newException(ValueError,
      "memory tracker error: all category caps must be positive")

  new(result)
  result.caps = initCategoryTable()
  result.globalUsage = initCategoryTable()
  result.usageByThing = initTable[string, Table[MemoryCategory, int]]()
  result.usageByModule = initTable[string, Table[MemoryCategory, int]]()
  result.violationCount = 0

  result.caps[mcState] = stateCap
  result.caps[mcPerception] = perceptionCap
  result.caps[mcTemporal] = temporalCap
  result.caps[mcModule] = moduleCap

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc ensureThingBucket(tracker: MemoryTracker, thingId: string) =
  if thingId.len == 0:
    return
  if thingId notin tracker.usageByThing:
    tracker.usageByThing[thingId] = initCategoryTable()

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc ensureModuleBucket(tracker: MemoryTracker, moduleId: string) =
  if moduleId.len == 0:
    return
  if moduleId notin tracker.usageByModule:
    tracker.usageByModule[moduleId] = initCategoryTable()

# Flow: Record usage and return escalation result when over cap.
proc recordMemoryUsage*(tracker: MemoryTracker,
    category: MemoryCategory,
    bytesDelta: int,
    thingId: string = "",
    moduleId: string = ""): MemoryViolation =
  ## Record memory usage for category and optionally Thing/module ownership.
  ## First cap violation returns warning; repeated violations return rejection.
  if bytesDelta < 0:
    raise newException(ValueError,
      "memory tracker error: bytesDelta cannot be negative")

  tracker.globalUsage[category] = tracker.globalUsage[category] + bytesDelta
  let used = tracker.globalUsage[category]
  let cap = tracker.caps[category]

  ensureThingBucket(tracker, thingId)
  if thingId.len > 0:
    tracker.usageByThing[thingId][category] = tracker.usageByThing[thingId][category] + bytesDelta

  ensureModuleBucket(tracker, moduleId)
  if moduleId.len > 0:
    tracker.usageByModule[moduleId][category] = tracker.usageByModule[moduleId][category] + bytesDelta

  if used > cap:
    tracker.violationCount = tracker.violationCount + 1
    result = mkViolation(thingId, moduleId, category, used, cap, tracker.violationCount)
    if result.level == melReject:
      raise newException(ValueError, result.message)
  else:
    result = mkViolation(thingId, moduleId, category, used, cap, 0)

# Flow: Query memory usage for one Thing and optional module.
proc memoryReportForThing*(tracker: MemoryTracker,
    thingId: string,
    moduleId: string = ""): MemoryReport =
  ## Introspection report for Thing and optional module context.
  result.byCategory = initCategoryTable()
  result.thingId = thingId
  result.moduleId = moduleId
  result.violationCount = tracker.violationCount
  result.level = toLevel(tracker.violationCount)

  if thingId.len > 0 and thingId in tracker.usageByThing:
    for category in [mcState, mcPerception, mcTemporal, mcModule]:
      result.byCategory[category] = tracker.usageByThing[thingId][category]

  if moduleId.len > 0 and moduleId in tracker.usageByModule:
    result.byCategory[mcModule] = tracker.usageByModule[moduleId][mcModule]

  result.totalBytes = 0
  for category in [mcState, mcPerception, mcTemporal, mcModule]:
    result.totalBytes = result.totalBytes + result.byCategory[category]

# Flow: Query aggregate memory usage across all Things/modules.
proc memoryReportGlobal*(tracker: MemoryTracker): MemoryReport =
  ## Introspection report for global memory usage.
  result.byCategory = initCategoryTable()
  result.thingId = "global"
  result.moduleId = "global"
  result.violationCount = tracker.violationCount
  result.level = toLevel(tracker.violationCount)

  for category in [mcState, mcPerception, mcTemporal, mcModule]:
    result.byCategory[category] = tracker.globalUsage[category]
    result.totalBytes = result.totalBytes + result.byCategory[category]

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
