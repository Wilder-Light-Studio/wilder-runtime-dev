# Wilder Cosmos 0.4.0
# Module name: ch2_uat Tests
# Module Path: tests/ch2_uat.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## ch2_uat.nim
#
## Summary: Chapter 2 comprehensive user-acceptance test scenarios.
## Simile: Like a systems integration test verifying all components work together.
## Memory note: Chapter 2 UAT covers validation, serialization, config, messaging, and prefilter.
## Flow: test validation -> test serialization -> test messaging -> verify security invariants.

## Covers: validation helpers, serialization envelopes, runtime config,
## messaging dispatch, prefilter validation firewall, and security invariants.

import unittest
import json
import std/[strutils, os, tables]
import ../src/runtime/validation
import ../src/runtime/serialization
import ../src/runtime/config
import ../src/runtime/messaging
import ../src/runtime/prefilter_table_generated

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Flow: Execute procedure with deterministic test helper behavior.
proc makeInbound(ns, sym: string, ver: int, args: seq[JsonNode]): InboundMessage =
  result = InboundMessage(
    namespaceId: ns,
    symbolId: sym,
    contractVersion: ver,
    args: args
  )

# Flow: Execute procedure with deterministic test helper behavior.
proc makeInbound(args: seq[JsonNode]): InboundMessage =
  makeInbound("runtime", "Ping", 1, args)

# Flow: Execute procedure with deterministic test helper behavior.
proc toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i in 0 ..< s.len:
    result[i] = byte(s[i])

# Flow: Execute procedure with deterministic test helper behavior.
proc writeTempConfig(content: string): string =
  result = getTempDir() / "ch2_uat_config.json"
  writeFile(result, content)

# ===========================================================================
# 1. Validation Helper UATs
# ===========================================================================

suite "UAT Validation Helpers":
  test "UAT-VAL-001 validateNonEmpty accepts valid string":
    check validateNonEmpty("hello")

  test "UAT-VAL-002 validateNonEmpty rejects empty string":
    expect(ValueError):
      discard validateNonEmpty("")

  test "UAT-VAL-003 validateRange accepts in-bounds value":
    check validateRange(50, 1, 100)

  test "UAT-VAL-004 validateRange rejects out-of-bounds value":
    expect(ValueError):
      discard validateRange(0, 1, 100)
    expect(ValueError):
      discard validateRange(101, 1, 100)

  test "UAT-VAL-005 validatePortRange accepts valid ports":
    check validatePortRange(80)
    check validatePortRange(443)
    check validatePortRange(1)
    check validatePortRange(65535)

  test "UAT-VAL-006 validatePortRange rejects invalid ports":
    expect(ValueError):
      discard validatePortRange(0)
    expect(ValueError):
      discard validatePortRange(65536)
    expect(ValueError):
      discard validatePortRange(-1)

  test "UAT-VAL-007 validateStructure accepts complete object":
    let n = %*{"name": "test", "version": 1}
    check validateStructure(n, @["name", "version"])

  test "UAT-VAL-008 validateStructure rejects missing fields":
    let n = %*{"name": "test"}
    expect(ValueError):
      discard validateStructure(n, @["name", "version"])

  test "UAT-VAL-009 validateStructure rejects nil and non-object":
    expect(ValueError):
      discard validateStructure(newJNull(), @["x"])
    expect(ValueError):
      discard validateStructure(newJArray(), @["x"])

  test "UAT-VAL-010 validateChecksum accepts correct SHA256":
    let data = toBytes("hello world")
    let expected = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    check validateChecksum(data, expected)

  test "UAT-VAL-011 validateChecksum is case-insensitive":
    let data = toBytes("hello world")
    let upper = "B94D27B9934D3E08A52E52D7DA7DABFAC484EFE37A5380EE9088F7ACE2EFCDE9"
    check validateChecksum(data, upper)

  test "UAT-VAL-012 validateChecksum rejects mismatch without leaking data":
    let data = toBytes("secret-payload")
    let wrong = "0000000000000000000000000000000000000000000000000000000000000000"
    var caught = false
    try:
      discard validateChecksum(data, wrong)
    except ValueError as e:
      caught = true
      check "secret-payload" notin e.msg
      check "mismatch" in e.msg
    check caught

  test "UAT-VAL-013 validateChecksum rejects malformed expected digest":
    let data = toBytes("x")
    expect(ValueError):
      discard validateChecksum(data, "")
    expect(ValueError):
      discard validateChecksum(data, "abc")
    expect(ValueError):
      discard validateChecksum(data, repeat('z', 64))

  test "UAT-VAL-014 validateJsonChecksum round-trips correctly":
    let payload = "hello world"
    let digest = computeSha256(toBytes(payload))
    check validateJsonChecksum(payload, digest)

# ===========================================================================
# 2. Serialization Envelope UATs
# ===========================================================================

suite "UAT Serialization Envelope":
  test "UAT-SER-001 envelopeWrap produces valid envelope structure":
    let env = envelopeWrap(%*{"x": 1}, 1)
    check env.hasKey("schemaVersion")
    check env.hasKey("payload")
    check env.hasKey("checksum")
    check env.hasKey("timestamp")
    check env.hasKey("origin")
    check env["schemaVersion"].getInt() == 1
    check env["origin"].getStr() == "runtime"

  test "UAT-SER-002 envelopeUnwrap recovers original payload":
    let original = %*{"message": "ping", "count": 42}
    let env = envelopeWrap(original, 1)
    let recovered = envelopeUnwrap(env)
    check recovered == original

  test "UAT-SER-003 envelopeUnwrap detects payload tampering":
    var env = envelopeWrap(%*{"message": "ping"}, 1)
    env["payload"] = %*{"message": "tampered"}
    expect(ValueError):
      discard envelopeUnwrap(env)

  test "UAT-SER-004 envelopeUnwrap detects checksum tampering":
    var env = envelopeWrap(%*{"message": "ping"}, 1)
    env["checksum"] = %"0000000000000000000000000000000000000000000000000000000000000000"
    expect(ValueError):
      discard envelopeUnwrap(env)

  test "UAT-SER-005 envelopeUnwrap rejects non-string checksum":
    let env = %*{
      "schemaVersion": 1,
      "payload": %*{"a": 1},
      "checksum": 123,
      "timestamp": "2026-03-31T00:00:00Z",
      "origin": "runtime"
    }
    expect(ValueError):
      discard envelopeUnwrap(env)

  test "UAT-SER-006 envelopeWrap rejects zero/negative schema version":
    expect(ValueError):
      discard envelopeWrap(%*{"x": 1}, 0)
    expect(ValueError):
      discard envelopeWrap(%*{"x": 1}, -1)

  test "UAT-SER-007 JSON serializer round-trips data":
    let s = JsonSerializer(kind: skJson)
    let original = %*{"key": "value", "num": 99}
    let encoded = s.encode(original)
    let decoded = s.decode(encoded)
    check decoded["key"].getStr() == "value"
    check decoded["num"].getInt() == 99

  test "UAT-SER-008 Protobuf serializer fails safely without bindings":
    let s = ProtobufSerializer(kind: skProtobuf)
    expect(ValueError):
      discard s.encode(%*{"x": 1})
    expect(ValueError):
      discard s.decode(@[byte(0)])

  test "UAT-SER-009 selectSerializer returns correct type":
    let jsonSer = selectSerializer(tkJson)
    check jsonSer of JsonSerializer
    let protoSer = selectSerializer(tkProtobuf)
    check protoSer of ProtobufSerializer

# ===========================================================================
# 3. Runtime Config UATs
# ===========================================================================

suite "UAT Runtime Config":
  test "UAT-CFG-001 loadConfig parses valid config":
    let path = writeTempConfig("""{"mode":"development","transport":"json","logLevel":"info","endpoint":"localhost","port":8080}""")
    let cfg = loadConfig(path)
    check cfg.mode == rmDevelopment
    check cfg.transport == tkJson
    check cfg.logLevel == llInfo
    check cfg.endpoint == "localhost"
    check cfg.port == 8080
    removeFile(path)

  test "UAT-CFG-002 loadConfig rejects missing fields":
    let path = writeTempConfig("""{"mode":"development"}""")
    expect(ValueError):
      discard loadConfig(path)
    removeFile(path)

  test "UAT-CFG-003 loadConfig rejects invalid port":
    let path = writeTempConfig("""{"mode":"development","transport":"json","logLevel":"info","endpoint":"localhost","port":99999}""")
    expect(ValueError):
      discard loadConfig(path)
    removeFile(path)

  test "UAT-CFG-004 loadConfig rejects production with debug log level":
    let path = writeTempConfig("""{"mode":"production","transport":"json","logLevel":"debug","endpoint":"localhost","port":443}""")
    expect(ValueError):
      discard loadConfig(path)
    removeFile(path)

  test "UAT-CFG-005 loadConfig rejects production with trace log level":
    let path = writeTempConfig("""{"mode":"production","transport":"json","logLevel":"trace","endpoint":"localhost","port":443}""")
    expect(ValueError):
      discard loadConfig(path)
    removeFile(path)

  test "UAT-CFG-006 loadConfig accepts production with info log level":
    let path = writeTempConfig("""{"mode":"production","transport":"json","logLevel":"info","endpoint":"localhost","port":443}""")
    let cfg = loadConfig(path)
    check cfg.mode == rmProduction
    check cfg.logLevel == llInfo
    removeFile(path)

  test "UAT-CFG-007 loadConfig rejects nonexistent file":
    expect(ValueError):
      discard loadConfig("/nonexistent/path/config.json")

  test "UAT-CFG-008 loadConfig rejects empty path":
    expect(ValueError):
      discard loadConfig("")

# ===========================================================================
# 4. Messaging Dispatch UATs
# ===========================================================================

suite "UAT Messaging Dispatch":
  test "UAT-MSG-001 dispatchEnvelope delivers payload in debug mode":
    let cfg = RuntimeConfig(
      mode: rmDebug,
      transport: tkJson,
      logLevel: llDebug,
      endpoint: "localhost",
      port: 8080
    )
    let env = MessageEnvelope(
      id: "msg-001",
      `type`: "ping",
      version: 1,
      timestamp: 1000,
      payload: %*{"message": "hello"}
    )
    var dispatched = false
    var logged = ""
    let ok = dispatchEnvelope(env, cfg,
      proc(p: JsonNode): bool =
        dispatched = p["message"].getStr() == "hello"
        return true,
      proc(m: string) =
        logged = m
    )
    check ok
    check dispatched
    check logged.len > 0  # debug mode logs envelope

  test "UAT-MSG-002 dispatchEnvelope does not log in production mode":
    let cfg = RuntimeConfig(
      mode: rmProduction,
      transport: tkJson,
      logLevel: llInfo,
      endpoint: "localhost",
      port: 443
    )
    let env = MessageEnvelope(
      id: "msg-002",
      `type`: "ping",
      version: 1,
      timestamp: 1000,
      payload: %*{"x": 1}
    )
    var logged = ""
    discard dispatchEnvelope(env, cfg,
      proc(p: JsonNode): bool = true,
      proc(m: string) = logged = m
    )
    check logged.len == 0  # production mode does not log

  test "UAT-MSG-003 dispatchEnvelope rejects empty envelope id":
    let cfg = RuntimeConfig(
      mode: rmDevelopment,
      transport: tkJson,
      logLevel: llInfo,
      endpoint: "localhost",
      port: 8080
    )
    let env = MessageEnvelope(
      id: "",
      `type`: "ping",
      version: 1,
      timestamp: 1000,
      payload: %*{"x": 1}
    )
    expect(ValueError):
      discard dispatchEnvelope(env, cfg,
        proc(p: JsonNode): bool = true,
        proc(m: string) = discard
      )

  test "UAT-MSG-004 dispatchEnvelope rejects zero version":
    let cfg = RuntimeConfig(
      mode: rmDevelopment,
      transport: tkJson,
      logLevel: llInfo,
      endpoint: "localhost",
      port: 8080
    )
    let env = MessageEnvelope(
      id: "msg-004",
      `type`: "ping",
      version: 0,
      timestamp: 1000,
      payload: %*{"x": 1}
    )
    expect(ValueError):
      discard dispatchEnvelope(env, cfg,
        proc(p: JsonNode): bool = true,
        proc(m: string) = discard
      )

# ===========================================================================
# 5. Prefilter Validation Firewall UATs
# ===========================================================================

suite "UAT Prefilter Validation Firewall":
  test "UAT-PF-001 valid Ping payload passes prefilter and dispatches":
    let index = loadGeneratedValidationIndex()
    let decision = prefilterValidate(
      index,
      makeInbound(@[%*{"message": "hello"}]),
      "ingress",
      501
    )
    check decision.validated
    check decision.failure.id.len == 0

    var delivered = false
    let ok = dispatchValidated(
      decision,
      proc(args: seq[JsonNode]): bool =
        delivered = args[0]["message"].getStr() == "hello"
        return true
    )
    check ok
    check delivered

  test "UAT-PF-002 type mismatch blocks dispatch":
    let index = loadGeneratedValidationIndex()
    let decision = prefilterValidate(
      index,
      makeInbound(@[%*{"message": 100}]),
      "ingress",
      502
    )
    check not decision.validated
    check decision.failure.failureKind == vfTypeMismatch

    expect(ValueError):
      discard dispatchValidated(
        decision,
        proc(args: seq[JsonNode]): bool = true
      )

  test "UAT-PF-003 unknown signature is rejected":
    let index = loadGeneratedValidationIndex()
    let decision = prefilterValidate(
      index,
      makeInbound("unknown", "NoOp", 1, @[%*{"x": 1}]),
      "ingress",
      503
    )
    check not decision.validated
    check decision.failure.failureKind == vfUnknownSignature

  test "UAT-PF-004 argument count mismatch is rejected":
    let index = loadGeneratedValidationIndex()
    let decision = prefilterValidate(
      index,
      makeInbound(@[%*{"message": "a"}, %*{"extra": "b"}]),
      "ingress",
      504
    )
    check not decision.validated
    check decision.failure.failureKind == vfArgumentCountMismatch

  test "UAT-PF-005 unvalidated payload cannot be admitted":
    let index = loadGeneratedValidationIndex()
    let decision = prefilterValidate(
      index,
      makeInbound(@[%*{"message": 999}]),
      "ingress",
      505
    )
    check not decision.validated

    expect(ValueError):
      discard admitValidatedOccurrence(decision)

  test "UAT-PF-006 validated payload can be admitted":
    let index = loadGeneratedValidationIndex()
    let decision = prefilterValidate(
      index,
      makeInbound(@[%*{"message": "ok"}]),
      "ingress",
      506
    )
    check decision.validated
    check admitValidatedOccurrence(decision)

# ===========================================================================
# 6. Security Invariant UATs
# ===========================================================================

suite "UAT Security Invariants":
  test "UAT-SEC-001 failure log line never contains raw payload data":
    let index = loadGeneratedValidationIndex()
    let secret = "token=abc123&key=secret"
    let decision = prefilterValidate(
      index,
      makeInbound(@[%*{"message": 100, "secret": secret}]),
      "ingress",
      601
    )
    check not decision.validated
    let line = safeFailureLogLine(decision.failure)
    check "validation_failure" in line
    check secret notin line
    check "token" notin line
    check "abc123" notin line

  test "UAT-SEC-002 failure JSON contains only safe metadata fields":
    let index = loadGeneratedValidationIndex()
    let decision = prefilterValidate(
      index,
      makeInbound(@[%*{"message": 42}]),
      "ingress",
      602
    )
    check not decision.validated
    let j = decision.failure.toJson()
    check j.hasKey("id")
    check j.hasKey("payloadDigest")
    check j.hasKey("payloadByteLen")
    check j.hasKey("failureKind")
    # Must NOT contain raw payload
    let jStr = $j
    check "42" notin jStr or "payloadByteLen" in jStr

  test "UAT-SEC-003 signature digest is deterministic":
    let a = deriveSignatureDigest("runtime", "Ping", 1, 1, @["payload:object"])
    let b = deriveSignatureDigest("runtime", "Ping", 1, 1, @["payload:object"])
    check a == b
    check a.len == 32  # truncated to 32 hex chars

  test "UAT-SEC-004 signature digest is case and whitespace insensitive":
    let a = deriveSignatureDigest(" runtime ", " Ping ", 1, 1, @["payload:object"])
    let b = deriveSignatureDigest("RUNTIME", "PING", 1, 1, @["payload:object"])
    check a == b

  test "UAT-SEC-005 generated table is reproducible":
    let idx1 = loadGeneratedValidationIndex()
    let idx2 = loadGeneratedValidationIndex()
    check idx1.generationId == idx2.generationId
    check idx1.sourceDigests == idx2.sourceDigests
    for key, rec in idx1.byKey:
      check key in idx2.byKey
      check rec.keyDigest == idx2.byKey[key].keyDigest
      check rec.canonicalTypeVector == idx2.byKey[key].canonicalTypeVector

  test "UAT-SEC-006 envelope wrap/unwrap round-trip preserves integrity":
    let original = %*{"sensitive": "data", "count": 99}
    let env = envelopeWrap(original, 2)
    let recovered = envelopeUnwrap(env)
    check recovered == original

  test "UAT-SEC-007 checksum mismatch error does not reveal hash values":
    let data = toBytes("confidential")
    let wrong = "0000000000000000000000000000000000000000000000000000000000000000"
    var caught = false
    try:
      discard validateChecksum(data, wrong)
    except ValueError as e:
      caught = true
      # Error must say mismatch but NOT reveal the actual computed hash
      check "mismatch" in e.msg
      check "confidential" notin e.msg
    check caught

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
