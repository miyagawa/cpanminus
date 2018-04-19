use strict;
use Test::More;
use xt::Run;

my ($old, $mid, $new) = qw{0.12 0.13 0.14};
run_L "--mirror-index", "xt/mirror.txt", "Hash::MultiValue";
like last_build_log, qr/installed Hash-MultiValue-\Q$mid\E/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "Hash::MultiValue~$old";
like last_build_log, qr/Hash::MultiValue is up to date/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "Hash::MultiValue~$new";
like last_build_log, qr/Found Hash::MultiValue \Q$mid\E which doesn't satisfy \Q$new\E/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "--cascade-search", "Hash::MultiValue~$new";
like last_build_log, qr/installed Hash-MultiValue-/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "Try::Tiny";
like last_build_log, qr/Couldn't find .* Try::Tiny/;

run_L "--mirror-index", "xt/mirror.txt", "--skip-installed", "--cascade-search", "Try::Tiny";
like last_build_log, qr/installed Try-Tiny/;

done_testing;
