Example how to convert the scfg events into a data structure.

.. code-block:: nim

    import std/sequtils
    import scfgdir

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

