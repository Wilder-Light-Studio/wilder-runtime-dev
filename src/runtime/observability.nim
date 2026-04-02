# Wilder Cosmos 0.4.0
# Module name: Observability
# Module Path: src/runtime/observability.nim
# Summary: Structured host observability for deterministic startup and shutdown.
# Simile: Like a flight recorder, it captures lifecycle signals without leaking cockpit contents.
# Memory note: host events must stay safe, structured, and easy to assert in tests.
# Flow: receive event request -> normalize message -> timestamp -> append to sink.

import std/[times, strutils]

type
  HostEventKind* = enum
    evStartupStep
    evReconcilePass
    evReconcileHalt
    evMigrate
    evPrefilterActivated
    evError
    evShutdown

  HostEvent* = object
    kind*: HostEventKind
    step*: string
    epochSeconds*: int64
    message*: string

  HostEventSink* = ref object
    events*: seq[HostEvent]

# Flow: Normalize event messages into a single safe line.
proc normalizeEventMessage(message: string): string =
  result = message.replace("\r", " ").replace("\n", " ").strip
  while "  " in result:
    result = result.replace("  ", " ")
  if result.len == 0:
    result = "event recorded"

# Flow: Create an empty in-memory event sink.
proc newHostEventSink*(): HostEventSink =
  result = HostEventSink(events: @[])

# Flow: Append a structured event to the sink with the current Unix timestamp.
proc logEvent*(sink: HostEventSink,
               kind: HostEventKind,
               step: string,
               message: string) =
  if sink.isNil:
    return
  sink.events.add(HostEvent(
    kind: kind,
    step: step.strip,
    epochSeconds: getTime().toUnix,
    message: normalizeEventMessage(message)
  ))

# Flow: Return the number of recorded events of a given kind.
proc countEvents*(sink: HostEventSink, kind: HostEventKind): int =
  if sink.isNil:
    return 0
  for event in sink.events:
    if event.kind == kind:
      inc result

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
