# Project Status

Quick context recovery — read this first when returning after a break.

## Current Focus

| Phase | Status | Summary |
|-------|--------|---------|
| **Phase XF** | 🚧 Active | Cosmos Encryption Spectrum — encryption-mode config, runtime policy layer, RECORD/persistence/snapshot integration |
| **Phase XE** | 📅 Planned | Humane Offline Licensing — offline-first local licensing, liberation-timer deactivation gate |

**Version:** `0.9.10` · **Dev line:** `0.9.9.9` · **Preview tag:** `v0.9.9.9-wip`

## Pick Up Here

- Phase XF is the active workstream. Normative anchors:
  - [REQUIREMENTS.md](docs/implementation/REQUIREMENTS.md) (Phase XF section)
  - [SPECIFICATION.md](docs/implementation/SPECIFICATION.md) §19G and §9
  - [PLAN.md](docs/implementation/PLAN.md) (Phase XF tasks)
- Encrypted RECORD primitives in `src/runtime/encrypted_record.nim` are ready
  for persistence layer integration.
- 23 chapters and 5 phases are complete. See the
  [Completion Matrix](docs/implementation/PLAN.md) for the full table.

## Quick Commands

```
nimble verify          # Full gate: compliance + all tests
nimble test            # Run all tests
nimble compliance      # Requirements compliance check only
nimble buildRuntime    # Build release binary to bin/
```

## Session Log

<!-- Append one line per session: date + what you did + what's next -->

- 2026-04-09: Added ND-friendly repo administration infrastructure (STATUS, CHEATSHEET, script help, VS Code tasks).
