use strict;
use xt::Run;
use Test::More;

# https://github.com/miyagawa/cpanminus/issues/229

# install the higher version than on CPAN
run './testdist/Hash-MultiValue-1.200';

run '--skip-installed', 'Hash::MultiValue';
like last_build_log, qr/is up to date\. \(1\.200\)/, "by default don't downgrade";

run '--reinstall', 'Hash::MultiValue';
like last_build_log, qr/downgraded/;

run '--skip-installed', 'Hash::MultiValue';
like last_build_log, qr/is up to date/;
unlike last_build_log, qr/installed Hash-MultiValue/;

run 'Hash::MultiValue@0.13';

run '--skip-installed', 'Hash::MultiValue@0.13';
like last_build_log, qr/is up to date/;
unlike last_build_log, qr/installed Hash-MultiValue-0\.13/;

run '--reinstall', 'Hash::MultiValue@0.13';
unlike last_build_log, qr/is up to date/;
like last_build_log, qr/reinstalled Hash-MultiValue-0\.13/;

run 'Hash::MultiValue'; # install the latest

run '--skip-installed', 'Hash::MultiValue@999';
like last_build_log, qr/Found .* which doesn't satisfy == 999/;

run '--skip-installed', 'Hash::MultiValue~999';
like last_build_log, qr/Found .* which doesn't satisfy 999/;

done_testing;
