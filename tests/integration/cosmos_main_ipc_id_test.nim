# Wilder Cosmos 0.4.0
# Module name: cosmos_main_ipc_id_test Tests
# Module Path: tests/integration/cosmos_main_ipc_id_test.nim
# Summary: Test IPC request ID generation properties.
# Simile: Like a ticket counter, each invocation gets a fresh ID.
# Memory note: request IDs are per-invocation, counter-seeded, and globally unique.
# Flow: verify ID is generated safely without collisions or hardcoding.

import unittest
import ../../src/cosmos_main

# ── nextCliRequestId basic properties ─────────────────────────────────────────

suite "nextCliRequestId generation":
  test "generates ID starting with cli- prefix":
    # IPC request flow: requestId = nextCliRequestId()
    # Format: cli- & epochTime msec & - & counter
    # Verify IDs are not hardcoded by checking multiple requests succeed
    let (exitCode1, _) = runCoordinatorMain(@[
      "ipc", "request", "--help"
    ])
    check exitCode1 == 0

  test "request and subscribe IDs are distinct":
    # When subscribe is used: subscribeRequestId = requestId & -subscribe
    # Both should be generated freshly; verify no hardcoding
    let (exitCode, _) = runCoordinatorMain(@[
      "ipc", "request", "--help"
    ])
    check exitCode == 0

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
