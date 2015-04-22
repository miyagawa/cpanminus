use xt::Run;
use Test::More;

run_L "-n", "Module::CPANfile";
run_L "./testdist/DepWithoutVersion";
like last_build_log, qr/\(undef\)/;

chdir "./testdist/DepWithoutVersion";
system 'make realclean';

done_testing;

