use Commands:ver<0.0.2+>:auth<zef:lizmat>;
use Ecosystem:ver<0.0.20+>:auth<zef:lizmat>;
use Identity::Utils:ver<0.0.11+>:auth<zef:lizmat>;
use Prompt:ver<0.0.6+>:auth<zef:lizmat>;

#- App::Ecosystems -------------------------------------------------------------

class App::Ecosystems {
    has $.ecosystem = "rea";
    has $.ver;
    has $.auth;
    has $.api;
    has $.from;
    has $.verbose;
    has $.eco    is built(False);
    has $.prompt is built(False);

    method TWEAK(
      :$history = "here",
    ) {
        $!prompt := Prompt.new(:$history);
    }
            
    method !load-ecosystem($ecosystem = $!ecosystem) {
        say "Loading $ecosystem ecosystem...";
        $!eco      := Ecosystem.new(:$ecosystem);
        $!ecosystem = $ecosystem;
    }

    method run(App::Ecosystems:D:) {
        self!load-ecosystem without $!eco;
        loop {
            last without my $line = $!prompt.readline("$!ecosystem> ");
            say $line;
        }
        $!prompt.save-history;
    }
}

#- subroutines -----------------------------------------------------------------

my sub ecosystems(*%_) is export {
    App::Ecosystems.new(|%_).run
}

# vim: expandtab shiftwidth=4
