# ND Documentation and Public API Comment Style Guide

This guide defines the standards for documenting public APIs and writing comments in the Wilder Cosmos Nim runtime, with a focus on Neurodivergent (ND) accessibility and New Developer onboarding.


**ND means Neurodivergent (ND) throughout all Wilder Cosmos documentation and code.**

*ND must always be expanded as "Neurodivergent (ND)" on first use in every file, including source, documentation, comments, help text, templates, tests, plans, and walkthroughs. Do not use ND to mean Non-Determinist or Non-Deterministic. If you need to refer to determinism, always write out "deterministic" or "non-deterministic" in full.*

This document must remain aligned with the code comment rules in `docs/implementation/REQUIREMENTS.md`.

## 1. General Principles
- **Beginner-first:** Assume the reader is new to Nim and the Cosmos runtime.
- **Entry-level baseline:** Assume readers understand entry-level programming
  concepts (variables, functions, control flow, and basic data structures),
  but not project-specific architecture.
- **Acronym expansion (global rule):** Every acronym or initialialism must be
  written out in full on its first appearance in every file — source, doc,
  comment, help text, template, test, plan, or walkthrough — with the short
  form in parentheses immediately after. Example: `Interface Model (IM)`.
  All subsequent uses in the same file may use the short form alone.
  No exceptions. This rule applies everywhere without qualification.
- **Similes and analogies:** Use concise, professional comparisons grounded
  in technical or operational contexts. Avoid poetic, theatrical, or
  emotionally loaded metaphors.
- **Memory notes:** Add reminders for why a design exists or what to watch
  out for.
- **Determinism reminders:** Note when an API or function is deterministic
  or not.
- **Explicitness:** Avoid hidden behavior; state all side effects.
- **Plain procedural style:** Use professional, plain, instruction-oriented
  language.
- **Avoid ambiguity:** Do not use esoteric, emotional, or ambiguous wording
  in procedural comments.

## 2. Required Nim Comment Structure

Every `.nim` module must begin with these identity header lines:
- `# Wilder Cosmos <version>`
- `# Module name: <module name>`
- `# Module Path: <workspace-relative path>`

Every `.nim` module must include a module header comment block containing all four tags:
- `Summary`
- `Simile`
- `Memory note`
- `Flow`

Every `proc` declaration must have a directly preceding `Flow` comment line.

These are mandatory compliance requirements, not optional style suggestions.

## 3. Public API Comment Guidance

For exported procs and types:
- Add a doc comment describing purpose, parameters, and return value.
- Include a minimal usage example when practical.
- Explain streaming behavior for APIs that handle large payloads (for example blobs larger than 64KB).

## 4. Examples

Module header example:

```nim
# Wilder Cosmos 0.1.1
# Module name: API
# Module Path: runtime/api.nim
#
# Summary: Provide snapshot export and import helpers for runtime persistence.
# Simile: Like writing and restoring a checkpoint in a long-running service.
# Memory note: Keep schema and checksum validation in sync with persistence metadata.
# Flow: Validate request, stream data, then return structured success or error.
```

Template and generation workflow:
- Header templates live in `templates/headers/`.
- Use `scripts/dev/new_nim_module.ps1` to generate new modules with compliant
  headers and standard footer.

Proc-level Flow example:

```nim
# Flow: Validate destination stream, emit snapshot chunks, and return completion status.
proc exportSnapshot*(dest: Stream): bool
```

## 5. Accessibility

Use plain language and avoid jargon.
Prefer short sentences and bullet lists.
Add TODO markers for unclear or complex sections that need follow-up.

## 6. Line Length and Wrapping

- **Code lines:** Wrap code and inline examples at 80 characters. This includes Nim source, example snippets, and signature lines in docs.
- **Comment lines:** Prefer 80-character wraps for comments and documentation paragraphs to improve readability in narrow terminals and diff views.
- **Automated formatting:** When possible, run your formatter or wrapping tool on code and examples before committing. If wrapping a long identifier or signature would reduce clarity, prefer breaking after logical separators (commas, operators) and keep each continued line indented.

---

## 7. Module Footer

Every `.nim` module must end with the standard Wilder footer block:

```nim
# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
```

The footer must be the last thing in the file, after all code and
comments. No trailing blank lines after the footer.

---

## 8. Document Footer

Every `.md` document must end with the standard Wilder document footer:

```
---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
```

The footer must follow a horizontal rule (`---`) and be the last
content in the file.

---

All PRs must follow this guide for new public APIs and documentation.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
