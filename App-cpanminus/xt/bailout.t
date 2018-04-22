use strict;
use Test::More;
use lib ".";
use xt::Run;

$ENV{TEST} = 1;
run "./testdist/TestDist-DepFail/";
like last_build_log, qr/Bailing out/;

chdir "testdist/TestDist-DepFail";
system "make distclean";

done_testing;

