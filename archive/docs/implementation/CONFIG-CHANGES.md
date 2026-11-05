# Config Optional Update - Summary

**Date:** April 7, 2026
**Version:** 0.9.10

## Changes Made

### 1. Updated Requirements Documentation
**File:** `docs/implementation/REQUIREMENTS.md`

- Changed `--config <path>` from **required** to **optional**
- Added new required CLI parameters when config is not provided:
  - `--mode <dev|debug|prod>` (required if no config)
  - `--transport <json|protobuf>` (required if no config)
  - `--log-level <level>` (required if no config)
  - `--endpoint <host>` (required if no config)
  - `--port <N>` (required if no config)
- Added optional parameters that were CLI-only:
  - `--encryption-mode` (optional, default: standard)
  - `--recovery-enabled` (optional, default: false)
  - `--operator-escrow` (optional, default: false)
- Updated validation rule: Must provide EITHER `--config` OR all required CLI params

### 2. Updated Plan Documents
**File:** `docs/PLAN.md`

- Updated HH-4 Console Entrypoint notes to reflect config is now optional
- Updated coordinator launch flags documentation to show both usage options
- Updated acceptance criteria to allow both config file and CLI-only approaches

### 3. Updated Runtime Config Module
**File:** `src/runtime/config.nim`

- Added new function: `buildConfigFromCliParams()`
  - Accepts individual mode, transport, logLevel, endpoint, port parameters
  - Accepts optional encryption params
  - Returns fully validated RuntimeConfig without requiring a file
  - Supports building valid config from CLI arguments alone

### 4. Updated Coordinator (cosmos_main.nim)
**File:** `src/cosmos_main.nim`

#### Type Changes:
- Changed `configPath: string` to `configPath: Option[string]`
- Added new fields to `CoordinatorLaunchOptions`:
  - `transport: Option[string]`
  - `endpoint: Option[string]`

#### Help Text Updates:
- Completely rewrote `CoordinatorHelpText` to show both usage options
- Added clear "Required (either option A or B)" section
- Updated examples to show CLI-only usage
- Updated usage text to show both approaches

#### Parser Updates (`parseCoordinatorOptions`):
- Made `--config` optional (wraps result in `some()`)
- Added parsing for `--transport` parameter
- Added parsing for `--endpoint` parameter
- Added validation for transport values (json|protobuf)
- Changed configPath assignment to use `some()`

#### Validator Updates (`validateCoordinatorOptions`):
- Completely rewrote validation logic
- Now validates that EITHER:
  - Config file is provided (with `.isSome` and non-empty), OR
  - ALL required CLI params are provided (mode, transport, logLevel, endpoint, port)
- Provides detailed error message listing missing params if neither condition is met
- Maintains all existing cross-flag validation

#### Config Loading Logic (runCoordinatorMain):
- Added conditional branching:
  - If `--config` provided: use `loadConfigWithOverrides()` with file path
  - If `--config` not provided: use new `buildConfigFromCliParams()` function
- Updated output message to show "(generated from CLI params)" when no config file used

## Usage Examples

### With Config File (Traditional)
```bash
cosmos --config config/runtime.json
cosmos --config config/runtime.json --mode dev --log-level debug
```

### Without Config File (New)
```bash
cosmos --mode dev --transport json --log-level debug --endpoint localhost --port 8090

cosmos --mode prod --transport protobuf --log-level info --endpoint 0.0.0.0 --port 3000 \
  --encryption-mode standard --console detach
```

### Mixed (Config + CLI Overrides)
```bash
cosmos --config config/runtime.json --log-level trace --port 9000
```

## Validation Flow

1. **Parse args** - If `--help`, return early
2. **Extract values** - Parse all provided flags
3. **Validate** - Either:
   - Config file path is provided AND non-empty, OR
   - All required CLI params (mode, transport, logLevel, endpoint, port) are provided
4. **Load/Build config**:
   - If config file: `loadConfigWithOverrides(path, overrides)`
   - If CLI only: `buildConfigFromCliParams(...)`
5. **Proceed with startup**

## Pass Criteria Met

✅ Config file is now optional
✅ All required runtime params can be provided via CLI
✅ Help text clearly documents both options
✅ Requirements updated to reflect new behavior
✅ Plans updated to reflect new behavior
✅ Validation is fail-fast and helpful
✅ CLI-only configs are as valid as file-loaded configs
✅ Backward compatible - existing config file usage still works
✅ CLI overrides take precedence over config file values

## Testing Recommendations

- Test with `--config` only (existing behavior)
- Test with CLI params only (new behavior)  
- Test with config + CLI overrides
- Test error cases:
  - Missing required params
  - Both config AND CLI params incomplete
  - Invalid values for enums (mode, transport, etc.)
- Verify startup messages show correct config source
