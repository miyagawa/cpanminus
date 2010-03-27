use strict;
use Test::More;
use xt::Run;

unlink "./xt/testdist/Foo/META.yml"; # make sure

run "./xt/testdist/Foo";
like last_build_log, qr/installed Foo-0\.01/;

chdir "xt/testdist/Foo";
system "make distclean";

done_testing;

