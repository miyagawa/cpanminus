use strict;
use Test::More;
use xt::Run;

run_L '-n', "https://github.com/miyagawa/Hash-MultiValue/archive/master.tar.gz";
like last_build_log, qr/installed Hash-MultiValue-/;

done_testing;
