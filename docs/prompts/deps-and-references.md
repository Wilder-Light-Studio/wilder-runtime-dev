You are updating the project’s normative documents. Create a new project phase titled:

    Phase X — DRY Wants/Provides, Capability Discovery, Multi-Module Provides (Nim-first)

Perform the following steps IN ORDER:

1. Update REQUIREMENTS.md
2. Update SPECIFICATION.md
3. Update PLAN.md
4. Then begin implementation work for this phase.

Integrate ALL of the following requirements and specifications:

────────────────────────────────────────────────────────
A. DRY WANTS/PROVIDES (NO DOUBLE ENTRY)
────────────────────────────────────────────────────────

1. A Thing’s provides MUST be declared exactly once.
2. Consumer Things MUST NOT re-declare signatures of provides.
3. Wants MUST reference provides by:
   - Thing name + provide name (e.g., `Lexicons.get`)
   - OR whole-Thing wants (e.g., `wants Lexicons`)
4. Wants MUST NOT require signature duplication.
5. The runtime MUST resolve wants → provides using:
   - provider Thing name
   - provide name
   - signature from provider Concept
6. Wants MUST fail early if:
   - provider Thing does not exist
   - provide does not exist
   - signature mismatch occurs
   - multiple providers conflict

────────────────────────────────────────────────────────
B. CAPABILITY DISCOVERY (WAVE AVAILABILITY)
────────────────────────────────────────────────────────

7. The runtime MUST build a global capability graph at startup.
8. The capability graph MUST include:
   - all Things
   - all provides
   - all wants
   - all signatures
   - all module bindings
9. The runtime MUST expose capability discovery to:
   - the lifecycle surface
   - the CLI (`cosmos capabilities`)
   - the Concept registry
10. The runtime MUST detect:
    - missing capabilities
    - ambiguous capabilities
    - incompatible signatures
    - orphaned provides
11. The runtime MUST refuse to start if capability resolution fails.

────────────────────────────────────────────────────────
C. MULTI-MODULE PROVIDES (NIM + OTHER LANGUAGES)
────────────────────────────────────────────────────────

12. A Thing MAY declare provides in one module and implement them in another.
13. Implementation modules MAY be:
    - Nim modules
    - Python modules
    - Rust crates
    - Node packages
    - System binaries
14. The boundary (provides list) MUST live in a single canonical SEM/Nim boundary file.
15. Implementation modules MUST register provides with the runtime using:
    - a stable ABI
    - a registration proc
    - or a module descriptor
16. The runtime MUST bind implementation modules to provides at startup.
17. The runtime MUST error if:
    - a provide has no implementation
    - an implementation exists for an undeclared provide
    - multiple implementations conflict

────────────────────────────────────────────────────────
D. NIM-FIRST IMPLEMENTATION (SEM NOT REQUIRED)
────────────────────────────────────────────────────────

18. All boundary declarations MUST be representable in Nim until SEM is ready.
19. Provide declarations MUST be stored in:
    - a Nim boundary file
    - OR a manual Concept file
20. Wants MUST reference provides using:
    - `ThingName.provideName`
    - OR whole-Thing wants
21. The Concept Derivation Engine MUST:
    - extract provides from Nim boundary files
    - extract wants from Nim boundary files
    - validate signatures
    - populate the Concept registry

────────────────────────────────────────────────────────
E. CLI SUPPORT
────────────────────────────────────────────────────────

22. Add `cosmos capabilities`:
    - list all Things
    - list all provides
    - list all wants
    - show resolution status
23. Add `cosmos concept resolve`:
    - show how wants map to provides
    - show missing or ambiguous mappings

────────────────────────────────────────────────────────
F. DOCUMENTATION REQUIREMENTS
────────────────────────────────────────────────────────

24. REQUIREMENTS.md MUST include:
    - DRY wants/provides rules
    - capability discovery rules
    - multi-module provides rules
    - Nim-first boundary rules

25. SPECIFICATION.md MUST include:
    - capability graph structure
    - resolution algorithm
    - module binding ABI
    - error conditions
    - CLI behavior

26. PLAN.md MUST include:
    - ordered tasks for implementing this phase
    - dependencies
    - outputs
    - acceptance criteria

────────────────────────────────────────────────────────

Your output must:
- Update REQUIREMENTS.md first.
- Update SPECIFICATION.md second.
- Update PLAN.md third.
- Then begin implementation work for this phase.
- All requirements must be explicit, propagation-safe, and testable.
- All specifications must be mechanically executable by an AI coding agent.