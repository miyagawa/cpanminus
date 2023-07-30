use strict;
use Test::More;
use xt::Run;

# check http(s) git uri works
run "https://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git";
like last_build_log, qr/Cloning/;
like last_build_log, qr/installed .*-0\.01/;

done_testing;

