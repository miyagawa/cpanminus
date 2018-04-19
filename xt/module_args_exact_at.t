use strict;
use Test::More;
use xt::Run;

{
    # mirror.txt - has $new, but not $old
    my ($old, $new) = qw{0.12 0.13};
    run_L '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@'.$old;
    like last_build_log, qr/Found Hash::MultiValue \Q$new\E which doesn't satisfy == \Q$old\E/;

    run_L '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@'.$new;
    like last_build_log, qr/installed Hash-MultiValue-\Q$new\E/;
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
