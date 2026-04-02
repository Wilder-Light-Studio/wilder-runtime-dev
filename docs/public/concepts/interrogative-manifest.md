# Interrogative Manifest

What this is. This page explains when an Interrogative Manifest is needed and how it validates.

## Minimal Concept Requirements

A Concept requires only:

- WHO expressed as identity through a unique Concept id
- WHY expressed as purpose or description

A Thing requires only identity.

Everything else is world-defined and optional until a manifest is attached.

## Interrogative Manifest Behavior

The Interrogative Manifest is optional.

If no manifest is present, a Concept is valid as long as identity and WHY exist.

If a manifest is present, it must fully declare:

- WHO
- WHAT
- WHY
- WHERE
- WHEN
- HOW
- REQUIRES
- WANTS
- PROVIDES
- WITH

## Validation Rules

- No manifest means the Concept stays on the minimal WHO + WHY contract.
- A present manifest must be complete.
- String fields must be non-empty.
- Sequence fields must be non-empty and cannot contain empty values.
- Specialist manifests must have non-empty PROVIDES and REQUIRES.

## Why This Exists

The manifest gives a stable query surface for interpretation and matching when a world needs one. It is not the source of identity. It is an optional, explicit contract surface layered on top of the minimal ontology.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
