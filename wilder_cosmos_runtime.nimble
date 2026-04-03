#? replace(sub = "\t", by = "  ")
# Package file for Wilder Cosmos Runtime (Nim)
version = "0.9.4"
author = "wilder"
description = "Wilder Cosmos Runtime — three-layer persistence, module system, and console."
license = "Wilder Foundation License 1.0"

srcDir = "src"

# minimal requires
requires "nim >= 1.6"
requires "checksums >= 0.2.1"

task build, "Build release binary":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_requirements.ps1"

task compliance, "Validate requirements compliance documentation and gates":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_requirements.ps1"

task testCompile, "Compile-check current test stubs":
	exec "nimble check"
	exec "nim c --compileOnly tests/api_tests.nim"
	exec "nim c --compileOnly tests/console_status_test.nim"
	exec "nim c --compileOnly tests/reconciliation_test.nim"
	exec "nim c --compileOnly tests/ch3_uat.nim"
	exec "nim c --compileOnly tests/validation_checksum_test.nim"
	exec "nim c --compileOnly tests/validation_test.nim"
	exec "nim c --compileOnly tests/serialization_test.nim"
	exec "nim c --compileOnly tests/config_test.nim"
	exec "nim c --compileOnly tests/messaging_test.nim"
	exec "nim c --compileOnly tests/validation_membrane_test.nim"
	exec "nim c --compileOnly tests/validation_membrane_perf_test.nim"
	exec "nim c --compileOnly tests/validation_table_generation_test.nim"
	exec "nim c --compileOnly tests/validation_failure_occurrence_test.nim"
	exec "nim c --compileOnly tests/ch2_edgecases_test.nim"
	exec "nim c --compileOnly tests/ch2_uat.nim"
	exec "nim c --compileOnly tests/ch4_ontology_test.nim"
	exec "nim c --compileOnly tests/lifecycle_test.nim"
	exec "nim c --compileOnly tests/module_test.nim"
	exec "nim c --compileOnly tests/portability_test.nim"
	exec "nim c --compileOnly tests/security_bench_test.nim"
	exec "nim c --compileOnly tests/security_boundary_test.nim"
	exec "nim c --compileOnly tests/core_principles_test.nim"
	exec "nim c --compileOnly tests/doc_compliance_test.nim"
	exec "nim c --compileOnly tests/harness_test.nim"
	exec "nim c --compileOnly tests/example_test.nim"
	exec "nim c --compileOnly tests/integration_test.nim"
	exec "nim c --compileOnly tests/coordinator_test.nim"
	exec "nim c --compileOnly tests/runtime_home_test.nim"
	exec "nim c --compileOnly tests/concept_registry_test.nim"
task test, "Run all tests":
	exec "nimble testCompile"
	exec "nim c -r tests/reconciliation_test.nim"
	exec "nim c -r tests/ch3_uat.nim"
	exec "nim c -r tests/validation_test.nim"
	exec "nim c -r tests/validation_checksum_test.nim"
	exec "nim c -r tests/serialization_test.nim"
	exec "nim c -r tests/config_test.nim"
	exec "nim c -r tests/messaging_test.nim"
	exec "nim c -r tests/validation_membrane_test.nim"
	exec "nim c -r tests/validation_membrane_perf_test.nim"
	exec "nim c -r tests/validation_table_generation_test.nim"
	exec "nim c -r tests/validation_failure_occurrence_test.nim"
	exec "nim c -r tests/ch2_edgecases_test.nim"
	exec "nim c -r tests/ch2_uat.nim"
	exec "nim c -r tests/ch4_ontology_test.nim"
	exec "nim c -r tests/lifecycle_test.nim"
	exec "nim c -r tests/console_status_test.nim"
	exec "nim c -r tests/module_test.nim"
	exec "nim c -r tests/portability_test.nim"
	exec "nim c -r tests/security_bench_test.nim"
	exec "nim c -r tests/security_boundary_test.nim"
	exec "nim c -r tests/core_principles_test.nim"
	exec "nim c -r tests/doc_compliance_test.nim"
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_validate_config_script.ps1"
	exec "nim c -r tests/harness_test.nim"
	exec "nim c -r tests/example_test.nim"
	exec "nim c -r tests/integration_test.nim"
	exec "nim c -r tests/coordinator_test.nim"
	exec "nim c -r tests/runtime_home_test.nim"
	exec "nim c -r tests/concept_registry_test.nim"

task verify, "Run compliance and tests":
	exec "nimble compliance"
	exec "nimble test"

task updateReadme, "Update README with current version from nimble":
	exec "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/update-readme-version.ps1"

task release, "Prepare release: update README and run verification":
	exec "nimble updateReadme"
	exec "nimble verify"

task testRelease, "Test-focused release: update README and run tests (skip compliance)":
	exec "nimble updateReadme"
	exec "nimble test"
