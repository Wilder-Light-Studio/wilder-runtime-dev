# Wilder Cosmos 0.4.0
# Module name: prefilter_table_generated
# Module Path: src/runtime/prefilter_table_generated.nim
#
# Summary: Auto-generated validation prefilter table — deterministic
#   baseline for signature-keyed rule lookup.
# Simile: Like a pre-printed customs form — every valid shape is
#   already defined before the payload arrives.
# Memory note: never edit by hand; regenerate from canonical
#   signature and schema sources.
# Flow: provide source digests -> supply generated ValidationRecords
#   -> used by ValidationMembrane at startup.
## prefilter_table_generated.nim
## Auto-generated validation prefilter table (deterministic baseline).
## This file is generated from canonical signature sources.

import validation

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc generatedSourceDigests*(): seq[string] =
  result = @[
    "spec:24.9",
    "schema:runtime-v1",
    "proto:messaging-v1"
  ]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc generatedValidationRecords*(): seq[ValidationRecord] =
  let pingArg = ArgumentRule(
    name: "payload",
    expectedType: ptObject,
    required: true,
    fields: @[
      FieldRule(path: "message", expectedType: ptString, required: true, minItems: -1, maxItems: -1)
    ],
    extraFieldPolicy: efIgnoreUnknown,
    enforceOrdering: false,
    knownFieldOrder: @[],
    minItems: -1,
    maxItems: -1
  )

  result = @[
    buildValidationRecord(
      "runtime",
      "Ping",
      1,
      @[pingArg],
      "record:runtime:ping:v1"
    )
  ]

# Flow: Execute procedure with deterministic validation and bounded side effects.
proc loadGeneratedValidationIndex*(): ValidationIndex =
  result = buildValidationIndex(
    generatedValidationRecords(),
    "gen-v1",
    generatedSourceDigests()
  )

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
