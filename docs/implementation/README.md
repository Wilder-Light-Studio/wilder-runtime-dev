# Documentation Guide

This folder contains the documents that define, explain and track the Wilder Cosmos
Runtime. The full list is in [index.md](index.md). Newcomer docs are in
[../public/index.md](../public/index.md).

## Source order

1. [MVP-REQUIREMENTS.md](MVP-REQUIREMENTS.md): what must be true.
2. [MVP-SPECIFICATION.md](MVP-SPECIFICATION.md): how it's met, and in which phase.
3. [MVP-COMPLIANCE-MATRIX.md](MVP-COMPLIANCE-MATRIX.md): what's proven so far.

When an MVP file and [REQUIREMENTS.md](REQUIREMENTS.md) or
[SPECIFICATION.md](SPECIFICATION.md) disagree, the MVP file governs. Each MVP rule
cites the old section it builds on, and marks real changes as **Departs**.

## Reading order

Returning after a break:

1. [../../STATUS.md](../../STATUS.md): current focus and next tasks (about 30 seconds).
2. The matrix rows for the area you're working on.
3. The matching requirement and spec sections.

New to the project:

1. [../../README.md](../../README.md): overview and quick start.
2. [MVP-REQUIREMENTS.md](MVP-REQUIREMENTS.md), section 1 (Ontology), then the rest.
3. [MVP-SPECIFICATION.md](MVP-SPECIFICATION.md).

## Making a change

1. Read the affected requirement.
2. Check its row in the matrix.
3. Follow [DEVELOPMENT-GUIDELINES.md](DEVELOPMENT-GUIDELINES.md).
4. When a requirement's status changes, update the matrix and, if needed,
   `tests/KNOWN_FAILURES.txt` in the same change.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
