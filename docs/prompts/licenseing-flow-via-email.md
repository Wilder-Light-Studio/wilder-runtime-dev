You are entering a new project phase: **Phase X — Wilder Licensing System**.

Your responsibilities in this phase are:

============================================================
PHASE X — OBJECTIVES
============================================================

Design and implement the **Wilder Licensing System**, a humane, offline‑first,
propagation‑safe licensing mechanism with the following properties:

1. **Offline‑first operation**
   - No telemetry, no tracking, no network calls.
   - No online activation or server verification.

2. **Local license generation**
   - After agreeing to the Wilder License, the user may generate a local license file.
   - License generation is allowed if the user meets the conditions (duty‑to‑pay or hardship).
   - The license file is stored locally and never transmitted.

3. **Duty‑to‑pay model**
   - A small, reachable price (e.g., $5–$10) is expected for all users.
   - Complimentary licenses are automatically available for anyone in need.
   - Students, hobbyists, and individuals in hardship qualify without proof.
   - Corporations, extractors, and institutions have a duty to pay.

4. **Optional one‑time transparency email**
   - After installation, the user may optionally send a one‑time email indicating
     that installation succeeded.
   - This email is user‑initiated, editable, and transparent.
   - No binary backdoors, no hidden network calls, no secrets.
   - Declining has no effect on functionality.

5. **License deactivation behavior**
   - When a valid license file is present, all licensing checks deactivate.
   - No periodic checks, no renewal, no revalidation.

6. **Three‑year liberation timer**
   - Each version contains a built‑in 3‑year countdown.
   - After the countdown, all licensing code for that version permanently deactivates.
   - The version becomes open‑source or shared‑source automatically.

7. **Propagation‑safe, humane, ND‑friendly design**
   - No coercion, no manipulation, no dark patterns.
   - Clear, transparent, respectful user experience.
   - No data collection, no analytics, no profiling.

============================================================
PHASE X — EXECUTION ORDER (MANDATORY)
============================================================

You MUST perform the following steps in strict order:

------------------------------------------------------------
STEP 1 — Update REQUIREMENTS.md
------------------------------------------------------------
Extend REQUIREMENTS.md to define:

- The full licensing philosophy (duty‑to‑pay + compassion).
- Offline‑first constraints.
- Local license generation rules.
- Optional one‑time transparency email.
- License deactivation behavior.
- Three‑year liberation timer.
- Integration with the Wilder License text.
- Non‑responsibilities (no telemetry, no tracking, no enforcement).
- Propagation‑safe guarantees.

REQUIREMENTS.md must be complete, canonical, and aligned with all prior phases.

------------------------------------------------------------
STEP 2 — Update SPECIFICATION.md
------------------------------------------------------------
After REQUIREMENTS.md is updated, update SPECIFICATION.md to define:

- The installer flow.
- The license generation mechanism.
- The structure of the local license file.
- The optional email template and invocation mechanism.
- The licensing check deactivation logic.
- The 3‑year liberation timer implementation.
- Error handling and deterministic behavior.
- Integration points with the runtime.

SPECIFICATION.md must implement REQUIREMENTS exactly and add no new requirements.

------------------------------------------------------------
STEP 3 — Update PLAN.md
------------------------------------------------------------
After SPECIFICATION.md is updated, update PLAN.md to include:

- A new Phase X section.
- Atomic, mechanically executable tasks.
- Real file paths only.
- No invented tools or directories.
- A stepwise plan that Continue.dev can execute.

PLAN.md must reflect SPEC exactly and introduce no new architecture.

------------------------------------------------------------
STEP 4 — Proceed with Implementation
------------------------------------------------------------
After all documents are updated:

- Implement the licensing system according to PLAN.md.
- Ask clarifying questions only when required by the PLAN.
- Never reorder tasks or skip steps.
- Maintain offline‑first, humane, propagation‑safe behavior.

============================================================
PHASE X — COMPLETION CRITERIA
============================================================

The phase is complete when:

- REQUIREMENTS.md is updated and stable.
- SPECIFICATION.md is updated and consistent.
- PLAN.md contains an executable Phase X section.
- The licensing system is implemented according to PLAN.md.
- The system is offline‑first, humane, and propagation‑safe.
- No contradictions exist across documents.

============================================================
END OF PHASE X PROMPT
============================================================