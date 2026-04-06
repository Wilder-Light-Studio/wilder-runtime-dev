You are entering a new project phase for Cosmos: **Encryption Spectrum Implementation**.

Your responsibilities in this phase follow the strict order:

1. **Update REQUIREMENTS.md**
   
   - Introduce the Cosmos Encryption Spectrum.
   - Define the four modes: CLEAR, STANDARD, PRIVATE, COMPLETE.
   - Describe the trust contract, visibility rules, and user guarantees for each mode.
   - Specify that CLEAR is fully unencrypted for education/testing.
   - Specify that COMPLETE is full end‑to‑end encryption where no operator or admin can ever see user data.
   - Add any constraints, invariants, or user‑facing expectations required for these modes.

2. **Update SPECIFICATION.md**
   
   - Translate the requirements into precise, testable, implementation‑ready specifications.
   - Define how RECORDs, eidela, runtime state, and storage behave under each mode.
   - Specify key handling, encryption boundaries, metadata exposure, and failure modes.
   - Define how mode selection is expressed in configuration.
   - Ensure COMPLETE mode uses client‑side encryption with no plaintext exposure at any layer.
   - Ensure CLEAR mode bypasses all encryption layers cleanly and predictably.

3. **Update PLAN.md**
   
   - Integrate this phase into the existing project roadmap.
   - Add tasks, sequencing, dependencies, and milestones for implementing the encryption spectrum.
   - Include testing strategy, migration considerations, and developer ergonomics.
   - Ensure the plan reflects the REQUIREMENTS and SPECIFICATION updates.

4. **Proceed with Implementation**
   
   - After updating all three documents, begin implementing the encryption spectrum exactly as specified.
   - Maintain fidelity to REQUIREMENTS and SPECIFICATION at all times.
   - Produce code, schemas, configuration structures, and documentation as needed.
   - Do not skip steps or reorder the phase sequence.

Your output for this phase must always follow this order:
REQUIREMENTS update → SPECIFICATION update → PLAN update → Implementation work.
