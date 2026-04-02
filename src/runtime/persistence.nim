# Wilder Cosmos 0.4.0
# Module name: persistence
# Module Path: src/runtime/persistence.nim
#
# Wilder Cosmos 0.4.0
## Module: Persistence
## Purpose: Persistence is a safety net, like a lighthouse preserving state
## across storms while keeping integrity checks visible.
## Summary: Three-layer bridge implementation with deterministic validation.
## Notes: Non-Deterministic (ND) friendly messages and fail-fast behavior.

# Summary: Three-layer bridge implementation with deterministic validation.
# Simile: Persistence is a safety net, like a lighthouse preserving state across storms.
# Memory note: Non-Deterministic (ND) friendly messages and fail-fast behavior.
# Flow: validate requests -> persist to layers -> verify checksums -> report status.
## persistence.nim



import std/[json, tables, strutils, times, os, sequtils, algorithm, monotimes]
import validation
import api

const
  RuntimeLayer* = "runtime"
  ModulesLayer* = "modules"
  TxlogLayer* = "txlog"
  SnapshotsLayer* = "snapshots"
  StreamChunkSize* = 64 * 1024

type
  PersistenceError* = object of CatchableError

  MigrationStep* = proc(payload: JsonNode): JsonNode

  PersistenceBridge* = ref object of RootObj
    ## Shared bridge state for transaction and envelope metadata.
    epoch*: int64
    schemaVersion*: int
    origin*: string
    activeTransaction*: bool
    activeTransactionId*: string
    stagedWrites*: Table[string, JsonNode]
    rollbackCheckpoint*: Table[string, JsonNode]

  InMemoryBridge* = ref object of PersistenceBridge
    ## In-memory bridge used by tests.
    runtimeLayer*: Table[string, JsonNode]
    modulesLayer*: Table[string, JsonNode]
    txlogLayer*: Table[string, JsonNode]
    snapshotsLayer*: Table[string, JsonNode]

  FileBridge* = ref object of PersistenceBridge
    ## File-backed bridge used by runtime.
    basePath*: string

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateEnvelope*(env: JsonNode)

# Flow: Normalize and validate layer name for safety.
proc normalizeLayer(layer: string): string =
  result = layer.toLowerAscii.strip
  if result notin [RuntimeLayer, ModulesLayer, TxlogLayer, SnapshotsLayer]:
    raise newException(PersistenceError,
      "persistence: unsupported layer '" & layer & "'")

# Flow: Convert string to byte sequence.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

# Flow: Convert byte sequence back to string.
proc bytesToString(data: openArray[byte]): string =
  result = newString(data.len)
  for i in 0 ..< data.len:
    result[i] = char(data[i])

# Flow: Create independent copy of JSON object.
proc cloneJson(node: JsonNode): JsonNode =
  result = parseJson($node)

# Flow: Clone tables with deep copy of JSON values.
proc tableClone(src: Table[string, JsonNode]): Table[string, JsonNode] =
  result = initTable[string, JsonNode]()
  for k, v in src.pairs:
    result[k] = cloneJson(v)

# Flow: Create composite key from layer and key components.
proc composeKey(layer, key: string): string =
  result = normalizeLayer(layer) & ":" & key

# Flow: Split composite key into layer and key parts.
proc splitKey(composite: string): tuple[layer: string, key: string] =
  let idx = composite.find(':')
  if idx <= 0 or idx >= composite.len - 1:
    raise newException(PersistenceError,
      "persistence: invalid staged key")
  result.layer = composite[0 ..< idx]
  result.key = composite[idx + 1 .. ^1]

# Flow: Remove unsafe path characters from key for file safety.
proc sanitizeKey(key: string): string =
  result = key
  for c in ["/", "\\", ":", "..", " "]:
    result = result.replace(c, "_")
  if result.len == 0:
    result = "default"

# Flow: Compute directory path for persistence layer.
proc layerDir(basePath, layer: string): string =
  let stateRoot = basePath / "state"
  case normalizeLayer(layer)
  of RuntimeLayer:
    result = stateRoot
  of ModulesLayer:
    result = stateRoot / "modules"
  of TxlogLayer:
    result = stateRoot / "txlog"
  of SnapshotsLayer:
    result = stateRoot / "snapshots"
  else:
    raise newException(PersistenceError, "persistence: unsupported layer")

# Flow: Build deterministic txlog path for an epoch.
proc txlogPathForEpoch(bridge: FileBridge, epoch: int64): string =
  layerDir(bridge.basePath, TxlogLayer) / ($epoch & ".txlog")

# Flow: Build deterministic snapshot path for an epoch.
proc snapshotPathForEpoch(bridge: FileBridge, epoch: int64): string =
  layerDir(bridge.basePath, SnapshotsLayer) / ($epoch & "_snapshot.json")

# Flow: Write content through a temporary file and then replace the target file.
proc atomicWriteFile(path: string, content: string) =
  let parentDir = path.splitFile.dir
  if parentDir.len > 0 and not dirExists(parentDir):
    createDir(parentDir)

  let tmpPath = path & ".tmp"
  if fileExists(tmpPath):
    removeFile(tmpPath)

  writeFile(tmpPath, content)
  try:
    moveFile(tmpPath, path)
  except OSError:
    try:
      if fileExists(path):
        removeFile(path)
      moveFile(tmpPath, path)
    except OSError:
      raise newException(IOError,
        "atomicWriteFile: failed to write " & path & ": " & getCurrentExceptionMsg())

# Flow: Parse non-empty newline-delimited JSON records from a file.
proc parseNdjsonFile(path: string): seq[JsonNode] =
  if not fileExists(path):
    return @[]

  for line in readFile(path).splitLines:
    let trimmed = line.strip
    if trimmed.len == 0:
      continue
    try:
      result.add(parseJson(trimmed))
    except JsonParsingError:
      raise newException(PersistenceError,
        "persistence: invalid JSON envelope")

# Flow: Resolve stable key for persisted txlog or snapshot records.
proc persistedRecordKey(env: JsonNode): string =
  if env.kind != JObject:
    raise newException(PersistenceError,
      "persistence: persisted record must be object")
  if env.hasKey("recordKey") and env["recordKey"].kind == JString:
    return env["recordKey"].getStr()
  if env.hasKey("txId") and env["txId"].kind == JString:
    return env["txId"].getStr()
  raise newException(PersistenceError,
    "persistence: persisted record missing record key")

# Flow: Collect sorted file paths for a layer-specific glob pattern.
proc sortedLayerFiles(dir: string, pattern: string): seq[string] =
  if not dirExists(dir):
    return @[]
  for path in walkFiles(dir / pattern):
    result.add(path)
  result.sort(system.cmp[string])

# Flow: Append txlog record if transaction id has not already been stored.
proc appendTxlogEnvelope(bridge: FileBridge, key: string, env: JsonNode) =
  let txlogPath = txlogPathForEpoch(bridge, env["epoch"].getInt().int64)
  let txId = env["txId"].getStr()
  let existingEntries = parseNdjsonFile(txlogPath)
  for existing in existingEntries:
    if existing.hasKey("txId") and existing["txId"].kind == JString and
        existing["txId"].getStr() == txId:
      return

  var stored = cloneJson(env)
  stored["recordKey"] = %key

  var lines: seq[string] = @[]
  for existing in existingEntries:
    lines.add($existing)
  lines.add($stored)
  atomicWriteFile(txlogPath, lines.join("\n") & "\n")

# Flow: Find txlog entry by record key or transaction id.
proc loadTxlogEnvelope(bridge: FileBridge, key: string): JsonNode =
  let files = sortedLayerFiles(layerDir(bridge.basePath, TxlogLayer), "*.txlog")
  for path in files:
    for env in parseNdjsonFile(path):
      let recordKey = persistedRecordKey(env)
      let txId = if env.hasKey("txId") and env["txId"].kind == JString:
        env["txId"].getStr() else: ""
      if recordKey == key or txId == key:
        return env
  raise newException(PersistenceError,
    "persistence: key not found")

# Flow: List txlog record keys across all epoch files.
proc listTxlogKeys(bridge: FileBridge): seq[string] =
  let files = sortedLayerFiles(layerDir(bridge.basePath, TxlogLayer), "*.txlog")
  for path in files:
    for env in parseNdjsonFile(path):
      result.add(persistedRecordKey(env))
  result.sort(system.cmp[string])

# Flow: Load snapshot envelope by record key or epoch-derived filename.
proc loadSnapshotEnvelope(bridge: FileBridge, key: string): JsonNode =
  let files = sortedLayerFiles(layerDir(bridge.basePath, SnapshotsLayer), "*_snapshot.json")
  for path in files:
    let env = parseJson(readFile(path))
    let recordKey = if env.hasKey("recordKey") and env["recordKey"].kind == JString:
      env["recordKey"].getStr() else: path.splitFile.name
    if recordKey == key or path.splitFile.name == sanitizeKey(key):
      return env
  raise newException(PersistenceError,
    "persistence: key not found")

# Flow: List snapshot record keys across all snapshot files.
proc listSnapshotKeys(bridge: FileBridge): seq[string] =
  let files = sortedLayerFiles(layerDir(bridge.basePath, SnapshotsLayer), "*_snapshot.json")
  for path in files:
    let env = parseJson(readFile(path))
    if env.hasKey("recordKey") and env["recordKey"].kind == JString:
      result.add(env["recordKey"].getStr())
    else:
      result.add(path.splitFile.name)
  result.sort(system.cmp[string])

# Flow: Remove a path if it exists as either file or directory.
proc removePathIfExists(path: string) =
  if fileExists(path):
    removeFile(path)
  elif dirExists(path):
    removeDir(path)

# Flow: Stage a snapshot table into an isolated file-bridge root.
proc stageSnapshotState(bridge: FileBridge,
    snapshot: Table[string, JsonNode],
    stageRoot: string) =
  removePathIfExists(stageRoot)
  createDir(stageRoot)
  let stageStateRoot = stageRoot / "state"
  createDir(stageStateRoot)
  createDir(stageStateRoot / "modules")
  createDir(stageStateRoot / "txlog")
  createDir(stageStateRoot / "snapshots")
  var stageBridge = FileBridge(
    epoch: bridge.epoch,
    schemaVersion: bridge.schemaVersion,
    origin: bridge.origin,
    activeTransaction: false,
    activeTransactionId: "",
    stagedWrites: initTable[string, JsonNode](),
    rollbackCheckpoint: initTable[string, JsonNode](),
    basePath: stageRoot
  )
  stageBridge.epoch = bridge.epoch
  for k, env in snapshot.pairs:
    try:
      let parts = splitKey(k)
      validateEnvelope(env)
      case normalizeLayer(parts.layer)
      of RuntimeLayer:
        let runtimePath = layerDir(stageBridge.basePath, RuntimeLayer) / "runtime.json"
        atomicWriteFile(runtimePath, env.pretty)
      of ModulesLayer:
        let modulePath = layerDir(stageBridge.basePath, ModulesLayer) /
          (sanitizeKey(parts.key) & ".json")
        atomicWriteFile(modulePath, env.pretty)
      of TxlogLayer:
        appendTxlogEnvelope(stageBridge, parts.key, env)
      of SnapshotsLayer:
        var stored = cloneJson(env)
        stored["recordKey"] = %parts.key
        let snapshotPath = snapshotPathForEpoch(stageBridge,
          env["epoch"].getInt().int64)
        atomicWriteFile(snapshotPath, stored.pretty)
      else:
        raise newException(PersistenceError,
          "persistence: unsupported layer in staged snapshot")
    except ValueError:
      raise newException(PersistenceError,
        "persistence: invalid envelope in snapshot restore")

# Flow: Atomically replace the on-disk state tree with a staged snapshot tree.
proc replaceStateTreeAtomically(bridge: FileBridge,
    stageRoot: string) =
  let stateRoot = bridge.basePath / "state"
  let stagedStateRoot = stageRoot / "state"
  let backupRoot = bridge.basePath / ("state_backup_" & $ticks(getMonoTime()))

  if not dirExists(stagedStateRoot):
    raise newException(PersistenceError,
      "persistence: staged snapshot missing state tree")

  removePathIfExists(backupRoot)
  try:
    if dirExists(stateRoot):
      moveDir(stateRoot, backupRoot)
    moveDir(stagedStateRoot, stateRoot)
  except OSError:
    if not dirExists(stateRoot) and dirExists(backupRoot):
      moveDir(backupRoot, stateRoot)
    raise newException(PersistenceError,
      "persistence: restore failed during state tree replacement")

  removePathIfExists(backupRoot)
  removePathIfExists(stageRoot)

# Flow: Create all required directory structure for file bridge.
proc ensureFileBridgeLayout(bridge: FileBridge) =
  let stateRoot = bridge.basePath / "state"
  createDir(stateRoot)
  createDir(stateRoot / "modules")
  createDir(stateRoot / "txlog")
  createDir(stateRoot / "snapshots")

# Flow: Create timestamped envelope wrapping payload with checksum.
proc envelopeFor(bridge: PersistenceBridge,
    payload: JsonNode,
    epoch: int64,
    txId: string): JsonNode =
  let payloadChecksum = computeSha256(toBytes($payload))
  let ts = now().utc().format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  result = %*{
    "schemaVersion": bridge.schemaVersion,
    "epoch": epoch,
    "checksum": payloadChecksum,
    "origin": bridge.origin,
    "txId": txId,
    "timestamp": ts,
    "payload": payload
  }

# Flow: Validate envelope structure and verify payload checksum.
proc validateEnvelope*(env: JsonNode) =
  discard validateStructure(env,
    @["schemaVersion", "epoch", "checksum", "origin", "payload"])
  if env["schemaVersion"].kind != JInt:
    raise newException(PersistenceError,
      "persistence: schemaVersion must be int")
  if env["epoch"].kind != JInt:
    raise newException(PersistenceError,
      "persistence: epoch must be int")
  if env["checksum"].kind != JString:
    raise newException(PersistenceError,
      "persistence: checksum must be string")
  if env["origin"].kind != JString:
    raise newException(PersistenceError,
      "persistence: origin must be string")

  let payloadChecksum = env["checksum"].getStr()
  discard validateChecksum(toBytes($(env["payload"])), payloadChecksum)

# Flow: Extract and return payload from validated envelope.
proc unwrapEnvelope*(env: JsonNode): JsonNode =
  validateEnvelope(env)
  result = cloneJson(env["payload"])

method persistEnvelope*(bridge: PersistenceBridge,
    layer: string,
    key: string,
    env: JsonNode) {.base.} =
  raise newException(PersistenceError,
    "persistEnvelope must be implemented by bridge")

method loadEnvelope*(bridge: PersistenceBridge,
    layer: string,
    key: string): JsonNode {.base.} =
  raise newException(PersistenceError,
    "loadEnvelope must be implemented by bridge")

method deleteLayer*(bridge: PersistenceBridge,
    layer: string) {.base.} =
  raise newException(PersistenceError,
    "deleteLayer must be implemented by bridge")

method listLayerKeys*(bridge: PersistenceBridge,
    layer: string): seq[string] {.base.} =
  raise newException(PersistenceError,
    "listLayerKeys must be implemented by bridge")

method snapshotAll*(bridge: PersistenceBridge):
  Table[string, JsonNode] {.base.} =
  raise newException(PersistenceError,
    "snapshotAll must be implemented by bridge")

method restoreSnapshot*(bridge: PersistenceBridge,
    snapshot: Table[string, JsonNode]) {.base.} =
  raise newException(PersistenceError,
    "restoreSnapshot must be implemented by bridge")
# Flow: Create and initialize new in-memory persistence bridge.
proc newInMemoryBridge*(schemaVersion: int = 1,
    origin: string = "runtime"): InMemoryBridge =
  if schemaVersion <= 0:
    raise newException(PersistenceError,
      "persistence: schemaVersion must be positive")
  result = InMemoryBridge(
    epoch: 0,
    schemaVersion: schemaVersion,
    origin: origin,
    activeTransaction: false,
    activeTransactionId: "",
    stagedWrites: initTable[string, JsonNode](),
    rollbackCheckpoint: initTable[string, JsonNode](),
    runtimeLayer: initTable[string, JsonNode](),
    modulesLayer: initTable[string, JsonNode](),
    txlogLayer: initTable[string, JsonNode](),
    snapshotsLayer: initTable[string, JsonNode]()
  )

# Flow: Create and initialize new file-backed persistence bridge.
proc newFileBridge*(basePath: string,
    schemaVersion: int = 1,
    origin: string = "runtime"): FileBridge =
  if schemaVersion <= 0:
    raise newException(PersistenceError,
      "persistence: schemaVersion must be positive")
  if basePath.len == 0:
    raise newException(PersistenceError,
      "persistence: basePath cannot be empty")
  result = FileBridge(
    epoch: 0,
    schemaVersion: schemaVersion,
    origin: origin,
    activeTransaction: false,
    activeTransactionId: "",
    stagedWrites: initTable[string, JsonNode](),
    rollbackCheckpoint: initTable[string, JsonNode](),
    basePath: basePath
  )
  ensureFileBridgeLayout(result)

# Flow: Persist validated envelope to specified layer and key in memory bridge.
method persistEnvelope*(bridge: InMemoryBridge,
    layer: string,
    key: string,
    env: JsonNode) =
  validateEnvelope(env)
  case normalizeLayer(layer)
  of RuntimeLayer:
    bridge.runtimeLayer[key] = cloneJson(env)
  of ModulesLayer:
    bridge.modulesLayer[key] = cloneJson(env)
  of TxlogLayer:
    bridge.txlogLayer[key] = cloneJson(env)
  of SnapshotsLayer:
    bridge.snapshotsLayer[key] = cloneJson(env)
  else:
    raise newException(PersistenceError,
      "persistence: unsupported in-memory layer")

method loadEnvelope*(bridge: InMemoryBridge,
    layer: string,
    key: string): JsonNode =
  case normalizeLayer(layer)
  of RuntimeLayer:
    if key notin bridge.runtimeLayer:
      raise newException(PersistenceError, "persistence: key not found")
    result = cloneJson(bridge.runtimeLayer[key])
  of ModulesLayer:
    if key notin bridge.modulesLayer:
      raise newException(PersistenceError, "persistence: key not found")
    result = cloneJson(bridge.modulesLayer[key])
  of TxlogLayer:
    if key notin bridge.txlogLayer:
      raise newException(PersistenceError, "persistence: key not found")
    result = cloneJson(bridge.txlogLayer[key])
  of SnapshotsLayer:
    if key notin bridge.snapshotsLayer:
      raise newException(PersistenceError, "persistence: key not found")
    result = cloneJson(bridge.snapshotsLayer[key])
  else:
    raise newException(PersistenceError,
      "persistence: unsupported in-memory layer")

method deleteLayer*(bridge: InMemoryBridge,
    layer: string) =
  case normalizeLayer(layer)
  of RuntimeLayer:
    bridge.runtimeLayer.clear()
  of ModulesLayer:
    bridge.modulesLayer.clear()
  of TxlogLayer:
    bridge.txlogLayer.clear()
  of SnapshotsLayer:
    bridge.snapshotsLayer.clear()
  else:
    raise newException(PersistenceError,
      "persistence: unsupported in-memory layer")

method listLayerKeys*(bridge: InMemoryBridge,
    layer: string): seq[string] =
  case normalizeLayer(layer)
  of RuntimeLayer:
    for k in bridge.runtimeLayer.keys:
      result.add(k)
  of ModulesLayer:
    for k in bridge.modulesLayer.keys:
      result.add(k)
  of TxlogLayer:
    for k in bridge.txlogLayer.keys:
      result.add(k)
  of SnapshotsLayer:
    for k in bridge.snapshotsLayer.keys:
      result.add(k)
  else:
    raise newException(PersistenceError,
      "persistence: unsupported in-memory layer")
  result.sort(system.cmp[string])

method snapshotAll*(bridge: InMemoryBridge): Table[string, JsonNode] =
  result = initTable[string, JsonNode]()
  for k, v in bridge.runtimeLayer.pairs:
    result[composeKey(RuntimeLayer, k)] = cloneJson(v)
  for k, v in bridge.modulesLayer.pairs:
    result[composeKey(ModulesLayer, k)] = cloneJson(v)
  for k, v in bridge.txlogLayer.pairs:
    result[composeKey(TxlogLayer, k)] = cloneJson(v)
  for k, v in bridge.snapshotsLayer.pairs:
    result[composeKey(SnapshotsLayer, k)] = cloneJson(v)

method restoreSnapshot*(bridge: InMemoryBridge,
    snapshot: Table[string, JsonNode]) =
  bridge.runtimeLayer.clear()
  bridge.modulesLayer.clear()
  bridge.txlogLayer.clear()
  bridge.snapshotsLayer.clear()
  for k, v in snapshot.pairs:
    let parts = splitKey(k)
    case normalizeLayer(parts.layer)
    of RuntimeLayer:
      bridge.runtimeLayer[parts.key] = cloneJson(v)
    of ModulesLayer:
      bridge.modulesLayer[parts.key] = cloneJson(v)
    of TxlogLayer:
      bridge.txlogLayer[parts.key] = cloneJson(v)
    of SnapshotsLayer:
      bridge.snapshotsLayer[parts.key] = cloneJson(v)
    else:
      raise newException(PersistenceError,
        "persistence: unsupported in-memory layer")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc filePathFor(bridge: FileBridge,
    layer: string,
    key: string): string =
  let normalized = normalizeLayer(layer)
  let safe = sanitizeKey(key)
  case normalized
  of RuntimeLayer:
    if key != "runtime":
      raise newException(PersistenceError,
        "persistence: runtime layer only supports key 'runtime', got '" & key & "'")
    result = layerDir(bridge.basePath, RuntimeLayer) / "runtime.json"
  of ModulesLayer:
    result = layerDir(bridge.basePath, ModulesLayer) / (safe & ".json")
  of TxlogLayer:
    result = txlogPathForEpoch(bridge, bridge.epoch)
  of SnapshotsLayer:
    result = snapshotPathForEpoch(bridge, bridge.epoch)
  else:
    raise newException(PersistenceError, "persistence: unsupported file layer")

method persistEnvelope*(bridge: FileBridge,
    layer: string,
    key: string,
    env: JsonNode) =
  ensureFileBridgeLayout(bridge)
  validateEnvelope(env)
  case normalizeLayer(layer)
  of TxlogLayer:
    appendTxlogEnvelope(bridge, key, env)
  of SnapshotsLayer:
    var stored = cloneJson(env)
    stored["recordKey"] = %key
    let path = snapshotPathForEpoch(bridge, env["epoch"].getInt().int64)
    atomicWriteFile(path, stored.pretty)
  else:
    let path = bridge.filePathFor(layer, key)
    atomicWriteFile(path, env.pretty)

method loadEnvelope*(bridge: FileBridge,
    layer: string,
    key: string): JsonNode =
  case normalizeLayer(layer)
  of TxlogLayer:
    result = loadTxlogEnvelope(bridge, key)
  of SnapshotsLayer:
    result = loadSnapshotEnvelope(bridge, key)
  else:
    let path = bridge.filePathFor(layer, key)
    if not fileExists(path):
      raise newException(PersistenceError,
        "persistence: key not found")
    try:
      result = parseJson(readFile(path))
    except JsonParsingError:
      raise newException(PersistenceError,
        "persistence: invalid JSON envelope")
  validateEnvelope(result)

method deleteLayer*(bridge: FileBridge,
    layer: string) =
  let normalized = normalizeLayer(layer)
  if normalized == RuntimeLayer:
    let runtimePath = bridge.filePathFor(RuntimeLayer, "runtime")
    if fileExists(runtimePath):
      removeFile(runtimePath)
    return

  let dir = layerDir(bridge.basePath, normalized)
  if dirExists(dir):
    removeDir(dir)
  createDir(dir)

method listLayerKeys*(bridge: FileBridge,
    layer: string): seq[string] =
  let normalized = normalizeLayer(layer)
  if normalized == RuntimeLayer:
    if fileExists(bridge.filePathFor(RuntimeLayer, "runtime")):
      result.add("runtime")
    return

  if normalized == TxlogLayer:
    return listTxlogKeys(bridge)

  if normalized == SnapshotsLayer:
    return listSnapshotKeys(bridge)

  let dir = layerDir(bridge.basePath, normalized)
  if not dirExists(dir):
    return
  for path in walkFiles(dir / "*.json"):
    result.add(path.splitFile.name)
  result.sort(system.cmp[string])

method snapshotAll*(bridge: FileBridge): Table[string, JsonNode] =
  result = initTable[string, JsonNode]()
  if fileExists(bridge.filePathFor(RuntimeLayer, "runtime")):
    let runtimeEnv = bridge.loadEnvelope(RuntimeLayer, "runtime")
    result[composeKey(RuntimeLayer, "runtime")] = cloneJson(runtimeEnv)

  for layer in [ModulesLayer, TxlogLayer, SnapshotsLayer]:
    for key in bridge.listLayerKeys(layer):
      let loadedEnv = bridge.loadEnvelope(layer, key)
      result[composeKey(layer, key)] = cloneJson(loadedEnv)

method restoreSnapshot*(bridge: FileBridge,
    snapshot: Table[string, JsonNode]) =
  ensureFileBridgeLayout(bridge)
  let stageRoot = bridge.basePath / ("restore_stage_" & $ticks(getMonoTime()))
  try:
    bridge.stageSnapshotState(snapshot, stageRoot)
    bridge.replaceStateTreeAtomically(stageRoot)
  except CatchableError:
    removePathIfExists(stageRoot)
    raise

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc nextTxId(bridge: PersistenceBridge): string =
  "tx-" & $(bridge.epoch + 1) & "-" & $ticks(getMonoTime())

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc beginTransaction*(bridge: PersistenceBridge): string =
  ## Begin a transaction mutation context.
  if bridge.activeTransaction:
    raise newException(PersistenceError,
      "persistence: transaction already active")
  bridge.activeTransaction = true
  bridge.activeTransactionId = nextTxId(bridge)
  bridge.rollbackCheckpoint = tableClone(bridge.snapshotAll())
  bridge.stagedWrites.clear()
  result = bridge.activeTransactionId

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc writeEnvelope*(bridge: PersistenceBridge,
    layer: string,
    key: string,
    payload: JsonNode) =
  ## Stage envelope write in active transaction.
  if not bridge.activeTransaction:
    raise newException(PersistenceError,
      "persistence: write requires active transaction")
  let env = envelopeFor(bridge,
    cloneJson(payload),
    bridge.epoch + 1,
    bridge.activeTransactionId)
  bridge.stagedWrites[composeKey(layer, key)] = env

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc readEnvelope*(bridge: PersistenceBridge,
    layer: string,
    key: string): JsonNode =
  ## Read and validate envelope payload, fail-fast on checksum errors.
  let env = bridge.loadEnvelope(layer, key)
  result = unwrapEnvelope(env)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc commit*(bridge: PersistenceBridge): bool =
  ## Commit staged changes atomically with post-commit invariant checks.
  if not bridge.activeTransaction:
    raise newException(PersistenceError,
      "persistence: no active transaction")

  let checkpoint = tableClone(bridge.rollbackCheckpoint)
  try:
    for composite, env in bridge.stagedWrites.pairs:
      let parts = splitKey(composite)
      bridge.persistEnvelope(parts.layer, parts.key, env)

    # Fail-fast invariant check: read each staged write and validate envelope.
    for composite, _ in bridge.stagedWrites.pairs:
      let parts = splitKey(composite)
      discard bridge.readEnvelope(parts.layer, parts.key)

    bridge.epoch = bridge.epoch + 1
    bridge.activeTransaction = false
    bridge.activeTransactionId = ""
    bridge.stagedWrites.clear()
    bridge.rollbackCheckpoint.clear()
    result = true
  except CatchableError:
    bridge.restoreSnapshot(checkpoint)
    bridge.activeTransaction = false
    bridge.activeTransactionId = ""
    bridge.stagedWrites.clear()
    bridge.rollbackCheckpoint.clear()
    raise newException(PersistenceError,
      "persistence: commit failed; rollback applied")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc rollback*(bridge: PersistenceBridge) =
  ## Roll back active transaction and restore prior consistent state.
  if not bridge.activeTransaction:
    return
  bridge.restoreSnapshot(bridge.rollbackCheckpoint)
  bridge.activeTransaction = false
  bridge.activeTransactionId = ""
  bridge.stagedWrites.clear()
  bridge.rollbackCheckpoint.clear()

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc writeStreamBlob*(bridge: PersistenceBridge,
    layer: string,
    key: string,
    bytes: openArray[byte],
    chunkSize: int = StreamChunkSize) =
  ## Stage large payload write as deterministic chunks.
  ## Note: this stages the write; call readStreamBlob only after commit.
  if chunkSize <= 0:
    raise newException(PersistenceError,
      "persistence: chunkSize must be positive")
  var chunks = newJArray()
  var offset = 0
  while offset < bytes.len:
    let n = min(chunkSize, bytes.len - offset)
    let chunkText = bytesToString(bytes.toSeq[offset ..< offset + n])
    chunks.add(%*{
      "offset": offset,
      "length": n,
      "data": chunkText
    })
    offset += n

  let payload = %*{
    "byteLength": bytes.len,
    "chunkSize": chunkSize,
    "chunks": chunks
  }
  bridge.writeEnvelope(layer, key, payload)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc readStreamBlob*(bridge: PersistenceBridge,
    layer: string,
    key: string): seq[byte] =
  ## Read blob payload and reconstruct bytes using stored chunk offsets.
  ## Note: reads from committed storage; call only after commit of writeStreamBlob.
  let payload = bridge.readEnvelope(layer, key)
  discard validateStructure(payload, @["byteLength", "chunkSize", "chunks"])
  if payload["chunks"].kind != JArray:
    raise newException(PersistenceError,
      "persistence: stream payload chunks must be array")
  let totalBytes = payload["byteLength"].getInt
  result = newSeq[byte](totalBytes)
  for ch in payload["chunks"].items:
    discard validateStructure(ch, @["offset", "length", "data"])
    let offset = ch["offset"].getInt
    let length = ch["length"].getInt
    let data = ch["data"].getStr()
    if offset < 0 or length < 0 or offset + length > totalBytes:
      raise newException(PersistenceError,
        "persistence: stream chunk bounds out of range")
    let part = toBytes(data)
    if part.len != length:
      raise newException(PersistenceError,
        "persistence: stream chunk data length mismatch")
    for i in 0 ..< length:
      result[offset + i] = part[i]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc migrateEnvelope*(bridge: PersistenceBridge,
    env: JsonNode,
    targetSchemaVersion: int,
    migrators: Table[int, MigrationStep]): JsonNode =
  ## Run ordered migration chain with pre/post checksum validation.
  validateEnvelope(env)
  if targetSchemaVersion < env["schemaVersion"].getInt:
    raise newException(PersistenceError,
      "persistence: target schema lower than source schema")

  var currentSchema = env["schemaVersion"].getInt
  var payload = unwrapEnvelope(env)
  while currentSchema < targetSchemaVersion:
    if currentSchema notin migrators:
      raise newException(PersistenceError,
        "persistence: missing migration step")
    let nextPayload = migrators[currentSchema](payload)
    payload = cloneJson(nextPayload)
    currentSchema += 1

  # Validate transformed payload by building a fresh checksum envelope.
  let payloadChecksum = computeSha256(toBytes($payload))
  result = %*{
    "schemaVersion": targetSchemaVersion,
    "epoch": env["epoch"],
    "checksum": payloadChecksum,
    "origin": bridge.origin,
    "payload": payload
  }
  validateEnvelope(result)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc hmacSha256(key: string, message: string): string =
  ## Compute HMAC-SHA256(key, message) — prevents length-extension attacks.
  const blockSize = 64
  var kBytes: seq[byte]
  let rawKey = toBytes(key)
  if rawKey.len > blockSize:
    let hk = computeSha256(rawKey)
    kBytes = newSeq[byte](32)
    for i in 0 ..< 32:
      kBytes[i] = byte(parseHexInt(hk[i * 2 .. i * 2 + 1]))
  else:
    kBytes = rawKey
  kBytes.setLen(blockSize)
  var innerInput = newSeq[byte](blockSize + message.len)
  var outerInput = newSeq[byte](blockSize + 32)
  for i in 0 ..< blockSize:
    innerInput[i] = kBytes[i] xor 0x36'u8
    outerInput[i] = kBytes[i] xor 0x5C'u8
  let msgBytes = toBytes(message)
  for i in 0 ..< msgBytes.len:
    innerInput[blockSize + i] = msgBytes[i]
  let innerHash = computeSha256(innerInput)
  for i in 0 ..< 32:
    outerInput[blockSize + i] = byte(parseHexInt(innerHash[i * 2 .. i * 2 + 1]))
  result = computeSha256(outerInput)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc signSnapshot(snapshotEnv: JsonNode,
    signingKey: string): string =
  if signingKey.len == 0:
    raise newException(PersistenceError,
      "persistence: signingKey must not be empty for snapshot signing")
  let payload = snapshotEnv["payload"]
  hmacSha256(signingKey, $payload)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc exportSnapshot*(bridge: PersistenceBridge,
    snapshotId: string,
    signingKey: string): JsonNode =
  ## Export full bridge state as signed, checksummed snapshot envelope.
  let snapshot = bridge.snapshotAll()
  var items = newJObject()
  for k, env in snapshot.pairs:
    items[k] = cloneJson(env)
  let payload = %*{
    "snapshotId": snapshotId,
    "epoch": bridge.epoch,
    "entries": items
  }
  var env = envelopeFor(bridge, payload, bridge.epoch, "snapshot-export")
  env["signature"] = %signSnapshot(env, signingKey)
  result = env

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc importSnapshot*(bridge: PersistenceBridge,
    snapshotEnv: JsonNode,
    signingKey: string) =
  ## Import validated snapshot with signature and checksum checks.
  if signingKey.len == 0:
    raise newException(PersistenceError,
      "persistence: signingKey must not be empty for snapshot import")
  validateEnvelope(snapshotEnv)
  discard validateStructure(snapshotEnv,
    @["schemaVersion", "epoch", "checksum", "origin", "payload", "signature"])

  let expected = signSnapshot(snapshotEnv, signingKey)
  let actual = snapshotEnv["signature"].getStr()
  if actual != expected:
    raise newException(PersistenceError,
      "persistence: snapshot signature verification failed")

  let payload = unwrapEnvelope(snapshotEnv)
  discard validateStructure(payload, @["snapshotId", "epoch", "entries"])
  if payload["entries"].kind != JObject:
    raise newException(PersistenceError,
      "persistence: snapshot entries must be object")

  var snapshot = initTable[string, JsonNode]()
  for k, env in payload["entries"]:
    snapshot[k] = cloneJson(env)
  bridge.restoreSnapshot(snapshot)
  bridge.epoch = payload["epoch"].getInt.int64

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc layerHealthy(bridge: PersistenceBridge,
    layer: string): bool =
  try:
    let normalized = normalizeLayer(layer)
    let keys = bridge.listLayerKeys(normalized)
    if normalized == RuntimeLayer:
      if keys.len == 0:
        return false
      discard bridge.readEnvelope(RuntimeLayer, "runtime")
      return true

    for k in keys:
      discard bridge.readEnvelope(normalized, k)
    result = true
  except CatchableError:
    result = false

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc reconcile*(bridge: PersistenceBridge): ReconcileResult =
  ## Reconcile three layers using deterministic majority validity decisions.
  let runtimeOk = layerHealthy(bridge, RuntimeLayer)
  let modulesOk = layerHealthy(bridge, ModulesLayer)
  let txlogOk = layerHealthy(bridge, TxlogLayer)

  result.success = false
  result.layersUsed = @[]
  result.messages = @[]

  if runtimeOk: result.layersUsed.add(RuntimeLayer)
  if modulesOk: result.layersUsed.add(ModulesLayer)
  if txlogOk: result.layersUsed.add(TxlogLayer)

  if result.layersUsed.len == 3:
    result.success = true
    result.messages.add("reconcile: all layers healthy")
    return

  if result.layersUsed.len < 2:
    result.messages.add("reconcile: insufficient healthy layers for recovery")
    return

  discard beginTransaction(bridge)
  try:
    if not runtimeOk:
      let repairPayload = %*{
        "status": "recovered",
        "sourceLayers": result.layersUsed,
        "epoch": bridge.epoch
      }
      bridge.writeEnvelope(RuntimeLayer, "runtime", repairPayload)
      result.messages.add(
        "reconcile: runtime rebuilt from remaining healthy layers"
      )

    if not modulesOk:
      bridge.deleteLayer(ModulesLayer)
      result.messages.add("reconcile: modules layer reset")

    if not txlogOk:
      let txRecovery = %*{
        "event": "recovered-txlog",
        "sourceLayers": result.layersUsed,
        "epoch": bridge.epoch
      }
      bridge.writeEnvelope(TxlogLayer, "recovery-" & $bridge.epoch, txRecovery)
      result.messages.add("reconcile: txlog rebuilt with recovery marker")

    discard commit(bridge)
  except CatchableError:
    rollback(bridge)
    raise

  result.success = true


# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
