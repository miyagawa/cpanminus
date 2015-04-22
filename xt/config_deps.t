use strict;
use Test::More;
use xt::Run;

run_L 'git://github.com/kazeburo/CPAN-Test-Dummy-ConfigDeps.git';
like last_build_log, qr/Checking if you have Module::CPANfile/;

done_testing;

