# Wilder Cosmos 0.4.0
# Module name: Bundle Loader
# Module Path: src/runtime/bundle_loader.nim
# Summary: Manifest-driven loading of .cosmos bundles.
# Simile: Like a shipping manifest — it describes exactly what's inside the package and how to install it.

import json
import std/[os, strutils, tables]
import runtime/core

type
  ThingManifest* = object
    id*: string
    entryPoints*: Table[string, string]
    capabilities*: seq[string]
    dependencies*: seq[string]
    version*: string

  BundleLoadResult* = object
    manifest*: ThingManifest
    loadStatus*: ThingLoadStatus
    errorMsg*: string
    location*: string

# Flow: Parse a manifest.json file into a ThingManifest object.
proc parseManifest(path: string): Result[ThingManifest, string] =
  if not fileExists(path):
    return err("manifest.json not found at " & path)
  
  try:
    let content = readFile(path)
    let node = parseJson(content)
    if node.kind != JObject:
      return err("manifest.json must be a JSON object")
    
    result = ThingManifest(
      id: node{"id"}.getStr(""),
      version: node{"version"}.getStr(""),
      dependencies: node{"dependencies"}.getArray().map(x => x.getStr()),
      capabilities: node{"capabilities"}.getArray().map(x => x.getStr()),
      entryPoints: node{"entryPoints"}.getObj().pairs.map(p => (p.key, p.val.getStr()))
    )
    
    if result.id.len == 0:
      return err("manifest.json: 'id' field is required")
  except CatchableError as e:
    return err("manifest.json parsing failed: " & e.msg)

# Flow: Load a .cosmos bundle (folder or archive).
proc loadCosmosBundle*(path: string): BundleLoadResult =
  let trimmedPath = path.strip
  if trimmedPath.len == 0:
    return BundleLoadResult(loadStatus: tlsSkippedMalformed, errorMsg: "empty path")

  # For now, we treat .cosmos as a directory. 
  # In a full implementation, this would handle zip/tar archives.
  let bundleDir = if trimmedPath.endsWith(".cosmos"):
                    trimmedPath.replace(".cosmos", "")
                  else:
                    trimmedPath

  if not dirExists(bundleDir):
    return BundleLoadResult(
      loadStatus: tlsSkippedMalformed, 
      errorMsg: "bundle directory not found: " & bundleDir
    )

  let manifestPath = bundleDir & "/manifest.json"
  case parseManifest(manifestPath):
  of err(msg):
    return BundleLoadResult(
      loadStatus: tlsSkippedMalformed,
      errorMsg: "manifest error: " & msg,
      location: manifestPath
    )
  of ok(manifest):
    return BundleLoadResult(
      manifest: manifest,
      loadStatus: tlsLoaded,
      location: bundleDir
    )

# Helper for mapping JSON arrays to strings
proc map[T, U](seq: seq[T], f: proc(T): U): seq[U] =
  result = @[]
  for x in seq:
    result.add(f(x))

# Helper for mapping JSON objects to tables
proc map[K, V](pairs: seq[tuple[K, JsonNode]], f: proc(K, JsonNode): tuple[K, V]) =
  # This is a simplified helper for the manifest parsing
  # In a real project, I'd use a more robust mapping utility