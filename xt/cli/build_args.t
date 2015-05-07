use strict;
use xt::Run;
use Test::More;

run 'DBD::mysql', '--configure-args=--help';
like last_build_log, qr/Print this message/;
like last_build_log, qr/Configure failed/;

done_testing;
