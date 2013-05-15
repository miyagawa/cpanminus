use strict;
use Test::More;
use xt::Run;

run "./testdist/HelloWorld-0.01/";

my $ver = `perl -MHelloWorld -e 'print \$HelloWorld::VERSION'`;
is $ver, 0.01;

run "--uninst-shadows", "./testdist/HelloWorld-0.02";
like last_build_log, qr/installed HelloWorld-0.02/;

my $ver = `perl -MHelloWorld -e 'print \$HelloWorld::VERSION'`;
is $ver, 0.02;

chdir "testdist/HelloWorld-0.01"; system "make distclean";
chdir "../../testdist/HelloWorld-0.02"; system "make distclean";

run "-Uf", "HelloWorld";

done_testing;

