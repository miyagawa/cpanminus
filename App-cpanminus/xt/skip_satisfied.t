use strict;
use Test::More;
use lib ".";
use xt::Run;

run_L "MIYAGAWA/Hash-MultiValue-0.03.tar.gz";
run_L '--skip-satisfied', "Hash::MultiValue~0.02";

like last_build_log, qr/You have Hash::MultiValue \(0\.03\)/;

run_L '--skip-satisfied', "Hash::MultiValue~0.04";
like last_build_log, qr/installed Hash-MultiValue/;

done_testing;
