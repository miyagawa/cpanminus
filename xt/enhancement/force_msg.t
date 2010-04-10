use strict;
use Test::More;
use xt::Run;

run "./testdist/TestFail/";
like last_build_log, qr/Installing .* failed/;

run "-f", "./testdist/TestFail/";
like last_build_log, qr/failed but installing/;

chdir "testdist/TestFail";
system "make distclean";

done_testing;

