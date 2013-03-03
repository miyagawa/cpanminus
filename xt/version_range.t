use strict;
use Test::More;
use xt::Run;

run_L "./testdist/Foo-Ver";
like last_build_log, qr/Checking .* ExtUtils::MakeMaker > 5.* Yes/;
unlike last_build_log, qr/installed Hash-MultiValue/;
like last_build_log, qr/Found Hash::MultiValue .* doesn't satisfy > 2/;

chdir "testdist/Foo-Ver";
system "make distclean";

done_testing;

