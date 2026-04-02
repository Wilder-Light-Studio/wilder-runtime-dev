# Serialization

What this is. This page explains how payloads are wrapped and verified during serialization.

## Envelope Contract

Serialization uses envelope metadata with fields such as:

- schema version
- payload
- checksum
- timestamp
- origin

On unwrap, checksum is recomputed and validated.

## Serializer Kinds

- JSON serializer
- Protobuf serializer

Selection is made from runtime transport configuration.

## Current Boundary

In current code, Protobuf serializer methods raise errors when generated bindings are unavailable. This is an explicit stop, not a silent fallback.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
