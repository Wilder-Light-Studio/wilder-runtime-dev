# Wilder Cosmos 0.4.0
# Module name: CLI Parser Test
# Module Path: tests/unit/cli_parser_test.nim
# Summary: Unit tests for the Git-style CLI grammar parser.

import std/[os, strutils]
import cli_parser
import unittest

proc testParseStart() =
  let args = @["start", "--mode=step"]
  let res = parseArgs(args)
  assert res.isOk
  let cmd = res.get()
  assert cmd.verb == cvStart
  assert cmd.flags.hasKey("--mode")
  assert cmd.flags["--mode"] == "step"

proc testParseAddWatch() =
  let args = @["add", "watch", "/tmp/app"]
  let res = parseArgs(args)
  assert res.isOk
  let cmd = res.get()
  assert cmd.verb == cvAdd
  assert cmd.noun == nnWatch
  assert cmd.args[0] == "/tmp/app"

proc testParseAddThing() =
  let args = @["add", "thing", "mything.cosmos"]
  let res = parseArgs(args)
  assert res.isOk
  let cmd = res.get()
  assert cmd.verb == cvAdd
  assert cmd.noun == nnThing
  assert cmd.args[0] == "mything.cosmos"

proc testParseConsole() =
  let args = @["console"]
  let res = parseArgs(args)
  assert res.isOk
  assert res.get().verb == cvConsole

proc testParseInvalidVerb() =
  let args = @["unknown"]
  let res = parseArgs(args)
  assert res.isErr

proc testParseMissingNoun() =
  let args = @["add", "/tmp/app"]
  let res = parseArgs(args)
  assert res.isErr

proc testParseHelp() =
  let args = @["--help"]
  let res = parseArgs(args)
  assert res.isErr # Returns UsageText as error

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