use strict;
use xt::Run;
use Test::More;

run_L '--notest', 'Object::Array';
unlike last_build_log, qr/--installdeps=/;
like last_build_log, qr/installed Sub-Exporter/;

done_testing;
