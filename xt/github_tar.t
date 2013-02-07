use strict;
use Test::More;
use xt::Run;

run '-n', "https://github.com/plack/Plack/archive/master.tar.gz";
like last_build_log, qr/installed Plack-/;

done_testing;
