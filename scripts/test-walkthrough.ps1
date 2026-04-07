# ============================================================================
# Wilder Cosmos Runtime - Complete Manual QA & UAR Testing Walkthrough
# ============================================================================
# 
# This script guides you through manual testing of every subsystem in Cosmos.
# It is designed for learning the system while performing QA and UAR (User Acceptance Review) testing.
#
# Organization:
#   - Foundation Tests (API, config, harness basics)
#   - Chapter Tests (Ch1-Ch4 organized by architecture phase)
#   - Subsystem Tests (organized by functionality)
#   - UAT Tests (User Acceptance Scenarios)
#   - Integration Tests (Full system end-to-end)
#
# Each section includes:
#   - What subsystems are being tested
#   - What to look for (pass criteria)
#   - Learning notes (key concepts)
#   - Manual walkthrough options
#
# ============================================================================

param(
    [ValidateSet('foundation', 'chapter1', 'chapter2', 'chapter3', 'chapter4', 
                  'subsystems', 'integration', 'all', 'quick')]
    [string]$TestCategory = 'all',
    
    [switch]$NoColor,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'

# Color output helpers
function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "=" * 80 -ForegroundColor Cyan
}

function Write-Subsection {
    param([string]$Title)
    Write-Host "`n►► $Title" -ForegroundColor Yellow
}

function Write-TestInfo {
    param([string]$Info)
    Write-Host "  ℹ️  $Info" -ForegroundColor Gray
}

function Write-PassCriteria {
    param([string]$Criteria)
    Write-Host "  ✓  [PASS CRITERIA] $Criteria" -ForegroundColor Green
}

function Write-LearningNote {
    param([string]$Note)
    Write-Host "  📚 [LEARNING] $Note" -ForegroundColor Magenta
}

function Write-Command {
    param([string]$Command)
    Write-Host "  ⚡ Command: $Command" -ForegroundColor Cyan
}

function Run-Test {
    param(
        [string]$TestFile,
        [string]$Description,
        [string[]]$PassCriteria,
        [string[]]$LearningNotes,
        [switch]$CompileOnly
    )
    
    Write-Subsection $Description
    Write-TestInfo "Test File: tests/$TestFile"
    
    foreach ($criterion in $PassCriteria) {
        Write-PassCriteria $criterion
    }
    
    foreach ($note in $LearningNotes) {
        Write-LearningNote $note
    }
    
    $cmd = if ($CompileOnly) {
        "nim c --compileOnly tests/$TestFile"
    } else {
        "nim c -r tests/$TestFile"
    }
    
    Write-Command $cmd
    Write-Host ""
    Write-Host "Press ENTER to run this test (or type 'skip' to continue):" -ForegroundColor White
    $response = Read-Host
    
    if ($response -eq 'skip') {
        Write-Host "[SKIPPED]" -ForegroundColor Gray
        return $false
    }
    
    try {
        Invoke-Expression $cmd
        Write-Host "✅ Test completed" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Test failed: $_" -ForegroundColor Red
        return $false
    }
}

function Show-TestGuide {
    param(
        [string]$Title,
        [string]$Purpose,
        [string[]]$Subsystems,
        [string[]]$TestFiles
    )
    
    Write-Subsection $Title
    Write-TestInfo "Purpose: $Purpose"
    Write-TestInfo "Subsystems tested: $($Subsystems -join ', ')"
    Write-TestInfo "Contains tests: $($TestFiles -join ', ')"
}

# ============================================================================
# FOUNDATION TESTS - Start here for basic system understanding
# ============================================================================

function Test-Foundation {
    Write-Section "FOUNDATION TESTS - Basic System & API Checks"
    
    $results = @()
    
    # Test 1: Test Harness
    $results += Run-Test `
        -TestFile "harness_test.nim" `
        -Description "Test Harness Validation (Step 1 of Foundation)" `
        -PassCriteria @(
            "All harness setup/teardown procedures complete without errors",
            "Temporary test directories created and cleaned properly",
            "JSON helper utilities work correctly"
        ) `
        -LearningNotes @(
            "The harness provides shared utilities for all test suites",
            "Every test uses setupTest(name) and teardownTest() for isolation",
            "Test tmp directories ensure no cross-contamination"
        )
    
    # Test 2: API Tests
    $results += Run-Test `
        -TestFile "api_tests.nim" `
        -Description "Runtime API Validation (Step 2 of Foundation)" `
        -PassCriteria @(
            "All API module types validate correctly",
            "API procedures execute with expected signatures",
            "Type contracts are enforced"
        ) `
        -LearningNotes @(
            "The API module defines core public types for the runtime",
            "These are the entry points that external code interacts with",
            "API validation ensures type safety at the boundary"
        )
    
    # Test 3: Configuration
    $results += Run-Test `
        -TestFile "config_test.nim" `
        -Description "Configuration Loading & Validation (Step 3 of Foundation)" `
        -PassCriteria @(
            "Runtime config loads from runtime.cue successfully",
            "Invalid config is rejected fail-fast",
            "All required fields are validated"
        ) `
        -LearningNotes @(
            "Configuration is defined in CUE format (config/runtime.cue)",
            "This determines runtime behavior at startup",
            "Fail-fast validation prevents bad configs from starting"
        )
    
    return $results
}

# ============================================================================
# CHAPTER 1 - Lifecycle Scaffolding
# ============================================================================

function Test-Chapter1 {
    Write-Section "CHAPTER 1 - Lifecycle Scaffolding & Startup Structure"
    Write-TestInfo "Learning Goal: Understand runtime startup sequence and initialization order"
    
    $results = @()
    
    # Chapter 1 UAT
    $results += Run-Test `
        -TestFile "ch1_uat.nim" `
        -Description "Chapter 1 UAT: Scaffold Structure Validation" `
        -PassCriteria @(
            "Runtime scaffold initializes in correct sequence",
            "Startup hooks execute in deterministic order",
            "Each lifecycle phase can be verified"
        ) `
        -LearningNotes @(
            "Scaffolding defines the runtime's structural foundation",
            "Deterministic sequence ensures reproducible startup",
            "UAT = User Acceptance Test, verifies end-to-end scenarios"
        )
    
    # Chapter 1 Core Tests
    $results += Run-Test `
        -TestFile "ch1_test.nim" `
        -Description "Chapter 1 Unit Tests: Scaffold Components" `
        -PassCriteria @(
            "Individual scaffold components work correctly",
            "Component contracts are met",
            "Edge cases are handled"
        ) `
        -LearningNotes @(
            "Unit tests verify single components in isolation",
            "These form the building blocks for Chapter 1 UAT"
        )
    
    return $results
}

# ============================================================================
# CHAPTER 2 - Validation & Boundary Safety
# ============================================================================

function Test-Chapter2 {
    Write-Section "CHAPTER 2 - Validation Firewall & Message Boundaries"
    Write-TestInfo "Learning Goal: Understand fail-fast validation and prefilter system"
    
    $results = @()
    
    # Validation Fundamentals
    $results += Run-Test `
        -TestFile "validation_test.nim" `
        -Description "Validation Foundations: Helper Tests" `
        -PassCriteria @(
            "All validation helper functions work correctly",
            "Type predicates identify valid/invalid data correctly",
            "Validation errors are detected and reported"
        ) `
        -LearningNotes @(
            "Validation helpers are the tools for boundary safety",
            "They check data before it enters the runtime",
            "Fail-fast means invalid data is rejected immediately"
        )
    
    # Validation Checksum
    $results += Run-Test `
        -TestFile "validation_checksum_test.nim" `
        -Description "Validation: SHA256 Checksum Integrity" `
        -PassCriteria @(
            "SHA256 checksums are computed correctly",
            "Mismatched checksums are detected",
            "Integrity validation prevents tampering"
        ) `
        -LearningNotes @(
            "Checksums ensure data hasn't been corrupted or tampered",
            "Critical for persistence and transmission safety",
            "Chapter 2 requirement for all record validation"
        )
    
    # Validation Firewall Core
    $results += Run-Test `
        -TestFile "validation_firewall_test.nim" `
        -Description "Validation Firewall: Core Behavior Tests" `
        -PassCriteria @(
            "Firewall prefilter correctly identifies allowed/denied patterns",
            "False positives and negatives are minimal",
            "Firewall state is consistent"
        ) `
        -LearningNotes @(
            "The prefilter is the first line of defense",
            "It performs fast pattern matching on incoming messages",
            "Prevents invalid data from reaching core logic"
        )
    
    # Validation Firewall Performance
    $results += Run-Test `
        -TestFile "validation_firewall_perf_test.nim" `
        -Description "Validation Firewall: Performance Benchmarks" `
        -PassCriteria @(
            "Prefilter lookup stays within performance bounds",
            "Hot-path validation doesn't cause delays",
            "Performance is deterministic (not random)"
        ) `
        -LearningNotes @(
            "Performance matters for real-time systems",
            "Prefilter must be O(1) or O(log n) for lookups",
            "Deterministic performance allows capacity planning"
        )
    
    # Validation Table Generation
    $results += Run-Test `
        -TestFile "validation_table_generation_test.nim" `
        -Description "Validation: Prefilter Table Generation" `
        -PassCriteria @(
            "Prefilter tables are generated correctly",
            "Table contents match expected patterns",
            "Generated tables pass verification"
        ) `
        -LearningNotes @(
            "Prefilter tables are built at startup",
            "Tables define which message patterns are allowed",
            "Generation must be deterministic (same input = same table)"
        )
    
    # Validation Failure Handling
    $results += Run-Test `
        -TestFile "validation_failure_occurrence_test.nim" `
        -Description "Validation: Failure Occurrence & Redaction" `
        -PassCriteria @(
            "Validation failures are recorded correctly",
            "Failure reasons are captured",
            "Sensitive data is redacted in error logs"
        ) `
        -LearningNotes @(
            "When validation fails, evidence must be preserved",
            "Redaction prevents leaking secrets in logs",
            "Audit trail needed for compliance"
        )
    
    # Edge Cases
    $results += Run-Test `
        -TestFile "ch2_edgecases_test.nim" `
        -Description "Chapter 2: Edge Cases & Boundary Conditions" `
        -PassCriteria @(
            "Edge cases don't crash the validation system",
            "Boundary conditions are handled correctly",
            "Serialization edge cases work"
        ) `
        -LearningNotes @(
            "Edge cases find bugs that normal tests miss",
            "Boundary conditions include: empty, null, max size, min size",
            "Serialization must handle complex nested types"
        )
    
    # Serialization
    $results += Run-Test `
        -TestFile "serialization_test.nim" `
        -Description "Chapter 2: Serialization & Message Envelopes" `
        -PassCriteria @(
            "Envelopes serialize/deserialize correctly",
            "Type information is preserved in envelopes",
            "Round-trip serialization is lossless"
        ) `
        -LearningNotes @(
            "Envelopes wrap messages with metadata",
            "Include type hints, timestamps, version info",
            "Enables safe message routing and validation"
        )
    
    # Messaging
    $results += Run-Test `
        -TestFile "messaging_test.nim" `
        -Description "Chapter 2: Message Dispatch & Routing" `
        -PassCriteria @(
            "All message types dispatch to correct handlers",
            "Mode-aware logging works (production vs. debug)",
            "Message routing is deterministic"
        ) `
        -LearningNotes @(
            "Messages are routed based on type and destination",
            "Different log levels for production vs. development",
            "Wave-based communication (See terminology notes)"
        )
    
    # Chapter 2 UAT
    $results += Run-Test `
        -TestFile "ch2_uat.nim" `
        -Description "Chapter 2 UAT: Comprehensive Validation Scenarios" `
        -PassCriteria @(
            "Full validation pipeline works end-to-end",
            "Messages survive the complete validation -> dispatch -> logging cycle",
            "Invalid messages are rejected at the right stage"
        ) `
        -LearningNotes @(
            "This is the user acceptance scenario for Chapter 2",
            "Tests the complete validation pipeline together",
            "Closest to real-world message processing"
        )
    
    return $results
}

# ============================================================================
# CHAPTER 3 - Persistence & Recovery
# ============================================================================

function Test-Chapter3 {
    Write-Section "CHAPTER 3 - Persistence, Recovery & Reconciliation"
    Write-TestInfo "Learning Goal: Understand multi-layer persistence and recovery mechanisms"
    
    $results = @()
    
    # Reconciliation Engine
    $results += Run-Test `
        -TestFile "reconciliation_test.nim" `
        -Description "Reconciliation Engine: Layer Failure Recovery" `
        -PassCriteria @(
            "Fails over to secondary layer when primary is corrupted",
            "Fails over to tertiary layer when primary and secondary fail",
            "Recovery is deterministic",
            "No data loss on single-layer failure"
        ) `
        -LearningNotes @(
            "Three-layer persistence: memory, disk, remote",
            "If one layer fails, reconciliation recovers from the others",
            "Deterministic means same sequence always produces same result",
            "Critical for reliability in production systems"
        )
    
    # Chapter 3 UAT
    $results += Run-Test `
        -TestFile "ch3_uat.nim" `
        -Description "Chapter 3 UAT: Complete Persistence Scenarios" `
        -PassCriteria @(
            "Transactions commit and persist correctly",
            "Failed invariants prevent commits and preserve state",
            "Rollback restores pre-transaction state",
            "Checksums detect corruption",
            "Reconciliation completes successfully",
            "Migration chains work with validation",
            "Snapshots export/import with correct encryption contract"
        ) `
        -LearningNotes @(
            "The '3' in Ch3 represents the three layers of persistence",
            "UAT means all these scenarios are tested end-to-end",
            "Snapshots = portable state exports (for migration or backup)",
            "Encryption contract = agreement about what's encrypted"
        )
    
    return $results
}

# ============================================================================
# CHAPTER 4 - Ontology System
# ============================================================================

function Test-Chapter4 {
    Write-Section "CHAPTER 4 - Ontology & Concept Registry"
    Write-TestInfo "Learning Goal: Understand the type/concept system"
    
    $results = @()
    
    # Ontology Foundations
    $results += Run-Test `
        -TestFile "ontology_test.nim" `
        -Description "Ontology Basics: Four Primitives (Concept, Aspect, Facet, Vernacular)" `
        -PassCriteria @(
            "All four ontological types instantiate correctly",
            "Type relationships are validated",
            "Concept hierarchies work correctly"
        ) `
        -LearningNotes @(
            "Ontology = type system for Cosmos concepts",
            "Concept = abstract idea or domain entity",
            "Aspect = observable property of a Concept",
            "Facet = specific constraint or value range",
            "Vernacular = domain-specific language/terminology"
        )
    
    # Concept Registry
    $results += Run-Test `
        -TestFile "concept_registry_test.nim" `
        -Description "Concept Registry: Storage & Retrieval" `
        -PassCriteria @(
            "Concepts register and are retrievable by ID",
            "Registry maintains effective ordering",
            "ABI exports are generated correctly"
        ) `
        -LearningNotes @(
            "Registry = central store for all defined Concepts",
            "ABI = Application Binary Interface export",
            "Effective Concept = resolved with all relationships"
        )
    
    # Chapter 4 Tests
    $results += Run-Test `
        -TestFile "ch4_ontology_test.nim" `
        -Description "Chapter 4: Comprehensive Ontology Verification" `
        -PassCriteria @(
            "Full ontology system works end-to-end",
            "Complex concept relationships are handled",
            "Type safety is maintained throughout"
        ) `
        -LearningNotes @(
            "Built on foundation of ontology primitives",
            "Includes hierarchies, inheritance, constraints"
        )
    
    return $results
}

# ============================================================================
# SUBSYSTEM TESTS
# ============================================================================

function Test-Subsystems {
    Write-Section "SUBSYSTEM TESTS - Core Functionality Deep Dives"
    Write-TestInfo "Learning Goal: Master specific runtime subsystems"
    
    $results = @()
    
    # Lifecycle Management (Chapter 10)
    $results += Run-Test `
        -TestFile "lifecycle_test.nim" `
        -Description "Subsystem: Runtime Lifecycle Management (Ch10)" `
        -PassCriteria @(
            "Startup sequence executes correctly",
            "Shutdown is clean and deterministic",
            "State machines transition properly",
            "Lifecycle hooks fire at right times"
        ) `
        -LearningNotes @(
            "Lifecycle manages: init -> run -> shutdown",
            "Pull-based architecture (runtime pulls from modules, not vice versa)",
            "Reversible = can stop and resume"
        )
    
    # World Ledger & Graph (Chapter 7)
    $results += Run-Test `
        -TestFile "world_test.nim" `
        -Description "Subsystem: World Ledger & Graph (Ch7)" `
        -PassCriteria @(
            "World Ledger stores state correctly",
            "World Graph maintains relationships",
            "Queries return expected results",
            "Graph traversal is deterministic"
        ) `
        -LearningNotes @(
            "World = the runtime's view of the system state",
            "Ledger = immutable record of changes",
            "Graph = relationship network between entities"
        )
    
    # Status & Memory (Chapter 6)
    $results += Run-Test `
        -TestFile "status_memory_test.nim" `
        -Description "Subsystem: Status & Memory Model (Ch6)" `
        -PassCriteria @(
            "Status state is tracked correctly",
            "Memory bounds are enforced",
            "Status transitions are valid",
            "Memory doesn't grow unbounded"
        ) `
        -LearningNotes @(
            "Status = current health/state of the runtime",
            "Memory = bounded storage for runtime state",
            "Prevents memory leaks and resource exhaustion"
        )
    
    # Scheduler (Chapter 8)
    $results += Run-Test `
        -TestFile "scheduler_test.nim" `
        -Description "Subsystem: Scheduler & Replay (Ch8)" `
        -PassCriteria @(
            "Scheduler queues tasks deterministically",
            "Task execution order is reproducible",
            "Replay produces identical results",
            "Deterministic scheduling enables debugging"
        ) `
        -LearningNotes @(
            "Scheduler = deterministic task sequencing",
            "Deterministic = same sequence always gives same result",
            "Replay = re-execute same sequence to debug issues"
        )
    
    # Delegation (Chapter 9)
    $results += Run-Test `
        -TestFile "delegation_test.nim" `
        -Description "Subsystem: Delegation Model (Ch9)" `
        -PassCriteria @(
            "Delegation relationships are created correctly",
            "Delegated operations complete successfully",
            "Delegation chains resolve properly",
            "Permission checks work"
        ) `
        -LearningNotes @(
            "Delegation = authorization model",
            "One entity can delegate tasks to another",
            "Maintains audit trail of who delegated to whom"
        )
    
    # Module System (Chapter 12)
    $results += Run-Test `
        -TestFile "module_test.nim" `
        -Description "Subsystem: Module System (Ch12)" `
        -PassCriteria @(
            "Modules register correctly",
            "Load order is deterministic",
            "Module metadata is accessible",
            "Module boundaries are enforced"
        ) `
        -LearningNotes @(
            "Modules = pluggable functionality",
            "Each module has explicit boundaries",
            "Runtime manages module lifecycle"
        )
    
    # Portability (Chapter 13)
    $results += Run-Test `
        -TestFile "portability_test.nim" `
        -Description "Subsystem: Portability Layer (Ch13)" `
        -PassCriteria @(
            "Cross-platform operations work",
            "File paths are abstracted correctly",
            "Environment differences are handled",
            "Portability doesn't require code changes"
        ) `
        -LearningNotes @(
            "Portability = works on any platform (Windows, Linux, macOS)",
            "Abstracts away OS-specific details",
            "Ensures consistent behavior everywhere"
        )
    
    # Security (Chapter 14)
    $results += Run-Test `
        -TestFile "security_bench_test.nim" `
        -Description "Subsystem: Security Boundaries (Ch14)" `
        -PassCriteria @(
            "Channel isolation is maintained",
            "Mode validation works correctly",
            "Security boundaries can't be crossed",
            "Boundary checks have acceptable performance"
        ) `
        -LearningNotes @(
            "Security boundaries prevent unauthorized access",
            "Mode = production vs. debug (affects what's logged)",
            "Channel isolation prevents info leakage between channels"
        )
    
    # Documentation Compliance (Chapter 15)
    $results += Run-Test `
        -TestFile "doc_compliance_test.nim" `
        -Description "Subsystem: Documentation Compliance (Ch15)" `
        -PassCriteria @(
            "Required doc tags present (Summary, Simile, Memory note, Flow)",
            "Code documentation is complete",
            "Examples are functional"
        ) `
        -LearningNotes @(
            "Documentation tags make code self-explaining",
            "Summary = what it does",
            "Simile = analogy for understanding",
            "Memory note = key things to remember",
            "Flow = how it works step-by-step"
        )
    
    return $results
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

function Test-Integration {
    Write-Section "INTEGRATION TESTS - End-to-End System Testing"
    Write-TestInfo "Learning Goal: See the whole system working together"
    
    $results = @()
    
    # Core Principles
    $results += Run-Test `
        -TestFile "core_principles_test.nim" `
        -Description "Integration: Core Principles Validation" `
        -PassCriteria @(
            "Pull-based flow works as designed",
            "Reversible lifecycle operations complete",
            "Determinism is maintained",
            "No race conditions detected"
        ) `
        -LearningNotes @(
            "Core Principles = Pull-based, Reversible, Deterministic",
            "These define Cosmos's fundamental architecture",
            "Must hold even under stress"
        )
    
    # Capabilities System
    $results += Run-Test `
        -TestFile "capabilities_test.nim" `
        -Description "Integration: Capability Graph Resolution" `
        -PassCriteria @(
            "Capabilities resolve to modules correctly",
            "Capability graphs don't have cycles",
            "Failure modes are handled gracefully"
        ) `
        -LearningNotes @(
            "Capabilities = what the runtime can do",
            "Expressed as a graph of dependencies",
            "Runtime must resolve capabilities to implementations"
        )
    
    # Coordinator
    $results += Run-Test `
        -TestFile "coordinator_test.nim" `
        -Description "Integration: Runtime Coordinator (CLI Entry Point)" `
        -PassCriteria @(
            "Startup coordinator handles all commands correctly",
            "Command help is available",
            "Status queries work",
            "Summary generation is accurate"
        ) `
        -LearningNotes @(
            "Coordinator = entry point to runtime",
            "Handles CLI commands and initialization",
            "First component to run when starting Cosmos"
        )
    
    # Coordinator IPC
    $results += Run-Test `
        -TestFile "coordinator_ipc_test.nim" `
        -Description "Integration: Coordinator IPC (Inter-Process messaging)" `
        -PassCriteria @(
            "IPC request handling is correct",
            "Notification formatting is accurate",
            "Message round-trips without corruption",
            "Concurrency is handled safely"
        ) `
        -LearningNotes @(
            "IPC = Inter-Process Communication",
            "Allows external tools to talk to runtime",
            "Messages must be reliable and ordered"
        )
    
    # Runtime Home Path Safety
    $results += Run-Test `
        -TestFile "cosmos_main_path_safety_test.nim" `
        -Description "Integration: Path Safety & Directory Handling" `
        -PassCriteria @(
            "Path traversal attacks are prevented",
            "Symlinks are handled safely",
            "Directory creation doesn't fail on bad paths",
            "Runtime home is isolated"
        ) `
        -LearningNotes @(
            "Path safety prevents unauthorized directory access",
            "Symlinks can be attack vector (prevent following escapes)",
            "Runtime home = isolated directory for all runtime state"
        )
    
    # Runtime IPC ID Generation
    $results += Run-Test `
        -TestFile "cosmos_main_ipc_id_test.nim" `
        -Description "Integration: IPC Request ID Generation" `
        -PassCriteria @(
            "Request IDs are unique",
            "ID generation is deterministic",
            "IDs encode necessary metadata",
            "Collision probability is negligible"
        ) `
        -LearningNotes @(
            "Request IDs track messages through the system",
            "Must be unique to prevent mixing up responses",
            "Deterministic IDs enable reproducible debugging"
        )
    
    # Console Status UI
    $results += Run-Test `
        -TestFile "console_status_test.nim" `
        -Description "Integration: Console Status UI (20 commands)" `
        -PassCriteria @(
            "All 20 console commands work correctly",
            "Three-layer rendering produces correct output",
            "Attach/detach cycles work",
            "UI state is consistent"
        ) `
        -LearningNotes @(
            "Console = interactive status UI for the runtime",
            "Three-layer rendering = status | details | logs",
            "Attach/detach = can connect and disconnect while running"
        )
    
    # Runtime Home Directory
    $results += Run-Test `
        -TestFile "runtime_home_test.nim" `
        -Description "Integration: Runtime Home & State Directory" `
        -PassCriteria @(
            "Runtime home directory is created correctly",
            "Subdirectories are set up properly",
            "File permissions are safe",
            "Initialization is idempotent"
        ) `
        -LearningNotes @(
            "Runtime home = where all runtime state lives",
            "Idempotent = running setup multiple times is safe",
            "Default: ~/.wilder/cosmos or COSMOS_HOME env var"
        )
    
    # Full End-to-End Integration
    $results += Run-Test `
        -TestFile "integration_test.nim" `
        -Description "Integration: Full End-to-End System Test (MAIN TEST)" `
        -PassCriteria @(
            "Full startup sequence completes",
            "Config loads and validates",
            "Runtime becomes ready",
            "Message ingress works",
            "Validation pipeline executes",
            "State is persisted",
            "System can handle requests"
        ) `
        -LearningNotes @(
            "This is THE most important test - if this passes, the whole system works",
            "Tests startup -> config -> validation -> messaging -> persistence",
            "This is the closest to a real user scenario",
            "If you only run one test, make it this one"
        )
    
    return $results
}

# ============================================================================
# QUICK TEST TRACK - For rapid verification
# ============================================================================

function Test-QuickTrack {
    Write-Section "QUICK TEST TRACK - Essential Smoke Tests (5 minutes)"
    Write-TestInfo "Use this when you want fast verification that nothing is broken"
    
    # Quick sequence
    "harness_test.nim",
    "api_tests.nim",
    "validation_checksum_test.nim",
    "ch2_uat.nim",
    "ch3_uat.nim",
    "integration_test.nim" | ForEach-Object {
        Write-Subsection "Running: $_"
        $cmd = "nim c -r tests/$_"
        Write-Command $cmd
        try {
            Invoke-Expression $cmd
            Write-Host "✅ Passed" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed" -ForegroundColor Red
            return
        }
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host @"

  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                                                                            ║
  ║          WILDER COSMOS RUNTIME - COMPLETE TESTING WALKTHROUGH             ║
  ║                                                                            ║
  ║                 QA Testing & User Acceptance Review (UAR)                 ║
  ║                   Version 0.9.10 | April 2026                             ║
  ║                                                                            ║
  ╚════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-TestInfo "This walkthrough guides you through manual testing of every Cosmos subsystem."
Write-TestInfo "It's designed for learning AND official QA/UAR verification."
Write-TestInfo "Run time: Foundation only ~15 min | All tests ~2 hours"
Write-TestInfo ""

$startTime = Get-Date

Write-Host "Running: $TestCategory" -ForegroundColor Cyan
Write-Host ""

switch ($TestCategory) {
    'foundation' { 
        $allResults = @()
        $allResults += Test-Foundation
        Write-Host $allResults
    }
    'chapter1' { 
        $allResults = @()
        $allResults += Test-Chapter1
        Write-Host $allResults
    }
    'chapter2' { 
        $allResults = @()
        $allResults += Test-Chapter2
        Write-Host $allResults
    }
    'chapter3' { 
        $allResults = @()
        $allResults += Test-Chapter3
        Write-Host $allResults
    }
    'chapter4' { 
        $allResults = @()
        $allResults += Test-Chapter4
        Write-Host $allResults
    }
    'subsystems' { 
        $allResults = @()
        $allResults += Test-Subsystems
        Write-Host $allResults
    }
    'integration' { 
        $allResults = @()
        $allResults += Test-Integration
        Write-Host $allResults
    }
    'quick' {
        Test-QuickTrack
    }
    'all' {
        $allResults = @()
        $allResults += Test-Foundation
        $allResults += Test-Chapter1
        $allResults += Test-Chapter2
        $allResults += Test-Chapter3
        $allResults += Test-Chapter4
        $allResults += Test-Subsystems
        $allResults += Test-Integration
    }
}

$endTime = Get-Date
$elapsed = $endTime - $startTime

Write-Section "TESTING COMPLETE"
Write-Host "Total time: $($elapsed.TotalMinutes.ToString('F1')) minutes" -ForegroundColor Green
Write-Host ""
Write-Host "Summary Notes:" -ForegroundColor Yellow
Write-Host "  • All tests follow the documentation-first principle"
Write-Host "  • Each test includes comments about what to look for (pass criteria)"
Write-Host "  • Learning notes explain why each subsystem matters"
Write-Host "  • UAT (User Acceptance Test) files are the official verification scenarios"
Write-Host ""
Write-Host "For detailed test code, see the tests/*.nim files" -ForegroundColor Gray
Write-Host "For architecture docs, see docs/implementation/" -ForegroundColor Gray
