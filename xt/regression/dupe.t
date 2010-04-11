use strict;
use Test::More;
use xt::Run;

run "CGI", "CGI::Cookie";
like last_build_log, qr/Already tried CGI\.pm/;

done_testing;

