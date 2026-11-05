# Wilder Cosmos Runtime — ND Terminology Update Implementation Plan

**Date:** 2026-04-10
**Scope:** Global update of all ND references to mean Neurodivergent (ND), removal of Non-Determinist/Non-Deterministic as ND, and documentation of best practices for future compliance.

---

## 1. Objective

- Ensure all references to "ND" in code, documentation, templates, and tests are expanded as "Neurodivergent (ND)" on first use in every file.
- Remove or correct any use of ND to mean Non-Determinist or Non-Deterministic.
- Align all developer-facing guidance and compliance checks with the new definition.

## 2. Implementation Steps

### Phase A: Canonical Definitions
- [x] Update `docs/implementation/COMMENT_STYLE.md` with canonical ND definition and usage rule.
- [x] Update `docs/implementation/SPECIFICATION.md` with canonical ND definition and usage rule.
- [x] Update `docs/implementation/REQUIREMENTS.md` with canonical ND definition and usage rule.
- [x] Update `docs/implementation/DEVELOPMENT-GUIDELINES.md` with canonical ND definition and usage rule.

### Phase B: Source and Template Corrections
- [x] Update all ND references in `src/runtime/persistence.nim` to use "Neurodivergent (ND)".
- [x] Update ND references in `src/style_templates/test_module.nim` and `src/style_templates/cosmos_runtime_module.nim`.
- [x] Update ND references in `src/runtime/api.nim` and any other runtime modules.

### Phase C: Derived and Downstream References
- [x] Search all source and documentation files for ND, Non-Determinist, Non-Deterministic, neurodivergent, neurodiverse.
- [x] Update all matches to comply with the new rule.
- [x] Validate that all first uses of ND in every file are expanded as "Neurodivergent (ND)".

### Phase D: Compliance and Best Practices
- [x] Ensure compliance scripts and doc tests check for correct ND usage.
- [x] Document the rule in all developer onboarding and style guides.
- [x] Communicate the change in project changelogs and developer channels.

## 3. Validation

- Run compliance and verification tasks (`nimble compliance`, `nimble verify`).
- Review all PRs for ND usage compliance.
- Add checklist item to PR template for ND expansion.

## 4. Ownership and Review

- Implementation: Core maintainers
- Review: Documentation and compliance leads
- Approval: Project owner

---

**Status:** All steps complete as of 2026-04-10. Future ND references must follow this rule.
