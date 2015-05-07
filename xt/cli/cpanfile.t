use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

{
    run_L "--installdeps", "./testdist/cpanfile_app";

    like last_build_log, qr/installed Hash-MultiValue-0\.12/;
    like last_build_log, qr/installed Try-Tiny-0\.11/;
    like last_build_log, qr/installed Test-Warn/, '--notest means skip tests on *deps*, not necessarily root'
}

{
    run "--installdeps", "./testdist/cpanfile_bad_app";
    like last_build_log, qr/Bareword "foobar" not allowed/;
}

{
    run_L "--installdeps", "--cpanfile", "cpanfile.foobar", "./testdist/cpanfile_app2";
    like last_build_log, qr/installed Hash-MultiValue-0\.13/;
}

{
    my($out, $err) = run_L "--installdeps", "./testdist/cpanfile_non_resolvable";
    like $err, qr/Can't merge requirements for Time::Local/;
    like last_build_log, qr/Installed version \(1\.1901\) of Time::Local is not in range '1\.2'/;
}

done_testing;

