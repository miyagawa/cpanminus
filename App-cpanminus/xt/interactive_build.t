use strict;
use xt::Run;
use Test::More;

run '--build-timeout', 5, 'Mail::Sender';
like last_build_log, qr/installed Mail-Sender/;

done_testing;
