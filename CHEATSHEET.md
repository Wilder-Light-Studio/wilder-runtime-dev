# Cheatsheet

Copy-paste reference for everyday tasks. No context needed.

## Core Commands

```powershell
nimble verify          # Full gate: compliance + all tests
nimble test            # Run all tests (compile-check + execute)
nimble compliance      # Requirements compliance check only
nimble buildRuntime    # Build release binary to bin/
nimble cleanExe        # Remove generated .exe files
```

## Testing

```powershell
# Run a single test file
nim c -r tests/unit/api_tests.nim

# Compile-check only (no execution)
nim c --compileOnly tests/unit/api_tests.nim

# Guided walkthrough (pick a category)
.\scripts\verify\test-walkthrough.ps1 -TestCategory quick
.\scripts\verify\test-walkthrough.ps1 -TestCategory foundation
.\scripts\verify\test-walkthrough.ps1 -TestCategory chapter2
.\scripts\verify\test-walkthrough.ps1 -TestCategory all
```

### Which test do I run?

- **"Did I break anything?"** → `nimble verify`
- **"Just my module"** → `nim c -r tests/unit/<module>_test.nim`
- **"Quick sanity check"** → `.\scripts\verify\test-walkthrough.ps1 -TestCategory quick`

## Create a New Module

```powershell
.\scripts\dev\new_nim_module.ps1 `
  -Kind runtime `
  -Name "mymodule" `
  -RelativePath "src/runtime/mymodule.nim" `
  -Summary "What this module does" `
  -Simile "Like a ..." `
  -MemoryNote "Key constraint or invariant" `
  -Flow "How execution moves through this module"
```

Kinds: `runtime`, `cosmos`, `test`, `example`, `style`

Or run without arguments for interactive mode:

```powershell
.\scripts\dev\new_nim_module.ps1
```

## Development Loop

1. Read the affected requirement section in `docs/implementation/REQUIREMENTS.md`
2. Update `docs/implementation/COMPLIANCE-MATRIX.md`
3. Implement code
4. Add or update tests
5. Run `nimble verify`

## Release

```powershell
nimble release         # Full release: update README + verify + build + package
nimble testRelease     # Quick release: update README + tests (skip compliance)
nimble releaseArtifacts  # Build binary + package release artifacts
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/build/build_binary.ps1` | Compile release binary to bin/ |
| `scripts/build/clean_exes.ps1` | Remove all generated .exe files |
| `scripts/dev/new_nim_module.ps1` | Scaffold a new Nim module from template |
| `scripts/dev/add_flow_comments.ps1` | Add Flow comments to source files |
| `scripts/verify/check_requirements.ps1` | Validate requirements compliance gates |
| `scripts/verify/validate_config.ps1` | Validate runtime config against Cue schema |
| `scripts/verify/test-walkthrough.ps1` | Guided manual QA testing walkthrough |
| `scripts/verify/test_validate_config_script.ps1` | Tests for the config validation script |
| `scripts/ops/prepare_release.ps1` | Create dist/v\<version\> release artifacts |
| `scripts/ops/generate_release_manifest.ps1` | Generate release manifest JSON |
| `scripts/ops/generate_artifact_checksums.ps1` | Generate SHA-256 checksums for artifacts |
| `scripts/ops/test_installer_contract.ps1` | Test installer directory contract |
| `scripts/ops/update-readme-version.ps1` | Sync README version from nimble file |

## Key Paths

| What | Where |
|------|-------|
| Project status | `STATUS.md` |
| Requirements | `docs/implementation/REQUIREMENTS.md` |
| Specification | `docs/implementation/SPECIFICATION.md` |
| Plan (canonical) | `docs/implementation/PLAN.md` |
| Compliance matrix | `docs/implementation/COMPLIANCE-MATRIX.md` |
| Dev guidelines | `docs/implementation/DEVELOPMENT-GUIDELINES.md` |
| Test quick ref | `tests/QUICK-REFERENCE.md` |
| Test walkthrough | `tests/WALKTHROUGH.md` |
