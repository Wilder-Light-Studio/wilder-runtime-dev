# Changelog

This file tracks public-facing project milestones for Wilder Cosmos Runtime.

Current development line: `0.9.9.9`

Current preview tag: `v0.9.9.9-wip`

## v0.9.6 - In Progress

This development line reflects the current package version and the active work in
the repository.

Highlights so far:

- Validation firewall terminology now replaces the older membrane wording
	across requirements, specification, plans, compliance tracking, and user-facing
	test text.
- Chapter 2C validation test artifacts now use `validation_firewall_*` naming,
	and the repo verification flow is green after the rename and compliance cleanup.

- Phase X documentation is now in place for installer, build, release, and
	Concept system work, including canonical `cosmos.exe` entrypoint rules,
	runtime-home ownership, and channel expansion expectations.
- Runtime-home resolution and directory creation helpers are implemented for the
	Phase X filesystem contract.
- Concept registry foundations are implemented with programmatic-overrides-manual
	effective Concept selection and stable ABI export scaffolding.
- `cosmos startapp` now creates a deterministic starter scaffold with
	`cosmos.toml`, `src/`, and build-manifest generation.

- Phase XA work has started for DRY wants/provides and capability discovery,
	including new normative requirements/specification coverage, mirrored plan
	entries, and initial runtime resolver plus edge-case tests.
- Startup now enforces a pre-ingress capability validation gate that halts on
	fatal capability resolution issues and logs deterministic validation outcomes.
- Coordinator CLI now supports data-driven `cosmos capabilities` output and
	`cosmos concept resolve` mapping introspection.
- Phase XB semantic scanner work has started with deterministic source scanning,
	relationship inference, and initial CLI surfaces for `cosmos scan` and
	`cosmos capability conflicts`.
- Phase XB scanner tests now pass (`semantic_scanner_test` and extended
	coordinator CLI suites), and compliance tracking has been updated to verified.
- Phase XC runtime messaging strategy is now implemented with coordinator IPC
	request/response/event schema handling, localhost endpoint validation,
	subscription push events, and deterministic `cosmos ipc` command routes.
- Console notification stream formatting is now available via
	`cosmos notify format`, and Phase XC evidence is verified in
	`coordinator_ipc_test` and coordinator CLI contracts.
- Phase XD encrypted RECORD work is now verified with deterministic
	encryption/decryption primitives, structural metadata chain
	validation, and passing `encrypted_record_test` coverage.

- **Security Hardening & Test Coverage (Phase X):**
  - Cryptographic: Added HMAC-SHA256 authentication tags to encrypted RECORD entries; all ciphertexts now integrity-verified before decryption via `verifyAndDecryptRecordEntry()` safe API.
  - Injection Prevention: Application names validated against character allowlist `[a-zA-Z0-9_\- .]` (max 64 chars); prevents code injection in scaffold file generation.
  - Path Safety: Filesystem paths from CLI arguments now reject root paths (preventing traversal); applied to all path-accepting commands (`cosmos scan`, `concept show`, etc.).
  - IPC Security: Replaced hardcoded request IDs with per-invocation dynamic IDs (format: `cli-<epochMsec>-<counter>`); subscribe requests no longer leak static identity.
  - Key Material: Shutdown snapshot signing key now environment-driven via `COSMOS_SHUTDOWN_SNAPSHOT_SIGNING_KEY` with config-derived fallback.
  - Delimiter Injection: Nonce and signature derivation now use length-prefixed encoding, preventing field-boundary attacks.
  - Key Sanitization: Persistence layer keys now use character-class allowlist and 128-char max length (was denylist approach).
  - Exception Safety: Removed bare `except:` blocks throughout; all exception handlers now specify `except CatchableError:` or more specific types.
  - Test Coverage: 3 new test suites with 16 test cases verifying injection prevention, path safety, and dynamic ID generation.
  - Documentation: REQUIREMENTS.md, SPECIFICATION.md, PLAN.md, and COMPLIANCE-MATRIX.md all updated with security coverage and test mappings.

- Runtime API foundations are in place, including typed runtime state, module
	context, status schema, and reconciliation result structures.
- Validation boundaries are implemented with fail-fast helper procedures for
	public runtime entry points.
- Runtime configuration loading is implemented with typed parsing and startup
	validation.
- Messaging and serialization foundations are implemented, including envelope
	validation and transport selection support.
- Validation prefilter groundwork is implemented for structural runtime gating.
- Lifecycle scaffolding is implemented for ordered startup, reconciliation, and
	ingress activation steps.
- File-backed persistence hardening is implemented with deterministic txlog
	files, snapshot persistence, atomic restore behavior, and corruption guards.
- Startup and lifecycle hardening now include structured halt guidance and
	host-event emission for startup, reconcile, migrate, prefilter, and shutdown.
- Runtime configuration now supports file < environment < CLI precedence for
	mode, log level, and port with shared validation rules.
- Console hardening now includes the thin CLI entrypoint contract
	for --config, --mode, --attach, and --watch launch behavior.
- Concept and Thing validation now follow the minimal ontology contract:
	Concepts require identity plus WHY, Things require identity, and manifests
	validate only when present.
- Cosmos-native modules now keep code-defined contracts as the single source of
	truth, while external-process wrappers accept handwritten manifests as their
	authoritative contract surface.
- Chapter 5, requirements, and public module/concept documentation were aligned
	with the optional-manifest and external-wrapper model.

## v0.3.0 - 2026-03-31

- Completed the Chapter 2 delivery line across validation, serialization,
	configuration, messaging, and prefilter foundations.
- Hardened envelope and validation behavior with SHA256 checksum validation,
	deterministic checks, and sanitized failure signaling.
- Expanded the verification surface with Chapter 2 tests, edge cases, and user
	acceptance coverage under `tests/`.
- Refreshed implementation documentation for Chapter 2 under
	`docs/implementation/Chapter2/`.
- Updated Nimble tasks so `nimble test` compile-checks and runs the active test
	suites.

## v0.1.2 - 2026-03-29

- Added Chapter 1 walkthrough and module structure documentation.
- Expanded the source taxonomy with core, tempo, thing, and runtime modules.
- Added or updated runtime APIs, console behavior, persistence, serialization,
	and test helpers.
- Added supporting READMEs and test updates for the Chapter 1 foundation pass.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*