#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
##
## SCFG (simple configuration file format) deserializer.
##
## Format specification: <https://codeberg.org/emersion/scfg>
##
import std/[streams, options, sequtils]

type
  ScfgError* = object of ValueError
    line*: int
    col*: Option[int]


  Directive* = ref object
    name*: string
    params*: seq[string]
    children*: Block
    line*: int


  Block* = seq[Directive]


const NO_QUOTE = '\0'


func error(msg: string, line: int, col = -1) =
  let ex = new_exception(
    ScfgError, msg & " Line: " & $line & (if col > -1: ", column: " & $col else: "")
  )
  ex.line = line
  ex.col = if col > -1: some(col) else: none(int)
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
    case c
    of '\\':
      if quote == '\'':
        error("Invalid escape sequence: Escapes are not allowed in single quotes.", line_no, col)
      inc col
      if col >= line.len:
        error("Unfinished escape sequence at end of line.", line_no, col - 1)
      word.add(line[col])
    of '"', '\'':
      if quote != NO_QUOTE:
        if quote != c:
          word.add(c)
        else:
          result.add(word)
          word = ""
          quote = NO_QUOTE
      else:
        quote = c
    of ' ', '\t', '{', '}':
      if quote != NO_QUOTE:
        word.add(c)
      elif c in {'{', '}'}:
        var i = col + 1
        eat_space(line, i)
        if i != line.len:
          error("Expected newline after '" & c & "'.", line_no, col)
        if c == '}' and result.len != 0:  # This is an artificial prohibition but enforced by the grammar…
          error("The end of a block marker '}' must be alone on a line.", line_no, col)
        return result
      elif word.len > 0:
        result.add(word)
        word = ""
    else:
      word.add(c)
    inc col

  if word.len > 0:
    result.add(word)
  if quote != NO_QUOTE:
    error("Unclosed string literal.", line_no)


proc read_block(s: Stream, line_no: var int, depth: int, expect_close=false): Block =
  if depth >= 10:
    error("Block nesting depth exceeded.", line_no)

  while not s.at_end():
    var line = s.read_line()
    var col = 0
    inc line_no
    eat_space(line, col)
    if col == line.len or col < line.len and line[col] == '#':
      continue
    let words = split_words(line, line_no, col)
    if col < line.len and line[col] == '}':
      if not expect_close:
        error("Unexpected block closing '}' without opening '{'.", line_no, col)
      return result
    if words.len == 0:
      continue
    let has_block = col < line.len and line[col] == '{'
    result.add(
      Directive(
        name: words[0],
        params: if words.len > 1: words[1..^1] else: @[],
        line: line_no,
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
  ## Reads the scfg from a file provided by the path name and returns a (maybe empty) Block.
  let stream = new_file_stream(path, fm_read)
  if stream == nil:
    raise new_exception(IOError, "Cannot open file: " & path)
  defer: stream.close()
  return read_scfg(stream)


func get*(blck: Block, name: string): Option[Directive] =
  ## Returns the first directive with the provided name
  for directive in blck:
    if directive.name == name:
      return some(directive)
  return none(Directive)


func get_all*(blck: Block, name: string): seq[Directive] =
  ## Returns all directives with the provided name
  return blck.filter_it(it.name == name)


func get*(directive: Directive, name: string): Option[Directive] =
  ## Returns the first directive with the provided name
  return get(directive.children, name)


func get_all*(directive: Directive, name: string): seq[Directive] =
  ## Returns all directives with the provided name
  return get_all(directive.children, name)

