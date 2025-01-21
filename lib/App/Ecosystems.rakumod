#- prologue --------------------------------------------------------------------

use Commands:ver<0.0.6+>:auth<zef:lizmat>;
use Ecosystem:ver<0.0.28+>:auth<zef:lizmat>;
use Identity::Utils:ver<0.0.17+>:auth<zef:lizmat> <build from short-name>;
use Prompt:ver<0.0.9+>:auth<zef:lizmat>;
use String::Utils:ver<0.0.32+>:auth<zef:lizmat> <word-at>;

# The named parts of an identity
my constant @identity-parts    = <ver auth api from>;
my constant any-identity-parts = @identity-parts.any;

#- helper subs -----------------------------------------------------------------
# These all assume $app is set to the active App:Ecosystem object
# and $eco is set to the active Ecosystem object, and $commands
# to the active Commands object

# Defined here to allow for early visibility
my $app;
my $eco;
my $commands;
my $helper;

# Set / Get ecosystem string attribute value
my sub setter-getter($_, $short, $long = $short) {
    with .[1] -> $new is copy {
        $new = Nil if $new eq 'Any';
        $app."$short"() = $new;
        say "Default $long set to '{$new // 'Any'}'";
    }
    else {
        say "Default $long is: '{$app."$short"() // 'Any'}'";
    }
}

# Set / Get ecosystem bool attribute value
my sub setter-getter-bool($_, $short, $long = $short, :$object = $app) {
    with .[1] -> $new is copy {
        if $new.uc eq 'ON' | 'OFF' {
            $new .= uc;
            $object."$short"() = $new eq 'ON';
            say "$long.tclc() set to $new";
        }
        else {
            say "Unexpected value '$new' for '$long': $new";
        }
    }
    else {
        my $state := $object."$short"() ?? "ON" !! "OFF";
        say "$long.tclc() is: $state";
    }
}

# Convert all words given by user (except first) to a Capture
my sub args-to-capture(@words) {
    my @list;
    my %hash;

    my $verbose = $app.verbose;
    my role verbose { has $.verbose is built(:bind) }

    sub add-key($word, $key, $value) {
        $key eq any-identity-parts
          ?? (%hash{$key} := $value)
          !! @list.push($word)
    }

    for @words.skip.map({
        my @parts = .split(/ ':' <before \w+ '<'>/);
        @parts.shift unless @parts.head;
        @parts.Slip
    }) -> $word {
        if $word eq 'verbose' {
            $verbose = True;
        }
        orwith $word.index("=",1) -> $index {
            add-key($word, $word.substr(0,$index), $word.substr($index + 1));
        }
        elsif $word.ends-with('>') {
            with $word.index('<') {
                add-key($word, $word.substr(0,$_), $word.substr($_ + 1).chop);
            }
            else {
                @list.push: $word;
            }
        }
        else {
            @list.push: $word;
        }
    }

    for @identity-parts {
        if %hash{$_}:!exists && $app."$_"() -> $default {
            %hash{$_} := $default;
        }
    }

    Capture.new(:@list, :%hash) but verbose($verbose)
}

# Change the first positional of the capture into a regex if it
# looks like a regex
sub targetize1st(Capture:D $capture) {
    if $capture.list -> @positionals {
        my $target := target @positionals.head;
        @positionals[0] = $target if $target ~~ Regex;
    }
}

# Check string for special characters and change it into a regex if
# any found, otherwise return unchanged
sub target(Str:D $string) {
    my $target = $string.subst(/ '§' (\w+) /, { "<<$0>>" });

    $target.contains(('.','^','$','\\','<<','>>','?','+','*').any)
      ?? "/:i $target.subst('::','\\:\\:',:g) /".EVAL
      !! $string
}

# Just a visual divider
sub line() { say "-" x 80 }

# Return recent identities from full list of identies
sub recent-identities($identities) {
    my %seen;
    $identities<>.map: {
        $_ unless %seen{short-name $_}++;
    }
}

# Complete shortened primary commands
sub additional-completions($line, $pos) {

    my ($start, $chars, $index) = word-at($line, $pos);
    if $start.defined {
        my $before := $line.substr(0,$start);
        my $target := $line.substr($start, $chars).lc;
        my $after  := $line.substr($start + $chars);
        $after := " " unless $after;

        # primary command
        if $index == 0 {
            $commands.primaries.map({
                $before ~ $_ ~ $after if .starts-with($target)
            }).List
        }

        # secondary command
        elsif $index == 1 {

            # Looks like tab completion of "verbose" somewhere
            if "verbose".starts-with($target) {
                ($before ~ "verbose" ~ $after,)
            }

            else {
                my @words    = $line.words;
                my $action  := $commands.resolve-command(@words.head);
                my $capture := args-to-capture(@words);
                sub grepper($_) { $_ if .contains($target, :i, :m) }

                my @targets;
                if $action eq 'auths' | 'authors' | 'tags' | 'use-targets' {
                    @targets = $eco."$action"().keys.map(&grepper)
                }
                elsif $action eq 'distros' {
                    @targets = $eco.distro-names.keys.map(&grepper)
                }
                elsif $action eq 'identities' {
                    my %seen;
                    @targets = $eco.identities.keys.map: {
                        if .contains($target, :i, :m) {
                            my $short-name := short-name($_);
                            $_ unless %seen{$short-name}++
                        }
                    }
                }
                elsif $action eq 'help' {
                    @targets = $helper.primaries.map(&grepper)
                }

                @targets.map({ $before ~ $_ ~ $after }).sort(*.fc).List
            }
        }

        # Looks like tab completion of "verbose" somewhere else
        elsif "verbose".starts-with($target) {
            ($before ~ "verbose" ~ $after,)
        }
    }
}

#- handlers --------------------------------------------------------------------

my sub catch($_) {
    setter-getter-bool $_, 'catch', 'exception catching', :object($commands)
}

my sub authors($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;

    if $capture.head -> $needle {
        if $eco.authors(target($needle), :p).sort(*.key.fc) -> @authors {
            say "Authors matching '$needle'";
            line;

            for @authors {
                my $author    := .key;
                my @identities = recent-identities(.value);
                if $verbose {
                    my $ids := @identities == 1 ?? "identity" !! "identities";
                    say "@identities.elems() recent $ids (co-)authored by '$author':";
                    line;
                    .say for @identities;
                }
                else {
                    my $identities := @identities == 1
                      ?? ""
                      !! " (" ~ @identities.elems ~ "x)";
                    say "$author$identities";
                }
            }
        }
        else {
            say "No authors found matching '$needle'";
        }
    }
    else {
        my @authors = $eco.authors.keys;
        if $verbose {
            say "@authors.elems() unique authors:";
            line;
            say $_ || '<none>' for @authors.sort(*.fc);
        }
        else {
            say "Found @authors.elems() unique author names";
        }
    }
}

my sub auths($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;

    if $capture.head -> $needle {
        if $eco.auths(target($needle), :p).sort(*.key.fc) -> @auths {
            say "Auths matching '$needle'";
            line;

            for @auths {
                my $auth      := .key;
                my @identities = recent-identities(.value);
                if $verbose {
                    my $ids := @identities == 1 ?? "identity" !! "identities";
                    say "@identities.elems() recent $ids with auth '$auth':";
                    line;
                    .say for @identities;
                }
                else {
                    my $identities := @identities == 1
                      ?? ""
                      !! " (" ~ @identities.elems ~ "x)";
                    say "$auth$identities";
                }
            }
        }
        else {
            say "No 'auth' found matching '$needle'";
        }
    }
    else {
        my @auths = $eco.auths.keys;
        if $verbose {
            say "@auths.elems() unique 'auth' values:";
            line;
            say $_ || '<none>' for @auths.sort(*.fc);
        }
        else {
            say "Found @auths.elems() unique 'auth' values";
        }
    }
}

my sub default-api($_)  { setter-getter $_, 'api'               }
my sub default-auth($_) { setter-getter $_, 'auth', 'authority' }
my sub default-from($_) { setter-getter $_, 'from'              }
my sub default-ver($_)  { setter-getter $_, 'ver', 'version'    }

my sub dependencies($_) {
    my $capture := args-to-capture($_);

    if $eco.resolve(|$capture) -> $identity {
        my $verbose := $capture.verbose;

        if $eco.dependencies($identity, :recurse($verbose)) -> @identities {
            say $verbose
              ?? "Recursive dependencies of $identity"
              !! "Dependencies of $identity
Add 'verbose' for recursive depencies";
            line;
            .say for @identities;
        }
        else {
            say "No dependencies found for '$identity'";
        }
    }
    else {
        my $needle := build(|$capture);
        say "Could not resolve '$needle'";
    }
}

my sub distros($_) {
    my $capture := args-to-capture($_);
    my $needle  := $capture.head ?? build(|$capture) !! "";
    my $verbose := $capture.verbose;

    targetize1st($capture);
    if $eco.find-distro-names(|$capture).sort(*.fc) -> @names {
        my $target := $needle ?? " that match '$needle'" !! "";

        say $verbose
          ?? "Distributions$target and number of identities"
          !! "Distributions$target
Add 'verbose' to also see the number of identities";
        line;
        if $verbose {
            my %identities := $eco.distro-names;
            for @names -> $name {
                my $versions := %identities{$name}.elems;
                say $versions == 1
                  ?? $name
                  !! "$name ({$versions}x)";
            }
        }
        else {
            .say for @names;
        }
    }
    else {
        say "No distributions found for: $needle";
    }
}


my sub editor($_) { say $app.prompt.editor-name }

sub help($_) {
    if .skip.join(" ") -> $deeper {
        $helper.process($deeper)
    }
    else {
        say "Available commands:";
        line;
        say $commands.primaries().join(" ").naive-word-wrapper;
        say "\nMore in-depth help available with 'help <command>'";
    }
}

my sub identities($_) {
    my $capture := args-to-capture($_);
    my $needle  := $capture.head ?? build(|$capture) !! "";
    my $verbose := $capture.verbose;

    targetize1st($capture);
    if $eco.find-identities(|$capture, :all($verbose)) -> @ids {
        my $target := $needle ?? " that match '$needle'" !! "";
        say $verbose
          ?? "All identities$target"
          !! "Most recent version of identities$target
Add 'verbose' to see all identities";
        line;
        .say for @ids;
    }
    else {
        say "No identities found matching: $needle";
    }
}

my sub meta($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;

    # Extract any additional positionals
    my @list        = $capture.list;
    my @additional := @list.splice(1);
    $capture       := Capture.new(:@list, :hash($capture.hash));

    my $needle := build(|$capture);
    if $eco.resolve(|$capture) -> $identity {
        if $eco.identities{$identity} -> $found {
            say "Meta information of $identity @additional[]";
            say "Resolved from: $needle" if $needle ne $identity;
            line;

            my $data := $found.clone;
            while @additional
              && $data ~~ Associative
              && $data{@additional.shift} -> $deeper {
                $data := $deeper;
            }

            # Only show fields with meaning unless verbose
            if $data ~~ Associative && !$verbose {
                my %data = $data.grep(*.value);
                $data   := %data;
            }
            say $eco.to-json: $data;
        }
        else {
            say "No meta information for '$identity' found";
        }
    }
    else {
        say "'$needle' did not resolve to a known identity";
    }
}

my sub no-tags($_) {
    my $capture := args-to-capture($_);
    my $needle  := $capture.list ?? build(|$capture) !! "";
    my $verbose := $capture.verbose;

    targetize1st($capture);
    if $eco.find-no-tags(|$capture, :all($verbose)) -> @ids {
        say $verbose
          ?? "All identities without any tags that match '$needle'"
          !! "Most recent version of identities without tags that match
'$needle'.  Add 'verbose' to see all identities";
        line;
        .say for @ids;
    }
    else {
        say "No identities without tags found matching: $needle";
    }
}

my sub release-dates($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;

    if $eco.ecosystem ne 'rea' {
        say "Release dates are only provided by the Raku Ecosystem Archive.";
    }
    elsif $capture.head -> $needle {
        if $eco.release-dates(target($needle), :p).sort(*.key.fc) -> @dates {
            my $releases = @dates.map(*.value.elems).sum;
            say "Found @dates.elems() dates matching '$needle' with $releases releases";

            if $verbose {
                line;
                for @dates {
                    my $date      := .key;
                    my @identities = recent-identities(.value);
                    if $verbose {
                        my $ids := @identities == 1 ?? "identity" !! "identities";
                        say "\n@identities.elems() recent $ids on $date:";
                        line;
                        .say for @identities;
                    }
                    else {
                        my $identities := @identities == 1
                          ?? ""
                          !! " (" ~ @identities.elems ~ "x)";
                        say "$date$identities";
                    }
                }
            }
        }
        else {
            say "No dates found matching '$needle'";
        }
    }
    else {
        my @dates = $eco.release-dates.keys;
        if $verbose {
            say "@dates.elems() unique release-dates:";
            line;
            .say for @dates.sort(*.fc);
        }
        else {
            say "Found @dates.elems() unique release-dates";
        }
    }
}

my sub reverse-dependencies($_) {
    my $capture := args-to-capture($_);
    my $needle := build(|$capture);

    with $eco.resolve(|$capture) // $needle -> $identity {
        if $capture.verbose {
            if $eco.reverse-dependencies{$identity} -> @identities {
                say "Reverse dependency identities of $identity";
                say "Resolved from: $needle" if $needle ne $identity;
                line;
                .say for Ecosystem.sort-identities: @identities;
            }
            else {
                say "'$identity' does not have any reverse dependencies";
            }
        }
        else {
            my $short-name := short-name($identity);
            if $eco.reverse-dependencies-for-short-name($short-name) -> @sn {
                say "Reverse dependencies of $short-name
Add 'verbose' to see reverse dependency identities";
                line;
                .say for @sn.sort(*.fc)
            }
            else {
                say "'$short-name' does not have any reverse dependencies";
            }
        }
    }
    else {
        say "'$needle' did not resolve to a known identity";
    }
}

my sub river($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;
    my $top     := $verbose ?? 20 !! 3;
    $top        := $_ with $capture.head andthen .Int;

    say $verbose
      ?? "Top $top distributions with their dependees"
      !! "Top $top distributions and number of dependees";
    say "Add 'verbose' to also see the actual dependees"
      unless $verbose;

    for $eco.river.sort( -> $a, $b {
        $b.value.elems cmp $a.value.elems
          || $a.key.fc cmp $b.key.fc
    }).head($top) {
        say "$_.key() ($_.value.elems())";
        say "  $_.value()[]\n" if $verbose
    }
}

my sub tags($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;

    if $capture.head -> $needle {
        if $eco.tags(target($needle), :p).sort(*.key.fc) -> @tags {
            say "Tags matching '$needle'";
            line;

            for @tags {
                my $tag       := .key;
                my @identities = recent-identities(.value);
                if $verbose {
                    my $ids := @identities == 1 ?? "identity" !! "identities";
                    say "@identities.elems() recent $ids with '$tag' tag:";
                    line;
                    .say for @identities;
                }
                else {
                    my $identities := @identities == 1
                      ?? ""
                      !! " (" ~ @identities.elems ~ "x)";
                    say "$tag$identities";
                }
            }
        }
        else {
            say "No tags found matching '$needle'";
        }
    }
    else {
        my @tags = $eco.tags.keys;
        if $verbose {
            say "@tags.elems() unique tags:";
            line;
            .say for @tags.sort(*.fc);
        }
        else {
            say "Found @tags.elems() unique tags";
        }
    }
}

my sub set-ecosystem($_) {
    with .[1] {
        $app.load-ecosystem($_);
    }
    else {
        say "Using the $eco.longname()";
    }
}

my sub unresolvable($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;

    if $eco.unresolvable-dependencies(:all($verbose)) -> %ud {
        say $verbose
          ?? "All unresolvable identities"
          !! "Unresolvable identities in most recent versions only
Add 'verbose' to see all unresolvable identities";
        say "Add 'from=xxxx' to also see identities with a :from<> setting"
          unless my $from := $capture<from>;
        line;

        for %ud.keys.sort(*.fc) {
            next if !$from && from($_);
            say "$_";
            say "  $_" for %ud{$_};
        }
    }
    else {
        say "No unresolvable entities";
    }
}

my sub unversioned($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;

    my @unversioned = $eco.unversioned-distro-names;
    say "Found @unversioned.elems() distributions that did not have a release with a valid version";
    if $verbose {
        line;
        .say for @unversioned;
    }
    else {
        say "Add 'verbose' to list the distribution names";
    }
}

my sub update($_) {
    $app.update-ecosystem;
}

my sub use-targets($_) {
    my $capture := args-to-capture($_);
    my $needle  := $capture.head ?? build(|$capture) !! "";
    my $verbose := $capture.verbose;

    targetize1st($capture);
    if $eco.find-use-targets(|$capture).sort(*.fc) -> @targets {
        my $target := $needle ?? " that match '$needle'" !! "";

        say $verbose
          ?? "Use targets$target and their distribution (if different)"
          !! "Use targets$target
Add 'verbose' to also see their distribution";
        line;

        if $verbose {
            for @targets -> $target {
                my @distros = $eco.distros-of-use-target($target);
                say @distros == 1 && $target eq @distros.head
                  ?? $target
                  !! "$target (@distros[])";
            }
        }
        else {
            .say for @targets;
        }
    }
    else {
        say "No use-targets found for '$needle'";
    }
}

my sub verbose($_) { setter-getter-bool $_, 'verbose', 'verbosity' }

#- commands --------------------------------------------------------------------

$commands := Commands.new(
  default  => { say "Unrecognized command: $_" if $_ },
  commands => (
    :ecosystem(&set-ecosystem),
    :exit({ last }),
    :quit({ last }),

    &authors, &auths, &catch, &default-api, &default-auth, &default-from,
    &default-ver, &dependencies, &distros, &editor, &help, &identities,
    &meta, &no-tags, &release-dates, &reverse-dependencies, &river,
    &tags, &unresolvable, &unversioned, &update, &use-targets, &verbose
  ),
);

#- help ------------------------------------------------------------------------

my constant %help =
  authors => q:to/AUTHORS/,
If no search term given, show the number of unique authors (as determined
by the strings found in the "author" and "authors" fields of the meta
information), or the authors with the number of recent identities if
verbose is active.

If a search term is given, show the authors matching that term, and
their recent identities if verbose is active.

The search term may be expressed as a regular expression.
AUTHORS

  auths => q:to/AUTHS/,
If no search term given, show the number of unique "auth" strings seen
in the meta information, or the "auth" strings with the number of recent
identities if verbose is active.

If a search term is given, show the "auth" strings matching that term,
and their recent identities if verbose is active.

The search term may be expressed as a regular expression.
AUTHS

  catch => q:to/CATCH/,
Show whether exceptions will be caught or not, or change that setting.

By default any exceptions during execution will be caught and only a
one-line message of the error will be shown.  By default it is ON.
Switching it to OFF will cause an exception to show a complete
backtrace and exit the program, which may be desirable during debugging
and/or error reporting.
CATCH

  default-api => q:to/DEFAULT-API/,
Show or set the default "api" value to be used in ecosystem searches.
DEFAULT-API

  default-auth => q:to/DEFAULT-AUTH/,
Show or set the default "auth" value to be used in ecosystem searches.
DEFAULT-AUTH

  default-from => q:to/DEFAULT-FROM/,
Show or set the default "from" value to be used in ecosystem searches.
DEFAULT-FROM

  default-ver => q:to/DEFAULT-VER/,
Show or set the default "ver" value to be used in ecosystem searches.
DEFAULT-VER

  dependencies => q:to/DEPENDENCIES/,
Show the dependencies of a given distribution name.  If the distribution
name is not fully qualified with C<auth>, C<ver> and C<api>, then the
most recent version will be assumed.

You can also specify a version if you'd like to see the dependency
information of that version of the distribution.
DEPENDENCIES

  distros => q:to/DISTROS/,
Show the names of the distributions with the given search term.  For now
any distribution name that contains the given string, will be included.

The search term may be expressed as a regular expression.
DISTROS

  ecosystem => q:to/ECOSYSTEM/,
Show or set the ecosystem to be used in ecosystem searches.  Note that
the currently used ecosystem is also shown in the prompt.
ECOSYSTEM

  editor => q:to/EDITOR/,
Show the name of the underlying editor that is being used.  Note that
only Linenoise and LineEditor allow tab-completions.
EDITOR

  help => q:to/HELP/,
Show available commands if used without additional argument.  If a
command is specified as an additional argument, show any in-depth
information about that command.

Subjects with additional information:
- introduction  an introduction into some of the concepts used
- authverapi    how to ad-hoc specify auth / ver / api
- regexes       how to use regexes in search terms
- completions   when to expect tab-completions to work
HELP

  identities => q:to/IDENTITIES/,
Show the most recent versions of the identities that match the given
search term, either as use target, distribution name or description.

Show all identities that match if "verbose" is ON.

The search term may be expressed as a regular expression.
IDENTITIES

  meta => q:to/META/,
Show the meta information of the given distribution name as it was found
in the currently active ecosystem.  Note that this may be subtly different
from the contents of the META6.json file becomes an ecosystem may have
added fields and/or have updated fields for that particular ecosystem
(such as "source-url").
META

  no-tags => q:to/NO-TAGS/,
Show the most recent versions of the identities that do NOT have any
tags and that match the given search term, either as use target,
distribution name or description.

Show all identities without tags that match if "verbose" is ON.

The search term may be expressed as a regular expression.
NO-TAGS

  quit => q:to/QUIT/,
Exit and save any history.
QUIT

  release-dates => q:to/RELEASE-DATES/,
Show the dates and optionally the releases on those dates.
RELEASE-DATES

  reverse-dependencies => q:to/REVERSE-DEPENDENCIES/,
Show the distribution names that have a dependency on the given identity.
REVERSE-DEPENDENCIES

  river => q:to/RIVER/,
Show the N distributions (defaults to B<3>) that have the most reverse
dependencies (aka: are most "up-stream").
RIVER

  tags => q:to/TAGS/,
If no string given, show the number of unique tags, or the tags
with the number of recent identities if verbose is active.

If a string is given, show the tags matching that string, and their
recent identities if verbose is active.

The search term may be expressed as a regular expression.
TAGS

  unversioned => q:to/UNVERSIONED/,
Show how many distributions there are in the ecosystem without valid
version information (and which did B<not> have a later release with a
valid version value).  Optionally also list the identities of these
distributions.
UNVERSIONED

  update => q:to/UPDATE/,
Update the in-memory information about the current ecosystem from its
original source.
UPDATE

  use-targets => q:to/USE-TARGETS/,
Show the names of the use targets with the given search term
(aka search all keys that are specified in provides sections
of distributions in the ecosystem).

The search term may be expressed as a regular expression.
USE-TARGETS

  verbose => q:to/VERBOSE/,
Show or set the default verbosity level to be used in showing the
result of ecosystem searches.  The default is OFF.
VERBOSE
;

sub no-extended(Str:D $_) {
    say "No extended help available for: $_"
}

sub moreinfo(Str:D $command, Str:D $text) {
    say "More information about: $command";
    line;
    say $text.chomp
}

$helper = $commands.extended-help-from-hash(
  %help, :default(&no-extended), :handler(&moreinfo)
);

$helper.add-command: "introduction" => {
    say q:to/INTRODUCTION/.chomp;
The App::Ecosystems program allows one to browse the various parts
of the Raku ecosystem.  The following content storage systems are
currently supported:

rea
The Raku Ecosystem Archive (REA).  This attempts to contain all
modules ever published in the Raku ecosystem.  The information of
this content storage system will be loaded by default, unless
overridden with the --ecosystem command line argument.

zef
The "zef" ecosystem is the most modern and preferable content
storage for new Raku modules and updates to existing ones.

cpan
The "cpan" ecosystem uses Perl's CPAN (PAUSE) infrastructure as
content storage.  Its use is deprecated.

p6c
The "p6c" ecosystem is the oldest "content storage" system, but
has severe accountability and consistency issues, and its use
is therefore deprecated.  Any modules in this ecosystem should
be migrated to the "zef" ecosystem, or be removed (but still
remain available through the REA).
INTRODUCTION
}

$helper.add-command: "verauthapi" => {
    moreinfo 'authverapi', qq:to/VERAUTHAPI/;
A version of a distribution is identified by a so-called "identity".
This consists of the following parts:
- name
- ver     the version of the distribution (mandatory)
- auth    the authority of the distribution (mandatory)
- api     the API level (default: 0)
- from    programming language (default: 'Raku')

These are then expressed as a single string, using named argument
syntax.  For instance, the identity of the module providing this
functionality is "$app.^name():ver<$app.^ver()>:auth<$app.^auth()>".
VERAUTHAPI
}

$helper.add-command: "regexes" => {
    moreinfo 'regexes', q:to/REGEXES/;
The command line parser is still pretty basic, so you can only enter
regexes that look like a single word.  The following special characters
are allowed:
  ^   must match at beginning
  $   must match at end
  <<  must match at start of word
  >>  must match at end of word
  .   any character
  \   any backslash sequence, such as \d+
  ?   as multiplier (zero or one)
  +   as multiplier (one or more)
  *   as multiplier (zero or more)
REGEXES
}

$helper.add-command: "completions" => {
    my $prompt := $app.prompt;
    moreinfo 'completions',  $prompt.supports-completions
      ?? q:to/COMPLETIONS/.chomp !! qq:to/NO-COMPLETIONS/.chomp;
The first word allows tab-completions on the available commands.

The second word will tab complete depending on the contents of
the first word:
- auths        known "auth" strings
- authors      known author names
- distros      known distribution names
- help         available commands
- identities   known identities
- tags         known tags
- use-targets  known use targets
COMPLETIONS
The currently active editor ('$prompt.editor-name()') does NOT support
completions.
NO-COMPLETIONS
}

#- App::Ecosystems -------------------------------------------------------------

class App::Ecosystems:ver<0.0.8>:auth<zef:lizmat> {

    has $.ecosystem = "rea";
    has $.ver     is rw;
    has $.auth    is rw;
    has $.api     is rw;
    has $.from    is rw;
    has $.verbose is rw = False;
    has $.eco    is built(False);
    has $.prompt is built(False);

    has $!last-line  = "";
    has %!ecosystems = <cpan fez rea p6c>.map(* => Any);

    method TWEAK(
      :$history is copy = "ecosystems",
    ) {
        $history = ($*HOME || $*TMPDIR).add(".raku/$history")
          if $history ~~ Str && !$history.contains(/\W/);
        $!prompt := Prompt.new(:$history, :&additional-completions);
        %!ecosystems =
          cpan => Any,
          fez  => Any,
          rea  => Any,
          p6c  => Any
        ;

        # Alias "zef" to "fez"
        .<zef> := .<fez> with %!ecosystems;
    }

    method report-ecosystem() {
        say "Ecosystem: $!eco.longname() ('$!ecosystem' $!eco.identities.elems() identities)";
        say "  Updated: $!eco.IO.modified.DateTime.Str.substr(0,19)";
        with $eco.least-recent-release -> $from {
            say "   Period: $from - $!eco.most-recent-release()";
        }
    }

    method load-ecosystem($ecosystem = $!ecosystem) {
        with %!ecosystems{$ecosystem} -> $!eco {
            $!ecosystem = $ecosystem;
        }
        elsif %!ecosystems{$ecosystem}:exists {
            my $message = "Loading $ecosystem ecosystem...";
            print $message;
            %!ecosystems{$ecosystem} =
              $eco := $!eco = Ecosystem.new(:$ecosystem);
            print "\b" x $message.chars;
            $!ecosystem = $ecosystem;
        }
        else {
            say "Unknown ecosystem '$ecosystem'";
            return;
        }

        self.report-ecosystem;
    }

    method update-ecosystem() {
        with $!eco -> $eco {
            my $message = "Updating '$!ecosystem' ecosystem...";
            print $message;
            $eco.update;
            print "\b" x $message.chars;
            self.report-ecosystem;
        }
        else {
            say "No ecosystem to update";
        }
    }

    method run(App::Ecosystems:D:) {
        self.load-ecosystem without $!eco;
        $app := self;
        $eco := $!eco;
        loop {
            last without my $line = $!prompt.read("\n$!ecosystem > ");
            $commands.process($line);

            if $line ne $!last-line {
                $!prompt.add-history($line);
                $!last-line = $line;
            }
        }
        $!prompt.save-history;
    }
}

#- subroutines -----------------------------------------------------------------

my sub ecosystems(*%_) is export {
    App::Ecosystems.new(|%_).run
}

# vim: expandtab shiftwidth=4
