use strict;
use warnings;
use Test::More;
use xt::Run;

run_L "--mirror-index", "xt/multi_index_mirror.txt", 'Hash::MultiValue@0.01';
warn last_build_log;

like last_build_log, qr/installed Hash-MultiValue-0\.01/;

done_testing;

