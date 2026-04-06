# Wilder Cosmos 0.4.0
# Module name: capabilities
# Module Path: src/runtime/capabilities.nim
# Summary: Deterministic capability resolver for Thing provides and wants.
# Simile: Like a wiring map, it matches demand points to stable service sockets before power-on.
# Memory note: provider-side signatures are canonical; wants reference but do not redefine provider contracts.
# Flow: normalize declarations -> index providers -> resolve wants -> emit bindings and issues.

import std/[algorithm, strutils, tables]

type
  CapabilityIssueKind* = enum
    cikMissingProviderThing
    cikMissingProvide
    cikProviderConflict
    cikSignatureMismatch
    cikOrphanedProvide
    cikMissingImplementation
    cikUndeclaredProvideImplementation
    cikImplementationConflict

  ProvideDeclaration* = object
    thingName*: string
    provideName*: string
    signature*: string

  WantDeclaration* = object
    consumerThing*: string
    reference*: string
    expectedSignature*: string

  ModuleBindingDeclaration* = object
    provideKey*: string
    moduleType*: string
    moduleRef*: string
    entrypoint*: string
    abiVersion*: string

  CapabilityBinding* = object
    consumerThing*: string
    reference*: string
    providerThing*: string
    provideName*: string
    signature*: string

  CapabilityIssue* = object
    kind*: CapabilityIssueKind
    consumerThing*: string
    reference*: string
    detail*: string

  CapabilityResolution* = object
    bindings*: seq[CapabilityBinding]
    issues*: seq[CapabilityIssue]

  CapabilityGraph* = object
    things*: seq[string]
    provides*: seq[ProvideDeclaration]
    wants*: seq[WantDeclaration]
    signatures*: seq[string]
    moduleBindings*: seq[ModuleBindingDeclaration]
    resolution*: CapabilityResolution
    startupEligible*: bool

# Flow: Build a stable provider key from thing and provide name.
proc providerKey(thingName: string, provideName: string): string =
  thingName.strip & "." & provideName.strip

# Flow: Parse a want reference as either Thing.provide or whole-Thing.
proc parseWantReference*(reference: string): tuple[thingName: string,
                                                   provideName: string,
                                                   isWholeThing: bool] =
  let trimmed = reference.strip
  if trimmed.len == 0:
    raise newException(ValueError,
      "capabilities: want reference must not be empty")
  let dot = trimmed.find('.')
  if dot < 0:
    return (trimmed, "", true)
  let thingName = trimmed[0 ..< dot].strip
  let provideName = trimmed[dot + 1 .. ^1].strip
  if thingName.len == 0 or provideName.len == 0:
    raise newException(ValueError,
      "capabilities: want reference must be Thing or Thing.provide")
  (thingName, provideName, false)

# Flow: Determine if one capability issue should halt startup.
proc issueIsFatal*(issue: CapabilityIssue): bool =
  issue.kind in [
    cikMissingProviderThing,
    cikMissingProvide,
    cikProviderConflict,
    cikSignatureMismatch,
    cikMissingImplementation,
    cikUndeclaredProvideImplementation,
    cikImplementationConflict
  ]

# Flow: Validate declaration-to-implementation bindings with deterministic issue order.
proc validateModuleBindings(providersByKey: Table[string, seq[ProvideDeclaration]],
                            moduleBindings: seq[ModuleBindingDeclaration],
                            enforceBindingCoverage: bool): seq[CapabilityIssue] =
  var sortedBindings = moduleBindings
  sortedBindings.sort(proc(a, b: ModuleBindingDeclaration): int =
    let byKey = system.cmp(a.provideKey, b.provideKey)
    if byKey != 0:
      return byKey
    let byType = system.cmp(a.moduleType, b.moduleType)
    if byType != 0:
      return byType
    let byRef = system.cmp(a.moduleRef, b.moduleRef)
    if byRef != 0:
      return byRef
    let byEntrypoint = system.cmp(a.entrypoint, b.entrypoint)
    if byEntrypoint != 0:
      return byEntrypoint
    system.cmp(a.abiVersion, b.abiVersion)
  )

  var bindingsByKey = initTable[string, seq[ModuleBindingDeclaration]]()
  for binding in sortedBindings:
    let key = binding.provideKey.strip
    let moduleType = binding.moduleType.strip
    let moduleRef = binding.moduleRef.strip
    let entrypoint = binding.entrypoint.strip
    let abiVersion = binding.abiVersion.strip
    if key.len == 0 or moduleType.len == 0 or moduleRef.len == 0 or
        entrypoint.len == 0 or abiVersion.len == 0:
      raise newException(ValueError,
        "capabilities: module binding requires non-empty provideKey/moduleType/moduleRef/entrypoint/abiVersion")

    if not providersByKey.hasKey(key):
      result.add(CapabilityIssue(
        kind: cikUndeclaredProvideImplementation,
        consumerThing: "",
        reference: key,
        detail: "implementation binding exists for undeclared provide " & key
      ))
      continue

    bindingsByKey.mgetOrPut(key, @[]).add(ModuleBindingDeclaration(
      provideKey: key,
      moduleType: moduleType,
      moduleRef: moduleRef,
      entrypoint: entrypoint,
      abiVersion: abiVersion
    ))

  for key, bindings in bindingsByKey.pairs:
    if bindings.len > 1:
      result.add(CapabilityIssue(
        kind: cikImplementationConflict,
        consumerThing: "",
        reference: key,
        detail: "multiple implementation bindings found for " & key
      ))

  if enforceBindingCoverage:
    var keys: seq[string] = @[]
    for key, _ in providersByKey.pairs:
      keys.add(key)
    keys.sort(system.cmp[string])
    for key in keys:
      if not bindingsByKey.hasKey(key):
        result.add(CapabilityIssue(
          kind: cikMissingImplementation,
          consumerThing: "",
          reference: key,
          detail: "declared provide has no implementation binding: " & key
        ))

# Flow: Resolve wants to provider declarations with deterministic issue reporting.
proc resolveCapabilities*(provides: seq[ProvideDeclaration],
                          wants: seq[WantDeclaration],
                          moduleBindings: seq[ModuleBindingDeclaration] = @[],
                          enforceBindingCoverage: bool = false): CapabilityResolution =
  var providersByThing = initTable[string, seq[ProvideDeclaration]]()
  var providersByKey = initTable[string, seq[ProvideDeclaration]]()

  var sortedProvides = provides
  sortedProvides.sort(proc(a, b: ProvideDeclaration): int =
    let byThing = system.cmp(a.thingName, b.thingName)
    if byThing != 0:
      return byThing
    let byProvide = system.cmp(a.provideName, b.provideName)
    if byProvide != 0:
      return byProvide
    system.cmp(a.signature, b.signature)
  )

  for p in sortedProvides:
    let thingName = p.thingName.strip
    let provideName = p.provideName.strip
    let signature = p.signature.strip
    if thingName.len == 0 or provideName.len == 0 or signature.len == 0:
      raise newException(ValueError,
        "capabilities: provider declarations require non-empty thing/provide/signature")

    let normalized = ProvideDeclaration(
      thingName: thingName,
      provideName: provideName,
      signature: signature
    )
    providersByThing.mgetOrPut(thingName, @[]).add(normalized)
    providersByKey.mgetOrPut(providerKey(thingName, provideName), @[]).add(normalized)

  for want in wants:
    let consumerThing = want.consumerThing.strip
    let expectedSignature = want.expectedSignature.strip
    if consumerThing.len == 0:
      raise newException(ValueError,
        "capabilities: want declarations require non-empty consumerThing")

    let (thingName, provideName, isWholeThing) = parseWantReference(want.reference)

    if not providersByThing.hasKey(thingName):
      result.issues.add(CapabilityIssue(
        kind: cikMissingProviderThing,
        consumerThing: consumerThing,
        reference: want.reference,
        detail: "provider Thing not found: " & thingName
      ))
      continue

    if isWholeThing:
      for candidate in providersByThing[thingName]:
        result.bindings.add(CapabilityBinding(
          consumerThing: consumerThing,
          reference: want.reference,
          providerThing: candidate.thingName,
          provideName: candidate.provideName,
          signature: candidate.signature
        ))
      continue

    let key = providerKey(thingName, provideName)
    let candidates = providersByKey.getOrDefault(key)
    if candidates.len == 0:
      result.issues.add(CapabilityIssue(
        kind: cikMissingProvide,
        consumerThing: consumerThing,
        reference: want.reference,
        detail: "provide not found: " & key
      ))
      continue

    if candidates.len > 1:
      result.issues.add(CapabilityIssue(
        kind: cikProviderConflict,
        consumerThing: consumerThing,
        reference: want.reference,
        detail: "multiple provider declarations found for " & key
      ))
      continue

    let selected = candidates[0]
    if expectedSignature.len > 0 and expectedSignature != selected.signature:
      result.issues.add(CapabilityIssue(
        kind: cikSignatureMismatch,
        consumerThing: consumerThing,
        reference: want.reference,
        detail: "expected signature '" & expectedSignature &
          "' but provider declares '" & selected.signature & "'"
      ))
      continue

    result.bindings.add(CapabilityBinding(
      consumerThing: consumerThing,
      reference: want.reference,
      providerThing: selected.thingName,
      provideName: selected.provideName,
      signature: selected.signature
    ))

  var referencedKeys = initTable[string, bool]()
  for binding in result.bindings:
    referencedKeys[providerKey(binding.providerThing, binding.provideName)] = true

  for p in sortedProvides:
    let key = providerKey(p.thingName, p.provideName)
    if not referencedKeys.getOrDefault(key, false):
      result.issues.add(CapabilityIssue(
        kind: cikOrphanedProvide,
        consumerThing: "",
        reference: key,
        detail: "declared provide has no resolved consumers"
      ))

  result.issues.add(validateModuleBindings(
    providersByKey,
    moduleBindings,
    enforceBindingCoverage
  ))

# Flow: Build one immutable capability graph snapshot for discovery surfaces.
proc buildCapabilityGraph*(provides: seq[ProvideDeclaration],
                           wants: seq[WantDeclaration],
                           moduleBindings: seq[ModuleBindingDeclaration] = @[],
                           enforceBindingCoverage: bool = false): CapabilityGraph =
  result.provides = provides
  result.provides.sort(proc(a, b: ProvideDeclaration): int =
    let byThing = system.cmp(a.thingName, b.thingName)
    if byThing != 0:
      return byThing
    let byProvide = system.cmp(a.provideName, b.provideName)
    if byProvide != 0:
      return byProvide
    system.cmp(a.signature, b.signature)
  )

  result.wants = wants
  result.wants.sort(proc(a, b: WantDeclaration): int =
    let byConsumer = system.cmp(a.consumerThing, b.consumerThing)
    if byConsumer != 0:
      return byConsumer
    let byReference = system.cmp(a.reference, b.reference)
    if byReference != 0:
      return byReference
    system.cmp(a.expectedSignature, b.expectedSignature)
  )

  result.moduleBindings = moduleBindings
  result.moduleBindings.sort(proc(a, b: ModuleBindingDeclaration): int =
    let byKey = system.cmp(a.provideKey, b.provideKey)
    if byKey != 0:
      return byKey
    let byType = system.cmp(a.moduleType, b.moduleType)
    if byType != 0:
      return byType
    let byRef = system.cmp(a.moduleRef, b.moduleRef)
    if byRef != 0:
      return byRef
    let byEntrypoint = system.cmp(a.entrypoint, b.entrypoint)
    if byEntrypoint != 0:
      return byEntrypoint
    system.cmp(a.abiVersion, b.abiVersion)
  )

  result.resolution = resolveCapabilities(
    result.provides,
    result.wants,
    result.moduleBindings,
    enforceBindingCoverage
  )

  var thingNames = initTable[string, bool]()
  var signatures = initTable[string, bool]()

  for provide in provides:
    let thingName = provide.thingName.strip
    let signature = provide.signature.strip
    if thingName.len > 0:
      thingNames[thingName] = true
    if signature.len > 0:
      signatures[signature] = true

  for want in wants:
    let consumerThing = want.consumerThing.strip
    if consumerThing.len > 0:
      thingNames[consumerThing] = true
    let parsed = parseWantReference(want.reference)
    if parsed.thingName.len > 0:
      thingNames[parsed.thingName] = true

  for thingName, _ in thingNames.pairs:
    result.things.add(thingName)
  result.things.sort(system.cmp[string])

  for signature, _ in signatures.pairs:
    result.signatures.add(signature)
  result.signatures.sort(system.cmp[string])

  result.startupEligible = true
  for issue in result.resolution.issues:
    if issueIsFatal(issue):
      result.startupEligible = false
      break

# Flow: Raise on first fatal capability issue for startup gate behavior.
proc assertFatalFree*(resolution: CapabilityResolution) =
  for issue in resolution.issues:
    if issueIsFatal(issue):
      raise newException(ValueError,
        "capabilities: " & issue.detail & " (reference=" & issue.reference & ")")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
