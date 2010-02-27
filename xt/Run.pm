package xt::Run;
use strict;
use base qw(Exporter);
our @EXPORT = qw(run last_build_log);

use File::Temp qw(tempdir);

$ENV{PERL_CPANM_HOME} = tempdir(CLEANUP => 1);

sub run {
    system($^X, "./script/cpanm.PL", "--quiet", @_);
}

sub last_build_log {
    open my $log, "<", "$ENV{PERL_CPANM_HOME}/latest-build/build.log";
    join '', <$log>;
}

1;
