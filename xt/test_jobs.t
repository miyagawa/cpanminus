use strict;
use Test::More;
use xt::Run;

run "--test-only", "--jobs=5", "Test::Simple";
diag last_build_log;
like last_build_log, qr/Successfully tested Test-Simple/;

done_testing;

