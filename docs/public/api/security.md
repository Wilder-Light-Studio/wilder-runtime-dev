# security — Instance Boundaries & Channel Isolation

> Source: `src/runtime/security.nim`

Instance security boundary protection with explicit mode validation and channel isolation. Enforces access boundaries with read/write/admin permission modes and manages inter-instance communication channels.

---

## Types

### `BoundaryMode`

```nim
BoundaryMode* = enum
  bmNone       ## No access
  bmReadOnly   ## Read only
  bmReadWrite  ## Read and write
  bmAdmin      ## Full access
```

### `SecurityDenial`

Recorded denial event for audit.

```nim
SecurityDenial* = object
  instanceId*: string
  operation*: string
  reason*: string
  epochSeconds*: int64
```

### `InstanceBoundary`

Security boundary for a single instance.

```nim
InstanceBoundary* = ref object
  instanceId*: string
  mode*: BoundaryMode
  denials*: seq[SecurityDenial]
```

### `ChannelIsolation`

Inter-instance communication channel tracker.

```nim
ChannelIsolation* = ref object
  allowedChannels*: Table[string, bool]
```

---

## Procedures

### Boundary Lifecycle

```nim
proc newInstanceBoundary*(instanceId: string, mode: BoundaryMode): InstanceBoundary
```

### Permission Checks

```nim
proc canRead*(b: InstanceBoundary): bool
proc canWrite*(b: InstanceBoundary): bool
proc canAdmin*(b: InstanceBoundary): bool
```

### Guarded Checks (record denials)

```nim
proc checkRead*(b: InstanceBoundary): bool
proc checkWrite*(b: InstanceBoundary): bool
proc checkAdmin*(b: InstanceBoundary): bool
```
Returns `false` and appends a `SecurityDenial` record when the check fails.

### Mode Promotion

```nim
proc validateModePromotion*(current, proposed: BoundaryMode): bool
proc promoteMode*(b: InstanceBoundary, proposed: BoundaryMode): bool
proc isKnownRuntimeMode*(modeStr: string): bool
```

### Channel Isolation

```nim
proc newChannelIsolation*(): ChannelIsolation
proc allowChannel*(iso: ChannelIsolation, fromId, toId: string)
proc isChannelAllowed*(iso: ChannelIsolation, fromId, toId: string): bool
proc revokeChannel*(iso: ChannelIsolation, fromId, toId: string)
```

### Diagnostics

```nim
proc measureLookupNs*(warmupRounds, measureRounds: int, target: proc()): int64
```
Measure nanoseconds per call using a monotonic clock. Useful for performance assertions.
