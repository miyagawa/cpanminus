use strict;
use Test::More;
use xt::Run;

{
    run_L "--installdeps", "./testdist/cpanfile_pin";
    unlike last_build_log, qr/Installed version \(.*\) of Path::Class is not in range '== 0.26'/;

    like last_build_log, qr/installed Path-Class-0\.26/;
    like last_build_log, qr/installed Data-Dumper-2\.139/;
}

{
    run_L "--installdeps", "./testdist/cpanfile_pin_core";
    unlike last_build_log, qr/Installing the dependencies failed/;
}

done_testing;
