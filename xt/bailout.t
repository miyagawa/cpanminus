use strict;
use Test::More;
use xt::Run;

run "--no-notest", "./testdist/TestDist-DepFail/";
like last_build_log, qr/Bailing out/;

chdir "testdist/TestDist-DepFail";
system "make distclean";

done_testing;

