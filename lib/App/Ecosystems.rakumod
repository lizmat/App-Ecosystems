#- prologue --------------------------------------------------------------------

use Commands:ver<0.0.3+>:auth<zef:lizmat>;
use Ecosystem:ver<0.0.20+>:auth<zef:lizmat>;
use Identity::Utils:ver<0.0.11+>:auth<zef:lizmat>;
use Prompt:ver<0.0.6+>:auth<zef:lizmat>;

# The named parts of an identity
my constant @identity-parts    = <ver auth api from>;
my constant any-identity-parts = @identity-parts.any;

#- helper subs -----------------------------------------------------------------
# These all assume $*APP is set to the active App:Ecosystem object
# and $*ECO is set to the acive Ecosystem object

# Set / Get ecosystem string attribute value
my sub setter-getter($_, $short, $long = $short) {
    with .[1] -> $new is copy {
        $new = Nil if $new eq 'Any';
        $*APP."$short"() = $new;
        say "Default $long set to '{$new // 'Any'}'";
    }
    else {
        say "Default $long is: '{$*APP."$short"() // 'Any'}'";
    }
}

# Set / Get ecosystem bool attribute value
my sub setter-getter-bool($_, $short, $long = $short, :$object = $*APP) {
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

    my $app    := $*APP;
    my $verbose = $app.verbose;
    my role verbose { has $.verbose is built(:bind) }

    for @words.skip -> $word {
        with $word.index("=",1) -> $index {
            my $key := $word.substr(0,$index);
            $key eq any-identity-parts
              ?? (%hash{$key} := $word.substr($index + 1))
              !! say "'$key' is not a supported key";
        }
        elsif $word eq 'verbose' {
            $verbose = True;
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

#- help ------------------------------------------------------------------------

sub help($_) {
    say "Available commands:";
    line;
    say $*COMMANDS.primaries().join(" ").naive-word-wrapper;
}

#- handlers --------------------------------------------------------------------

my sub catch($_) {
}

my sub dependencies($_) {
    my $capture := args-to-capture($_);

    if $*ECO.resolve(|$capture) -> $identity {
        my $verbose := $capture.verbose;

        if $*ECO.dependencies($identity, :recurse($verbose)) -> @identities {
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
    say "distro";
}

my sub set-ecosystem($_) {
    with .[1] {
        $*APP.load-ecosystem($_);
    }
    else {
        say "Using the $*APP.ecosystem() ecosystem";
    }
}

my sub identity($_) {
    say "identity";
}

my sub meta($_) {
    say "meta";
}

my sub reverse-dependencies($_) {
    say "reverse-dependencies";
}

my sub river($_) {
    say "river";
}

my sub unresolvable($_) {
    say "unresolvable";
}

my sub unversioned($_) {
    say "unversioned";
}

my sub use-target($_) {
    my $capture := args-to-capture($_);
    my $needle  := build(|$capture);

    my $eco := $*ECO;
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

my $commands = Commands.new(
  default  => { say "Unrecognized command: $_" },
  commands => (
    api                  => { setter-getter $_, 'api' },
    authority            => { setter-getter $_, 'auth', 'authority' },
    catch                => {
      setter-getter-bool $_, 'catch', 'exception catching', :object($commands)
    },
    dependencies         => &dependencies,
    distro               => &distro,
    ecosystem            => &set-ecosystem,
    editor               => { say $*ECO.prompt.editor-name() },
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

# Complete shortened primary commands
sub additional-completions($line, $) {
    $commands.primaries.map({
        "$_ " if .starts-with($line)
    }).List
}

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
        my $*APP := self;
        my $*ECO := $!eco;
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
