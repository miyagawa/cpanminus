use strict;
use Test::More;
use lib ".";
use xt::Run;

run "git://github.com/miyagawa/___.git";
like last_build_log, qr/Fail/;

run "git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git";
like last_build_log, qr/Cloning/;
like last_build_log, qr/installed .*-0\.01/;

run 'git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@devel';
like last_build_log, qr/installed .*-0\.02/;

run 'git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@0.02';
like last_build_log, qr/installed .*-0\.02/;

run 'git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@acdffda';
like last_build_log, qr/installed .*-0\.02/;

run 'git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@nonexistent';
like last_build_log, qr/Failed to checkout 'nonexistent'/;
unlike last_build_log, qr/cannot remove path/;

# check http(s) git uri works
run "https://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git";
like last_build_log, qr/Cloning/;
like last_build_log, qr/installed .*-0\.01/;

done_testing;

