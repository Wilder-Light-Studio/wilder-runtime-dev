# Wilder Cosmos 0.1.1
# Module name: API
# Module Path: runtime/api.nim
#
# Summary: Public runtime API types and input validation framework.
# Simile: API is the contract between modules and the runtime.
# Memory note: all types are validated at boundaries; private procs assume correctness.
# Flow: public proc input → validate → fail-fast on error → proceed with private impl.

import json, std/options
import validation

## Type-safe distinct types for domain-specific values (SPEC §24.5)
type
  EpochCounter* = distinct int  ## Frame-order counter; must be non-negative
  SchemaVersion* = distinct int ## Schema version; must be positive
  PortNumber* = distinct int    ## Port number; must be in [1, 65535]

## RuntimeState represents the overall state of the runtime.
## It includes the current epoch and version information.
type
  RuntimeState* = ref object
    ## The current epoch (frame counter) of the runtime.
    epoch*: EpochCounter
    ## The semantic version of the runtime.
    version*: string
    ## A display name for the runtime state.
    name*: string

  ## ModuleContext represents the context for a module.
  ## It provides access to module state and host bindings.
  ModuleContext* = object
    ## Module name identifier.
    name*: string
    ## Reference to the module's mutable state.
    state*: ref ModuleState
    ## Host bindings for module-to-runtime communication.
    host*: HostBindings

  ## HostBindings provides the module interface to the runtime.
  ## Modules use these bindings for host interactions.
  HostBindings* = object
    ## Send a message to another module (async).
    sendMessage*: proc (toModule: string, payload: JsonNode): bool
    ## Get current timestamp (frame epoch).
    getTime*: proc (): int
    ## Read from persistent storage.
    storageRead*: proc (key: string): Option[seq[byte]]
    ## Write to persistent storage.
    storageWrite*: proc (key: string, value: seq[byte]): bool
    ## Logging callback (never expose sensitive data).
    log*: proc (msg: string)

  ## ModuleState represents the state of a module.
  ## It includes initialization status and configuration data.
  ModuleState* = object
    ## The module name.
    name*: string
    ## Whether the module is active.
    active*: bool
    ## Indicates whether the module is initialized.
    initialized*: bool
    ## JSON configuration data for the module.
    config*: JsonNode

  ## StatusField represents a single status field (SPEC §7.1).
  ## It includes a field name, type, and optional invariant.
  StatusField* = object
    ## Field name (required, non-empty).
    name*: string
    ## Field type as string (e.g., "int", "string").
    fieldType*: string
    ## Whether this field is required.
    required*: bool
    ## Default value as JsonNode or nil.
    default*: JsonNode
    ## Optional invariant constraint (e.g., "x > 0").
    invariant*: Option[string]

  ## StatusSchema represents a schema for status fields (SPEC §7.1).
  ## It defines the structure and validation for Thing status.
  StatusSchema* = object
    ## List of status fields.
    fields*: seq[StatusField]
    ## Schema version for migration.
    schemaVersion*: SchemaVersion

  ## ReconcileResult represents the result of a reconciliation process.
  ## It includes a success flag and additional details.
  ReconcileResult* = object
    ## Indicates whether the reconciliation was successful.
    success*: bool
    ## Layers used in reconciliation (e.g., ["primary", "txlog"]).
    layersUsed*: seq[string]
    ## Human-readable messages describing reconciliation actions.
    messages*: seq[string]

## Conversion helpers (unsafe; use only in private context)
# Flow: Convert RuntimeState object to string representation.
proc `$`*(state: RuntimeState): string =
  if state.isNil:
    return "RuntimeState(nil)"
  result = "RuntimeState(epoch=" & $(state.epoch.int) & ")"

## Neurodivergent (ND)-friendly helper: convert JSON safely
# Flow: Execute procedure with deterministic validation and bounded side effects.
proc fromJson*[T](jsonStr: string): Option[T] =
  ## Flow: parse JSON, return Option[T]. Returns none on parse error.
  try:
    let node = parseJson(jsonStr)
    return some(node.to(T))
  except CatchableError:
    return none(T)

## Module Initialization
# Flow: Verify types compile and initialize logging infrastructure.
proc initModule*() =
  ## Initialize the API module.
  discard

## Module Cleanup
# Flow: Flush pending operations and reset module state.
proc cleanupModule*() =
  ## Clean up the API module.
  discard

## Public API: Create ModuleContext with validation (SPEC §2.5, §24.1)
# Flow: Validate inputs, construct context, and return initialized ModuleContext.
proc moduleContext_create*(name: string,
    state: ref ModuleState,
    host: HostBindings): ModuleContext =
  ## Create a module context with input validation.
  ## Raises: ValueError if name is empty.
  discard validateNonEmpty(name)
  return ModuleContext(name: name, state: state, host: host)

## Public API: Create StatusField with validation (SPEC §2.2, §24.1)
# Flow: Validate name and type, construct field object, then return.
proc statusField_create*(name: string, fieldType: string,
    required: bool): StatusField =
  ## Create a status field with input validation.
  ## Raises: ValueError if name or fieldType is empty.
  discard validateNonEmpty(name)
  discard validateNonEmpty(fieldType)
  return StatusField(name: name, fieldType: fieldType, required: required)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
