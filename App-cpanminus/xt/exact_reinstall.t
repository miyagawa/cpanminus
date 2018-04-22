use strict;
use lib ".";
use xt::Run;
use Test::More;

# https://github.com/miyagawa/cpanminus/issues/229

# install the higher version than on CPAN
run_L './testdist/Hash-MultiValue-1.200';

run_L '--skip-installed', 'Hash::MultiValue';
like last_build_log, qr/is up to date\. \(1\.200\)/, "by default don't downgrade";

run_L '--reinstall', 'Hash::MultiValue';
like last_build_log, qr/downgraded/;

run_L '--skip-installed', 'Hash::MultiValue';
like last_build_log, qr/is up to date/;
unlike last_build_log, qr/installed Hash-MultiValue/;

run_L 'Hash::MultiValue@0.13';

run_L '--skip-installed', 'Hash::MultiValue@0.13';
like last_build_log, qr/is up to date/;
unlike last_build_log, qr/installed Hash-MultiValue-0\.13/;

run_L '--reinstall', 'Hash::MultiValue@0.13';
unlike last_build_log, qr/is up to date/;
like last_build_log, qr/reinstalled Hash-MultiValue-0\.13/;

run_L 'Hash::MultiValue'; # install the latest

run_L '--skip-installed', 'Hash::MultiValue@999';
like last_build_log, qr/Found .* which doesn't satisfy == 999/;

run_L '--skip-installed', 'Hash::MultiValue~999';
like last_build_log, qr/Found .* which doesn't satisfy 999/;

done_testing;
