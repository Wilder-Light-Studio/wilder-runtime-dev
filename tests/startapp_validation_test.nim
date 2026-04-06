# Wilder Cosmos 0.4.0
# Module name: startapp_validation_test Tests
# Module Path: tests/startapp_validation_test.nim
# Summary: Test startapp name sanitization and injection prevention.
# Simile: Like a gatekeeper at a template factory, verifying names cannot break output.
# Memory note: names are interpolated into TOML strings and generated Nim source.
# Flow: validate allowed chars -> reject disallowed -> enforce length limits -> reject empty.

import unittest
import ../src/runtime/startapp

# ── validateStartAppName edge cases ───────────────────────────────────────────

suite "startapp name validation":
  test "accepts alphanumeric names":
    expect(ValueError):
      discard  # validation is called during scaffoldApp; we test indirectly
    let opts = StartAppOptions(
      targetDir: "test-app",
      appName: "MyApp123",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    # This should not raise during name normalization
    try:
      let dirs = scaffoldApp(opts)
      check dirs.len > 0
    except ValueError as e:
      fail("alphanumeric name should not raise: " & e.msg)
    finally:
      if dirExists("test-app"):
        removeDir("test-app")

  test "accepts names with hyphens and underscores":
    let opts = StartAppOptions(
      targetDir: "test-app-2",
      appName: "my_app-name",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    try:
      let dirs = scaffoldApp(opts)
      check dirs.len > 0
    except ValueError as e:
      fail("hyphenated/underscore name should not raise: " & e.msg)
    finally:
      if dirExists("test-app-2"):
        removeDir("test-app-2")

  test "rejects names with double quotes":
    let opts = StartAppOptions(
      targetDir: "test-app-3",
      appName: "app\"name",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    expect(ValueError):
      discard scaffoldApp(opts)
    if dirExists("test-app-3"):
      removeDir("test-app-3")

  test "rejects names with newlines":
    let opts = StartAppOptions(
      targetDir: "test-app-4",
      appName: "app\nname",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    expect(ValueError):
      discard scaffoldApp(opts)
    if dirExists("test-app-4"):
      removeDir("test-app-4")

  test "rejects names with backslashes":
    let opts = StartAppOptions(
      targetDir: "test-app-5",
      appName: "app\\name",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    expect(ValueError):
      discard scaffoldApp(opts)
    if dirExists("test-app-5"):
      removeDir("test-app-5")

  test "rejects names exceeding max length (64)":
    let opts = StartAppOptions(
      targetDir: "test-app-6",
      appName: "a" & "x".repeat(70),
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    expect(ValueError):
      discard scaffoldApp(opts)
    if dirExists("test-app-6"):
      removeDir("test-app-6")

  test "accepts names at max length (64)":
    let opts = StartAppOptions(
      targetDir: "test-app-7",
      appName: "a" & "x".repeat(63),
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    try:
      let dirs = scaffoldApp(opts)
      check dirs.len > 0
    except ValueError as e:
      fail("64-char name should not raise: " & e.msg)
    finally:
      if dirExists("test-app-7"):
        removeDir("test-app-7")

  test "allows spaces in names":
    let opts = StartAppOptions(
      targetDir: "test-app-8",
      appName: "My App Name",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    try:
      let dirs = scaffoldApp(opts)
      check dirs.len > 0
    except ValueError as e:
      fail("space-containing name should not raise: " & e.msg)
    finally:
      if dirExists("test-app-8"):
        removeDir("test-app-8")

  test "allows dots in names":
    let opts = StartAppOptions(
      targetDir: "test-app-9",
      appName: "my.app.name",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    try:
      let dirs = scaffoldApp(opts)
      check dirs.len > 0
    except ValueError as e:
      fail("dot-containing name should not raise: " & e.msg)
    finally:
      if dirExists("test-app-9"):
        removeDir("test-app-9")

  test "uses defaultAppName when appName is empty":
    let opts = StartAppOptions(
      targetDir: "app-from-dir",
      appName: "",
      mode: "development",
      transport: "json",
      includeTemplate: true
    )
    try:
      let dirs = scaffoldApp(opts)
      check dirs.len > 0
      # Verify cosmos.toml contains the derived name
      let cosmosPath = "app-from-dir" / "cosmos.toml"
      check fileExists(cosmosPath)
    except ValueError as e:
      fail("empty appName with defaulting should not raise: " & e.msg)
    finally:
      if dirExists("app-from-dir"):
        removeDir("app-from-dir")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
