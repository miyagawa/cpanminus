use strict;
use Test::More;
use xt::Run;

run "HTTP::Tiny", "HTTP::Tiny::Handle";
like last_build_log, qr/Already tried HTTP-Tiny/;

done_testing;

