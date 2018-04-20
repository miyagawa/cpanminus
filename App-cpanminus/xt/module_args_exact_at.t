use strict;
use Test::More;
use xt::Run;

{
    # mirror.txt
    run_L '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.01';
    like last_build_log, qr/Found Hash::MultiValue 0.02 which doesn't satisfy == 0.01/;

    run_L '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.02';
    like last_build_log, qr/installed Hash-MultiValue-0.02/;
}

{
    # historical releases
    run_L '--mirror-only', 'Try::Tiny@0.10';
    like last_build_log, qr/Found Try::Tiny .* doesn't satisfy == 0.10/;

    run_L 'Try::Tiny'; # pull latest from CPAN

    run_L '--skip-installed', 'Try::Tiny@0.11';
    like last_build_log, qr/Searching Try::Tiny \(== 0.11\) on cpanmetadb/;
    unlike last_build_log, qr/Try::Tiny is up to date/;

    run_L 'Carmel@v0.1.22';
    like last_build_log, qr/Carmel-v0.1.22-TRIAL/, 'should work with TRIAL release';
}

done_testing;
