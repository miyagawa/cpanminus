package xt::Run;
use strict;
use base qw(Exporter);
our @EXPORT = qw(run run_L run_uninstall run_uninstall_L last_build_log);

use Capture::Tiny qw(capture);
use File::Temp qw(tempdir);

my $executable = $ENV{FATPACKED_TEST} ? './cpanm' : './script/cpanm.PL';

delete $ENV{PERL_CPANM_OPT};
$ENV{PERL_CPANM_HOME} = tempdir(CLEANUP => 1);

sub run_L {
    run("-L", "$ENV{PERL_CPANM_HOME}/perl5", @_);
}

sub run {
    my @args = @_;
    my @notest = $ENV{NOTEST} ? ("--notest") : ();
    my($stdout, $stderr, $exit) = capture {
        system($^X, $executable, @notest, "--quiet", "--reinstall", @args);
    };
    ::diag($stderr) if $stderr;
    return wantarray ? ($stdout, $stderr, $exit) : $stdout;
}

sub run_uninstall_L {
    run_uninstall("-L", "$ENV{PERL_CPANM_HOME}/perl5", @_);
}

sub run_uninstall {
    my @args = @_;
    my($stdout, $stderr, $exit) = capture {
        system($^X, $executable, "--uninstall", @args);
    };
    ::diag($stderr) if $stderr;
    return wantarray ? ($stdout, $stderr, $exit) : $stdout;
}

sub last_build_log {
    open my $log, "<", "$ENV{PERL_CPANM_HOME}/latest-build/build.log";
    join '', <$log>;
}

1;
