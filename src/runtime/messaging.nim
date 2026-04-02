# Wilder Cosmos 0.4.0
# Module name: messaging
# Module Path: src/runtime/messaging.nim
#
# messaging.nim
# Runtime message envelope dispatch and mode-aware introspection.
# Summary: Validate inbound envelopes and dispatch payloads with debug-safe logging.
# Simile: messaging dispatch is a gatekeeper that checks shape before routing.
# Memory note: validate before dispatch; never leak full payloads in production logs.
# Flow: validate envelope -> optional debug log -> dispatch payload.

import json
import config
import validation

type
  MessageEnvelope* = object
    id*: string
    `type`*: string
    version*: int
    timestamp*: int64
    payload*: JsonNode

  MessageDispatcher* = proc (payload: JsonNode): bool
  MessageLogger* = proc (msg: string)

# Flow: Convert MessageEnvelope object to JSON for validation.
proc envelopeToJson*(env: MessageEnvelope): JsonNode =
  ## Map envelope object to JSON for validation and optional logging.
  result = %*{
    "id": env.id,
    "type": env.`type`,
    "version": env.version,
    "timestamp": env.timestamp,
    "payload": env.payload
  }

# Flow: Validate envelope fields, optionally log, then dispatch payload.
proc dispatchEnvelope*(env: MessageEnvelope,
    cfg: RuntimeConfig,
    dispatch: MessageDispatcher,
    logger: MessageLogger): bool =
  ## Validate and dispatch message envelope with debug-safe logging.
  discard validateNonEmpty(env.id)
  discard validateNonEmpty(env.`type`)
  discard validateRange(env.version, 1, high(int))

  let envJson = envelopeToJson(env)
  discard validateStructure(envJson, @["id", "type", "version", "timestamp", "payload"])

  if cfg.mode == rmDebug:
    let safeLog = %*{"id": env.id, "type": env.`type`, "version": env.version, "timestamp": env.timestamp}
    logger("dispatchEnvelope(debug): " & $safeLog)

  return dispatch(env.payload)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
