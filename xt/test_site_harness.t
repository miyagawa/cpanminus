use strict;
use Test::More;
use xt::Run;

$ENV{TEST} = 1;
run_L "Hash::MultiValue";
like last_build_log, qr/Successfully installed Hash-MultiValue/;

done_testing;

