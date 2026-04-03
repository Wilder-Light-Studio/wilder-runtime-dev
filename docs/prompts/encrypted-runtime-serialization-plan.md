You are updating the project’s normative documents. Create a new project phase titled:

    Phase X — Encrypted RECORD, Concept System, Installer, Build, and Release

Perform the following steps IN ORDER:

1. Update REQUIREMENTS.md
2. Update SPECIFICATION.md
3. Update PLAN.md
4. Then proceed with implementation work for this phase.

Integrate ALL of the following requirements and specifications:

────────────────────────────────────────────────────────
A. ENCRYPTED TRIUMVIRATE RECORD
────────────────────────────────────────────────────────

1. All RECORD entries must be encrypted end‑to‑end.
2. Encryption must be deterministic per entry so that:
   - The ciphertext is stable.
   - The hash of the ciphertext is stable.
   - Reconciliation across the triumvirate copies is possible.
3. Each RECORD entry consists of:
   - Encrypted payload (content, metadata, evidence)
   - Hash of encrypted payload
   - Hash of previous entry
   - Timestamp or sequence number
   - Entry type
   - Pseudonymous author ID
4. Reconciliation must use ONLY structural metadata:
   - Hash
   - Previous hash
   - Sequence
   - Entry type
5. The system must NEVER decrypt RECORD entries during reconciliation.
6. All three RECORD copies must remain sovereign, encrypted, and reconcilable.

────────────────────────────────────────────────────────
B. INSTALLERS & RUNTIME ENTRY POINT
────────────────────────────────────────────────────────

7. All major packages must ship with cross‑platform binary installers.
8. Installers must support:
   - User‑home installation using OS‑appropriate locations.
   - System‑wide installation using best‑practice shared directories.
   - Optional PATH integration for runtime and supporting binaries.
   - Clean uninstall with zero residue, except user-created projects.
9. The runtime MUST always start with `cosmos.exe` as the canonical entry point.
   - All packaged apps must internally delegate to `cosmos.exe`.
   - Wrapper scripts or symlinks must resolve to `cosmos.exe`.
   - No app may embed or bypass the runtime.

────────────────────────────────────────────────────────
C. CONCEPT SYSTEM (PROGRAMMATIC + MANUAL)
────────────────────────────────────────────────────────

10. Cosmos must support BOTH:
    - Programmatic Concepts (derived from code)
    - Manual Concept files (for wrapping external programs)

11. Programmatic Concepts MUST override manual Concepts when both exist.

12. The build system must:
    - Automatically derive Concepts from code.
    - Detect and embed the effective Concept into packaged apps.
    - Validate manual Concepts when no programmatic Concept exists.
    - Produce a stable Concept ABI for runtime loading.

13. The runtime must:
    - Load programmatic Concepts first.
    - Fall back to manual Concepts only when no programmatic Concept exists.
    - Maintain a Concept registry under ~/.wilder/cosmos/registry/.
    - Warn on conflicts (optional).

14. CLI must provide:
    - `cosmos concept show` (effective Concept)
    - `cosmos concept validate`
    - `cosmos concept export`
    - `cosmos concept registry` (list, inspect)

────────────────────────────────────────────────────────
D. RUNTIME HOME TREE
────────────────────────────────────────────────────────

15. Define and create the following structure:

    ~/.wilder/cosmos/
        config/
        logs/
        cache/
        messages/
        projects/
        registry/
        bin/
        temp/

16. Ownership rules:
    - config/ is user‑editable.
    - registry/ is tool‑owned.
    - projects/ is optional; users may create projects anywhere.
    - bin/ contains user‑local runtime tools.

────────────────────────────────────────────────────────
E. CLI & DEVELOPER EXPERIENCE
────────────────────────────────────────────────────────

17. Add `cosmos startapp`:
    - Interactive wizard.
    - Sane defaults.
    - Generates:
      - cosmos.toml
      - src/ directory
      - build manifest
      - optional templates

18. All CLI commands must resolve through `cosmos.exe`.

────────────────────────────────────────────────────────
F. BUILD & RELEASE TOOLING
────────────────────────────────────────────────────────

19. Build matrix:
    - Windows (x64, ARM64)
    - macOS (x64, ARM64)
    - Linux (x64, ARM64)

20. Build pipeline must include:
    - Compilation
    - Tests
    - Packaging
    - Signing
    - Publishing
    - Artifact verification

21. Versioning:
    - Semantic versioning
    - Channels: stable, beta, nightly

22. Update mechanism:
    - Manual update via installer
    - Optional auto‑update check in CLI
    - Version registry stored in ~/.wilder/cosmos/registry/

────────────────────────────────────────────────────────
G. DOCUMENTATION REQUIREMENTS
────────────────────────────────────────────────────────

23. REQUIREMENTS.md must include:
    - Encrypted RECORD system
    - Installer requirements
    - Runtime entry point rule
    - Concept system (programmatic + manual)
    - Concept override rule
    - Runtime home tree
    - CLI additions
    - Build pipeline
    - Versioning
    - Update mechanism

24. SPECIFICATION.md must include:
    - Mechanically executable details for all above
    - Deterministic encryption rules
    - RECORD structure
    - Reconciliation algorithm
    - Concept Derivation Engine
    - Concept ABI
    - Concept registry format
    - CLI command behavior
    - Installer behavior per OS
    - Build matrix and signing steps

25. PLAN.md must include:
    - Ordered tasks for implementing this entire phase
    - Dependencies
    - Outputs
    - Acceptance criteria

────────────────────────────────────────────────────────

Your output must:
- Update REQUIREMENTS.md first.
- Update SPECIFICATION.md second.
- Update PLAN.md third.
- Then begin implementation work for this phase.
- All requirements must be explicit, propagation‑safe, and testable.
- All specifications must be mechanically executable by an AI coding agent.