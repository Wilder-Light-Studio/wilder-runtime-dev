# scanner — Semantic Source Scanner

> Source: `src/runtime/scanner.nim`

Deterministic semantic scanner for needs/wants/provides extraction from source code. Emits canonical Thing objects with scanner metadata without modifying source files.

---

## Types

### `ScanRelationships`

Inferred relationships from scanning.

```nim
ScanRelationships* = object
  needs*: seq[string]
  wants*: seq[string]
  provides*: seq[string]
  conflicts*: seq[string]
  before*: seq[string]
  after*: seq[string]
```

---

## Procedures

```nim
proc scanPath*(root: string): seq[Thing]
```
Scan a root path and emit Things with scanner metadata.

```nim
proc scanThingsJson*(root: string): JsonNode
```
Convert scanner output to a deterministic JSON array.

```nim
proc findCapabilityConflicts*(things: seq[Thing]): seq[string]
```
Extract sorted conflict entries from scanned Things.
