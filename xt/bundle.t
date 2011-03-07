use strict;
use xt::Run;
use Test::More;

my($out, $err) = run("--scandeps", "Bundle::DBI");
like $out, qr/DBD-Multiplex/;

done_testing;
