use strict;
use lib ".";
use xt::Run;
use Test::More;

# DBD::mysql needs DBI to configure, and DBI 1.656+ requires perl 5.12
plan skip_all => "DBI requires perl 5.12" if $] < 5.012;

run 'DBD::mysql', '--configure-args=--help';
like last_build_log, qr/Print this message/;
like last_build_log, qr/Configure failed/;

done_testing;
