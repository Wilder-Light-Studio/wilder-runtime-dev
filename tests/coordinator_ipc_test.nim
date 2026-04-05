# Wilder Cosmos 0.4.0
# Module name: coordinator_ipc_test Tests
# Module Path: tests/coordinator_ipc_test.nim
# Summary: Contract tests for coordinator IPC request handling and notification formatting.
# Simile: Like checking control-panel switches, each test confirms one deterministic command path.
# Memory note: assert schema shape and stable error behavior for malformed and unknown requests.
# Flow: create session -> submit request -> assert response and queued events.

import unittest
import json
import std/strutils
import ../src/runtime/coordinator_ipc

suite "coordinator IPC endpoint and request schema":
  test "endpoint enforces localhost host and valid port":
    check ipcEndpointUri("127.0.0.1", 7700) == "tcp://127.0.0.1:7700"
    expect(ValueError):
      discard ipcEndpointUri("0.0.0.0", 7700)
    expect(ValueError):
      discard ipcEndpointUri("localhost", 0)

  test "invalid request returns invalid_request error envelope":
    let session = newIpcSession()
    let response = handleRequest(session, %*{"method": "pause", "params": {}})
    check response.hasKey("error")
    check response["error"]["code"].getStr() == "invalid_request"

suite "coordinator IPC method behavior":
  test "pause and resume mutate paused state":
    let session = newIpcSession()
    let pauseResp = handleRequest(session, %*{"id": "1", "method": "pause", "params": {}})
    check pauseResp["result"]["paused"].getBool()
    let resumeResp = handleRequest(session, %*{"id": "2", "method": "resume", "params": {}})
    check resumeResp["result"]["paused"].getBool() == false

  test "step and snapshot advance counters deterministically":
    let session = newIpcSession()
    let stepResp = handleRequest(session, %*{"id": "1", "method": "step", "params": {}})
    check stepResp["result"]["tick"].getInt() == 1
    let snapResp = handleRequest(session, %*{"id": "2", "method": "snapshot", "params": {}})
    check snapResp["result"]["revision"].getInt() == 1
    check snapResp["result"]["snapshotId"].getStr() == "snapshot-1"

  test "inspect includes required deterministic state fields":
    let session = newIpcSession()
    let response = handleRequest(session, %*{"id": "1", "method": "inspect", "params": {}})
    check response.hasKey("result")
    check response["result"].hasKey("paused")
    check response["result"].hasKey("tempoHz")
    check response["result"].hasKey("health")
    check response["result"].hasKey("things")
    check response["result"].hasKey("reconciliation")

  test "unknown method returns method_not_found error":
    let session = newIpcSession()
    let response = handleRequest(session, %*{"id": "1", "method": "does.not.exist", "params": {}})
    check response.hasKey("error")
    check response["error"]["code"].getStr() == "method_not_found"

suite "coordinator IPC subscriptions and notifications":
  test "subscribed event is queued and drained":
    let session = newIpcSession()
    discard handleRequest(session, %*{
      "id": "sub",
      "method": "subscribe",
      "params": {"events": ["runtime.paused"]}
    })
    discard handleRequest(session, %*{"id": "1", "method": "pause", "params": {}})
    let events = drainPushEvents(session)
    check events.len == 1
    check events[0]["event"].getStr() == "runtime.paused"

  test "format notification line normalizes level and preserves shape":
    let line = formatNotificationLine("2026-04-05T10:00:00Z", "info", "runtime", "started")
    check line == "[2026-04-05T10:00:00Z] [INFO] [runtime] started"
    check line.contains("[INFO]")

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.