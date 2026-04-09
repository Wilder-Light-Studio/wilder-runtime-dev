# api — Public Contract Types

> Source: `src/runtime/api.nim`

Public runtime API types and input validation framework. Defines the contract between modules and the runtime through type-safe distinct types and context structures.

---

## Distinct Types

These carry domain constraints enforced at construction time.

| Type | Underlying | Constraint |
|------|-----------|------------|
| `EpochCounter*` | `int` | Must be non-negative |
| `SchemaVersion*` | `int` | Must be positive |
| `PortNumber*` | `int` | Must be in `[1, 65535]` |

---

## Types

### `RuntimeState`

Top-level runtime state, readable by modules.

```nim
RuntimeState* = ref object
  epoch*: EpochCounter
  version*: string
  name*: string
```

### `ModuleContext`

Context handed to a module at initialization.

```nim
ModuleContext* = object
  name*: string
  state*: ref ModuleState
  host*: HostBindings
```

### `HostBindings`

Module-facing interface to runtime host capabilities.

```nim
HostBindings* = object
  sendMessage*: proc
  getTime*: proc
  storageRead*: proc
  storageWrite*: proc
  log*: proc
```

### `ModuleState`

State of an individual module inside the registry.

```nim
ModuleState* = object
  name*: string
  active*: bool
  initialized*: bool
  config*: JsonNode
```

### `StatusField`

Single status field definition per SPEC §7.1.

```nim
StatusField* = object
  name*: string
  fieldType*: string
  required*: bool
  default*: JsonNode
  invariant*: Option[string]
```

### `StatusSchema`

Schema for a set of status fields.

```nim
StatusSchema* = object
  fields*: seq[StatusField]
  schemaVersion*: SchemaVersion
```

### `ReconcileResult`

Result of persistence layer reconciliation.

```nim
ReconcileResult* = object
  success*: bool
  layersUsed*: seq[string]
  messages*: seq[string]
```

---

## Procedures

```nim
proc `$`*(state: RuntimeState): string
```
String representation of `RuntimeState`.

```nim
proc fromJson*[T](jsonStr: string): Option[T]
```
Parse JSON safely, returning `none` on failure.

```nim
proc initModule*()
proc cleanupModule*()
```
Module lifecycle hooks.

```nim
proc moduleContext_create*(name: string, state: ref ModuleState,
                           host: HostBindings): ModuleContext
```
Create a validated `ModuleContext`.

```nim
proc statusField_create*(name: string, fieldType: string,
                          required: bool): StatusField
```
Create a validated `StatusField`.
