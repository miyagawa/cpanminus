use strict;
use Test::More;
use xt::Run;

run "http://monster.bulknews.net/~miyagawa/Hash-MultiValue-0.13.tar.gz";
like last_build_log, qr/installed Hash-MultiValue/;

done_testing;

