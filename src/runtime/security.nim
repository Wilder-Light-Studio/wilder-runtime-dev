# Wilder Cosmos 0.4.0
# Module name: security
# Module Path: src/runtime/security.nim
#
# Summary: 
#  Security boundaries and mode validation at the instance level.
#
# Simile: 
#   Like a building access card system — each instance holds an
#   access level; the boundary checks before any operation is allowed.
#
# Memory note: 
#   no silent promotion; mode must be explicitly set; read/write
#   access is enforced at the boundary, not assumed.
#
# Flow: 
#  create boundary -> check access -> allow or deny -> record denial.
#
## security.nim
## Instance boundary protection, explicit mode validation, and channel isolation.
## SPEC §17 Security.

## Example:
##   import runtime/security
##   let b = newInstanceBoundary("inst-a", bmReadOnly)
##   assert b.canRead
##   assert not b.canWrite

import std/[strutils, tables, times, monotimes]

# ── Types ─────────────────────────────────────────────────────────────────────

type
  BoundaryMode* = enum
    ## Access mode for an instance boundary.  Promotion must be explicit.
    bmNone      ## No access — default state; must be explicitly promoted.
    bmReadOnly  ## Read access only.
    bmReadWrite ## Full read/write access.
    bmAdmin     ## Administrative access (includes read/write + management).

  SecurityDenial* = object
    ## Recorded denial event.  Never silently dropped.
    instanceId*: string
    operation*: string
    reason*: string
    epochSeconds*: int64

  InstanceBoundary* = ref object
    ## Security boundary for a single runtime instance.
    instanceId*: string
    mode*: BoundaryMode
    denials*: seq[SecurityDenial]

  ChannelIsolation* = ref object
    ## Tracks inter-instance channels; ensures no implicit channel exists.
    ## An explicit channel must be registered before messages can flow.
    allowedChannels*: Table[string, bool]  ## "fromId->toId" -> true

# ── Instance Boundary ─────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc newInstanceBoundary*(instanceId: string,
                          mode: BoundaryMode = bmNone): InstanceBoundary =
  ## Create an instance boundary with an explicit access mode.
  ## Simile: Issuing an access card — no default privileges.
  if instanceId.strip.len == 0:
    raise newException(ValueError, "security: instanceId must not be empty")
  result = InstanceBoundary(instanceId: instanceId, mode: mode, denials: @[])

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc canRead*(b: InstanceBoundary): bool =
  ## Returns true if the boundary allows read operations.
  b.mode in {bmReadOnly, bmReadWrite, bmAdmin}

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc canWrite*(b: InstanceBoundary): bool =
  ## Returns true if the boundary allows write operations.
  b.mode in {bmReadWrite, bmAdmin}

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc canAdmin*(b: InstanceBoundary): bool =
  ## Returns true if the boundary allows administrative operations.
  b.mode == bmAdmin

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc recordDenial(b: InstanceBoundary, op: string, reason: string) =
  b.denials.add(SecurityDenial(
    instanceId: b.instanceId,
    operation: op,
    reason: reason,
    epochSeconds: toUnix(getTime())
  ))

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc checkRead*(b: InstanceBoundary): bool =
  ## Assert read permission.  Records denial if not allowed.
  if not b.canRead:
    b.recordDenial("read", "boundary mode " & $b.mode & " does not permit read")
    return false
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc checkWrite*(b: InstanceBoundary): bool =
  ## Assert write permission.  Records denial if not allowed.
  if not b.canWrite:
    b.recordDenial("write", "boundary mode " & $b.mode & " does not permit write")
    return false
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc checkAdmin*(b: InstanceBoundary): bool =
  ## Assert admin permission.  Records denial if not allowed.
  if not b.canAdmin:
    b.recordDenial("admin", "boundary mode " & $b.mode & " does not permit admin")
    return false
  true

# ── Mode Validation ───────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc validateModePromotion*(current: BoundaryMode,
                             proposed: BoundaryMode): bool =
  ## Return true if the mode transition is an explicit promotion (not silent).
  ## Silent promotions (e.g., None -> Admin) are only allowed if every
  ## intermediate step is acknowledged.  For simplicity: any promotion one
  ## level at a time is valid; skipping levels requires an explicit override.
  ## Simile: Climbing a ladder — no jumping from the bottom to the top.
  let order = [bmNone, bmReadOnly, bmReadWrite, bmAdmin]
  var ci = -1
  var pi = -1
  for i, m in order:
    if m == current: ci = i
    if m == proposed: pi = i
  if ci < 0 or pi < 0:
    return false
  # Demotion is always valid.  Promotion must not skip more than one step.
  pi <= ci + 1

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc promoteMode*(b: InstanceBoundary,
                  proposed: BoundaryMode): bool =
  ## Promote (or demote) the instance boundary mode.
  ## Returns false and records a denial if the promotion skips a level.
  if not validateModePromotion(b.mode, proposed):
    b.recordDenial("promote",
      "invalid mode promotion from " & $b.mode & " to " & $proposed)
    return false
  b.mode = proposed
  true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc isKnownRuntimeMode*(modeStr: string): bool =
  ## Return true if the mode string is a known runtime mode value.
  ## This does NOT enforce production-safety; it only checks that the string
  ## is a recognized value.  Use config validation to enforce mode constraints.
  modeStr.toLowerAscii in ["development", "debug", "production"]

# ── Channel Isolation ─────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc newChannelIsolation*(): ChannelIsolation =
  ## Create a new isolation registry with no allowed channels.
  result = ChannelIsolation(allowedChannels: initTable[string, bool]())

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc channelKey(fromId: string, toId: string): string =
  $fromId.len & ":" & fromId & "|" & $toId.len & ":" & toId

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc allowChannel*(iso: ChannelIsolation, fromId: string, toId: string) =
  ## Explicitly allow a message channel between two instances.
  iso.allowedChannels[channelKey(fromId, toId)] = true

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc isChannelAllowed*(iso: ChannelIsolation, fromId: string, toId: string): bool =
  ## Return true only if an explicit channel has been registered.
  ## No implicit channels exist; denies by default.
  iso.allowedChannels.getOrDefault(channelKey(fromId, toId), false)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc revokeChannel*(iso: ChannelIsolation, fromId: string, toId: string) =
  ## Revoke a previously allowed channel.
  iso.allowedChannels.del(channelKey(fromId, toId))

# ── Microbenchmark Helpers ────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc measureLookupNs*(warmupRounds: int, measureRounds: int,
                      target: proc(): void): int64 =
  ## Measure average nanoseconds per call using monotonic clock.
  ## Simile: Timing a relay race — warm up, then record the real run.
  for _ in 0 ..< warmupRounds:
    target()
  let t0 = ticks(getMonoTime())
  for _ in 0 ..< measureRounds:
    target()
  let t1 = ticks(getMonoTime())
  if measureRounds == 0:
    return 0
  result = (t1 - t0) div measureRounds

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
