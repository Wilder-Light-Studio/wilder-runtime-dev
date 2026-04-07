# Wilder Cosmos 0.4.0
# Module name: config
# Module Path: src/runtime/config.nim
#
# config.nim
# Runtime configuration loading and validation.
# Summary: Parse Cue-exported JSON config, validate fail-fast, and return typed config.
# Simile: startup config is a contract check before the runtime opens for traffic.
# Memory note: validate once at startup; inject typed config everywhere.
# Flow: load file -> parse JSON -> validate fields -> enforce mode/log constraints -> return.

import json
import std/[os, strutils, options]
import validation

type
  RuntimeMode* = enum
    rmDevelopment
    rmDebug
    rmProduction

  EncryptionMode* = enum
    emClear
    emStandard
    emPrivate
    emComplete

  TransportKind* = enum
    tkJson
    tkProtobuf

  LogLevel* = enum
    llTrace
    llDebug
    llInfo
    llWarn
    llError

  RuntimeConfig* = object
    mode*: RuntimeMode
    encryptionMode*: EncryptionMode
    recoveryEnabled*: bool
    operatorEscrow*: bool
    transport*: TransportKind
    logLevel*: LogLevel
    endpoint*: string
    port*: int

  RuntimeConfigOverrides* = object
    mode*: Option[string]
    encryptionMode*: Option[string]
    recoveryEnabled*: Option[bool]
    operatorEscrow*: Option[bool]
    logLevel*: Option[string]
    port*: Option[int]

var configLoadInvocationCount*: int = 0

# Flow: Normalize text value and map to RuntimeMode.
proc parseRuntimeMode(raw: string): RuntimeMode =
  ## Parse runtime mode from string configuration.
  case raw.toLowerAscii.strip
  of "development": rmDevelopment
  of "debug": rmDebug
  of "production": rmProduction
  else:
    raise newException(ValueError,
      "loadConfig: mode must be one of development|debug|production")

# Flow: Normalize text value and map to EncryptionMode.
proc parseEncryptionMode*(raw: string): EncryptionMode =
  ## Parse encryption mode from string configuration.
  case raw.toLowerAscii.strip
  of "clear": emClear
  of "standard": emStandard
  of "private": emPrivate
  of "complete": emComplete
  else:
    raise newException(ValueError,
      "loadConfig: encryptionMode must be one of clear|standard|private|complete")

# Flow: Convert one encryption mode enum to the canonical configuration string.
proc encryptionModeName*(mode: EncryptionMode): string =
  ## Return the stable text form used in config and persisted runtime metadata.
  case mode
  of emClear: "clear"
  of emStandard: "standard"
  of emPrivate: "private"
  of emComplete: "complete"

# Flow: Normalize text value and map to TransportKind.
proc parseTransportKind(raw: string): TransportKind =
  ## Normalize text value and map to TransportKind.
  case raw.toLowerAscii.strip
  of "json": tkJson
  of "protobuf": tkProtobuf
  else:
    raise newException(ValueError,
      "loadConfig: transport must be one of json|protobuf")

# Flow: Normalize text value and map to LogLevel.
proc parseLogLevel(raw: string): LogLevel =
  ## Normalize text value and map to LogLevel.
  case raw.toLowerAscii.strip
  of "trace": llTrace
  of "debug": llDebug
  of "info": llInfo
  of "warn": llWarn
  of "error": llError
  else:
    raise newException(ValueError,
      "loadConfig: logLevel must be one of trace|debug|info|warn|error")

# Flow: Read config file, parse JSON, validate required fields and constraints.
proc parseRuntimeConfig(n: JsonNode): RuntimeConfig =
  discard validateStructure(n, @["mode", "transport", "logLevel", "endpoint", "port"])

  if "encryptionMode" notin n:
    n["encryptionMode"] = %"standard"
  if "recoveryEnabled" notin n:
    n["recoveryEnabled"] = %false
  if "operatorEscrow" notin n:
    n["operatorEscrow"] = %false

  if n["mode"].kind != JString or
     n["encryptionMode"].kind != JString or
     n["recoveryEnabled"].kind != JBool or
     n["operatorEscrow"].kind != JBool or
     n["transport"].kind != JString or
     n["logLevel"].kind != JString or
     n["endpoint"].kind != JString or
     n["port"].kind != JInt:
    raise newException(ValueError,
      "loadConfig: config fields have invalid types")

  result.mode = parseRuntimeMode(n["mode"].getStr())
  result.encryptionMode = parseEncryptionMode(n["encryptionMode"].getStr())
  result.recoveryEnabled = n["recoveryEnabled"].getBool()
  result.operatorEscrow = n["operatorEscrow"].getBool()
  result.transport = parseTransportKind(n["transport"].getStr())
  result.logLevel = parseLogLevel(n["logLevel"].getStr())
  result.endpoint = n["endpoint"].getStr().strip
  result.port = n["port"].getInt

  discard validateNonEmpty(result.endpoint)
  discard validatePortRange(result.port)

  if result.mode == rmProduction and result.logLevel in {llTrace, llDebug}:
    raise newException(ValueError,
      "loadConfig: production mode does not allow trace/debug log levels")

  case result.encryptionMode
  of emClear:
    if result.recoveryEnabled or result.operatorEscrow:
      raise newException(ValueError,
        "loadConfig: clear mode does not permit recovery or operator escrow")
  of emStandard:
    if result.operatorEscrow and not result.recoveryEnabled:
      raise newException(ValueError,
        "loadConfig: operatorEscrow requires recoveryEnabled in standard mode")
  of emPrivate:
    if result.operatorEscrow:
      raise newException(ValueError,
        "loadConfig: private mode does not permit operator escrow")
  of emComplete:
    if result.operatorEscrow:
      raise newException(ValueError,
        "loadConfig: complete mode does not permit operator escrow")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc applyEnvironmentOverrides(n: var JsonNode) =
  if existsEnv("COSMOS_MODE"):
    let raw = getEnv("COSMOS_MODE").strip
    if raw.len > 0:
      n["mode"] = %raw

  if existsEnv("COSMOS_ENCRYPTION_MODE"):
    let raw = getEnv("COSMOS_ENCRYPTION_MODE").strip
    if raw.len > 0:
      n["encryptionMode"] = %raw

  if existsEnv("COSMOS_LOG_LEVEL"):
    let raw = getEnv("COSMOS_LOG_LEVEL").strip
    if raw.len > 0:
      n["logLevel"] = %raw

  if existsEnv("COSMOS_RECOVERY_ENABLED"):
    let raw = getEnv("COSMOS_RECOVERY_ENABLED").strip.toLowerAscii
    if raw.len > 0:
      case raw
      of "true":
        n["recoveryEnabled"] = %true
      of "false":
        n["recoveryEnabled"] = %false
      else:
        raise newException(ValueError,
          "COSMOS_RECOVERY_ENABLED environment variable must be true or false")

  if existsEnv("COSMOS_OPERATOR_ESCROW"):
    let raw = getEnv("COSMOS_OPERATOR_ESCROW").strip.toLowerAscii
    if raw.len > 0:
      case raw
      of "true":
        n["operatorEscrow"] = %true
      of "false":
        n["operatorEscrow"] = %false
      else:
        raise newException(ValueError,
          "COSMOS_OPERATOR_ESCROW environment variable must be true or false")

  if existsEnv("COSMOS_PORT"):
    let raw = getEnv("COSMOS_PORT").strip
    if raw.len > 0:
      try:
        n["port"] = %parseInt(raw)
      except ValueError:
        raise newException(ValueError,
          "COSMOS_PORT environment variable is not a valid integer: " & raw)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc applyCliOverrides(n: var JsonNode, overrides: RuntimeConfigOverrides) =
  if overrides.mode.isSome:
    n["mode"] = %overrides.mode.get().strip
  if overrides.encryptionMode.isSome:
    n["encryptionMode"] = %overrides.encryptionMode.get().strip
  if overrides.recoveryEnabled.isSome:
    n["recoveryEnabled"] = %overrides.recoveryEnabled.get()
  if overrides.operatorEscrow.isSome:
    n["operatorEscrow"] = %overrides.operatorEscrow.get()
  if overrides.logLevel.isSome:
    n["logLevel"] = %overrides.logLevel.get().strip
  if overrides.port.isSome:
    n["port"] = %overrides.port.get()

# Flow: Return total number of config loads in this process.
proc getConfigLoadInvocationCount*(): int =
  configLoadInvocationCount

# Flow: Reset config load counter for deterministic test assertions.
proc resetConfigLoadInvocationCount*() =
  configLoadInvocationCount = 0

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc loadConfigWithOverrides*(path: string,
                              overrides: RuntimeConfigOverrides = RuntimeConfigOverrides()): RuntimeConfig =
  ## Load config, then apply file < environment < CLI override precedence.
  discard validateNonEmpty(path)

  if not fileExists(path):
    raise newException(ValueError,
      "loadConfig: config file not found")

  inc configLoadInvocationCount

  let raw = readFile(path)
  var n = parseJson(raw)
  applyEnvironmentOverrides(n)
  applyCliOverrides(n, overrides)
  result = parseRuntimeConfig(n)

# Flow: Build config directly from individual CLI parameters without requiring a config file.
proc buildConfigFromCliParams*(mode: string,
                                transport: string,
                                logLevel: string,
                                endpoint: string,
                                port: int,
                                encryptionMode: Option[string] = none[string](),
                                recoveryEnabled: Option[bool] = none[bool](),
                                operatorEscrow: Option[bool] = none[bool]()): RuntimeConfig =
  ## Build RuntimeConfig directly from CLI params (no config file needed).
  ## Used when --config is omitted and all required params are provided via CLI.
  var n = newJObject()
  n["mode"] = %mode
  n["transport"] = %transport
  n["logLevel"] = %logLevel
  n["endpoint"] = %endpoint
  n["port"] = %port
  
  # Set optional params with defaults
  if encryptionMode.isSome:
    n["encryptionMode"] = %(encryptionMode.get())
  else:
    n["encryptionMode"] = %"standard"
  
  if recoveryEnabled.isSome:
    n["recoveryEnabled"] = %(recoveryEnabled.get())
  else:
    n["recoveryEnabled"] = %false
  
  if operatorEscrow.isSome:
    n["operatorEscrow"] = %(operatorEscrow.get())
  else:
    n["operatorEscrow"] = %false
  
  inc configLoadInvocationCount
  result = parseRuntimeConfig(n)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc loadConfig*(path: string): RuntimeConfig =
  ## Load and validate runtime configuration from file.
  result = loadConfigWithOverrides(path)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
