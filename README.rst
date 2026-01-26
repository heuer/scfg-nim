scfg (simple configuration file format) parser
==============================================

A Nim library for `scfg <https://codeberg.org/emersion/scfg>`_


Usage
^^^^^

.. code-block:: nim

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
    let server = config.get("server").get
    let port = server.get("listen").get
    assert port.params[0] == "80"
    let server_name = server.get("server_name").get
    assert server_name.params == @["example.com", "www.example.com"]
    let locations = server.get_all("location")
    assert locations.len == 2
    assert locations[0].params[0] == "/"
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
        port: int
        names: seq[string]
        locations: seq[LocationConfig]


    func error(msg: string, directive: Directive) =
      raise new_exception(ValueError, msg & ", line: " & $directive.line)


    func error_unknown(directive: Directive) =
      error("Unknown directive " & directive.name, directive)


    func parse_bool(directive: Directive): bool =
      if directive.params.len != 1 or directive.params[0] notin ["on", "off"]:
        error("Expected either 'on' or 'off' for " & directive.name, directive)
      return directive.params[0] == "on"


    func parse_location(section: Directive): LocationConfig =
      result.exact_match = false
      if section.params.len == 0:
        error("Expected a location path", section)
      if section.params.len > 1:
        result.exact_match = section.params[0] == "="
      result.path = section.params[^1]
      result.access_log = true
      for child in section.children:
        if child.name != "index" and child.params.len != 1:
          error("Expected exactly one value for " & child.name, child)
        case child.name:
        of "log_not_found": result.log_not_found = parse_bool(child)
        of "allow": result.allow = child.params[0]
        of "access_log": result.access_log = parse_bool(child)
        of "root": result.root = child.params[0]
        of "index": result.index = child.params
        else: error_unknown(child)


    func parse_server(section: Directive): ServerConfig =
      for child in section.children:
        case child.name:
        of "listen":
          if child.params.len != 1:
            error("Expected exactly one value for " & child.name, child)
          result.port = parse_int(child.params[0])
        of "server_name": result.names = child.params
        of "location": result.locations.add parse_location(child)
        else: error_unknown(child)

    var servers: seq[ServerConfig]

    for directive in read_scfg(server_config):
      if directive.name == "server":
        servers.add parse_server(directive)
      else:
        error_unknown(directive)


    assert servers.len == 1
    assert servers[0].port == 80
    assert servers[0].locations.len == 2
    assert servers[0].locations[0].access_log
    assert not servers[0].locations[1].access_log



Similar projects
^^^^^^^^^^^^^^^^
* `nim-scfg <https://codeberg.org/xoich/nim-scfg>`_

