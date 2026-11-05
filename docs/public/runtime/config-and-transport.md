# Config And Transport

What this is. This page describes runtime configuration and how transport selection
affects serialization.

## Config Is Optional

With no config file, Cosmos starts on documented defaults (MVP-CFG-1). Config is a
JSON file. Cue schemas are no longer used.

## Core Config Fields

- `mode`: `development`, `debug` or `production`
- `transport`: how payloads are serialized (JSON in the MVP)
- `logLevel`
- `endpoint`
- `port`: the daemon's port, default 7700

Every value, whatever its source, passes the same validation. Invalid config is
rejected at load time with a structured error.

## Override Precedence

Lowest to highest:

1. defaults
2. the config file
3. environment variables: `COSMOS_MODE`, `COSMOS_LOG_LEVEL`, `COSMOS_PORT`
4. command-line flags

Subsystems receive one loaded config object and never read config files themselves.

**Until Phase 2:** the daemon and the `cosmos` command ignore the configured port and
always use 7700.

## Two Meanings of "mode"

Config `mode` (`COSMOS_MODE`) is `development`, `debug` or `production`. The
`cosmos start --mode` flag is different: it chooses how frames run (`step`,
`continuous` or `periodic`). Renaming one of them is a later decision.

## Transport Selection

Transport chooses the serializer at startup, not per message. The MVP uses JSON
only. Protobuf transport is deferred: its code remains, but it raises an error when
generated bindings are missing.

---
*&copy; 2026 Wilder. All rights reserved.*\
*Contact: teamwilder@wildercode.org*\
*Licensed under the Wilder Foundation License 1.0.*\
*See LICENSE for details.*
