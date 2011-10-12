use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
run "-L", $local_lib, "--mirror-index", "xt/mirror.txt", "Hash::MultiValue";
like last_build_log, qr/installed Hash-MultiValue-0\.02/;

run "-L", $local_lib, "--mirror-index", "xt/mirror.txt", "--skip-installed", "Hash::MultiValue~0.03";
like last_build_log, qr/Hash::MultiValue is up to date/;

run "-L", $local_lib, "--mirror-index", "xt/mirror.txt", "--skip-installed", "--cascade-search", "Hash::MultiValue~0.03";
like last_build_log, qr/installed Hash-MultiValue/;

done_testing;
