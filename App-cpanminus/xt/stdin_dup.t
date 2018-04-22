use strict;
use Test::More;
use lib ".";
use xt::Run;

run "HTTP::Request::AsCGI";
like last_build_log, qr/Successfully/;

done_testing;

