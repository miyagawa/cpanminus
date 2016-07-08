use strict;
use xt::Run;
use Test::More;

run 'DBI'; # https://github.com/perl5-dbi/DBD-mysql/pull/51
run 'DBD::mysql', '--configure-args=--help';
like last_build_log, qr/Print this message/;
like last_build_log, qr/Configure failed/;

done_testing;
