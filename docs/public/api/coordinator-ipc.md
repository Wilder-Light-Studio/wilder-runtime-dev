# coordinator-ipc — JSON-Lines IPC

> Source: `src/runtime/coordinator_ipc.nim`

Deterministic coordinator IPC request/response/event handling. Validates IPC requests, mutates bounded session state, and emits structured responses and events over JSON-lines TCP.

---

## Constants

| Constant | Value |
|----------|-------|
| `IpcVersion*` | `"ipc-v1"` |
| `IpcDefaultHost*` | `"127.0.0.1"` |
| `IpcDefaultPort*` | `7700` |

---

## Types

### `IpcServerState`

Runtime IPC server state.

```nim
IpcServerState* = object
  paused*: bool
  tempoHz*: int
  health*: string
  reconciliation*: string
  things*: seq[string]
  snapshotRevision*: int
  tick*: int
```

### `IpcSession`

In-memory IPC session with subscription tracking and event push queue.

```nim
IpcSession* = ref object
  state*: IpcServerState
  subscriptions*: HashSet[string]
  pushQueue*: seq[JsonNode]
  notificationLines*: seq[string]
```

---

## Procedures

### Construction

```nim
proc defaultIpcServerState*(): IpcServerState
proc newIpcSession*(state: IpcServerState): IpcSession
```

### Endpoint Helpers

```nim
proc isLocalhostHost*(host: string): bool
proc ipcEndpointUri*(host: string, port: int): string
```

### Request Handling

```nim
proc validateRequest*(request: JsonNode): tuple[...]
proc handleRequest*(session: IpcSession, request: JsonNode): JsonNode
proc dispatchRequest*(session: IpcSession, request: JsonNode): seq[JsonNode]
proc dispatchRequestLine*(session: IpcSession, line: string): seq[string]
```
`dispatchRequestLine` accepts a JSON-lines string and returns JSON-lines response strings.

### TCP Server & Client

```nim
proc serveIpcTcp*(session: IpcSession, host: string, port: int,
                   maxRequests: int): int
proc sendIpcTcpRequest*(host: string, port: int, request: JsonNode): seq[JsonNode]
```

### Events & Notifications

```nim
proc drainPushEvents*(session: IpcSession): seq[JsonNode]
proc formatNotificationLine*(time, level, component, message: string): string
proc appendNotification*(session: IpcSession, time, level, component,
                           message: string): string
```
