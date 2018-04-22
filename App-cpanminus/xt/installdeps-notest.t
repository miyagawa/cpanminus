use strict;
use Test::More;
use lib ".";
use xt::Run;

run "--installdeps", "./testdist/Test-META";
like last_build_log, qr/if you have Test::NoWarnings/;

done_testing;
