#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
##
## Test against the scfg deserializer.
##
import std/[os, unittest, strutils, sequtils]
import scfg


func canonicalize(s: string): string =
  result = "\""
  for c in s:
    if c in {'"', '\\'}:
      result.add('\\')
    result.add(c)
  result.add('"')


func canonicalize(blck: Block, level=0): string =
  for directive in blck:
    result.add(repeat('\t', level))
    result.add(canonicalize(directive.name))
    for param in directive.params:
      result.add(" " & canonicalize(param))
    if directive.children.len > 0:
      result.add(" {\n")
      result.add(canonicalize(directive.children, level + 1))
      result.add(repeat('\t', level))
      result.add("}\n")
    else:
      result.add("\n")


suite "scfg test suite":

  let tests_dir = current_source_path().parent_dir()

  for kind, path in walk_dir(tests_dir / "valid"):
    if kind != pc_file:
      continue
    let filename = path.split_path.tail
    test "Valid: " & filename:
      let blck = load_scfg(path)
      let expect = read_file(tests_dir / "expected" / filename)
      let output = canonicalize(blck)
      if output != expect:
        check escape(output) == escape(expect)

  for kind, path in walk_dir(tests_dir / "invalid"):
    if kind != pc_file:
      continue
    let filename = path.split_path.tail
    test "Invalid: " & filename:
      expect(ScfgError):
        discard load_scfg(path)


suite "API":

  test "has_block":
    check not read_scfg("key")[0].has_block
    check not read_scfg("key value")[0].has_block
    var s = """
    block {
      key
    }
    """
    check read_scfg(s)[0].has_block
    s = """
    block {

    }
    """
    check read_scfg(s)[0].has_block
    s = """
    key value {

    }
    """
    check read_scfg(s)[0].has_block


suite "examples":

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

  test "First example from README.rst":
    let config = read_scfg(server_config)
    check config.len == 1
    let server = config[0]
    let port = server.children[0]
    check port.to_int == 80
    let server_name = server.children[1]
    check server_name.params == @["example.com", "www.example.com"]
    let locations = server.children.filter_it(it.name == "location")
    check locations.len == 2
    check locations[0].params[0] == "/"
    check locations[0].children[0].to_str == "/var/www/html"
    check locations[1].params[0] == "="
    check locations[1].params[1] == "/robots.txt"


  test "2nd example from README.rst":
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


    func error(msg: string, line: int) =
      raise new_exception(ValueError, msg & ", line: " & $line)


    func error_unknown(directive: Directive) =
      error("Unknown directive " & directive.name, directive.line)


    func to_bool(directive: Directive): bool =
      let val = directive.to_str()
      if val notin ["on", "off"]:
        error("Expected either 'on' or 'off' for " & directive.name & " got: " & val,
              directive.line)
      return val == "on"


    func parse_location(section: Directive): LocationConfig =
      if section.params.len == 0:
        error("Expected a location path", section.line)
      result.exact_match = section.params[0] == "="
      result.path = section.params[^1]
      result.access_log = true
      for child in section.children:
        case child.name:
        of "log_not_found": result.log_not_found = child.to_bool
        of "allow": result.allow = child.to_str
        of "access_log": result.access_log = child.to_bool
        of "root": result.root = child.to_str
        of "index": result.index = child.params
        else: error_unknown(child)


    func parse_server(section: Directive): ServerConfig =
      for child in section.children:
        case child.name:
        of "listen": result.port = child.to_uint()
        of "server_name": result.names = child.params
        of "location": result.locations.add parse_location(child)
        else: error_unknown(child)


    var servers: seq[ServerConfig]

    for directive in read_scfg(server_config):
      case directive.name:
      of "server": servers.add parse_server(directive)
      else: error_unknown(directive)


    check servers.len == 1
    check servers[0].port == 80
    check servers[0].locations.len == 2
    check servers[0].locations[0].access_log
    check not servers[0].locations[1].access_log

