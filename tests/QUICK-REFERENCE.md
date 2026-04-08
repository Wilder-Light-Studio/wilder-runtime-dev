# Wilder Cosmos Testing Quick Reference Card

## 🚀 Quick Start Commands

```powershell
# Learn the system (all tests with explanations)
.\scripts\test-walkthrough.ps1 -TestCategory all

# Quick verification (5 min smoke test)
.\scripts\test-walkthrough.ps1 -TestCategory quick

# Run specific track
.\scripts\test-walkthrough.ps1 -TestCategory chapter2
```

---

## 📊 Test Categories & Time

| Category | Time | Tests | Start With? |
|----------|------|-------|------------|
| **quick** | 5 min | 6 | ✅ Daily |
| **foundation** | 15 min | 3 | ✅ First time |
| **chapter1** | 10 min | 2 | — |
| **chapter2** | 30 min | 10 | — Most tests |
| **chapter3** | 20 min | 2 | — |
| **chapter4** | 15 min | 3 | — |
| **subsystems** | 45 min | 8 | — |
| **integration** | 35 min | 8+ | — |
| **all** | 2+ hr | 50+ | ⓘ Complete |

---

## 🏗️ The 4 Chapters

```
1️⃣  SCAFFOLDING (ch1_uat.nim)
    Runtime initialization & startup

2️⃣  VALIDATION (ch2_uat.nim)
    Messages blocked at boundary, fail-fast

3️⃣  PERSISTENCE (ch3_uat.nim) ⭐
    Data survives failures, auto-recovery

4️⃣  ONTOLOGY (ch4_ontology_test.nim)
    Type system & semantic model
```

---

## ✅ The 5 UAT Tests (Official Acceptance)

**These MUST pass for UAR sign-off:**

1. `ch1_uat.nim` — Startup works
2. `ch2_uat.nim` — Validation works
3. `ch3_uat.nim` — Persistence works
4. `ch4_ontology_test.nim` — Types work
5. `integration_test.nim` — Everything works ⭐⭐⭐

---

## 📁 Subsystems (Chapters 6-15)

| Ch | Name | Test | What It Does |
|----|------|------|------------|
| 6 | Status & Memory | `status_memory_test.nim` | Health tracking, bounds |
| 7 | World Ledger | `world_test.nim` | State & relationships |
| 8 | Scheduler | `scheduler_test.nim` | Deterministic tasks |
| 9 | Delegation | `delegation_test.nim` | Authorization model |
| 10 | Lifecycle | `lifecycle_test.nim` | Startup/shutdown |
| 12 | Modules | `module_test.nim` | Pluggable features |
| 13 | Portability | `portability_test.nim` | Cross-platform |
| 14 | Security | `security_bench_test.nim` | Boundary protection |
| 15 | Docs | `doc_compliance_test.nim` | Code quality |

---

## 🎯 Key Tests to Know

| Test | Why Run It | Time |
|------|-----------|------|
| `integration_test.nim` | Full system test | **5 min** — RUN FIRST |
| `ch3_uat.nim` | Data reliability | **5 min** |
| `ch2_uat.nim` | Security/validation | **10 min** |
| `coordinator_test.nim` | CLI/startup | **5 min** |
| `validation_firewall_test.nim` | Understand prefilter | **5 min** |

---

## 📖 Common Pass Criteria

### ✓ It Passes If...

- **Foundation tests:** All procedures run, no crashes
- **Chapter tests:** Full scenario completes successfully
- **Subsystem tests:** Component works in isolation
- **Integration tests:** Everything works together
- **UAT tests:** User acceptance scenario verified

### ✗ It Fails If...

- Test doesn't compile
- Test stops with assertion failure
- Performance exceeds timeout
- State isn't as expected after operations

---

## 🧠 Learning Progression

### 15-minute primer
1. Ch1 UAT (learn startup)
2. Validation test (learn boundaries)
3. Ch3 UAT (learn persistence)

### 1-hour overview
1. Foundation tests (3)
2. Chapter 1-4 UATs (4)
3. Integration test (1)

### 2-hour mastery
1. All foundation tests
2. All chapter tests
3. All subsystem tests
4. All integration tests

---

## 🔑 Key Concepts

| Concept | Means | Example |
|---------|-------|---------|
| **Wave** | Message pattern | Sending command |
| **Prefilter** | Fast boundary check | Block bad messages |
| **Reconciliation** | Auto-restore from failure | Recover from disk corruption |
| **Deterministic** | Reproducible | Same input = same output |
| **Fail-fast** | Error immediately | Reject at boundary |
| **UAT** | User Acceptance Test | Official verification |
| **Envelope** | Message wrapper | Metadata + payload |

---

## 🛠️ Manual Test Commands

```powershell
# Run one test
nim c -r tests/uat/ch3_uat.nim

# Just compile (check for errors)
nim c --compileOnly tests/unit/validation_test.nim

# Rebuild binary
nimble buildRuntime

# Run all tests (no walkthrough)
nimble test
```

---

## ⚠️ Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| "cannot open 'harness'" | Run from workspace root |
| Test timeout | Use `-d:release` flag |
| File not found | Check config/runtime.cue exists |
| Stale failures | Run `.\scripts\clean_exes.ps1` |

---

## 📋 QA Sign-Off Checklist

- [ ] Foundation tests pass
- [ ] Ch1 UAT passes
- [ ] Ch2 UAT passes
- [ ] Ch3 UAT passes
- [ ] Ch4 UAT passes
- [ ] Integration test passes ⭐
- [ ] No new failures vs. baseline
- [ ] Performance acceptable
- [ ] All 5 UATs pass (official)

---

## 📞 When Tests Fail

1. **Which test?** → Note the filename
2. **What error?** → Read the assertion message
3. **Why?** → Read the test code (tests/unit/*.nim, tests/integration/*.nim, tests/uat/*.nim)
4. **Fix?** → Find source code, fix bug, re-test
5. **Stuck?** → Check workspace root, clean artifacts

---

## 🎓 For More Details

- **Full Guide:** `tests/WALKTHROUGH.md`
- **Architecture:** `docs/PLAN.md`
- **Test Code:** `tests/uat/ch*_uat.nim` (start with these)
- **Examples:** `tests/integration/example_test.nim`

---

**Version:** 0.9.10 | **Created:** April 7, 2026
