use strict;
use Test::More;
use xt::Run;

{
    run_L "--installdeps", "--notest", "./testdist/cpanfile_pin";
    unlike last_build_log, qr/Installed version \(.*\) of Path::Class is not in range '== 0.26'/;
}

done_testing;
