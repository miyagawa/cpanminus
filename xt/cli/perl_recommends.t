use strict;
use xt::Run;
use Test::More;

run_L 'Text::CSV_XS';
unlike last_build_log, qr/Needs perl 5\.016/;

done_testing;

