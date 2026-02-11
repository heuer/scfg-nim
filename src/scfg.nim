#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
##
## SCFG (simple configuration file format) deserializer.
##
## Format specification: <https://codeberg.org/emersion/scfg>
##
import std/[streams, strutils]

type
  ScfgError* = object of ValueError
    line*: int


  ScfgEventKind* = enum
    evt_start  ## Indicates the start of a directive
    evt_end  ## Indicates the end of a directive


  ScfgEvent* = object
    ## Indicates if the event has a block.
    ## It cannot be assumed that the directive has children, it merly
    ## symbolizes that the directive has an openig block `{`, or in case
    ## of the `end` event that a block was closed.
    has_block*: bool
    case kind*: ScfgEventKind
    of evt_start:
      name*: string  ## Directive name
      params*: seq[string]  ## Directive parameters
      line*: int  ## Line number from the scfg doc
    of evt_end:
      discard


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


const
  NO_QUOTE = '\0'
  EVT_END_DIRECTIVE = ScfgEvent(kind: evt_end, has_block: false)
  EVT_END_BLOCK = ScfgEvent(kind: evt_end, has_block: true)


func error(msg: string, line: int) {.noReturn.} =
  let ex = new_exception(ScfgError, msg & " Line: " & $line)
  ex.line = line
  raise ex


func eat_space(s: string, i: var int) =
  while i < s.len and s[i] in {' ', '\t'}:
    inc i


func split_words(line: string, line_no: int, col: var int): seq[string] =
  var
    word = ""
    quote = NO_QUOTE
  while col < line.len:
    let c = line[col]
    if c == '\\':
      if quote == '\'':
        word.add(c)
        inc col
        continue
      inc col
      if col >= line.len:
        error("Unfinished escape sequence.", line_no)
      word.add(line[col])
    elif quote == NO_QUOTE:
      if c in {'{', '}'}:
        var i = col + 1
        eat_space(line, i)
        if i < line.len:
          error("Expected newline after '" & c & "'.", line_no)
        if c == '}' and result.len != 0:  # This is an artificial prohibition but enforced by the grammar…
          error("The end of a block marker '}' must be alone on a line.", line_no)
        return
      if c in {' ', '\t'}:
        if word.len > 0:
          result.add(word)
          word = ""
      elif c in {'"', '\''}:
        if word.len > 0:
          result.add(word)
          word = ""
        quote = c
      else:
        word.add(c)
    else:
      if c == quote:
        result.add(word)
        word = ""
        quote = NO_QUOTE
      else:
        word.add(c)
    inc col
  if word.len > 0:
    result.add(word)
  if quote != NO_QUOTE:
    error("Unclosed string literal.", line_no)


iterator parse_scfg*(stream: Stream): ScfgEvent =
  ## Parses the scfg from the provided stream and issues events.
  var
    line_no = 0
    open_blocks = 0

  while not stream.at_end():
    var line = stream.read_line()
    var col = 0
    inc line_no
    eat_space(line, col)

    if col >= line.len or line[col] == '#':
      continue

    let words = split_words(line, line_no, col)

    if col < line.len and line[col] == '}':
      if open_blocks == 0:
        error("Unexpected block closing '}' without opening '{'.", line_no)
      dec open_blocks
      yield EVT_END_BLOCK
      continue

    if words.len == 0:
      continue

    let has_block = col < line.len and line[col] == '{'

    yield ScfgEvent(
      kind: evt_start,
      name: words[0],
      params: if words.len > 1: words[1..^1] else: @[],
      has_block: has_block,
      line: line_no
    )

    if has_block:
      inc open_blocks
    else:
      yield EVT_END_DIRECTIVE

  if open_blocks > 0:
    error("Unclosed block: Expected '}'.", line_no)


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

