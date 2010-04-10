use strict;
use Test::More;
use xt::Run;

run "./xt/testdist/TestFail/";
like last_build_log, qr/Installing .* failed/;

run "-f", "./xt/testdist/TestFail/";
like last_build_log, qr/failed but installing/;

chdir "xt/testdist/TestFail";
system "make distclean";

done_testing;

