You are performing a vocabulary refactor across a codebase and its documentation. This is to be considered a new implementation phase with chapters and tasks in the project plan. Requirments and Specifications are to be updated with this new information, prior to updating the project plan and any related documents.

Your task:
- Replace all occurrences of the old term with the new term.
- Apply changes consistently across code, comments, docs, tests, and examples.
- Do not alter unrelated text.
- Do not rewrite sentences unless required for grammatical correctness after substitution.
- Preserve formatting, indentation, and file structure.s
- Maintain semantic intent exactly.

Vocabulary change:
OLD TERM: "membrane"
NEW TERM: "validation firewall"

Rules:
1. Replace only whole-word matches unless otherwise specified.
2. Preserve capitalization patterns:
   - membrane → validation firewall
   - Membrane → Validation Firewall
   - MEMBRANE → VALIDATION FIREWALL
3. Do not introduce synonyms, expansions, or interpretations.
4. Do not change variable names, function names, or identifiers unless explicitly instructed.
5. If a sentence becomes awkward after substitution, minimally adjust it for clarity without adding new meaning.
6. Output only the modified files or diff blocks, nothing else.

Before applying changes:
- Scan the provided files.
- Identify all occurrences.
- Confirm that each replacement preserves meaning.

After applying changes:
- Provide a summary of what changed.
- Flag any ambiguous cases for human review.