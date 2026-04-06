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
  for key in ["COSMOS_MODE", "COSMOS_ENCRYPTION_MODE", "COSMOS_RECOVERY_ENABLED", "COSMOS_OPERATOR_ESCROW", "COSMOS_LOG_LEVEL", "COSMOS_PORT"]:
    if existsEnv(key):
      delEnv(key)

suite "runtime config":
  test "loads valid development config":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "debug",
      "endpoint": "localhost",
      "port": 8080
    }""")

    let cfg = loadConfig(path)
    check cfg.mode == rmDevelopment
    check cfg.encryptionMode == emStandard
    check cfg.recoveryEnabled == false
    check cfg.operatorEscrow == false
    check cfg.transport == tkJson
    check cfg.logLevel == llDebug
    check cfg.port == 8080

  test "loads valid production config":
    let path = writeTempConfig("""{
      "mode": "production",
      "encryptionMode": "complete",
      "transport": "protobuf",
      "logLevel": "info",
      "endpoint": "runtime.prod",
      "port": 443
    }""")

    let cfg = loadConfig(path)
    check cfg.mode == rmProduction
    check cfg.encryptionMode == emComplete
    check cfg.transport == tkProtobuf
    check cfg.logLevel == llInfo

  test "rejects production with debug logging":
    let path = writeTempConfig("""{
      "mode": "production",
      "encryptionMode": "standard",
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
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 0
    }""")
    expect(ValueError):
      discard loadConfig(p0)

    let p65536 = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "standard",
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
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 1
    }""")
    check loadConfig(p1).port == 1

    let p65535 = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "standard",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 65535
    }""")
    check loadConfig(p65535).port == 65535

  test "environment overrides beat file values":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "clear",
      "transport": "json",
      "logLevel": "debug",
      "endpoint": "localhost",
      "port": 8080
    }""")

    clearOverrideEnv()
    defer: clearOverrideEnv()
    putEnv("COSMOS_MODE", "production")
    putEnv("COSMOS_ENCRYPTION_MODE", "private")
    putEnv("COSMOS_LOG_LEVEL", "info")
    putEnv("COSMOS_PORT", "443")

    let cfg = loadConfigWithOverrides(path)
    check cfg.mode == rmProduction
    check cfg.encryptionMode == emPrivate
    check cfg.logLevel == llInfo
    check cfg.port == 443

  test "cli overrides beat environment values":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "clear",
      "transport": "json",
      "logLevel": "debug",
      "endpoint": "localhost",
      "port": 8080
    }""")

    clearOverrideEnv()
    defer: clearOverrideEnv()
    putEnv("COSMOS_MODE", "production")
    putEnv("COSMOS_ENCRYPTION_MODE", "private")
    putEnv("COSMOS_LOG_LEVEL", "info")
    putEnv("COSMOS_PORT", "443")

    let cfg = loadConfigWithOverrides(path, RuntimeConfigOverrides(
      mode: some("debug"),
      encryptionMode: some("complete"),
      logLevel: some("warn"),
      port: some(9001)
    ))
    check cfg.mode == rmDebug
    check cfg.encryptionMode == emComplete
    check cfg.logLevel == llWarn
    check cfg.port == 9001

  test "invalid override values are rejected after precedence is applied":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "standard",
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

  test "invalid encryption mode is rejected":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "sealed",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    expect(ValueError):
      discard loadConfig(path)

  test "missing encryption mode defaults to standard":
    let path = writeTempConfig("""{
      "mode": "development",
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    let cfg = loadConfig(path)
    check cfg.encryptionMode == emStandard

  test "clear mode rejects recovery and escrow flags":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "clear",
      "recoveryEnabled": true,
      "operatorEscrow": false,
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    expect(ValueError):
      discard loadConfig(path)

  test "private mode rejects operator escrow":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "private",
      "recoveryEnabled": true,
      "operatorEscrow": true,
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    expect(ValueError):
      discard loadConfig(path)

  test "complete mode rejects operator escrow":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "complete",
      "recoveryEnabled": true,
      "operatorEscrow": true,
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    expect(ValueError):
      discard loadConfig(path)

  test "standard operator escrow requires recovery opt-in":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "standard",
      "recoveryEnabled": false,
      "operatorEscrow": true,
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    expect(ValueError):
      discard loadConfig(path)

  test "environment boolean overrides apply to encryption settings":
    let path = writeTempConfig("""{
      "mode": "development",
      "encryptionMode": "standard",
      "recoveryEnabled": false,
      "operatorEscrow": false,
      "transport": "json",
      "logLevel": "info",
      "endpoint": "localhost",
      "port": 8080
    }""")

    clearOverrideEnv()
    defer: clearOverrideEnv()
    putEnv("COSMOS_RECOVERY_ENABLED", "true")
    putEnv("COSMOS_OPERATOR_ESCROW", "true")

    let cfg = loadConfig(path)
    check cfg.recoveryEnabled == true
    check cfg.operatorEscrow == true

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
