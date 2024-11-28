[![Actions Status](https://github.com/lizmat/App-Ecosystems/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/App-Ecosystems/actions) [![Actions Status](https://github.com/lizmat/App-Ecosystems/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/App-Ecosystems/actions) [![Actions Status](https://github.com/lizmat/App-Ecosystems/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/App-Ecosystems/actions)

NAME
====

App::Ecosystems - Interactive Ecosystem Inspector

SYNOPSIS
========

    $ ecosystems
    Loading rea ecosystem...
    rea >

DESCRIPTION
===========

App::Ecosystems provides an interactive shell for interrogating and inspecting the Raku module ecosystem. This shell is both provided as an exported `ecosystems` subroutine, as well as a command-line script called `ecosystems`.

COMMANDS
========

These are the available commands in alphabetical order. Note that if `Linenoise` or `Terminal::LineEditor` is used as the underlying interface, tab completion will be available for all of these commands.

Also note that each command may be shortened to a unique root: so just entering "a" would be ambiguous, but "ap" would give you the "api" functionality.

api
---

authority
---------

catch
-----

dependencies
------------

distro
------

ecosystem
---------

editor
------

exit
----

from
----

help
----

identity
--------

meta
----

quit
----

reverse-dependencies
--------------------

river
-----

unresolvable
------------

unversioned
-----------

use-target
----------

verbose
-------

version
-------

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/App-Ecosystems . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

