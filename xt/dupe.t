use strict;
use Test::More;
use xt::Run;

run "Email::Find", "Email::Find::addrspec";
like last_build_log, qr/Already tried Email-Find/;

done_testing;

