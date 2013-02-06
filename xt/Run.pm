package xt::Run;
use strict;
use base qw(Exporter);
our @EXPORT = qw(run run_L last_build_log);

use Capture::Tiny qw(capture);
use File::Temp qw(tempdir);

delete $ENV{PERL_CPANM_OPT};
$ENV{PERL_CPANM_HOME} = tempdir(CLEANUP => 1);

sub run_L {
    run("-L", "$ENV{PERL_CPANM_HOME}/perl5", @_);
}

sub run {
    my @args = @_;
    my @notest = $ENV{NOTEST} ? ("--notest") : ();
    my($stdout, $stderr, $exit) = capture {
        system($^X, "./script/cpanm.PL", @notest, "--quiet", "--reinstall", @args);
    };
    ::diag($stderr) if $stderr;
    return wantarray ? ($stdout, $stderr, $exit) : $stdout;
}

sub last_build_log {
    open my $log, "<", "$ENV{PERL_CPANM_HOME}/latest-build/build.log";
    join '', <$log>;
}

1;
