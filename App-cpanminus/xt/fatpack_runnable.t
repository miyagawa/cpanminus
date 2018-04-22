use strict;
BEGIN { $ENV{FATPACKED_TEST} = 1 };
use lib ".";
use xt::Run;
use Test::More;

run_L 'Try::Tiny';
like last_build_log, qr/installed Try-Tiny/;

done_testing;
