# Wilder Cosmos 0.4.0
# Module name: serialization
# Module Path: src/runtime/serialization.nim
#
# Summary: Serialization envelopes with deterministic checksums and serializer abstractions.
# Simile: Like a certified shipping label wrapping any payload with provenance, version, seal.
# Memory note: Always recalculate and validate SHA256 checksums on wrap and unwrap.
# Flow: wrap payload -> compute checksum -> return envelope; unwrap -> validate checksum.
## serialization.nim
## Module: Serialization
## Purpose: Implements serialization envelopes with deterministic
## checksums and serializer abstractions.
##
## Overview:
## This module provides the foundation for serializing and deserializing data in
## the Wilder Cosmos Runtime. It includes:
## - `SerializerKind`: Enum for supported serialization formats (JSON, Protobuf).
## - `Serializer`: Base type for serializer implementations.
## - `envelopeWrap`: Function to wrap data with metadata and checksum.
## - `envelopeUnwrap`: Function to validate and extract data from an envelope.
##
## Key Concepts:
## - **Envelope**: A wrapper for data that includes metadata (e.g., schema
##   version, timestamp, checksum).
## - **Checksum**: Ensures data integrity by validating that the serialized data
##   has not been tampered with.
## - **Serializer Abstraction**: Provides a common interface for different
##   serialization formats.
##
## Usage:
## - Use `envelopeWrap` to serialize and wrap data with metadata.
## - Use `envelopeUnwrap` to validate and extract the original data.
##
## Example:
## ```nim
## let env = envelopeWrap(%*{"x": 1}, 1)
## let payload = envelopeUnwrap(env)
## ```

import json, times
import std/jsonutils
import validation
import config

## Serializer abstraction types (SPEC §24, §23.1)
type
  SerializerKind* = enum
    skJson      ## JSON serializer (human-readable, debug)
    skProtobuf  ## Protobuf serializer (binary, production)

  Serializer* = ref object of RootObj
    ## Base type for serializers. Implementations inherit and override
    ## encode* and decode* procs.
    kind*: SerializerKind

  JsonSerializer* = ref object of Serializer
  ProtobufSerializer* = ref object of Serializer

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stringToBytes(s: string): seq[byte] =
  ## Flow: convert string to byte sequence for hashing.
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc bytesToString(data: openArray[byte]): string =
  ## Flow: convert byte sequence to string for JSON decoding.
  result = newString(data.len)
  for i in 0 ..< data.len:
    result[i] = char(data[i])

## Wrap `data` with metadata and SHA256 checksum.
## Flow: serialize data, compute checksum, create envelope with metadata.
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc envelopeWrap*(data: JsonNode, schemaVersion: int): JsonNode =
  if schemaVersion <= 0:
    raise newException(ValueError,
      "envelopeWrap: schemaVersion must be positive")

  let serializedData = $data
  let checksum = computeSha256(stringToBytes(serializedData))
  let currentTime = now().utc()
  let envTimestamp = currentTime.format("yyyy-MM-dd'T'HH:mm:ss'Z'")

  result = %*{
    "schemaVersion": schemaVersion,
    "payload": data,
    "checksum": checksum,
    "timestamp": envTimestamp,
    "origin": "runtime"
  }

## Extract and verify the `payload` from an envelope.
## Flow: validate structure, verify checksum, return payload.
## Raises: ValueError if envelope is invalid or checksum fails.
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc envelopeUnwrap*(env: JsonNode): JsonNode =
  discard validateStructure(env, @["schemaVersion", "payload", "checksum", "timestamp", "origin"])

  let checksumNode = env["checksum"]
  if checksumNode.kind != JString:
    raise newException(ValueError,
      "envelopeUnwrap: 'checksum' must be string")

  let payload = env["payload"]
  let checksum = checksumNode.getStr()

  # Compute checksum and verify.
  let serializedPayload = $payload
  discard validateChecksum(stringToBytes(serializedPayload), checksum)

  result = payload

## Serialize typed payload to envelope with checksum metadata.
## Flow: convert type to JSON payload, envelope-wrap, return JsonNode envelope.
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc serializeWithEnvelope*[T](value: T, schemaVersion: int): JsonNode =
  let payload = value.toJson()
  result = envelopeWrap(payload, schemaVersion)

## Deserialize typed payload from validated checksum envelope.
## Flow: validate envelope, decode payload into target type, return value.
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc deserializeWithEnvelope*[T](env: JsonNode): T =
  let payload = envelopeUnwrap(env)
  try:
    result = payload.to(T)
  except CatchableError:
    raise newException(ValueError,
      "deserializeWithEnvelope: payload does not match target type")


# Serializer implementations (stub; full impl in Ch 2B)
method encode*(s: Serializer, msg: JsonNode): seq[byte] {.base.} =
  ## Encode a message. Override in subclasses.
  raise newException(ValueError, "encode must be implemented by subclass")

method decode*(s: Serializer, data: seq[byte]): JsonNode {.base.} =
  ## Decode binary data to JsonNode. Override in subclasses.
  raise newException(ValueError, "decode must be implemented by subclass")

method encode*(s: JsonSerializer, msg: JsonNode): seq[byte] =
  ## Flow: serialize JSON node to bytes for transport.
  result = stringToBytes($msg)

method decode*(s: JsonSerializer, data: seq[byte]): JsonNode =
  ## Flow: parse transport bytes as JSON payload.
  let raw = bytesToString(data)
  discard validateNonEmpty(raw)
  result = parseJson(raw)

method encode*(s: ProtobufSerializer, msg: JsonNode): seq[byte] =
  ## Flow: reject Protobuf usage when bindings are unavailable.
  raise newException(ValueError,
    "encode: protobuf serializer requires generated bindings")

method decode*(s: ProtobufSerializer, data: seq[byte]): JsonNode =
  ## Flow: reject Protobuf usage when bindings are unavailable.
  raise newException(ValueError,
    "decode: protobuf serializer requires generated bindings")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc selectSerializer*(transport: TransportKind): Serializer =
  ## Flow: choose serializer once at startup from validated RuntimeConfig transport.
  case transport
  of tkJson:
    return JsonSerializer(kind: skJson)
  of tkProtobuf:
    return ProtobufSerializer(kind: skProtobuf)

when isMainModule:
  echo "Testing envelopeWrap and envelopeUnwrap..."
  let env = envelopeWrap(%*{"x": 1}, 1)
  echo "Envelope:", env
  let payload = envelopeUnwrap(env)
  echo "Unwrapped Payload:", payload



# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
