scfg (simple configuration file format) parser
==============================================

A Nim library for `scfg <https://codeberg.org/emersion/scfg>`_


Usage
^^^^^

.. code-block:: nim

    import scfg

    let server_config = """
    server   {
        listen  80   # Listen on port 80
        server_name    example.com   www.example.com

        location / {
            root   /var/www/html  # Document root
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




Similar projects
^^^^^^^^^^^^^^^^
* `nim-scfg <https://codeberg.org/xoich/nim-scfg>`_

