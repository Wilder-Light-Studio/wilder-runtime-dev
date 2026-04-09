# persistence — Three-Layer Bridge

> Source: `src/runtime/persistence.nim`

Three-layer bridge implementation with deterministic validation. Provides transaction management, layer reconciliation, snapshot export/import, and stream blob handling.

---

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `RuntimeLayer*` | `"runtime"` | Runtime state layer |
| `ModulesLayer*` | `"modules"` | Module state layer |
| `TxlogLayer*` | `"txlog"` | Transaction log layer |
| `SnapshotsLayer*` | `"snapshots"` | Snapshot storage layer |
| `RecordsLayer*` | `"records"` | Encrypted RECORD layer |
| `StreamChunkSize*` | `65536` | Default stream chunk size (64 KB) |

---

## Types

### `PersistenceBridge`

Base bridge type that carries shared transaction state.

```nim
PersistenceBridge* = ref object of RootObj
  epoch*: int64
  schemaVersion*: int
  origin*: string
  activeTransaction*: bool
  activeTransactionId*: string
  stagedWrites*: Table[string, JsonNode]
  rollbackCheckpoint*: Table[string, JsonNode]
```

### `InMemoryBridge`

In-memory bridge for tests.

```nim
InMemoryBridge* = ref object of PersistenceBridge
  runtimeLayer*: Table[string, JsonNode]
  modulesLayer*: Table[string, JsonNode]
  txlogLayer*: Table[string, JsonNode]
  snapshotsLayer*: Table[string, JsonNode]
  recordsLayer*: Table[string, JsonNode]
```

### `FileBridge`

File-backed bridge for production use.

```nim
FileBridge* = ref object of PersistenceBridge
  basePath*: string
```

### `PersistenceError`

```nim
PersistenceError* = object of CatchableError
```

### `RecordMigrationResult`

```nim
RecordMigrationResult* = object
  migratedCount*: int
  fromMode*: EncryptionMode
  toMode*: EncryptionMode
```

### `MigrationStep`

```nim
MigrationStep* = proc(payload: JsonNode): JsonNode
```

---

## Procedures

### Construction

```nim
proc newInMemoryBridge*(schemaVersion: int, origin: string): InMemoryBridge
proc newFileBridge*(basePath: string, schemaVersion: int, origin: string): FileBridge
```

### Envelope I/O

```nim
proc persistEnvelope*(bridge: PersistenceBridge, layer, key: string, env: JsonNode)
proc loadEnvelope*(bridge: PersistenceBridge, layer, key: string): JsonNode
proc deleteLayer*(bridge: PersistenceBridge, layer: string)
proc listLayerKeys*(bridge: PersistenceBridge, layer: string): seq[string]
```

### Transactions

```nim
proc beginTransaction*(bridge: PersistenceBridge): string
proc writeEnvelope*(bridge: PersistenceBridge, layer, key: string, payload: JsonNode)
proc readEnvelope*(bridge: PersistenceBridge, layer, key: string): JsonNode
proc commit*(bridge: PersistenceBridge): bool
proc rollback*(bridge: PersistenceBridge)
```

### Stream Blobs

```nim
proc writeStreamBlob*(bridge: PersistenceBridge, layer, key: string,
                       bytes: openArray[byte], chunkSize: int)
proc readStreamBlob*(bridge: PersistenceBridge, layer, key: string): seq[byte]
```

### Migration

```nim
proc migrateEnvelope*(bridge: PersistenceBridge, env: JsonNode,
                       targetSchemaVersion: int,
                       migrators: Table[int, MigrationStep]): JsonNode
```
Run an ordered migration chain with validation.

### Snapshots

```nim
proc snapshotAll*(bridge: PersistenceBridge): Table[string, JsonNode]
proc restoreSnapshot*(bridge: PersistenceBridge, snapshot: Table[string, JsonNode])
proc signSnapshot*(snapshotEnv: JsonNode, signingKey: string): string
proc exportSnapshot*(bridge: PersistenceBridge, snapshotId, signingKey: string): JsonNode
proc importSnapshot*(bridge: PersistenceBridge, snapshotEnv: JsonNode, signingKey: string)
```

### RECORD Layer

```nim
proc writeRecordEntry*(bridge: PersistenceBridge, key: string, payload: JsonNode,
                        encryptionMode: EncryptionMode, keyMaterial: string,
                        sequence: int, entryType, authorId, previousHash: string)
proc readRecordPayload*(bridge: PersistenceBridge, key: string,
                         encryptionMode: EncryptionMode, keyMaterial: string): JsonNode
proc summarizeRecordForOperator*(bridge: PersistenceBridge, key: string,
                                  encryptionMode: EncryptionMode): JsonNode
proc migrateRecordLayer*(bridge: PersistenceBridge,
                          fromMode, toMode: EncryptionMode,
                          fromKeyMaterial, toKeyMaterial: string,
                          allowDowngrade: bool): RecordMigrationResult
```

### Encryption Contract

```nim
proc extractRuntimeContract*(payload: JsonNode): JsonNode
proc mergeRuntimeContract*(payload: JsonNode, cfg: RuntimeConfig): JsonNode
```

### Reconciliation

```nim
proc reconcile*(bridge: PersistenceBridge): ReconcileResult
```
Reconcile three layers deterministically.
