#? replace(sub = "\t", by = "  ")
# Package file for Wilder Cosmos Runtime (Nim)
version = "0.1.0"
author = "wilder"
description = "Wilder Cosmos Runtime — three-layer persistence, module system, and console."
license = "Wilder Foundation License 1.0"

srcDir = "src"

# minimal requires
requires "nim >= 1.6"
requires "checksums >= 0.2.1"

task buildRuntime, "Build release binary into bin/":
	exec "nim c -d:release -o:bin/cosmos.exe src/cosmos_main.nim"

task compliance, "Validate requirements compliance documentation and gates":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify/check_requirements.ps1"

task testCompile, "Compile-check current test stubs":
	exec "nimble check"
	exec "nim c --compileOnly tests/unit/api_tests.nim"
	exec "nim c --compileOnly tests/unit/console_status_test.nim"
	exec "nim c --compileOnly tests/unit/reconciliation_test.nim"
	exec "nim c --compileOnly tests/uat/ch3_uat.nim"
	exec "nim c --compileOnly tests/unit/validation_checksum_test.nim"
	exec "nim c --compileOnly tests/unit/validation_test.nim"
	exec "nim c --compileOnly tests/unit/serialization_test.nim"
	exec "nim c --compileOnly tests/unit/config_test.nim"
	exec "nim c --compileOnly tests/unit/messaging_test.nim"
	exec "nim c --compileOnly tests/unit/validation_firewall_test.nim"
	exec "nim c --compileOnly tests/unit/validation_firewall_perf_test.nim"
	exec "nim c --compileOnly tests/unit/validation_table_generation_test.nim"
	exec "nim c --compileOnly tests/unit/validation_failure_occurrence_test.nim"
	exec "nim c --compileOnly tests/unit/ch2_edgecases_test.nim"
	exec "nim c --compileOnly tests/uat/ch2_uat.nim"
	exec "nim c --compileOnly tests/unit/ch4_ontology_test.nim"
	exec "nim c --compileOnly tests/unit/lifecycle_test.nim"
	exec "nim c --compileOnly tests/unit/module_test.nim"
	exec "nim c --compileOnly tests/unit/portability_test.nim"
	exec "nim c --compileOnly tests/unit/security_bench_test.nim"
	exec "nim c --compileOnly tests/unit/security_boundary_test.nim"
	exec "nim c --compileOnly tests/unit/core_principles_test.nim"
	exec "nim c --compileOnly tests/unit/doc_compliance_test.nim"
	exec "nim c --compileOnly tests/harness_test.nim"
	exec "nim c --compileOnly tests/integration/example_test.nim"
	exec "nim c --compileOnly tests/integration/integration_test.nim"
	exec "nim c --compileOnly tests/integration/coordinator_test.nim"
	exec "nim c --compileOnly tests/integration/runtime_home_test.nim"
	exec "nim c --compileOnly tests/unit/concept_registry_test.nim"

task test, "Run every test under tests/, each with a time limit (scripts/verify/run_tests.ps1)":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify/run_tests.ps1"

task checkFast, "Run every test except daemon tests (net, osproc or cosmos_main imports)":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify/run_tests.ps1 -Fast"

task verify, "Run compliance and tests":
	exec "nimble compliance"
	exec "nimble test"

task cleanExe, "Remove generated .exe artifacts":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build/clean_exes.ps1"

task packageRelease, "(Deferred: script archived) Create dist/v<version> release artifacts":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File archive/scripts/ops/prepare_release.ps1"

task releaseArtifacts, "Build and stage release artifacts":
	exec "nimble buildRuntime"
	exec "nimble packageRelease"

task updateReadme, "(Deferred: script archived) Update README with current version from nimble":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File archive/scripts/ops/update-readme-version.ps1"

task release, "Prepare release: update README, verify, and stage artifacts":
	exec "nimble updateReadme"
	exec "nimble verify"
	exec "nimble releaseArtifacts"

task testRelease, "Test-focused release: update README and run tests (skip compliance)":
	exec "nimble updateReadme"
	exec "nimble test"

task commands, "List available nimble commands for this project":
	echo ""
	echo "  Wilder Cosmos Runtime — Project Commands"
	echo "  ========================================="
	echo ""
	echo "  Day-to-day:"
	echo "    nimble verify          Full gate: compliance + all tests"
	echo "    nimble test            Run all tests (compile-check + execute)"
	echo "    nimble testCompile     Compile-check test stubs only (no execution)"
	echo "    nimble compliance      Requirements compliance check only"
	echo "    nimble buildRuntime    Build release binary to bin/"
	echo "    nimble cleanExe        Remove generated .exe files"
	echo ""
	echo "  Release:"
	echo "    nimble release         Full release: README + verify + build + package"
	echo "    nimble testRelease     Quick release: README + tests (skip compliance)"
	echo "    nimble releaseArtifacts Build binary + package artifacts"
	echo "    nimble packageRelease  Package artifacts into dist/"
	echo "    nimble updateReadme    Sync README version from nimble file"
	echo ""
	echo "  Info:"
	echo "    nimble commands        This help listing"
	echo ""
