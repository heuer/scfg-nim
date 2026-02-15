#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
##
## This example shows how to change the stream on the fly.
##
## An option to declare variables is implemented but the API caller
## does not see any variables but a usual scfg stream.
##
import std/[streams, tables, sequtils, sets, strutils]
import scfg


type
  VariableKind = enum
    vk_simple
    vk_block


  VariableDefinition = object
    case kind: VariableKind
    of vk_simple:
      params: seq[string]
    of vk_block:
      events: seq[ScfgEvent]
    line: int


const
  EVT_END_DIRECTIVE = ScfgEvent(kind: evt_end, has_block: false)
  EVT_END_BLOCK = ScfgEvent(kind: evt_end, has_block: true)


func error(msg: string, line: int) {.noReturn.} =
  let ex = new_exception(ScfgError, msg & " Line: " & $line)
  ex.line = line
  raise ex


func is_decl(event: ScfgEvent): bool =
  event.params.len > 0 and event.params[0] == "="


func is_decl_dollar(event: ScfgEvent): bool =
  ## Constrains variable decl. further: All identifiers must start with a
  ## dollar ``$`` sign.
  ## Not used, just an example
  event.name[0] == '$' and event.params.len > 0 and event.params[0] == "="


iterator parse_scfg*(stream: Stream, is_variable_decl = is_decl): ScfgEvent =
  var
    variables = initTable[string, VariableDefinition]()
    capturing_var = ""
    captured_events: seq[ScfgEvent] = @[]
    capture_depth = 0
    capturing_start_line = 0
    expansion_stack = initHashSet[string]()

  func is_var(param: string): bool = param in variables

  proc resolve_vars(event: ScfgEvent, expansion_stack: var HashSet[string]): seq[ScfgEvent] =
    if event.kind == evt_end or not event.params.any(is_var):
      return @[event]

    let var_refs = event.params.filter(is_var)

    for var_name in var_refs:
      if var_name in expansion_stack:
        error("Circular reference detected: " & var_name & " references itself", event.line)

    var block_var_count = 0
    var last_is_block = false

    for i, param in event.params:
      if is_var(param) and variables[param].kind == vk_block:
        inc block_var_count
        last_is_block = (i == event.params.len - 1)

    if block_var_count > 1:
      error("Only one block variable is allowed per directive", event.line)
    if block_var_count == 1 and not last_is_block:
      error("Block variable must be the last parameter", event.line)

    if block_var_count == 0:
      var params: seq[string] = @[]
      for param in event.params:
        if is_var(param):
          params.add(variables[param].params)
        else:
          params.add(param)

      result.add ScfgEvent(kind: evt_start, name: event.name, params: params,
                           has_block: event.has_block, line: event.line)
    else:
      var params: seq[string] = @[]
      for i, param in event.params:
        if i == event.params.len - 1:
          break
        elif is_var(param):
          params.add(variables[param].params)
        else:
          params.add(param)

      result.add ScfgEvent(kind: evt_start, name: event.name, params: params,
                           has_block: true, line: event.line)

      let block_var = event.params[^1]
      expansion_stack.incl(block_var)

      for var_event in variables[block_var].events:
        result.add(resolve_vars(var_event, expansion_stack))

      expansion_stack.excl(block_var)

      result.add(EVT_END_BLOCK)

  for event in scfg.parse_scfg(stream):
    if capturing_var != "":
      if event.kind == evt_start and event.has_block:
        inc capture_depth
        captured_events.add(event)
      elif event.kind == evt_end:
        if event.has_block:
          dec capture_depth
          if capture_depth == 0:
            variables[capturing_var] = VariableDefinition(kind: vk_block,
                                                          events: captured_events,
                                                          line: capturing_start_line)
            capturing_var = ""
            captured_events = @[]
          else:
            captured_events.add(event)
        else:
          captured_events.add(event)
      else:
        captured_events.add(event)
      continue

    if event.kind == evt_start and is_variable_decl(event):
      if event.has_block:
        if event.params.len > 1:  # 1st param is "="
          error("Block variables must not have params", event.line)
        capturing_var = event.name
        captured_events = @[]
        capture_depth = 1
        capturing_start_line = event.line
      else:
        let params = if event.params.len > 1: event.params[1..^1] else: @[]
        if params.len == 0:
          error("Variable " & event.name & " has no value after '='", event.line)

        variables[event.name] = VariableDefinition(kind: vk_simple,
                                                   params: params,
                                                   line: event.line)
      continue

    for evt in resolve_vars(event, expansion_stack):
      yield evt


func scfg_name(s: string): string =
  let quote = s.contains({' ', '{', '}'})
  if quote:
    result.add '"'
  result.add s
  if quote:
    result.add '"'


proc process_with_variables(input: Stream, output: Stream) =
  # Writes all directives received by parse_scfg to zhe output stream
  var depth = 0
  for evt in parse_scfg(input):
    case evt.kind:
    of evt_start:
      output.write("  ".repeat(depth))
      output.write(scfg_name(evt.name))
      for param in evt.params:
        output.write(" " & scfg_name(param))
      if evt.has_block:
        output.write(" {")
        inc depth
      output.write_line("")
    of evt_end:
      if evt.has_block:
        dec depth
        output.write("  ".repeat(depth))
        output.write_line("}")
      if depth == 0:
        output.write_line("")


proc main() =
  let
    input = new_file_stream(stdin)
    output = new_file_stream(stdout)
  defer:
    input.close()
    output.close()
  try:
    process_with_variables(input, output)
  except CatchableError as ex:
    stderr.write_line(ex.msg)
    quit(1)


when is_main_module:
  main()

