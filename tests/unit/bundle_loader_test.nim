# Wilder Cosmos 0.4.0
# Module name: Bundle Loader Test
# Module Path: tests/unit/bundle_loader_test.nim
# Summary: Unit tests for manifest-driven .cosmos bundle loading.
# Simile: Like checking parcels at the door — a good one is unpacked, a bad one
#   is turned away with a note saying why.
# Memory note: each test builds its bundle folder and removes it afterwards.
# Flow: write a bundle -> load it -> check status and message -> clean up.

import std/[os, strutils, json]
import runtime/bundle_loader
import runtime/core

# Flow: Create a bundle folder holding the given manifest.json text.
proc setupBundle(dir: string, manifestContent: string) =
  createDir(dir)
  writeFile(dir & "/manifest.json", manifestContent)

# Flow: Remove a bundle folder made by setupBundle.
proc teardownBundle(dir: string) =
  removeDir(dir)

# Flow: Load a well-formed bundle and check its manifest fields.
proc testLoadValidBundle() =
  let bundleDir = "test_valid.cosmos"
  let manifest = """
  {
    "id": "test-thing",
    "version": "1.0.0",
    "dependencies": [],
    "capabilities": ["cap.test"],
    "entryPoints": { "main": "src/main.nim" }
  }
  """
  setupBundle(bundleDir, manifest)
  try:
    let res = loadCosmosBundle(bundleDir)
    assert res.loadStatus == tlsLoaded
    assert res.manifest.id == "test-thing"
    assert res.manifest.version == "1.0.0"
    assert "cap.test" in res.manifest.capabilities
  finally:
    teardownBundle(bundleDir)

# Flow: Load a bundle with no manifest.json and check it is skipped.
proc testLoadMissingManifest() =
  let bundleDir = "test_no_manifest.cosmos"
  createDir(bundleDir)
  try:
    let res = loadCosmosBundle(bundleDir)
    assert res.loadStatus == tlsSkippedMalformed
    assert "manifest.json not found" in res.errorMsg
  finally:
    removeDir(bundleDir)

# Flow: Load a bundle with broken JSON and check it is skipped.
proc testLoadMalformedJson() =
  let bundleDir = "test_malformed.cosmos"
  setupBundle(bundleDir, "{ invalid json }")
  try:
    let res = loadCosmosBundle(bundleDir)
    assert res.loadStatus == tlsSkippedMalformed
    assert "parsing failed" in res.errorMsg
  finally:
    teardownBundle(bundleDir)

# Flow: Load a manifest with no id and check it is skipped.
proc testLoadMissingId() =
  let bundleDir = "test_no_id.cosmos"
  let manifest = """
  {
    "version": "1.0.0",
    "dependencies": [],
    "capabilities": [],
    "entryPoints": {}
  }
  """
  setupBundle(bundleDir, manifest)
  try:
    let res = loadCosmosBundle(bundleDir)
    assert res.loadStatus == tlsSkippedMalformed
    assert "'id' field is required" in res.errorMsg
  finally:
    teardownBundle(bundleDir)

# Flow: Run each bundle loader test in order.
proc main() =
  echo "Running Bundle Loader Tests..."
  testLoadValidBundle()
  echo "  [x] testLoadValidBundle"
  testLoadMissingManifest()
  echo "  [x] testLoadMissingManifest"
  testLoadMalformedJson()
  echo "  [x] testLoadMalformedJson"
  testLoadMissingId()
  echo "  [x] testLoadMissingId"
  echo "All Bundle Loader tests passed!"

when isMainModule:
  main()
