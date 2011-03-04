use strict;
use Test::More;
use xt::Run;

run "--no-notest", "./testdist/TestFail/";
like last_build_log, qr/Installing .* failed/;

run "--no-notest", "-f", "./testdist/TestFail/";
like last_build_log, qr/failed but installing/;

chdir "testdist/TestFail";
system "make distclean";

done_testing;

