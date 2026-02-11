#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
##
## Test against the streaming API.
##
import std/[os, unittest, strutils, streams]
import scfg


func canonicalize(s: string): string =
  result = "\""
  for c in s:
    if c in {'"', '\\'}:
      result.add('\\')
    result.add(c)
  result.add('"')


suite "scfg test suite (streaming API)":
  let tests_dir = current_source_path().parent_dir()
  for kind, path in walk_dir(tests_dir / "valid"):
    if kind != pc_file:
      continue
    let filename = path.split_path.tail
    test "Valid: " & filename:
      let stream = new_file_stream(path, fm_read)
      defer: stream.close()
      var
        output: string
        level = 0
        pending_newline = false
        has_block_stack: seq[bool] = @[]
      for event in parse_scfg(stream):
        case event.kind:
        of evt_start:
          output.add repeat('\t', level)
          output.add canonicalize(event.name)
          for param in event.params:
            output.add " " & canonicalize(param)
          has_block_stack.add(event.has_block)
          if event.has_block:
            output.add " {\n"
            inc level
          else:
            output.add '\n'
        of evt_end:
          let had_block = has_block_stack.pop()
          if had_block:
            dec level
            if not output.ends_with(" {\n"):   # No empty blocks in canoncial output
              output.add repeat('\t', level)
              output.add "}\n"
            else:
              output = output[0..^4]  # Revert opening block
              output.add '\n'
      let expect = read_file(tests_dir / "expected" / filename)
      if output != expect:
        check escape(output) == escape(expect)

  for kind, path in walk_dir(tests_dir / "invalid"):
    if kind != pc_file:
      continue
    let filename = path.split_path.tail
    test "Invalid: " & filename:
     let stream = new_file_stream(path, fm_read)
     defer: stream.close()
     expect(ScfgError):
        for evt in parse_scfg(stream):
          discard


suite "README":
  test "Streaming":
    type
      LocationConfig = object
        path: string
        exact_match: bool
        root: string
        index: seq[string]
        allow: string
        log_not_found: bool
        access_log: bool

      ServerConfig = object
        port: uint
        names: seq[string]
        locations: seq[LocationConfig]

    func error(msg: string) = raise new_exception(ValueError, msg)


    func to_str(evt: ScfgEvent): string =
      if evt.params.len != 1:
        error("Expected exatly one value for " & evt.name & " got: " & $evt.params)
      evt.params[0]


    func to_bool(evt: ScfgEvent): bool =
      let val = to_str(evt)
      if val notin ["on", "off"]:
        error("Expected either 'on' or 'off' for " & evt.name & " got: " & val)
      val == "on"


    func to_uint(evt: ScfgEvent): uint = parse_uint(to_str(evt))


    let server_config = """
    server   {
        listen  80
        server_name    example.com   www.example.com

        location / {
            root   /var/www/html
            index  index.html index.htm
        }

        location = /robots.txt {
            allow all
            log_not_found off
            access_log off
        }
    }
    """

    let stream = new_string_stream(server_config)
    var
      servers: seq[ServerConfig]
      depth = 0
      in_server = false
      in_location = false

    for event in parse_scfg(stream):
      case event.kind:
      of evt_start:
        inc depth
        if not in_server and event.name == "server":
          in_server = true
          servers.add ServerConfig()
          continue
        if in_server and not in_location:
          case event.name:
          of "location":
            in_location = true
            servers[^1].locations.add LocationConfig(
              access_log: true,
              exact_match: event.params[0] == "=",
              path: event.params[^1]
            )
          of "listen": servers[^1].port = event.to_uint()
          of "server_name": servers[^1].names = event.params
          else: error("Unknown directive: " & event.name)
        elif in_location:
          case event.name:
          of "root": servers[^1].locations[^1].root = event.to_str()
          of "index": servers[^1].locations[^1].index = event.params
          of "allow": servers[^1].locations[^1].allow = event.to_str()
          of "log_not_found": servers[^1].locations[^1].log_not_found = event.to_bool()
          of "access_log": servers[^1].locations[^1].access_log = event.to_bool()
          else: error("Unknown directive: " & event.name)
      of evt_end:
        dec depth
        if in_location and depth == 1:
          in_location = false
        elif in_server and depth == 0:
          in_server = false

    check servers.len == 1
    check servers[0].port == 80
    check servers[0].locations.len == 2
    check servers[0].locations[0].access_log
    check not servers[0].locations[1].access_log

