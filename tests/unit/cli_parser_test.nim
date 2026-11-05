# Wilder Cosmos 0.4.0
# Module name: CLI Parser Test
# Module Path: tests/unit/cli_parser_test.nim
# Summary: Unit tests for the Git-style CLI grammar parser.
# Simile: Like reading back an order — each command line should come back as
#   exactly the request that was meant.
# Memory note: tests call parseArgs only; nothing starts or connects.
# Flow: build args -> parse -> check verb, noun, flags or error.

import std/[os, strutils, tables]
import cli_parser
import runtime/result
import unittest

# Flow: Parse start with a mode flag.
proc testParseStart() =
  let args = @["start", "--mode=step"]
  let res = parseArgs(args)
  assert res.isOk
  let cmd = res.get()
  assert cmd.verb == cvStart
  assert cmd.flags.hasKey("--mode")
  assert cmd.flags["--mode"] == "step"

# Flow: Parse add watch with its target.
proc testParseAddWatch() =
  let args = @["add", "watch", "/tmp/app"]
  let res = parseArgs(args)
  assert res.isOk
  let cmd = res.get()
  assert cmd.verb == cvAdd
  assert cmd.noun == nnWatch
  assert cmd.args[0] == "/tmp/app"

# Flow: Parse add thing with its bundle path.
proc testParseAddThing() =
  let args = @["add", "thing", "mything.cosmos"]
  let res = parseArgs(args)
  assert res.isOk
  let cmd = res.get()
  assert cmd.verb == cvAdd
  assert cmd.noun == nnThing
  assert cmd.args[0] == "mything.cosmos"

# Flow: Parse console with no arguments.
proc testParseConsole() =
  let args = @["console"]
  let res = parseArgs(args)
  assert res.isOk
  assert res.get().verb == cvConsole

# Flow: Reject an unknown verb.
proc testParseInvalidVerb() =
  let args = @["unknown"]
  let res = parseArgs(args)
  assert res.isErr

# Flow: Reject add with a missing noun.
proc testParseMissingNoun() =
  let args = @["add", "/tmp/app"]
  let res = parseArgs(args)
  assert res.isErr

# Flow: Return usage text as an error for --help.
proc testParseHelp() =
  let args = @["--help"]
  let res = parseArgs(args)
  assert res.isErr # Returns UsageText as error

# Flow: Run each CLI parser test in order.
proc main() =
  echo "Running CLI Parser Tests..."
  testParseStart()
  echo "  [x] testParseStart"
  testParseAddWatch()
  echo "  [x] testParseAddWatch"
  testParseAddThing()
  echo "  [x] testParseAddThing"
  testParseConsole()
  echo "  [x] testParseConsole"
  testParseInvalidVerb()
  echo "  [x] testParseInvalidVerb"
  testParseMissingNoun()
  echo "  [x] testParseMissingNoun"
  testParseHelp()
  echo "  [x] testParseHelp"
  echo "All CLI Parser tests passed!"

when isMainModule:
  main()
