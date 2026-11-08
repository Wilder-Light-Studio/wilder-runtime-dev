# Neurodivergent (ND) Documentation Checklist

Use this checklist when adding or changing a module, test or document. The full rules
are in [COMMENT_STYLE.md](COMMENT_STYLE.md) and
[DEVELOPMENT-GUIDELINES.md](DEVELOPMENT-GUIDELINES.md).
`tests/unit/doc_compliance_test.nim` checks parts of it automatically.

This file replaces `.github/ND_DOCS_CHECKLIST.md`, which the test referenced but which
was never committed.

## Module Header

- [ ] The first lines name the module: `Wilder Cosmos <version>`, `Module name`,
      `Module Path`.
- [ ] `Summary`, `Simile`, `Memory note` and `Flow` lines are present.
- [ ] Every proc has a `# Flow:` comment directly above it.
- [ ] The module ends with the standard footer (COMMENT_STYLE.md §7).

## Acronym Expansion

- [ ] "Neurodivergent (ND)" is spelled out on first use in every file.
- [ ] Every other acronym is spelled out on first use, for example Model Context
      Protocol (MCP).
- [ ] ND always means Neurodivergent, never non-deterministic.
- [ ] Code uses full words for names, with minimal abbreviations.
- [ ] Every abbreviation a code file uses, including name prefixes, is listed in an
      "Abbreviations used in this file" comment near its header.

## Plain Language

- [ ] Short sentences, plain words, one idea per sentence.
- [ ] No figurative or emotional language in procedural text.
- [ ] Determinism is stated wherever it matters ("deterministic" or
      "non-deterministic", written in full).

## Review Sign-Off

- [ ] The relevant tests pass in `nimble test`.
- [ ] STATUS.md reflects the change if it affects the current state or next tasks.
- [ ] The compliance matrix is updated if a requirement's status changed.
- [ ] New or retired words are updated in `docs/public/glossary/cosmos-terms.md`.
- [ ] `docs/implementation/MVP-PLAIN-LANGUAGE.md` matches any change to the MVP
      requirements or specification.
- [ ] Anything cut from the MVP has an entry in `docs/implementation/FUTURE-UPDATES.md`.
- [ ] `docs/implementation/MVP-REASONING.md` records the reason for any new or changed
      design choice.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
