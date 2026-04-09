# home — Runtime Home Resolution

> Source: `src/runtime/home.nim`

Runtime-home path resolution and directory ownership helpers. Fixes runtime-owned paths deterministically across supported OS targets.

---

## Types

### `InstallMode`

```nim
InstallMode* = enum
  imUser    ## Per-user install
  imSystem  ## System-wide install
```

### `RuntimeHomeOwnership`

Ownership expectation for runtime-home subdirectories.

```nim
RuntimeHomeOwnership* = enum
  rhoUserEditable
  rhoToolOwned
  rhoOptionalProjects
  rhoRuntimeTools
  rhoOperationalData
```

---

## Constants

| Constant | Description |
|----------|-------------|
| `RuntimeHomeDirs*` | Array of standard runtime-home subdirectory names |

---

## Procedures

```nim
proc detectHostOs*(): string
```
Return the current host OS identifier.

```nim
proc resolveRuntimeHomeRoot*(mode: InstallMode, targetOs: string,
                              sandboxRoot: string): string
```
Resolve the canonical runtime-home root for the given install mode and OS.

```nim
proc runtimeHomeOwnership*(dirName: string): RuntimeHomeOwnership
```
Classify the ownership expectation for a subdirectory name.

```nim
proc ensureRuntimeHomeTree*(root: string)
```
Materialize the full directory tree idempotently.

```nim
proc runtimeHomePath*(root: string, child: string): string
```
Return the canonical child path under the runtime home root.
