use strict;
use Test::More;
use xt::Run;

run "git://github.com/miyagawa/CPAN-Test-Dummy-MultiPkgVer.git";
like last_build_log, qr/Cloning/;
like last_build_log, qr/installed/;

run "git://github.com/miyagawa/___.git";
like last_build_log, qr/Fail/;

done_testing;

