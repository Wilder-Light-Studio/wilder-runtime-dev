# console — Runtime Console

> Source: `src/runtime/console.nim`

Three-layer console with 20 commands and an attach/detach protocol. Provides a runtime navigator and debugger with status bar, scope line, and prompt layers.

---

## Types

### `ConsolePerm`

```nim
ConsolePerm* = enum
  cpRead, cpWrite, cpAdmin
```

### `ConsoleCapability`

```nim
ConsoleCapability* = enum
  ccAnsi, ccFullScreen, ccMouse
```

### `AttachFlags`

State captured at session attach time.

```nim
AttachFlags* = object
  identity*: string
  permissions*: set[ConsolePerm]
  capabilities*: set[ConsoleCapability]
  attached*: bool
```

### `WatchState`

```nim
WatchState* = object
  active*: bool
  targetPath*: string
  snapshotLines*: seq[string]
```

### `RuntimeIntrospectionState`

Global read-only runtime state exposed to the console.

```nim
RuntimeIntrospectionState* = object
  frame*: int64
  blip*: string
  morphos*: string
  uptime*: int64
  schedulerMode*: string
```

### `ConsoleSession`

Live console session carrying attach state, scope path, display layers, and watch state.

```nim
ConsoleSession* = ref object
  attach*: AttachFlags
  currentPath*: seq[string]
  statusLine*: string
  scopeLine*: string
  promptText*: string
  watchState*: WatchState
  runtimeState*: RuntimeIntrospectionState
  instanceRegistry*: Table[string, string]
```

### `ConsoleOutput`

```nim
ConsoleOutput* = object
  ok*: bool
  lines*: seq[string]
```

---

## Procedures

### Session Lifecycle

```nim
proc newConsoleSession*(): ConsoleSession
proc cmdAttach*(cs: ConsoleSession, identity: string,
                 perms: set[ConsolePerm],
                 caps: set[ConsoleCapability]): ConsoleOutput
proc cmdDetach*(cs: ConsoleSession): ConsoleOutput
proc cmdExit*(cs: ConsoleSession): ConsoleOutput
```

### Display Layers

```nim
proc renderStatusBar*(cs: ConsoleSession): string
proc renderScopeLine*(cs: ConsoleSession): string
proc renderPromptLine*(cs: ConsoleSession): string
proc renderAll*(cs: ConsoleSession): string
```

### Navigation

| Command | Procedure |
|---------|-----------|
| `ls` | `cmdLs*(cs, entries: seq[string]): ConsoleOutput` |
| `cd` | `cmdCd*(cs, path: string): ConsoleOutput` |
| `pwd` | `cmdPwd*(cs): ConsoleOutput` |

### Inspection

| Command | Procedure |
|---------|-----------|
| `info` | `cmdInfo*(cs, target: string): ConsoleOutput` |
| `peek` | `cmdPeek*(cs, target: string): ConsoleOutput` |
| `state` | `cmdState*(cs, target: string): ConsoleOutput` |
| `instances` | `cmdInstances*(cs): ConsoleOutput` |
| `specialists` | `cmdSpecialists*(cs): ConsoleOutput` |
| `delegations` | `cmdDelegations*(cs): ConsoleOutput` |
| `world` | `cmdWorld*(cs): ConsoleOutput` |
| `claims` | `cmdClaims*(cs): ConsoleOutput` |

### Watch Mode

```nim
proc cmdWatch*(cs: ConsoleSession, target: string): ConsoleOutput
proc exitWatch*(cs: ConsoleSession): ConsoleOutput
```

### Interaction

| Command | Procedure |
|---------|-----------|
| `run` | `cmdRun*(cs, target: string, args: seq[string]): ConsoleOutput` |
| `set` | `cmdSet*(cs, target, field, value: string): ConsoleOutput` |
| `call` | `cmdCall*(cs, target, msg: string): ConsoleOutput` |

### Utility

```nim
proc cmdHelp*(cs: ConsoleSession): ConsoleOutput
proc cmdClear*(cs: ConsoleSession): ConsoleOutput
proc dispatch*(cs: ConsoleSession, input: string): ConsoleOutput
proc printRuntimeStatus*()
```
`dispatch` parses raw input and routes to the matching command handler.
