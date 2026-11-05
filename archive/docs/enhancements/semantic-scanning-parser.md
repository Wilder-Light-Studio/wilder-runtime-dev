You are entering a new project phase: **Phase X — Dynamic Codebase Scanner & Needs/Wants/Provides Extractor**.

Your responsibilities in this phase are:

============================================================
PHASE X — OBJECTIVES
============================================================

Create a dynamic introspection utility that:

1. Scans a codebase (files, modules, directories)
2. Extracts structural information (symbols, imports, annotations, comments)
3. Infers semantic relationships:
   - needs
   - wants
   - provides
   - conflicts
   - before/after
4. Emits these as canonical **Thing objects**
5. Integrates with the existing Cosmos ontology and VFS exposure model
6. Remains propagation‑safe, deterministic, and non‑inventive

============================================================
PHASE X — EXECUTION ORDER (MANDATORY)
============================================================

You MUST perform the following steps in strict order:

------------------------------------------------------------
STEP 1 — Update REQUIREMENTS.md
------------------------------------------------------------
Rewrite or extend REQUIREMENTS.md to include:

- The definition of the Dynamic Scanner util
- Its responsibilities and non‑responsibilities
- The ontology for extracted relationships
- The rules for inference (imports → needs, annotations → provides, etc.)
- The guarantees (no mutation, no enforcement, pure introspection)
- Integration points with Cosmos (Thing objects, VFS, manifests)
- Any constraints needed for propagation‑safety

The REQUIREMENTS.md must be:
- Complete
- Canonical
- Non‑inventive
- In the user’s voice and architecture
- Fully aligned with all previous phases

------------------------------------------------------------
STEP 2 — Update SPECIFICATION.md
------------------------------------------------------------
After REQUIREMENTS.md is updated, update SPECIFICATION.md to:

- Define the util’s API surface
- Define the scanning pipeline
- Define the inference engine
- Define the Thing object output schema
- Define integration with TranslatorThing and VFS
- Define error handling and safety constraints
- Define testability and determinism rules

SPECIFICATION.md must:
- Implement the REQUIREMENTS exactly
- Add no new requirements
- Be mechanically executable by a planner

------------------------------------------------------------
STEP 3 — Update PLAN.md
------------------------------------------------------------
After SPECIFICATION.md is updated, update PLAN.md to:

- Add a new Phase X section
- Break the work into atomic, mechanically executable tasks
- Reference only real files and directories
- Avoid invention of files, folders, or tools
- Produce a plan that Continue.dev can execute safely

PLAN.md must:
- Reflect the SPEC exactly
- Contain no new requirements or architecture
- Be minimal, deterministic, and stepwise

------------------------------------------------------------
STEP 4 — Proceed with Implementation
------------------------------------------------------------
After REQUIREMENTS.md, SPECIFICATION.md, and PLAN.md are updated:

- Begin implementing Phase X according to PLAN.md
- Ask clarifying questions only when required by the PLAN
- Never invent files, directories, or tools
- Never skip steps or reorder tasks

============================================================
PHASE X — COMPLETION CRITERIA
============================================================

The phase is complete when:
- REQUIREMENTS.md is updated and stable
- SPECIFICATION.md is updated and consistent
- PLAN.md contains an executable Phase X section
- Implementation is completed according to PLAN.md
- No contradictions exist across documents

============================================================
END OF PHASE X PROMPT
============================================================