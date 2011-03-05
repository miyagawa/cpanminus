package xt::Run;
use strict;
use base qw(Exporter);
our @EXPORT = qw(run last_build_log);

use Capture::Tiny qw(capture);
use File::Temp qw(tempdir);

$ENV{PERL_CPANM_HOME} = tempdir(CLEANUP => 1);

sub run {
    my @args = @_;
    my @notest = $ENV{NOTEST} ? ("--notest") : ();
    my($stdout, $stderr) = capture { system($^X, "./script/cpanm.PL", @notest, "--quiet", "--reinstall", @args) };
}

sub last_build_log {
    open my $log, "<", "$ENV{PERL_CPANM_HOME}/latest-build/build.log";
    join '', <$log>;
}

1;
