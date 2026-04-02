# Documentation Guide

This folder contains the reference documents that define, explain, and track the
Wilder Cosmos Runtime.

If you are new to the project, use this page as the starting point.

Primary landing page: `index.md`.

Public newcomer docs: `public/index.md`.

## Start Here

- `index.md`
  Documentation landing page for both newcomer and implementation lanes.

- `public/index.md`
  Newcomer-facing documentation set for onboarding and module development.

- `REQUIREMENTS.md`
  The canonical statement of what must be true for the runtime to be correct.

- `SPECIFICATION-NIM.md`
  The implementation-oriented specification that supports the requirements.

- `PLAN.md`
  The chapter-by-chapter implementation plan and current execution order.

- `IMPLEMENTATION-DETAILS.md`
  Supporting notes for how major areas are expected to be built.

- `DEVELOPMENT-GUIDELINES.md`
  The standard workflow for making changes, updating evidence, and keeping the
  repository compliant.

## Supporting Documents

- `MODULES.md`
  Explains the difference between `modules/` and `runtime_modules/`.

- `COMPLIANCE-MATRIX.md`
  Maps requirement areas to verification methods and artifacts.

- `COMMENT_STYLE.md`
  Project guidance for source comments and documentation style.

- `COSMOS_UNINTEGRATED_TERMS.md`
  Vocabulary notes and terms that are not yet integrated into the main
  requirements set.

## Implementation Walkthroughs

The `docs/implementation/` directory contains chapter-based walkthroughs, plans, and
supporting implementation notes.

These files are most useful when you are working on a specific chapter or trying
to understand how a requirement area was translated into code and tests.

## How to Use the Docs

For a high-level introduction:

1. Read `REQUIREMENTS.md`.
2. Read `SPECIFICATION-NIM.md`.
3. Review `PLAN.md`.

For active development work:

1. Read the affected requirement section.
2. Check `COMPLIANCE-MATRIX.md`.
3. Follow `DEVELOPMENT-GUIDELINES.md`.
4. Review the matching chapter materials under `docs/implementation/`.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*