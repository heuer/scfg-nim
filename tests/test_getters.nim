#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2026 -- Lars Heuer
#
## Tests against the directive get_* functions
import std/[unittest]
import scfg


proc directive(s: string): Directive =
  return read_scfg(s)[0]


block:
  let input = """
  key
  """
  let d = directive(input)
  expect(ValueError):
    discard get_str(d)


block:
  let input = """
  key value
  """
  check "value" == get_str(directive(input))


block:
  let input = """
  key value 2
  """
  let d = directive(input)
  expect(ValueError):
    discard get_str(d)


block:
  let input = """
  key ""
  """
  check "" == get_str(directive(input))


block:
  let input = """
  key 1
  """
  check 1 == get_int(directive(input))


block:
  let input = """
  key 10_000
  """
  check 10000 == get_int(directive(input))


block:
  let input = """
  key +1
  """
  check +1 == get_int(directive(input))


block:
  let input = """
  key -1
  """
  check -1 == get_int(directive(input))


block:
  let input = """
  key 120km/h
  """
  let d = directive(input)
  expect(ValueError):
    discard get_int(d)


block:
  let input = """
  key
  """
  let d = directive(input)
  expect(ValueError):
    discard get_int(d)


block:
  let input = """
  key ""
  """
  let d = directive(input)
  expect(ValueError):
    discard get_int(d)


block:
  let input = """
  key 1
  """
  check 1 == get_uint(directive(input))


block:
  let input = """
  key -1
  """
  let d = directive(input)
  expect(ValueError):
    discard get_uint(d)


block:
  let input = """
  key 120km/h
  """
  let d = directive(input)
  expect(ValueError):
    discard get_uint(d)


block:
  let input = """
  key 1
  """
  check 1.0 == get_float(directive(input))


block:
  let input = """
  key +1
  """
  check +1.0 == get_float(directive(input))


block:
  let input = """
  key -1
  """
  check -1.0 == get_float(directive(input))


block:
  let input = """
  key 1.25
  """
  check 1.25 == get_float(directive(input))


block:
  let input = """
  key +1.25
  """
  check +1.25 == get_float(directive(input))


block:
  let input = """
  key -1.25
  """
  check -1.25 == get_float(directive(input))


block:
  let input = """
  key "+1.25"
  """
  check +1.25 == get_float(directive(input))


block:
  let input = """
  key '-1.25'
  """
  check -1.25 == get_float(directive(input))


block:
  let input = """
  key 120km/h
  """
  let d = directive(input)
  expect(ValueError):
    discard get_float(d)


block:
  let input = """
  key
  """
  let d = directive(input)
  expect(ValueError):
    discard get_float(d)


block:
  let input = """
  key ""
  """
  let d = directive(input)
  expect(ValueError):
    discard get_float(d)

