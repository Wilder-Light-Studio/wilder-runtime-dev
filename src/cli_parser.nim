# Wilder Cosmos 0.4.0
# Module name: CLI Parser
# Module Path: src/cli_parser.nim
# Summary: Git-style CLI grammar parser for the Cosmos Runtime.
# Grammar: cosmos [flags] <verb> [noun] [args]

import std/[strutils, options, tables]
import runtime/core
import runtime/result

type
  CommandVerb = enum
    cvStart, cvStop, cvRestart,
    cvAdd, cvRemove, cvList,
    cvMode, cvInspect, cvStep,
    cvConsole
    
  CommandNoun = enum
    nnWatch, nnThing, nnWorld, nnEvent, nnBus, nnNone

  ParsedCommand* = object
    verb*: CommandVerb
    noun*: CommandNoun
    args*: seq[string]
    flags*: Table[string, string]

const
  UsageText* =
    "Cosmos Runtime CLI\n" &
    "\n" &
    "Usage: cosmos [flags] <verb> [noun] [args]\n" &
    "\n" &
    "Daemon Lifecycle:\n" &
    "  cosmos start [--mode=aware|step]   Start or attach to the daemon\n" &
    "  cosmos stop                       Stop the daemon\n" &
    "  cosmos restart                    Restart the daemon\n" &
    "\n" &
    "Watch Management:\n" &
    "  cosmos add watch <path>           Add a directory to watch\n" &
    "  cosmos remove watch <path>        Remove a directory from watch\n" &
    "  cosmos list watch                 List all watched directories\n" &
    "\n" &
    "Thing Management:\n" &
    "  cosmos add thing <bundle.cosmos>  Install a .cosmos bundle\n" &
    "  cosmos remove thing <id>          Remove a Thing by ID\n" &
    "  cosmos list things                List all installed Things\n" &
    "\n" &
    "Mode Switching:\n" &
    "  cosmos mode <step|aware|debug|encrypted|clear>  Switch introspection mode\n" &
    "\n" &
    "Introspection:\n" &
    "  cosmos inspect <world|thing <id>|events|busses>  Inspect runtime state\n" &
    "  cosmos console <command>           Interactive console access\n" &
    "\n" &
    "Frame Control:\n" &
    "  cosmos step [--count=N]           Advance the frame loop\n"

proc parseArgs*(args: seq[string]): Result[ParsedCommand, string] =
  if args.len == 0:
    return err("No command provided. Use 'cosmos --help' for usage.")

  var result: ParsedCommand
  result.flags = initTable[string, string]()
  var i = 0
  
  # Parse flags first
  while i < args.len and args[i].startsWith("--"):
    let flag = args[i]
    if flag == "--help" or flag == "-h":
      return err(UsageText)
    
    if "=" in flag:
      let parts = flag.split('=')
      result.flags[parts[0]] = parts[1]
    else:
      result.flags[flag] = "true"
    i += 1

  if i >= args.len:
    return err("Missing verb. Use 'cosmos --help' for usage.")

  # Parse Verb
  case args[i].toLowerAscii
  of "start":   result.verb = cvStart
  of "stop":    result.verb = cvStop
  of "restart": result.verb = cvRestart
  of "add":     result.verb = cvAdd
  of "remove":  result.verb = cvRemove
  of "list":    result.verb = cvList
  of "mode":    result.verb = cvMode
  of "inspect": result.verb = cvInspect
  of "step":    result.verb = cvStep
  of "console": result.verb = cvConsole
  else:
    return err("Unknown verb '" & args[i] & "'. Use 'cosmos --help' for usage.")
  i += 1

  # Parse Noun (if applicable)
  result.noun = nnNone
  if i < args.len:
    case args[i].toLowerAscii
    of "watch": result.noun = nnWatch
    of "thing", "things": result.noun = nnThing
    of "world": result.noun = nnWorld
    of "events": result.noun = nnEvent
    of "busses": result.noun = nnBus
    else:
      # If it's not a known noun, it might be an argument for the verb
      # But for 'add', 'remove', 'list', a noun is expected.
      if result.verb in [cvAdd, cvRemove, cvList]:
        return err("Expected noun (watch|thing) after verb '" & $result.verb & "'.")
  
  if result.noun != nnNone:
    i += 1

  # Remaining are args
  while i < args.len:
    result.args.add(args[i])
    i += 1

  return ok(result)