use strict;
use Test::More;
use xt::Run;

# http://www.cpan.org/ no longer has 0.02, 0.03 and 0.04 switch to 0.13, 0.14 and 0.15
my ($old, $mid, $new) = qw{0.13 0.14 0.15};
run_L "MIYAGAWA/Hash-MultiValue-$mid.tar.gz";
run_L '--skip-satisfied', "Hash::MultiValue~$old";

like last_build_log, qr/You have Hash::MultiValue \(\Q$mid\E\)/;

run_L '--skip-satisfied', "Hash::MultiValue~$new";
like last_build_log, qr/installed Hash-MultiValue/;

done_testing;
