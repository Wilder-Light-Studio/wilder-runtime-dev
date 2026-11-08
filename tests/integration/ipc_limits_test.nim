# Wilder Cosmos 0.4.0
# Module name: ipc_limits_test Tests
# Module Path: tests/integration/ipc_limits_test.nim
#
# Summary: Proves the command channel has limits and survives hostile clients (MVP-VAL-6).
# Simile: Like a reception desk, one difficult visitor must not stop it serving the next.
# Memory note: uses free ports and its own server threads, so it never touches port 7700.
# Flow: start server thread -> send hostile input -> assert limits and continued service.
#
# Abbreviations used in this file:
#   IPC  = inter-process communication (the command channel)
#   JSON = JavaScript Object Notation
#   TCP  = Transmission Control Protocol
#   MiB  = mebibyte (1,048,576 bytes)
#   MVP  = minimum viable product

import unittest
import json
import std/[net, os, random, strutils, typedthreads]
import ../../src/runtime/coordinator_ipc
import ../../src/runtime/core

const
  MessageSizeLimitBytes = 1_048_576
  NestingDepthLimit = 64
  ClientWaitMilliseconds = 6000
  RandomizedTestSeed = 20261108
  RandomizedLineCount = 5000
  ValidPauseRequest = """{"id":"1","method":"pause","params":{}}"""

type
  ServerArguments = tuple[session: IpcSession, port: int, requestsToServe: int]

# Flow: Ask the operating system for a free localhost port.
proc findFreePort(): int =
  let probeSocket = newSocket()
  probeSocket.bindAddr(Port(0), "127.0.0.1")
  result = probeSocket.getLocalAddr()[1].int
  probeSocket.close()

# Flow: Serve the requested number of requests on the given port, then finish.
proc serveRequests(arguments: ServerArguments) {.thread.} =
  discard serveIpcTcp(arguments.session, IpcDefaultHost, arguments.port,
    arguments.requestsToServe)

# Flow: Build a pause request padded to exactly the given length in bytes.
proc pauseRequestOfLength(totalBytes: int): string =
  let prefix = """{"id":"1","method":"pause","padding":""""
  let suffix = "\"}"
  prefix & repeat('x', totalBytes - prefix.len - suffix.len) & suffix

# Flow: Build a pause request whose padding reaches the given total nesting depth.
proc pauseRequestOfDepth(totalDepth: int): string =
  let arrayLevels = totalDepth - 1 # The request object itself is one level.
  """{"id":"1","method":"pause","padding":""" &
    repeat('[', arrayLevels) & repeat(']', arrayLevels) & "}"

# Flow: Send one valid request and return the reply line, or "" if none arrives.
proc requestReply(port: int): string =
  let clientSocket = newSocket()
  try:
    clientSocket.connect("127.0.0.1", Port(port))
    clientSocket.send(ValidPauseRequest & "\n")
    result = clientSocket.recvLine(timeout = ClientWaitMilliseconds)
  except CatchableError:
    result = ""
  finally:
    clientSocket.close()

suite "command channel limits":
  test "defect 11: a message over the size limit is refused before it runs":
    let session = newIpcSession(newRuntimeLifecycle())
    let replies = dispatchRequestLine(session,
      pauseRequestOfLength(MessageSizeLimitBytes + 1))
    check replies.len == 1
    check parseJson(replies[0])["error"]["code"].getStr() == "invalid_request"
    check "size limit" in parseJson(replies[0])["error"]["message"].getStr()
    check not session.state.paused

  test "a message at the size limit is accepted":
    let session = newIpcSession(newRuntimeLifecycle())
    discard dispatchRequestLine(session, pauseRequestOfLength(MessageSizeLimitBytes))
    check session.state.paused

  test "a message nested past the limit is refused before it runs":
    let session = newIpcSession(newRuntimeLifecycle())
    let replies = dispatchRequestLine(session,
      pauseRequestOfDepth(NestingDepthLimit + 1))
    check replies.len == 1
    check "nesting limit" in parseJson(replies[0])["error"]["message"].getStr()
    check not session.state.paused

  test "a message nested at the limit is accepted":
    let session = newIpcSession(newRuntimeLifecycle())
    discard dispatchRequestLine(session, pauseRequestOfDepth(NestingDepthLimit))
    check session.state.paused

  test "brackets inside text don't count as nesting":
    let session = newIpcSession(newRuntimeLifecycle())
    let bracketText = repeat('[', NestingDepthLimit * 2)
    let request = """{"id":"1","method":"pause","padding":"""" & bracketText & "\"}"
    discard dispatchRequestLine(session, request)
    check session.state.paused

  test "random and damaged lines always get a reply and never crash":
    let session = newIpcSession(newRuntimeLifecycle())
    var randomSource = initRand(RandomizedTestSeed)
    var linesWithoutReply = 0
    for lineNumber in 1 .. RandomizedLineCount:
      var line = ValidPauseRequest
      if lineNumber mod 2 == 0:
        line = newString(randomSource.rand(200))
        for position in 0 ..< line.len:
          line[position] = char(randomSource.rand(255))
      else:
        for _ in 1 .. 3:
          line[randomSource.rand(line.high)] = char(randomSource.rand(255))
      # A newline can't arrive inside one received line, so damage never adds one.
      if dispatchRequestLine(session, line.replace("\n", " ")).len == 0:
        inc linesWithoutReply
    check linesWithoutReply == 0

suite "command channel survives hostile clients":
  test "defect 12: a client that sends nothing doesn't block the next one":
    let port = findFreePort()
    var serverThread: Thread[ServerArguments]
    createThread(serverThread, serveRequests,
      (newIpcSession(newRuntimeLifecycle()), port, 1))
    sleep(200) # Give the server time to start listening.

    let silentClient = newSocket()
    silentClient.connect("127.0.0.1", Port(port))
    sleep(100) # Let the server begin waiting on the silent client.

    let reply = requestReply(port)
    silentClient.close()
    check reply.len > 0
    if reply.len > 0:
      joinThread(serverThread)

  test "a client that sends too much doesn't stop the server":
    let port = findFreePort()
    var serverThread: Thread[ServerArguments]
    createThread(serverThread, serveRequests,
      (newIpcSession(newRuntimeLifecycle()), port, 2))
    sleep(200) # Give the server time to start listening.

    let floodingClient = newSocket()
    try:
      floodingClient.connect("127.0.0.1", Port(port))
      floodingClient.send(repeat('x', MessageSizeLimitBytes + 1000) & "\n")
      discard floodingClient.recvLine(timeout = ClientWaitMilliseconds)
    except CatchableError:
      discard # The server may close the connection first, which is acceptable.
    finally:
      floodingClient.close()

    let reply = requestReply(port)
    check reply.len > 0
    if reply.len > 0:
      joinThread(serverThread)

# --
# (C) Copyright 2026, Wilder. All rights reserved.
# Contact: teamwilder@wildercode.org
# GitHub: github.com/wilder-light-studio
# Codeberg: codeberg.org/wilder-light-studio
# Licensed under the Wilder Foundation License 1.0.
# See LICENSE for details.
