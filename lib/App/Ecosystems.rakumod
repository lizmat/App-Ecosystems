#- prologue --------------------------------------------------------------------

use Commands:ver<0.0.4+>:auth<zef:lizmat>;
use Ecosystem:ver<0.0.24+>:auth<zef:lizmat>;
use Identity::Utils:ver<0.0.11+>:auth<zef:lizmat>;
use Prompt:ver<0.0.6+>:auth<zef:lizmat>;

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
    $string.contains(('.','^','$','\\','<<','>>').any)
      ?? "/:i $string.subst('::','\\:\\:',:g) /".EVAL
      !! $string
}

# Just a visual divider
sub line() { say "-" x 80 }

# Complete shortened primary commands
sub additional-completions($line, $pos) {
    # not longer at the first word
    with $line.index(" ") -> $index {
        my @words = $line.words;
        if @words[1].lc -> $target {
            my $before  := $line.substr(0,$index + 1);
            my $capture := args-to-capture(@words);
            if $eco.find-use-targets(|$capture).sort(*.fc) -> @targets {
                @targets.map({
                    $before ~ $_ if .lc.starts-with($target)
                }).List
            }
        }
    }

    # still at the first word
    else {
        $commands.primaries.map({
            "$_ " if .starts-with($line)
        }).List
    }
}

#- help ------------------------------------------------------------------------

my constant %help =
  api => q:to/API/,
Show or set the default "api" value to be used in ecosystem searches.
API

  authority => q:to/AUTHORITY/,
Show or set the default "auth" value to be used in ecosystem searches.
AUTHORITY

  catch => q:to/CATCH/,
Show whether exceptions will be caught or not, or change that setting.

By default any exceptions during execution will be caught and only a
one-line message of the error will be shown.  By default it is ON.
Switching it to OFF will cause an exception to show a complete
backtrace and exit the program, which may be desirable during debugging
and/or error reporting.
CATCH

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

  from => q:to/FROM/,
Show or set the default "from" value to be used in ecosystem searches.
FROM

  help => q:to/HELP/,
Show available commands if used without additional argument.  If a
command is specified as an additional argument, show any in-depth
information about that command.
HELP

  identities => q:to/IDENTITIES/,
Show the most recent versions of the identities that match the given search
term, either as distribution name or C<use> target.

The search term may be expressed as a regular expression.
IDENTITIES

  meta => q:to/META/,
Show the meta information of the given distribution name as it was found
in the currently active ecosystem.  Note that this may be subtly different
from the contents of the META6.json file becomes an ecosystem may have
added fields and/or have updated fields for that particular ecosystem
(such as "source-url").
META

  quit => q:to/QUIT/,
Exit and save any history.
QUIT

  reverse-dependencies => q:to/REVERSE-DEPENDENCIES/,
Show the distribution names that have a dependency on the given identity.
REVERSE-DEPENDENCIES

  river => q:to/RIVER/,
Show the N distributions (defaults to B<3>) that have the most reverse
dependencies (aka: are most "up-stream").
RIVER

  unversioned => q:to/UNVERSIONED/,
Show how many distributions there are in the ecosystem without valid
version information (and which did B<not> have a later release with a
valid version value).  Optionally also list the identities of these
distributions.
UNVERSIONED

  use-targets => q:to/USE-TARGETS/,
Show the names of the use targets with the given search term
(aka search all keys that are specified in provides sections
of distributions in the ecosystem).

The search term may be expressed as a regular expression.
USE-TARGETS

  verbose => q:to/VERBOSE/,
Show or set the default verbosity level to be used in showing the result
of ecosystem searches.  The default is OFF.
VERBOSE

  version => q:to/VERSION/,
Show or set the default "ver" value to be used in ecosystem searches.
VERSION
;

sub default($_) {
    say "No extended help available for: $_"
}

sub handler($command, $text) {
    say "More information about: $command";
    line;
    say $text.chomp
}

sub help($_) {
    state $help = $*COMMANDS.extended-help-from-hash(
      %help, :&default, :&handler
    );
    if .skip.join(" ") -> $deeper {
        $help.process($deeper)
    }
    else {
        say "Available commands:";
        line;
        say $commands.primaries().join(" ").naive-word-wrapper;
        say "More in-depth help available with 'help <command>'";
    }
}

#- handlers --------------------------------------------------------------------

my sub catch($_) {
    setter-getter-bool $_, 'catch', 'exception catching', :object($commands)
}

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
    my $needle  := build(|$capture);

    targetize1st($capture);
    if $eco.find-distro-names(|$capture).sort(*.fc) -> @names {
        my $verbose := $capture.verbose;

        say $verbose
          ?? "Distributions that match '$needle' and their frequency"
          !! "Distributions that match '$needle'
Add 'verbose' to also see their frequency";
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

my sub set-ecosystem($_) {
    with .[1] {
        $app.load-ecosystem($_);
    }
    else {
        say "Using the $eco.longname()";
    }
}

my sub identities($_) {
    my $capture := args-to-capture($_);
    my $needle  := build(|$capture);
    my $verbose := $capture.verbose;

    targetize1st($capture);
    if $eco.find-identities(|$capture, :all($verbose)) -> @ids {
        say $verbose
          ?? "All identities that match '$needle'"
          !! "Most recent version of identities that match '$needle'
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
            say "";
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

my sub use-targets($_) {
    my $capture := args-to-capture($_);
    my $verbose := $capture.verbose;
    my $needle  := build(|$capture);

    targetize1st($capture);
    if $eco.find-use-targets(|$capture).sort(*.fc) -> @targets {

        say $verbose
          ?? "Use targets that match $needle and their distribution"
          !! "Use targets that match $needle
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

#- commands --------------------------------------------------------------------

$commands := Commands.new(
  default  => { say "Unrecognized command: $_" if $_ },
  commands => (
    api                  => { setter-getter $_, 'api' },
    authority            => { setter-getter $_, 'auth', 'authority' },
    catch                => &catch,
    dependencies         => &dependencies,
    distros              => &distros,
    ecosystem            => &set-ecosystem,
    editor               => { say $app.prompt.editor-name() },
    exit                 => { last },
    from                 => { setter-getter $_, 'from' },
    help                 => &help,
    identities           => &identities,
    meta                 => &meta,
    quit                 => { last },
    reverse-dependencies => &reverse-dependencies,
    river                => &river,
    unresolvable         => &unresolvable,
    unversioned          => &unversioned,
    use-targets          => &use-targets,
    verbose              => { setter-getter-bool $_, 'verbose', 'verbosity' },
    version              => { setter-getter $_, 'ver', 'version' },
  ),
);

#- App::Ecosystems -------------------------------------------------------------

class App::Ecosystems {
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

        say "Ecosystem: $eco.longname() ('$ecosystem' $eco.identities.elems() identities)";
        say "  Updated: $eco.IO.modified.DateTime.Str.substr(0,19)";
        with $eco.least-recent-release -> $from {
            say "   Period: $from - $eco.most-recent-release()";
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
