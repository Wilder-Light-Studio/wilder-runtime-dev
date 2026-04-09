# startapp — Application Scaffold

> Source: `src/runtime/startapp.nim`

Deterministic application scaffold generation for CLI. Creates starter application structure with config, source, and manifest files using staged writes and atomic moves.

---

## Constants

| Constant | Value |
|----------|-------|
| `MaxStartAppNameLength` | `64` |

---

## Types

### `StartAppOptions`

```nim
StartAppOptions* = object
  targetDir*: string
  appName*: string
  mode*: string
  transport*: string
  includeTemplate*: bool
```

---

## Procedures

```nim
proc defaultAppName*(targetDir: string): string
```
Derive an app name from the target directory path.

```nim
proc normalizeStartAppMode*(raw: string): string
proc normalizeStartAppTransport*(raw: string): string
```
Normalize free-text mode and transport values to canonical forms.

```nim
proc scaffoldApp*(opts: StartAppOptions): seq[string]
```
Generate the starter application file tree. Returns the list of created file paths.
