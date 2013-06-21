use strict;
use Test::More;
use xt::Run;

run "./testdist/Sym";
like last_build_log, qr/installed/;

run "--installdeps", "./testdist/SymUp";
like last_build_log, qr/Installed dependencies/;

done_testing;
