# Wilder Cosmos 0.4.0
# Module name: CLI Parser
# Module Path: src/cli_parser.nim
# Summary: Git-style CLI grammar parser for the Cosmos Runtime.
# Grammar: cosmos [flags] <verb> [noun] [args]

import std/[strutils, tables]
import runtime/result

type
  CommandVerb* = enum
    cvStart, cvStop, cvRestart,
    cvAdd, cvRemove, cvList,
    cvMode, cvInspect, cvStep,
    cvConsole
    
  CommandNoun* = enum
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

proc parseArgs*(args: seq[string]): Result[ParsedCommand] =
  if args.len == 0:
    return err[ParsedCommand]("No command provided. Use 'cosmos --help' for usage.")

  var cmd: ParsedCommand
  cmd.flags = initTable[string, string]()
  var i = 0
  
  # Parse flags first
  while i < args.len and args[i].startsWith("--"):
    let flag = args[i]
    if flag == "--help" or flag == "-h":
      return err[ParsedCommand](UsageText)
    
    if "=" in flag:
      let parts = flag.split('=')
      cmd.flags[parts[0]] = parts[1]
    else:
      cmd.flags[flag] = "true"
    i += 1

  if i >= args.len:
    return err[ParsedCommand]("Missing verb. Use 'cosmos --help' for usage.")

  # Parse Verb
  case args[i].toLowerAscii
  of "start":   cmd.verb = cvStart
  of "stop":    cmd.verb = cvStop
  of "restart": cmd.verb = cvRestart
  of "add":     cmd.verb = cvAdd
  of "remove":  cmd.verb = cvRemove
  of "list":    cmd.verb = cvList
  of "mode":    cmd.verb = cvMode
  of "inspect": cmd.verb = cvInspect
  of "step":    cmd.verb = cvStep
  of "console": cmd.verb = cvConsole
  else:
    return err[ParsedCommand]("Unknown verb '" & args[i] & "'. Use 'cosmos --help' for usage.")
  i += 1

  # Parse Noun (if applicable)
  cmd.noun = nnNone
  if i < args.len:
    case args[i].toLowerAscii
    of "watch": cmd.noun = nnWatch
    of "thing", "things": cmd.noun = nnThing
    of "world": cmd.noun = nnWorld
    of "events": cmd.noun = nnEvent
    of "busses": cmd.noun = nnBus
    else:
      # If it's not a known noun, it might be an argument for the verb
      # But for 'add', 'remove', 'list', a noun is expected.
      if cmd.verb in [cvAdd, cvRemove, cvList]:
        return err[ParsedCommand]("Expected noun (watch|thing) after verb '" & $cmd.verb & "'.")
  
  if cmd.noun != nnNone:
    i += 1

  # Remaining are args
  while i < args.len:
    cmd.args.add(args[i])
    i += 1

  return ok(cmd)
