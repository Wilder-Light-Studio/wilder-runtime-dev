# Wilder Cosmos 0.4.0
# Module name: security_boundary_test Tests
# Module Path: tests/security_boundary_test.nim
# Summary: Security boundary tests for isolation, denial logging, and channel safety.
# Simile: Like a gatehouse that allows only explicit doors and records every denied entry.
# Memory note: default-deny and explicit-allow behavior must stay deterministic.
# Flow: create boundary -> attempt operations -> assert allow/deny and isolation semantics.

import unittest
import ../src/runtime/security

suite "security boundary":
  test "boundary defaults to no access":
    let b = newInstanceBoundary("inst-a")
    check not b.canRead
    check not b.canWrite
    check not b.canAdmin

  test "invalid promotion skip is denied and recorded":
    let b = newInstanceBoundary("inst-a", bmNone)
    check not promoteMode(b, bmAdmin)
    check b.denials.len == 1
    check b.denials[0].operation == "promote"

  test "stepwise promotion permits write only at readwrite or above":
    let b = newInstanceBoundary("inst-a", bmNone)
    check promoteMode(b, bmReadOnly)
    check b.canRead
    check not b.canWrite
    check promoteMode(b, bmReadWrite)
    check b.canWrite

  test "checkWrite denial is recorded":
    let b = newInstanceBoundary("inst-b", bmReadOnly)
    check not checkWrite(b)
    check b.denials.len == 1
    check b.denials[0].operation == "write"

suite "channel isolation":
  test "cross-instance channel is denied by default":
    let iso = newChannelIsolation()
    check not isChannelAllowed(iso, "inst-a", "inst-b")

  test "channel is only allowed after explicit registration":
    let iso = newChannelIsolation()
    allowChannel(iso, "inst-a", "inst-b")
    check isChannelAllowed(iso, "inst-a", "inst-b")
    check not isChannelAllowed(iso, "inst-b", "inst-a")

  test "revocation removes previously allowed channel":
    let iso = newChannelIsolation()
    allowChannel(iso, "inst-a", "inst-b")
    check isChannelAllowed(iso, "inst-a", "inst-b")
    revokeChannel(iso, "inst-a", "inst-b")
    check not isChannelAllowed(iso, "inst-a", "inst-b")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
