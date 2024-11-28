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

App::Ecosystems provides an interactive shell for interrogating and inspecting the Raku module ecosystem, providing an interactive interface to the API provided by the [`Ecosystem`](https://raku.land/zef:lizmat/Ecosystem) module.

This shell is both provided as an exported `ecosystems` subroutine, as well as a command-line script called `ecosystems`.

COMMANDS
========

These are the available commands in alphabetical order. Note that if `Linenoise` or `Terminal::LineEditor` is used as the underlying interface, tab completion will be available for all of these commands.

Also note that each command may be shortened to a unique root: so just entering "a" would be ambiguous, but "ap" would give you the "api" functionality.

api
---

    rea > api
    Default api is: 'Any'

    rea > api 1
    Default api set to '1'

Show or set the default "api" value to be used in ecosystem searches.

authority
---------

    rea > auth
    Default authority is: 'Any'

    rea > auth zef:raku-community-modules
    Default authority set to 'zef:raku-community-modules'

Show or set the default "auth" value to be used in ecosystem searches.

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

    rea > from
    Default from is: 'Any'

    rea > from NQP
    Default from set to 'NQP'

Show or set the default "from" value to be used in ecosystem searches.

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

    rea > version
    Default version is: 'Any'

    rea > version 0.0.3+
    Default version set to '0.0.3+'

Show or set the default "ver" value to be used in ecosystem searches.

SEE ALSO
--------

This module is basically a replacement of the [`CLI::Ecosystem`](https://raku.land/zef:lizmat/CLI::Ecosystem) module, which suffers from noticeable startup delay because of ecosystem information loading on **each** invocation.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/App-Ecosystems . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

