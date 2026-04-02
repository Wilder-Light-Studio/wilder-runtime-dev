# Config And Transport

What this is. This page describes runtime configuration fields and how transport selection affects serialization.

## Core Config Fields

Runtime config includes:

- mode
- transport
- log level
- endpoint
- port

Validation rejects invalid combinations and bad bounds at load time.

## Override Precedence

Configuration precedence is:

1. config file
2. environment variables
3. CLI overrides

## Transport Selection

Transport chooses serializer kind at startup:

- JSON transport -> JSON serializer
- Protobuf transport -> Protobuf serializer

Transport choice is a startup decision, not a per-message switch.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
