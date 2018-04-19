package xt::Run;
use strict;
use base qw(Exporter);
our @EXPORT = qw(run run_L last_build_log);

use Capture::Tiny qw(capture);
use File::Temp qw(tempdir);

my $executable = "./script/cpanm-menlo";

delete $ENV{PERL_CPANM_OPT};
$ENV{PERL_CPANM_HOME} = tempdir(CLEANUP => 1);

sub run_L {
    run("-L", "$ENV{PERL_CPANM_HOME}/perl5", @_);
}

sub run {
    my @args = @_;

    # use metacpan's mirror in the tests
    my @mirrors;
    unless (grep /--mirror($|=)/, @args) {
        @mirrors = ('--mirror', 'http://cpan.metacpan.org/');
    }

    my @notest = $ENV{TEST} ? ("--no-notest") : ("--notest");
    my($stdout, $stderr, $exit) = capture {
        system($^X, $executable, @notest, "--quiet", "--reinstall", @mirrors, @args);
    };
    ::diag($stderr) if $stderr and !$ENV{NODIAG};  # Some tests actually want stderr
    return wantarray ? ($stdout, $stderr, $exit) : $stdout;
}

sub last_build_log {
    open my $log, "<", "$ENV{PERL_CPANM_HOME}/latest-build/build.log";
    join '', <$log>;
}

1;
