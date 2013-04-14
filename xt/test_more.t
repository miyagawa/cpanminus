use strict;
use Test::More;
use xt::Run;

# Test::More's exit.t has $^X -I../t/lib

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';

run_L "--no-notest", "Test::Simple";
like last_build_log, qr/Successfully (re)?installed Test-Simple/;

done_testing;

