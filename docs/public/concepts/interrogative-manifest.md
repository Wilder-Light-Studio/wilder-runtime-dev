# Interrogative Manifest

What this is. This page explains the manifest: the one file that declares a Concept.

## One Form for Every Concept

Every Concept is declared the same way, in a `manifest.json` file inside a bundle
folder (MVP-INT-5). The file doesn't depend on any programming language. Code may
generate it, but the file is the declaration.

The keys are uppercase:

| Key | Meaning | Required |
|---|---|---|
| `WHO` | Identity. Also the Concept's id. | Yes |
| `WHY` | Purpose. | Yes, on the Concept or the Thing |
| `VERSION` | The Concept's version. | Expected (`startapp` writes it) |
| `WHAT`, `WHERE`, `WHEN`, `HOW` | Description, location, timing, mechanism. | No |
| `REQUIRES` | Other Concepts it depends on. | No |
| `WANTS` | What it accepts, with signatures. | No |
| `PROVIDES` | What it offers, with signatures. | No |
| `WITH` | What it works alongside. | No |
| `SENSES` | The kinds of wave it perceives. | No |
| `IMPLEMENTATION` | Its code, for a Concept with no parts. | One of these two |
| `PARTS` and `WIRES` | The Concepts it's built from and how they connect. | One of these two |

## Validation Rules

- WHO must be present and non-empty.
- WHY must be present on the Concept, or on the Thing made from it. A Thing's own WHY
  overrides its Concept's.
- Missing optional keys aren't errors. Keys that are present must be valid.
- A `PROVIDES` contract is declared once, by the provider. Other Concepts refer to it
  as `Thing.provide` and never repeat its signature.
- Every wire is checked when the Concept loads: each destination's WANTS must accept
  what the wire carries.

## A Composite Example

```json
{
  "WHO": "synth",
  "WHY": "Play notes from a keyboard",
  "VERSION": "0.1.0",
  "PARTS": [
    {"name": "keys", "concept": "midi-keys"},
    {"name": "osc", "concept": "oscillator"}
  ],
  "WIRES": [
    {"from": "keys.notes", "to": ["osc"]}
  ]
}
```

The WIRES entry is the form the specification fixes. The shape of a PARTS entry is a
sketch until Phase 3 settles it.

## Building Status

The manifest keys WHO, WHAT, WHY, WHERE, WHEN and HOW, plus REQUIRES, WANTS,
PROVIDES and WITH, exist in code today (`src/cosmos/core/manifest.nim`). VERSION,
SENSES, IMPLEMENTATION, PARTS and WIRES, and the single bundle format, arrive in
Phase 3 ([MVP-SPECIFICATION.md](../../implementation/MVP-SPECIFICATION.md) §4B).

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
