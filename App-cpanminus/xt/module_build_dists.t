use strict;
use Test::More;
use lib ".";
use xt::Run;

run "Test::Pod";
like last_build_log, qr/installed Test-Pod/;

done_testing;

