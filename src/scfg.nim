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


  Directive* = ref object
    name*: string
    params*: seq[string]
    children*: Block
    has_block*: bool
    line*: int


  Block* = seq[Directive]


const
  NO_QUOTE = '\0'
  MAX_DEPTH = 1000


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


proc read_block(s: Stream, line_no: var int, depth: int, expect_close=false): Block =
  if depth >= MAX_DEPTH:
    error("Block nesting depth exceeded.", line_no)

  while not s.at_end():
    var line = s.read_line()
    var col = 0
    inc line_no
    eat_space(line, col)
    if col >= line.len or line[col] == '#':
      continue
    let words = split_words(line, line_no, col)
    if col < line.len and line[col] == '}':
      if not expect_close:
        error("Unexpected block closing '}' without opening '{'.", line_no)
      return result
    if words.len == 0:
      continue
    let has_block = col < line.len and line[col] == '{'
    result.add(
      Directive(
        name: words[0],
        params: if words.len > 1: words[1..^1] else: @[],
        line: line_no,
        has_block: has_block,
        children: if has_block: read_block(s, line_no, depth + 1, true) else: @[],
      )
    )
  if expect_close:
    error("Unclosed block: Expected '}'.", line_no)


proc read_scfg*(stream: Stream): Block =
  ## Reads the scfg from the provided stream and returns a (maybe empty) Block.
  var line_no = 0
  return read_block(stream, line_no, 0)


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
  ## Raises a `ValueError` if less or more params are provided
  if directive.params.len != 1 or directive.has_block:
    error("Expected exactly one value for " & directive.name, directive.line)
  return directive.params[0]


func to_int*(directive: Directive): int =
  ## Returns the first param of the directive if it is an integer.
  ## Raises a `ValueError` otherwise.
  ##
  ## .. note:: A value of 10_000 is iterpreted as a valid integer.
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

