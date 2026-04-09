# concepts — Concept Registry

> Source: `src/runtime/concepts.nim`

In-memory Concept registry with effective-source resolution. Programmatic Concepts override manual Concepts when both exist, preserving both sources while picking one effective contract.

---

## Constants

| Constant | Value |
|----------|-------|
| `ConceptAbiVersion*` | `"concept-abi-v1"` |

---

## Types

### `ConceptSourceKind`

```nim
ConceptSourceKind* = enum
  cskProgrammatic   ## Derived from code
  cskManual          ## Hand-authored
```

### `RegisteredConcept`

```nim
RegisteredConcept* = object
  conceptId*: string
  sourceKind*: ConceptSourceKind
  schemaVersion*: int
  derivedFrom*: string
  conceptDef*: Concept
```

### `ConceptRegistry`

```nim
ConceptRegistry* = ref object
  entries*: Table[string, seq[RegisteredConcept]]
```

---

## Procedures

### Registry Lifecycle

```nim
proc newConceptRegistry*(): ConceptRegistry
```

### Registration

```nim
proc registerProgrammaticConcept*(reg: ConceptRegistry, conceptDef: Concept,
                                   schemaVersion: int, derivedFrom: string)
proc registerManualConcept*(reg: ConceptRegistry, conceptDef: Concept,
                             schemaVersion: int, derivedFrom: string)
proc registerConceptFromBoundaryDeclarations*(
    reg: ConceptRegistry, thingName: string,
    provides: seq[ProvideDeclaration], wants: seq[WantDeclaration],
    moduleBindings: seq[ModuleBindingDeclaration],
    schemaVersion: int, derivedFrom: string)
```

### Query

```nim
proc hasConcept*(reg: ConceptRegistry, conceptId: string): bool
proc hasConflict*(reg: ConceptRegistry, conceptId: string): bool
proc listConceptIds*(reg: ConceptRegistry): seq[string]
```
`listConceptIds` returns IDs in deterministic sorted order.

### Resolution

```nim
proc resolveEffectiveConcept*(reg: ConceptRegistry,
                               conceptId: string): RegisteredConcept
```
Resolve the effective Concept by precedence (programmatic wins over manual).

```nim
proc exportEffectiveConcept*(reg: ConceptRegistry,
                              conceptId: string): JsonNode
```
Build a deterministic ABI payload for the effective Concept.

```nim
proc conceptRegistryRecord*(reg: ConceptRegistry,
                              conceptId: string): JsonNode
```
Build an inspectable registry record showing all sources.
