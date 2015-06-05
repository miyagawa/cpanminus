use strict;
use Test::More;
use xt::Run;

# install dev release of MakeMaker
run_L 'ExtUtils::MakeMaker@7.05_19';

# then install a module with Module::Install 1.04
run_L 'ADAMK/Class-Inspector-1.27.tar.gz';

unlike last_build_log, qr/Installed version \(7\.05_19\) of ExtUtils::MakeMaker is not in range '7\.0519'/;

done_testing;


