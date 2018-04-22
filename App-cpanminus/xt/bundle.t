use strict;
use lib ".";
use xt::Run;
use Test::More;

my($out, $err) = run_L("--scandeps", "Bundle::DBI");
like $out, qr/DBD-Multiplex/;

done_testing;
