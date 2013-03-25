use strict;
use Test::More;
use xt::Run;

run "--installdeps", "--notest", "./testdist/Test-META";
like last_build_log, qr/if you have Test::NoWarnings/;

done_testing;
