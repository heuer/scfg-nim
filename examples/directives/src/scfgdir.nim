#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
##
## This examples shows how to build a data structure from the scfg events.
##
import std/[streams, strutils]
import scfg

type
  Directive* = ref object
    name*: string  ## Directive name
    params*: seq[string]  ## Directive parameters
    children*: Block
    ## Indicates if the directive has a block: `{ […] }`
    ## This might be useful to know because a directive with an empty block
    ## (children sequence is empty) behaves identical to a directive w/o a block.
    has_block*: bool
    line*: int  ## Line number from the scfg doc


  Block* = seq[Directive]


func error(msg: string, line: int) {.noReturn.} =
  raise new_exception(ValueError, "Error line " & $line & ": " & msg)


proc read_scfg*(stream: Stream): Block =
  ## Reads the scfg from the provided stream and returns a (maybe empty) Block.
  var stack: Block

  for event in parse_scfg(stream):
    case event.kind
    of evt_start:
      let directive = Directive(name: event.name, params: event.params,
                                has_block: event.has_block, line: event.line,
                                children: @[])
      if stack.len == 0:
        result.add directive
      else:
        stack[^1].children.add directive
      if event.has_block:
        stack.add directive
    of evt_end:
      if event.has_block:
        discard stack.pop()


proc read_scfg*(s: string): Block =
  ## Reads the scfg from the provided string and returns a (maybe empty) Block.
  return read_scfg(new_string_stream(s))


proc load_scfg*(path: string): Block =
  ## Reads the scfg from a file provided by the path name and returns a
  ## (maybe empty) Block.
  let stream = new_file_stream(path, fm_read)
  if stream == nil:
    raise new_exception(IOError, "Cannot open file: " & path)
  defer: stream.close()
  return read_scfg(stream)


func to_str*(directive: Directive): string =
  ## Returns the first param of the directive.
  ## Raises a `ValueError` if the directive has less or more params.
  if directive.params.len != 1:
    error("Expected exactly one value for " & directive.name, directive.line)
  return directive.params[0]


func to_int*(directive: Directive): int =
  ## Returns the first param of the directive if it is an integer.
  ## Raises a `ValueError` otherwise.
  ##
  ## .. note:: A value of 10_000 is interpreted as a valid integer.
  let s = to_str(directive)
  try:
    return parse_int(s)
  except ValueError:
    error("Expected an integer for " & directive.name & " got: " & s,
          directive.line)


func to_uint*(directive: Directive): uint =
  ## Returns the first param of the directive if it is an unsigned integer.
  ## Raises a `ValueError` otherwise.
  let s = to_str(directive)
  try:
    return parse_uint(s)
  except ValueError:
    error("Expected an unsigned integer for " & directive.name & " got: " & s,
          directive.line)


func to_float*(directive: Directive): float =
  ## Returns the first param of the directive if it is a decimal floating point.
  ## Raises a `ValueError` otherwise.
  let s = to_str(directive)
  try:
    return parse_float(s)
  except ValueError:
    error("Expected a decimal floating point for " & directive.name &
          " got: " & s, directive.line)

