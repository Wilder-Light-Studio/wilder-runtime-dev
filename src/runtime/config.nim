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
    transport*: TransportKind
    logLevel*: LogLevel
    endpoint*: string
    port*: int

  RuntimeConfigOverrides* = object
    mode*: Option[string]
    logLevel*: Option[string]
    port*: Option[int]

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

  if n["mode"].kind != JString or
     n["transport"].kind != JString or
     n["logLevel"].kind != JString or
     n["endpoint"].kind != JString or
     n["port"].kind != JInt:
    raise newException(ValueError,
      "loadConfig: config fields have invalid types")

  result.mode = parseRuntimeMode(n["mode"].getStr())
  result.transport = parseTransportKind(n["transport"].getStr())
  result.logLevel = parseLogLevel(n["logLevel"].getStr())
  result.endpoint = n["endpoint"].getStr().strip
  result.port = n["port"].getInt

  discard validateNonEmpty(result.endpoint)
  discard validatePortRange(result.port)

  if result.mode == rmProduction and result.logLevel in {llTrace, llDebug}:
    raise newException(ValueError,
      "loadConfig: production mode does not allow trace/debug log levels")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc applyEnvironmentOverrides(n: var JsonNode) =
  if existsEnv("COSMOS_MODE"):
    let raw = getEnv("COSMOS_MODE").strip
    if raw.len > 0:
      n["mode"] = %raw

  if existsEnv("COSMOS_LOG_LEVEL"):
    let raw = getEnv("COSMOS_LOG_LEVEL").strip
    if raw.len > 0:
      n["logLevel"] = %raw

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
  if overrides.logLevel.isSome:
    n["logLevel"] = %overrides.logLevel.get().strip
  if overrides.port.isSome:
    n["port"] = %overrides.port.get()

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc loadConfigWithOverrides*(path: string,
                              overrides: RuntimeConfigOverrides = RuntimeConfigOverrides()): RuntimeConfig =
  ## Load config, then apply file < environment < CLI override precedence.
  discard validateNonEmpty(path)

  if not fileExists(path):
    raise newException(ValueError,
      "loadConfig: config file not found")

  let raw = readFile(path)
  var n = parseJson(raw)
  applyEnvironmentOverrides(n)
  applyCliOverrides(n, overrides)
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
