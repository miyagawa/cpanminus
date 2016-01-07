use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;
use File::Temp;
use File::Copy::Recursive qw(dircopy);

{
    my $dir = File::Temp::tempdir;

    dircopy("testdist/local-mirror","$dir/local-mirror");

    open my $cpanfile, ">", "$dir/cpanfile";
    print $cpanfile <<EOF;
mirror 'file:/$dir/local-mirror';
requires 'Hash::MultiValue';
EOF

    run_L "--mirror-only", "--installdeps", $dir;
    like last_build_log, qr/Fetching file\:\/$dir\/local-mirror/;
}

{
    run_L "--installdeps", "./testdist/cpanfile_app";

    like last_build_log, qr/installed Hash-MultiValue-0\.10/;
    like last_build_log, qr/installed Try-Tiny-0\.11/;
    like last_build_log, qr/installed Test-Warn/, '--notest means skip tests on *deps*, not necessarily root';
    unlike last_build_log, qr/installed Module-Build-Tiny/;
}

{
    run_L "--installdeps", "--with-configure", "./testdist/cpanfile_app";

    like last_build_log, qr/installed Hash-MultiValue-0\.10/;
    like last_build_log, qr/installed Try-Tiny-0\.11/;
    like last_build_log, qr/installed Test-Warn/, '--notest means skip tests on *deps*, not necessarily root';
    like last_build_log, qr/installed Module-Build-Tiny/;
}


{
    run "--installdeps", "./testdist/cpanfile_bad_app";
    like last_build_log, qr/Bareword "foobar" not allowed/;
}

{
    run_L "--installdeps", "--cpanfile", "cpanfile.foobar", "./testdist/cpanfile_app2";
    like last_build_log, qr/installed Hash-MultiValue-0\.12/;
}

{
    my($out, $err) = run_L "--installdeps", "./testdist/cpanfile_non_resolvable";
    like $err, qr/Can't merge requirements for File::Spec/;
    like last_build_log, qr/Installed version \(.*\) of File::Spec is not in range '.*'/;
}

done_testing;

