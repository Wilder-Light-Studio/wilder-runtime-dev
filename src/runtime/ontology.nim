# Wilder Cosmos 0.4.0
# Module name: ontology
# Module Path: src/runtime/ontology.nim
#
# Summary: Deterministic scope, context, override, and reference resolution.
# Simile: Like a map legend, it keeps path and relationship meaning consistent.
# Memory note: all scope and context resolution must be deterministic and
#   bounded to Cosmos descendants.
# Flow: resolve scope -> resolve context -> apply overrides -> resolve reference.

import json
import std/[strutils, sequtils, tables, algorithm]
import ../cosmos/thing/thing

const
  CosmosScopeRoot* = "cosmos"

type
  Reference* = object
    ## Canonical reference record.
    targetId*: string
    localMetadata*: JsonNode

  Context* = object
    ## Resolved downward context for a Thing.
    mergedCapabilities*: seq[string]
    mergedConfig*: JsonNode
    inheritedLogs*: seq[string]
    inheritedRelationships*: seq[string]
    children*: seq[string]

  ResolvedReference* = object
    ## Canonical target context plus local reference metadata.
    targetId*: string
    context*: Context
    localMetadata*: JsonNode

# Flow: Append only values that are not already present.
proc uniqueAppend(dest: var seq[string], incoming: seq[string]) =
  for item in incoming:
    if item notin dest:
      dest.add(item)

# Flow: Parse one JSON string array field into a sequence of strings.
proc parseStringArray(node: JsonNode, key: string): seq[string] =
  if node.isNil or key notin node or node[key].kind != JArray:
    return @[]
  for item in node[key].items:
    if item.kind == JString:
      result.add(item.getStr)

# Flow: Merge overlay JSON into base JSON recursively for object keys.
proc mergeJson(baseNode, overlayNode: JsonNode): JsonNode =
  let baseObj = if baseNode.isNil or baseNode.kind != JObject: %*{} else: baseNode
  let overlayObj = if overlayNode.isNil or overlayNode.kind != JObject: %*{} else: overlayNode
  result = baseObj.copy()
  for key, value in overlayObj.pairs:
    if key in result and result[key].kind == JObject and value.kind == JObject:
      result[key] = mergeJson(result[key], value)
    else:
      result[key] = value

# Flow: Render scope path segments into canonical Cosmos scope text.
proc renderScope*(segments: seq[string]): string =
  if segments.len == 0:
    return "(" & CosmosScopeRoot & ")"
  "(" & CosmosScopeRoot & "." & segments.join(".") & ")"

# Flow: Resolve one input path into normalized scope segments.
proc resolveScope*(path: string, currentSegments: seq[string] = @[]): seq[string] =
  ## Resolve dot-separated semantic scope descendants under Cosmos.
  let raw = path.strip()
  if raw.len == 0:
    return currentSegments
  if raw == "/":
    return @[]
  if raw == "..":
    if currentSegments.len == 0:
      return @[]
    return currentSegments[0 ..< currentSegments.high]

  var normalized = raw
  if normalized.startsWith("(") and normalized.endsWith(")") and normalized.len > 1:
    normalized = normalized[1 ..< normalized.high]
  normalized = normalized.toLowerAscii()

  if normalized == CosmosScopeRoot:
    raise newException(ValueError,
      "scope: cannot cd into cosmos; session is already contained by cosmos")

  var absolute = false
  if normalized.startsWith(CosmosScopeRoot & "."):
    absolute = true
    normalized = normalized[(CosmosScopeRoot.len + 1) ..< normalized.len]

  let parts = normalized.split('.')
  var parsed: seq[string] = @[]
  for part in parts:
    let seg = part.strip()
    if seg.len == 0:
      raise newException(ValueError, "scope: empty segment is invalid")
    if seg == CosmosScopeRoot:
      raise newException(ValueError, "scope: nested cosmos segment is invalid")
    parsed.add(seg)

  if absolute:
    return parsed

  result = currentSegments
  result.add(parsed)

# Flow: Apply one layer of context overrides to a resolved context value.
proc applyOverrides*(context: Context, deltas: JsonNode): Context =
  ## Apply local contextual deltas and return a new context value.
  result = context
  if deltas.isNil or deltas.kind != JObject:
    return result

  result.mergedConfig = mergeJson(result.mergedConfig, deltas{"config"})
  result.mergedCapabilities.uniqueAppend(parseStringArray(deltas, "capabilities"))
  result.inheritedLogs.uniqueAppend(parseStringArray(deltas, "logs"))
  result.inheritedRelationships.uniqueAppend(parseStringArray(deltas, "relationships"))

# Flow: Resolve effective context by walking from root ancestor to target Thing.
proc resolveContext*(thingsById: Table[string, Thing], thingId: string): Context =
  ## Resolve downward-only context by walking ancestors from root to leaf.
  if thingId.len == 0:
    raise newException(ValueError, "context: thing id cannot be empty")
  if thingId notin thingsById:
    raise newException(ValueError, "context: unknown thing id: " & thingId)

  var ancestry: seq[Thing] = @[]
  var cursor = thingId
  var visited = initTable[string, bool]()

  while cursor.len > 0:
    if cursor in visited:
      raise newException(ValueError, "context: cycle detected at " & cursor)
    visited[cursor] = true
    if cursor notin thingsById:
      raise newException(ValueError, "context: unresolved parent chain at " & cursor)
    let thing = thingsById[cursor]
    ancestry.add(thing)
    cursor = thing.parentId

  ancestry.reverse()

  result = Context(
    mergedCapabilities: @[],
    mergedConfig: %*{},
    inheritedLogs: @[],
    inheritedRelationships: @[],
    children: thingsById[thingId].children
  )

  for thing in ancestry:
    result.mergedCapabilities.uniqueAppend(thing.capabilities)
    result.mergedConfig = mergeJson(result.mergedConfig, thing.config)
    result.inheritedLogs.uniqueAppend(parseStringArray(thing.metadata, "logs"))
    result.inheritedRelationships.uniqueAppend(parseStringArray(thing.metadata, "relationships"))
    result = applyOverrides(result, thing.overrideDeltas)

  # Flow: Resolve one reference entry to target context plus local metadata.
proc resolveReference*(referencesById: Table[string, Reference],
                       thingsById: Table[string, Thing],
                       refId: string): ResolvedReference =
  ## Resolve reference to canonical target context and attach local metadata.
  if refId.len == 0:
    raise newException(ValueError, "reference: id cannot be empty")
  if refId notin referencesById:
    raise newException(ValueError, "reference: unknown id: " & refId)

  let refEntry = referencesById[refId]
  if refEntry.targetId.len == 0:
    raise newException(ValueError, "reference: targetId cannot be empty")
  if refEntry.targetId notin thingsById:
    raise newException(ValueError, "reference: target Thing not found: " & refEntry.targetId)

  result = ResolvedReference(
    targetId: refEntry.targetId,
    context: resolveContext(thingsById, refEntry.targetId),
    localMetadata: if refEntry.localMetadata.isNil: %*{} else: refEntry.localMetadata
  )
