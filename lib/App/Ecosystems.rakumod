#- prologue --------------------------------------------------------------------

use Commands:ver<0.0.3+>:auth<zef:lizmat>;
use Ecosystem:ver<0.0.21+>:auth<zef:lizmat>;
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

    sub add-key($key, $value) {
        $key eq any-identity-parts
          ?? (%hash{$key} := $value)
          !! say "'$key' is not a supported key";
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
            add-key($word.substr(0,$index), $word.substr($index + 1));
        }
        elsif $word.ends-with('>') {
            add-key($word.substr(0,$_), $word.substr($_ + 1).chop)
              with $word.index('<');
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

sub help($_) {
    say "Available commands:";
    line;
    say $commands.primaries().join(" ").naive-word-wrapper;
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

my sub distro($_) {
    my $capture := args-to-capture($_);
    my $needle  := build(|$capture);

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
        say "Using the $app.ecosystem() ecosystem";
    }
}

my sub identity($_) {
    my $capture := args-to-capture($_);
    my $needle  := build(|$capture);

    my $verbose := $capture.verbose;
    if $eco.find-identities(|$capture, :all($verbose)).sort(*.fc) -> @ids {
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

my sub use-target($_) {
    my $capture := args-to-capture($_);
    my $needle  := build(|$capture);

    if $eco.find-use-targets(|$capture).sort(*.fc) -> @use-targets {
        my $verbose := $capture.verbose;

        say $verbose
          ?? "Use targets that match $needle and their distribution"
          !! "Use targets that match $needle
Add 'verbose' to also see their distribution";
        line;

        if $verbose {
            for @use-targets -> $use-target {
                my @distros = $eco.distros-of-use-target($use-target);
                say @distros == 1 && $use-target eq @distros.head
                  ?? $use-target
                  !! "$use-target (@distros[])";
            }
        }
        else {
            .say for @use-targets;
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
    distro               => &distro,
    ecosystem            => &set-ecosystem,
    editor               => { say $app.prompt.editor-name() },
    exit                 => { last },
    from                 => { setter-getter $_, 'from' },
    help                 => &help,
    identity             => &identity,
    meta                 => &meta,
    quit                 => { last },
    reverse-dependencies => &reverse-dependencies,
    river                => &river,
    unresolvable         => &unresolvable,
    unversioned          => &unversioned,
    use-target           => &use-target,
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
    }

    method load-ecosystem($ecosystem = $!ecosystem) {
        with %!ecosystems{$ecosystem} -> $!eco {
            $!ecosystem = $ecosystem;
        }
        elsif %!ecosystems{$ecosystem}:exists {
            say "Loading $ecosystem ecosystem...";
            %!ecosystems{$ecosystem} := $!eco := Ecosystem.new(:$ecosystem);
            $!ecosystem = $ecosystem;
        }
        else {
            say "Unknown $ecosystem";
        }
    }

    method run(App::Ecosystems:D:) {
        self.load-ecosystem without $!eco;
        $app := self;
        $eco := $!eco;
        loop {
            last without my $line = $!prompt.read("$!ecosystem > ");
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
