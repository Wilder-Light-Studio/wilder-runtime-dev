# config — Runtime Configuration

> Source: `src/runtime/config.nim`

Configuration loading and validation. Parses Cue-exported JSON config, validates fail-fast, enforces mode/log constraints, and supports CLI/environment overrides with **file < environment < CLI** precedence.

---

## Types

### `RuntimeMode`

```nim
RuntimeMode* = enum
  rmDevelopment
  rmDebug
  rmProduction
```

### `EncryptionMode`

```nim
EncryptionMode* = enum
  emClear
  emStandard
  emPrivate
  emComplete
```

### `TransportKind`

```nim
TransportKind* = enum
  tkJson
  tkProtobuf
```

### `LogLevel`

```nim
LogLevel* = enum
  llTrace, llDebug, llInfo, llWarn, llError
```

### `RuntimeConfig`

Typed runtime configuration loaded from disk and overrides.

```nim
RuntimeConfig* = object
  mode*: RuntimeMode
  encryptionMode*: EncryptionMode
  recoveryEnabled*: bool
  operatorEscrow*: bool
  transport*: TransportKind
  logLevel*: LogLevel
  endpoint*: string
  port*: int
```

### `RuntimeConfigOverrides`

CLI/environment override options. Each field is `Option[T]` — only set fields override the file-based value.

```nim
RuntimeConfigOverrides* = object
  mode*: Option[string]
  encryptionMode*: Option[string]
  recoveryEnabled*: Option[bool]
  operatorEscrow*: Option[bool]
  logLevel*: Option[string]
  port*: Option[int]
```

---

## Procedures

### Loading

```nim
proc loadConfig*(path: string): RuntimeConfig
```
Load and validate config from a JSON file (exported from Cue).

```nim
proc loadConfigWithOverrides*(path: string,
                               overrides: RuntimeConfigOverrides): RuntimeConfig
```
Load config with override precedence: file < environment < CLI.

```nim
proc buildConfigFromCliParams*(mode, transport, logLevel, endpoint: string,
                                port: int,
                                encryptionMode: Option[string],
                                recoveryEnabled: Option[bool],
                                operatorEscrow: Option[bool]): RuntimeConfig
```
Build config directly from CLI parameters without loading a file.

### Encryption Mode Helpers

```nim
proc parseEncryptionMode*(raw: string): EncryptionMode
proc encryptionModeName*(mode: EncryptionMode): string
```

### Diagnostics

```nim
proc getConfigLoadInvocationCount*(): int
proc resetConfigLoadInvocationCount*()
```
Track and reset how many times config has been loaded in the current process.
