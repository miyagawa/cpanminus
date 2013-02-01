use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run "-L", $local_lib, '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.01';
like last_build_log, qr/Found Hash::MultiValue 0.02 which doesn't satisfy == 0.01/;

run "-L", $local_lib, '--mirror-index', 'xt/mirror.txt', 'Hash::MultiValue@0.02';
like last_build_log, qr/installed Hash-MultiValue-0.02/;

run "-L", $local_lib, '--mirror-only', 'Try::Tiny@0.10';
like last_build_log, qr/Found Try::Tiny .* doesn't satisfy == 0.10/;

done_testing;
