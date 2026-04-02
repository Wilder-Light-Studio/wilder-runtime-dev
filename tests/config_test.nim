# Wilder Cosmos 0.4.0
# Module name: config_test Tests
# Module Path: tests/config_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## config_test.nim
## Runtime config loading and validation tests.
## Flow: write temp config files, load, verify valid and invalid startup constraints.

## config_test.nim
#
## Summary: Configuration loading and validation tests.
## Simile: Like testing a startup procedure to ensure contract compliance.
## Memory note: config is validated once; test all constraint paths.
## Flow: load file -> parse JSON -> validate -> enforce constraints.

import unittest
import std/[os, options]
import ../src/runtime/config

# Flow: Execute procedure with deterministic test helper behavior.
proc writeTempConfig(content: string): string =
  ## Flow: create a temporary config file for tests and return path.
  let dir = getTempDir()
  let path = dir / "wilder_runtime_config_test.json"
  writeFile(path, content)
  return path

# Flow: Execute procedure with deterministic test helper behavior.
proc clearOverrideEnv() =
  for key in ["COSMOS_MODE", "COSMOS_LOG_LEVEL", "COSMOS_PORT"]:
    if existsEnv(key):
      delEnv(key)

suite "runtime config":
  test "loads valid development config":
    let path = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "debug",
      "endpoint": "localhost",
      "port": 8080
    }""")

    let cfg = loadConfig(path)
    check cfg.mode == rmDevelopment
    check cfg.transport == tkJson
    check cfg.logLevel == llDebug
    check cfg.port == 8080

  test "loads valid production config":
    let path = writeTempConfig("""{
      "mode": "production",
      "transport": "protobuf",
      "logLevel": "info",
      "endpoint": "runtime.prod",
      "port": 443
    }""")

    let cfg = loadConfig(path)
    check cfg.mode == rmProduction
    check cfg.transport == tkProtobuf
    check cfg.logLevel == llInfo

  test "rejects production with debug logging":
    let path = writeTempConfig("""{
      "mode": "production",
      "transport": "json",
      "logLevel": "debug",
      "endpoint": "runtime.prod",
      "port": 443
    }""")

    expect(ValueError):
      discard loadConfig(path)

  test "rejects missing config file":
    let path = getTempDir() / "wilder_config_does_not_exist.json"
    if fileExists(path):
      removeFile(path)

    expect(ValueError):
      discard loadConfig(path)

  test "rejects invalid port boundaries":
    let p0 = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 0
    }""")
    expect(ValueError):
      discard loadConfig(p0)

    let p65536 = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 65536
    }""")
    expect(ValueError):
      discard loadConfig(p65536)

  test "accepts valid port boundaries":
    let p1 = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 1
    }""")
    check loadConfig(p1).port == 1

    let p65535 = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 65535
    }""")
    check loadConfig(p65535).port == 65535

  test "environment overrides beat file values":
    let path = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "debug",
      "endpoint": "localhost",
      "port": 8080
    }""")

    clearOverrideEnv()
    defer: clearOverrideEnv()
    putEnv("COSMOS_MODE", "production")
    putEnv("COSMOS_LOG_LEVEL", "info")
    putEnv("COSMOS_PORT", "443")

    let cfg = loadConfigWithOverrides(path)
    check cfg.mode == rmProduction
    check cfg.logLevel == llInfo
    check cfg.port == 443

  test "cli overrides beat environment values":
    let path = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "debug",
      "endpoint": "localhost",
      "port": 8080
    }""")

    clearOverrideEnv()
    defer: clearOverrideEnv()
    putEnv("COSMOS_MODE", "production")
    putEnv("COSMOS_LOG_LEVEL", "info")
    putEnv("COSMOS_PORT", "443")

    let cfg = loadConfigWithOverrides(path, RuntimeConfigOverrides(
      mode: some("debug"),
      logLevel: some("warn"),
      port: some(9001)
    ))
    check cfg.mode == rmDebug
    check cfg.logLevel == llWarn
    check cfg.port == 9001

  test "invalid override values are rejected after precedence is applied":
    let path = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    clearOverrideEnv()
    defer: clearOverrideEnv()
    putEnv("COSMOS_PORT", "70000")

    expect(ValueError):
      discard loadConfigWithOverrides(path)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
