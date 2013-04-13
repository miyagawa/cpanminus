use strict;
use Test::More;
use xt::Run;

plan skip_all => "needs 5.12" unless $] >= 5.012;

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib-src';

run_L "Task::Deprecations::5_12";
like last_build_log, qr/installed Class-ISA/;

done_testing;

