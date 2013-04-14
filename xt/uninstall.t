use strict;
use xt::Run;
use Test::More;

run 'Hash::MultiValue';
run_uninstall '-f', 'Hash::MultiValue';
like last_build_log, qr!Unlink.*/Hash/MultiValue\.pm!;

run_L 'Hash::MultiValue';
run_uninstall_L '-f', 'Hash::MultiValue';
like last_build_log, qr!Unlink.*$ENV{PERL_CPANM_HOME}.*/Hash/MultiValue\.pm!;

done_testing;
