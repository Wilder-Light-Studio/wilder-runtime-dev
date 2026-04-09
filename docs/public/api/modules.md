# modules — Module Registry

> Source: `src/runtime/modules.nim`

Kernel/loadable module registry with deterministic load order. Manages static module registration with lifecycle callbacks, memory caps, and contract validation for both Cosmos-native and external-process modules.

---

## Types

### `ModuleKind`

```nim
ModuleKind* = enum
  mkKernel     ## Loaded first, always present
  mkLoadable   ## Loaded after kernel modules
```

### `ModuleExecutionKind`

```nim
ModuleExecutionKind* = enum
  mekCosmosNative       ## Runs in-process
  mekExternalProcess    ## Runs as subprocess
```

### `ModuleContractSource`

```nim
ModuleContractSource* = enum
  mcsCodeDefined            ## Contract derived from code
  mcsHandWrittenManifest    ## Contract from external manifest
```

### `ModuleTransport`

```nim
ModuleTransport* = enum
  mtNone
  mtStdInStdOut
  mtArgumentsOnly
```

### `ModuleMetadata`

Static descriptor for a registered module.

```nim
ModuleMetadata* = object
  name*: string
  kind*: ModuleKind
  schemaVersion*: int
  memoryCap*: int
  resourceBudget*: int
  description*: string
  executionKind*: ModuleExecutionKind
  contractSource*: ModuleContractSource
  contractManifest*: InterrogativeManifest
  entryCommand*: string
  entryArgs*: seq[string]
  transport*: ModuleTransport
```

### `ModuleEntry`

Registry entry pairing metadata with an initialization callback.

```nim
ModuleEntry* = object
  meta*: ModuleMetadata
  initProc*: proc
```

### `ModuleRegistry`

```nim
ModuleRegistry* = ref object
  entries*: Table[string, ModuleEntry]
```

---

## Procedures

### Registry

```nim
proc newModuleRegistry*(): ModuleRegistry
proc registerModule*(reg: ModuleRegistry, meta: ModuleMetadata, initProc: proc)
proc getModule*(reg: ModuleRegistry, name: string): ModuleEntry
proc hasModule*(reg: ModuleRegistry, name: string): bool
```

### Load Order

```nim
proc loadModulesInOrder*(reg: ModuleRegistry): seq[ModuleEntry]
```
Return all modules in deterministic order: kernel first, then loadable, each sorted lexicographically.

```nim
proc loadedModuleNames*(reg: ModuleRegistry): seq[string]
```
Return module names in the same deterministic order.

### Contracts

```nim
proc attachCodeDefinedContract*(meta: var ModuleMetadata,
                                 manifest: InterrogativeManifest)
```
Attach a code-defined contract to a Cosmos-native module.

```nim
proc attachExternalManifest*(meta: var ModuleMetadata, command: string,
                              manifest: InterrogativeManifest,
                              args: seq[string], transport: ModuleTransport)
```
Attach a handwritten manifest to an external process wrapper.

```nim
proc contractManifestJson*(meta: ModuleMetadata): JsonNode
```
Generate JSON from the module's contract manifest.

### Resource Limits

```nim
proc checkMemoryCap*(meta: ModuleMetadata, usedBytes: int): bool
```
Returns `true` if `usedBytes` is within the module's `memoryCap`.
