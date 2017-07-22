use strict;
use warnings;
use Test::More;
use xt::Run;

run_L "--mirror-index", "xt/multi_index_mirror.txt", 'Hash::MultiValue@0.03';
like last_build_log, qr/installed Hash-MultiValue-0\.03/;

# get latest dev version right from index but not equal or bigger than 0.04
run_L "--mirror-index", "xt/multi_index_mirror.txt", 'Hash::MultiValue~<0.04';
like last_build_log, qr/installed Hash-MultiValue-0\.02/;

# check if binary search supports duplicates in dict file
run_L "--mirror-index", "xt/multi_index_mirror.txt", 'Hash::MultiValue~<0.03';
like last_build_log, qr/installed Hash-MultiValue-0\.02/;


done_testing;

