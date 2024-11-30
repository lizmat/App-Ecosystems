[![Actions Status](https://github.com/lizmat/App-Ecosystems/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/App-Ecosystems/actions) [![Actions Status](https://github.com/lizmat/App-Ecosystems/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/App-Ecosystems/actions) [![Actions Status](https://github.com/lizmat/App-Ecosystems/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/App-Ecosystems/actions)

NAME
====

App::Ecosystems - Interactive Ecosystem Inspector

SYNOPSIS
========

    $ ecosystems
    Ecosystem: Raku Ecosystem Archive ('rea' 12030 identities)
      Updated: 2024-11-30T11:52:48
       Period: 2011-05-10 - 2024-11-30

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

    rea > catch
    Exception catching is: ON

    rea > catch off
    Exception catching set to OFF

Show whether exceptions will be caught or not, or change that setting.

By default any exceptions during execution will be caught and only a one-line message of the error will be shown. By default it is **ON**. Switching it to **OFF** will cause an exception to show a complete backtrace and exit the program, which may be desirable during debugging and/or error reporting.

dependencies
------------

    rea > dependencies Map::Match
    Dependencies of Map::Match:ver<0.0.5>:auth<zef:lizmat>
    Add 'verbose' for recursive depencies
    --------------------------------------------------------------------------------
    Hash::Agnostic:ver<0.0.16>:auth<zef:lizmat>
    Map::Agnostic:ver<0.0.10>:auth<zef:lizmat>

Show the dependencies of a given distribution name. If the distribution name is not fully qualified with `auth`, `ver` and `api`, then the most recent version will be assumed.

    rea > dependencies Map::Match :ver<0.0.1>
    Dependencies of Map::Match:ver<0.0.1>:auth<zef:lizmat>
    Add 'verbose' for recursive depencies
    --------------------------------------------------------------------------------
    Hash::Agnostic:ver<0.0.10>:auth<zef:lizmat>
    Map::Agnostic:ver<0.0.6>:auth<zef:lizmat>

You can also specify a version if you'd like to see the dependency information of that version of the distribution.

distros
-------

    rea > distros Agnostic
    Distributions that match 'Agnostic'
    Add 'verbose' to also see their frequency
    --------------------------------------------------------------------------------
    Array::Agnostic
    Hash::Agnostic
    List::Agnostic
    Map::Agnostic

Show the names of the distributions with the given search term. For now any distribution name that contains the given string, will be included.

The search term may be expressed as a regular expression.

ecosystem
---------

    rea > ecosystem
    Using the rea ecosystem

    rea > ecosystem fez
    Loading fez ecosystem...
    fez >

Show or set the ecosystem to be used in ecosystem searches. Note that the currently used ecosystem is also shown in the prompt.

editor
------

    rea > editor
    LineEditor

Show the name of the underlying editor that is being used. Note that only `Linenoise` and `LineEditor` allow tab-completions.

exit
----

    rea > exit
    $

Exit and save any history.

from
----

    rea > from
    Default from is: 'Any'

    rea > from NQP
    Default from set to 'NQP'

Show or set the default "from" value to be used in ecosystem searches.

help
----

    rea > help
    Available commands:
    --------------------------------------------------------------------------------
    api authority catch dependencies distros ecosystem editor exit from help
    identities meta quit reverse-dependencies river unresolvable unversioned
    use-targets verbose version

Show available commands if used without additional argument. If a command is specified as an additional argument, show any in-depth information about that command.

identities
----------

    rea > identities SSH::LibSSH
    Most recent version of identities that match 'SSH::LibSSH'
    Add 'verbose' to see all identities
    --------------------------------------------------------------------------------
    SSH::LibSSH:ver<0.9.2>:auth<zef:raku-community-modules>
    SSH::LibSSH::Tunnel:ver<0.0.9>:auth<zef:massa>

Show the most recent versions of the identities that match the given search term, either as distribution name or `use` target.

The search term may be expressed as a regular expression.

meta
----

    rea > meta actions
    Meta information of actions:ver<0.0.2>:auth<zef:lizmat>
    Resolved from: actions
    --------------------------------------------------------------------------------
    {
      "auth": "zef:lizmat",
      "authors": [
        "Elizabeth Mattijsen"
      ],
      "description": "Introduce \"actions\" keyword",
      "dist": "actions:ver<0.0.2>:auth<zef:lizmat>",
      "license": "Artistic-2.0",
      "name": "actions",
      "perl": "6.d",
      "provides": {
        "actions": "lib/actions.rakumod"
      },
      "release-date": "2024-09-23",
      "source-url": "https://raw.githubusercontent.com/raku/REA/main/archive/A/actions/actions%3Aver%3C0.0.2%3E%3Aauth%3Czef%3Alizmat%3E.tar.gz",
      "tags": [
        "GRAMMAR",
        "ACTIONS"
      ],
      "version": "0.0.2"
    }

Show the meta information of the given distribution name as it was found in the currently active ecosystem. Note that this may be subtly different from the contents of the META6.json file becomes an ecosystem may have added fields and/or have updated fields for that particular ecosystem (such as "source-url").

quit
----

    rea > quit
    $

Exit and save any history.

reverse-dependencies
--------------------

    rea > reverse-dependencies Ecosystem
    Reverse dependencies of Ecosystem
    --------------------------------------------------------------------------------
    App::Ecosystems
    CLI::Ecosystem

Show the distribution names that have a dependency on the given identity.

river
-----

    rea > river
    Top 3 distributions and number of dependees
    Add 'verbose' to also see the actual dependees
    JSON::Fast (398)
    File::Directory::Tree (249)
    MIME::Base64 (233)

Show the N distributions (defaults to **3**) that have the most reverse dependencies (aka: are most "up-stream").

unresolvable
------------

Current semantics are less than useful. Please ignore until fixed.

unversioned
-----------

    rea > unversioned
    Found 105 distributions that did not have a release with a valid version
    Add 'verbose' to list the distribution names

Show how many distributions there are in the ecosystem without valid version information (and which did **not** have a later release with a valid version value). Optionally also list the identities of these distributions.

use-targets
-----------

    rea > use-targets Crane::A
    Use targets that match Crane::A
    Add 'verbose' to also see their distribution
    --------------------------------------------------------------------------------
    Crane::Add
    Crane::At

Show the names of the `use` targets with the given search term (aka search all keys that are specified in `provides` sections of distributions in the ecosystem).

The search term may be expressed as a regular expression.

verbose
-------

    rea > verbose
    Verbosity is: OFF

    rea > verbose on
    Verbosity set to ON

Show or set the default verbosity level to be used in showing the result of ecosystem searches. The default is **OFF**.

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

