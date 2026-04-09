# record-reconciliation — RECORD Copy Reconciliation

> Source: `src/runtime/record_reconciliation.nim`

Metadata-only reconciliation for sovereign encrypted RECORD copy sets. Compares chain evidence across three copies using structural metadata tuples without decrypting payloads.

---

## Types

### `RecordCopyStatus`

```nim
RecordCopyStatus* = enum
  rcHealthy
  rcChainBroken
  rcHashMismatch
  rcSequenceError
```

### `ReconciliationResult`

```nim
ReconciliationResult* = object
  status*: RecordCopyStatus
  description*: string
  healthyCount*: int
  brokenKeys*: seq[string]
```

### `ReconciliationError`

```nim
ReconciliationError* = object of CatchableError
```

---

## Procedures

```nim
proc reconcileTriumvirate*(copy1, copy2, copy3: seq[JsonNode]): ReconciliationResult
```
Validate three independent RECORD copies and report their reconciliation status.

```nim
proc extractMetadataTuple*(entry: JsonNode): tuple[...]
```
Extract the structural metadata tuple from a single entry.

```nim
proc allMetadataMatch*(tuple1, tuple2, tuple3: auto): bool
```
Check whether all three metadata tuples are identical.

```nim
proc formatReconciliationReport*(reconcResult: ReconciliationResult): string
```
Format the reconciliation result as a human-readable report.
