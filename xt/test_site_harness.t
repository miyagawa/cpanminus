use strict;
use Test::More;
use xt::Run;

run_L "--no-notest", "Hash::MultiValue";
like last_build_log, qr/Successfully installed Hash-MultiValue/;

done_testing;

