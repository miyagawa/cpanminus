use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

{
    run_L "--installdeps", "--notest", "./testdist/cpanfile_app";

    like last_build_log, qr/installed Hash-MultiValue-0\.10/;
    like last_build_log, qr/installed Try-Tiny-0\.11/;
    like last_build_log, qr/installed Test-Warn/, '--notest means skip tests on *deps*, not necessarily root'
}

{
    run "--installdeps", "./testdist/cpanfile_bad_app";
    like last_build_log, qr/Bareword "foobar" not allowed/;
}

done_testing;

