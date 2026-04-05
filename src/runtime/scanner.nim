# Wilder Cosmos 0.4.0
# Module name: scanner
# Module Path: src/runtime/scanner.nim
# Summary: Deterministic semantic scanner for needs/wants/provides extraction.
# Simile: Like a survey pass, it maps structural signals without changing the landscape.
# Memory note: scanner is pure introspection; it does not execute or mutate scanned files.
# Flow: discover files -> parse signals -> infer relationships -> emit Thing objects.

import std/[algorithm, os, sequtils, sets, strutils, tables, json]
import ../cosmos/thing/thing

type
  ScanRelationships* = object
    needs*: seq[string]
    wants*: seq[string]
    provides*: seq[string]
    conflicts*: seq[string]
    before*: seq[string]
    after*: seq[string]

# Flow: Sort and deduplicate inferred relationship arrays.
proc dedupSorted(values: seq[string]): seq[string] =
  var seen = initHashSet[string]()
  for value in values:
    let normalized = value.strip
    if normalized.len > 0 and normalized notin seen:
      seen.incl(normalized)
      result.add(normalized)
  result.sort(system.cmp[string])

# Flow: Parse import line into module references.
proc parseImportLine(line: string): seq[string] =
  let body = line.strip.substr("import ".len)
  for token in body.split(','):
    let normalized = token.strip
    if normalized.len > 0:
      result.add(normalized)

# Flow: Parse annotation-like line for one scanner key.
proc parseQuotedValue(line: string, marker: string): string =
  let idx = line.find(marker)
  if idx < 0:
    return ""
  let start = idx + marker.len
  let rest = line[start .. ^1]
  let endIdx = rest.find('"')
  if endIdx < 0:
    return ""
  rest[0 ..< endIdx].strip

# Flow: Parse one list-style comment relationship line.
proc parseCommentList(line: string, prefix: string): seq[string] =
  let trimmed = line.strip
  if not trimmed.startsWith(prefix):
    return @[]
  let payload = trimmed.substr(prefix.len)
  for token in payload.split(','):
    let normalized = token.strip
    if normalized.len > 0:
      result.add(normalized)

# Flow: Parse one Nim file into inferred relationship sets.
proc parseNimFile(filePath: string, root: string): Thing =
  let source = readFile(filePath)
  let relPath = relativePath(filePath, root).replace('\\', '/')

  var rel = ScanRelationships()
  for rawLine in source.splitLines():
    let line = rawLine.strip
    if line.startsWith("import "):
      rel.needs.add(parseImportLine(line))
      rel.after.add(parseImportLine(line))

    if line.startsWith("proc "):
      let head = line.substr("proc ".len)
      let paren = head.find('(')
      if paren > 0:
        var name = head[0 ..< paren].strip
        if name.endsWith("*"):
          name = name[0 .. ^2]
        if name.len > 0:
          rel.provides.add(name)

    let provideAnn = parseQuotedValue(line, "@provides(\"")
    if provideAnn.len > 0:
      rel.provides.add(provideAnn)

    let wantAnn = parseQuotedValue(line, "@wants(\"")
    if wantAnn.len > 0:
      rel.wants.add(wantAnn)

    rel.provides.add(parseCommentList(line, "## Provides:"))
    rel.wants.add(parseCommentList(line, "## Wants:"))
    rel.needs.add(parseCommentList(line, "## Needs:"))

  rel.needs = dedupSorted(rel.needs)
  rel.wants = dedupSorted(rel.wants)
  rel.provides = dedupSorted(rel.provides)
  rel.after = dedupSorted(rel.after)
  rel.before = @[]
  rel.conflicts = @[]

  createThing(
    thingId = "scan:" & relPath,
    conceptId = "scanner.semantic.nim",
    metadata = %*{
      "scannerVersion": "semantic-v1",
      "sourcePath": relPath,
      "needs": rel.needs,
      "wants": rel.wants,
      "provides": rel.provides,
      "conflicts": rel.conflicts,
      "before": rel.before,
      "after": rel.after
    }
  )

# Flow: Build before-relationships from after-relationships across Things.
proc applyBeforeAfterLinks(things: var seq[Thing]) =
  var providerByModule = initTable[string, seq[string]]()
  for thing in things:
    providerByModule[thing.metadata["sourcePath"].getStr] =
      thing.metadata["provides"].getElems.mapIt(it.getStr)

  var idxByPath = initTable[string, int]()
  for i, thing in things:
    idxByPath[thing.metadata["sourcePath"].getStr] = i

  for i in 0 ..< things.len:
    var beforeSet = initHashSet[string]()
    for dep in things[i].metadata["after"].getElems:
      let depName = dep.getStr
      if idxByPath.hasKey(depName):
        let depIndex = idxByPath[depName]
        let currentPath = things[i].metadata["sourcePath"].getStr
        var depBefore = things[depIndex].metadata["before"].getElems.mapIt(it.getStr)
        depBefore.add(currentPath)
        things[depIndex].metadata["before"] = %*dedupSorted(depBefore)
      beforeSet.incl(depName)
    things[i].metadata["before"] = %*dedupSorted(toSeq(beforeSet))

# Flow: Apply conflict detection for duplicate provide keys.
proc applyConflicts(things: var seq[Thing]) =
  var provideOwners = initTable[string, seq[string]]()
  for thing in things:
    let source = thing.metadata["sourcePath"].getStr
    for provide in thing.metadata["provides"].getElems:
      provideOwners.mgetOrPut(provide.getStr, @[]).add(source)

  for i in 0 ..< things.len:
    var conflicts: seq[string] = @[]
    let source = things[i].metadata["sourcePath"].getStr
    for provide in things[i].metadata["provides"].getElems:
      let owners = provideOwners.getOrDefault(provide.getStr)
      if owners.len > 1:
        for owner in owners:
          if owner != source:
            conflicts.add(provide.getStr & "@" & owner)
    things[i].metadata["conflicts"] = %*dedupSorted(conflicts)

# Flow: Scan a root path and emit canonical Thing objects with scanner metadata.
proc scanPath*(root: string): seq[Thing] =
  if root.strip.len == 0:
    raise newException(ValueError, "scanner: root path must not be empty")
  if not dirExists(root):
    raise newException(ValueError, "scanner: root path does not exist: " & root)

  var files: seq[string] = @[]
  for path in walkDirRec(root):
    if path.toLowerAscii.endsWith(".nim"):
      files.add(path)
  files.sort(system.cmp[string])

  for path in files:
    result.add(parseNimFile(path, root))

  result.sort(proc(a, b: Thing): int =
    system.cmp(a.metadata["sourcePath"].getStr, b.metadata["sourcePath"].getStr)
  )

  applyBeforeAfterLinks(result)
  applyConflicts(result)

# Flow: Convert scanner output into deterministic JSON array.
proc scanThingsJson*(root: string): JsonNode =
  var payload: seq[JsonNode] = @[]
  for thing in scanPath(root):
    payload.add(thingToJson(thing))
  %*payload

# Flow: Extract sorted conflict entries from scanned Things.
proc findCapabilityConflicts*(things: seq[Thing]): seq[string] =
  for thing in things:
    for conflict in thing.metadata["conflicts"].getElems:
      result.add(thing.metadata["sourcePath"].getStr & " -> " & conflict.getStr)
  result = dedupSorted(result)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
