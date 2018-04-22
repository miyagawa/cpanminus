use strict;
use Test::More;
use lib ".";
use xt::Run;

unlink "./testdist/Foo/META.yml"; # make sure

run "./testdist/Foo";
like last_build_log, qr/Writing MYMETA\.yml/;
unlike last_build_log, qr/Could not create MYMETA\.yml/;
like last_build_log, qr/installed Foo-0\.01/;

chdir "testdist/Foo";
system "make distclean";

done_testing;

