use strict;
use xt::Run;
use Test::More;

run "--reinstall", "--verify", "URI";
like last_build_log, qr/Fetching.*CHECKSUMS/;
like last_build_log, qr/Checksum.*Verified/;

done_testing;
