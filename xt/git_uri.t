use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run "-L", $local_lib, "git://github.com/miyagawa/cpanminus.git";
like last_build_log, qr/installed/;

done_testing;

