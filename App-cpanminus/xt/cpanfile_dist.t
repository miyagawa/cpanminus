use strict;
use Test::More;
use xt::Run;

{
    run_L "--installdeps", "./testdist/cpanfile_dist";

    like last_build_log, qr/installed Hash-MultiValue-0\.15/;
    like last_build_log, qr/installed Path-Class-0\.26/;
}

done_testing;
