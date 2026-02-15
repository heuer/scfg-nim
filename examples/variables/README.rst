An example how to collect events and replay them.

This example interprets some scfg directives as variable declarations and
resolves them transparently for the API caller.

Variables can be declared as follows::

    $x = "simple variable"

    $y = 1 2 3

    # Variable $z represents a scfg block
    $z = {
        background-color #000
        foreground-color #fff
    }


Although the example uses a ``$`` as prefix for identifiers, the implementation
is actually more lenient and any valid directive name could be used as
identifier::

    x = "D

    *y = 1 2 3

    'a b' = {
        background-color #000
        foreground-color #fff
    }


After a variable has been defined it can be used by other directives::

    $ringo = "Ringo Starr"

    the-beatles "Paul McCartney" "John Lennon" "George Harrison" $ringo

    plays-drums $ringo


If a variable represents a block, it must appear at the end of a directive
declaration::

    $border = {
        width 10
        color #000
    }

    bar {
        border $border
    }


Try out the examples using the ``scfg_vars`` program in the ``src``
directory which takes any scfg document with variables and writes the
output to ``stdout``.

