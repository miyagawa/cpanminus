use strict;
use Test::More;
use xt::Run;

run_L '--no-uninst-shadows', 'Acme::Pi';
unlike last_build_log, qr/installed Module-Build-Tiny/;
like last_build_log, qr/Distribution opts in x_static_install/;

done_testing;

