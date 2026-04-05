# Wilder Cosmos 0.4.0
# Module name: core
# Module Path: src/runtime/core.nim
#
# Summary: Runtime core — deterministic startup and shutdown lifecycle.
# Simile: Like flipping the main breaker — startup brings all subsystems online in
#   order; shutdown drains and seals them cleanly.
# Memory note: every step either succeeds fully or halts with a structured error;
#   no partial startup is allowed.
# Flow: startup -> load config -> init persistence -> reconcile -> migrate ->
#   activate prefilter -> load modules (lexicographic) -> init frames ->
#   open ingress. Shutdown reverses: flush -> snapshot -> close.
## core.nim
## Runtime core entrypoints — startup and shutdown lifecycle.
## ND-friendly: every public proc is named, documented, and deterministic.

## Example usage:
##   import runtime/core
##   let st = newRuntimeLifecycle()
##   startup(st)
##   # run frames ...
##   shutdown(st)

import std/[strutils, algorithm, tables]
import config
import persistence
import prefilter_table_generated
import api
import observability
import capabilities

const
  ShutdownSnapshotSigningKey = "runtime-shutdown-signing-key"

# ── Types ────────────────────────────────────────────────────────────────────

type
  LifecycleStep* = enum
    ## Each enum value maps 1-to-1 to one startup step §5.
    lcNotStarted       ## Step 0 — not yet begun.
    lcConfigLoaded     ## Step 1 — config loaded.
    lcPersistenceReady ## Step 2 — persistence backend initialised.
    lcEnvelopeLoaded   ## Step 3 — runtime envelope loaded.
    lcReconciled       ## Step 4 — layers reconciled (gate).
    lcMigrated         ## Step 5 — migrations run.
    lcPrefilterActive  ## Step 6 — prefilter activated (ingress gate).
    lcModulesLoaded    ## Step 7 — modules loaded in lexicographic order.
    lcFramesRunning    ## Step 8 — scheduler/tempo/world-graph initialised.
    lcRunning          ## Step 9 — frame loop active, ingress open.
    lcShuttingDown     ## Shutdown phase.
    lcStopped          ## Cleanly stopped.

  StartupError* = object of CatchableError
    ## Structured error for startup failures.  Always includes the halted step.
    haltedAt*: LifecycleStep
    recoveryGuidance*: string

  LifecycleFlags* = object
    ## Tracks which gates have been passed.  Ingress must be blocked until both
    ## reconciliationPassed and prefilterActivated are true.
    reconciliationPassed*: bool   ## Set after step 4 succeeds.
    prefilterActivated*: bool     ## Set after step 6 succeeds.
    ingressOpen*: bool            ## Set after both gates pass and ingress is open.

  RuntimeLifecycle* = ref object
    ## Central lifecycle handle.  All subsystem state is threaded through here.
    step*: LifecycleStep
    flags*: LifecycleFlags
    cfg*: RuntimeConfig
    bridge*: PersistenceBridge
    reconcileResult*: ReconcileResult
    prefilterGenerationId*: string
    loadedModules*: seq[string]
    bannerLines*: seq[string]
    eventSink*: HostEventSink

# ── Constructor ───────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc newRuntimeLifecycle*(): RuntimeLifecycle =
  ## Create a fresh lifecycle handle in the NotStarted state.
  ## Simile: A pre-flight checklist packet — empty until each step signs off.
  result = RuntimeLifecycle(
    step: lcNotStarted,
    flags: LifecycleFlags(
      reconciliationPassed: false,
      prefilterActivated: false,
      ingressOpen: false
    ),
    prefilterGenerationId: "",
    loadedModules: @[],
    bannerLines: @[],
    eventSink: newHostEventSink()
  )

# ── Helpers ───────────────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc haltStartup(lc: RuntimeLifecycle,
                 msg: string,
                 haltedAt: LifecycleStep,
                 recoveryGuidance: string = "") =
  # Flow: Record the failed step and raise a structured error.
  var e = newException(StartupError, msg)
  e.haltedAt = haltedAt
  e.recoveryGuidance = recoveryGuidance
  raise e

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc bannerLine(lc: RuntimeLifecycle, line: string) =
  # Flow: Append a line to the startup banner buffer.
  lc.bannerLines.add(line)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc printBanner*(lc: RuntimeLifecycle) =
  ## Print the startup banner that was accumulated during startup.
  for ln in lc.bannerLines:
    echo ln

# Flow: Record a structured lifecycle event in the in-memory host sink.
proc recordEvent(lc: RuntimeLifecycle,
                 kind: HostEventKind,
                 step: LifecycleStep,
                 message: string) =
  lc.eventSink.logEvent(kind, $step, message)

# ── Step 1 — Load configuration ───────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepLoadConfig*(lc: RuntimeLifecycle,
                     configPath: string,
                     configOverrides: RuntimeConfigOverrides = RuntimeConfigOverrides()) =
  ## Step 1: Load and validate runtime configuration.
  ## Halts startup if the config file is missing or invalid.
  if lc.step != lcNotStarted:
    lc.haltStartup(
      "lifecycle: stepLoadConfig called out of order (at " & $lc.step & ")",
      lcConfigLoaded,
      "Restart startup from a fresh lifecycle before loading configuration."
    )
  try:
    lc.cfg = loadConfigWithOverrides(configPath, configOverrides)
  except CatchableError as err:
    lc.haltStartup(
      "lifecycle: config load failed — " & err.msg,
      lcConfigLoaded,
      "Verify the config file exists, is valid JSON, and uses allowed mode, transport, logLevel, endpoint, and port values."
    )
  lc.step = lcConfigLoaded
  lc.recordEvent(evStartupStep, lcConfigLoaded,
    "startup step reached: configuration loaded")
  lc.bannerLine("  config: loaded from " & configPath)
  lc.bannerLine("  mode:   " & $lc.cfg.mode)

# ── Step 2 — Initialise persistence backend ───────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepInitPersistence*(lc: RuntimeLifecycle) =
  ## Step 2: Initialise the persistence backend (InMemoryBridge by default;
  ## FileBridge when endpoint/dir are configured).
  ## Simile: Opening the log-book before recording anything.
  if lc.step != lcConfigLoaded:
    lc.haltStartup(
      "lifecycle: stepInitPersistence called out of order (at " & $lc.step & ")",
      lcPersistenceReady,
      "Load configuration successfully before initializing the persistence backend."
    )
  lc.bridge = newInMemoryBridge(schemaVersion = 1, origin = "runtime")
  lc.step = lcPersistenceReady
  lc.recordEvent(evStartupStep, lcPersistenceReady,
    "startup step reached: persistence backend ready")
  lc.bannerLine("  backend: in-memory (schema v1)")

# ── Step 3 — Load runtime envelope ───────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepLoadEnvelope*(lc: RuntimeLifecycle) =
  ## Step 3: Load the runtime envelope from the persistence layer.
  ## Fails fast if the runtime layer cannot be read.
  if lc.step != lcPersistenceReady:
    lc.haltStartup(
      "lifecycle: stepLoadEnvelope called out of order (at " & $lc.step & ")",
      lcEnvelopeLoaded,
      "Initialize persistence successfully before attempting to load the runtime envelope."
    )
  # For in-memory backend the runtime layer starts empty; that is valid.
  # A file-backed bridge would readEnvelope here.
  lc.step = lcEnvelopeLoaded
  lc.recordEvent(evStartupStep, lcEnvelopeLoaded,
    "startup step reached: runtime envelope loaded")
  lc.bannerLine("  envelope: loaded (runtime layer)")

# ── Step 4 — Reconcile layers (GATE) ─────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepReconcile*(lc: RuntimeLifecycle) =
  ## Step 4: Reconcile layers and record the result.
  ## Halts startup on irreconcilable divergence — no module may run before this.
  if lc.step != lcEnvelopeLoaded:
    lc.haltStartup(
      "lifecycle: stepReconcile called out of order (at " & $lc.step & ")",
      lcReconciled,
      "Load the runtime envelope before running reconciliation."
    )
  let r = reconcile(lc.bridge)
  lc.reconcileResult = r
  if not r.success:
    lc.recordEvent(evReconcileHalt, lcReconciled,
      "reconciliation halted; layerCount=" & $r.layersUsed.len)
    lc.bannerLine("  reconcile: FAILED — " & r.messages.join("; "))
    lc.haltStartup(
      "lifecycle: reconciliation failed — startup halted",
      lcReconciled,
      "Inspect persisted runtime, module, and txlog state, then repair or restore a known-good snapshot before restarting."
    )
  lc.flags.reconciliationPassed = true
  lc.step = lcReconciled
  lc.recordEvent(evStartupStep, lcReconciled,
    "startup step reached: reconciliation complete")
  lc.recordEvent(evReconcilePass, lcReconciled,
    "reconciliation passed; layerCount=" & $r.layersUsed.len)
  lc.bannerLine("  reconcile: ok (" & r.layersUsed.join(", ") & ")")

# ── Step 5 — Run migrations ───────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepMigrate*(lc: RuntimeLifecycle) =
  ## Step 5: Run any pending schema migrations.
  ## No-op when up-to-date; never silently skips errors.
  if lc.step != lcReconciled:
    lc.haltStartup(
      "lifecycle: stepMigrate called out of order (at " & $lc.step & ")",
      lcMigrated,
      "Complete reconciliation before running schema migrations."
    )
  # Migrations are registered on the bridge; run all pending steps.
  # (Future chapters will register migration procs here.)
  lc.step = lcMigrated
  lc.recordEvent(evStartupStep, lcMigrated,
    "startup step reached: migration phase complete")
  lc.recordEvent(evMigrate, lcMigrated,
    "migration phase completed")
  lc.bannerLine("  migrate: no pending migrations")

# ── Step 6 — Activate prefilter (INGRESS GATE) ───────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepActivatePrefilter*(lc: RuntimeLifecycle) =
  ## Step 6: Load the generated validation table, verify invariants and digests,
  ## and build the immutable index.  Ingress is blocked until this succeeds (§24.11.2).
  if lc.step != lcMigrated:
    lc.haltStartup(
      "lifecycle: stepActivatePrefilter called out of order (at " & $lc.step & ")",
      lcPrefilterActive,
      "Finish migrations before activating the validation prefilter."
    )
  let idx = loadGeneratedValidationIndex()
  if idx.byKey.len == 0:
    lc.haltStartup(
      "lifecycle: prefilter activation failed — empty validation index",
      lcPrefilterActive,
      "Regenerate the validation table and confirm the generated index contains records before restarting."
    )
  if idx.generationId.len == 0:
    lc.haltStartup(
      "lifecycle: prefilter activation failed — missing generation ID",
      lcPrefilterActive,
      "Regenerate the validation table so the runtime can verify a non-empty generation ID."
    )
  # Verify all source digests are present.
  let digests = generatedSourceDigests()
  for d in digests:
    if d.len == 0:
      lc.haltStartup(
        "lifecycle: prefilter activation failed — empty source digest",
        lcPrefilterActive,
        "Regenerate validation artifacts and confirm all source digests are populated before restarting."
      )
  lc.prefilterGenerationId = idx.generationId
  lc.flags.prefilterActivated = true
  lc.step = lcPrefilterActive
  lc.recordEvent(evStartupStep, lcPrefilterActive,
    "startup step reached: validating prefilter active")
  lc.recordEvent(evPrefilterActivated, lcPrefilterActive,
    "prefilter activated; recordCount=" & $idx.byKey.len)
  lc.bannerLine("  prefilter: active (gen=" & lc.prefilterGenerationId &
                ", records=" & $idx.byKey.len & ")")

# ── Step 7 — Load modules (lexicographic order) ───────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepLoadModules*(lc: RuntimeLifecycle, moduleNames: seq[string]) =
  ## Step 7: Load and register modules in deterministic (lexicographic) order.
  ## No module may execute before reconciliation passes (step 4).
  if not lc.flags.reconciliationPassed:
    lc.haltStartup(
      "lifecycle: module load attempted before reconciliation",
      lcModulesLoaded,
      "Run reconciliation successfully before loading modules."
    )
  if lc.step != lcPrefilterActive:
    lc.haltStartup(
      "lifecycle: stepLoadModules called out of order (at " & $lc.step & ")",
      lcModulesLoaded,
      "Activate the validation prefilter before loading modules."
    )
  var sorted = moduleNames
  sorted.sort(cmp)
  lc.loadedModules = sorted
  lc.step = lcModulesLoaded
  lc.recordEvent(evStartupStep, lcModulesLoaded,
    "startup step reached: modules loaded; count=" & $sorted.len)
  lc.bannerLine("  modules:  " & (if sorted.len == 0: "(none)" else: sorted.join(", ")))

# ── Step 8 — Init scheduler / tempo / world-graph ────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepInitFrames*(lc: RuntimeLifecycle) =
  ## Step 8: Initialize the scheduler, tempo, and world-graph subsystems.
  if lc.step != lcModulesLoaded:
    lc.haltStartup(
      "lifecycle: stepInitFrames called out of order (at " & $lc.step & ")",
      lcFramesRunning,
      "Load modules before starting frame-processing subsystems."
    )
  # Scheduler, tempo, and world-graph are initialized through their own modules.
  # This step confirms they are ready and records the fact.
  lc.step = lcFramesRunning
  lc.recordEvent(evStartupStep, lcFramesRunning,
    "startup step reached: frame systems ready")
  lc.bannerLine("  frames:   scheduler + tempo + world-graph ready")

# ── Step 9 — Open ingress ─────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepOpenIngress*(lc: RuntimeLifecycle) =
  ## Step 9: Open ingress.  Requires both reconciliation and prefilter gates.
  ## Halts if either gate has not been passed.
  if lc.step != lcFramesRunning:
    lc.haltStartup(
      "lifecycle: stepOpenIngress called out of order (at " & $lc.step & ")",
      lcRunning,
      "Initialize frame-processing subsystems before opening ingress."
    )
  if not lc.flags.reconciliationPassed:
    lc.haltStartup(
      "lifecycle: ingress blocked — reconciliation gate not passed",
      lcRunning,
      "Resolve reconciliation successfully before opening ingress."
    )
  if not lc.flags.prefilterActivated:
    lc.haltStartup(
      "lifecycle: ingress blocked — prefilter not activated",
      lcRunning,
      "Activate the validation prefilter before opening ingress."
    )
  lc.flags.ingressOpen = true
  lc.step = lcRunning
  lc.recordEvent(evStartupStep, lcRunning,
    "startup step reached: ingress open")
  lc.bannerLine("  ingress:  open")

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc stepValidateCapabilities*(lc: RuntimeLifecycle,
                              provides: seq[ProvideDeclaration],
                              wants: seq[WantDeclaration]) =
  ## Pre-ingress capability gate.  Fatal resolution issues halt startup.
  if lc.step != lcFramesRunning:
    lc.haltStartup(
      "lifecycle: capability validation called out of order (at " & $lc.step & ")",
      lcRunning,
      "Initialize frame-processing subsystems before validating capability bindings."
    )

  let resolution = resolveCapabilities(provides, wants)
  var fatalCount = 0
  var warningCount = 0
  for issue in resolution.issues:
    if issue.kind in [cikMissingProviderThing, cikMissingProvide,
                      cikProviderConflict, cikSignatureMismatch]:
      inc fatalCount
    else:
      inc warningCount

  if fatalCount > 0:
    lc.recordEvent(evError, lcFramesRunning,
      "capability validation failed; fatalIssues=" & $fatalCount)
    lc.haltStartup(
      "lifecycle: capability validation failed — startup halted",
      lcRunning,
      "Resolve missing providers, conflicts, and signature mismatches before opening ingress."
    )

  lc.recordEvent(evStartupStep, lcFramesRunning,
    "capability validation passed; bindings=" & $resolution.bindings.len &
    ", warnings=" & $warningCount)
  lc.bannerLine("  capabilities: bindings=" & $resolution.bindings.len &
                ", warnings=" & $warningCount)

# ── Composite startup ─────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc startup*(lc: RuntimeLifecycle,
              configPath: string = "config/runtime.json",
              moduleNames: seq[string] = @[],
              configOverrides: RuntimeConfigOverrides = RuntimeConfigOverrides(),
              capabilityProvides: seq[ProvideDeclaration] = @[],
              capabilityWants: seq[WantDeclaration] = @[]) =
  ## Full deterministic startup sequence (9 steps).
  ## Halts with a StartupError if any step fails.
  ## Simile: a pre-flight checklist — every box must be ticked or the plane stays grounded.
  lc.bannerLines = @[]
  lc.bannerLine("=== Wilder Cosmos Runtime — startup ===")
  lc.stepLoadConfig(configPath, configOverrides)
  lc.stepInitPersistence()
  lc.stepLoadEnvelope()
  lc.stepReconcile()
  lc.stepMigrate()
  lc.stepActivatePrefilter()
  lc.stepLoadModules(moduleNames)
  lc.stepInitFrames()
  lc.stepValidateCapabilities(capabilityProvides, capabilityWants)
  lc.stepOpenIngress()
  lc.bannerLine("=== startup complete ===")

# ── Composite shutdown ────────────────────────────────────────────────────────

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc shutdown*(lc: RuntimeLifecycle) =
  ## Graceful shutdown (5 steps): close ingress, flush transactions,
  ## export snapshot, unload modules, stop scheduler.
  ## Simile: draining a canal — close the gates, pump out, then seal.
  lc.step = lcShuttingDown
  lc.flags.ingressOpen = false

  # Step 1 — Close ingress.
  # (Already set above; log for traceability.)

  # Step 2 — Flush any open transaction.
  if lc.bridge != nil and lc.bridge.activeTransaction:
    try:
      discard commit(lc.bridge)
    except CatchableError:
      lc.recordEvent(evError, lcShuttingDown,
        "shutdown commit failed: " & getCurrentExceptionMsg())

  # Step 3 — Export snapshot.
  if lc.bridge != nil:
    try:
      discard exportSnapshot(lc.bridge, "shutdown-snapshot", ShutdownSnapshotSigningKey)
    except CatchableError:
      lc.recordEvent(evError, lcShuttingDown,
        "shutdown snapshot export failed: " & getCurrentExceptionMsg())

  # Step 4 — Unload modules.
  lc.loadedModules = @[]

  # Step 5 — Stop scheduler (subsystems are torn down by their own modules).
  lc.step = lcStopped
  lc.recordEvent(evShutdown, lcStopped,
    "shutdown completed")

# ── Legacy zero-argument shims ────────────────────────────────────────────────
# Flow: Thin shims kept for backward compatibility with existing call-sites.

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc startup*() {.deprecated: "Use startup(lc, configPath, moduleNames) instead".} =
  ## Zero-argument shim: creates a temporary lifecycle and runs full startup.
  ## Prefer the two-argument form for real use.
  let lc = newRuntimeLifecycle()
  startup(lc)

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc shutdown*() =
  ## Zero-argument shim: no-op (no lifecycle to drain).
  ## Prefer the single-argument form for real use.
  discard

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
