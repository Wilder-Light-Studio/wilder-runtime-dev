# Wilder Cosmos Runtime - Complete QA & UAR Testing Guide

**Version:** 0.9.10 | **Date:** April 7, 2026

This is a complete manual walkthrough for testing and learning every subsystem in Wilder Cosmos Runtime. It's designed for both **QA verification** and **User Acceptance Review (UAR)**, plus hands-on learning of the system architecture.

---

## Quick Start

### The Three Testing Tracks

```powershell
# Quick smoke test (5 minutes) - verify nothing is broken
.\scripts\test-walkthrough.ps1 -TestCategory quick

# Foundation only (15 minutes) - learn the basics
.\scripts\test-walkthrough.ps1 -TestCategory foundation

# Complete walkthrough (2 hours) - master all subsystems
.\scripts\test-walkthrough.ps1 -TestCategory all
```

### What Each Category Includes

| Category | Tests | Time | Best For |
|----------|-------|------|----------|
| `quick` | 6 essential tests | 5 min | Daily smoke testing |
| `foundation` | API, config, harness | 15 min | First-time learning |
| `chapter1` | Lifecycle scaffolding | 10 min | Startup understanding |
| `chapter2` | Validation & messaging | 30 min | Boundary safety deep-dive |
| `chapter3` | Persistence & recovery | 20 min | Data reliability learning |
| `chapter4` | Ontology & types | 15 min | Type system understanding |
| `subsystems` | 8 core subsystems | 45 min | Feature-specific learning |
| `integration` | End-to-end scenarios | 35 min | Real-world QA testing |
| `all` | Everything | 2+ hours | Complete certification |

---

## Test Organization by Architecture Phase

Cosmos is organized into architectural **Chapters** that build on each other:

```
Chapter 1: Scaffolding
    ↓
Chapter 2: Validation & Boundaries
    ↓
Chapter 3: Persistence & Recovery
    ↓
Chapter 4: Ontology & Types
    ↓
Subsystems (Chapters 6-15)
    ↓
Integration (Full System)
```

### Chapter 1: Lifecycle Scaffolding ⚙️

**What it tests:** Runtime initialization and startup sequence

| Test File | Purpose | UAT | Learn |
|-----------|---------|-----|-------|
| `ch1_uat.nim` | Full scaffold validation | ✅ | Startup order matters |
| `ch1_test.nim` | Individual components | — | Each piece works |

**Key Concepts:**
- Deterministic startup sequence
- Initialization hooks
- Lifecycle phases: INIT → READY → RUNNING → SHUTDOWN

**Pass Criteria:**
- Runtime initializes without errors
- Startup order is always the same
- Each phase completes successfully

---

### Chapter 2: Validation & Boundaries 🔒

**What it tests:** Fail-fast validation, message safety, and boundary protection

| Test File | Purpose | UAT | Learn |
|-----------|---------|-----|-------|
| `validation_test.nim` | Validation helpers | — | How to check data |
| `validation_checksum_test.nim` | Data integrity | — | Detect corruption |
| `validation_firewall_test.nim` | Boundary protection | — | Block invalid messages |
| `validation_firewall_perf_test.nim` | Performance | — | Fast enough? |
| `validation_table_generation_test.nim` | Prefilter building | — | How rules work |
| `validation_failure_occurrence_test.nim` | Error handling | — | Audit trail |
| `serialization_test.nim` | Message format | — | Data exchange |
| `messaging_test.nim` | Message routing | — | Wave dispatch |
| `ch2_edgecases_test.nim` | Edge cases | — | Boundaries |
| `ch2_uat.nim` | Full pipeline | ✅ | Complete flow |

**Key Concepts:**
- **Fail-fast:** Invalid data rejected immediately at boundary
- **Prefilter:** Fast pattern matching first line of defense
- **Envelope:** Message wrapper with metadata and type info
- **Wave:** Communication pattern in Cosmos (terminology)
- **Mode-aware:** Different logging for production vs. debug

**Pass Criteria:**
- Invalid messages rejected before processing
- Valid messages pass through cleanly
- Performance is deterministic
- Serialization round-trips without loss
- Error logs don't leak secrets (redaction)

**Learning Path:**
1. Start with `validation_test.nim` - understand helpers
2. Study `validation_checksum_test.nim` - how integrity works
3. Run `validation_firewall_test.nim` - see prefilter in action
4. Check `serialization_test.nim` - see message format
5. Run `ch2_uat.nim` - watch it all work together

---

### Chapter 3: Persistence & Recovery 💾

**What it tests:** Three-layer persistence, recovery from failures, data migration

| Test File | Purpose | UAT | Learn |
|-----------|---------|-----|-------|
| `reconciliation_test.nim` | Layer failure recovery | — | How to recover |
| `ch3_uat.nim` | Full persistence scenarios | ✅ | Complete reliability |

**Key Concepts:**
- **Three-layer persistence:** Memory (fast) → Disk (reliable) → Remote (backup)
- **Reconciliation:** Auto-recovery when one layer fails
- **Snapshot:** Exportable state for migration/backup
- **Encryption contract:** Agreement about what's encrypted/not

**Pass Criteria:**
- Single layer failure doesn't lose data
- Multiple layer failures recover deterministically
- Transactions commit atomically
- Checksums detect corruption
- Snapshots can be exported and re-imported
- Migration completes with validation

**Learning Path:**
1. Study `reconciliation_test.nim` - understand layer failures
2. Run `ch3_uat.nim` - see all recovery scenarios

---

### Chapter 4: Ontology & Type System 📚

**What it tests:** Type system, concept definitions, semantic model

| Test File | Purpose | UAT | Learn |
|-----------|---------|-----|-------|
| `ontology_test.nim` | Four primitives | — | Type basics |
| `concept_registry_test.nim` | Concept storage | — | Registry system |
| `ch4_ontology_test.nim` | Full system | ✅ | Complete typing |

**Key Concepts:**
- **Concept:** Abstract idea (e.g., "User", "Transaction")
- **Aspect:** Observable property (e.g., "User.name")
- **Facet:** Constraint (e.g., "name must be 1-255 chars")
- **Vernacular:** Domain-specific terminology
- **Registry:** Central store of all concepts

**Pass Criteria:**
- All types instantiate correctly
- Type relationships validate
- Registry operations work
- ABI exports are accurate

---

## Core Subsystems (Chapters 6-15)

Each subsystem is tested in isolation AND integrated together.

### Chapter 6: Status & Memory Model 🧠

**Test:** `status_memory_test.nim`

Tracks runtime health and enforces memory bounds.

- Status states: IDLE, LOADING, READY, ACTIVE, DRAINING, SHUTDOWN
- Memory bounds prevent runaway allocation
- No resource leaks

---

### Chapter 7: World Ledger & Graph 🌍

**Test:** `world_test.nim`

The runtime's view of system state.

- **Ledger:** Immutable record of all state changes
- **Graph:** Relationship network between entities
- Query and traverse deterministically

---

### Chapter 8: Scheduler & Replay ⏱️

**Test:** `scheduler_test.nim`

Deterministic task sequencing and debugging.

- Tasks execute in reproducible order
- Replay executes same sequence again
- Debugging enabled by determinism

---

### Chapter 9: Delegation Model 🔐

**Test:** `delegation_test.nim`

Authorization and task assignment.

- Delegation relationships work
- Permission checks pass
- Audit trail maintained

---

### Chapter 10: Lifecycle Management 🔄

**Test:** `lifecycle_test.nim`

Runtime startup → running → shutdown.

- Pull-based: Runtime pulls from modules
- Reversible: Can stop and resume
- Clean shutdown

---

### Chapter 12: Module System 🧩

**Test:** `module_test.nim`

Pluggable functionality with clear boundaries.

- Modules register and initialize
- Load order is deterministic
- Boundaries are enforced

---

### Chapter 13: Portability Layer 🌐

**Test:** `portability_test.nim`

Cross-platform compatibility (Windows, Linux, macOS).

- Platform differences abstracted
- File paths work anywhere
- No code changes needed for portability

---

### Chapter 14: Security Boundaries 🛡️

**Test:** `security_bench_test.nim`

Protection against unauthorized access.

- Channel isolation prevents cross-talk
- Mode validation correct (prod vs. debug)
- Boundary checks acceptable performance

---

### Chapter 15: Documentation Compliance 📖

**Test:** `doc_compliance_test.nim`

Self-documenting code standards.

Each code module must include:
- `# Summary:` — what it does
- `# Simile:` — useful analogy
- `# Memory note:` — key things to remember
- `# Flow:` — step-by-step how it works

---

## Integration Tests (End-to-End Scenarios)

### Coordinator & CLI Entry Point 🎯

**Tests:**
- `coordinator_test.nim` — CLI command handling
- `coordinator_ipc_test.nim` — Inter-process communication

Entry point for starting the runtime. All CLI commands work correctly.

### Capabilities System 🎯

**Test:** `capabilities_test.nim`

Runtime exposes what it can do as a capability graph. Resolves to actual modules.

### Core Principles Validation 🎯

**Test:** `core_principles_test.nim`

Validates the three core principles:
1. **Pull-based:** Runtime pulls data from modules
2. **Reversible:** Startup/shutdown can be re-run
3. **Deterministic:** Same inputs always produce same outputs

### Full End-to-End Integration 🎯🎯🎯

**Test:** `integration_test.nim` ← **START HERE IF ONLY RUNNING ONE TEST**

Complete startup through message processing:
1. Config loads
2. Runtime initializes
3. Validation pipeline ready
4. Messages can be ingested
5. State persists correctly

This is the most important test. If it passes, the whole system works.

---

## How to Use the Testing Script

### Basic Usage

```powershell
# Run the script with Category parameter
cd c:\Users\heywi\Development\wilder-runtime-dev
.\scripts\test-walkthrough.ps1 -TestCategory foundation

# Available categories:
#   foundation    - API, config, harness
#   chapter1      - Lifecycle scaffolding
#   chapter2      - Validation & boundaries
#   chapter3      - Persistence & recovery
#   chapter4      - Ontology & types
#   subsystems    - Core functionality
#   integration   - End-to-end tests
#   all           - Everything
#   quick         - 5-min smoke test
```

### What You'll See

For each test, the script shows:

```
►► Chapter 3 UAT: Complete Persistence Scenarios
  ℹ️  Test File: tests/uat/ch3_uat.nim
  ✓  [PASS CRITERIA] Transactions commit and persist correctly
  ✓  [PASS CRITERIA] Failed invariants prevent commits
  📚 [LEARNING] The '3' in Ch3 represents the three layers
  ⚡ Command: nim c -r tests/uat/ch3_uat.nim

Press ENTER to run this test (or type 'skip' to continue):
```

**Options at each test:**
- Press **ENTER** → Run the test
- Type **skip** → Skip this test and go to next

### Reading Test Output

Tests use the `unittest` module from Nim. Output shows:

```
[OK] test_name
[FAIL] test_name - reason
```

If all tests pass:
```
Tests: 42 | Passed: 42 | Failed: 0 |
OK: All tests passed
```

If any fail:
```
Tests: 42 | Passed: 40 | Failed: 2 |
FAILED: test_example_1
FAILED: test_example_2
```

---

## Test Execution Reference

### Manual Test Compilation & Execution

Each test can be run independently:

```powershell
# Compile and run a single test
nim c -r tests/unit/validation_firewall_test.nim

# Just compile (find errors without running)
nim c --compileOnly tests/unit/api_tests.nim

# Build with optimizations
nim c -d:release -r tests/uat/ch3_uat.nim

# Run with verbose output (if test supports it)
nim c -r tests/integration/integration_test.nim -v
```

### Batch Running (without the walkthrough script)

```powershell
# Run Foundation track all at once
nim c -r tests/harness_test.nim && `
nim c -r tests/unit/api_tests.nim && `
nim c -r tests/unit/config_test.nim

# Or use nimble task
nimble test
```

---

## QA Testing Checklist

Use this for official QA verification:

### Pre-Testing
- [ ] Nim compiler installed and working
- [ ] Workspace compiles without errors
- [ ] No uncommitted changes (clean git state)
- [ ] All dependencies available

### Foundation Tests (30 min)
- [ ] `harness_test.nim` passes
- [ ] `api_tests.nim` passes
- [ ] `config_test.nim` passes

### Chapter Tests (60 min)
- [ ] Ch1 UAT passes
- [ ] Ch2 UAT passes
- [ ] Ch3 UAT passes
- [ ] Ch4 UAT passes

### Integration Tests (30 min)
- [ ] `integration_test.nim` passes ✅ MOST IMPORTANT
- [ ] `coordinator_test.nim` passes
- [ ] `core_principles_test.nim` passes

### Sign-Off
- [ ] All required tests pass
- [ ] No new failures vs. baseline
- [ ] Performance within bounds
- [ ] Documentation up-to-date

---

## UAR (User Acceptance Review) Scenarios

UAR tests are the official verification that user-facing functionality works:

| Scenario | Test File | Acceptance Criteria |
|----------|-----------|-------------------|
| **Ch1: Scaffold** | `ch1_uat.nim` | Runtime starts in correct sequence |
| **Ch2: Validation** | `ch2_uat.nim` | Invalid messages blocked, valid routed |
| **Ch3: Persistence** | `ch3_uat.nim` | Data survives failures, recovers correctly |
| **Ch4: Ontology** | `ch4_ontology_test.nim` | Type system works end-to-end |
| **Integration** | `integration_test.nim` | Full startup works, messages process |

All five of these must pass for UAR sign-off.

---

## Learning Paths by Interest

### For Learning the System (Best on First Read)

1. **Understand Architecture** (30 min)
   - Read: `docs/PLAN.md`
   - Run: `validation_test.nim`

2. **See Real Startup** (20 min)
   - Run: `ch1_uat.nim`
   - Read test code for what happens in each phase

3. **Learn Validation** (30 min)
   - Run: `validation_firewall_test.nim`
   - Run: `serialization_test.nim`

4. **Understand Persistence** (20 min)
   - Run: `reconciliation_test.nim`
   - Run: `ch3_uat.nim`

5. **See It All Together** (20 min)
   - Run: `integration_test.nim`

**Total: 2 hours for solid system understanding**

### For Quick Verification (Daily Use)

```powershell
.\scripts\test-walkthrough.ps1 -TestCategory quick
```

Runs 6 essential tests in ~5 minutes:
- harness_test.nim
- api_tests.nim
- validation_checksum_test.nim
- ch2_uat.nim
- ch3_uat.nim
- integration_test.nim

### For Deep Subsystem Mastery (4 hours)

```powershell
.\scripts\test-walkthrough.ps1 -TestCategory all
```

Runs all 50+ tests with learning notes for each.

---

## Key Terminology Reference

| Term | Meaning | Example |
|------|---------|---------|
| **Wave** | Message-based communication pattern in Cosmos | Sending a command Wave |
| **Envelope** | Message wrapper with metadata | Adds type info, timestamp |
| **Prefilter** | Fast pattern matching at boundary | Blocks obviously invalid messages |
| **UAT** | User Acceptance Test | ch2_uat.nim validates user scenarios |
| **Fail-fast** | Reject invalid data immediately | Don't process bad messages |
| **Deterministic** | Same inputs → same outputs always | Scheduling, reconciliation |
| **Reconciliation** | Auto-recovery from layer failures | When disk corrupt, recover from remote |
| **Snapshot** | Exportable system state | For backup or migration |
| **Ontology** | Type system for concepts | Defines what the system knows about |
| **Concept** | Core domain entity type | "User", "Transaction" |

See `/memories/repo/planning-and-terminology.md` for project-specific notes.

---

## Troubleshooting Failed Tests

### Test won't compile

```
error: cannot open 'harness'
```

**Solution:** Run from workspace root
```powershell
cd c:\Users\heywi\Development\wilder-runtime-dev
nim c -r tests/harness_test.nim
```

### Test fails with file not found

```
Error: cannot open file: 'runtime.cue'
```

**Solution:** Tests expect to run from workspace root. Ensure:
```powershell
# Verify you're in the right directory
Get-Location  # should show: c:\Users\heywi\Development\wilder-runtime-dev

# If somewhere else, navigate there
cd c:\Users\heywi\Development\wilder-runtime-dev
```

### Test passes but seems wrong

**Solution:** Check for:
1. Stale compiled artifacts:
   ```powershell
   .\scripts\clean_exes.ps1
   ```

2. Run with fresh compile (don't use cached objects):
   ```powershell
   nim c --forceBuild -r tests/unit/validation_test.nim
   ```

### Performance test times out

**Solution:** Performance tests have time limits. Running on slow hardware:
1. May timeout (not a real failure)
2. Try: `nim c -d:release -r tests/unit/validation_firewall_perf_test.nim`

---

## Next Steps After Testing

### If All Tests Pass ✅

1. Run the integration test one more time to confirm
2. Build the release binary: `nimble buildRuntime`
3. Review any documentation that changed
4. Sign off on QA checklist above
5. Ready for UAR review

### If Any Tests Fail ❌

1. Note which tests failed
2. Read the test code to understand what broke
3. Check git differences: `git diff`
4. File an issue with test name and reproduction steps
5. Fix the bug and re-run tests

### Learning Beyond Tests

- **Architecture docs:** `docs/implementation/REQUIREMENTS.md`
- **Implementation guide:** `docs/implementation/SPECIFICATION.md`
- **Test examples:** Examples in `tests/integration/example_test.nim`
- **Module templates:** `templates/cosmos_runtime_module.nim`

---

## References

- **Project Root:** `c:\Users\heywi\Development\wilder-runtime-dev`
- **Test Directory:** `tests/`
- **Script Location:** `scripts/test-walkthrough.ps1`
- **Config:** `config/runtime.cue`
- **Docs:** `docs/PLAN.md`, `docs/implementation/`

---

**Created:** April 7, 2026 | **Version:** 0.9.10
