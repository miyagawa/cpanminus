use strict;
use Test::More;
use lib ".";
use xt::Run;

run "Data::Dump";

run_L "--skip-installed", "Data::Dump";
like last_build_log, qr/installed Data-Dump/; # should reinstall because it's not core

done_testing;

