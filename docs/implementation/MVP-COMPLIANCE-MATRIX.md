# Wilder Cosmos Runtime — MVP Compliance Matrix

**Snapshot:** 2026-11-05, Nim 2.0.8, Windows 11, after the Phase 1 gate work.
`nimble test` now compiles and runs all 50 test files under `tests/`, each on its own
with a 90-second limit (`scripts/verify/run_tests.ps1`).
**Requirements:** [MVP-REQUIREMENTS.md](MVP-REQUIREMENTS.md). **How:**
[MVP-SPECIFICATION.md](MVP-SPECIFICATION.md).

This follows the old [COMPLIANCE-MATRIX.md (archived)](../../archive/docs/implementation/COMPLIANCE-MATRIX.md), with one row per MVP
requirement ID and stricter status values. The old matrix marks rows "Verified" that
the gate can't run, so those rows aren't carried over.

## Status values

| Status | Meaning |
|---|---|
| **Verified** | A test proves it, the test passes, and it runs in `nimble test`. |
| **Passing** | Checked, but not by a test in the gate (for example, by hand). |
| **Partial** | Tests cover part of the requirement. The note says what's missing. |
| **Failing** | The proving test fails, times out or doesn't compile. |
| **False pass** | The test passes for the wrong reason. |
| **Gap** | The code may do it, but no test proves it. |
| **Missing** | The code doesn't do it yet. |

`nimble test` passes: 46 files pass and 4 are known failures, listed with reasons in
`tests/KNOWN_FAILURES.txt`. A known failure is still a failure: the rows it should
prove stay Failing until Phase 2 fixes it.

## Test results

- **50 files, all in the gate:** 46 pass, 4 are known failures.
- **Fixed in Phase 1:** five compile errors, two real bugs exposed by them (the bundle
  loader looked in the wrong folder; status invariants were checked and then ignored),
  and one test that expected the old "config required" rule.

| Known failure | Cause | Fixed in |
|---|---|---|
| `integration/coordinator_test` | `start` runs the real daemon and never returns. No-argument launch exits 2 (routing regression). | Phase 2 |
| `integration/daemon_console_test` | The console session is forgotten between requests. | Phase 2 |
| `integration/cosmos_main_ipc_id_test` | `ipc` is unrouted. The test also doesn't check IDs. | Phase 2 |
| `unit/cli_parser_test` | The parser reads flags only before the verb, so `start --mode step` loses its flag. | Phase 2 |

---

## 1. Ontology

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-ONT-1 | `ontology_test`, `ch4_ontology_test` | Partial | Thing and World are one type, but the code also has separate entity types for modules, bundles and specialists (MVP-ONT-7). |
| MVP-ONT-2 | `interrogative_test`, `ontology_test` | Partial | Concepts require WHY, and `ontology_test` accepts a Thing with only WHO. Nothing yet takes a Thing's WHY from its Concept or checks that one of the two has it. |
| MVP-ONT-3 | `capabilities_test`, `interrogative_test` | Verified | |
| MVP-ONT-4 | `ontology_test` | Partial | Perception filters (senses) are tested. There are no wires, and occurrence immutability isn't tested. |
| MVP-ONT-5 | `lifecycle_test` | Verified | |
| MVP-ONT-6 | `console_status_test` (cd tests) | Verified | |
| MVP-ONT-7 | — | Missing | Modules, bundles and specialists are separate types today. The Cosmos root and Concepts aren't Things yet. |
| MVP-ONT-8 | `ontology_test` | Partial | Waves, perception and occurrences exist as types, but `emitWave` is a stub and `filterOccurrence` accepts everything. Waves don't radiate and senses aren't declared yet. The code calls the history `RECORD`. There are no wires. |
| MVP-ONT-9 | `scheduler_test` | Partial | Frames run in deterministic rounds with a digest, counted by `epoch`. Occurrences are emitted per event, not one per frame, and the history isn't a table of frame-to-changes rows. The console still shows `blip` and `morphos`. |
| MVP-ONT-10 | — | Missing | Scope paths exist, but nothing limits what a Thing can act on to its natural scope, senses and wires. |
| MVP-ONT-11 | — | Partial | The runtime applies no inheritance, but `resolveContext` and `applyOverrides` (`ontology.nim`) still merge ancestors' config down to children, called only by `ch4_ontology_test` and `resolveReference`. `Thing.overrideDeltas` is still stored. Spec §4C.7 removes them. |

## 2. Lifecycle

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-LIFE-1 | `lifecycle_test`, `integration_test` | Verified | |
| MVP-LIFE-2 | `lifecycle_test` | Verified | |
| MVP-LIFE-3 | `lifecycle_test` | Verified | |
| MVP-LIFE-4 | `lifecycle_test` | Verified | |
| MVP-LIFE-5 | `integration_test` | Partial | Nothing checks that guidance contains no paths or secrets. |
| MVP-LIFE-6 | `integration_test` | Partial | Reaching Stopped is tested. The step order isn't. |
| MVP-LIFE-7 | `integration_test` | Verified | |

## 3. Persistence

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-PER-1 | `ch3_uat` | Verified | |
| MVP-PER-2 | `ch3_uat`, `serialization_test` | Verified | |
| MVP-PER-3 | `reconciliation_test`, `ch3_uat` | Verified | |
| MVP-PER-4 | `ch3_uat` | Verified | |
| MVP-PER-5 | `ch3_uat` | Partial | A corrupt snapshot fails fast. No test covers startup halting on irreconcilable layers. |
| MVP-PER-6 | — | Gap | `sanitizeKey` exists in `persistence.nim`. No test. |

## 4. Validation

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-VAL-1 | `validation_test`, `ch2_uat` | Verified | |
| MVP-VAL-2 | `validation_table_generation_test`, `lifecycle_test` | Verified | |
| MVP-VAL-3 | `validation_firewall_test` | Verified | |
| MVP-VAL-4 | `validation_failure_occurrence_test` | Verified | |

## 5. Scheduler

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-SCH-1 | `scheduler_test` | Verified | |
| MVP-SCH-2 | `scheduler_test` | Verified | |
| MVP-SCH-3 | `scheduler_test` | Verified | |
| MVP-SCH-4 | `scheduler_test` | Partial | The five tempo kinds exist. Validation at load isn't tested. |

## 6. Integration

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-INT-1 | `capabilities_test`, `concept_registry_test` | Verified | |
| MVP-INT-2 | `lifecycle_test`, `integration_test` | Verified | |
| MVP-INT-3 | `capabilities_test` | Verified | |
| MVP-INT-4 | `coordinator_test` | Failing | `cosmos capabilities` has been unrouted since `f71f93a`. |
| MVP-INT-5 | `interrogative_test`, `module_test` | Partial | `InterrogativeManifest` has the ten interrogatives. There's no VERSION, SENSES, IMPLEMENTATION, PARTS or WIRES yet. The bundle loader reads a different format (`id`, `version`, `dependencies`, `capabilities`, `entryPoints`), and native modules declare their contract in code. |
| MVP-INT-6 | `ontology_test` | Partial | `wrapExternalProcessThing` describes a stdin/stdout implementation, but nothing runs one or exchanges messages with it. There's no in-process adapter. |
| MVP-INT-7 | — | Missing | Things can have children, but there are no composite Concepts (parts and wires) and no wires. |

## 7. Configuration

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-CFG-1 | `lifecycle_test` | Verified | |
| MVP-CFG-2 | `config_test` | Partial | The precedence logic passes, but the daemon never loads config (MVP-CLI-9). |
| MVP-CFG-3 | `config_test` | Verified | |
| MVP-CFG-4 | `integration_test` | Verified | |

## 8. Daemon, CLI and IPC

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-CLI-1 | `coordinator_test` | Failing | No arguments exits 2 instead of showing help. |
| MVP-CLI-2 | `coordinator_test` | Missing | `launchDaemon` ignores every flag. `parseStartOptions` exists but nothing calls it. |
| MVP-CLI-3 | — | Gap | The probe works only because `runtime.ping` returns `method_not_found`, which counts as "running". |
| MVP-CLI-4 | — | Missing | There's no `runtime.stop` handler. The daemon loop is `while true`. |
| MVP-CLI-5 | `daemon_console_test` | Failing | Doesn't compile. Clients have no timeout. |
| MVP-CLI-6 | `coordinator_test`, `cosmos_main_ipc_id_test` | Missing | The `run…Command` procs exist but nothing calls them. |
| MVP-CLI-7 | `coordinator_ipc_test` | Failing | Doesn't compile. Requests carry no version. |
| MVP-CLI-8 | `coordinator_test` | Failing | The file times out before reaching these tests. |
| MVP-CLI-9 | — | Missing | Every client uses `IpcDefaultPort`. |

## 9. Console

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-CON-1 | `console_status_test` | Verified | |
| MVP-CON-2 | `console_status_test` | Partial | `world`, `clear` and `exit` aren't tested. |
| MVP-CON-3 | `console_status_test` | Verified | |
| MVP-CON-4 | `console_status_test` | Partial | Session clearing is tested. Watch cancellation isn't. |
| MVP-CON-5 | `console_status_test` | Verified | |
| MVP-CON-6 | — | Gap | |
| MVP-CON-7 | — | Missing | The console session is keyed by request id, so `cosmos console` never stays attached. `console_main` is still present. |

## 10. Safety and stacking

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-SAFE-1 | `coordinator_test` | Failing | The test hangs, and IPC clients have no timeout. |
| MVP-SAFE-2 | — | Missing | Depends on `cosmos stop`. |
| MVP-SAFE-3 | `cosmos_main_path_safety_test` | False pass | `scan` and `concept` are unrouted, so every call exits 2 whatever the path. |
| MVP-SAFE-4 | `startapp_validation_test` | Verified | |
| MVP-SAFE-5 | — | Gap | `src/` has no bare `except:` today. Nothing in the gate checks for one. |
| MVP-SAFE-6 | `config_test` | Missing | The default encryption mode is `standard`, the home-made cipher, not CLEAR. |

## 11. Gate and developer experience

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-GATE-1 | `run_tests.ps1` | Verified | Tests are discovered, not listed. All 50 run. |
| MVP-GATE-2 | `doc_compliance_test` | Partial | The checklist is now tracked and `buildRuntime` needs no missing script. Not yet tried on a fresh clone. |
| MVP-GATE-3 | `run_tests.ps1` | Verified | Every file has a 90-second limit. `coordinator_test` hits it and is a known failure. |
| MVP-GATE-4 | `nimble checkFast` | Partial | Skips socket and process tests. Over one minute until `coordinator_test` stops using its full limit (Phase 2). |
| MVP-GATE-5 | — | — | A process rule, enforced by this matrix. |
| MVP-DX-1 | — | Missing | `startapp` writes `cosmos.toml`, but the loader reads `manifest.json`. |
| MVP-DX-2 | — | Passing | Checked by hand. |
| MVP-DX-3 | — | — | A process rule. |
| MVP-DX-4 | `doc_compliance_test` | Verified | |

## 12. Platform

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-PLAT-1 | all | — | The target environment. |
| MVP-PLAT-2 | `portability_test` | Verified | |

## 13. AI access

| ID | Test | Status | Note |
|---|---|---|---|
| MVP-AI-1 | — | Missing | Console commands are reachable only as text lines through `console_dispatch`. |
| MVP-AI-2 | — | Missing | The IPC `things` field is a list of names. |
| MVP-AI-3 | — | Missing | |
| MVP-AI-4 | — | Missing | IPC changes bypass the lifecycle entirely today. |
| MVP-AI-5 | — | Missing | |
| MVP-AI-6 | — | Missing | |
| MVP-AI-7 | — | Missing | The Cosmos root has no PROVIDES today. |

---

## Totals

| Status | Rows |
|---|---|
| Verified | 33 |
| Passing | 1 |
| Partial | 17 |
| Failing | 6 |
| False pass | 1 |
| Gap | 4 |
| Missing | 18 |
| Not applicable | 3 |
| **All rows** | **83** |

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
