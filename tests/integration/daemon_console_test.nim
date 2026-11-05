# Wilder Cosmos 0.4.0
# Module name: Daemon Console Integration Test
# Module Path: tests/integration/daemon_console_test.nim
# Summary: Integration tests for the Daemon -> IPC -> Console flow.

import std/[os, strutils, json, net, typedthreads]
import runtime/coordinator_ipc
import runtime/core
import runtime/bundle_loader

# Flow: Ask the OS for a free localhost port so the test never collides with 7700.
proc freePort(): int =
  let probe = newSocket()
  probe.bindAddr(Port(0), "127.0.0.1")
  result = probe.getLocalAddr()[1].int
  probe.close()

let testPort = freePort()
var serverThread: Thread[IpcSession]

# Flow: Serve IPC requests on the test port until the process exits.
proc serveForTest(session: IpcSession) {.thread.} =
  discard serveIpcTcp(session, IpcDefaultHost, testPort)

# Flow: Start a daemon in a background thread for testing.
proc startTestDaemon() =
  let session = newIpcSession(newRuntimeLifecycle())
  createThread(serverThread, serveForTest, session)
  sleep(200) # Give server time to bind

proc testConsoleFlow() =
  echo "Testing Console IPC Flow..."
  
  # 1. Test Attach
  let attachReq = %*{
    "id": "test-1",
    "method": "runtime.attach",
    "params": %*{"identity": "test-op"}
  }
  let attachRes = sendIpcTcpRequest(IpcDefaultHost, testPort, attachReq)
  assert attachRes.len > 0
  assert attachRes[0]["result"]["status"].getStr() == "attached"
  echo "  [x] Attach successful"

  # 2. Test Render
  let renderReq = %*{
    "id": "test-2",
    "method": "runtime.console_render",
    "params": %*{}
  }
  let renderRes = sendIpcTcpRequest(IpcDefaultHost, testPort, renderReq)
  assert renderRes.len > 0
  let renderText = renderRes[0]["result"]["render"].getStr()
  assert "Wilder Cosmos Runtime" in renderText
  assert "[test-op]" in renderText
  echo "  [x] Render successful"

  # 3. Test Dispatch (pwd)
  let dispatchReq = %*{
    "id": "test-3",
    "method": "runtime.console_dispatch",
    "params": %*{"input": "pwd"}
  }
  let dispatchRes = sendIpcTcpRequest(IpcDefaultHost, testPort, dispatchReq)
  assert dispatchRes.len > 0
  assert dispatchRes[0]["result"]["ok"].getBool() == true
  echo "  [x] Dispatch (pwd) successful"

proc testBundleIpcFlow() =
  echo "Testing Bundle IPC Flow..."
  
  # Setup a dummy bundle
  let bundleDir = "test_ipc_bundle.cosmos"
  createDir(bundleDir)
  writeFile(bundleDir & "/manifest.json", """{"id": "ipc-thing", "version": "1.0", "dependencies": [], "capabilities": [], "entryPoints": {}}""")
  
  try:
    # 1. Test Valid Bundle Add
    let addReq = %*{
      "id": "test-4",
      "method": "runtime.addThing",
      "params": %*{"bundle": bundleDir}
    }
    let addRes = sendIpcTcpRequest(IpcDefaultHost, testPort, addReq)
    assert addRes.len > 0
    assert addRes[0]["result"]["status"].getStr() == "installed"
    echo "  [x] Valid bundle install successful"

    # 2. Test Invalid Bundle Add
    let badReq = %*{
      "id": "test-5",
      "method": "runtime.addThing",
      "params": %*{"bundle": "non_existent.cosmos"}
    }
    let badRes = sendIpcTcpRequest(IpcDefaultHost, testPort, badReq)
    assert badRes.len > 0
    assert badRes[0].hasKey("error")
    echo "  [x] Invalid bundle error handled"
  finally:
    removeDir(bundleDir)

proc main() =
  startTestDaemon()
  try:
    testConsoleFlow()
    testBundleIpcFlow()
    echo "All Daemon Console Integration tests passed!"
  except Exception as e:
    echo "Integration test failed: " & e.msg
    quit(1)

when isMainModule:
  main()