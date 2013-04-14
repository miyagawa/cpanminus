use strict;
use xt::Run;
use Test::More;

# https://github.com/miyagawa/cpanminus/issues/229

run 'Hash::MultiValue@0.13';

run '--skip-installed', 'Hash::MultiValue';
like last_build_log, qr/is up to date/;
unlike last_build_log, qr/installed Hash-MultiValue/;

run '--skip-installed', 'Hash::MultiValue@0.13';
like last_build_log, qr/is up to date/;
unlike last_build_log, qr/installed Hash-MultiValue-0\.13/;

done_testing;
