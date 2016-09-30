use strict;
use Test::More;
use xt::Run;

run "--test-only", "Hash::MultiValue";
like last_build_log, qr/Successfully tested Hash-MultiValue/;

done_testing;

