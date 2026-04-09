# capabilities — Capability Resolver

> Source: `src/runtime/capabilities.nim`

Deterministic capability resolver for Thing provides and wants. Matches demand points to stable service sockets before power-on and validates provider-side signatures as canonical.

---

## Types

### `ProvideDeclaration`

Service offered by a Thing.

```nim
ProvideDeclaration* = object
  thingName*: string
  provideName*: string
  signature*: string
```

### `WantDeclaration`

Service demanded by a consuming Thing.

```nim
WantDeclaration* = object
  consumerThing*: string
  reference*: string
  expectedSignature*: string
```

### `ModuleBindingDeclaration`

Implementation binding linking a provide to a concrete module.

```nim
ModuleBindingDeclaration* = object
  provideKey*: string
  moduleType*: string
  moduleRef*: string
  entrypoint*: string
  abiVersion*: string
```

### `CapabilityBinding`

Resolved connection from a consumer want to a provider provide.

```nim
CapabilityBinding* = object
  consumerThing*: string
  reference*: string
  providerThing*: string
  provideName*: string
  signature*: string
```

### `CapabilityIssueKind`

```nim
CapabilityIssueKind* = enum
  cikMissingProviderThing
  cikMissingProvide
  cikProviderConflict
  cikSignatureMismatch
  cikOrphanedProvide
  cikMissingImplementation
  cikUndeclaredProvideImplementation
  cikImplementationConflict
```

### `CapabilityIssue`

```nim
CapabilityIssue* = object
  kind*: CapabilityIssueKind
  consumerThing*: string
  reference*: string
  detail*: string
```

### `CapabilityResolution`

```nim
CapabilityResolution* = object
  bindings*: seq[CapabilityBinding]
  issues*: seq[CapabilityIssue]
```

### `CapabilityGraph`

Immutable snapshot of the full capability graph after resolution.

```nim
CapabilityGraph* = object
  things*: seq[string]
  provides*: seq[ProvideDeclaration]
  wants*: seq[WantDeclaration]
  signatures*: seq[string]
  moduleBindings*: seq[ModuleBindingDeclaration]
  resolution*: CapabilityResolution
  startupEligible*: bool
```

---

## Procedures

```nim
proc parseWantReference*(reference: string): tuple[
  thingName: string, provideName: string, isWholeThing: bool]
```
Parse a want reference string into its components.

```nim
proc resolveCapabilities*(provides: seq[ProvideDeclaration],
                           wants: seq[WantDeclaration],
                           moduleBindings: seq[ModuleBindingDeclaration],
                           enforceBindingCoverage: bool): CapabilityResolution
```
Resolve wants to providers with deterministic issue reporting.

```nim
proc buildCapabilityGraph*(provides: seq[ProvideDeclaration],
                            wants: seq[WantDeclaration],
                            moduleBindings: seq[ModuleBindingDeclaration],
                            enforceBindingCoverage: bool): CapabilityGraph
```
Build the full immutable capability graph.

```nim
proc issueIsFatal*(issue: CapabilityIssue): bool
```
Determine whether an issue should halt startup.

```nim
proc assertFatalFree*(resolution: CapabilityResolution)
```
Raise on the first fatal issue found.
