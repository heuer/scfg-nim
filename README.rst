scfg (simple configuration file format) parser
==============================================

A Nim library for `scfg <https://codeberg.org/emersion/scfg>`_


Usage
^^^^^

.. code-block:: nim

    import std/sequtils
    import scfg

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
    let config = read_scfg(server_config)
    assert config.len == 1
    let server = config[0]
    let port = server.children[0]
    assert port.to_int == 80
    let server_name = server.children[1]
    assert server_name.params == @["example.com", "www.example.com"]
    let locations = server.children.filter_it(it.name == "location")
    assert locations.len == 2
    assert locations[0].params[0] == "/"
    assert locations[0].children[0].to_str == "/var/www/html"
    assert locations[1].params[0] == "="
    assert locations[1].params[1] == "/robots.txt"


Convert the config on the fly into objects:

.. code-block:: nim

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

    assert servers.len == 1
    assert servers[0].port == 80
    assert servers[0].locations.len == 2
    assert servers[0].locations[0].access_log
    assert not servers[0].locations[1].access_log



Same result but using the event API which avoids to read the whole config at
once and allows a more direct creation of the config structure without
re-iterating through the tree.

.. code-block:: nim


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

    assert servers.len == 1
    assert servers[0].port == 80
    assert servers[0].locations.len == 2
    assert servers[0].locations[0].access_log
    assert not servers[0].locations[1].access_log


Similar projects
^^^^^^^^^^^^^^^^
* `nim-scfg <https://codeberg.org/xoich/nim-scfg>`_

