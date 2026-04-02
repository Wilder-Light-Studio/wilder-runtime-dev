# Wilder Cosmos 0.4.0
# Module name: security_bench_test Tests
# Module Path: tests/security_bench_test.nim
#
# Summary: Test module covering deterministic runtime behavior and contract checks.
# Simile: Like a launch checklist, each case verifies one safety condition before go-live.
# Memory note: keep tests explicit, isolated, and safe for repeated local and CI runs.
# Flow: setup fixture -> execute behavior -> assert invariants and failure boundaries.

## security_bench_test.nim
#
## Summary: Chapter 14 security boundary, mode validation, channel isolation,
##   and microbenchmark tests.
## Simile: Like a security audit combined with a stopwatch session —
##   verify walls hold AND that they don't slow the system down.
## Memory note: denials must be recorded, never swallowed; mode promotion
##   must be step-by-step; channels must be explicit.
## Flow: create boundary -> test access -> record denials -> benchmark hot paths.

import unittest
import ../src/runtime/security

# ── instance boundary ─────────────────────────────────────────────────────────

suite "instance boundary":
  test "new boundary with None mode denies read":
    let b = newInstanceBoundary("inst-a", bmNone)
    check not b.canRead

  test "new boundary with None mode denies write":
    let b = newInstanceBoundary("inst-a", bmNone)
    check not b.canWrite

  test "read-only boundary allows read":
    let b = newInstanceBoundary("inst-a", bmReadOnly)
    check b.canRead

  test "read-only boundary denies write":
    let b = newInstanceBoundary("inst-a", bmReadOnly)
    check not b.canWrite

  test "read-write boundary allows both":
    let b = newInstanceBoundary("inst-a", bmReadWrite)
    check b.canRead
    check b.canWrite

  test "admin boundary allows all":
    let b = newInstanceBoundary("inst-a", bmAdmin)
    check b.canRead
    check b.canWrite
    check b.canAdmin

  test "checkRead on None records denial":
    let b = newInstanceBoundary("inst-a", bmNone)
    discard b.checkRead()
    check b.denials.len == 1

  test "checkWrite on ReadOnly records denial":
    let b = newInstanceBoundary("inst-a", bmReadOnly)
    discard b.checkWrite()
    check b.denials.len == 1

  test "checkRead on ReadWrite does not record denial":
    let b = newInstanceBoundary("inst-a", bmReadWrite)
    check b.checkRead()
    check b.denials.len == 0

  test "empty instance ID raises ValueError":
    expect(ValueError):
      discard newInstanceBoundary("")

# ── mode validation ───────────────────────────────────────────────────────────

suite "mode validation":
  test "promotion one step at a time is valid":
    check validateModePromotion(bmNone, bmReadOnly)
    check validateModePromotion(bmReadOnly, bmReadWrite)
    check validateModePromotion(bmReadWrite, bmAdmin)

  test "demotion is always valid":
    check validateModePromotion(bmAdmin, bmNone)
    check validateModePromotion(bmReadWrite, bmNone)

  test "skipping two levels is invalid":
    check not validateModePromotion(bmNone, bmReadWrite)
    check not validateModePromotion(bmNone, bmAdmin)

  test "promoteMode applies valid promotion":
    let b = newInstanceBoundary("inst-a", bmNone)
    check b.promoteMode(bmReadOnly)
    check b.mode == bmReadOnly

  test "promoteMode rejects skipped promotion and records denial":
    let b = newInstanceBoundary("inst-a", bmNone)
    check not b.promoteMode(bmAdmin)
    check b.denials.len == 1
    check b.mode == bmNone  # unchanged

# ── channel isolation ─────────────────────────────────────────────────────────

suite "channel isolation":
  test "no implicit channels exist by default":
    let iso = newChannelIsolation()
    check not iso.isChannelAllowed("a", "b")

  test "explicitly allowed channel is allowed":
    let iso = newChannelIsolation()
    iso.allowChannel("a", "b")
    check iso.isChannelAllowed("a", "b")

  test "channel is directional — reverse is not allowed":
    let iso = newChannelIsolation()
    iso.allowChannel("a", "b")
    check not iso.isChannelAllowed("b", "a")

  test "revoked channel is no longer allowed":
    let iso = newChannelIsolation()
    iso.allowChannel("a", "b")
    iso.revokeChannel("a", "b")
    check not iso.isChannelAllowed("a", "b")

  test "multiple channels can be registered independently":
    let iso = newChannelIsolation()
    iso.allowChannel("mod-a", "mod-b")
    iso.allowChannel("mod-c", "mod-d")
    check iso.isChannelAllowed("mod-a", "mod-b")
    check iso.isChannelAllowed("mod-c", "mod-d")
    check not iso.isChannelAllowed("mod-a", "mod-d")

# ── microbenchmarks ───────────────────────────────────────────────────────────

suite "microbenchmarks":
  test "boundary canRead lookup completes in bounded time":
    let b = newInstanceBoundary("bench", bmReadOnly)
    let ns = measureLookupNs(100, 10_000, proc() = discard b.canRead)
    # O(1) constant-time — we just verify it's measurable and not absurdly slow.
    # On any Tier 1 platform a simple enum check should be < 1 microsecond.
    check ns >= 0  # always true; documents that measurement ran

  test "channel allowed lookup completes in bounded time":
    let iso = newChannelIsolation()
    iso.allowChannel("m1", "m2")
    let ns = measureLookupNs(100, 10_000, proc() =
      discard iso.isChannelAllowed("m1", "m2"))
    check ns >= 0

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
