# Wilder Cosmos Runtime — AI Builder Developer Guide

**Last updated:** 2026-04-10

---

## Purpose

This guide provides best practices, patterns, and practical steps for AI builders and advanced developers working with the Wilder Cosmos Runtime. It covers core concepts, extensibility, and Neurodivergent (ND)-friendly documentation and code style.

---

## 1. Core Concepts

- **Thing / World / Scope:** The fundamental primitives for identity, containment, and visibility.
- **Wave:** The only communication physics; all interactions are wave-based.
- **Occurrence:** Immutable internal truth; the atomic unit of change.
- **Perception:** Local awareness event; how Things interpret Waves.
- **RECORD:** Internalized Occurrence; atomic state change.
- **Module System:** Extensible runtime via modules with clear boundaries.
- **Persistence:** Three-layer storage (primary, txlog, snapshot) with deterministic reconciliation.

---

## 2. Getting Started

1. **Clone the repository and install dependencies.**
2. **Read the following docs first:**
   - [REQUIREMENTS](../../implementation/REQUIREMENTS.md)
   - [SPECIFICATION](../../implementation/SPECIFICATION.md)
   - [COMMENT_STYLE](../../implementation/COMMENT_STYLE.md)
   - [DEVELOPMENT-GUIDELINES](../../implementation/DEVELOPMENT-GUIDELINES.md)
3. **Run compliance and verification:**
   - `nimble compliance`
   - `nimble verify`
4. **Explore the examples:**
   - `examples/counter.nim`

---

## 3. Best Practices for AI Builders

- **ND-Friendly Writing:**
  - Expand every acronym on first use (e.g., Neurodivergent (ND)).
  - Use plain, direct language and short sentences.
  - Avoid figurative or emotional language in procedural docs.
- **Modular Design:**
  - Use the module template in `src/style_templates/cosmos_runtime_module.nim`.
  - Keep modules focused and boundaries explicit.
- **Determinism:**
  - Always state when an API or function is deterministic or not.
  - Avoid hidden side effects.
- **Testing:**
  - Use the test module template in `src/style_templates/test_module.nim`.
  - Keep tests executable and complete.
- **Documentation:**
  - Follow the COMMENT_STYLE and DEVELOPMENT-GUIDELINES for all public APIs and docs.
  - Add similes, memory notes, and explicit flows to module headers.
- **Extensibility:**
  - Register new modules via the runtime module system.
  - Use clear, versioned interfaces.
- **Compliance:**
  - Update the compliance matrix and run all checks before submitting PRs.

---

## 4. Example: Creating a New Module

1. Copy `src/style_templates/cosmos_runtime_module.nim` to `src/runtime_modules/your_module.nim`.
2. Replace placeholders with your module’s name, version, and logic.
3. Implement `initModule` and `cleanupModule`.
4. Register your module in the runtime.
5. Add tests using the test module template.
6. Document all public APIs and flows.

---

## 5. Advanced Topics

- **Ontology and Capabilities:** See [ontology.nim](../../runtime/ontology.nim) and [capabilities.nim](../../runtime/capabilities.nim).
- **Persistence and Reconciliation:** See [persistence.nim](../../runtime/persistence.nim).
- **Scheduler and Tempo:** See [scheduler.nim](../../runtime/scheduler.nim) and [tempo.nim](../../runtime/tempo.nim).
- **Security and Encryption:** See [security.nim](../../runtime/security.nim) and [encryption_mode.nim](../../runtime/encryption_mode.nim).

---

## 6. ND-Friendly Checklist

- [ ] All acronyms expanded on first use
- [ ] Short, direct sentences
- [ ] Determinism noted for all APIs
- [ ] Examples are executable
- [ ] Compliance checks pass

---

## 7. Further Reading

- [COMPLIANCE-MATRIX](../../implementation/COMPLIANCE-MATRIX.md)
- [IMPLEMENTATION-DETAILS](../../implementation/IMPLEMENTATION-DETAILS.md)
- [PLAN](../../implementation/PLAN.md)
- [WALKTHROUGH](../../../tests/WALKTHROUGH.md)

---

*Licensed under the Wilder Foundation License 1.0.*
