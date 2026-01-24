#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
##
## Test against the scfg deserializer.
##
import std/[os, unittest, strutils, options]
import scfg


func canonicalize(s: string): string =
  result = "\""
  for c in s:
    if c in {'"', '\t', '\r', '\n'}:
      result.add('\\')
      if c == '"': result.add('"')
      elif c == '\n': result.add('n')
      elif c == '\r': result.add('r')
      elif c == '\t': result.add('t')
    else:
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


const example = """
train "Shinkansen" {
	model "E5" {
   	max-speed 320km/h
    weight 453.5t

    lines-served "Tōhoku" "Hokkaido"
	}

  model "E7" {
    max-speed 275km/h
    weight 540t

    lines-served "Hokuriku" "Jōetsu"
  }
}
"""


suite "scfg test suite":

  let tests_dir = current_source_path().parent_dir() / "scfg"

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


suite "API tests":

  test "get":
    let blck = read_scfg(example)
    check blck.len == 1
    var res = blck.get("train")
    check res.is_some
    let train = res.get
    check train.name == "train"
    check train.params == @["Shinkansen"]
    check train.children.len == 2
    res = train.get("model")
    check res.is_some
    let model = res.get
    check model.name == "model"
    check model.params == @["E5"]

  test "get: no result":
    let blck = read_scfg(example)
    check blck.len == 1
    check blck.get("truck").is_none
    let train = blck.get("train").get
    check train.get("type").is_none

  test "get-all":
    let blck = read_scfg(example)
    check blck.len == 1
    let res = blck.get("train")
    check res.is_some
    let train = res.get
    let models = train.get_all("model")
    check models.len == 2
    check models[0].name == "model"
    check models[0].params[0] == "E5"
    check models[1].name == "model"
    check models[1].params[0] == "E7"

  test "get-all: empty result":
    let blck = read_scfg(example)
    check blck.len == 1
    check blck.get_all("truck").len == 0
    let trains = blck.get_all("train")
    check trains.len == 1
    let train = trains[0]
    check train.get_all("type").len == 0

  test "line field":
    let blck = read_scfg(example)
    let train = blck.get("train").get
    check train.line == 1
    let models = train.get_all("model")
    check models.len == 2
    check models[0].line == 2
    check models[1].line == 9


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

  test "Example from README.rst":
    let config = read_scfg(server_config)
    check config.len == 1
    let server = config.get("server").get
    let port = server.get("listen").get
    check port.params.len == 1
    check port.params[0] == "80"
    let server_name = server.get("server_name").get
    check server_name.params == @["example.com", "www.example.com"]
    let locations = server.get_all("location")
    check locations.len == 2
    check locations[0].params[0] == "/"
    check locations[0].get("root").get().params.len == 1
    check locations[1].params[0] == "="
    check locations[1].params[1] == "/robots.txt"

