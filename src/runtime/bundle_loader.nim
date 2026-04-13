# Wilder Cosmos 0.4.0
# Module name: Bundle Loader
# Module Path: src/runtime/bundle_loader.nim
# Summary: Manifest-driven loading of .cosmos bundles.
# Simile: Like a shipping manifest — it describes exactly what's inside the package and how to install it.

import json
import std/[os, strutils, tables]
import runtime/core
import runtime/result

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
    
    var deps: seq[string] = @[]
    for x in node{"dependencies"}.getArray():
      deps.add(x.getStr())

    var caps: seq[string] = @[]
    for x in node{"capabilities"}.getArray():
      caps.add(x.getStr())

    var eps = initTable[string, string]()
    for k, v in node{"entryPoints"}.getObj():
      eps[k] = v.getStr()

    result = ThingManifest(
      id: node{"id"}.getStr(""),
      version: node{"version"}.getStr(""),
      dependencies: deps,
      capabilities: caps,
      entryPoints: eps
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

