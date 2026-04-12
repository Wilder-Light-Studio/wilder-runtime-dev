# Wilder Cosmos Runtime Project Overview

## Project Structure
```
src/                  # Core implementation
  cosmos/             # Core runtime components
  examples/           # Example modules
  modules/            # Runtime modules
  runtime/            # Runtime system
  runtime_modules/    # Runtime-specific modules
  style_templates/    # Code style templates

tests/                # Test suite
  unit/               # Unit tests
  integration/        # Integration tests
  uat/                # User acceptance tests
  harness/            # Test harnesses

docs/                 # Documentation
  index.md            # Project overview
  PLAN.md             # Development plan
  implementation/     # Technical specifications
  public/             # Public documentation

config/               # Configuration files
  runtime.cue         # Runtime configuration

scripts/              # Build/ops scripts
  build/              # Build scripts
  verify/             # Verification scripts
  ops/                # Operations scripts

templates/            # Module templates
  headers/            # File headers
  test_module.nim     # Test module template
```

## Key Dependencies
- **Nim**: >=1.6 (primary language)
- **checksums**: >=0.2.1 (verification)
- **PowerShell**: Required for build scripts

## Build & Test Workflow
```powershell
# Full verification
nimble verify

# Build release binary
nimble buildRuntime

# Run tests
nimble test

# Compliance check
nimble compliance
```

## Documentation Sources
- [docs/index.md](docs/index.md): Project introduction
- [docs/implementation/REQUIREMENTS.md](docs/implementation/REQUIREMENTS.md): Formal requirements
- [docs/implementation/SPECIFICATION-NIM.md](docs/implementation/SPECIFICATION-NIM.md): Technical spec
- [docs/public/index.md](docs/public/index.md): Public API docs

## Configuration
- Primary config: [config/runtime.cue](config/runtime.cue)
- Build config: [wilder_cosmos_runtime.nimble](wilder_cosmos_runtime.nimble)

## Development Tools
- Module scaffolding: `scripts/dev/new_nim_module.ps1`
- Release management: `scripts/ops/prepare_release.ps1`
- CI/CD workflows: `.github/workflows/`