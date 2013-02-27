use strict;
use Test::More;
use xt::Run;

{
    # mirror.txt
    run '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.01';
    like last_build_log, qr/Found Hash::MultiValue 0.02 which doesn't satisfy == 0.01/;

    run '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.02';
    like last_build_log, qr/installed Hash-MultiValue-0.02/;
}

{
    # metacpan releases

    run '--mirror-only', 'Try::Tiny@0.10';
    like last_build_log, qr/Found Try::Tiny .* doesn't satisfy == 0.10/;

    run 'Try::Tiny'; # pull latest from CPAN

    run '--skip-installed', 'Try::Tiny@0.11';
    like last_build_log, qr/Searching Try::Tiny \(== 0.11\) on metacpan/;
    unlike last_build_log, qr/Try::Tiny is up to date/;

    run '-n', 'Plack@1.0017';
    like last_build_log, qr/Plack-1.0017-TRIAL/, 'should work with TRIAL release';
}

done_testing;
