# ontology — Scope, Context & References

> Source: `src/runtime/ontology.nim`

Deterministic scope, context, override, and reference resolution. Resolves downward-only context by walking ancestors and manages semantic scope paths under Cosmos.

---

## Constants

| Constant | Value |
|----------|-------|
| `CosmosScopeRoot*` | `"cosmos"` |

---

## Types

### `Reference`

Canonical reference record pointing to a target Thing.

```nim
Reference* = object
  targetId*: string
  localMetadata*: JsonNode
```

### `Context`

Resolved downward context for a Thing, built by walking ancestors.

```nim
Context* = object
  mergedCapabilities*: seq[string]
  mergedConfig*: JsonNode
  inheritedLogs*: seq[string]
  inheritedRelationships*: seq[string]
  children*: seq[string]
```

### `ResolvedReference`

Canonical target context plus per-reference metadata.

```nim
ResolvedReference* = object
  targetId*: string
  context*: Context
  localMetadata*: JsonNode
```

---

## Procedures

### Scope

```nim
proc renderScope*(segments: seq[string]): string
```
Render scope segments as a canonical dot-separated semantic scope string (e.g. `cosmos.things.counter`).

```nim
proc resolveScope*(path: string, currentSegments: seq[string]): seq[string]
```
Resolve dot-separated scope descendants relative to current segments.

### Context

```nim
proc resolveContext*(thingsById: Table[string, Thing],
                      thingId: string): Context
```
Resolve downward-only context by walking from Thing to its ancestors.

```nim
proc applyOverrides*(context: Context, deltas: JsonNode): Context
```
Apply local contextual deltas to a resolved context.

### References

```nim
proc resolveReference*(referencesById: Table[string, Reference],
                        thingsById: Table[string, Thing],
                        refId: string): ResolvedReference
```
Resolve a reference to its canonical target context plus metadata.
