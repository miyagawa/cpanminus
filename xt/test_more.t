use strict;
use Test::More;
use xt::Run;

plan skip_all => 'Skip with perl >= 5.17' if $] >= 5.017;

# Test::More's exit.t has $^X -I../t/lib

$ENV{TEST} = 1;
run_L "Test::Simple";
like last_build_log, qr/Successfully (re)?installed Test-Simple/;

done_testing;

