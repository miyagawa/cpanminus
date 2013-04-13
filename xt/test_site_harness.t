use strict;
use Test::More;
use xt::Run;

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib-src';

run_L "--no-notest", "Hash::MultiValue";
like last_build_log, qr/Successfully installed Hash-MultiValue/;

done_testing;

