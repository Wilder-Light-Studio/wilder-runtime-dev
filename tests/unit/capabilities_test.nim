# Wilder Cosmos 0.4.0
# Module name: capabilities_test Tests
# Module Path: tests/unit/capabilities_test.nim
# Summary: Edge-focused tests for capability graph resolution and failure classes.
# Simile: Like a circuit tester, each case checks one wiring fault before startup can proceed.
# Memory note: fatal resolution issues must be explicit and deterministic.
# Flow: define declarations -> resolve capabilities -> assert bindings and issues.

import unittest
import std/sequtils
import ../../src/runtime/capabilities

suite "capability resolution":
  test "exact capability resolves with matching signature":
    let provides = @[
      ProvideDeclaration(thingName: "Lexicons", provideName: "get", signature: "(string)->string")
    ]
    let wants = @[
      WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get", expectedSignature: "(string)->string")
    ]
    let resolution = resolveCapabilities(provides, wants)
    check resolution.bindings.len == 1
    check resolution.bindings[0].providerThing == "Lexicons"
    check resolution.bindings[0].provideName == "get"
    check resolution.issues.len == 0

  test "whole thing want expands deterministically":
    let provides = @[
      ProvideDeclaration(thingName: "Store", provideName: "fetch", signature: "()->json"),
      ProvideDeclaration(thingName: "Store", provideName: "put", signature: "(json)->bool")
    ]
    let wants = @[
      WantDeclaration(consumerThing: "Sync", reference: "Store", expectedSignature: "")
    ]
    let resolution = resolveCapabilities(provides, wants)
    check resolution.bindings.len == 2
    check resolution.bindings[0].provideName == "fetch"
    check resolution.bindings[1].provideName == "put"
    check resolution.issues.len == 0

  test "missing provider thing is reported as fatal issue":
    let wants = @[
      WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get", expectedSignature: "")
    ]
    let resolution = resolveCapabilities(@[], wants)
    check resolution.bindings.len == 0
    check resolution.issues.len == 1
    check resolution.issues[0].kind == cikMissingProviderThing

  test "missing provide is reported as fatal issue":
    let provides = @[
      ProvideDeclaration(thingName: "Lexicons", provideName: "put", signature: "(string)->bool")
    ]
    let wants = @[
      WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get", expectedSignature: "")
    ]
    let resolution = resolveCapabilities(provides, wants)
    check resolution.bindings.len == 0
    check resolution.issues.anyIt(it.kind == cikMissingProvide)

  test "duplicate provider declaration is conflict":
    let provides = @[
      ProvideDeclaration(thingName: "Lexicons", provideName: "get", signature: "(string)->string"),
      ProvideDeclaration(thingName: "Lexicons", provideName: "get", signature: "(string)->string")
    ]
    let wants = @[
      WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get", expectedSignature: "")
    ]
    let resolution = resolveCapabilities(provides, wants)
    check resolution.bindings.len == 0
    check resolution.issues.anyIt(it.kind == cikProviderConflict)

  test "signature mismatch is fatal issue":
    let provides = @[
      ProvideDeclaration(thingName: "Lexicons", provideName: "get", signature: "(string)->string")
    ]
    let wants = @[
      WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get", expectedSignature: "(int)->string")
    ]
    let resolution = resolveCapabilities(provides, wants)
    check resolution.bindings.len == 0
    check resolution.issues.anyIt(it.kind == cikSignatureMismatch)

  test "orphaned provide is reported as non-fatal issue":
    let provides = @[
      ProvideDeclaration(thingName: "Telemetry", provideName: "publish", signature: "(json)->bool")
    ]
    let resolution = resolveCapabilities(provides, @[])
    check resolution.bindings.len == 0
    check resolution.issues.len == 1
    check resolution.issues[0].kind == cikOrphanedProvide

suite "fatal gate":
  test "assertFatalFree passes when only orphaned issues exist":
    let provides = @[
      ProvideDeclaration(thingName: "Telemetry", provideName: "publish", signature: "(json)->bool")
    ]
    let resolution = resolveCapabilities(provides, @[])
    assertFatalFree(resolution)

  test "assertFatalFree raises when fatal issue exists":
    let wants = @[
      WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get", expectedSignature: "")
    ]
    let resolution = resolveCapabilities(@[], wants)
    expect(ValueError):
      assertFatalFree(resolution)

suite "want reference parser":
  test "thing reference parses as whole thing":
    let parsed = parseWantReference("Store")
    check parsed.thingName == "Store"
    check parsed.provideName == ""
    check parsed.isWholeThing

  test "thing provide reference parses":
    let parsed = parseWantReference("Store.fetch")
    check parsed.thingName == "Store"
    check parsed.provideName == "fetch"
    check not parsed.isWholeThing

  test "invalid reference raises":
    expect(ValueError):
      discard parseWantReference("Store.")

suite "capability graph and module bindings":
  test "capability graph includes things signatures and startup eligibility":
    let provides = @[
      ProvideDeclaration(thingName: "Lexicons", provideName: "get", signature: "(string)->string")
    ]
    let wants = @[
      WantDeclaration(consumerThing: "Parser", reference: "Lexicons.get", expectedSignature: "")
    ]
    let bindings = @[
      ModuleBindingDeclaration(
        provideKey: "Lexicons.get",
        moduleType: "nim",
        moduleRef: "src/runtime/lexicons.nim",
        entrypoint: "registerLexicons",
        abiVersion: "cap-abi-v1"
      )
    ]

    let graph = buildCapabilityGraph(provides, wants, bindings, enforceBindingCoverage = true)
    check graph.things == @["Lexicons", "Parser"]
    check graph.signatures == @["(string)->string"]
    check graph.moduleBindings.len == 1
    check graph.startupEligible

  test "missing implementation is fatal when enforcement enabled":
    let provides = @[
      ProvideDeclaration(thingName: "Lexicons", provideName: "get", signature: "(string)->string")
    ]
    let resolution = resolveCapabilities(
      provides,
      @[],
      @[],
      enforceBindingCoverage = true
    )
    check resolution.issues.anyIt(it.kind == cikMissingImplementation)
    expect(ValueError):
      assertFatalFree(resolution)

  test "undeclared implementation is fatal":
    let bindings = @[
      ModuleBindingDeclaration(
        provideKey: "GhostThing.ping",
        moduleType: "binary",
        moduleRef: "ghost.exe",
        entrypoint: "main",
        abiVersion: "cap-abi-v1"
      )
    ]
    let resolution = resolveCapabilities(@[], @[], bindings)
    check resolution.issues.anyIt(it.kind == cikUndeclaredProvideImplementation)
    expect(ValueError):
      assertFatalFree(resolution)

  test "duplicate implementation bindings are fatal":
    let provides = @[
      ProvideDeclaration(thingName: "Lexicons", provideName: "get", signature: "(string)->string")
    ]
    let bindings = @[
      ModuleBindingDeclaration(
        provideKey: "Lexicons.get",
        moduleType: "nim",
        moduleRef: "src/runtime/lexicons_a.nim",
        entrypoint: "registerA",
        abiVersion: "cap-abi-v1"
      ),
      ModuleBindingDeclaration(
        provideKey: "Lexicons.get",
        moduleType: "python",
        moduleRef: "lexicons.py",
        entrypoint: "register_b",
        abiVersion: "cap-abi-v1"
      )
    ]
    let resolution = resolveCapabilities(provides, @[], bindings)
    check resolution.issues.anyIt(it.kind == cikImplementationConflict)
    expect(ValueError):
      assertFatalFree(resolution)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
