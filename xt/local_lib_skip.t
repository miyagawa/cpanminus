use strict;
use Test::More;
use xt::Run;

run "Data::Dump";

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';

run_L "--skip-installed", "Data::Dump";
like last_build_log, qr/installed Data-Dump/; # should reinstall because it's not core

done_testing;

