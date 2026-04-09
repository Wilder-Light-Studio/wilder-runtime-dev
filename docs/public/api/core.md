# core — Runtime Lifecycle

> Source: `src/runtime/core.nim`

Deterministic startup and shutdown lifecycle management. Implements a 9-step startup sequence with gates and reconciliation, followed by graceful shutdown with snapshot export.

---

## Types

### `LifecycleStep`

Startup step enum tracking progress through the 9-step sequence.

```nim
LifecycleStep* = enum
  lcNotStarted
  lcConfigLoaded
  lcPersistenceReady
  lcEnvelopeLoaded
  lcReconciled
  lcMigrated
  lcPrefilterActive
  lcModulesLoaded
  lcFramesInitialized
  lcIngressOpen
  lcStopped
```

### `LifecycleFlags`

Tracks gates passed during startup. Ingress cannot open until reconciliation and prefilter gates are both passed.

```nim
LifecycleFlags* = object
  reconciliationPassed*: bool
  prefilterActivated*: bool
  ingressOpen*: bool
```

### `RuntimeLifecycle`

Central lifecycle handle that carries startup state, loaded modules, Things, scheduler state, event sink, and accumulated banner lines.

```nim
RuntimeLifecycle* = ref object
  step*: LifecycleStep
  flags*: LifecycleFlags
  cfg*: RuntimeConfig
  bridge*: PersistenceBridge
  reconcileResult*: ReconcileResult
  prefilterGenerationId*: string
  loadedModules*: seq[string]
  loadedThings*: seq[LoadedThing]
  cosmosRootId*: string
  schedulerState*: SchedulerState
  schedulerInitialized*: bool
  capabilityRegistryInitialized*: bool
  capabilityBindings*: seq[CapabilityBinding]
  frameLoopStarted*: bool
  loadedRuntimePayload*: JsonNode
  bannerLines*: seq[string]
  eventSink*: HostEventSink
```

### `ThingLoadStatus`

Load outcome for Things during the startup scan.

```nim
ThingLoadStatus* = enum
  tlsLoaded
  tlsSkippedMalformed
  tlsSkippedDuplicate
  tlsSkippedReservedRoot
```

### `LoadedThing`

Metadata for a Thing that was processed during startup.

```nim
LoadedThing* = object
  id*: string
  parentId*: string
  isCosmosRoot*: bool
  loadStatus*: ThingLoadStatus
```

### `StartupError`

Structured error raised when a startup step fails. Includes which step halted and suggested recovery.

```nim
StartupError* = object of CatchableError
  haltedAt*: LifecycleStep
  recoveryGuidance*: string
```

---

## Procedures

### Lifecycle Construction

```nim
proc newRuntimeLifecycle*(): RuntimeLifecycle
```

Create a fresh lifecycle handle in the `lcNotStarted` state.

### Startup Steps (1–9)

Each step advances the lifecycle sequentially. Steps that enforce gates are noted.

```nim
proc stepLoadConfig*(lc: RuntimeLifecycle, configPath: string,
                     configOverrides: RuntimeConfigOverrides)
```
**Step 1** — Load and validate runtime configuration.

```nim
proc stepInitPersistence*(lc: RuntimeLifecycle)
```
**Step 2** — Initialize the persistence backend.

```nim
proc stepLoadEnvelope*(lc: RuntimeLifecycle)
```
**Step 3** — Load runtime envelope from persistence.

```nim
proc stepReconcile*(lc: RuntimeLifecycle)
```
**Step 4** — Reconcile layers. **GATE**: sets `reconciliationPassed`.

```nim
proc stepMigrate*(lc: RuntimeLifecycle)
```
**Step 5** — Run pending schema migrations.

```nim
proc stepActivatePrefilter*(lc: RuntimeLifecycle)
```
**Step 6** — Activate the validation prefilter. **INGRESS GATE**: sets `prefilterActivated`.

```nim
proc stepLoadModules*(lc: RuntimeLifecycle, moduleNames: seq[string])
```
**Step 7** — Load modules in lexicographic order.

```nim
proc stepInitFrames*(lc: RuntimeLifecycle)
```
**Step 8** — Initialize scheduler, tempo, and world-graph.

```nim
proc stepOpenIngress*(lc: RuntimeLifecycle)
```
**Step 9** — Open ingress. Requires both `reconciliationPassed` and `prefilterActivated`.

### Optional Startup Steps

```nim
proc stepLoadUserThings*(lc: RuntimeLifecycle, thingIds: seq[string])
```
Load optional user Things between Steps 7 and 8.

```nim
proc stepValidateCapabilities*(lc: RuntimeLifecycle,
                                provides: seq[ProvideDeclaration],
                                wants: seq[WantDeclaration])
```
Pre-ingress capability gate.

### Full Startup

```nim
proc startup*(lc: RuntimeLifecycle, configPath: string,
              moduleNames: seq[string], userThingIds: seq[string],
              configOverrides: RuntimeConfigOverrides,
              capabilityProvides: seq[ProvideDeclaration],
              capabilityWants: seq[WantDeclaration])
```
Run the full 9-step deterministic startup in one call.

### Shutdown

```nim
proc shutdown*(lc: RuntimeLifecycle)
```
Graceful shutdown with snapshot export.

### Display

```nim
proc printBanner*(lc: RuntimeLifecycle)
```
Print the startup banner accumulated during startup steps.
