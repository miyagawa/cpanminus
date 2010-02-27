use strict;
use Test::More;
use xt::Run;

run "App::cpanoutdated";

my $log = last_build_log;
like $log, qr/App::cpanoutdated .* successfully/;

done_testing;


