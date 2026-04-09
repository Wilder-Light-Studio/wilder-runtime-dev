# messaging — Envelope Dispatch

> Source: `src/runtime/messaging.nim`

Runtime message envelope dispatch and mode-aware introspection. Validates inbound envelope shape and dispatches payloads with debug-safe logging that never exposes full payloads in production.

---

## Types

### `MessageEnvelope`

```nim
MessageEnvelope* = object
  id*: string
  type*: string
  version*: int
  timestamp*: int64
  payload*: JsonNode
```

### Callback Types

```nim
MessageDispatcher* = proc(payload: JsonNode): bool
MessageLogger* = proc(msg: string)
```

---

## Procedures

```nim
proc envelopeToJson*(env: MessageEnvelope): JsonNode
```
Convert a `MessageEnvelope` to a `JsonNode` for validation.

```nim
proc dispatchEnvelope*(env: MessageEnvelope, cfg: RuntimeConfig,
                        dispatch: MessageDispatcher,
                        logger: MessageLogger): bool
```
Validate the envelope shape, dispatch the payload through `dispatch`, and log via `logger`. In production mode, payloads are never fully logged.
