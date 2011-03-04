use strict;
use Test::More;
use xt::Run;

run "Data::Dump";

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';

my @opt = ("--skip-installed", "-L", $local_lib);

run @opt, "Data::Dump";
like last_build_log, qr/installed Data-Dump/; # should reinstall because it's not core

done_testing;

