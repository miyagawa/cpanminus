use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

{
    # mirror.txt
    run "-L", $local_lib, '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.01';
    like last_build_log, qr/Found Hash::MultiValue 0.02 which doesn't satisfy == 0.01/;

    run "-L", $local_lib, '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.02';
    like last_build_log, qr/installed Hash-MultiValue-0.02/;
}

{
    # metacpan releases

    run "-L", $local_lib, '--mirror-only', 'Try::Tiny@0.10';
    like last_build_log, qr/Found Try::Tiny .* doesn't satisfy == 0.10/;

    run "-L", $local_lib, 'Try::Tiny'; # pull latest from CPAN

    run "-L", $local_lib, '--skip-installed', 'Try::Tiny@0.11';
    like last_build_log, qr/Searching Try::Tiny \(0.11\) on metacpan/;
    unlike last_build_log, qr/Try::Tiny is up to date/;
}

done_testing;
