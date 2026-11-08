# Cheatsheet

Copy-paste reference for everyday tasks. No context needed.

## The Gate

```powershell
nimble verify          # Full gate: compliance check, then every test
nimble test            # Every test file under tests/, each with a 90 s limit
nimble checkFast       # Same, minus daemon tests: about 20 s
nimble compliance      # Compliance check only (docs, matrix, header comments)
nimble buildRuntime    # Build bin/cosmos.exe
```

`nimble test` ends with `Gate passed.` when every file passes or is a listed known
failure. Known failures and their reasons are in `tests/KNOWN_FAILURES.txt`.

Tests build and run in parallel, so results print in the order they finish. Daemon
tests (files importing `net`, `osproc` or `cosmos_main`) take turns. To run one at a
time instead:

```powershell
.\scripts\verify\run_tests.ps1 -Jobs 1
```

### Which check do I run?

- **"Did I break anything?"** → `nimble verify`
- **"Quick sanity check"** → `nimble checkFast`
- **"Just one test file"** → `nim c -r tests/unit/<name>_test.nim`
- **"Why did a test fail?"** → read `tests/tmp/gate/logs/<name>.*`

## The cosmos Command

`cosmos <verb> [noun] [args]`. Start the daemon in one terminal, then use a second
terminal for everything else.

| Command | Does |
|---|---|
| `cosmos start` | Run the daemon in this terminal (port 7700) |
| `cosmos stop` | Ask the daemon to stop |
| `cosmos list things` | List loaded Things |
| `cosmos list watch` | List watched paths |
| `cosmos add thing <bundle>` | Load a bundle folder |
| `cosmos remove thing <id>` | Remove a Thing |
| `cosmos add watch <path>` / `remove watch <path>` | Watch or stop watching a path |
| `cosmos inspect <target>` | Show runtime state |
| `cosmos step` | Advance one frame |
| `cosmos mode <step\|continuous\|periodic>` | Change how frames run |
| `cosmos console` | Open an interactive console |

**Until Phase 2 lands:** only `start`, `inspect`, `step` and `console` reach the
daemon. The others, including `stop`, fail with "method not found" (close the
daemon's terminal to stop it). `--help` exits with an error, and the port can't be
changed. Phase 2 replaces `inspect` with `describe`, and adds `history` and `logs`. The
[Runtime CLI Guide](docs/public/getting-started/runtime-cli-guide.md) has the details.

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

Every Nim file needs the header lines (Summary, Simile, Memory note, Flow) and a
`# Flow:` comment before each `proc`. `nimble compliance` checks both.

## Development Loop

1. Read the requirement in `docs/implementation/MVP-REQUIREMENTS.md`
2. Change the code and its tests
3. Update the requirement's row in `docs/implementation/MVP-COMPLIANCE-MATRIX.md`
4. Run `nimble verify`

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/verify/run_tests.ps1` | The test gate behind `nimble test` and `nimble checkFast` |
| `scripts/verify/check_requirements.ps1` | The compliance check behind `nimble compliance` |
| `scripts/dev/new_nim_module.ps1` | Scaffold a new Nim module from a template |
| `scripts/dev/add_flow_comments.ps1` | Add Flow comments to a fixed list of older files |

Release, installer and Cue-config scripts are archived under `archive/scripts/`:
the MVP builds from source on one machine.

## Key Paths

| What | Where |
|------|-------|
| Project status | `STATUS.md` |
| Plain-language guide | `docs/implementation/MVP-PLAIN-LANGUAGE.md` |
| Reasoning behind the design | `docs/implementation/MVP-REASONING.md` |
| Glossary | `docs/public/glossary/cosmos-terms.md` |
| MVP requirements | `docs/implementation/MVP-REQUIREMENTS.md` |
| MVP specification | `docs/implementation/MVP-SPECIFICATION.md` |
| Compliance matrix | `docs/implementation/MVP-COMPLIANCE-MATRIX.md` |
| Plan and reference deployment | `docs/implementation/MVP-PLAN.md` |
| Known test failures | `tests/KNOWN_FAILURES.txt` |
| Dev guidelines | `docs/implementation/DEVELOPMENT-GUIDELINES.md` |
| Long-term reference | `docs/implementation/REQUIREMENTS.md`, `SPECIFICATION.md` |
| Superseded material | `archive/` |
