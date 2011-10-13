use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
run "-L", $local_lib, "MIYAGAWA/Hash-MultiValue-0.03.tar.gz";
run "-L", $local_lib, "Hash::MultiValue~0.02";

like last_build_log, qr/You have Hash::MultiValue \(0\.03\)/;

run "-L", $local_lib, "Hash::MultiValue~0.04";
like last_build_log, qr/installed Hash-MultiValue/;

done_testing;
