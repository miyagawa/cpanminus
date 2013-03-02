use strict;
use xt::Run;
use Test::More;

run 'Net::LDAP::Server::Test@0.14';
like last_build_log, qr/Fetching .*backpan/;

# --dev shouldn't search for backpan
run '--test-only', '--notest', '--dev', 'Test::More';
unlike last_build_log, qr/backpan/;
like last_build_log, qr/TB2/;

done_testing;

