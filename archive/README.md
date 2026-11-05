# Archive

Files that are no longer part of the current design, kept for reference. Each one is at
its original path under `archive/`. For example, `docs/implementation/PLAN.md` is now
`archive/docs/implementation/PLAN.md`. Nothing here is read by the build or the tests.

Archived on 2026-11-05. The current documents start at
[docs/implementation/index.md](../docs/implementation/index.md).

## What's here and why

| Group | Files | Why archived |
|---|---|---|
| Old plans | `docs/PLAN.md`, `docs/implementation/PLAN.md`, `PHASE-2-PLAN.md`, `PLAN-ND-TERMINOLOGY-UPDATE.md`, `ROADMAP.md` | They contradicted each other. The phases in MVP-SPECIFICATION §9 replace them. |
| Superseded references | `docs/implementation/COMPLIANCE-MATRIX.md`, `IMPLEMENTATION-DETAILS.md`, `CONFIG-CHANGES.md`, `docs/PROJECT_OVERVIEW.md` | Replaced by MVP-COMPLIANCE-MATRIX and MVP-SPECIFICATION, or one-off change notes. The old matrix marked rows "Verified" that the gate never ran. |
| Contradicts the ontology | `docs/implementation/MODULES.md`, `docs/enhancements/module-loading.md` | They say modules are not Things. MVP-ONT-7 says everything that exists is a Thing. |
| Deferred features | `docs/enhancements/` notes on encryption, multiple instances, the semantic scanner and start commands; `docs/public/` pages on encryption, the scanner, the world ledger, status and memory, the Windows installer and release tooling | Deferred in MVP-REQUIREMENTS. |
| Old manual QA | `tests/WALKTHROUGH.md`, `tests/QUICK-REFERENCE.md`, `scripts/verify/test-walkthrough.ps1` | A walkthrough of the April 2026 commands. `nimble test` and `nimble checkFast` replace it. |
| Deferred config | `config/runtime.cue`, `config/proto/messaging.proto`, `scripts/verify/validate_config.ps1` and its test, `Dockerfile` | Cue, protobuf and Linux builds are deferred. Config is JSON. |
| Release tooling | `scripts/ops/*` | Installer and release are deferred. The nimble release tasks still point here. |

## Notes

- Links inside archived files may be stale. They point at paths as they were before
  archiving.
- To bring a file back, move it to its original path (drop the `archive/` prefix) and
  update the links that point to it.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
