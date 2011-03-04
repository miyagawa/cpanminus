use strict;
use Test::More;
use xt::Run;

run "App::cpanoutdated";

my $log = last_build_log;
like $log, qr/Successfully .*installed App-cpanoutdated/;

done_testing;


