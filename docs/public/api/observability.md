# observability — Host Event Sink

> Source: `src/runtime/observability.nim`

Structured host observability for deterministic startup and shutdown. Captures lifecycle signals without leaking cockpit contents through a safe event sink.

---

## Types

### `HostEventKind`

```nim
HostEventKind* = enum
  evStartupStep
  evReconcilePass
  evReconcileHalt
  evMigrate
  evPrefilterActivated
  evError
  evShutdown
```

### `HostEvent`

```nim
HostEvent* = object
  kind*: HostEventKind
  step*: string
  epochSeconds*: int64
  message*: string
```

### `HostEventSink`

In-memory event sink that accumulates structured events.

```nim
HostEventSink* = ref object
  events*: seq[HostEvent]
```

---

## Procedures

```nim
proc newHostEventSink*(): HostEventSink
```
Create an empty event sink.

```nim
proc logEvent*(sink: HostEventSink, kind: HostEventKind,
                step: string, message: string)
```
Append a structured event with a Unix timestamp.

```nim
proc countEvents*(sink: HostEventSink, kind: HostEventKind): int
```
Count recorded events of a given kind.
