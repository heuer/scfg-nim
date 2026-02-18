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


const
  NO_QUOTE = '\0'
  EVT_END_DIRECTIVE = ScfgEvent(kind: evt_end, has_block: false)
  EVT_END_BLOCK = ScfgEvent(kind: evt_end, has_block: true)


func error(msg: string, line: int) {.noReturn.} =
  let ex = new_exception(ScfgError, "Error line " & $line & ": " & msg)
  ex.line = line
  raise ex


func eat_space(s: string, i: var int) =
  while i < s.len and s[i] in {' ', '\t'}:
    inc i


func split_words(line: string, line_no: int, col: var int): seq[string] =
  var
    word = ""
    quote = NO_QUOTE
  result = new_seq_of_cap[string](4)
  while col < line.len:
    let c = line[col]
    if c == '\\':
      if quote == '\'':
        word.add(c)
        inc col
        continue
      inc col
      if col >= line.len:
        error("Unfinished escape sequence", line_no)
      word.add(line[col])
    elif quote == NO_QUOTE:
      if c in {'{', '}'}:
        var i = col + 1
        eat_space(line, i)
        if i < line.len:
          error("Expected newline after '" & c, line_no)
        if c == '}' and result.len != 0:  # This is an artificial prohibition but enforced by the grammar…
          error("The end of a block marker '}' must be on its own line", line_no)
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
    error("Unclosed string literal", line_no)


iterator parse_scfg*(stream: Stream): ScfgEvent =
  ## Parses the scfg from the provided stream and issues events.
  var
    line_no = 0
    open_blocks = 0
    line: string
    col: int
  while stream.read_line(line):
    col = 0
    inc line_no
    eat_space(line, col)
    if col >= line.len or line[col] == '#':
      continue
    let words = split_words(line, line_no, col)
    if col < line.len and line[col] == '}':
      if open_blocks == 0:
        error("Unexpected block closing '}' without opening '{'", line_no)
      dec open_blocks
      yield EVT_END_BLOCK
      continue
    if words.len == 0:
      continue
    let has_block = col < line.len and line[col] == '{'
    yield ScfgEvent(kind: evt_start, name: words[0], params: words[1..^1],
                    has_block: has_block, line: line_no)
    if has_block:
      inc open_blocks
    else:
      yield EVT_END_DIRECTIVE
  if open_blocks > 0:
    error("Unclosed block: Expected '}'", line_no)

