use strict;
use Test::More;
use lib ".";
use xt::Run;

run_L "--mirror-index", "xt/mirror.txt", "Hash::MultiValue";
like last_build_log, qr/installed Hash-MultiValue-0\.02/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "Hash::MultiValue~0.01";
like last_build_log, qr/Hash::MultiValue is up to date/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "Hash::MultiValue~0.03";
like last_build_log, qr/Found Hash::MultiValue 0\.02 which doesn't satisfy 0\.03/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "--cascade-search", "Hash::MultiValue~0.03";
like last_build_log, qr/installed Hash-MultiValue-/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "Try::Tiny";
like last_build_log, qr/Couldn't find .* Try::Tiny/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "--cascade-search", "Try::Tiny";
like last_build_log, qr/installed Try-Tiny/;

done_testing;
