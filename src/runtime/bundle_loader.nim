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
proc parseManifest(path: string): Result[ThingManifest] =
  if not fileExists(path):
    return err[ThingManifest]("manifest.json not found at " & path)
  
  try:
    let content = readFile(path)
    let node = parseJson(content)
    if node.kind != JObject:
      return err[ThingManifest]("manifest.json must be a JSON object")
    
    var deps: seq[string] = @[]
    if node.hasKey("dependencies") and node["dependencies"].kind == JArray:
      for x in node["dependencies"]:
        deps.add(x.getStr())

    var caps: seq[string] = @[]
    if node.hasKey("capabilities") and node["capabilities"].kind == JArray:
      for x in node["capabilities"]:
        caps.add(x.getStr())

    var eps = initTable[string, string]()
    if node.hasKey("entryPoints") and node["entryPoints"].kind == JObject:
      for k, v in node["entryPoints"].pairs:
        eps[k] = v.getStr()

    result = ThingManifest(
      id: node{"id"}.getStr(""),
      version: node{"version"}.getStr(""),
      dependencies: deps,
      capabilities: caps,
      entryPoints: eps
    )
    
    if result.id.len == 0:
      return err[ThingManifest]("manifest.json: 'id' field is required")
  except CatchableError as e:
    return err[ThingManifest]("manifest.json parsing failed: " & e.msg)

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

